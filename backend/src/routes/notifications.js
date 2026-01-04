const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { body, param, query, validationResult } = require('express-validator');
const nodemailer = require('nodemailer');

const { asyncHandler, AppError } = require('../middleware/errorHandler');
const { requireRole } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();
const prisma = new PrismaClient();

// Email transporter
const emailTransporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: parseInt(process.env.SMTP_PORT) || 587,
  secure: process.env.SMTP_SECURE === 'true',
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS
  }
});

// Mock SMS sender (replace with Twilio in production)
async function sendSMS(to, message) {
  if (process.env.NODE_ENV === 'production' && process.env.TWILIO_ACCOUNT_SID) {
    const twilio = require('twilio')(
      process.env.TWILIO_ACCOUNT_SID,
      process.env.TWILIO_AUTH_TOKEN
    );
    return twilio.messages.create({
      body: message,
      from: process.env.TWILIO_PHONE_NUMBER,
      to
    });
  }
  // Mock in development
  logger.info(`[MOCK SMS] To: ${to}, Message: ${message}`);
  return { sid: 'mock-' + Date.now() };
}

/**
 * @route   GET /api/v1/notifications
 * @desc    Get notifications (sent by user or received)
 * @access  Private
 */
router.get('/', [
  query('type').optional().isIn(['sent', 'received']),
  query('status').optional().isIn(['PENDING', 'SENDING', 'SENT', 'FAILED'])
], asyncHandler(async (req, res) => {
  const { type = 'received', status, page = 1, limit = 20 } = req.query;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  if (type === 'sent') {
    // Get notifications sent by user
    let where = { senderId: req.user.id, schoolId: req.user.schoolId };
    if (status) where.status = status;

    const [notifications, total] = await Promise.all([
      prisma.notification.findMany({
        where,
        include: {
          class: { select: { id: true, name: true, section: true } },
          subject: { select: { id: true, name: true } },
          _count: { select: { userRecipients: true, studentRecipients: true } }
        },
        skip,
        take: parseInt(limit),
        orderBy: { createdAt: 'desc' }
      }),
      prisma.notification.count({ where })
    ]);

    return res.json({
      success: true,
      data: {
        notifications,
        pagination: { page: parseInt(page), limit: parseInt(limit), total, pages: Math.ceil(total / parseInt(limit)) }
      }
    });
  }

  // Get received notifications
  const [notifications, total] = await Promise.all([
    prisma.userNotification.findMany({
      where: { userId: req.user.id },
      include: {
        notification: {
          include: {
            sender: { select: { id: true, firstName: true, lastName: true } }
          }
        }
      },
      skip,
      take: parseInt(limit),
      orderBy: { createdAt: 'desc' }
    }),
    prisma.userNotification.count({ where: { userId: req.user.id } })
  ]);

  res.json({
    success: true,
    data: {
      notifications: notifications.map(n => ({
        id: n.id,
        isRead: n.isRead,
        readAt: n.readAt,
        ...n.notification
      })),
      pagination: { page: parseInt(page), limit: parseInt(limit), total, pages: Math.ceil(total / parseInt(limit)) }
    }
  });
}));

/**
 * @route   POST /api/v1/notifications
 * @desc    Create and send notification
 * @access  Private (Principal only for school-wide)
 */
router.post('/', [
  body('title').trim().isLength({ min: 3, max: 200 }),
  body('message').trim().isLength({ min: 10, max: 5000 }),
  body('type').isIn(['ANNOUNCEMENT', 'NOTICE', 'ALERT', 'REMINDER', 'EVENT', 'ATTENDANCE', 'MARKS', 'QUIZ']),
  body('targetType').isIn(['ALL', 'TEACHERS', 'STUDENTS', 'CLASS', 'SUBJECT', 'INDIVIDUAL']),
  body('channels').isArray({ min: 1 }),
  body('priority').optional().isIn(['LOW', 'NORMAL', 'HIGH', 'URGENT']),
  body('classId').optional().isUUID(),
  body('subjectId').optional().isUUID(),
  body('recipientIds').optional().isArray()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ success: false, message: 'Validation failed', errors: errors.array() });
  }

  const { title, message, type, targetType, channels, priority, classId, subjectId, recipientIds, scheduledAt } = req.body;

  // Only principal can send to ALL or TEACHERS
  if (['ALL', 'TEACHERS'].includes(targetType) && req.user.role !== 'PRINCIPAL') {
    throw new AppError('Only principal can send school-wide notifications', 403);
  }

  // Create notification
  const notification = await prisma.notification.create({
    data: {
      schoolId: req.user.schoolId,
      senderId: req.user.id,
      title,
      message,
      type,
      targetType,
      channels,
      priority: priority || 'NORMAL',
      classId,
      subjectId,
      scheduledAt: scheduledAt ? new Date(scheduledAt) : null,
      status: scheduledAt ? 'PENDING' : 'SENDING'
    }
  });

  // Determine recipients
  let userRecipients = [];
  let studentRecipients = [];

  switch (targetType) {
    case 'ALL':
      userRecipients = await prisma.user.findMany({
        where: { schoolId: req.user.schoolId, isActive: true },
        select: { id: true, email: true, phone: true }
      });
      studentRecipients = await prisma.student.findMany({
        where: { schoolId: req.user.schoolId, isActive: true },
        select: { id: true, email: true, parentEmail: true, parentPhone: true }
      });
      break;
    case 'TEACHERS':
      userRecipients = await prisma.user.findMany({
        where: { schoolId: req.user.schoolId, role: 'TEACHER', isActive: true },
        select: { id: true, email: true, phone: true }
      });
      break;
    case 'STUDENTS':
      studentRecipients = await prisma.student.findMany({
        where: { schoolId: req.user.schoolId, isActive: true },
        select: { id: true, email: true, parentEmail: true, parentPhone: true }
      });
      break;
    case 'CLASS':
      if (!classId) throw new AppError('Class ID required for class notifications', 400);
      studentRecipients = await prisma.student.findMany({
        where: { classId, schoolId: req.user.schoolId, isActive: true },
        select: { id: true, email: true, parentEmail: true, parentPhone: true }
      });
      break;
    case 'INDIVIDUAL':
      if (!recipientIds || recipientIds.length === 0) {
        throw new AppError('Recipient IDs required for individual notifications', 400);
      }
      // Check if recipients are users or students
      userRecipients = await prisma.user.findMany({
        where: { id: { in: recipientIds }, schoolId: req.user.schoolId },
        select: { id: true, email: true, phone: true }
      });
      studentRecipients = await prisma.student.findMany({
        where: { id: { in: recipientIds }, schoolId: req.user.schoolId },
        select: { id: true, email: true, parentEmail: true, parentPhone: true }
      });
      break;
  }

  // Create recipient records
  if (userRecipients.length > 0) {
    await prisma.userNotification.createMany({
      data: userRecipients.map(u => ({ notificationId: notification.id, userId: u.id }))
    });
  }

  if (studentRecipients.length > 0) {
    await prisma.studentNotification.createMany({
      data: studentRecipients.map(s => ({ notificationId: notification.id, studentId: s.id }))
    });
  }

  // Send notifications if not scheduled
  if (!scheduledAt) {
    await sendNotifications(notification, channels, userRecipients, studentRecipients, title, message);
  }

  res.status(201).json({
    success: true,
    message: 'Notification created successfully',
    data: {
      id: notification.id,
      recipientCount: userRecipients.length + studentRecipients.length
    }
  });
}));

async function sendNotifications(notification, channels, users, students, title, message) {
  const logs = [];

  for (const channel of channels) {
    if (channel === 'EMAIL') {
      // Send to users
      for (const user of users) {
        if (user.email) {
          try {
            await emailTransporter.sendMail({
              from: process.env.EMAIL_FROM,
              to: user.email,
              subject: title,
              text: message,
              html: `<h2>${title}</h2><p>${message}</p>`
            });
            logs.push({ recipientType: 'USER', recipientId: user.id, channel: 'EMAIL', status: 'SENT' });
          } catch (error) {
            logger.error('Email send error:', error);
            logs.push({ recipientType: 'USER', recipientId: user.id, channel: 'EMAIL', status: 'FAILED', errorMessage: error.message });
          }
        }
      }
      // Send to students/parents
      for (const student of students) {
        const email = student.parentEmail || student.email;
        if (email) {
          try {
            await emailTransporter.sendMail({
              from: process.env.EMAIL_FROM,
              to: email,
              subject: title,
              text: message
            });
            logs.push({ recipientType: 'STUDENT', recipientId: student.id, channel: 'EMAIL', status: 'SENT' });
          } catch (error) {
            logs.push({ recipientType: 'STUDENT', recipientId: student.id, channel: 'EMAIL', status: 'FAILED', errorMessage: error.message });
          }
        }
      }
    }

    if (channel === 'SMS') {
      for (const user of users) {
        if (user.phone) {
          try {
            await sendSMS(user.phone, `${title}: ${message}`);
            logs.push({ recipientType: 'USER', recipientId: user.id, channel: 'SMS', status: 'SENT' });
          } catch (error) {
            logs.push({ recipientType: 'USER', recipientId: user.id, channel: 'SMS', status: 'FAILED', errorMessage: error.message });
          }
        }
      }
      for (const student of students) {
        if (student.parentPhone) {
          try {
            await sendSMS(student.parentPhone, `${title}: ${message}`);
            logs.push({ recipientType: 'STUDENT', recipientId: student.id, channel: 'SMS', status: 'SENT' });
          } catch (error) {
            logs.push({ recipientType: 'STUDENT', recipientId: student.id, channel: 'SMS', status: 'FAILED', errorMessage: error.message });
          }
        }
      }
    }
  }

  // Save logs
  if (logs.length > 0) {
    await prisma.notificationLog.createMany({
      data: logs.map(log => ({ notificationId: notification.id, ...log }))
    });
  }

  // Update notification status
  await prisma.notification.update({
    where: { id: notification.id },
    data: { status: 'SENT', sentAt: new Date() }
  });
}

/**
 * @route   PUT /api/v1/notifications/:id/read
 * @desc    Mark notification as read
 * @access  Private
 */
router.put('/:id/read', [param('id').isUUID()], asyncHandler(async (req, res) => {
  await prisma.userNotification.updateMany({
    where: { id: req.params.id, userId: req.user.id },
    data: { isRead: true, readAt: new Date() }
  });

  res.json({ success: true, message: 'Notification marked as read' });
}));

/**
 * @route   GET /api/v1/notifications/unread-count
 * @desc    Get unread notification count
 * @access  Private
 */
router.get('/unread-count', asyncHandler(async (req, res) => {
  const count = await prisma.userNotification.count({
    where: { userId: req.user.id, isRead: false }
  });

  res.json({ success: true, data: { count } });
}));

module.exports = router;

