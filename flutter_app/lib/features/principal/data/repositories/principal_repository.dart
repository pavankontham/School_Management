import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_service.dart';
import '../models/teacher_model.dart';

final principalRepositoryProvider = Provider<PrincipalRepository>((ref) {
  return PrincipalRepository(ref.read(apiServiceProvider));
});

class PrincipalRepository {
  final ApiService _apiService;

  PrincipalRepository(this._apiService);

  // Dashboard Stats
  Future<DashboardStats?> getDashboardStats() async {
    final response = await _apiService.get('/dashboard/stats');
    if (response.success && response.data != null) {
      return DashboardStats.fromJson(response.data);
    }
    return null;
  }

  // Teachers
  Future<List<TeacherModel>> getTeachers({String? search}) async {
    final response = await _apiService.get('/users', queryParams: {
      if (search != null) 'search': search,
    });
    if (response.success && response.data != null) {
      return (response.data as List)
          .map((e) => TeacherModel.fromJson(e))
          .toList();
    }
    return [];
  }

  Future<TeacherModel?> getTeacher(String id) async {
    final response = await _apiService.get('/users/$id');
    if (response.success && response.data != null) {
      return TeacherModel.fromJson(response.data);
    }
    return null;
  }

  Future<ApiResult<TeacherModel>> createTeacher({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
    List<String>? classIds,
    List<String>? subjectIds,
  }) async {
    final response = await _apiService.post('/users/teacher', data: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      'phone': phone,
      if (classIds != null) 'classIds': classIds,
      if (subjectIds != null) 'subjectIds': subjectIds,
    });
    if (response.success && response.data != null) {
      return ApiResult.success(TeacherModel.fromJson(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to create teacher');
  }

  Future<ApiResult<TeacherModel>> updateTeacher(
    String id, {
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    bool? isActive,
  }) async {
    final response = await _apiService.put('/users/$id', data: {
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (isActive != null) 'isActive': isActive,
    });
    if (response.success && response.data != null) {
      return ApiResult.success(TeacherModel.fromJson(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to update teacher');
  }

  Future<bool> deleteTeacher(String id) async {
    final response = await _apiService.delete('/users/$id');
    return response.success;
  }

  // Classes
  Future<List<ClassModel>> getClasses({String? search}) async {
    final response = await _apiService.get('/classes', queryParams: {
      if (search != null) 'search': search,
    });
    if (response.success && response.data != null) {
      return (response.data as List)
          .map((e) => ClassModel.fromJson(e))
          .toList();
    }
    return [];
  }

  Future<ClassModel?> getClass(String id) async {
    final response = await _apiService.get('/classes/$id');
    if (response.success && response.data != null) {
      return ClassModel.fromJson(response.data);
    }
    return null;
  }

  Future<ApiResult<ClassModel>> createClass({
    required String name,
    required String grade,
    String? section,
    String? academicYear,
  }) async {
    final response = await _apiService.post('/classes', data: {
      'name': name,
      'grade': grade,
      'section': section,
      'academicYear': academicYear,
    });
    if (response.success && response.data != null) {
      return ApiResult.success(ClassModel.fromJson(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to create class');
  }

  Future<ApiResult<ClassModel>> updateClass(
    String id, {
    String? name,
    String? section,
    String? academicYear,
    bool? isActive,
  }) async {
    final response = await _apiService.put('/classes/$id', data: {
      if (name != null) 'name': name,
      if (section != null) 'section': section,
      if (academicYear != null) 'academicYear': academicYear,
      if (isActive != null) 'isActive': isActive,
    });
    if (response.success && response.data != null) {
      return ApiResult.success(ClassModel.fromJson(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to update class');
  }

  Future<bool> deleteClass(String id) async {
    final response = await _apiService.delete('/classes/$id');
    return response.success;
  }

  // Subjects
  Future<List<SubjectModel>> getSubjects({String? classId}) async {
    final response = await _apiService.get('/subjects', queryParams: {
      if (classId != null) 'classId': classId,
    });
    if (response.success && response.data != null) {
      return (response.data as List)
          .map((e) => SubjectModel.fromJson(e))
          .toList();
    }
    return [];
  }

  Future<ApiResult<SubjectModel>> createSubject({
    required String name,
    required String code,
    String? description,
  }) async {
    final response = await _apiService.post('/subjects', data: {
      'name': name,
      'code': code,
      'description': description,
    });
    if (response.success && response.data != null) {
      return ApiResult.success(SubjectModel.fromJson(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to create subject');
  }

  Future<ApiResult<SubjectModel>> updateSubject(
    String id, {
    String? name,
    String? description,
    String? teacherId,
  }) async {
    final response = await _apiService.put('/subjects/$id', data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (teacherId != null) 'teacherId': teacherId,
    });
    if (response.success && response.data != null) {
      return ApiResult.success(SubjectModel.fromJson(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to update subject');
  }

  Future<ApiResult<bool>> deleteSubject(String id) async {
    final response = await _apiService.delete('/subjects/$id');
    if (response.success) {
      return ApiResult.success(true);
    }
    return ApiResult.failure(response.message ?? 'Failed to delete subject');
  }

  // Students
  Future<List<StudentDetailModel>> getStudents({
    String? classId,
    String? search,
  }) async {
    final response = await _apiService.get('/students', queryParams: {
      if (classId != null) 'classId': classId,
      if (search != null) 'search': search,
    });
    if (response.success && response.data != null) {
      return (response.data as List)
          .map((e) => StudentDetailModel.fromJson(e))
          .toList();
    }
    return [];
  }

  Future<StudentDetailModel?> getStudent(String id) async {
    final response = await _apiService.get('/students/$id');
    if (response.success && response.data != null) {
      return StudentDetailModel.fromJson(response.data);
    }
    return null;
  }

  Future<ApiResult<StudentDetailModel>> createStudent({
    required String rollNumber,
    required String firstName,
    required String lastName,
    required String classId,
    required String password,
    String? email,
    String? phone,
    required String parentName,
    required String parentPhone,
    String? parentEmail,
    String? address,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    final response = await _apiService.post('/students', data: {
      'rollNumber': rollNumber,
      'firstName': firstName,
      'lastName': lastName,
      'classId': classId,
      'password': password,
      'email': email,
      'phone': phone,
      'parentName': parentName,
      'parentPhone': parentPhone,
      'parentEmail': parentEmail,
      'address': address,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
    });
    if (response.success && response.data != null) {
      return ApiResult.success(StudentDetailModel.fromJson(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to create student');
  }

  Future<ApiResult<StudentDetailModel>> updateStudent(
    String id, {
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? parentPhone,
    String? parentEmail,
    String? address,
    DateTime? dateOfBirth,
    String? gender,
    String? classId,
    bool? isActive,
  }) async {
    final response = await _apiService.put('/students/$id', data: {
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (parentPhone != null) 'parentPhone': parentPhone,
      if (parentEmail != null) 'parentEmail': parentEmail,
      if (address != null) 'address': address,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String(),
      if (gender != null) 'gender': gender,
      if (classId != null) 'classId': classId,
      if (isActive != null) 'isActive': isActive,
    });
    if (response.success && response.data != null) {
      return ApiResult.success(StudentDetailModel.fromJson(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to update student');
  }

  Future<bool> deleteStudent(String id) async {
    final response = await _apiService.delete('/students/$id');
    return response.success;
  }

  Future<bool> uploadStudentPhoto(String studentId, File photo) async {
    final response = await _apiService.uploadFile(
      '/students/$studentId/photo',
      photo,
      fieldName: 'photo',
    );
    return response.success;
  }
}

class DashboardStats {
  final int totalTeachers;
  final int totalStudents;
  final int totalClasses;
  final int totalSubjects;
  final double attendanceRate;
  final int pendingNotifications;

  DashboardStats({
    required this.totalTeachers,
    required this.totalStudents,
    required this.totalClasses,
    required this.totalSubjects,
    required this.attendanceRate,
    required this.pendingNotifications,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalTeachers: json['totalTeachers'] ?? 0,
      totalStudents: json['totalStudents'] ?? 0,
      totalClasses: json['totalClasses'] ?? 0,
      totalSubjects: json['totalSubjects'] ?? 0,
      attendanceRate: (json['attendanceRate'] ?? 0).toDouble(),
      pendingNotifications: json['pendingNotifications'] ?? 0,
    );
  }
}

class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResult._({required this.success, this.data, this.error});

  factory ApiResult.success(T data) => ApiResult._(success: true, data: data);
  factory ApiResult.failure(String error) =>
      ApiResult._(success: false, error: error);
}

