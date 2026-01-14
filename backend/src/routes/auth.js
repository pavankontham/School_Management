const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const { body, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');

const logger = require('../utils/logger');
const { asyncHandler, AppError } = require('../middleware/errorHandler');
const validators = require('../utils/validators');

const router = express.Router();
const prisma = new PrismaClient();

// Token generation helpers
function generateAccessToken(payload) {
  return jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '15m'
  });
}

function generateRefreshToken(payload) {
  return jwt.sign(payload, process.env.JWT_REFRESH_SECRET, {
    expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d'
  });
}

/**
 * @route   POST /api/v1/auth/register-school
 * @desc    Register a new school with principal account
 * @access  Public
 */
router.post('/register-school', [
  ...validators.schoolRegistration,
  validators.email,
  validators.password,
  validators.firstName,
  validators.lastName,
  validators.phone
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
    schoolName, address, city, state, country, postalCode,
    schoolPhone, schoolEmail, website,
    email, password, firstName, lastName, phone
  } = req.body;

  // Check if school email already exists
  const existingSchool = await prisma.school.findUnique({
    where: { email: schoolEmail }
  });

  if (existingSchool) {
    throw new AppError('A school with this email already exists', 409);
  }

  // Check if user email already exists
  const existingUser = await prisma.user.findUnique({
    where: { email }
  });

  if (existingUser) {
    throw new AppError('A user with this email already exists', 409);
  }

  // Hash password
  const hashedPassword = await bcrypt.hash(password, 12);

  // Create school and principal in a transaction
  const result = await prisma.$transaction(async (tx) => {
    // Create school
    const school = await tx.school.create({
      data: {
        name: schoolName,
        address,
        city,
        state,
        country,
        postalCode,
        phone: schoolPhone,
        email: schoolEmail,
        website
      }
    });

    // Create principal user
    const user = await tx.user.create({
      data: {
        schoolId: school.id,
        email,
        phone,
        password: hashedPassword,
        firstName,
        lastName,
        role: 'PRINCIPAL'
      }
    });

    // Generate tokens
    const accessToken = generateAccessToken({
      userId: user.id,
      schoolId: school.id,
      role: user.role
    });

    const refreshToken = generateRefreshToken({
      userId: user.id,
      schoolId: school.id
    });

    // Store refresh token
    const expiresAt = new Date();
    const refreshExpiryDays = parseInt(process.env.JWT_REFRESH_EXPIRES_IN?.replace('d', '')) || 7;
    expiresAt.setDate(expiresAt.getDate() + refreshExpiryDays);

    await tx.refreshToken.create({
      data: {
        userId: user.id,
        token: refreshToken,
        expiresAt
      }
    });

    return { school, user, accessToken, refreshToken };
  });

  logger.info(`New school registered: ${result.school.name} by ${result.user.email}`);

  res.status(201).json({
    success: true,
    message: 'School registered successfully',
    data: {
      school: {
        id: result.school.id,
        name: result.school.name,
        email: result.school.email
      },
      user: {
        id: result.user.id,
        email: result.user.email,
        firstName: result.user.firstName,
        lastName: result.user.lastName,
        role: result.user.role
      },
      accessToken: result.accessToken,
      refreshToken: result.refreshToken
    }
  });
}));

/**
 * @route   POST /api/v1/auth/login
 * @desc    Login user (Principal/Teacher)
 * @access  Public
 */
router.post('/login', [
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const { email, password } = req.body;

  // Find user
  const user = await prisma.user.findUnique({
    where: { email },
    include: {
      school: {
        select: {
          id: true,
          name: true,
          isActive: true
        }
      }
    }
  });

  if (!user) {
    throw new AppError('Invalid email or password', 401);
  }

  if (!user.isActive) {
    throw new AppError('Your account has been deactivated', 403);
  }

  if (!user.school.isActive) {
    throw new AppError('Your school has been deactivated', 403);
  }

  // Verify password
  const isValidPassword = await bcrypt.compare(password, user.password);
  if (!isValidPassword) {
    throw new AppError('Invalid email or password', 401);
  }

  // Generate tokens
  const accessToken = generateAccessToken({
    userId: user.id,
    schoolId: user.schoolId,
    role: user.role
  });

  const refreshToken = generateRefreshToken({
    userId: user.id,
    schoolId: user.schoolId
  });

  // Store refresh token
  const expiresAt = new Date();
  const refreshExpiryDays = parseInt(process.env.JWT_REFRESH_EXPIRES_IN?.replace('d', '')) || 7;
  expiresAt.setDate(expiresAt.getDate() + refreshExpiryDays);

  await prisma.refreshToken.create({
    data: {
      userId: user.id,
      token: refreshToken,
      expiresAt
    }
  });

  // Update last login
  await prisma.user.update({
    where: { id: user.id },
    data: { lastLogin: new Date() }
  });

  logger.info(`User logged in: ${user.email}`);

  res.json({
    success: true,
    message: 'Login successful',
    data: {
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        role: user.role,
        school: user.school
      },
      accessToken,
      refreshToken
    }
  });
}));

/**
 * @route   POST /api/v1/auth/login-student
 * @desc    Login student
 * @access  Public
 */
router.post('/login-student', [
  body('schoolId').isUUID(),
  body('rollNumber').notEmpty(),
  body('password').notEmpty()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const { schoolId, rollNumber, password } = req.body;

  // Find student
  const student = await prisma.student.findFirst({
    where: {
      schoolId,
      rollNumber
    },
    include: {
      school: {
        select: { id: true, name: true, isActive: true }
      },
      class: {
        select: { id: true, name: true, section: true, grade: true }
      }
    }
  });

  if (!student) {
    throw new AppError('Invalid credentials', 401);
  }

  if (!student.isActive) {
    throw new AppError('Your account has been deactivated', 403);
  }

  if (!student.school.isActive) {
    throw new AppError('Your school has been deactivated', 403);
  }

  // Verify password
  const isValidPassword = await bcrypt.compare(password, student.password);
  if (!isValidPassword) {
    throw new AppError('Invalid credentials', 401);
  }

  // Generate tokens
  const accessToken = generateAccessToken({
    studentId: student.id,
    schoolId: student.schoolId,
    classId: student.classId,
    type: 'student'
  });

  const refreshToken = generateRefreshToken({
    studentId: student.id,
    schoolId: student.schoolId,
    type: 'student'
  });

  // Store student refresh token
  const expiresAt = new Date();
  const refreshExpiryDays = parseInt(process.env.JWT_REFRESH_EXPIRES_IN?.replace('d', '')) || 7;
  expiresAt.setDate(expiresAt.getDate() + refreshExpiryDays);

  await prisma.studentRefreshToken.create({
    data: {
      studentId: student.id,
      token: refreshToken,
      expiresAt
    }
  });

  logger.info(`Student logged in: ${student.rollNumber} from school ${schoolId}`);

  res.json({
    success: true,
    message: 'Login successful',
    data: {
      student: {
        id: student.id,
        rollNumber: student.rollNumber,
        firstName: student.firstName,
        lastName: student.lastName,
        school: student.school,
        class: student.class
      },
      accessToken,
      refreshToken
    }
  });
}));

/**
 * @route   POST /api/v1/auth/refresh
 * @desc    Refresh access token (for both users and students)
 * @access  Public
 */
router.post('/refresh', [
  body('refreshToken').notEmpty()
], asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;

  // Verify refresh token
  let decoded;
  try {
    decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
  } catch (error) {
    throw new AppError('Invalid refresh token', 401);
  }

  // Check if this is a student or user token
  const isStudent = decoded.type === 'student' && decoded.studentId;

  if (isStudent) {
    // Handle student refresh token
    const storedToken = await prisma.studentRefreshToken.findUnique({
      where: { token: refreshToken }
    });

    if (!storedToken || storedToken.expiresAt < new Date()) {
      if (storedToken) {
        await prisma.studentRefreshToken.delete({ where: { id: storedToken.id } });
      }
      throw new AppError('Refresh token expired', 401);
    }

    // Generate new access token for student
    const accessToken = generateAccessToken({
      studentId: decoded.studentId,
      schoolId: decoded.schoolId,
      classId: decoded.classId,
      type: 'student'
    });

    res.json({
      success: true,
      data: { accessToken }
    });
  } else {
    // Handle user refresh token
    const storedToken = await prisma.refreshToken.findUnique({
      where: { token: refreshToken }
    });

    if (!storedToken || storedToken.expiresAt < new Date()) {
      if (storedToken) {
        await prisma.refreshToken.delete({ where: { id: storedToken.id } });
      }
      throw new AppError('Refresh token expired', 401);
    }

    // Fetch user to get current role
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      select: { role: true }
    });

    if (!user) {
      throw new AppError('User not found', 404);
    }

    // Generate new access token for user
    const accessToken = generateAccessToken({
      userId: decoded.userId,
      schoolId: decoded.schoolId,
      role: user.role
    });

    res.json({
      success: true,
      data: { accessToken }
    });
  }
}));

/**
 * @route   GET /api/v1/auth/school/:schoolId
 * @desc    Get school information by ID (for student login)
 * @access  Public
 */
router.get('/school/:schoolId', asyncHandler(async (req, res) => {
  const { schoolId } = req.params;

  const school = await prisma.school.findUnique({
    where: { id: schoolId },
    select: {
      id: true,
      name: true,
      address: true,
      city: true,
      state: true,
      country: true,
      phone: true,
      email: true,
      website: true,
      logo: true,
      isActive: true,
      createdAt: true
    }
  });

  if (!school) {
    throw new AppError('School not found', 404);
  }

  if (!school.isActive) {
    throw new AppError('This school is currently inactive', 403);
  }

  res.json({
    success: true,
    data: school
  });
}));

/**
 * @route   POST /api/v1/auth/logout
 * @desc    Logout user or student
 * @access  Public
 */
router.post('/logout', [
  body('refreshToken').notEmpty()
], asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;

  // Delete refresh token from both tables (only one will match)
  await Promise.all([
    prisma.refreshToken.deleteMany({
      where: { token: refreshToken }
    }),
    prisma.studentRefreshToken.deleteMany({
      where: { token: refreshToken }
    })
  ]);

  res.json({
    success: true,
    message: 'Logged out successfully'
  });
}));

/**
 * @route   POST /api/v1/auth/forgot-password
 * @desc    Request password reset
 * @access  Public
 */
router.post('/forgot-password', [
  body('email').isEmail().normalizeEmail()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Valid email is required',
      errors: errors.array()
    });
  }

  const { email } = req.body;

  // Find user
  const user = await prisma.user.findUnique({
    where: { email }
  });

  // Always return success to prevent email enumeration
  if (!user) {
    return res.json({
      success: true,
      message: 'If an account exists with this email, a password reset link has been sent'
    });
  }

  // Generate reset token (valid for 1 hour)
  const resetToken = uuidv4();
  const resetTokenExpiry = new Date(Date.now() + 3600000); // 1 hour

  // Store reset token in database
  await prisma.passwordReset.create({
    data: {
      email: user.email,
      token: resetToken,
      expiresAt: resetTokenExpiry
    }
  });

  // Send email with reset link
  const resetUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/reset-password?token=${resetToken}`;


  const emailService = require('../services/emailService');
  await emailService.sendPasswordResetEmail({
    email: user.email,
    resetToken,
    resetUrl,
    schoolId: user.schoolId // Use school's email as sender
  });

  logger.info(`Password reset requested for ${email}`);

  res.json({
    success: true,
    message: 'If an account exists with this email, a password reset link has been sent',
    // For development only - remove in production
    resetToken: process.env.NODE_ENV === 'development' ? resetToken : undefined
  });
}));

/**
 * @route   POST /api/v1/auth/reset-password
 * @desc    Reset password with token
 * @access  Public
 */
router.post('/reset-password', [
  body('token').notEmpty(),
  body('newPassword').isLength({ min: 8 })
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }

  const { token, newPassword } = req.body;

  // Verify token exists and is not expired
  const resetRecord = await prisma.passwordReset.findUnique({
    where: { token }
  });

  if (!resetRecord) {
    throw new AppError('Invalid or expired reset token', 400);
  }

  if (resetRecord.used) {
    throw new AppError('This reset token has already been used', 400);
  }

  if (resetRecord.expiresAt < new Date()) {
    throw new AppError('Reset token has expired', 400);
  }

  // Find user
  const user = await prisma.user.findUnique({
    where: { email: resetRecord.email }
  });

  if (!user) {
    throw new AppError('User not found', 404);
  }

  // Hash new password
  const hashedPassword = await bcrypt.hash(newPassword, 12);

  // Update password and mark token as used in a transaction
  await prisma.$transaction([
    prisma.user.update({
      where: { id: user.id },
      data: { password: hashedPassword }
    }),
    prisma.passwordReset.update({
      where: { id: resetRecord.id },
      data: { used: true }
    })
  ]);

  // Delete all refresh tokens to force re-login
  await prisma.refreshToken.deleteMany({
    where: { userId: user.id }
  });

  logger.info(`Password reset successful for ${user.email}`);

  res.json({
    success: true,
    message: 'Password reset successfully. You can now login with your new password.'
  });
}));

module.exports = router;

