const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { body, validationResult } = require('express-validator');

const { asyncHandler, AppError } = require('../middleware/errorHandler');
const { requireRole } = require('../middleware/auth');
const { uploadConfigs, getFileUrl } = require('../middleware/upload');

const router = express.Router();
const prisma = new PrismaClient();

/**
 * @route   GET /api/v1/schools/current
 * @desc    Get current user's school details
 * @access  Private
 */
router.get('/current', asyncHandler(async (req, res) => {
  const school = await prisma.school.findUnique({
    where: { id: req.user.schoolId },
    include: {
      _count: {
        select: {
          users: true,
          students: true,
          classes: true,
          subjects: true
        }
      }
    }
  });

  if (!school) {
    throw new AppError('School not found', 404);
  }

  res.json({
    success: true,
    data: {
      ...school,
      logo: school.logo ? getFileUrl(school.logo, req) : null
    }
  });
}));

/**
 * @route   PUT /api/v1/schools/current
 * @desc    Update current school details
 * @access  Private (Principal only)
 */
router.put('/current', requireRole('PRINCIPAL'), [
  body('name').optional().trim().isLength({ min: 3, max: 200 }),
  body('address').optional().trim().isLength({ min: 5, max: 500 }),
  body('city').optional().trim().isLength({ min: 2, max: 100 }),
  body('state').optional().trim().isLength({ min: 2, max: 100 }),
  body('country').optional().trim().isLength({ min: 2, max: 100 }),
  body('postalCode').optional().trim().isLength({ min: 3, max: 20 }),
  body('phone').optional().matches(/^\+?[\d\s-]{10,15}$/),
  body('website').optional().isURL()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const { name, address, city, state, country, postalCode, phone, website } = req.body;

  const school = await prisma.school.update({
    where: { id: req.user.schoolId },
    data: {
      ...(name && { name }),
      ...(address && { address }),
      ...(city && { city }),
      ...(state && { state }),
      ...(country && { country }),
      ...(postalCode && { postalCode }),
      ...(phone && { phone }),
      ...(website && { website })
    }
  });

  // Create audit log (only log fields that were updated)
  const updatedFields = {};
  if (name) updatedFields.name = name;
  if (address) updatedFields.address = address;
  if (city) updatedFields.city = city;
  if (state) updatedFields.state = state;
  if (country) updatedFields.country = country;
  if (postalCode) updatedFields.postalCode = postalCode;
  if (phone) updatedFields.phone = phone;
  if (website) updatedFields.website = website;

  await prisma.auditLog.create({
    data: {
      schoolId: req.user.schoolId,
      userId: req.user.id,
      action: 'UPDATE',
      entityType: 'SCHOOL',
      entityId: school.id,
      newValue: updatedFields
    }
  });

  res.json({
    success: true,
    message: 'School updated successfully',
    data: school
  });
}));

/**
 * @route   POST /api/v1/schools/current/logo
 * @desc    Upload school logo
 * @access  Private (Principal only)
 */
router.post('/current/logo',
  requireRole('PRINCIPAL'),
  uploadConfigs.dashboardMedia.single('logo'),
  asyncHandler(async (req, res) => {
    if (!req.file) {
      throw new AppError('No file uploaded', 400);
    }

    const school = await prisma.school.update({
      where: { id: req.user.schoolId },
      data: { logo: req.file.path }
    });

    res.json({
      success: true,
      message: 'Logo uploaded successfully',
      data: {
        logo: getFileUrl(school.logo, req)
      }
    });
  })
);

/**
 * @route   GET /api/v1/schools/stats
 * @desc    Get school statistics
 * @access  Private (Principal only)
 */
router.get('/stats', requireRole('PRINCIPAL'), asyncHandler(async (req, res) => {
  const schoolId = req.user.schoolId;

  // Use single date to avoid race conditions
  const now = new Date();
  const todayStart = new Date(now.setHours(0, 0, 0, 0));
  const todayEnd = new Date(now.setHours(23, 59, 59, 999));
  const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

  const [
    teacherCount,
    studentCount,
    classCount,
    subjectCount,
    todayAttendance,
    recentQuizzes
  ] = await Promise.all([
    prisma.user.count({
      where: { schoolId, role: 'TEACHER', isActive: true }
    }),
    prisma.student.count({
      where: { schoolId, isActive: true }
    }),
    prisma.class.count({
      where: { schoolId, isActive: true }
    }),
    prisma.subject.count({
      where: { schoolId, isActive: true }
    }),
    prisma.attendance.groupBy({
      by: ['status'],
      where: {
        schoolId,
        date: {
          gte: todayStart,
          lt: todayEnd
        }
      },
      _count: true
    }),
    prisma.quiz.count({
      where: {
        schoolId,
        createdAt: { gte: weekAgo }
      }
    })
  ]);

  const attendanceStats = {
    present: 0,
    absent: 0,
    late: 0,
    excused: 0
  };

  todayAttendance.forEach(item => {
    attendanceStats[item.status.toLowerCase()] = item._count;
  });

  res.json({
    success: true,
    data: {
      teachers: teacherCount,
      students: studentCount,
      classes: classCount,
      subjects: subjectCount,
      todayAttendance: attendanceStats,
      recentQuizzes
    }
  });
}));

/**
 * @route   GET /api/v1/schools/public/:schoolId
 * @desc    Get public school info (for student login)
 * @access  Public
 */
router.get('/public/:schoolId', asyncHandler(async (req, res) => {
  const school = await prisma.school.findUnique({
    where: { id: req.params.schoolId },
    select: {
      id: true,
      name: true,
      logo: true,
      city: true,
      state: true
    }
  });

  if (!school) {
    throw new AppError('School not found', 404);
  }

  res.json({
    success: true,
    data: {
      ...school,
      logo: school.logo ? getFileUrl(school.logo, req) : null
    }
  });
}));

/**
 * @route   PUT /api/v1/schools/grading-scale
 * @desc    Update school grading scale
 * @access  Private (Principal only)
 */
router.put('/grading-scale', requireRole('PRINCIPAL'), [
  body('gradingScale').isArray(),
  body('gradingScale.*.grade').trim().notEmpty(),
  body('gradingScale.*.minPercentage').isFloat({ min: 0, max: 100 }),
  body('gradingScale.*.maxPercentage').isFloat({ min: 0, max: 100 })
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const { gradingScale } = req.body;

  // Validate grading scale ranges don't overlap
  for (let i = 0; i < gradingScale.length; i++) {
    const scale = gradingScale[i];

    if (scale.minPercentage > scale.maxPercentage) {
      throw new AppError(`Invalid range for grade ${scale.grade}: min cannot be greater than max`, 400);
    }

    // Check for overlaps with other ranges
    for (let j = i + 1; j < gradingScale.length; j++) {
      const other = gradingScale[j];
      const overlaps = !(scale.maxPercentage < other.minPercentage || scale.minPercentage > other.maxPercentage);

      if (overlaps) {
        throw new AppError(`Grade ranges overlap: ${scale.grade} and ${other.grade}`, 400);
      }
    }
  }

  // Sort by minPercentage descending for proper grade calculation
  const sortedScale = gradingScale.sort((a, b) => b.minPercentage - a.minPercentage);

  const school = await prisma.school.update({
    where: { id: req.user.schoolId },
    data: { gradingScale: sortedScale }
  });

  // Create audit log
  await prisma.auditLog.create({
    data: {
      schoolId: req.user.schoolId,
      userId: req.user.id,
      action: 'UPDATE',
      entityType: 'SCHOOL_GRADING_SCALE',
      entityId: school.id,
      newValue: { gradingScale: sortedScale }
    }
  });

  res.json({
    success: true,
    message: 'Grading scale updated successfully',
    data: { gradingScale: school.gradingScale }
  });
}));

/**
 * @route   GET /api/v1/schools/grading-scale
 * @desc    Get school grading scale
 * @access  Private
 */
router.get('/grading-scale', asyncHandler(async (req, res) => {
  const school = await prisma.school.findUnique({
    where: { id: req.user.schoolId },
    select: { gradingScale: true }
  });

  // Return school-specific or default scale
  const gradingScale = school?.gradingScale || [
    { grade: 'A+', minPercentage: 90, maxPercentage: 100 },
    { grade: 'A', minPercentage: 80, maxPercentage: 89 },
    { grade: 'B+', minPercentage: 70, maxPercentage: 79 },
    { grade: 'B', minPercentage: 60, maxPercentage: 69 },
    { grade: 'C', minPercentage: 50, maxPercentage: 59 },
    { grade: 'D', minPercentage: 40, maxPercentage: 49 },
    { grade: 'F', minPercentage: 0, maxPercentage: 39 }
  ];

  res.json({
    success: true,
    data: {
      gradingScale,
      isCustom: !!school?.gradingScale
    }
  });
}));

module.exports = router;

