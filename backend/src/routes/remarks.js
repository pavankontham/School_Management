const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { body, param, query, validationResult } = require('express-validator');

const { asyncHandler, AppError } = require('../middleware/errorHandler');

const router = express.Router();
const prisma = new PrismaClient();

/**
 * @route   GET /api/v1/remarks
 * @desc    Get remarks
 * @access  Private
 */
router.get('/', [
  query('studentId').optional().isUUID(),
  query('type').optional().isIn(['POSITIVE', 'NEGATIVE', 'NEUTRAL', 'IMPROVEMENT'])
], asyncHandler(async (req, res) => {
  const { studentId, type, page = 1, limit = 50 } = req.query;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  let where = { schoolId: req.user.schoolId };

  if (studentId) where.studentId = studentId;
  if (type) where.type = type;

  const [remarks, total] = await Promise.all([
    prisma.remark.findMany({
      where,
      include: {
        student: {
          select: {
            id: true,
            rollNumber: true,
            firstName: true,
            lastName: true,
            class: { select: { id: true, name: true, section: true } }
          }
        },
        teacher: {
          select: { id: true, firstName: true, lastName: true }
        }
      },
      skip,
      take: parseInt(limit),
      orderBy: { createdAt: 'desc' }
    }),
    prisma.remark.count({ where })
  ]);

  res.json({
    success: true,
    data: {
      remarks,
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
 * @route   POST /api/v1/remarks
 * @desc    Add a remark for a student
 * @access  Private
 */
router.post('/', [
  body('studentId').isUUID(),
  body('type').isIn(['POSITIVE', 'NEGATIVE', 'NEUTRAL', 'IMPROVEMENT']),
  body('title').trim().isLength({ min: 3, max: 200 }),
  body('description').trim().isLength({ min: 10, max: 2000 })
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const { studentId, type, title, description } = req.body;

  // Verify student belongs to school
  const student = await prisma.student.findFirst({
    where: { id: studentId, schoolId: req.user.schoolId }
  });

  if (!student) {
    throw new AppError('Student not found', 404);
  }

  const remark = await prisma.remark.create({
    data: {
      schoolId: req.user.schoolId,
      studentId,
      teacherId: req.user.id,
      type,
      title,
      description
    },
    include: {
      student: {
        select: { id: true, rollNumber: true, firstName: true, lastName: true }
      },
      teacher: {
        select: { id: true, firstName: true, lastName: true }
      }
    }
  });

  res.status(201).json({
    success: true,
    message: 'Remark added successfully',
    data: remark
  });
}));

/**
 * @route   GET /api/v1/remarks/:id
 * @desc    Get remark by ID
 * @access  Private
 */
router.get('/:id', [param('id').isUUID()], asyncHandler(async (req, res) => {
  const remark = await prisma.remark.findFirst({
    where: {
      id: req.params.id,
      schoolId: req.user.schoolId
    },
    include: {
      student: {
        select: {
          id: true,
          rollNumber: true,
          firstName: true,
          lastName: true,
          class: true
        }
      },
      teacher: {
        select: { id: true, firstName: true, lastName: true }
      }
    }
  });

  if (!remark) {
    throw new AppError('Remark not found', 404);
  }

  res.json({
    success: true,
    data: remark
  });
}));

/**
 * @route   PUT /api/v1/remarks/:id
 * @desc    Update remark
 * @access  Private
 */
router.put('/:id', [
  param('id').isUUID(),
  body('type').optional().isIn(['POSITIVE', 'NEGATIVE', 'NEUTRAL', 'IMPROVEMENT']),
  body('title').optional().trim().isLength({ min: 3, max: 200 }),
  body('description').optional().trim().isLength({ min: 10, max: 2000 })
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
  const { type, title, description } = req.body;

  const remark = await prisma.remark.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!remark) {
    throw new AppError('Remark not found', 404);
  }

  // Only the teacher who created or principal can update
  if (req.user.role !== 'PRINCIPAL' && remark.teacherId !== req.user.id) {
    throw new AppError('Insufficient permissions', 403);
  }

  const updated = await prisma.remark.update({
    where: { id },
    data: {
      ...(type && { type }),
      ...(title && { title }),
      ...(description && { description })
    }
  });

  res.json({
    success: true,
    message: 'Remark updated successfully',
    data: updated
  });
}));

/**
 * @route   DELETE /api/v1/remarks/:id
 * @desc    Delete remark
 * @access  Private
 */
router.delete('/:id', [param('id').isUUID()], asyncHandler(async (req, res) => {
  const { id } = req.params;

  const remark = await prisma.remark.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!remark) {
    throw new AppError('Remark not found', 404);
  }

  // Only the teacher who created or principal can delete
  if (req.user.role !== 'PRINCIPAL' && remark.teacherId !== req.user.id) {
    throw new AppError('Insufficient permissions', 403);
  }

  await prisma.remark.delete({ where: { id } });

  res.json({
    success: true,
    message: 'Remark deleted successfully'
  });
}));

/**
 * @route   GET /api/v1/remarks/student/:studentId
 * @desc    Get all remarks for a student
 * @access  Private
 */
router.get('/student/:studentId', [
  param('studentId').isUUID()
], asyncHandler(async (req, res) => {
  const { studentId } = req.params;

  const student = await prisma.student.findFirst({
    where: { id: studentId, schoolId: req.user.schoolId }
  });

  if (!student) {
    throw new AppError('Student not found', 404);
  }

  const remarks = await prisma.remark.findMany({
    where: { studentId, schoolId: req.user.schoolId },
    include: {
      teacher: {
        select: { id: true, firstName: true, lastName: true }
      }
    },
    orderBy: { createdAt: 'desc' }
  });

  // Group by type
  const grouped = {
    positive: remarks.filter(r => r.type === 'POSITIVE'),
    negative: remarks.filter(r => r.type === 'NEGATIVE'),
    neutral: remarks.filter(r => r.type === 'NEUTRAL'),
    improvement: remarks.filter(r => r.type === 'IMPROVEMENT')
  };

  res.json({
    success: true,
    data: {
      student: {
        id: student.id,
        rollNumber: student.rollNumber,
        name: `${student.firstName} ${student.lastName}`
      },
      remarks,
      grouped,
      summary: {
        total: remarks.length,
        positive: grouped.positive.length,
        negative: grouped.negative.length,
        neutral: grouped.neutral.length,
        improvement: grouped.improvement.length
      }
    }
  });
}));

module.exports = router;

