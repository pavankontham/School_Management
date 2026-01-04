const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const logger = require('../utils/logger');

const prisma = new PrismaClient();

/**
 * Authenticate JWT token middleware
 */
async function authenticateToken(req, res, next) {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Access token required'
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Verify user still exists and is active
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      select: {
        id: true,
        schoolId: true,
        email: true,
        firstName: true,
        lastName: true,
        role: true,
        isActive: true
      }
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'User not found'
      });
    }

    if (!user.isActive) {
      return res.status(403).json({
        success: false,
        message: 'Account is deactivated'
      });
    }

    req.user = user;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: 'Token expired',
        code: 'TOKEN_EXPIRED'
      });
    }
    
    logger.error('Authentication error:', error);
    return res.status(401).json({
      success: false,
      message: 'Invalid token'
    });
  }
}

/**
 * Authenticate student JWT token middleware
 */
async function authenticateStudentToken(req, res, next) {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Access token required'
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    if (decoded.type !== 'student') {
      return res.status(401).json({
        success: false,
        message: 'Invalid token type'
      });
    }

    const student = await prisma.student.findUnique({
      where: { id: decoded.studentId },
      select: {
        id: true,
        schoolId: true,
        classId: true,
        firstName: true,
        lastName: true,
        rollNumber: true,
        isActive: true
      }
    });

    if (!student) {
      return res.status(401).json({
        success: false,
        message: 'Student not found'
      });
    }

    if (!student.isActive) {
      return res.status(403).json({
        success: false,
        message: 'Account is deactivated'
      });
    }

    req.student = student;
    req.user = { ...student, role: 'STUDENT' };
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: 'Token expired',
        code: 'TOKEN_EXPIRED'
      });
    }
    
    logger.error('Student authentication error:', error);
    return res.status(401).json({
      success: false,
      message: 'Invalid token'
    });
  }
}

/**
 * Role-based access control middleware
 * @param  {...string} roles - Allowed roles
 */
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required'
      });
    }

    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: 'Insufficient permissions'
      });
    }

    next();
  };
}

/**
 * Ensure user belongs to the school being accessed
 */
function requireSchoolAccess(req, res, next) {
  const schoolId = req.params.schoolId || req.body.schoolId || req.query.schoolId;
  
  if (schoolId && req.user.schoolId !== schoolId) {
    return res.status(403).json({
      success: false,
      message: 'Access denied to this school'
    });
  }

  next();
}

/**
 * Add school ID filter to all queries
 */
function addSchoolFilter(req, res, next) {
  req.schoolFilter = { schoolId: req.user.schoolId };
  next();
}

module.exports = {
  authenticateToken,
  authenticateStudentToken,
  requireRole,
  requireSchoolAccess,
  addSchoolFilter
};

