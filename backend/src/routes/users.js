const express = require('express');
const bcrypt = require('bcryptjs');
const { PrismaClient } = require('@prisma/client');
const { body, param, validationResult } = require('express-validator');

const { asyncHandler, AppError } = require('../middleware/errorHandler');
const { requireRole } = require('../middleware/auth');
const validators = require('../utils/validators');

const router = express.Router();
const prisma = new PrismaClient();

/**
 * @route   GET /api/v1/users
 * @desc    Get all users (teachers) in school
 * @access  Private (Principal only)
 */
router.get('/', requireRole(['PRINCIPAL', 'TEACHER']), asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, role, isActive, search } = req.query;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  const where = {
    schoolId: req.user.schoolId,
    ...(role && { role }),
    ...(isActive !== undefined && { isActive: isActive === 'true' }),
    ...(search && {
      OR: [
        { firstName: { contains: search, mode: 'insensitive' } },
        { lastName: { contains: search, mode: 'insensitive' } },
        { email: { contains: search, mode: 'insensitive' } },
      ]
    })
  };

  const [users, total] = await Promise.all([
    prisma.user.findMany({
      where,
      select: {
        id: true,
        email: true,
        phone: true,
        firstName: true,
        lastName: true,
        role: true,
        profileImage: true,
        isActive: true,
        lastLogin: true,
        createdAt: true,
        teacherClasses: {
          include: {
            class: {
              select: { id: true, name: true, section: true, grade: true }
            }
          }
        },
        teacherSubjects: {
          include: {
            subject: {
              select: { id: true, name: true, code: true }
            }
          }
        }
      },
      skip,
      take: parseInt(limit),
      orderBy: { createdAt: 'desc' }
    }),
    prisma.user.count({ where })
  ]);

  res.json({
    success: true,
    data: {
      users,
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
 * @route   POST /api/v1/users/teacher
 * @desc    Add a new teacher
 * @access  Private (Principal only)
 */
router.post('/teacher', requireRole('PRINCIPAL'), [
  validators.email,
  validators.password,
  validators.firstName,
  validators.lastName,
  validators.phone,
  body('classIds').optional().isArray(),
  body('classIds.*').optional().isUUID(),
  body('subjectIds').optional().isArray(),
  body('subjectIds.*').optional().isUUID()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const { email, password, firstName, lastName, phone, classIds = [], subjectIds = [] } = req.body;

  // Check if email exists
  const existingUser = await prisma.user.findUnique({
    where: { email }
  });

  if (existingUser) {
    throw new AppError('A user with this email already exists', 409);
  }

  // Hash password
  const hashedPassword = await bcrypt.hash(password, 12);

  // Create teacher with class and subject assignments
  const teacher = await prisma.$transaction(async (tx) => {
    const user = await tx.user.create({
      data: {
        schoolId: req.user.schoolId,
        email,
        phone,
        password: hashedPassword,
        firstName,
        lastName,
        role: 'TEACHER'
      }
    });

    // Assign classes
    if (classIds.length > 0) {
      await tx.teacherClass.createMany({
        data: classIds.map(classId => ({
          userId: user.id,
          classId
        }))
      });
    }

    // Assign subjects
    if (subjectIds.length > 0) {
      await tx.teacherSubject.createMany({
        data: subjectIds.map(subjectId => ({
          userId: user.id,
          subjectId
        }))
      });
    }

    return user;
  });

  // Create audit log
  await prisma.auditLog.create({
    data: {
      schoolId: req.user.schoolId,
      userId: req.user.id,
      action: 'CREATE',
      entityType: 'USER',
      entityId: teacher.id,
      newValue: { email, firstName, lastName, role: 'TEACHER' }
    }
  });

  res.status(201).json({
    success: true,
    message: 'Teacher added successfully',
    data: {
      id: teacher.id,
      email: teacher.email,
      firstName: teacher.firstName,
      lastName: teacher.lastName,
      role: teacher.role
    }
  });
}));

/**
 * @route   GET /api/v1/users/:id
 * @desc    Get user by ID
 * @access  Private
 */
router.get('/:id', [
  param('id').isUUID()
], asyncHandler(async (req, res) => {
  const user = await prisma.user.findFirst({
    where: {
      id: req.params.id,
      schoolId: req.user.schoolId
    },
    select: {
      id: true,
      email: true,
      phone: true,
      firstName: true,
      lastName: true,
      role: true,
      profileImage: true,
      isActive: true,
      lastLogin: true,
      createdAt: true,
      teacherClasses: {
        include: {
          class: true
        }
      },
      teacherSubjects: {
        include: {
          subject: true
        }
      }
    }
  });

  if (!user) {
    throw new AppError('User not found', 404);
  }

  res.json({
    success: true,
    data: user
  });
}));

/**
 * @route   PUT /api/v1/users/:id
 * @desc    Update user
 * @access  Private (Principal only, or self)
 */
router.put('/:id', [
  param('id').isUUID(),
  body('firstName').optional().trim().isLength({ min: 2, max: 50 }),
  body('lastName').optional().trim().isLength({ min: 2, max: 50 }),
  body('phone').optional().matches(/^\+?[\d\s-]{10,15}$/),
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
  const { firstName, lastName, phone, isActive } = req.body;

  // Check permissions
  if (req.user.role !== 'PRINCIPAL' && req.user.id !== id) {
    throw new AppError('Insufficient permissions', 403);
  }

  // Only principal can change isActive
  if (isActive !== undefined && req.user.role !== 'PRINCIPAL') {
    throw new AppError('Only principal can activate/deactivate users', 403);
  }

  const user = await prisma.user.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!user) {
    throw new AppError('User not found', 404);
  }

  const updatedUser = await prisma.user.update({
    where: { id },
    data: {
      ...(firstName && { firstName }),
      ...(lastName && { lastName }),
      ...(phone && { phone }),
      ...(isActive !== undefined && { isActive })
    },
    select: {
      id: true,
      email: true,
      firstName: true,
      lastName: true,
      phone: true,
      role: true,
      isActive: true
    }
  });

  res.json({
    success: true,
    message: 'User updated successfully',
    data: updatedUser
  });
}));

/**
 * @route   PUT /api/v1/users/:id/assignments
 * @desc    Update teacher class and subject assignments
 * @access  Private (Principal only)
 */
router.put('/:id/assignments', requireRole('PRINCIPAL'), [
  param('id').isUUID(),
  body('classIds').optional().isArray(),
  body('subjectIds').optional().isArray()
], asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { classIds, subjectIds } = req.body;

  const user = await prisma.user.findFirst({
    where: { id, schoolId: req.user.schoolId, role: 'TEACHER' }
  });

  if (!user) {
    throw new AppError('Teacher not found', 404);
  }

  await prisma.$transaction(async (tx) => {
    // Update class assignments
    if (classIds !== undefined) {
      await tx.teacherClass.deleteMany({ where: { userId: id } });
      if (classIds.length > 0) {
        await tx.teacherClass.createMany({
          data: classIds.map(classId => ({ userId: id, classId }))
        });
      }
    }

    // Update subject assignments
    if (subjectIds !== undefined) {
      await tx.teacherSubject.deleteMany({ where: { userId: id } });
      if (subjectIds.length > 0) {
        await tx.teacherSubject.createMany({
          data: subjectIds.map(subjectId => ({ userId: id, subjectId }))
        });
      }
    }
  });

  res.json({
    success: true,
    message: 'Assignments updated successfully'
  });
}));

/**
 * @route   DELETE /api/v1/users/:id
 * @desc    Deactivate user (soft delete)
 * @access  Private (Principal only)
 */
router.delete('/:id', requireRole('PRINCIPAL'), [
  param('id').isUUID()
], asyncHandler(async (req, res) => {
  const { id } = req.params;

  if (id === req.user.id) {
    throw new AppError('Cannot deactivate your own account', 400);
  }

  const user = await prisma.user.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!user) {
    throw new AppError('User not found', 404);
  }

  await prisma.user.update({
    where: { id },
    data: { isActive: false }
  });

  res.json({
    success: true,
    message: 'User deactivated successfully'
  });
}));

/**
 * @route   GET /api/v1/users/me
 * @desc    Get current user profile
 * @access  Private
 */
router.get('/profile/me', asyncHandler(async (req, res) => {
  const user = await prisma.user.findUnique({
    where: { id: req.user.id },
    select: {
      id: true,
      email: true,
      phone: true,
      firstName: true,
      lastName: true,
      role: true,
      profileImage: true,
      lastLogin: true,
      createdAt: true,
      school: {
        select: {
          id: true,
          name: true,
          logo: true
        }
      },
      teacherClasses: {
        include: { class: true }
      },
      teacherSubjects: {
        include: { subject: true }
      }
    }
  });

  res.json({
    success: true,
    data: user
  });
}));

module.exports = router;

