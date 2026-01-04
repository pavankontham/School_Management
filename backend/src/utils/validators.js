const { body, param, query } = require('express-validator');

// Common validators
const validators = {
  // UUID validation
  uuid: (field) => param(field).isUUID().withMessage(`${field} must be a valid UUID`),
  
  // Email validation
  email: body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email address'),
  
  // Password validation
  password: body('password')
    .isLength({ min: 8 })
    .withMessage('Password must be at least 8 characters')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage('Password must contain at least one uppercase letter, one lowercase letter, and one number'),
  
  // Phone validation
  phone: body('phone')
    .optional()
    .matches(/^\+?[\d\s-]{10,15}$/)
    .withMessage('Please provide a valid phone number'),
  
  // Name validation
  firstName: body('firstName')
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('First name must be between 2 and 50 characters')
    .matches(/^[a-zA-Z\s'-]+$/)
    .withMessage('First name can only contain letters, spaces, hyphens, and apostrophes'),
  
  lastName: body('lastName')
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('Last name must be between 2 and 50 characters')
    .matches(/^[a-zA-Z\s'-]+$/)
    .withMessage('Last name can only contain letters, spaces, hyphens, and apostrophes'),
  
  // School registration
  schoolRegistration: [
    body('schoolName')
      .trim()
      .isLength({ min: 3, max: 200 })
      .withMessage('School name must be between 3 and 200 characters'),
    body('address')
      .trim()
      .isLength({ min: 5, max: 500 })
      .withMessage('Address must be between 5 and 500 characters'),
    body('city')
      .trim()
      .isLength({ min: 2, max: 100 })
      .withMessage('City must be between 2 and 100 characters'),
    body('state')
      .trim()
      .isLength({ min: 2, max: 100 })
      .withMessage('State must be between 2 and 100 characters'),
    body('country')
      .trim()
      .isLength({ min: 2, max: 100 })
      .withMessage('Country must be between 2 and 100 characters'),
    body('postalCode')
      .trim()
      .isLength({ min: 3, max: 20 })
      .withMessage('Postal code must be between 3 and 20 characters'),
    body('schoolPhone')
      .matches(/^\+?[\d\s-]{10,15}$/)
      .withMessage('Please provide a valid school phone number'),
    body('schoolEmail')
      .isEmail()
      .normalizeEmail()
      .withMessage('Please provide a valid school email address')
  ],
  
  // Class validation
  classCreate: [
    body('name')
      .trim()
      .isLength({ min: 1, max: 50 })
      .withMessage('Class name must be between 1 and 50 characters'),
    body('grade')
      .trim()
      .isLength({ min: 1, max: 20 })
      .withMessage('Grade must be between 1 and 20 characters'),
    body('academicYear')
      .matches(/^\d{4}-\d{4}$/)
      .withMessage('Academic year must be in format YYYY-YYYY'),
    body('section')
      .optional()
      .trim()
      .isLength({ max: 10 })
      .withMessage('Section must be at most 10 characters')
  ],
  
  // Subject validation
  subjectCreate: [
    body('name')
      .trim()
      .isLength({ min: 2, max: 100 })
      .withMessage('Subject name must be between 2 and 100 characters'),
    body('code')
      .trim()
      .isLength({ min: 2, max: 20 })
      .withMessage('Subject code must be between 2 and 20 characters')
      .matches(/^[A-Z0-9_-]+$/i)
      .withMessage('Subject code can only contain letters, numbers, underscores, and hyphens')
  ],
  
  // Student validation
  studentCreate: [
    body('rollNumber')
      .trim()
      .isLength({ min: 1, max: 20 })
      .withMessage('Roll number must be between 1 and 20 characters'),
    body('firstName')
      .trim()
      .isLength({ min: 2, max: 50 })
      .withMessage('First name must be between 2 and 50 characters'),
    body('lastName')
      .trim()
      .isLength({ min: 2, max: 50 })
      .withMessage('Last name must be between 2 and 50 characters'),
    body('parentName')
      .trim()
      .isLength({ min: 2, max: 100 })
      .withMessage('Parent name must be between 2 and 100 characters'),
    body('parentPhone')
      .matches(/^\+?[\d\s-]{10,15}$/)
      .withMessage('Please provide a valid parent phone number'),
    body('classId')
      .isUUID()
      .withMessage('Class ID must be a valid UUID')
  ],
  
  // Attendance validation
  attendanceCreate: [
    body('classId')
      .isUUID()
      .withMessage('Class ID must be a valid UUID'),
    body('date')
      .isISO8601()
      .withMessage('Date must be a valid ISO 8601 date'),
    body('records')
      .isArray({ min: 1 })
      .withMessage('Records must be a non-empty array'),
    body('records.*.studentId')
      .isUUID()
      .withMessage('Student ID must be a valid UUID'),
    body('records.*.status')
      .isIn(['PRESENT', 'ABSENT', 'LATE', 'EXCUSED'])
      .withMessage('Status must be PRESENT, ABSENT, LATE, or EXCUSED')
  ],
  
  // Marks validation
  marksCreate: [
    body('studentId')
      .isUUID()
      .withMessage('Student ID must be a valid UUID'),
    body('subjectId')
      .isUUID()
      .withMessage('Subject ID must be a valid UUID'),
    body('examType')
      .isIn(['UNIT_TEST', 'MIDTERM', 'FINAL', 'ASSIGNMENT', 'PROJECT', 'QUIZ', 'OTHER'])
      .withMessage('Invalid exam type'),
    body('examName')
      .trim()
      .isLength({ min: 2, max: 100 })
      .withMessage('Exam name must be between 2 and 100 characters'),
    body('maxMarks')
      .isFloat({ min: 0 })
      .withMessage('Max marks must be a positive number'),
    body('obtainedMarks')
      .isFloat({ min: 0 })
      .withMessage('Obtained marks must be a positive number'),
    body('examDate')
      .isISO8601()
      .withMessage('Exam date must be a valid ISO 8601 date')
  ],
  
  // Quiz validation
  quizCreate: [
    body('title')
      .trim()
      .isLength({ min: 3, max: 200 })
      .withMessage('Quiz title must be between 3 and 200 characters'),
    body('classId')
      .isUUID()
      .withMessage('Class ID must be a valid UUID'),
    body('subjectId')
      .isUUID()
      .withMessage('Subject ID must be a valid UUID'),
    body('timeLimit')
      .optional()
      .isInt({ min: 1, max: 300 })
      .withMessage('Time limit must be between 1 and 300 minutes'),
    body('maxAttempts')
      .optional()
      .isInt({ min: 1, max: 10 })
      .withMessage('Max attempts must be between 1 and 10')
  ],
  
  // Notification validation
  notificationCreate: [
    body('title')
      .trim()
      .isLength({ min: 3, max: 200 })
      .withMessage('Title must be between 3 and 200 characters'),
    body('message')
      .trim()
      .isLength({ min: 10, max: 5000 })
      .withMessage('Message must be between 10 and 5000 characters'),
    body('type')
      .isIn(['ANNOUNCEMENT', 'NOTICE', 'ALERT', 'REMINDER', 'EVENT', 'ATTENDANCE', 'MARKS', 'QUIZ'])
      .withMessage('Invalid notification type'),
    body('targetType')
      .isIn(['ALL', 'TEACHERS', 'STUDENTS', 'CLASS', 'SUBJECT', 'INDIVIDUAL'])
      .withMessage('Invalid target type'),
    body('channels')
      .isArray({ min: 1 })
      .withMessage('At least one channel must be selected'),
    body('channels.*')
      .isIn(['EMAIL', 'SMS', 'IN_APP'])
      .withMessage('Invalid channel')
  ],
  
  // Pagination
  pagination: [
    query('page')
      .optional()
      .isInt({ min: 1 })
      .withMessage('Page must be a positive integer'),
    query('limit')
      .optional()
      .isInt({ min: 1, max: 100 })
      .withMessage('Limit must be between 1 and 100')
  ]
};

module.exports = validators;

