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
    expiresAt.setDate(expiresAt.getDate() + 7);

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
  expiresAt.setDate(expiresAt.getDate() + 7);

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
 * @desc    Refresh access token
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

  // Check if token exists in database
  const storedToken = await prisma.refreshToken.findUnique({
    where: { token: refreshToken }
  });

  if (!storedToken || storedToken.expiresAt < new Date()) {
    if (storedToken) {
      await prisma.refreshToken.delete({ where: { id: storedToken.id } });
    }
    throw new AppError('Refresh token expired', 401);
  }

  // Generate new access token
  const accessToken = generateAccessToken({
    userId: decoded.userId,
    schoolId: decoded.schoolId,
    role: decoded.role
  });

  res.json({
    success: true,
    data: { accessToken }
  });
}));

/**
 * @route   POST /api/v1/auth/logout
 * @desc    Logout user
 * @access  Public
 */
router.post('/logout', [
  body('refreshToken').notEmpty()
], asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;

  // Delete refresh token
  await prisma.refreshToken.deleteMany({
    where: { token: refreshToken }
  });

  res.json({
    success: true,
    message: 'Logged out successfully'
  });
}));

module.exports = router;

