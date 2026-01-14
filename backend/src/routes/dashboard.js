const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { body, param, query, validationResult } = require('express-validator');

const { asyncHandler, AppError } = require('../middleware/errorHandler');
const { requireRole } = require('../middleware/auth');
const { uploadConfigs, getFileUrl, deleteFile } = require('../middleware/upload');

const router = express.Router();
const prisma = new PrismaClient();

/**
 * @route   GET /api/v1/dashboard/posts
 * @desc    Get dashboard posts
 * @access  Private
 */
router.get('/posts', [
  query('type').optional().isIn(['UPDATE', 'EVENT', 'PROGRAM', 'ANNOUNCEMENT', 'ACHIEVEMENT']),
  query('view').optional().isIn(['timeline', 'grid'])
], asyncHandler(async (req, res) => {
  const { type, page = 1, limit = 20 } = req.query;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  let where = { schoolId: req.user.schoolId, isPublished: true };
  if (type) where.type = type;

  const [posts, total] = await Promise.all([
    prisma.dashboardPost.findMany({
      where,
      include: {
        author: {
          select: { id: true, firstName: true, lastName: true, role: true }
        }
      },
      skip,
      take: parseInt(limit),
      orderBy: [{ isPinned: 'desc' }, { createdAt: 'desc' }]
    }),
    prisma.dashboardPost.count({ where })
  ]);

  res.json({
    success: true,
    data: {
      posts: posts.map(p => ({
        ...p,
        mediaUrls: p.mediaUrls ? p.mediaUrls.map(url => getFileUrl(url, req)) : []
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
 * @route   POST /api/v1/dashboard/posts
 * @desc    Create a dashboard post
 * @access  Private (Principal only)
 */
router.post('/posts', requireRole('PRINCIPAL'), [
  body('title').trim().isLength({ min: 3, max: 200 }),
  body('content').trim().isLength({ min: 10, max: 10000 }),
  body('type').isIn(['UPDATE', 'EVENT', 'PROGRAM', 'ANNOUNCEMENT', 'ACHIEVEMENT']),
  body('eventDate').optional().isISO8601(),
  body('isPinned').optional().isBoolean(),
  body('isPublished').optional().isBoolean()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const { title, content, type, eventDate, isPinned, isPublished } = req.body;

  const post = await prisma.dashboardPost.create({
    data: {
      schoolId: req.user.schoolId,
      authorId: req.user.id,
      title,
      content,
      type,
      eventDate: eventDate ? new Date(eventDate) : null,
      isPinned: isPinned || false,
      isPublished: isPublished !== false,
      publishedAt: isPublished !== false ? new Date() : null
    },
    include: {
      author: {
        select: { id: true, firstName: true, lastName: true }
      }
    }
  });

  res.status(201).json({
    success: true,
    message: 'Post created successfully',
    data: post
  });
}));

/**
 * @route   POST /api/v1/dashboard/posts/:id/media
 * @desc    Upload media to a post
 * @access  Private (Principal only)
 */
router.post('/posts/:id/media',
  requireRole('PRINCIPAL'),
  uploadConfigs.dashboardMedia.array('media', 10),
  asyncHandler(async (req, res) => {
    const { id } = req.params;

    const post = await prisma.dashboardPost.findFirst({
      where: { id, schoolId: req.user.schoolId }
    });

    if (!post) {
      // Clean up uploaded files
      req.files?.forEach(f => deleteFile(f.path));
      throw new AppError('Post not found', 404);
    }

    const newMediaUrls = req.files?.map(f => f.path) || [];
    const existingUrls = post.mediaUrls || [];

    const updated = await prisma.dashboardPost.update({
      where: { id },
      data: {
        mediaUrls: [...existingUrls, ...newMediaUrls]
      }
    });

    res.json({
      success: true,
      message: 'Media uploaded successfully',
      data: {
        mediaUrls: updated.mediaUrls.map(url => getFileUrl(url, req))
      }
    });
  })
);

/**
 * @route   GET /api/v1/dashboard/posts/:id
 * @desc    Get post by ID
 * @access  Private
 */
router.get('/posts/:id', [param('id').isUUID()], asyncHandler(async (req, res) => {
  const post = await prisma.dashboardPost.findFirst({
    where: {
      id: req.params.id,
      schoolId: req.user.schoolId
    },
    include: {
      author: {
        select: { id: true, firstName: true, lastName: true, role: true }
      }
    }
  });

  if (!post) {
    throw new AppError('Post not found', 404);
  }

  res.json({
    success: true,
    data: {
      ...post,
      mediaUrls: post.mediaUrls ? post.mediaUrls.map(url => getFileUrl(url, req)) : []
    }
  });
}));

/**
 * @route   PUT /api/v1/dashboard/posts/:id
 * @desc    Update post
 * @access  Private (Principal only)
 */
router.put('/posts/:id', requireRole('PRINCIPAL'), [
  param('id').isUUID(),
  body('title').optional().trim().isLength({ min: 3, max: 200 }),
  body('content').optional().trim().isLength({ min: 10, max: 10000 }),
  body('type').optional().isIn(['UPDATE', 'EVENT', 'PROGRAM', 'ANNOUNCEMENT', 'ACHIEVEMENT']),
  body('isPinned').optional().isBoolean(),
  body('isPublished').optional().isBoolean()
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
  const { title, content, type, isPinned, isPublished } = req.body;

  const post = await prisma.dashboardPost.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!post) {
    throw new AppError('Post not found', 404);
  }

  const updated = await prisma.dashboardPost.update({
    where: { id },
    data: {
      ...(title && { title }),
      ...(content && { content }),
      ...(type && { type }),
      ...(isPinned !== undefined && { isPinned }),
      ...(isPublished !== undefined && {
        isPublished,
        publishedAt: isPublished && !post.publishedAt ? new Date() : post.publishedAt
      })
    }
  });

  res.json({
    success: true,
    message: 'Post updated successfully',
    data: updated
  });
}));

/**
 * @route   DELETE /api/v1/dashboard/posts/:id
 * @desc    Delete post
 * @access  Private (Principal only)
 */
router.delete('/posts/:id', requireRole('PRINCIPAL'), [
  param('id').isUUID()
], asyncHandler(async (req, res) => {
  const { id } = req.params;

  const post = await prisma.dashboardPost.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!post) {
    throw new AppError('Post not found', 404);
  }

  // Delete associated media files
  if (post.mediaUrls) {
    post.mediaUrls.forEach(url => deleteFile(url));
  }

  await prisma.dashboardPost.delete({ where: { id } });

  res.json({
    success: true,
    message: 'Post deleted successfully'
  });
}));

/**
 * @route   GET /api/v1/dashboard/stats
 * @desc    Get dashboard statistics
 * @access  Private
 */
router.get('/stats', asyncHandler(async (req, res) => {
  const schoolId = req.user.schoolId;
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const [
    totalStudents,
    totalTeachers,
    totalClasses,
    todayAttendance,
    recentPosts,
    upcomingEvents
  ] = await Promise.all([
    prisma.student.count({ where: { schoolId, isActive: true } }),
    prisma.user.count({ where: { schoolId, role: { in: ['TEACHER', 'PRINCIPAL'] }, isActive: true } }),
    prisma.class.count({ where: { schoolId, isActive: true } }),
    prisma.attendance.groupBy({
      by: ['status'],
      where: { schoolId, date: { gte: today } },
      _count: true
    }),
    prisma.dashboardPost.findMany({
      where: { schoolId, isPublished: true },
      take: 5,
      orderBy: { createdAt: 'desc' },
      select: { id: true, title: true, type: true, createdAt: true }
    }),
    prisma.dashboardPost.findMany({
      where: {
        schoolId,
        isPublished: true,
        type: 'EVENT',
        eventDate: { gte: today } // Events occurring today or in the future
      },
      take: 5,
      orderBy: { eventDate: 'asc' }, // Sort by event date, not creation date
      select: { id: true, title: true, content: true, eventDate: true, createdAt: true }
    })
  ]);

  const attendanceStats = {
    present: 0,
    absent: 0,
    late: 0,
    excused: 0
  };

  todayAttendance.forEach(item => {
    attendanceStats[item.status.toLowerCase()] = item._count;
  });

  res.json({
    success: true,
    data: {
      overview: {
        totalStudents,
        totalTeachers,
        totalClasses
      },
      todayAttendance: attendanceStats,
      recentPosts,
      upcomingEvents
    }
  });
}));

module.exports = router;

