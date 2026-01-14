const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { body, param, validationResult } = require('express-validator');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const { asyncHandler, AppError } = require('../middleware/errorHandler');
const { requireRole } = require('../middleware/auth');

const router = express.Router();
const prisma = new PrismaClient();

// Configure multer for face photo uploads
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        const dir = path.join(process.env.UPLOAD_DIR || './uploads', 'faces');
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        cb(null, dir);
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1E9)}`;
        cb(null, `face-${uniqueSuffix}${path.extname(file.originalname)}`);
    }
});

const upload = multer({
    storage,
    limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
    fileFilter: (req, file, cb) => {
        const allowedTypes = /jpeg|jpg|png/;
        const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
        const mimetype = allowedTypes.test(file.mimetype);
        if (extname && mimetype) {
            cb(null, true);
        } else {
            cb(new Error('Only image files (JPEG, JPG, PNG) are allowed'));
        }
    }
});

/**
 * @route   POST /api/v1/face-recognition/upload-reference
 * @desc    Upload student reference face photo
 * @access  Private (Principal/Teacher)
 */
router.post('/upload-reference', requireRole(['PRINCIPAL', 'TEACHER']), upload.single('photo'), asyncHandler(async (req, res) => {
    if (!req.file) {
        throw new AppError('No photo uploaded', 400);
    }

    const { studentId } = req.body;

    if (!studentId) {
        fs.unlinkSync(req.file.path);
        throw new AppError('Student ID is required', 400);
    }

    // Verify student exists
    const student = await prisma.student.findFirst({
        where: {
            id: studentId,
            schoolId: req.user.schoolId
        }
    });

    if (!student) {
        fs.unlinkSync(req.file.path);
        throw new AppError('Student not found', 404);
    }

    // Generate face encoding using ML service
    try {
        const FormData = require('form-data');
        const axios = require('axios');

        const formData = new FormData();
        formData.append('photo', fs.createReadStream(req.file.path));

        const mlResponse = await axios.post(
            `${process.env.ML_SERVICE_URL || 'http://localhost:5000'}/encode`,
            formData,
            {
                headers: {
                    ...formData.getHeaders(),
                    'X-API-Key': process.env.ML_SERVICE_API_KEY || ''
                },
                timeout: 30000
            }
        );

        if (!mlResponse.data.success) {
            fs.unlinkSync(req.file.path);
            throw new AppError(mlResponse.data.error || 'Failed to generate face encoding', 400);
        }

        const faceEncoding = mlResponse.data.encoding;

        // Update student with face photo and encoding
        const updated = await prisma.student.update({
            where: { id: studentId },
            data: {
                profileImage: req.file.path,
                faceEncoding: JSON.stringify(faceEncoding)
            }
        });

        res.json({
            success: true,
            message: 'Reference photo uploaded successfully',
            data: {
                studentId: updated.id,
                photoPath: req.file.path
            }
        });
    } catch (error) {
        // Clean up file on error
        if (fs.existsSync(req.file.path)) {
            fs.unlinkSync(req.file.path);
        }
        if (error.response?.data?.error) {
            throw new AppError(error.response.data.error, 400);
        }
        throw error;
    }
}));

/**
 * @route   POST /api/v1/face-recognition/mark-attendance
 * @desc    Mark attendance using a group photo
 * @access  Private (Teacher/Principal)
 * Note: Upload a single group photo containing multiple students.
 *       The system will detect and recognize faces, marking students as present/absent.
 */
router.post('/mark-attendance', requireRole(['TEACHER', 'PRINCIPAL']), upload.array('photos', 10), asyncHandler(async (req, res) => {
    if (!req.files || req.files.length === 0) {
        throw new AppError('No photos uploaded', 400);
    }

    const { classId, date, session } = req.body; // session: 'MORNING' or 'AFTERNOON'

    if (!classId || !date) {
        // Clean up uploaded files
        req.files.forEach(file => fs.unlinkSync(file.path));
        throw new AppError('Class ID and date are required', 400);
    }

    // Verify class exists
    const classRecord = await prisma.class.findFirst({
        where: {
            id: classId,
            schoolId: req.user.schoolId
        },
        include: {
            students: {
                where: { isActive: true },
                select: {
                    id: true,
                    firstName: true,
                    lastName: true,
                    rollNumber: true,
                    profileImage: true,
                    faceEncoding: true
                }
            }
        }
    });

    if (!classRecord) {
        req.files.forEach(file => fs.unlinkSync(file.path));
        throw new AppError('Class not found', 404);
    }

    // Process photos with face recognition ML service
    try {
        const FormData = require('form-data');
        const axios = require('axios');

        // Prepare known faces data
        const studentsWithEncodings = classRecord.students
            .filter(s => s.faceEncoding)
            .map(s => ({
                id: s.id,
                rollNumber: s.rollNumber,
                name: `${s.firstName} ${s.lastName}`,
                encoding: JSON.parse(s.faceEncoding)
            }));

        if (studentsWithEncodings.length === 0) {
            req.files.forEach(file => fs.unlinkSync(file.path));
            throw new AppError('No students have registered face encodings', 400);
        }

        // Process the first photo (group photo)
        // Note: If multiple photos are uploaded, we'll process the first one
        const photoFile = req.files[0];

        const formData = new FormData();
        formData.append('image', fs.createReadStream(photoFile.path));
        formData.append('known_faces', JSON.stringify(studentsWithEncodings));
        formData.append('threshold', '0.75'); // 75% confidence threshold

        const mlResponse = await axios.post(
            `${process.env.ML_SERVICE_URL || 'http://localhost:5000'}/recognize`,
            formData,
            {
                headers: {
                    ...formData.getHeaders(),
                    'X-API-Key': process.env.ML_SERVICE_API_KEY || ''
                },
                timeout: 60000 // 60 seconds for processing
            }
        );

        if (!mlResponse.data.success) {
            req.files.forEach(file => fs.unlinkSync(file.path));
            throw new AppError(mlResponse.data.message || 'Failed to process photo', 400);
        }

        const recognizedStudents = mlResponse.data.recognized || [];
        const recognizedIds = new Set(recognizedStudents.map(r => r.id));

        // Map results to all students
        const allStudents = classRecord.students.map(s => {
            const recognized = recognizedStudents.find(r => r.id === s.id);

            if (recognized) {
                // Student was detected in photo
                return {
                    id: s.id,
                    name: `${s.firstName} ${s.lastName}`,
                    rollNumber: s.rollNumber,
                    detected: true,
                    confidence: recognized.confidence,
                    status: 'PRESENT'
                };
            } else {
                // Student not detected (either no face encoding or not in photo)
                return {
                    id: s.id,
                    name: `${s.firstName} ${s.lastName}`,
                    rollNumber: s.rollNumber,
                    detected: false,
                    confidence: 0,
                    status: 'ABSENT',
                    reason: s.faceEncoding ? 'Not detected in photo' : 'No face encoding registered'
                };
            }
        });

        res.json({
            success: true,
            message: 'Photo processed. Please review and confirm attendance.',
            data: {
                classId,
                date,
                session,
                totalStudents: classRecord.students.length,
                totalDetected: mlResponse.data.total_faces_detected || 0,
                totalMatched: recognizedStudents.length,
                studentsWithEncodings: studentsWithEncodings.length,
                students: allStudents,
                processingTime: mlResponse.data.processing_time_ms
            }
        });
    } catch (error) {
        // Clean up files on error
        req.files.forEach(file => {
            if (fs.existsSync(file.path)) {
                fs.unlinkSync(file.path);
            }
        });

        if (error.response?.data?.detail) {
            throw new AppError(error.response.data.detail, 400);
        }
        throw error;
    }
}));

/**
 * @route   POST /api/v1/face-recognition/confirm-attendance
 * @desc    Confirm and save attendance after review
 * @access  Private (Teacher/Principal)
 */
router.post('/confirm-attendance', requireRole(['TEACHER', 'PRINCIPAL']), [
    body('classId').isUUID(),
    body('date').isISO8601(),
    body('attendance').isArray(),
    body('attendance.*.studentId').isUUID(),
    body('attendance.*.status').isIn(['PRESENT', 'ABSENT', 'LATE', 'EXCUSED'])
], asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({
            success: false,
            message: 'Validation failed',
            errors: errors.array()
        });
    }

    const { classId, date, attendance, method = 'FACE_RECOGNITION' } = req.body;

    // Verify class
    const classRecord = await prisma.class.findFirst({
        where: {
            id: classId,
            schoolId: req.user.schoolId
        }
    });

    if (!classRecord) {
        throw new AppError('Class not found', 404);
    }

    const attendanceDate = new Date(date);
    attendanceDate.setHours(0, 0, 0, 0);

    // Create attendance records
    const attendanceRecords = await Promise.all(
        attendance.map(async (record) => {
            // Check if attendance already exists for this student on this date
            const existing = await prisma.attendance.findFirst({
                where: {
                    studentId: record.studentId,
                    date: attendanceDate
                }
            });

            if (existing) {
                // Update existing
                return prisma.attendance.update({
                    where: { id: existing.id },
                    data: {
                        status: record.status,
                        method,
                        confidence: record.confidence || null,
                        remarks: record.remarks || null,
                        teacherId: req.user.id
                    }
                });
            } else {
                // Create new
                return prisma.attendance.create({
                    data: {
                        schoolId: req.user.schoolId,
                        classId,
                        studentId: record.studentId,
                        teacherId: req.user.id,
                        date: attendanceDate,
                        status: record.status,
                        method,
                        confidence: record.confidence || null,
                        remarks: record.remarks || null
                    }
                });
            }
        })
    );

    // Send notifications
    await sendAttendanceNotifications(classId, attendanceDate, attendanceRecords, req.user);

    res.json({
        success: true,
        message: 'Attendance marked successfully',
        data: {
            totalRecords: attendanceRecords.length,
            date: attendanceDate
        }
    });
}));

/**
 * Send attendance notifications to principal, teacher, and students
 */
async function sendAttendanceNotifications(classId, date, attendanceRecords, teacher) {
    try {
        const classRecord = await prisma.class.findUnique({
            where: { id: classId },
            include: {
                students: {
                    where: { isActive: true },
                    select: { id: true, firstName: true, lastName: true, parentPhone: true, parentEmail: true }
                }
            }
        });

        const presentCount = attendanceRecords.filter(r => r.status === 'PRESENT').length;
        const absentCount = attendanceRecords.filter(r => r.status === 'ABSENT').length;

        // Get principal
        const principal = await prisma.user.findFirst({
            where: {
                schoolId: teacher.schoolId,
                role: 'PRINCIPAL',
                isActive: true
            }
        });

        // Create notification for principal and teacher
        const notification = await prisma.notification.create({
            data: {
                schoolId: teacher.schoolId,
                senderId: teacher.id,
                title: `Attendance Marked - ${classRecord.name}`,
                message: `Attendance has been marked for ${classRecord.name} on ${date.toLocaleDateString()}. Present: ${presentCount}, Absent: ${absentCount}`,
                type: 'ATTENDANCE',
                targetType: 'CLASS',
                classId,
                priority: 'NORMAL',
                channels: ['IN_APP', 'EMAIL'],
                status: 'SENT',
                sentAt: new Date()
            }
        });

        // Send to principal
        if (principal) {
            await prisma.userNotification.create({
                data: {
                    notificationId: notification.id,
                    userId: principal.id
                }
            });
        }

        // Send to teacher (if different from sender)
        if (teacher.role !== 'PRINCIPAL') {
            await prisma.userNotification.create({
                data: {
                    notificationId: notification.id,
                    userId: teacher.id
                }
            });
        }

        // Send individual notifications to students
        for (const record of attendanceRecords) {
            const student = classRecord.students.find(s => s.id === record.studentId);
            if (!student) continue;

            const studentNotification = await prisma.notification.create({
                data: {
                    schoolId: teacher.schoolId,
                    senderId: teacher.id,
                    title: 'Attendance Update',
                    message: `Your attendance for ${date.toLocaleDateString()} has been marked as ${record.status}`,
                    type: 'ATTENDANCE',
                    targetType: 'INDIVIDUAL',
                    classId,
                    priority: record.status === 'ABSENT' ? 'HIGH' : 'NORMAL',
                    channels: ['IN_APP', 'SMS', 'EMAIL'],
                    status: 'SENT',
                    sentAt: new Date()
                }
            });

            await prisma.studentNotification.create({
                data: {
                    notificationId: studentNotification.id,
                    studentId: student.id
                }
            });

            // Send Email to parent
            if (student.parentEmail) {
                const { sendAttendanceEmail } = require('../services/emailService');
                await sendAttendanceEmail({
                    parentEmail: student.parentEmail,
                    studentName: `${student.firstName} ${student.lastName}`,
                    date: date.toLocaleDateString(),
                    status: record.status,
                    teacherName: teacher.fullName || `${teacher.firstName} ${teacher.lastName}`,
                    teacherEmail: teacher.email
                });
            }
        }
    } catch (error) {
        console.error('Error sending attendance notifications:', error);
    }
}

module.exports = router;
