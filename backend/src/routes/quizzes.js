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
router.get('/', [
  query('classId').optional().isUUID(),
  query('subjectId').optional().isUUID()
], asyncHandler(async (req, res) => {
  const { classId, subjectId, isActive, page = 1, limit = 20 } = req.query;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  let where = { schoolId: req.user.schoolId };

  // For teachers, filter by their classes
  if (req.user.role === 'TEACHER') {
    const teacherClasses = await prisma.teacherClass.findMany({
      where: { userId: req.user.id },
      select: { classId: true }
    });
    where.classId = { in: teacherClasses.map(tc => tc.classId) };
  }

  if (classId) where.classId = classId;
  if (subjectId) where.subjectId = subjectId;
  if (isActive !== undefined) where.isActive = isActive === 'true';

  const [quizzes, total] = await Promise.all([
    prisma.quiz.findMany({
      where,
      include: {
        class: { select: { id: true, name: true, section: true, grade: true } },
        subject: { select: { id: true, name: true, code: true } },
        teacher: { select: { id: true, firstName: true, lastName: true } },
        _count: { select: { questions: true, attempts: true } }
      },
      skip,
      take: parseInt(limit),
      orderBy: { createdAt: 'desc' }
    }),
    prisma.quiz.count({ where })
  ]);

  res.json({
    success: true,
    data: {
      quizzes,
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
 * @route   POST /api/v1/quizzes
 * @desc    Create a new quiz
 * @access  Private
 */
router.post('/', [
  body('title').trim().isLength({ min: 3, max: 200 }),
  body('classId').isUUID(),
  body('subjectId').isUUID(),
  body('description').optional().trim(),
  body('timeLimit').optional().isInt({ min: 1, max: 300 }),
  body('maxAttempts').optional().isInt({ min: 1, max: 10 }),
  body('randomizeQuestions').optional().isBoolean(),
  body('randomizeOptions').optional().isBoolean(),
  body('showResults').optional().isBoolean(),
  body('passingScore').optional().isFloat({ min: 0, max: 100 }),
  body('startTime').optional().isISO8601(),
  body('endTime').optional().isISO8601(),
  body('questions').optional().isArray()
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
    title, classId, subjectId, description, timeLimit, maxAttempts,
    randomizeQuestions, randomizeOptions, showResults, passingScore,
    startTime, endTime, questions = [], isAIGenerated = false
  } = req.body;

  // Verify class and subject belong to school
  const [classRecord, subject] = await Promise.all([
    prisma.class.findFirst({ where: { id: classId, schoolId: req.user.schoolId } }),
    prisma.subject.findFirst({ where: { id: subjectId, schoolId: req.user.schoolId } })
  ]);

  if (!classRecord) throw new AppError('Class not found', 404);
  if (!subject) throw new AppError('Subject not found', 404);

  const quiz = await prisma.$transaction(async (tx) => {
    const newQuiz = await tx.quiz.create({
      data: {
        schoolId: req.user.schoolId,
        classId,
        subjectId,
        teacherId: req.user.id,
        title,
        description,
        timeLimit,
        maxAttempts: maxAttempts || 1,
        randomizeQuestions: randomizeQuestions || false,
        randomizeOptions: randomizeOptions || false,
        showResults: showResults !== false,
        passingScore,
        startTime: startTime ? new Date(startTime) : null,
        endTime: endTime ? new Date(endTime) : null,
        isAIGenerated
      }
    });

    // Add questions if provided
    if (questions.length > 0) {
      await tx.quizQuestion.createMany({
        data: questions.map((q, index) => ({
          quizId: newQuiz.id,
          questionText: q.questionText,
          questionType: q.questionType || 'MCQ',
          options: q.options,
          correctAnswer: q.correctAnswer,
          explanation: q.explanation,
          points: q.points || 1,
          orderIndex: index + 1
        }))
      });
    }

    return newQuiz;
  });

  const createdQuiz = await prisma.quiz.findUnique({
    where: { id: quiz.id },
    include: {
      questions: { orderBy: { orderIndex: 'asc' } },
      class: { select: { id: true, name: true, section: true } },
      subject: { select: { id: true, name: true, code: true } }
    }
  });

  res.status(201).json({
    success: true,
    message: 'Quiz created successfully',
    data: createdQuiz
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
      questions: { orderBy: { orderIndex: 'asc' } },
      class: true,
      subject: true,
      teacher: { select: { id: true, firstName: true, lastName: true } },
      _count: { select: { attempts: true } }
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
 * @route   PUT /api/v1/quizzes/:id
 * @desc    Update quiz
 * @access  Private
 */
router.put('/:id', [
  param('id').isUUID(),
  body('title').optional().trim().isLength({ min: 3, max: 200 }),
  body('timeLimit').optional().isInt({ min: 1, max: 300 }),
  body('isActive').optional().isBoolean()
], asyncHandler(async (req, res) => {
  const { id } = req.params;

  const quiz = await prisma.quiz.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!quiz) {
    throw new AppError('Quiz not found', 404);
  }

  // Only creator or principal can update
  if (req.user.role !== 'PRINCIPAL' && quiz.teacherId !== req.user.id) {
    throw new AppError('Insufficient permissions', 403);
  }

  const updated = await prisma.quiz.update({
    where: { id },
    data: req.body
  });

  res.json({
    success: true,
    message: 'Quiz updated successfully',
    data: updated
  });
}));

/**
 * @route   POST /api/v1/quizzes/:id/questions
 * @desc    Add questions to quiz
 * @access  Private
 */
router.post('/:id/questions', [
  param('id').isUUID(),
  body('questions').isArray({ min: 1 }),
  body('questions.*.questionText').notEmpty(),
  body('questions.*.questionType').isIn(['MCQ', 'TRUE_FALSE', 'SHORT_ANSWER', 'FILL_BLANK']),
  body('questions.*.correctAnswer').notEmpty()
], asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { questions } = req.body;

  const quiz = await prisma.quiz.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!quiz) {
    throw new AppError('Quiz not found', 404);
  }

  // Get current max order index
  const lastQuestion = await prisma.quizQuestion.findFirst({
    where: { quizId: id },
    orderBy: { orderIndex: 'desc' }
  });

  const startIndex = (lastQuestion?.orderIndex || 0) + 1;

  await prisma.quizQuestion.createMany({
    data: questions.map((q, index) => ({
      quizId: id,
      questionText: q.questionText,
      questionType: q.questionType,
      options: q.options,
      correctAnswer: q.correctAnswer,
      explanation: q.explanation,
      points: q.points || 1,
      orderIndex: startIndex + index
    }))
  });

  res.status(201).json({
    success: true,
    message: 'Questions added successfully'
  });
}));

/**
 * @route   DELETE /api/v1/quizzes/:id
 * @desc    Delete quiz
 * @access  Private
 */
router.delete('/:id', [param('id').isUUID()], asyncHandler(async (req, res) => {
  const { id } = req.params;

  const quiz = await prisma.quiz.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!quiz) {
    throw new AppError('Quiz not found', 404);
  }

  if (req.user.role !== 'PRINCIPAL' && quiz.teacherId !== req.user.id) {
    throw new AppError('Insufficient permissions', 403);
  }

  await prisma.quiz.delete({ where: { id } });

  res.json({
    success: true,
    message: 'Quiz deleted successfully'
  });
}));

/**
 * @route   GET /api/v1/quizzes/:id/results
 * @desc    Get quiz results/analytics
 * @access  Private
 */
router.get('/:id/results', [param('id').isUUID()], asyncHandler(async (req, res) => {
  const { id } = req.params;

  const quiz = await prisma.quiz.findFirst({
    where: { id, schoolId: req.user.schoolId },
    include: { _count: { select: { questions: true } } }
  });

  if (!quiz) {
    throw new AppError('Quiz not found', 404);
  }

  const attempts = await prisma.quizAttempt.findMany({
    where: { quizId: id },
    include: {
      student: {
        select: { id: true, rollNumber: true, firstName: true, lastName: true }
      }
    },
    orderBy: { submittedAt: 'desc' }
  });

  const completedAttempts = attempts.filter(a => a.submittedAt);
  const scores = completedAttempts.map(a => a.percentage || 0);

  res.json({
    success: true,
    data: {
      quiz: {
        id: quiz.id,
        title: quiz.title,
        totalQuestions: quiz._count.questions
      },
      stats: {
        totalAttempts: attempts.length,
        completedAttempts: completedAttempts.length,
        averageScore: scores.length > 0 ? scores.reduce((a, b) => a + b, 0) / scores.length : 0,
        highestScore: scores.length > 0 ? Math.max(...scores) : 0,
        lowestScore: scores.length > 0 ? Math.min(...scores) : 0,
        passRate: quiz.passingScore && completedAttempts.length > 0
          ? (completedAttempts.filter(a => a.isPassed).length / completedAttempts.length) * 100
          : null
      },
      attempts
    }
  });
}));

module.exports = router;

