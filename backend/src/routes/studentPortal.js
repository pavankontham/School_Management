const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { query, param, validationResult } = require('express-validator');

const { asyncHandler, AppError } = require('../middleware/errorHandler');
const { getFileUrl } = require('../middleware/upload');

const router = express.Router();
const prisma = new PrismaClient();

/**
 * @route   GET /api/v1/student/profile
 * @desc    Get student profile
 * @access  Private (Student)
 */
router.get('/profile', asyncHandler(async (req, res) => {
  const student = await prisma.student.findUnique({
    where: { id: req.student.id },
    include: {
      class: {
        include: {
          subjects: {
            include: {
              subject: { select: { id: true, name: true, code: true } }
            }
          }
        }
      },
      school: {
        select: { id: true, name: true, logo: true }
      }
    }
  });

  if (!student) {
    throw new AppError('Student not found', 404);
  }

  // Remove sensitive data
  const { password, faceEncoding, ...safeStudent } = student;

  res.json({
    success: true,
    data: {
      ...safeStudent,
      photoUrl: student.photo ? getFileUrl(student.photo, req) : null
    }
  });
}));

/**
 * @route   GET /api/v1/student/attendance
 * @desc    Get student's attendance records
 * @access  Private (Student)
 */
router.get('/attendance', [
  query('month').optional().isInt({ min: 1, max: 12 }),
  query('year').optional().isInt({ min: 2020, max: 2100 })
], asyncHandler(async (req, res) => {
  const student = req.student;
  const { month, year } = req.query;

  let where = { studentId: student.id };

  if (month && year) {
    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0);
    where.date = {
      gte: startDate,
      lte: endDate
    };
  }

  const attendance = await prisma.attendance.findMany({
    where,
    orderBy: { date: 'desc' },
    take: 100
  });

  // Calculate summary
  const summary = {
    total: attendance.length,
    present: attendance.filter(a => a.status === 'PRESENT').length,
    absent: attendance.filter(a => a.status === 'ABSENT').length,
    late: attendance.filter(a => a.status === 'LATE').length,
    excused: attendance.filter(a => a.status === 'EXCUSED').length
  };

  summary.percentage = summary.total > 0 
    ? Math.round(((summary.present + summary.late) / summary.total) * 100)
    : 0;

  res.json({
    success: true,
    data: {
      records: attendance,
      summary
    }
  });
}));

/**
 * @route   GET /api/v1/student/marks
 * @desc    Get student's marks
 * @access  Private (Student)
 */
router.get('/marks', [
  query('subjectId').optional().isUUID(),
  query('examType').optional().isIn(['QUIZ', 'UNIT_TEST', 'MID_TERM', 'FINAL', 'ASSIGNMENT', 'PROJECT', 'PRACTICAL', 'OTHER'])
], asyncHandler(async (req, res) => {
  const student = req.student;
  const { subjectId, examType } = req.query;

  let where = { studentId: student.id };
  if (subjectId) where.subjectId = subjectId;
  if (examType) where.examType = examType;

  const marks = await prisma.marks.findMany({
    where,
    include: {
      subject: { select: { id: true, name: true, code: true } },
      teacher: { select: { id: true, firstName: true, lastName: true } }
    },
    orderBy: [{ examDate: 'desc' }, { createdAt: 'desc' }]
  });

  // Group by subject
  const bySubject = {};
  marks.forEach(mark => {
    const subjectName = mark.subject.name;
    if (!bySubject[subjectName]) {
      bySubject[subjectName] = {
        subject: mark.subject,
        marks: [],
        average: 0
      };
    }
    bySubject[subjectName].marks.push(mark);
  });

  // Calculate averages
  Object.values(bySubject).forEach(subjectData => {
    const percentages = subjectData.marks.map(m => m.percentage);
    subjectData.average = percentages.length > 0
      ? Math.round(percentages.reduce((a, b) => a + b, 0) / percentages.length * 100) / 100
      : 0;
  });

  res.json({
    success: true,
    data: {
      marks,
      bySubject: Object.values(bySubject)
    }
  });
}));

/**
 * @route   GET /api/v1/student/report-card
 * @desc    Get student's report card
 * @access  Private (Student)
 */
router.get('/report-card', asyncHandler(async (req, res) => {
  const student = await prisma.student.findUnique({
    where: { id: req.student.id },
    include: {
      class: true,
      school: { select: { name: true, logo: true } }
    }
  });

  // Get all marks grouped by subject
  const marks = await prisma.marks.findMany({
    where: { studentId: student.id },
    include: {
      subject: true
    },
    orderBy: { examDate: 'desc' }
  });

  // Get attendance summary
  const attendance = await prisma.attendance.findMany({
    where: { studentId: student.id }
  });

  const attendanceSummary = {
    total: attendance.length,
    present: attendance.filter(a => a.status === 'PRESENT').length,
    absent: attendance.filter(a => a.status === 'ABSENT').length,
    late: attendance.filter(a => a.status === 'LATE').length,
    percentage: 0
  };
  attendanceSummary.percentage = attendanceSummary.total > 0
    ? Math.round(((attendanceSummary.present + attendanceSummary.late) / attendanceSummary.total) * 100)
    : 0;

  // Group marks by subject and calculate grades
  const subjectGrades = {};
  marks.forEach(mark => {
    const subjectId = mark.subjectId;
    if (!subjectGrades[subjectId]) {
      subjectGrades[subjectId] = {
        subject: mark.subject,
        marks: [],
        totalObtained: 0,
        totalMax: 0
      };
    }
    subjectGrades[subjectId].marks.push(mark);
    subjectGrades[subjectId].totalObtained += mark.marksObtained;
    subjectGrades[subjectId].totalMax += mark.maxMarks;
  });

  // Calculate final grades
  const subjects = Object.values(subjectGrades).map(sg => {
    const percentage = sg.totalMax > 0 ? (sg.totalObtained / sg.totalMax) * 100 : 0;
    return {
      subject: sg.subject,
      totalObtained: sg.totalObtained,
      totalMax: sg.totalMax,
      percentage: Math.round(percentage * 100) / 100,
      grade: calculateGrade(percentage),
      examCount: sg.marks.length
    };
  });

  // Overall performance
  const totalObtained = subjects.reduce((sum, s) => sum + s.totalObtained, 0);
  const totalMax = subjects.reduce((sum, s) => sum + s.totalMax, 0);
  const overallPercentage = totalMax > 0 ? (totalObtained / totalMax) * 100 : 0;

  res.json({
    success: true,
    data: {
      student: {
        id: student.id,
        rollNumber: student.rollNumber,
        name: `${student.firstName} ${student.lastName}`,
        class: student.class,
        photo: student.photo ? getFileUrl(student.photo, req) : null
      },
      school: student.school,
      subjects,
      overall: {
        totalObtained,
        totalMax,
        percentage: Math.round(overallPercentage * 100) / 100,
        grade: calculateGrade(overallPercentage)
      },
      attendance: attendanceSummary,
      generatedAt: new Date().toISOString()
    }
  });
}));

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
 * @route   GET /api/v1/student/remarks
 * @desc    Get student's remarks
 * @access  Private (Student)
 */
router.get('/remarks', asyncHandler(async (req, res) => {
  const remarks = await prisma.remark.findMany({
    where: { studentId: req.student.id },
    include: {
      teacher: { select: { id: true, firstName: true, lastName: true } },
      subject: { select: { id: true, name: true } }
    },
    orderBy: { createdAt: 'desc' }
  });

  res.json({
    success: true,
    data: remarks
  });
}));

/**
 * @route   GET /api/v1/student/textbooks
 * @desc    Get textbooks for student's class
 * @access  Private (Student)
 */
router.get('/textbooks', asyncHandler(async (req, res) => {
  const student = req.student;

  // Get subjects for student's class
  const classSubjects = await prisma.classSubject.findMany({
    where: { classId: student.classId },
    select: { subjectId: true }
  });

  const subjectIds = classSubjects.map(cs => cs.subjectId);

  const textbooks = await prisma.textbook.findMany({
    where: {
      schoolId: student.schoolId,
      subjectId: { in: subjectIds },
      isActive: true
    },
    include: {
      subject: { select: { id: true, name: true, code: true } }
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

/**
 * @route   GET /api/v1/student/notifications
 * @desc    Get student's notifications
 * @access  Private (Student)
 */
router.get('/notifications', asyncHandler(async (req, res) => {
  const { page = 1, limit = 20 } = req.query;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  const [notifications, total] = await Promise.all([
    prisma.studentNotification.findMany({
      where: { studentId: req.student.id },
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
    prisma.studentNotification.count({ where: { studentId: req.student.id } })
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
 * @route   PUT /api/v1/student/notifications/:id/read
 * @desc    Mark notification as read
 * @access  Private (Student)
 */
router.put('/notifications/:id/read', [param('id').isUUID()], asyncHandler(async (req, res) => {
  await prisma.studentNotification.updateMany({
    where: { id: req.params.id, studentId: req.student.id },
    data: { isRead: true, readAt: new Date() }
  });

  res.json({ success: true, message: 'Notification marked as read' });
}));

/**
 * @route   GET /api/v1/student/dashboard
 * @desc    Get student dashboard posts
 * @access  Private (Student)
 */
router.get('/dashboard', asyncHandler(async (req, res) => {
  const posts = await prisma.dashboardPost.findMany({
    where: {
      schoolId: req.student.schoolId,
      isPublished: true
    },
    include: {
      author: { select: { id: true, firstName: true, lastName: true } }
    },
    orderBy: [{ isPinned: 'desc' }, { createdAt: 'desc' }],
    take: 20
  });

  res.json({
    success: true,
    data: posts.map(p => ({
      ...p,
      mediaUrls: p.mediaUrls ? p.mediaUrls.map(url => getFileUrl(url, req)) : []
    }))
  });
}));

module.exports = router;

