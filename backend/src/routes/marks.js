const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { body, param, query, validationResult } = require('express-validator');

const { asyncHandler, AppError } = require('../middleware/errorHandler');
const validators = require('../utils/validators');

const router = express.Router();
const prisma = new PrismaClient();

/**
 * Calculate grade based on percentage
 */
function calculateGrade(percentage) {
  if (percentage >= 90) return 'A+';
  if (percentage >= 80) return 'A';
  if (percentage >= 70) return 'B+';
  if (percentage >= 60) return 'B';
  if (percentage >= 50) return 'C';
  if (percentage >= 40) return 'D';
  return 'F';
}

/**
 * @route   GET /api/v1/marks
 * @desc    Get marks records
 * @access  Private
 */
router.get('/', [
  query('studentId').optional().isUUID(),
  query('subjectId').optional().isUUID(),
  query('classId').optional().isUUID(),
  query('examType').optional().isIn(['UNIT_TEST', 'MIDTERM', 'FINAL', 'ASSIGNMENT', 'PROJECT', 'QUIZ', 'OTHER'])
], asyncHandler(async (req, res) => {
  const { studentId, subjectId, classId, examType, page = 1, limit = 50 } = req.query;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  let where = { schoolId: req.user.schoolId };

  if (studentId) where.studentId = studentId;
  if (subjectId) where.subjectId = subjectId;
  if (examType) where.examType = examType;

  if (classId) {
    where.student = { classId };
  }

  const [marks, total] = await Promise.all([
    prisma.marks.findMany({
      where,
      include: {
        student: {
          select: {
            id: true,
            rollNumber: true,
            firstName: true,
            lastName: true,
            class: { select: { id: true, name: true, section: true } }
          }
        },
        subject: {
          select: { id: true, name: true, code: true }
        },
        teacher: {
          select: { id: true, firstName: true, lastName: true }
        }
      },
      skip,
      take: parseInt(limit),
      orderBy: [{ examDate: 'desc' }, { student: { rollNumber: 'asc' } }]
    }),
    prisma.marks.count({ where })
  ]);

  res.json({
    success: true,
    data: {
      marks,
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
 * @route   POST /api/v1/marks
 * @desc    Add marks for a student
 * @access  Private
 */
router.post('/', validators.marksCreate, asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const { studentId, subjectId, examType, examName, maxMarks, obtainedMarks, examDate, remarks } = req.body;

  // Verify student belongs to school
  const student = await prisma.student.findFirst({
    where: { id: studentId, schoolId: req.user.schoolId }
  });

  if (!student) {
    throw new AppError('Student not found', 404);
  }

  // Verify subject belongs to school
  const subject = await prisma.subject.findFirst({
    where: { id: subjectId, schoolId: req.user.schoolId }
  });

  if (!subject) {
    throw new AppError('Subject not found', 404);
  }

  // Validate marks
  if (obtainedMarks > maxMarks) {
    throw new AppError('Obtained marks cannot exceed maximum marks', 400);
  }

  const percentage = (obtainedMarks / maxMarks) * 100;
  const grade = calculateGrade(percentage);

  const marksRecord = await prisma.marks.create({
    data: {
      schoolId: req.user.schoolId,
      studentId,
      subjectId,
      teacherId: req.user.id,
      examType,
      examName,
      maxMarks,
      obtainedMarks,
      percentage,
      grade,
      remarks,
      examDate: new Date(examDate)
    }
  });

  // Create audit log
  await prisma.auditLog.create({
    data: {
      schoolId: req.user.schoolId,
      userId: req.user.id,
      action: 'CREATE',
      entityType: 'MARKS',
      entityId: marksRecord.id,
      newValue: { studentId, subjectId, examType, obtainedMarks, maxMarks }
    }
  });

  res.status(201).json({
    success: true,
    message: 'Marks added successfully',
    data: marksRecord
  });
}));

/**
 * @route   POST /api/v1/marks/bulk
 * @desc    Add marks for multiple students
 * @access  Private
 */
router.post('/bulk', [
  body('subjectId').isUUID(),
  body('examType').isIn(['UNIT_TEST', 'MIDTERM', 'FINAL', 'ASSIGNMENT', 'PROJECT', 'QUIZ', 'OTHER']),
  body('examName').trim().isLength({ min: 2, max: 100 }),
  body('maxMarks').isFloat({ min: 0 }),
  body('examDate').isISO8601(),
  body('records').isArray({ min: 1 }),
  body('records.*.studentId').isUUID(),
  body('records.*.obtainedMarks').isFloat({ min: 0 })
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const { subjectId, examType, examName, maxMarks, examDate, records } = req.body;

  // Verify subject belongs to school
  const subject = await prisma.subject.findFirst({
    where: { id: subjectId, schoolId: req.user.schoolId }
  });

  if (!subject) {
    throw new AppError('Subject not found', 404);
  }

  const results = await prisma.$transaction(async (tx) => {
    const savedRecords = [];

    for (const record of records) {
      if (record.obtainedMarks > maxMarks) {
        continue; // Skip invalid records
      }

      const percentage = (record.obtainedMarks / maxMarks) * 100;
      const grade = calculateGrade(percentage);

      const marksRecord = await tx.marks.create({
        data: {
          schoolId: req.user.schoolId,
          studentId: record.studentId,
          subjectId,
          teacherId: req.user.id,
          examType,
          examName,
          maxMarks,
          obtainedMarks: record.obtainedMarks,
          percentage,
          grade,
          remarks: record.remarks,
          examDate: new Date(examDate)
        }
      });

      savedRecords.push(marksRecord);
    }

    return savedRecords;
  });

  res.status(201).json({
    success: true,
    message: 'Marks added successfully',
    data: { count: results.length }
  });
}));

/**
 * @route   PUT /api/v1/marks/:id
 * @desc    Update marks record
 * @access  Private
 */
router.put('/:id', [
  param('id').isUUID(),
  body('obtainedMarks').optional().isFloat({ min: 0 }),
  body('maxMarks').optional().isFloat({ min: 0 }),
  body('remarks').optional().trim()
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
  const { obtainedMarks, maxMarks, remarks } = req.body;

  const record = await prisma.marks.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!record) {
    throw new AppError('Marks record not found', 404);
  }

  const oldValue = {
    obtainedMarks: record.obtainedMarks,
    maxMarks: record.maxMarks,
    remarks: record.remarks
  };

  const newMaxMarks = maxMarks || record.maxMarks;
  const newObtainedMarks = obtainedMarks !== undefined ? obtainedMarks : record.obtainedMarks;

  if (newObtainedMarks > newMaxMarks) {
    throw new AppError('Obtained marks cannot exceed maximum marks', 400);
  }

  const percentage = (newObtainedMarks / newMaxMarks) * 100;
  const grade = calculateGrade(percentage);

  const updated = await prisma.marks.update({
    where: { id },
    data: {
      obtainedMarks: newObtainedMarks,
      maxMarks: newMaxMarks,
      percentage,
      grade,
      remarks
    }
  });

  // Create audit log
  await prisma.auditLog.create({
    data: {
      schoolId: req.user.schoolId,
      userId: req.user.id,
      action: 'UPDATE',
      entityType: 'MARKS',
      entityId: id,
      oldValue,
      newValue: { obtainedMarks: newObtainedMarks, maxMarks: newMaxMarks, remarks }
    }
  });

  res.json({
    success: true,
    message: 'Marks updated successfully',
    data: updated
  });
}));

/**
 * @route   GET /api/v1/marks/student/:studentId/report
 * @desc    Get student marks report
 * @access  Private
 */
router.get('/student/:studentId/report', [
  param('studentId').isUUID()
], asyncHandler(async (req, res) => {
  const { studentId } = req.params;

  const student = await prisma.student.findFirst({
    where: { id: studentId, schoolId: req.user.schoolId },
    include: { class: true }
  });

  if (!student) {
    throw new AppError('Student not found', 404);
  }

  const marks = await prisma.marks.findMany({
    where: { studentId, schoolId: req.user.schoolId },
    include: {
      subject: { select: { id: true, name: true, code: true } }
    },
    orderBy: [{ subject: { name: 'asc' } }, { examDate: 'desc' }]
  });

  // Group by subject
  const subjectWise = {};
  marks.forEach(m => {
    if (!subjectWise[m.subjectId]) {
      subjectWise[m.subjectId] = {
        subject: m.subject,
        exams: [],
        totalObtained: 0,
        totalMax: 0
      };
    }
    subjectWise[m.subjectId].exams.push(m);
    subjectWise[m.subjectId].totalObtained += m.obtainedMarks;
    subjectWise[m.subjectId].totalMax += m.maxMarks;
  });

  // Calculate overall
  const subjects = Object.values(subjectWise).map(s => ({
    ...s,
    percentage: s.totalMax > 0 ? (s.totalObtained / s.totalMax) * 100 : 0,
    grade: s.totalMax > 0 ? calculateGrade((s.totalObtained / s.totalMax) * 100) : 'N/A'
  }));

  const totalObtained = subjects.reduce((sum, s) => sum + s.totalObtained, 0);
  const totalMax = subjects.reduce((sum, s) => sum + s.totalMax, 0);

  res.json({
    success: true,
    data: {
      student: {
        id: student.id,
        rollNumber: student.rollNumber,
        name: `${student.firstName} ${student.lastName}`,
        class: student.class
      },
      subjects,
      overall: {
        totalObtained,
        totalMax,
        percentage: totalMax > 0 ? (totalObtained / totalMax) * 100 : 0,
        grade: totalMax > 0 ? calculateGrade((totalObtained / totalMax) * 100) : 'N/A'
      }
    }
  });
}));

/**
 * @route   DELETE /api/v1/marks/:id
 * @desc    Delete marks record
 * @access  Private (Principal only)
 */
router.delete('/:id', [param('id').isUUID()], asyncHandler(async (req, res) => {
  const { id } = req.params;

  const record = await prisma.marks.findFirst({
    where: { id, schoolId: req.user.schoolId }
  });

  if (!record) {
    throw new AppError('Marks record not found', 404);
  }

  // Only principal or the teacher who created can delete
  if (req.user.role !== 'PRINCIPAL' && record.teacherId !== req.user.id) {
    throw new AppError('Insufficient permissions', 403);
  }

  await prisma.marks.delete({ where: { id } });

  res.json({
    success: true,
    message: 'Marks record deleted successfully'
  });
}));

module.exports = router;

