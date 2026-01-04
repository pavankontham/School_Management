const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { body, validationResult } = require('express-validator');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const { asyncHandler, AppError } = require('../middleware/errorHandler');
const logger = require('../utils/logger');

const router = express.Router();
const prisma = new PrismaClient();

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

/**
 * Generate quiz questions using AI
 */
async function generateQuizQuestions(topic, subject, grade, count, questionType) {
  const maxRetries = 3;
  
  const prompt = `Generate ${count} ${questionType} questions about "${topic}" for ${subject} subject, suitable for grade ${grade} students.

For each question, provide:
1. The question text
2. Four options (A, B, C, D) for MCQ, or True/False for TRUE_FALSE
3. The correct answer
4. A brief explanation

Format your response as a JSON array with this structure:
[
  {
    "questionText": "Question here?",
    "questionType": "${questionType}",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctAnswer": "A",
    "explanation": "Brief explanation here"
  }
]

Make questions educational, clear, and age-appropriate. Vary difficulty levels.`;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
      
      const result = await model.generateContent({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.8,
          maxOutputTokens: 4096
        }
      });

      const response = await result.response;
      const text = response.text();
      
      // Extract JSON from response
      const jsonMatch = text.match(/\[[\s\S]*\]/);
      if (!jsonMatch) {
        throw new Error('Invalid response format');
      }

      const questions = JSON.parse(jsonMatch[0]);
      return questions;
    } catch (error) {
      logger.error(`AI quiz generation attempt ${attempt} failed:`, error);
      
      if (attempt < maxRetries) {
        await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
      }
    }
  }

  throw new AppError('Failed to generate quiz questions. Please try again.', 503);
}

/**
 * @route   POST /api/v1/ai/generate-quiz
 * @desc    Generate quiz questions using AI
 * @access  Private
 */
router.post('/generate-quiz', [
  body('topic').trim().isLength({ min: 3, max: 200 }),
  body('subjectId').isUUID(),
  body('classId').isUUID(),
  body('count').optional().isInt({ min: 1, max: 20 }),
  body('questionType').optional().isIn(['MCQ', 'TRUE_FALSE']),
  body('title').optional().trim().isLength({ min: 3, max: 200 }),
  body('timeLimit').optional().isInt({ min: 1, max: 300 }),
  body('saveQuiz').optional().isBoolean()
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
    topic,
    subjectId,
    classId,
    count = 10,
    questionType = 'MCQ',
    title,
    timeLimit,
    saveQuiz = false
  } = req.body;

  // Verify class and subject
  const [classRecord, subject] = await Promise.all([
    prisma.class.findFirst({ where: { id: classId, schoolId: req.user.schoolId } }),
    prisma.subject.findFirst({ where: { id: subjectId, schoolId: req.user.schoolId } })
  ]);

  if (!classRecord) throw new AppError('Class not found', 404);
  if (!subject) throw new AppError('Subject not found', 404);

  // Generate questions
  const questions = await generateQuizQuestions(
    topic,
    subject.name,
    classRecord.grade,
    count,
    questionType
  );

  // Optionally save as quiz
  if (saveQuiz) {
    const quiz = await prisma.$transaction(async (tx) => {
      const newQuiz = await tx.quiz.create({
        data: {
          schoolId: req.user.schoolId,
          classId,
          subjectId,
          teacherId: req.user.id,
          title: title || `AI Quiz: ${topic}`,
          description: `AI-generated quiz about ${topic}`,
          timeLimit,
          isAIGenerated: true
        }
      });

      await tx.quizQuestion.createMany({
        data: questions.map((q, index) => ({
          quizId: newQuiz.id,
          questionText: q.questionText,
          questionType: q.questionType,
          options: q.options,
          correctAnswer: q.correctAnswer,
          explanation: q.explanation,
          points: 1,
          orderIndex: index + 1
        }))
      });

      return newQuiz;
    });

    return res.status(201).json({
      success: true,
      message: 'Quiz generated and saved successfully',
      data: {
        quizId: quiz.id,
        questions
      }
    });
  }

  res.json({
    success: true,
    message: 'Questions generated successfully',
    data: { questions }
  });
}));

/**
 * @route   POST /api/v1/ai/explain-topic
 * @desc    Get AI explanation for a topic
 * @access  Private
 */
router.post('/explain-topic', [
  body('topic').trim().isLength({ min: 3, max: 500 }),
  body('subject').optional().trim(),
  body('grade').optional().trim(),
  body('style').optional().isIn(['simple', 'detailed', 'examples'])
], asyncHandler(async (req, res) => {
  const { topic, subject, grade, style = 'simple' } = req.body;

  const styleInstructions = {
    simple: 'Explain in simple, easy-to-understand terms.',
    detailed: 'Provide a comprehensive, detailed explanation.',
    examples: 'Explain with multiple real-world examples.'
  };

  const prompt = `Explain the following topic${subject ? ` from ${subject}` : ''}${grade ? ` for grade ${grade} students` : ''}:

Topic: ${topic}

${styleInstructions[style]}

Structure your response with:
1. A brief introduction
2. Key concepts
3. ${style === 'examples' ? 'Multiple examples' : 'An example'}
4. Summary

Keep the explanation educational and engaging.`;

  try {
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
    
    const result = await model.generateContent({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 2048
      }
    });

    const response = await result.response;
    const explanation = response.text();

    res.json({
      success: true,
      data: { explanation }
    });
  } catch (error) {
    logger.error('AI explanation error:', error);
    throw new AppError('Failed to generate explanation. Please try again.', 503);
  }
}));

/**
 * @route   POST /api/v1/ai/lesson-plan
 * @desc    Generate lesson plan using AI
 * @access  Private
 */
router.post('/lesson-plan', [
  body('topic').trim().isLength({ min: 3, max: 200 }),
  body('subject').trim().isLength({ min: 2, max: 100 }),
  body('grade').trim().isLength({ min: 1, max: 20 }),
  body('duration').optional().isInt({ min: 15, max: 180 }),
  body('objectives').optional().isArray()
], asyncHandler(async (req, res) => {
  const { topic, subject, grade, duration = 45, objectives = [] } = req.body;

  const prompt = `Create a detailed lesson plan for teaching "${topic}" in ${subject} for grade ${grade} students.

Duration: ${duration} minutes
${objectives.length > 0 ? `Learning Objectives: ${objectives.join(', ')}` : ''}

Include:
1. Learning objectives (if not provided)
2. Required materials
3. Introduction/Hook (5 minutes)
4. Main lesson activities with timing
5. Student engagement activities
6. Assessment methods
7. Homework/Extension activities
8. Differentiation strategies for different learning levels

Format the response in a clear, structured way that a teacher can easily follow.`;

  try {
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
    
    const result = await model.generateContent({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 3000
      }
    });

    const response = await result.response;
    const lessonPlan = response.text();

    res.json({
      success: true,
      data: { lessonPlan }
    });
  } catch (error) {
    logger.error('AI lesson plan error:', error);
    throw new AppError('Failed to generate lesson plan. Please try again.', 503);
  }
}));

/**
 * @route   POST /api/v1/ai/study-tips
 * @desc    Get personalized study tips
 * @access  Private
 */
router.post('/study-tips', [
  body('subject').trim().isLength({ min: 2, max: 100 }),
  body('topic').optional().trim(),
  body('difficulty').optional().isIn(['easy', 'medium', 'hard']),
  body('learningStyle').optional().isIn(['visual', 'auditory', 'reading', 'kinesthetic'])
], asyncHandler(async (req, res) => {
  const { subject, topic, difficulty, learningStyle } = req.body;

  const prompt = `Provide study tips and strategies for learning ${subject}${topic ? ` specifically about ${topic}` : ''}.

${difficulty ? `Difficulty level: ${difficulty}` : ''}
${learningStyle ? `Learning style preference: ${learningStyle}` : ''}

Include:
1. Effective study techniques
2. Memory aids and mnemonics
3. Practice strategies
4. Common mistakes to avoid
5. Resources for further learning
6. Time management tips

Make the tips practical and actionable.`;

  try {
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
    
    const result = await model.generateContent({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 1500
      }
    });

    const response = await result.response;
    const tips = response.text();

    res.json({
      success: true,
      data: { tips }
    });
  } catch (error) {
    logger.error('AI study tips error:', error);
    throw new AppError('Failed to generate study tips. Please try again.', 503);
  }
}));

module.exports = router;

