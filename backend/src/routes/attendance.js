const express = require('express');
const axios = require('axios');
const { PrismaClient } = require('@prisma/client');
const { body, param, query, validationResult } = require('express-validator');

const { asyncHandler, AppError } = require('../middleware/errorHandler');
const { requireRole } = require('../middleware/auth');
const { uploadConfigs, deleteFile } = require('../middleware/upload');
const { decrypt } = require('../utils/encryption');
const logger = require('../utils/logger');

const router = express.Router();
const prisma = new PrismaClient();

const FACE_RECOGNITION_URL = process.env.FACE_RECOGNITION_URL || 'http://localhost:8000';

/**
 * @route   GET /api/v1/attendance
 * @desc    Get attendance records
 * @access  Private
 */
router.get('/', [
  query('classId').optional().isUUID(),
  query('date').optional().isISO8601(),
  query('startDate').optional().isISO8601(),
  query('endDate').optional().isISO8601()
], asyncHandler(async (req, res) => {
  const { classId, date, startDate, endDate, studentId, page = 1, limit = 100 } = req.query;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  let where = { schoolId: req.user.schoolId };

  if (classId) where.classId = classId;
  if (studentId) where.studentId = studentId;

  if (date) {
    const dateObj = new Date(date);
    where.date = {
      gte: new Date(dateObj.setHours(0, 0, 0, 0)),
      lt: new Date(dateObj.setHours(23, 59, 59, 999))
    };
  } else if (startDate && endDate) {
    where.date = {
      gte: new Date(startDate),
      lte: new Date(endDate)
    };
  }

  const [records, total] = await Promise.all([
    prisma.attendance.findMany({
      where,
      include: {
        student: {
          select: { id: true, rollNumber: true, firstName: true, lastName: true }
        },
        teacher: {
          select: { id: true, firstName: true, lastName: true }
        },
        class: {
          select: { id: true, name: true, section: true }
        }
      },
      skip,
      take: parseInt(limit),
      orderBy: [{ date: 'desc' }, { student: { rollNumber: 'asc' } }]
    }),
    prisma.attendance.count({ where })
  ]);

  res.json({
    success: true,
    data: {
      records,
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
 * @route   POST /api/v1/attendance/manual
 * @desc    Record attendance manually
 * @access  Private
 */
router.post('/manual', [
  body('classId').isUUID(),
  body('date').isISO8601(),
  body('records').isArray({ min: 1 }),
  body('records.*.studentId').isUUID(),
  body('records.*.status').isIn(['PRESENT', 'ABSENT', 'LATE', 'EXCUSED'])
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const { classId, date, records } = req.body;
  const attendanceDate = new Date(date);

  // Verify class belongs to school
  const classRecord = await prisma.class.findFirst({
    where: { id: classId, schoolId: req.user.schoolId }
  });

  if (!classRecord) {
    throw new AppError('Class not found', 404);
  }

  // Process attendance records
  const results = await prisma.$transaction(async (tx) => {
    const savedRecords = [];

    for (const record of records) {
      // Check if attendance already exists for this student on this date
      const existing = await tx.attendance.findUnique({
        where: {
          studentId_date: {
            studentId: record.studentId,
            date: attendanceDate
          }
        }
      });

      if (existing) {
        // Update existing record
        const updated = await tx.attendance.update({
          where: { id: existing.id },
          data: {
            status: record.status,
            method: 'MANUAL',
            remarks: record.remarks,
            teacherId: req.user.id
          }
        });
        savedRecords.push(updated);
      } else {
        // Create new record
        const created = await tx.attendance.create({
          data: {
            schoolId: req.user.schoolId,
            classId,
            studentId: record.studentId,
            teacherId: req.user.id,
            date: attendanceDate,
            status: record.status,
            method: 'MANUAL',
            remarks: record.remarks
          }
        });
        savedRecords.push(created);
      }
    }

    return savedRecords;
  });

  // Create audit log
  await prisma.auditLog.create({
    data: {
      schoolId: req.user.schoolId,
      userId: req.user.id,
      action: 'CREATE',
      entityType: 'ATTENDANCE',
      entityId: classId,
      newValue: { date, recordCount: records.length, method: 'MANUAL' }
    }
  });

  res.status(201).json({
    success: true,
    message: 'Attendance recorded successfully',
    data: { count: results.length }
  });
}));

/**
 * @route   POST /api/v1/attendance/face-recognition
 * @desc    Record attendance using face recognition
 * @access  Private
 */
router.post('/face-recognition',
  uploadConfigs.attendancePhoto.single('photo'),
  asyncHandler(async (req, res) => {
    if (!req.file) {
      throw new AppError('No photo uploaded', 400);
    }

    const { classId, date } = req.body;

    if (!classId) {
      deleteFile(req.file.path);
      throw new AppError('Class ID is required', 400);
    }

    // Verify class belongs to school
    const classRecord = await prisma.class.findFirst({
      where: { id: classId, schoolId: req.user.schoolId }
    });

    if (!classRecord) {
      deleteFile(req.file.path);
      throw new AppError('Class not found', 404);
    }

    // Get all students in the class with face encodings
    const students = await prisma.student.findMany({
      where: {
        classId,
        schoolId: req.user.schoolId,
        isActive: true,
        faceEncoding: { not: null }
      },
      select: {
        id: true,
        rollNumber: true,
        firstName: true,
        lastName: true,
        faceEncoding: true
      }
    });

    if (students.length === 0) {
      deleteFile(req.file.path);
      throw new AppError('No students with face encodings found in this class', 400);
    }

    // Decrypt face encodings
    const knownFaces = students.map(s => ({
      id: s.id,
      rollNumber: s.rollNumber,
      name: `${s.firstName} ${s.lastName}`,
      encoding: JSON.parse(decrypt(s.faceEncoding))
    }));

    try {
      // Call face recognition service
      const formData = new FormData();
      const fs = require('fs');
      const blob = new Blob([fs.readFileSync(req.file.path)]);
      formData.append('image', blob, req.file.originalname);
      formData.append('known_faces', JSON.stringify(knownFaces));
      formData.append('threshold', '0.75');

      const response = await axios.post(
        `${FACE_RECOGNITION_URL}/recognize`,
        formData,
        {
          headers: { 'Content-Type': 'multipart/form-data' },
          timeout: 30000
        }
      );

      const recognizedFaces = response.data.recognized || [];
      const attendanceDate = date ? new Date(date) : new Date();

      // Record attendance for recognized faces
      const results = await prisma.$transaction(async (tx) => {
        const savedRecords = [];

        for (const face of recognizedFaces) {
          const existing = await tx.attendance.findUnique({
            where: {
              studentId_date: {
                studentId: face.id,
                date: attendanceDate
              }
            }
          });

          if (existing) {
            const updated = await tx.attendance.update({
              where: { id: existing.id },
              data: {
                status: 'PRESENT',
                method: 'FACE_RECOGNITION',
                confidence: face.confidence,
                teacherId: req.user.id
              }
            });
            savedRecords.push(updated);
          } else {
            const created = await tx.attendance.create({
              data: {
                schoolId: req.user.schoolId,
                classId,
                studentId: face.id,
                teacherId: req.user.id,
                date: attendanceDate,
                status: 'PRESENT',
                method: 'FACE_RECOGNITION',
                confidence: face.confidence
              }
            });
            savedRecords.push(created);
          }
        }

        return savedRecords;
      });

      // Clean up temp file
      deleteFile(req.file.path);

      res.json({
        success: true,
        message: 'Face recognition attendance completed',
        data: {
          recognized: recognizedFaces.length,
          total: students.length,
          records: results.map(r => ({
            studentId: r.studentId,
            status: r.status,
            confidence: r.confidence
          }))
        }
      });
    } catch (error) {
      deleteFile(req.file.path);
      logger.error('Face recognition error:', error);
      throw new AppError('Face recognition service error. Please use manual attendance.', 500);
    }
  })
);

/**
 * @route   PUT /api/v1/attendance/:id
 * @desc    Update attendance record
 * @access  Private
 */
router.put('/:id', [
  param('id').isUUID(),
  body('status').isIn(['PRESENT', 'ABSENT', 'LATE', 'EXCUSED']),
  body('remarks').optional().trim()
], asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { status, remarks } = req.body;

  const record = await prisma.attendance.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!record) {
    throw new AppError('Attendance record not found', 404);
  }

  const oldValue = { status: record.status, remarks: record.remarks };

  const updated = await prisma.attendance.update({
    where: { id },
    data: { status, remarks, method: 'MANUAL' }
  });

  // Create audit log
  await prisma.auditLog.create({
    data: {
      schoolId: req.user.schoolId,
      userId: req.user.id,
      action: 'UPDATE',
      entityType: 'ATTENDANCE',
      entityId: id,
      oldValue,
      newValue: { status, remarks }
    }
  });

  res.json({
    success: true,
    message: 'Attendance updated successfully',
    data: updated
  });
}));

/**
 * @route   GET /api/v1/attendance/summary/:classId
 * @desc    Get attendance summary for a class
 * @access  Private
 */
router.get('/summary/:classId', [
  param('classId').isUUID(),
  query('month').optional().isInt({ min: 1, max: 12 }),
  query('year').optional().isInt({ min: 2020 })
], asyncHandler(async (req, res) => {
  const { classId } = req.params;
  const month = parseInt(req.query.month) || new Date().getMonth() + 1;
  const year = parseInt(req.query.year) || new Date().getFullYear();

  const startDate = new Date(year, month - 1, 1);
  const endDate = new Date(year, month, 0, 23, 59, 59);

  const summary = await prisma.attendance.groupBy({
    by: ['studentId', 'status'],
    where: {
      classId,
      schoolId: req.user.schoolId,
      date: { gte: startDate, lte: endDate }
    },
    _count: true
  });

  // Get student details
  const students = await prisma.student.findMany({
    where: { classId, schoolId: req.user.schoolId, isActive: true },
    select: { id: true, rollNumber: true, firstName: true, lastName: true }
  });

  // Organize summary by student
  const studentSummary = students.map(student => {
    const studentRecords = summary.filter(s => s.studentId === student.id);
    return {
      ...student,
      present: studentRecords.find(r => r.status === 'PRESENT')?._count || 0,
      absent: studentRecords.find(r => r.status === 'ABSENT')?._count || 0,
      late: studentRecords.find(r => r.status === 'LATE')?._count || 0,
      excused: studentRecords.find(r => r.status === 'EXCUSED')?._count || 0
    };
  });

  res.json({
    success: true,
    data: {
      month,
      year,
      summary: studentSummary
    }
  });
}));

module.exports = router;

