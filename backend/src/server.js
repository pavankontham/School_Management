require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const path = require('path');
const fs = require('fs');

const logger = require('./utils/logger');
const errorHandler = require('./middleware/errorHandler');
const { authenticateToken, authenticateStudentToken } = require('./middleware/auth');

// Import routes
const authRoutes = require('./routes/auth');
const schoolRoutes = require('./routes/schools');
const userRoutes = require('./routes/users');
const classRoutes = require('./routes/classes');
const subjectRoutes = require('./routes/subjects');
const studentRoutes = require('./routes/students');
const attendanceRoutes = require('./routes/attendance');
const marksRoutes = require('./routes/marks');
const remarksRoutes = require('./routes/remarks');
const textbookRoutes = require('./routes/textbooks');
const quizRoutes = require('./routes/quizzes');
const chatRoutes = require('./routes/chat');
const notificationRoutes = require('./routes/notifications');
const dashboardRoutes = require('./routes/dashboard');
const aiRoutes = require('./routes/ai');
const studentPortalRoutes = require('./routes/studentPortal');
const studentQuizRoutes = require('./routes/studentQuiz');

const app = express();

// Create uploads directory structure
const uploadsDir = process.env.UPLOAD_DIR || './uploads';
const dirs = [
  uploadsDir,
  path.join(uploadsDir, 'schools'),
  path.join(uploadsDir, 'temp')
];

dirs.forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Security middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" }
}));

// CORS configuration
const corsOptions = {
  origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:3000', 'http://localhost:8080'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
};
app.use(cors(corsOptions));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
  message: {
    success: false,
    message: 'Too many requests, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false
});
app.use('/api/', limiter);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Static files (with authentication for school files)
app.use('/uploads/public', express.static(path.join(uploadsDir, 'public')));

// Request logging
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    ip: req.ip,
    userAgent: req.get('User-Agent')
  });
  next();
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API version prefix
const API_PREFIX = `/api/${process.env.API_VERSION || 'v1'}`;

// Public routes
app.use(`${API_PREFIX}/auth`, authRoutes);

// Protected routes
app.use(`${API_PREFIX}/schools`, authenticateToken, schoolRoutes);
app.use(`${API_PREFIX}/users`, authenticateToken, userRoutes);
app.use(`${API_PREFIX}/classes`, authenticateToken, classRoutes);
app.use(`${API_PREFIX}/subjects`, authenticateToken, subjectRoutes);
app.use(`${API_PREFIX}/students`, authenticateToken, studentRoutes);
app.use(`${API_PREFIX}/attendance`, authenticateToken, attendanceRoutes);
app.use(`${API_PREFIX}/marks`, authenticateToken, marksRoutes);
app.use(`${API_PREFIX}/remarks`, authenticateToken, remarksRoutes);
app.use(`${API_PREFIX}/textbooks`, authenticateToken, textbookRoutes);
app.use(`${API_PREFIX}/quizzes`, authenticateToken, quizRoutes);
app.use(`${API_PREFIX}/chat`, authenticateToken, chatRoutes);
app.use(`${API_PREFIX}/notifications`, authenticateToken, notificationRoutes);
app.use(`${API_PREFIX}/dashboard`, authenticateToken, dashboardRoutes);
app.use(`${API_PREFIX}/ai`, authenticateToken, aiRoutes);

// Student portal routes (separate authentication)
app.use(`${API_PREFIX}/student`, authenticateStudentToken, studentPortalRoutes);
app.use(`${API_PREFIX}/student`, authenticateStudentToken, studentQuizRoutes);

// Secure file access
app.get('/uploads/schools/:schoolId/*', authenticateToken, (req, res, next) => {
  const { schoolId } = req.params;
  
  // Verify user belongs to this school
  if (req.user.schoolId !== schoolId && req.user.role !== 'SUPER_ADMIN') {
    return res.status(403).json({
      success: false,
      message: 'Access denied to this resource'
    });
  }
  
  const filePath = path.join(uploadsDir, 'schools', schoolId, req.params[0]);
  
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({
      success: false,
      message: 'File not found'
    });
  }
  
  res.sendFile(path.resolve(filePath));
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found'
  });
});

// Error handler
app.use(errorHandler);

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info(`Server running on port ${PORT}`);
  logger.info(`API available at http://localhost:${PORT}${API_PREFIX}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});

module.exports = app;

