const express = require('express');
const bcrypt = require('bcryptjs');
const { PrismaClient } = require('@prisma/client');
const { body, param, validationResult } = require('express-validator');

const { asyncHandler, AppError } = require('../middleware/errorHandler');
const { requireRole } = require('../middleware/auth');
const { uploadConfigs, getFileUrl, moveFile } = require('../middleware/upload');
const { encrypt } = require('../utils/encryption');
const validators = require('../utils/validators');

const router = express.Router();
const prisma = new PrismaClient();

/**
 * @route   GET /api/v1/students
 * @desc    Get all students (filtered by class for teachers)
 * @access  Private
 */
router.get('/', asyncHandler(async (req, res) => {
  const { classId, page = 1, limit = 50, search } = req.query;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  let where = { schoolId: req.user.schoolId, isActive: true };

  // For teachers, filter by assigned classes
  if (req.user.role === 'TEACHER') {
    const teacherClasses = await prisma.teacherClass.findMany({
      where: { userId: req.user.id },
      select: { classId: true }
    });
    where.classId = { in: teacherClasses.map(tc => tc.classId) };
  }

  if (classId) where.classId = classId;

  if (search) {
    where.OR = [
      { firstName: { contains: search, mode: 'insensitive' } },
      { lastName: { contains: search, mode: 'insensitive' } },
      { rollNumber: { contains: search, mode: 'insensitive' } }
    ];
  }

  const [students, total] = await Promise.all([
    prisma.student.findMany({
      where,
      select: {
        id: true,
        rollNumber: true,
        firstName: true,
        lastName: true,
        email: true,
        phone: true,
        parentName: true,
        parentPhone: true,
        profileImage: true,
        classId: true,
        class: {
          select: { id: true, name: true, section: true, grade: true }
        }
      },
      skip,
      take: parseInt(limit),
      orderBy: [{ class: { grade: 'asc' } }, { rollNumber: 'asc' }]
    }),
    prisma.student.count({ where })
  ]);

  res.json({
    success: true,
    data: {
      students: students.map(s => ({
        ...s,
        profileImage: s.profileImage ? getFileUrl(s.profileImage, req) : null
      })),
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    }
  });
}));

/**
 * @route   POST /api/v1/students
 * @desc    Add a new student
 * @access  Private (Principal/Teacher)
 */
router.post('/', validators.studentCreate, asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const {
    classId, rollNumber, firstName, lastName, email, phone,
    parentName, parentPhone, parentEmail, address,
    dateOfBirth, gender, bloodGroup, password
  } = req.body;

  // Verify class belongs to school
  const classRecord = await prisma.class.findFirst({
    where: { id: classId, schoolId: req.user.schoolId }
  });

  if (!classRecord) {
    throw new AppError('Class not found', 404);
  }

  // Check for duplicate roll number in class
  const existingStudent = await prisma.student.findFirst({
    where: { schoolId: req.user.schoolId, classId, rollNumber }
  });

  if (existingStudent) {
    throw new AppError('A student with this roll number already exists in this class', 409);
  }

  // Generate default password if not provided
  const studentPassword = password || `${rollNumber}@${new Date().getFullYear()}`;
  const hashedPassword = await bcrypt.hash(studentPassword, 12);

  const student = await prisma.student.create({
    data: {
      schoolId: req.user.schoolId,
      classId,
      rollNumber,
      firstName,
      lastName,
      email,
      phone,
      parentName,
      parentPhone,
      parentEmail,
      address,
      dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : null,
      gender,
      bloodGroup,
      password: hashedPassword
    }
  });

  // Create audit log
  await prisma.auditLog.create({
    data: {
      schoolId: req.user.schoolId,
      userId: req.user.id,
      action: 'CREATE',
      entityType: 'STUDENT',
      entityId: student.id,
      newValue: { rollNumber, firstName, lastName, classId }
    }
  });

  res.status(201).json({
    success: true,
    message: 'Student added successfully',
    data: {
      id: student.id,
      rollNumber: student.rollNumber,
      firstName: student.firstName,
      lastName: student.lastName,
      defaultPassword: password ? undefined : studentPassword
    }
  });
}));

/**
 * @route   GET /api/v1/students/:id
 * @desc    Get student by ID
 * @access  Private
 */
router.get('/:id', [param('id').isUUID()], asyncHandler(async (req, res) => {
  const student = await prisma.student.findFirst({
    where: {
      id: req.params.id,
      schoolId: req.user.schoolId
    },
    include: {
      class: true
    }
  });

  if (!student) {
    throw new AppError('Student not found', 404);
  }

  // Remove sensitive data
  const { password, faceEncoding, ...studentData } = student;

  res.json({
    success: true,
    data: {
      ...studentData,
      profileImage: student.profileImage ? getFileUrl(student.profileImage, req) : null,
      hasFaceEncoding: !!faceEncoding
    }
  });
}));

/**
 * @route   PUT /api/v1/students/:id
 * @desc    Update student
 * @access  Private
 */
router.put('/:id', [
  param('id').isUUID(),
  body('firstName').optional().trim().isLength({ min: 2, max: 50 }),
  body('lastName').optional().trim().isLength({ min: 2, max: 50 }),
  body('email').optional().isEmail().normalizeEmail(),
  body('phone').optional().matches(/^\+?[\d\s-]{10,15}$/),
  body('parentName').optional().trim().isLength({ min: 2, max: 100 }),
  body('parentPhone').optional().matches(/^\+?[\d\s-]{10,15}$/),
  body('classId').optional().isUUID()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const { id } = req.params;
  const updateData = req.body;

  const student = await prisma.student.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!student) {
    throw new AppError('Student not found', 404);
  }

  // If changing class, verify new class belongs to school
  if (updateData.classId) {
    const classRecord = await prisma.class.findFirst({
      where: { id: updateData.classId, schoolId: req.user.schoolId }
    });
    if (!classRecord) {
      throw new AppError('Class not found', 404);
    }
  }

  const updatedStudent = await prisma.student.update({
    where: { id },
    data: {
      ...updateData,
      ...(updateData.dateOfBirth && { dateOfBirth: new Date(updateData.dateOfBirth) })
    }
  });

  res.json({
    success: true,
    message: 'Student updated successfully',
    data: updatedStudent
  });
}));

/**
 * @route   POST /api/v1/students/:id/photo
 * @desc    Upload student profile photo
 * @access  Private
 */
router.post('/:id/photo',
  uploadConfigs.studentImage.single('photo'),
  asyncHandler(async (req, res) => {
    const { id } = req.params;

    if (!req.file) {
      throw new AppError('No file uploaded', 400);
    }

    const student = await prisma.student.findFirst({
      where: { id, schoolId: req.user.schoolId }
    });

    if (!student) {
      throw new AppError('Student not found', 404);
    }

    const updatedStudent = await prisma.student.update({
      where: { id },
      data: { profileImage: req.file.path }
    });

    res.json({
      success: true,
      message: 'Photo uploaded successfully',
      data: {
        profileImage: getFileUrl(updatedStudent.profileImage, req)
      }
    });
  })
);

/**
 * @route   POST /api/v1/students/:id/face-encoding
 * @desc    Store face encoding for attendance
 * @access  Private
 */
router.post('/:id/face-encoding', [
  param('id').isUUID(),
  body('encoding').notEmpty()
], asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { encoding } = req.body;

  const student = await prisma.student.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!student) {
    throw new AppError('Student not found', 404);
  }

  // Encrypt the face encoding before storing
  const encryptedEncoding = encrypt(JSON.stringify(encoding));

  await prisma.student.update({
    where: { id },
    data: { faceEncoding: encryptedEncoding }
  });

  res.json({
    success: true,
    message: 'Face encoding stored successfully'
  });
}));

/**
 * @route   DELETE /api/v1/students/:id
 * @desc    Deactivate student
 * @access  Private (Principal only)
 */
router.delete('/:id', requireRole('PRINCIPAL'), [
  param('id').isUUID()
], asyncHandler(async (req, res) => {
  const { id } = req.params;

  const student = await prisma.student.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!student) {
    throw new AppError('Student not found', 404);
  }

  await prisma.student.update({
    where: { id },
    data: { isActive: false }
  });

  res.json({
    success: true,
    message: 'Student deactivated successfully'
  });
}));

module.exports = router;

