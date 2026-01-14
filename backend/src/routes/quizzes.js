const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { body, param, query, validationResult } = require('express-validator');

const { asyncHandler, AppError } = require('../middleware/errorHandler');
const { requireRole } = require('../middleware/auth');

const router = express.Router();
const prisma = new PrismaClient();

/**
 * @route   GET /api/v1/quizzes
 * @desc    Get all quizzes
 * @access  Private
 */
router.get('/', asyncHandler(async (req, res) => {
  const { subjectId, classId, page = 1, limit = 20 } = req.query;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  let where = { schoolId: req.user.schoolId };

  if (subjectId) where.subjectId = subjectId;
  if (classId) where.classId = classId;

  // For teachers, only show their quizzes
  if (req.user.role === 'TEACHER') {
    where.teacherId = req.user.id;
  }

  const [quizzes, total] = await Promise.all([
    prisma.quiz.findMany({
      where,
      include: {
        subject: {
          select: { id: true, name: true, code: true }
        },
        class: {
          select: { id: true, name: true, section: true, grade: true }
        },
        questions: {
          select: { id: true, points: true }
        },
        _count: {
          select: { attempts: true }
        }
      },
      skip,
      take: parseInt(limit),
      orderBy: { createdAt: 'desc' }
    }),
    prisma.quiz.count({ where })
  ]);

  res.json({
    success: true,
    data: quizzes.map(q => ({
      ...q,
      totalQuestions: q.questions?.length || 0,
      totalMarks: q.questions?.reduce((sum, qu) => sum + (qu.points || 1), 0) || 0,
      duration: q.timeLimit,
      subjectName: q.subject?.name,
      className: q.class?.name,
      attemptCount: q._count.attempts
    }))
  });
}));

/**
 * @route   GET /api/v1/quizzes/:id
 * @desc    Get quiz by ID
 * @access  Private
 */
router.get('/:id', [param('id').isUUID()], asyncHandler(async (req, res) => {
  const quiz = await prisma.quiz.findFirst({
    where: {
      id: req.params.id,
      schoolId: req.user.schoolId
    },
    include: {
      subject: true,
      class: true,
      creator: {
        select: { id: true, firstName: true, lastName: true }
      }
    }
  });

  if (!quiz) {
    throw new AppError('Quiz not found', 404);
  }

  res.json({
    success: true,
    data: quiz
  });
}));

/**
 * @route   POST /api/v1/quizzes
 * @desc    Create a new quiz
 * @access  Private (Teacher/Principal)
 */
router.post('/', requireRole(['TEACHER', 'PRINCIPAL']), [
  body('title').trim().isLength({ min: 3, max: 200 }),
  body('description').optional().trim(),
  body('subjectId').isUUID(),
  body('classId').isUUID(),
  body('timeLimit').isInt({ min: 1 }),
  body('questions').isArray({ min: 1 }),
  body('maxAttempts').optional().isInt({ min: 1 }),
  body('randomizeQuestions').optional().isBoolean(),
  body('randomizeOptions').optional().isBoolean(),
  body('showResults').optional().isBoolean(),
  body('passingScore').optional().isFloat({ min: 0, max: 100 }),
  body('startTime').optional().isISO8601(),
  body('endTime').optional().isISO8601()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const {
    title,
    description,
    subjectId,
    classId,
    timeLimit,
    questions,
    maxAttempts,
    randomizeQuestions,
    randomizeOptions,
    showResults,
    passingScore,
    startTime,
    endTime
  } = req.body;

  // Verify subject and class belong to school
  const [subject, classRecord] = await Promise.all([
    prisma.subject.findFirst({
      where: { id: subjectId, schoolId: req.user.schoolId }
    }),
    prisma.class.findFirst({
      where: { id: classId, schoolId: req.user.schoolId }
    })
  ]);

  if (!subject) throw new AppError('Subject not found', 404);
  if (!classRecord) throw new AppError('Class not found', 404);

  const quiz = await prisma.quiz.create({
    data: {
      schoolId: req.user.schoolId,
      teacherId: req.user.id,
      title,
      description,
      subjectId,
      classId,
      timeLimit,
      maxAttempts: maxAttempts || 1,
      randomizeQuestions: randomizeQuestions || false,
      randomizeOptions: randomizeOptions || false,
      showResults: showResults !== false,
      passingScore: passingScore || 40,
      startTime: startTime ? new Date(startTime) : null,
      endTime: endTime ? new Date(endTime) : null,
      isActive: true,
      questions: {
        create: questions.map((q, index) => ({
          questionText: q.question,
          questionType: q.type || 'MCQ',  // Use provided type or default to MCQ
          options: q.options,
          correctAnswer: q.correctAnswer,
          points: q.marks || 1,
          orderIndex: index
        }))
      }
    },
    include: {
      subject: true,
      class: true,
      questions: true
    }
  });

  res.status(201).json({
    success: true,
    message: 'Quiz created successfully',
    data: quiz
  });
}));

/**
 * @route   PUT /api/v1/quizzes/:id
 * @desc    Update quiz
 * @access  Private (Teacher/Principal)
 */
router.put('/:id', requireRole(['TEACHER', 'PRINCIPAL']), [
  param('id').isUUID(),
  body('title').optional().trim().isLength({ min: 3, max: 200 }),
  body('description').optional().trim(),
  body('isActive').optional().isBoolean()
], asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { title, description, isActive } = req.body;

  const quiz = await prisma.quiz.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!quiz) throw new AppError('Quiz not found', 404);

  const updated = await prisma.quiz.update({
    where: { id },
    data: {
      ...(title && { title }),
      ...(description !== undefined && { description }),
      ...(isActive !== undefined && { isActive })
    }
  });

  res.json({
    success: true,
    message: 'Quiz updated successfully',
    data: updated
  });
}));

/**
 * @route   GET /api/v1/quizzes/:id/results
 * @desc    Get quiz results/attempts
 * @access  Private (Teacher/Principal)
 */
router.get('/:id/results', requireRole(['TEACHER', 'PRINCIPAL']), [
  param('id').isUUID()
], asyncHandler(async (req, res) => {
  const attempts = await prisma.quizAttempt.findMany({
    where: {
      quizId: req.params.id,
      quiz: { schoolId: req.user.schoolId }
    },
    include: {
      student: {
        select: {
          id: true,
          firstName: true,
          lastName: true,
          rollNumber: true
        }
      }
    },
    orderBy: { submittedAt: 'desc' }
  });

  res.json({
    success: true,
    data: attempts
  });
}));

/**
 * @route   DELETE /api/v1/quizzes/:id
 * @desc    Delete quiz
 * @access  Private (Teacher/Principal)
 */
router.delete('/:id', requireRole(['TEACHER', 'PRINCIPAL']), [
  param('id').isUUID()
], asyncHandler(async (req, res) => {
  const { id } = req.params;

  const quiz = await prisma.quiz.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!quiz) throw new AppError('Quiz not found', 404);

  await prisma.quiz.delete({ where: { id } });

  res.json({
    success: true,
    message: 'Quiz deleted successfully'
  });
}));

module.exports = router;
