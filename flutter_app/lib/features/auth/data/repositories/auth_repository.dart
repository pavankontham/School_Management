import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiServiceProvider));
});

class AuthRepository {
  final ApiService _apiService;
  
  AuthRepository(this._apiService);
  
  /// Register a new school with principal
  Future<AuthResult> registerSchool({
    required String schoolName,
    required String address,
    required String city,
    required String state,
    required String country,
    required String postalCode,
    required String schoolPhone,
    required String schoolEmail,
    String? website,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final response = await _apiService.post('/auth/register-school', data: {
      'schoolName': schoolName,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
      'schoolPhone': schoolPhone,
      'schoolEmail': schoolEmail,
      'website': website,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      'phone': phone,
    });
    
    if (response.success) {
      final data = response.data;
      await _saveAuthData(data, UserType.principal);
      return AuthResult.success(
        user: UserModel.fromJson(data['user']),
        school: SchoolModel.fromJson(data['school']),
      );
    }
    
    return AuthResult.failure(response.message ?? 'Registration failed');
  }
  
  /// Login for Principal/Teacher
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiService.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    
    if (response.success) {
      final data = response.data;
      final user = UserModel.fromJson(data['user']);
      final userType = user.isPrincipal ? UserType.principal : UserType.teacher;
      await _saveAuthData(data, userType);
      return AuthResult.success(
        user: user,
        school: user.school,
      );
    }
    
    return AuthResult.failure(response.message ?? 'Login failed');
  }
  
  /// Login for Student
  Future<StudentAuthResult> loginStudent({
    required String schoolId,
    required String rollNumber,
    required String password,
  }) async {
    final response = await _apiService.post('/auth/login-student', data: {
      'schoolId': schoolId,
      'rollNumber': rollNumber,
      'password': password,
    });
    
    if (response.success) {
      final data = response.data;
      await StorageService.saveAccessToken(data['accessToken']);
      await StorageService.saveRefreshToken(data['refreshToken']);
      await StorageService.saveStudentData(data['student']);
      await StorageService.saveUserType(UserType.student);
      
      return StudentAuthResult.success(
        student: StudentModel.fromJson(data['student']),
      );
    }
    
    return StudentAuthResult.failure(response.message ?? 'Login failed');
  }
  
  /// Refresh token
  Future<bool> refreshToken() async {
    final refreshToken = await StorageService.getRefreshToken();
    if (refreshToken == null) return false;
    
    final response = await _apiService.post('/auth/refresh', data: {
      'refreshToken': refreshToken,
    });
    
    if (response.success) {
      await StorageService.saveAccessToken(response.data['accessToken']);
      await StorageService.saveRefreshToken(response.data['refreshToken']);
      return true;
    }
    
    return false;
  }
  
  /// Logout
  Future<void> logout() async {
    try {
      await _apiService.post('/auth/logout');
    } catch (_) {
      // Ignore errors during logout
    }
    await StorageService.clearAll();
  }
  
  /// Get current user
  Future<UserModel?> getCurrentUser() async {
    final userData = StorageService.getUserData();
    if (userData != null) {
      return UserModel.fromJson(userData);
    }
    return null;
  }
  
  /// Get current student
  Future<StudentModel?> getCurrentStudent() async {
    final studentData = StorageService.getStudentData();
    if (studentData != null) {
      return StudentModel.fromJson(studentData);
    }
    return null;
  }
  
  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await StorageService.getAccessToken();
    return token != null;
  }
  
  /// Get user type
  UserType? getUserType() {
    return StorageService.getUserType();
  }
  
  /// Get school info by ID (for student login)
  Future<SchoolModel?> getSchoolInfo(String schoolId) async {
    final response = await _apiService.get('/auth/school/$schoolId');
    if (response.success && response.data != null) {
      return SchoolModel.fromJson(response.data);
    }
    return null;
  }
  
  Future<void> _saveAuthData(Map<String, dynamic> data, UserType userType) async {
    await StorageService.saveAccessToken(data['accessToken']);
    await StorageService.saveRefreshToken(data['refreshToken']);
    await StorageService.saveUserData(data['user']);
    await StorageService.saveUserType(userType);
  }
}

/// Result class for user authentication
class AuthResult {
  final bool success;
  final UserModel? user;
  final SchoolModel? school;
  final String? error;
  
  AuthResult._({
    required this.success,
    this.user,
    this.school,
    this.error,
  });
  
  factory AuthResult.success({required UserModel user, SchoolModel? school}) {
    return AuthResult._(success: true, user: user, school: school);
  }
  
  factory AuthResult.failure(String error) {
    return AuthResult._(success: false, error: error);
  }
}

/// Result class for student authentication
class StudentAuthResult {
  final bool success;
  final StudentModel? student;
  final String? error;
  
  StudentAuthResult._({
    required this.success,
    this.student,
    this.error,
  });
  
  factory StudentAuthResult.success({required StudentModel student}) {
    return StudentAuthResult._(success: true, student: student);
  }
  
  factory StudentAuthResult.failure(String error) {
    return StudentAuthResult._(success: false, error: error);
  }
}

