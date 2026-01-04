const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

const UPLOAD_DIR = process.env.UPLOAD_DIR || './uploads';
const MAX_FILE_SIZE = parseInt(process.env.MAX_FILE_SIZE) || 10 * 1024 * 1024; // 10MB

// Allowed file types
const ALLOWED_TYPES = {
  image: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
  document: ['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
  video: ['video/mp4', 'video/webm', 'video/quicktime'],
  all: ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'video/mp4', 'video/webm', 'video/quicktime']
};

/**
 * Create storage configuration for a specific school
 */
function createSchoolStorage(subfolder) {
  return multer.diskStorage({
    destination: (req, file, cb) => {
      const schoolId = req.user?.schoolId;
      if (!schoolId) {
        return cb(new Error('School ID not found'));
      }

      const uploadPath = path.join(UPLOAD_DIR, 'schools', schoolId, subfolder);
      
      // Create directory if it doesn't exist
      if (!fs.existsSync(uploadPath)) {
        fs.mkdirSync(uploadPath, { recursive: true });
      }

      cb(null, uploadPath);
    },
    filename: (req, file, cb) => {
      const uniqueName = `${uuidv4()}${path.extname(file.originalname)}`;
      cb(null, uniqueName);
    }
  });
}

/**
 * Create temp storage for processing
 */
const tempStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const tempPath = path.join(UPLOAD_DIR, 'temp');
    if (!fs.existsSync(tempPath)) {
      fs.mkdirSync(tempPath, { recursive: true });
    }
    cb(null, tempPath);
  },
  filename: (req, file, cb) => {
    const uniqueName = `${uuidv4()}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  }
});

/**
 * File filter factory
 */
function createFileFilter(allowedTypes) {
  return (req, file, cb) => {
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error(`File type not allowed. Allowed types: ${allowedTypes.join(', ')}`), false);
    }
  };
}

// Upload configurations
const uploadConfigs = {
  // Student profile images
  studentImage: multer({
    storage: createSchoolStorage('students'),
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
    fileFilter: createFileFilter(ALLOWED_TYPES.image)
  }),

  // Attendance photos (for face recognition)
  attendancePhoto: multer({
    storage: tempStorage,
    limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
    fileFilter: createFileFilter(ALLOWED_TYPES.image)
  }),

  // Textbooks and materials
  textbook: multer({
    storage: createSchoolStorage('materials'),
    limits: { fileSize: 50 * 1024 * 1024 }, // 50MB
    fileFilter: createFileFilter(ALLOWED_TYPES.document)
  }),

  // Dashboard media
  dashboardMedia: multer({
    storage: createSchoolStorage('dashboard'),
    limits: { fileSize: MAX_FILE_SIZE },
    fileFilter: createFileFilter(ALLOWED_TYPES.all)
  }),

  // General file upload
  general: multer({
    storage: tempStorage,
    limits: { fileSize: MAX_FILE_SIZE },
    fileFilter: createFileFilter(ALLOWED_TYPES.all)
  })
};

/**
 * Get file URL from path
 */
function getFileUrl(filePath, req) {
  if (!filePath) return null;
  
  const relativePath = filePath.replace(UPLOAD_DIR, '').replace(/\\/g, '/');
  const baseUrl = `${req.protocol}://${req.get('host')}`;
  return `${baseUrl}/uploads${relativePath}`;
}

/**
 * Delete file
 */
function deleteFile(filePath) {
  if (filePath && fs.existsSync(filePath)) {
    fs.unlinkSync(filePath);
    return true;
  }
  return false;
}

/**
 * Move file from temp to permanent location
 */
function moveFile(tempPath, schoolId, subfolder, filename) {
  const destDir = path.join(UPLOAD_DIR, 'schools', schoolId, subfolder);
  
  if (!fs.existsSync(destDir)) {
    fs.mkdirSync(destDir, { recursive: true });
  }

  const destPath = path.join(destDir, filename || path.basename(tempPath));
  fs.renameSync(tempPath, destPath);
  
  return destPath;
}

module.exports = {
  uploadConfigs,
  getFileUrl,
  deleteFile,
  moveFile,
  UPLOAD_DIR,
  ALLOWED_TYPES
};

