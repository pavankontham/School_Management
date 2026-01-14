const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { body, query, validationResult } = require('express-validator');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const { asyncHandler, AppError } = require('../middleware/errorHandler');
const logger = require('../utils/logger');

const router = express.Router();
const prisma = new PrismaClient();

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

const TEACHER_SYSTEM_PROMPT = `You are an AI teaching assistant for teachers. You help with:
- Lesson planning and curriculum development
- Teaching strategies and methodologies
- Student engagement techniques
- Assessment and evaluation methods
- Classroom management tips
- Educational resources and materials

Be professional, helpful, and provide practical advice. Always encourage best teaching practices.`;

const STUDENT_SYSTEM_PROMPT = `You are a friendly AI tutor for students. You help with:
- Explaining concepts in simple terms
- Providing study tips and techniques
- Guiding through problem-solving (without giving direct answers)
- Encouraging learning and curiosity
- Answering educational questions

IMPORTANT: Never provide direct answers to homework or test questions. Instead, guide students to understand concepts and find answers themselves. Be encouraging and patient.`;

/**
 * Generate AI response with retry logic
 */
async function generateAIResponse(prompt, systemPrompt, history = []) {
  const maxRetries = 3;
  let lastError;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

      // Build conversation history
      const chatHistory = history.map(msg => ({
        role: msg.role === 'USER' ? 'user' : 'model',
        parts: [{ text: msg.content }]
      }));

      const chat = model.startChat({
        history: [
          { role: 'user', parts: [{ text: systemPrompt }] },
          { role: 'model', parts: [{ text: 'I understand. I will follow these guidelines.' }] },
          ...chatHistory
        ],
        generationConfig: {
          maxOutputTokens: 2048,
          temperature: 0.7
        }
      });

      const result = await chat.sendMessage(prompt);
      const response = await result.response;
      return response.text();
    } catch (error) {
      lastError = error;
      logger.error(`AI generation attempt ${attempt} failed:`, error);

      if (attempt < maxRetries) {
        await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
      }
    }
  }

  throw new AppError('AI service temporarily unavailable. Please try again later.', 503);
}

/**
 * @route   GET /api/v1/chat/history
 * @desc    Get chat history for teacher
 * @access  Private
 */
router.get('/history', [
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 })
], asyncHandler(async (req, res) => {
  const { page = 1, limit = 50, search } = req.query;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  let where = {
    userId: req.user.id,
    schoolId: req.user.schoolId
  };

  if (search) {
    where.content = { contains: search, mode: 'insensitive' };
  }

  const [messages, total] = await Promise.all([
    prisma.chatMessage.findMany({
      where,
      skip,
      take: parseInt(limit),
      orderBy: { createdAt: 'desc' }
    }),
    prisma.chatMessage.count({ where })
  ]);

  res.json({
    success: true,
    data: {
      messages: messages.reverse(),
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
 * @route   POST /api/v1/chat/message
 * @desc    Send message to AI chatbot (Teacher)
 * @access  Private
 */
router.post('/message', [
  body('message').trim().isLength({ min: 1, max: 5000 })
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const { message } = req.body;

  // Get recent chat history for context
  const recentHistory = await prisma.chatMessage.findMany({
    where: {
      userId: req.user.id,
      schoolId: req.user.schoolId
    },
    orderBy: { createdAt: 'desc' },
    take: 10
  });

  // Save user message
  const userMessage = await prisma.chatMessage.create({
    data: {
      userId: req.user.id,
      schoolId: req.user.schoolId,
      role: 'USER',
      content: message
    }
  });

  try {
    // Generate AI response
    const aiResponse = await generateAIResponse(
      message,
      TEACHER_SYSTEM_PROMPT,
      recentHistory.reverse()
    );

    // Save AI response
    const assistantMessage = await prisma.chatMessage.create({
      data: {
        userId: req.user.id,
        schoolId: req.user.schoolId,
        role: 'ASSISTANT',
        content: aiResponse
      }
    });

    res.json({
      success: true,
      data: {
        userMessage,
        assistantMessage
      }
    });
  } catch (error) {
    logger.error('Chat error:', error);

    // Save error message
    await prisma.chatMessage.create({
      data: {
        userId: req.user.id,
        schoolId: req.user.schoolId,
        role: 'ASSISTANT',
        content: 'I apologize, but I encountered an error. Please try again.'
      }
    });

    throw error;
  }
}));

/**
 * @route   DELETE /api/v1/chat/history
 * @desc    Clear chat history
 * @access  Private
 */
router.delete('/history', asyncHandler(async (req, res) => {
  await prisma.chatMessage.deleteMany({
    where: {
      userId: req.user.id,
      schoolId: req.user.schoolId
    }
  });

  res.json({
    success: true,
    message: 'Chat history cleared'
  });
}));

/**
 * @route   GET /api/v1/chat/student/history
 * @desc    Get chat history for student
 * @access  Private (Student)
 */
router.get('/student/history', asyncHandler(async (req, res) => {
  const { page = 1, limit = 50 } = req.query;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  // This route is for students - check if student token
  if (!req.student && req.user.role !== 'STUDENT') {
    throw new AppError('Student access required', 403);
  }

  const studentId = req.student?.id || req.user.id;

  const [messages, total] = await Promise.all([
    prisma.studentChatMessage.findMany({
      where: { studentId },
      skip,
      take: parseInt(limit),
      orderBy: { createdAt: 'desc' }
    }),
    prisma.studentChatMessage.count({ where: { studentId } })
  ]);

  res.json({
    success: true,
    data: {
      messages: messages.reverse(),
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
 * @route   POST /api/v1/chat/student/message
 * @desc    Send message to AI chatbot (Student)
 * @access  Private (Student)
 */
router.post('/student/message', [
  body('message').trim().isLength({ min: 1, max: 2000 })
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  if (!req.student && req.user.role !== 'STUDENT') {
    throw new AppError('Student access required', 403);
  }

  const studentId = req.student?.id || req.user.id;
  const schoolId = req.student?.schoolId || req.user.schoolId;
  const { message } = req.body;

  // Rate limiting check - max 20 messages per hour
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  const recentCount = await prisma.studentChatMessage.count({
    where: {
      studentId,
      role: 'USER',
      createdAt: { gte: oneHourAgo }
    }
  });

  if (recentCount >= 20) {
    throw new AppError('Rate limit exceeded. Please wait before sending more messages.', 429);
  }

  // Content filtering - basic check for inappropriate content
  const inappropriatePatterns = [
    /\b(cheat|hack|answer\s+key|test\s+answers)\b/i
  ];

  for (const pattern of inappropriatePatterns) {
    if (pattern.test(message)) {
      return res.json({
        success: true,
        data: {
          userMessage: { content: message, role: 'USER' },
          assistantMessage: {
            content: "I'm here to help you learn, not to provide shortcuts. Let's focus on understanding the concepts together!",
            role: 'ASSISTANT'
          }
        }
      });
    }
  }

  // Get recent history
  const recentHistory = await prisma.studentChatMessage.findMany({
    where: { studentId },
    orderBy: { createdAt: 'desc' },
    take: 10
  });

  // Save user message
  const userMessage = await prisma.studentChatMessage.create({
    data: {
      studentId,
      schoolId,
      role: 'USER',
      content: message
    }
  });

  try {
    const aiResponse = await generateAIResponse(
      message,
      STUDENT_SYSTEM_PROMPT,
      recentHistory.reverse()
    );

    const assistantMessage = await prisma.studentChatMessage.create({
      data: {
        studentId,
        schoolId,
        role: 'ASSISTANT',
        content: aiResponse
      }
    });

    res.json({
      success: true,
      data: {
        userMessage,
        assistantMessage
      }
    });
  } catch (error) {
    logger.error('Student chat error:', error);
    throw error;
  }
}));

module.exports = router;

