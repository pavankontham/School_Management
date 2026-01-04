const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { body, param, query, validationResult } = require('express-validator');
const path = require('path');

const { asyncHandler, AppError } = require('../middleware/errorHandler');
const { requireRole } = require('../middleware/auth');
const { uploadConfigs, getFileUrl, deleteFile } = require('../middleware/upload');

const router = express.Router();
const prisma = new PrismaClient();

/**
 * @route   GET /api/v1/textbooks
 * @desc    Get all textbooks
 * @access  Private
 */
router.get('/', [
  query('subjectId').optional().isUUID(),
  query('grade').optional().trim()
], asyncHandler(async (req, res) => {
  const { subjectId, grade, page = 1, limit = 50 } = req.query;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  let where = { schoolId: req.user.schoolId, isActive: true };

  if (subjectId) where.subjectId = subjectId;
  if (grade) where.grade = grade;

  const [textbooks, total] = await Promise.all([
    prisma.textbook.findMany({
      where,
      include: {
        subject: {
          select: { id: true, name: true, code: true }
        }
      },
      skip,
      take: parseInt(limit),
      orderBy: [{ subject: { name: 'asc' } }, { title: 'asc' }]
    }),
    prisma.textbook.count({ where })
  ]);

  res.json({
    success: true,
    data: {
      textbooks: textbooks.map(t => ({
        ...t,
        fileUrl: getFileUrl(t.filePath, req)
      })),
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
 * @route   POST /api/v1/textbooks
 * @desc    Upload a new textbook
 * @access  Private
 */
router.post('/',
  uploadConfigs.textbook.single('file'),
  asyncHandler(async (req, res) => {
    if (!req.file) {
      throw new AppError('No file uploaded', 400);
    }

    const { subjectId, title, description, author, grade } = req.body;

    if (!subjectId || !title) {
      deleteFile(req.file.path);
      throw new AppError('Subject ID and title are required', 400);
    }

    // Verify subject belongs to school
    const subject = await prisma.subject.findFirst({
      where: { id: subjectId, schoolId: req.user.schoolId }
    });

    if (!subject) {
      deleteFile(req.file.path);
      throw new AppError('Subject not found', 404);
    }

    const textbook = await prisma.textbook.create({
      data: {
        schoolId: req.user.schoolId,
        subjectId,
        title,
        description,
        author,
        grade,
        filePath: req.file.path,
        fileSize: req.file.size,
        fileType: path.extname(req.file.originalname).toLowerCase()
      },
      include: {
        subject: {
          select: { id: true, name: true, code: true }
        }
      }
    });

    res.status(201).json({
      success: true,
      message: 'Textbook uploaded successfully',
      data: {
        ...textbook,
        fileUrl: getFileUrl(textbook.filePath, req)
      }
    });
  })
);

/**
 * @route   GET /api/v1/textbooks/:id
 * @desc    Get textbook by ID
 * @access  Private
 */
router.get('/:id', [param('id').isUUID()], asyncHandler(async (req, res) => {
  const textbook = await prisma.textbook.findFirst({
    where: {
      id: req.params.id,
      schoolId: req.user.schoolId
    },
    include: {
      subject: true
    }
  });

  if (!textbook) {
    throw new AppError('Textbook not found', 404);
  }

  res.json({
    success: true,
    data: {
      ...textbook,
      fileUrl: getFileUrl(textbook.filePath, req)
    }
  });
}));

/**
 * @route   GET /api/v1/textbooks/:id/download
 * @desc    Download textbook file
 * @access  Private
 */
router.get('/:id/download', [param('id').isUUID()], asyncHandler(async (req, res) => {
  const textbook = await prisma.textbook.findFirst({
    where: {
      id: req.params.id,
      schoolId: req.user.schoolId
    }
  });

  if (!textbook) {
    throw new AppError('Textbook not found', 404);
  }

  const fs = require('fs');
  if (!fs.existsSync(textbook.filePath)) {
    throw new AppError('File not found', 404);
  }

  res.download(textbook.filePath, `${textbook.title}${textbook.fileType}`);
}));

/**
 * @route   PUT /api/v1/textbooks/:id
 * @desc    Update textbook details
 * @access  Private
 */
router.put('/:id', [
  param('id').isUUID(),
  body('title').optional().trim().isLength({ min: 2, max: 200 }),
  body('description').optional().trim(),
  body('author').optional().trim(),
  body('grade').optional().trim(),
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
  const { title, description, author, grade, isActive } = req.body;

  const textbook = await prisma.textbook.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!textbook) {
    throw new AppError('Textbook not found', 404);
  }

  const updated = await prisma.textbook.update({
    where: { id },
    data: {
      ...(title && { title }),
      ...(description !== undefined && { description }),
      ...(author !== undefined && { author }),
      ...(grade !== undefined && { grade }),
      ...(isActive !== undefined && { isActive })
    }
  });

  res.json({
    success: true,
    message: 'Textbook updated successfully',
    data: {
      ...updated,
      fileUrl: getFileUrl(updated.filePath, req)
    }
  });
}));

/**
 * @route   DELETE /api/v1/textbooks/:id
 * @desc    Delete textbook
 * @access  Private (Principal only)
 */
router.delete('/:id', requireRole('PRINCIPAL'), [
  param('id').isUUID()
], asyncHandler(async (req, res) => {
  const { id } = req.params;

  const textbook = await prisma.textbook.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!textbook) {
    throw new AppError('Textbook not found', 404);
  }

  // Delete file
  deleteFile(textbook.filePath);

  // Delete record
  await prisma.textbook.delete({ where: { id } });

  res.json({
    success: true,
    message: 'Textbook deleted successfully'
  });
}));

/**
 * @route   GET /api/v1/textbooks/by-subject/:subjectId
 * @desc    Get all textbooks for a subject
 * @access  Private
 */
router.get('/by-subject/:subjectId', [
  param('subjectId').isUUID()
], asyncHandler(async (req, res) => {
  const { subjectId } = req.params;

  const textbooks = await prisma.textbook.findMany({
    where: {
      subjectId,
      schoolId: req.user.schoolId,
      isActive: true
    },
    orderBy: { title: 'asc' }
  });

  res.json({
    success: true,
    data: textbooks.map(t => ({
      ...t,
      fileUrl: getFileUrl(t.filePath, req)
    }))
  });
}));

/**
 * @route   GET /api/v1/textbooks/by-grade/:grade
 * @desc    Get all textbooks for a grade
 * @access  Private
 */
router.get('/by-grade/:grade', asyncHandler(async (req, res) => {
  const { grade } = req.params;

  const textbooks = await prisma.textbook.findMany({
    where: {
      grade,
      schoolId: req.user.schoolId,
      isActive: true
    },
    include: {
      subject: {
        select: { id: true, name: true, code: true }
      }
    },
    orderBy: [{ subject: { name: 'asc' } }, { title: 'asc' }]
  });

  res.json({
    success: true,
    data: textbooks.map(t => ({
      ...t,
      fileUrl: getFileUrl(t.filePath, req)
    }))
  });
}));

module.exports = router;

