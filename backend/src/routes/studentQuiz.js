const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { body, param, validationResult } = require('express-validator');

const { asyncHandler, AppError } = require('../middleware/errorHandler');

const router = express.Router();
const prisma = new PrismaClient();

/**
 * @route   GET /api/v1/student/quizzes
 * @desc    Get available quizzes for student
 * @access  Private (Student)
 */
router.get('/quizzes', asyncHandler(async (req, res) => {
  const student = req.student;
  const now = new Date();

  const quizzes = await prisma.quiz.findMany({
    where: {
      schoolId: student.schoolId,
      classId: student.classId,
      isActive: true,
      OR: [
        { startTime: null },
        { startTime: { lte: now } }
      ],
      AND: [
        {
          OR: [
            { endTime: null },
            { endTime: { gte: now } }
          ]
        }
      ]
    },
    include: {
      subject: { select: { id: true, name: true, code: true } },
      teacher: { select: { id: true, firstName: true, lastName: true } },
      _count: { select: { questions: true } },
      attempts: {
        where: { studentId: student.id },
        select: { id: true, score: true, percentage: true, submittedAt: true }
      }
    },
    orderBy: { createdAt: 'desc' }
  });

  // Filter quizzes based on max attempts
  const availableQuizzes = quizzes.map(quiz => {
    const attemptCount = quiz.attempts.length;
    const completedAttempts = quiz.attempts.filter(a => a.submittedAt);
    const canAttempt = attemptCount < quiz.maxAttempts;
    const hasInProgress = quiz.attempts.some(a => !a.submittedAt);

    return {
      id: quiz.id,
      title: quiz.title,
      description: quiz.description,
      subject: quiz.subject,
      teacher: quiz.teacher,
      questionCount: quiz._count.questions,
      timeLimit: quiz.timeLimit,
      maxAttempts: quiz.maxAttempts,
      attemptCount,
      canAttempt,
      hasInProgress,
      bestScore: completedAttempts.length > 0 
        ? Math.max(...completedAttempts.map(a => a.percentage || 0))
        : null,
      showResults: quiz.showResults,
      passingScore: quiz.passingScore,
      startTime: quiz.startTime,
      endTime: quiz.endTime
    };
  });

  res.json({
    success: true,
    data: availableQuizzes
  });
}));

/**
 * @route   GET /api/v1/student/quizzes/:id
 * @desc    Get quiz details for attempt
 * @access  Private (Student)
 */
router.get('/quizzes/:id', [param('id').isUUID()], asyncHandler(async (req, res) => {
  const student = req.student;
  const { id } = req.params;

  const quiz = await prisma.quiz.findFirst({
    where: {
      id,
      schoolId: student.schoolId,
      classId: student.classId,
      isActive: true
    },
    include: {
      subject: true,
      teacher: { select: { id: true, firstName: true, lastName: true } },
      questions: {
        orderBy: { orderIndex: 'asc' },
        select: {
          id: true,
          questionText: true,
          questionType: true,
          options: true,
          points: true,
          orderIndex: true
          // Note: correctAnswer and explanation are NOT included
        }
      },
      attempts: {
        where: { studentId: student.id }
      }
    }
  });

  if (!quiz) {
    throw new AppError('Quiz not found', 404);
  }

  // Check if can attempt
  const attemptCount = quiz.attempts.length;
  if (attemptCount >= quiz.maxAttempts) {
    throw new AppError('Maximum attempts reached for this quiz', 400);
  }

  // Randomize questions if enabled
  let questions = quiz.questions;
  if (quiz.randomizeQuestions) {
    questions = [...questions].sort(() => Math.random() - 0.5);
  }

  // Randomize options if enabled
  if (quiz.randomizeOptions) {
    questions = questions.map(q => {
      if (q.options && Array.isArray(q.options)) {
        return {
          ...q,
          options: [...q.options].sort(() => Math.random() - 0.5)
        };
      }
      return q;
    });
  }

  res.json({
    success: true,
    data: {
      id: quiz.id,
      title: quiz.title,
      description: quiz.description,
      subject: quiz.subject,
      timeLimit: quiz.timeLimit,
      questionCount: questions.length,
      questions,
      attemptNumber: attemptCount + 1,
      maxAttempts: quiz.maxAttempts
    }
  });
}));

/**
 * @route   POST /api/v1/student/quizzes/:id/start
 * @desc    Start a quiz attempt
 * @access  Private (Student)
 */
router.post('/quizzes/:id/start', [param('id').isUUID()], asyncHandler(async (req, res) => {
  const student = req.student;
  const { id } = req.params;

  const quiz = await prisma.quiz.findFirst({
    where: {
      id,
      schoolId: student.schoolId,
      classId: student.classId,
      isActive: true
    },
    include: {
      attempts: { where: { studentId: student.id } }
    }
  });

  if (!quiz) {
    throw new AppError('Quiz not found', 404);
  }

  // Check for existing in-progress attempt
  const inProgressAttempt = quiz.attempts.find(a => !a.submittedAt);
  if (inProgressAttempt) {
    return res.json({
      success: true,
      message: 'Resuming existing attempt',
      data: {
        attemptId: inProgressAttempt.id,
        startedAt: inProgressAttempt.startedAt,
        timeRemaining: quiz.timeLimit 
          ? Math.max(0, quiz.timeLimit * 60 - Math.floor((Date.now() - inProgressAttempt.startedAt.getTime()) / 1000))
          : null
      }
    });
  }

  // Check max attempts
  if (quiz.attempts.length >= quiz.maxAttempts) {
    throw new AppError('Maximum attempts reached', 400);
  }

  // Create new attempt
  const attempt = await prisma.quizAttempt.create({
    data: {
      quizId: id,
      studentId: student.id,
      startedAt: new Date()
    }
  });

  res.status(201).json({
    success: true,
    message: 'Quiz attempt started',
    data: {
      attemptId: attempt.id,
      startedAt: attempt.startedAt,
      timeLimit: quiz.timeLimit
    }
  });
}));

/**
 * @route   POST /api/v1/student/quizzes/attempt/:attemptId/submit
 * @desc    Submit quiz answers
 * @access  Private (Student)
 */
router.post('/quizzes/attempt/:attemptId/submit', [
  param('attemptId').isUUID(),
  body('answers').isObject()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const student = req.student;
  const { attemptId } = req.params;
  const { answers } = req.body; // { questionId: answer }

  // Get attempt with quiz and questions
  const attempt = await prisma.quizAttempt.findFirst({
    where: {
      id: attemptId,
      studentId: student.id,
      submittedAt: null
    },
    include: {
      quiz: {
        include: {
          questions: true
        }
      }
    }
  });

  if (!attempt) {
    throw new AppError('Attempt not found or already submitted', 404);
  }

  // Check time limit
  if (attempt.quiz.timeLimit) {
    const elapsedSeconds = Math.floor((Date.now() - attempt.startedAt.getTime()) / 1000);
    const allowedSeconds = attempt.quiz.timeLimit * 60 + 60; // 1 minute grace period
    
    if (elapsedSeconds > allowedSeconds) {
      throw new AppError('Time limit exceeded', 400);
    }
  }

  // Calculate score
  let totalPoints = 0;
  let earnedPoints = 0;
  const questionResults = [];

  for (const question of attempt.quiz.questions) {
    totalPoints += question.points;
    const studentAnswer = answers[question.id];
    const isCorrect = studentAnswer === question.correctAnswer;

    if (isCorrect) {
      earnedPoints += question.points;
    }

    questionResults.push({
      questionId: question.id,
      studentAnswer,
      correctAnswer: question.correctAnswer,
      isCorrect,
      points: isCorrect ? question.points : 0
    });
  }

  const percentage = totalPoints > 0 ? (earnedPoints / totalPoints) * 100 : 0;
  const isPassed = attempt.quiz.passingScore ? percentage >= attempt.quiz.passingScore : null;

  // Update attempt
  const updatedAttempt = await prisma.quizAttempt.update({
    where: { id: attemptId },
    data: {
      answers,
      score: earnedPoints,
      totalPoints,
      percentage,
      isPassed,
      submittedAt: new Date()
    }
  });

  // Prepare response based on showResults setting
  const response = {
    success: true,
    message: 'Quiz submitted successfully',
    data: {
      attemptId: updatedAttempt.id,
      score: earnedPoints,
      totalPoints,
      percentage: Math.round(percentage * 100) / 100,
      isPassed
    }
  };

  if (attempt.quiz.showResults) {
    response.data.results = questionResults.map(r => ({
      questionId: r.questionId,
      isCorrect: r.isCorrect,
      points: r.points,
      correctAnswer: r.correctAnswer,
      studentAnswer: r.studentAnswer
    }));
  }

  res.json(response);
}));

/**
 * @route   GET /api/v1/student/quizzes/attempt/:attemptId/results
 * @desc    Get quiz attempt results
 * @access  Private (Student)
 */
router.get('/quizzes/attempt/:attemptId/results', [
  param('attemptId').isUUID()
], asyncHandler(async (req, res) => {
  const student = req.student;
  const { attemptId } = req.params;

  const attempt = await prisma.quizAttempt.findFirst({
    where: {
      id: attemptId,
      studentId: student.id,
      submittedAt: { not: null }
    },
    include: {
      quiz: {
        include: {
          questions: true,
          subject: { select: { id: true, name: true } }
        }
      }
    }
  });

  if (!attempt) {
    throw new AppError('Attempt not found or not yet submitted', 404);
  }

  if (!attempt.quiz.showResults) {
    return res.json({
      success: true,
      data: {
        quizTitle: attempt.quiz.title,
        subject: attempt.quiz.subject,
        score: attempt.score,
        totalPoints: attempt.totalPoints,
        percentage: attempt.percentage,
        isPassed: attempt.isPassed,
        submittedAt: attempt.submittedAt,
        resultsHidden: true,
        message: 'Detailed results are not available for this quiz'
      }
    });
  }

  // Build detailed results
  const answers = attempt.answers || {};
  const questionResults = attempt.quiz.questions.map(q => ({
    questionId: q.id,
    questionText: q.questionText,
    questionType: q.questionType,
    options: q.options,
    studentAnswer: answers[q.id],
    correctAnswer: q.correctAnswer,
    isCorrect: answers[q.id] === q.correctAnswer,
    explanation: q.explanation,
    points: q.points
  }));

  res.json({
    success: true,
    data: {
      quizTitle: attempt.quiz.title,
      subject: attempt.quiz.subject,
      score: attempt.score,
      totalPoints: attempt.totalPoints,
      percentage: attempt.percentage,
      isPassed: attempt.isPassed,
      startedAt: attempt.startedAt,
      submittedAt: attempt.submittedAt,
      questions: questionResults
    }
  });
}));

module.exports = router;

