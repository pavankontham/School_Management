/// Application configuration constants
class AppConfig {
  AppConfig._();

  // App Info
  static const String appName = 'School Management';
  static const String appVersion = '1.0.0';

  // API Configuration
  // Production backend URL on Render
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://school-management-api-fxxl.onrender.com/api/v1',
  );

  // Face recognition service (deploy separately if needed)
  static const String faceRecognitionUrl = String.fromEnvironment(
    'FACE_RECOGNITION_URL',
    defaultValue: 'https://school-management-api-fxxl.onrender.com',
  );

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Token Configuration
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String studentDataKey = 'student_data';
  static const String userTypeKey = 'user_type';

  // Cache Configuration
  static const Duration cacheExpiry = Duration(hours: 24);

  // Pagination
  static const int defaultPageSize = 20;

  // Face Recognition
  static const double faceRecognitionThreshold = 0.75;

  // File Upload Limits
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5MB
  static const int maxDocumentSizeBytes = 50 * 1024 * 1024; // 50MB

  // Supported File Types
  static const List<String> supportedImageTypes = ['jpg', 'jpeg', 'png', 'gif'];
  static const List<String> supportedDocumentTypes = [
    'pdf',
    'doc',
    'docx',
    'ppt',
    'pptx'
  ];
}

/// User types for authentication
enum UserType {
  principal,
  teacher,
  student,
}

extension UserTypeExtension on UserType {
  String get value {
    switch (this) {
      case UserType.principal:
        return 'PRINCIPAL';
      case UserType.teacher:
        return 'TEACHER';
      case UserType.student:
        return 'STUDENT';
    }
  }

  static UserType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PRINCIPAL':
        return UserType.principal;
      case 'TEACHER':
        return UserType.teacher;
      case 'STUDENT':
        return UserType.student;
      default:
        throw ArgumentError('Unknown user type: $value');
    }
  }
}
