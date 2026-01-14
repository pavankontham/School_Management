import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_service.dart';
import '../models/teacher_model.dart';
import '../models/dashboard_models.dart';
import '../models/school_model.dart';

final principalRepositoryProvider = Provider<PrincipalRepository>((ref) {
  return PrincipalRepository(ref.read(apiServiceProvider));
});

class PrincipalRepository {
  final ApiService _apiService;

  PrincipalRepository(this._apiService);

  // School Info
  Future<SchoolModel?> getSchoolInfo() async {
    final response = await _apiService.get('/schools/current');
    if (response.success && response.data != null) {
      return SchoolModel.fromJson(response.data);
    }
    return null;
  }

  // Dashboard Stats
  Future<DashboardStats?> getDashboardStats() async {
    final response = await _apiService.get('/dashboard/stats');
    if (response.success && response.data != null) {
      return DashboardStats.fromJson(response.data);
    }
    return null;
  }

  Future<List<DashboardPostModel>> getDashboardPosts({String? type}) async {
    final response = await _apiService.get('/dashboard/posts', queryParams: {
      if (type != null) 'type': type,
    });
    if (response.success && response.data != null) {
      final posts = response.data['posts'] ?? [];
      return (posts as List)
          .map((e) => DashboardPostModel.fromJson(e))
          .toList();
    }
    return [];
  }

  Future<ApiResult<DashboardPostModel>> createDashboardPost({
    required String title,
    required String content,
    required String type,
    bool isPinned = false,
  }) async {
    final response = await _apiService.post('/dashboard/posts', data: {
      'title': title,
      'content': content,
      'type': type,
      'isPinned': isPinned,
    });
    if (response.success && response.data != null) {
      return ApiResult.success(DashboardPostModel.fromJson(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to create post');
  }

  Future<ApiResult<DashboardPostModel>> updateDashboardPost(
    String id, {
    String? title,
    String? content,
    String? type,
    bool? isPinned,
    bool? isPublished,
  }) async {
    final response = await _apiService.put('/dashboard/posts/$id', data: {
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (type != null) 'type': type,
      if (isPinned != null) 'isPinned': isPinned,
      if (isPublished != null) 'isPublished': isPublished,
    });
    if (response.success && response.data != null) {
      return ApiResult.success(DashboardPostModel.fromJson(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to update post');
  }

  Future<bool> deleteDashboardPost(String id) async {
    final response = await _apiService.delete('/dashboard/posts/$id');
    return response.success;
  }

  Future<DashboardPostModel?> getPostById(String postId) async {
    final response = await _apiService.get('/dashboard/posts/$postId');
    if (response.success && response.data != null) {
      return DashboardPostModel.fromJson(response.data);
    }
    return null;
  }

  // Teachers
  Future<List<TeacherModel>> getTeachers({String? search}) async {
    final response = await _apiService.get('/users', queryParams: {
      if (search != null) 'search': search,
    });
    if (response.success && response.data != null) {
      // Backend returns paginated response: {users: [], pagination: {}}
      final users = response.data['users'] ?? response.data;
      return (users as List).map((e) => TeacherModel.fromJson(e)).toList();
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
    String? classId,
  }) async {
    final response = await _apiService.post('/subjects', data: {
      'name': name,
      'code': code,
      'description': description,
      if (classId != null) 'classId': classId,
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

  Future<ApiResult<void>> assignTeacherToSubject({
    required String subjectId,
    String? teacherId,
  }) async {
    final response =
        await _apiService.put('/subjects/$subjectId/assign-teacher', data: {
      if (teacherId != null) 'teacherId': teacherId,
    });
    if (response.success) {
      return ApiResult.success(null);
    }
    return ApiResult.failure(response.message ?? 'Failed to assign teacher');
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
      // Backend returns paginated response: {students: [], pagination: {}}
      final students = response.data['students'] ?? response.data;
      return (students as List)
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

  Future<ApiResult<Map<String, dynamic>>> uploadStudentFacePhoto({
    required String studentId,
    required File photo,
  }) async {
    final formData = FormData.fromMap({
      'studentId': studentId,
      'photo': await MultipartFile.fromFile(photo.path),
    });
    final response = await _apiService.postMultipart(
      '/face-recognition/upload-reference',
      formData,
    );
    if (response.success && response.data != null) {
      return ApiResult.success(Map<String, dynamic>.from(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to upload photo');
  }
}

class DashboardStats {
  final int totalTeachers;
  final int totalStudents;
  final int totalClasses;
  final int totalSubjects;
  final double attendanceRate;
  final int pendingNotifications;
  final List<DashboardPostModel> recentPosts;
  final List<UpcomingEventModel> upcomingEvents;

  DashboardStats({
    required this.totalTeachers,
    required this.totalStudents,
    required this.totalClasses,
    required this.totalSubjects,
    required this.attendanceRate,
    required this.pendingNotifications,
    this.recentPosts = const [],
    this.upcomingEvents = const [],
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final overview = json['overview'] ?? {};
    final todayAttendance = json['todayAttendance'] ?? {};

    // Calculate attendance rate
    final present = (todayAttendance['present'] ?? 0) as int;
    final absent = (todayAttendance['absent'] ?? 0) as int;
    final late = (todayAttendance['late'] ?? 0) as int;
    final excused = (todayAttendance['excused'] ?? 0) as int;
    final total = present + absent + late + excused;
    final attendanceRate = total > 0 ? (present / total) * 100 : 0.0;

    return DashboardStats(
      totalTeachers: overview['totalTeachers'] ?? 0,
      totalStudents: overview['totalStudents'] ?? 0,
      totalClasses: overview['totalClasses'] ?? 0,
      totalSubjects: 0, // Not provided by backend
      attendanceRate: attendanceRate,
      pendingNotifications: 0,
      recentPosts: json['recentPosts'] != null
          ? (json['recentPosts'] as List)
              .map((e) => DashboardPostModel.fromJson(e))
              .toList()
          : [],
      upcomingEvents: json['upcomingEvents'] != null
          ? (json['upcomingEvents'] as List)
              .map((e) => UpcomingEventModel.fromJson(e))
              .toList()
          : [],
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
