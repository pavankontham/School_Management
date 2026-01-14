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
 * @desc    Get all subjects in school (optionally filtered by class)
 * @access  Private
 */
router.get('/', asyncHandler(async (req, res) => {
  const { isActive, classId } = req.query;

  let where = { schoolId: req.user.schoolId };

  // If classId is provided, filter subjects by class
  if (classId) {
    const classSubjects = await prisma.classSubject.findMany({
      where: { classId },
      select: { subjectId: true }
    });
    where.id = { in: classSubjects.map(cs => cs.subjectId) };
  }

  // For teachers, only show assigned subjects
  if (req.user.role === 'TEACHER') {
    const teacherSubjects = await prisma.teacherSubject.findMany({
      where: { userId: req.user.id },
      select: { subjectId: true }
    });
    const teacherSubjectIds = teacherSubjects.map(ts => ts.subjectId);

    // If already filtered by class, intersect with teacher's subjects
    if (where.id) {
      where.id = { in: where.id.in.filter(id => teacherSubjectIds.includes(id)) };
    } else {
      where.id = { in: teacherSubjectIds };
    }
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
      },
      classSubjects: classId ? {
        where: { classId },
        include: {
          class: {
            select: { id: true, name: true }
          }
        }
      } : false
    },
    orderBy: { name: 'asc' }
  });

  // Add classId to subjects if filtered by class
  const subjectsWithClass = subjects.map(subject => ({
    ...subject,
    classId: classId || null,
    className: subject.classSubjects?.[0]?.class?.name || null
  }));

  res.json({
    success: true,
    data: subjectsWithClass
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

  const { name, code, description, classId } = req.body;

  // If classId is provided, verify it belongs to the school
  if (classId) {
    const classRecord = await prisma.class.findFirst({
      where: { id: classId, schoolId: req.user.schoolId }
    });
    if (!classRecord) {
      throw new AppError('Class not found', 404);
    }
  }

  const subject = await prisma.$transaction(async (tx) => {
    // Create the subject
    const newSubject = await tx.subject.create({
      data: {
        schoolId: req.user.schoolId,
        name,
        code: code.toUpperCase(),
        description
      }
    });

    // If classId is provided, associate the subject with the class
    if (classId) {
      await tx.classSubject.create({
        data: {
          classId,
          subjectId: newSubject.id
        }
      });
    }

    return newSubject;
  });

  // Create audit log
  await prisma.auditLog.create({
    data: {
      schoolId: req.user.schoolId,
      userId: req.user.id,
      action: 'CREATE',
      entityType: 'SUBJECT',
      entityId: subject.id,
      newValue: { name, code, classId }
    }
  });

  res.status(201).json({
    success: true,
    message: 'Subject created successfully',
    data: { ...subject, classId }
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
 * @route   PUT /api/v1/subjects/:id/assign-teacher
 * @desc    Assign teacher to subject for specific class(es)
 * @access  Private (Principal only)
 */
router.put('/:id/assign-teacher', requireRole('PRINCIPAL'), [
  param('id').isUUID(),
  body('teacherId').optional().isUUID(),
  body('classId').optional().isUUID(),  // Optional: specific class
  body('classIds').optional().isArray() // Optional: multiple classes
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
  const { teacherId, classId, classIds } = req.body;

  // Verify subject exists
  const subject = await prisma.subject.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!subject) {
    throw new AppError('Subject not found', 404);
  }

  // If teacherId is provided, verify teacher exists
  if (teacherId) {
    const teacher = await prisma.user.findFirst({
      where: {
        id: teacherId,
        schoolId: req.user.schoolId,
        role: { in: ['TEACHER', 'PRINCIPAL'] }
      }
    });

    if (!teacher) {
      throw new AppError('Teacher not found', 404);
    }
  }

  // Determine which classes to update
  let targetClassIds = [];

  if (classId) {
    // Single class assignment
    targetClassIds = [classId];
  } else if (classIds && classIds.length > 0) {
    // Multiple classes assignment
    targetClassIds = classIds;
  } else {
    // No specific class - assign to all classes that have this subject
    const classSubjects = await prisma.classSubject.findMany({
      where: { subjectId: id },
      select: { classId: true }
    });
    targetClassIds = classSubjects.map(cs => cs.classId);
  }

  // Update class-subject associations
  const updatePromises = targetClassIds.map(cId =>
    prisma.classSubject.updateMany({
      where: {
        subjectId: id,
        classId: cId
      },
      data: { teacherId: teacherId || null }
    })
  );

  await Promise.all(updatePromises);

  // Also update TeacherSubject for backward compatibility
  if (teacherId) {
    // Remove existing assignment
    await prisma.teacherSubject.deleteMany({
      where: { subjectId: id }
    });

    // Add new assignment
    await prisma.teacherSubject.create({
      data: {
        userId: teacherId,
        subjectId: id
      }
    });
  } else {
    // Remove all assignments
    await prisma.teacherSubject.deleteMany({
      where: { subjectId: id }
    });
  }

  res.json({
    success: true,
    message: `Teacher assigned to ${targetClassIds.length} class(es) successfully`,
    data: {
      subjectId: id,
      teacherId,
      classesUpdated: targetClassIds.length
    }
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

