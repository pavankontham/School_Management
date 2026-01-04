const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { body, param, validationResult } = require('express-validator');

const { asyncHandler, AppError } = require('../middleware/errorHandler');
const { requireRole } = require('../middleware/auth');
const validators = require('../utils/validators');

const router = express.Router();
const prisma = new PrismaClient();

/**
 * @route   GET /api/v1/classes
 * @desc    Get all classes in school
 * @access  Private
 */
router.get('/', asyncHandler(async (req, res) => {
  const { grade, academicYear, isActive } = req.query;

  let where = { schoolId: req.user.schoolId };

  // For teachers, only show assigned classes
  if (req.user.role === 'TEACHER') {
    const teacherClasses = await prisma.teacherClass.findMany({
      where: { userId: req.user.id },
      select: { classId: true }
    });
    where.id = { in: teacherClasses.map(tc => tc.classId) };
  }

  if (grade) where.grade = grade;
  if (academicYear) where.academicYear = academicYear;
  if (isActive !== undefined) where.isActive = isActive === 'true';

  const classes = await prisma.class.findMany({
    where,
    include: {
      _count: {
        select: { students: true }
      },
      subjects: {
        include: {
          subject: {
            select: { id: true, name: true, code: true }
          }
        }
      }
    },
    orderBy: [{ grade: 'asc' }, { name: 'asc' }]
  });

  res.json({
    success: true,
    data: classes
  });
}));

/**
 * @route   POST /api/v1/classes
 * @desc    Create a new class
 * @access  Private (Principal only)
 */
router.post('/', requireRole('PRINCIPAL'), validators.classCreate, asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const { name, section, grade, academicYear, subjectIds = [] } = req.body;

  const newClass = await prisma.$transaction(async (tx) => {
    const classRecord = await tx.class.create({
      data: {
        schoolId: req.user.schoolId,
        name,
        section,
        grade,
        academicYear
      }
    });

    // Assign subjects to class
    if (subjectIds.length > 0) {
      await tx.classSubject.createMany({
        data: subjectIds.map(subjectId => ({
          classId: classRecord.id,
          subjectId
        }))
      });
    }

    return classRecord;
  });

  // Create audit log
  await prisma.auditLog.create({
    data: {
      schoolId: req.user.schoolId,
      userId: req.user.id,
      action: 'CREATE',
      entityType: 'CLASS',
      entityId: newClass.id,
      newValue: { name, section, grade, academicYear }
    }
  });

  res.status(201).json({
    success: true,
    message: 'Class created successfully',
    data: newClass
  });
}));

/**
 * @route   GET /api/v1/classes/:id
 * @desc    Get class by ID
 * @access  Private
 */
router.get('/:id', [param('id').isUUID()], asyncHandler(async (req, res) => {
  const classRecord = await prisma.class.findFirst({
    where: {
      id: req.params.id,
      schoolId: req.user.schoolId
    },
    include: {
      students: {
        where: { isActive: true },
        select: {
          id: true,
          rollNumber: true,
          firstName: true,
          lastName: true,
          profileImage: true
        },
        orderBy: { rollNumber: 'asc' }
      },
      subjects: {
        include: {
          subject: true
        }
      },
      teacherClasses: {
        include: {
          user: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              email: true
            }
          }
        }
      }
    }
  });

  if (!classRecord) {
    throw new AppError('Class not found', 404);
  }

  res.json({
    success: true,
    data: classRecord
  });
}));

/**
 * @route   PUT /api/v1/classes/:id
 * @desc    Update class
 * @access  Private (Principal only)
 */
router.put('/:id', requireRole('PRINCIPAL'), [
  param('id').isUUID(),
  body('name').optional().trim().isLength({ min: 1, max: 50 }),
  body('section').optional().trim().isLength({ max: 10 }),
  body('grade').optional().trim().isLength({ min: 1, max: 20 }),
  body('isActive').optional().isBoolean()
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
  const { name, section, grade, isActive } = req.body;

  const classRecord = await prisma.class.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!classRecord) {
    throw new AppError('Class not found', 404);
  }

  const updatedClass = await prisma.class.update({
    where: { id },
    data: {
      ...(name && { name }),
      ...(section !== undefined && { section }),
      ...(grade && { grade }),
      ...(isActive !== undefined && { isActive })
    }
  });

  res.json({
    success: true,
    message: 'Class updated successfully',
    data: updatedClass
  });
}));

/**
 * @route   PUT /api/v1/classes/:id/subjects
 * @desc    Update class subjects
 * @access  Private (Principal only)
 */
router.put('/:id/subjects', requireRole('PRINCIPAL'), [
  param('id').isUUID(),
  body('subjectIds').isArray()
], asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { subjectIds } = req.body;

  const classRecord = await prisma.class.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!classRecord) {
    throw new AppError('Class not found', 404);
  }

  await prisma.$transaction(async (tx) => {
    await tx.classSubject.deleteMany({ where: { classId: id } });
    
    if (subjectIds.length > 0) {
      await tx.classSubject.createMany({
        data: subjectIds.map(subjectId => ({ classId: id, subjectId }))
      });
    }
  });

  res.json({
    success: true,
    message: 'Class subjects updated successfully'
  });
}));

/**
 * @route   DELETE /api/v1/classes/:id
 * @desc    Deactivate class
 * @access  Private (Principal only)
 */
router.delete('/:id', requireRole('PRINCIPAL'), [
  param('id').isUUID()
], asyncHandler(async (req, res) => {
  const { id } = req.params;

  const classRecord = await prisma.class.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!classRecord) {
    throw new AppError('Class not found', 404);
  }

  await prisma.class.update({
    where: { id },
    data: { isActive: false }
  });

  res.json({
    success: true,
    message: 'Class deactivated successfully'
  });
}));

/**
 * @route   GET /api/v1/classes/:id/students
 * @desc    Get all students in a class
 * @access  Private
 */
router.get('/:id/students', [param('id').isUUID()], asyncHandler(async (req, res) => {
  const students = await prisma.student.findMany({
    where: {
      classId: req.params.id,
      schoolId: req.user.schoolId,
      isActive: true
    },
    orderBy: { rollNumber: 'asc' }
  });

  res.json({
    success: true,
    data: students
  });
}));

module.exports = router;

