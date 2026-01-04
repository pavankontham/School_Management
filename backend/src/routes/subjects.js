const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { body, param, validationResult } = require('express-validator');

const { asyncHandler, AppError } = require('../middleware/errorHandler');
const { requireRole } = require('../middleware/auth');
const validators = require('../utils/validators');

const router = express.Router();
const prisma = new PrismaClient();

/**
 * @route   GET /api/v1/subjects
 * @desc    Get all subjects in school
 * @access  Private
 */
router.get('/', asyncHandler(async (req, res) => {
  const { isActive } = req.query;

  let where = { schoolId: req.user.schoolId };

  // For teachers, only show assigned subjects
  if (req.user.role === 'TEACHER') {
    const teacherSubjects = await prisma.teacherSubject.findMany({
      where: { userId: req.user.id },
      select: { subjectId: true }
    });
    where.id = { in: teacherSubjects.map(ts => ts.subjectId) };
  }

  if (isActive !== undefined) where.isActive = isActive === 'true';

  const subjects = await prisma.subject.findMany({
    where,
    include: {
      _count: {
        select: {
          textbooks: true,
          marks: true
        }
      }
    },
    orderBy: { name: 'asc' }
  });

  res.json({
    success: true,
    data: subjects
  });
}));

/**
 * @route   POST /api/v1/subjects
 * @desc    Create a new subject
 * @access  Private (Principal only)
 */
router.post('/', requireRole('PRINCIPAL'), validators.subjectCreate, asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const { name, code, description } = req.body;

  const subject = await prisma.subject.create({
    data: {
      schoolId: req.user.schoolId,
      name,
      code: code.toUpperCase(),
      description
    }
  });

  // Create audit log
  await prisma.auditLog.create({
    data: {
      schoolId: req.user.schoolId,
      userId: req.user.id,
      action: 'CREATE',
      entityType: 'SUBJECT',
      entityId: subject.id,
      newValue: { name, code }
    }
  });

  res.status(201).json({
    success: true,
    message: 'Subject created successfully',
    data: subject
  });
}));

/**
 * @route   GET /api/v1/subjects/:id
 * @desc    Get subject by ID
 * @access  Private
 */
router.get('/:id', [param('id').isUUID()], asyncHandler(async (req, res) => {
  const subject = await prisma.subject.findFirst({
    where: {
      id: req.params.id,
      schoolId: req.user.schoolId
    },
    include: {
      textbooks: {
        where: { isActive: true },
        select: {
          id: true,
          title: true,
          author: true,
          grade: true
        }
      },
      classSubjects: {
        include: {
          class: {
            select: { id: true, name: true, section: true, grade: true }
          }
        }
      }
    }
  });

  if (!subject) {
    throw new AppError('Subject not found', 404);
  }

  res.json({
    success: true,
    data: subject
  });
}));

/**
 * @route   PUT /api/v1/subjects/:id
 * @desc    Update subject
 * @access  Private (Principal only)
 */
router.put('/:id', requireRole('PRINCIPAL'), [
  param('id').isUUID(),
  body('name').optional().trim().isLength({ min: 2, max: 100 }),
  body('code').optional().trim().isLength({ min: 2, max: 20 }),
  body('description').optional().trim(),
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
  const { name, code, description, isActive } = req.body;

  const subject = await prisma.subject.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!subject) {
    throw new AppError('Subject not found', 404);
  }

  const updatedSubject = await prisma.subject.update({
    where: { id },
    data: {
      ...(name && { name }),
      ...(code && { code: code.toUpperCase() }),
      ...(description !== undefined && { description }),
      ...(isActive !== undefined && { isActive })
    }
  });

  res.json({
    success: true,
    message: 'Subject updated successfully',
    data: updatedSubject
  });
}));

/**
 * @route   DELETE /api/v1/subjects/:id
 * @desc    Deactivate subject
 * @access  Private (Principal only)
 */
router.delete('/:id', requireRole('PRINCIPAL'), [
  param('id').isUUID()
], asyncHandler(async (req, res) => {
  const { id } = req.params;

  const subject = await prisma.subject.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!subject) {
    throw new AppError('Subject not found', 404);
  }

  await prisma.subject.update({
    where: { id },
    data: { isActive: false }
  });

  res.json({
    success: true,
    message: 'Subject deactivated successfully'
  });
}));

module.exports = router;

