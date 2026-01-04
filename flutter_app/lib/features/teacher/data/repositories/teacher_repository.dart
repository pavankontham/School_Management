import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_service.dart';
import '../../../principal/data/models/teacher_model.dart';
import '../../../principal/data/repositories/principal_repository.dart';
import '../models/attendance_model.dart';
import '../models/quiz_model.dart';

final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  return TeacherRepository(ref.read(apiServiceProvider));
});

class TeacherRepository {
  final ApiService _apiService;

  TeacherRepository(this._apiService);

  // Classes & Subjects
  Future<List<ClassModel>> getMyClasses() async {
    final response = await _apiService.get('/classes');
    if (response.success && response.data != null) {
      return (response.data as List).map((e) => ClassModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<SubjectModel>> getMySubjects({String? classId}) async {
    final response = await _apiService.get('/subjects', queryParams: {
      if (classId != null) 'classId': classId,
    });
    if (response.success && response.data != null) {
      return (response.data as List).map((e) => SubjectModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<StudentDetailModel>> getStudentsByClass(String classId) async {
    final response = await _apiService.get('/students', queryParams: {
      'classId': classId,
    });
    if (response.success && response.data != null) {
      return (response.data as List).map((e) => StudentDetailModel.fromJson(e)).toList();
    }
    return [];
  }

  // Attendance
  Future<List<AttendanceModel>> getAttendance({
    required String classId,
    required String subjectId,
    DateTime? date,
  }) async {
    final response = await _apiService.get('/attendance', queryParams: {
      'classId': classId,
      'subjectId': subjectId,
      if (date != null) 'date': date.toIso8601String().split('T')[0],
    });
    if (response.success && response.data != null) {
      return (response.data as List).map((e) => AttendanceModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<ApiResult<void>> submitAttendance({
    required String classId,
    required String subjectId,
    required DateTime date,
    required List<Map<String, dynamic>> records,
  }) async {
    final response = await _apiService.post('/attendance', data: {
      'classId': classId,
      'subjectId': subjectId,
      'date': date.toIso8601String().split('T')[0],
      'records': records,
    });
    if (response.success) {
      return ApiResult.success(null);
    }
    return ApiResult.failure(response.message ?? 'Failed to submit attendance');
  }

  Future<ApiResult<List<Map<String, dynamic>>>> recognizeFaces({
    required File photo,
    required String classId,
  }) async {
    final response = await _apiService.uploadFile(
      '/attendance/recognize',
      photo,
      fieldName: 'photo',
      data: {'classId': classId},
    );
    if (response.success && response.data != null) {
      return ApiResult.success(
        List<Map<String, dynamic>>.from(response.data['recognized'] ?? []),
      );
    }
    return ApiResult.failure(response.message ?? 'Face recognition failed');
  }

  // Marks
  Future<List<MarksModel>> getMarks({
    String? classId,
    String? subjectId,
    String? studentId,
    String? examType,
  }) async {
    final response = await _apiService.get('/marks', queryParams: {
      if (classId != null) 'classId': classId,
      if (subjectId != null) 'subjectId': subjectId,
      if (studentId != null) 'studentId': studentId,
      if (examType != null) 'examType': examType,
    });
    if (response.success && response.data != null) {
      return (response.data as List).map((e) => MarksModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<ApiResult<void>> submitMarks({
    required String subjectId,
    required String examType,
    required double totalMarks,
    required DateTime examDate,
    required List<Map<String, dynamic>> marks,
  }) async {
    final response = await _apiService.post('/marks', data: {
      'subjectId': subjectId,
      'examType': examType,
      'totalMarks': totalMarks,
      'examDate': examDate.toIso8601String(),
      'marks': marks,
    });
    if (response.success) {
      return ApiResult.success(null);
    }
    return ApiResult.failure(response.message ?? 'Failed to submit marks');
  }

  // Remarks
  Future<List<RemarkModel>> getRemarks({String? studentId}) async {
    final response = await _apiService.get('/remarks', queryParams: {
      if (studentId != null) 'studentId': studentId,
    });
    if (response.success && response.data != null) {
      return (response.data as List).map((e) => RemarkModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<ApiResult<RemarkModel>> addRemark({
    required String studentId,
    required String type,
    required String title,
    required String description,
    bool isPrivate = false,
  }) async {
    final response = await _apiService.post('/remarks', data: {
      'studentId': studentId,
      'type': type,
      'title': title,
      'description': description,
      'isPrivate': isPrivate,
    });
    if (response.success && response.data != null) {
      return ApiResult.success(RemarkModel.fromJson(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to add remark');
  }

  // Quizzes
  Future<List<QuizModel>> getQuizzes({String? subjectId}) async {
    final response = await _apiService.get('/quizzes', queryParams: {
      if (subjectId != null) 'subjectId': subjectId,
    });
    if (response.success && response.data != null) {
      return (response.data as List).map((e) => QuizModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<QuizModel?> getQuiz(String id) async {
    final response = await _apiService.get('/quizzes/$id');
    if (response.success && response.data != null) {
      return QuizModel.fromJson(response.data);
    }
    return null;
  }

  Future<ApiResult<QuizModel>> createQuiz({
    required String title,
    String? description,
    required String subjectId,
    required String classId,
    required int timeLimit,
    required List<Map<String, dynamic>> questions,
    int? maxAttempts,
    bool? randomizeQuestions,
    bool? randomizeOptions,
    bool? showResults,
    double? passingScore,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final response = await _apiService.post('/quizzes', data: {
      'title': title,
      'description': description,
      'subjectId': subjectId,
      'classId': classId,
      'timeLimit': timeLimit,
      'questions': questions,
      if (maxAttempts != null) 'maxAttempts': maxAttempts,
      if (randomizeQuestions != null) 'randomizeQuestions': randomizeQuestions,
      if (randomizeOptions != null) 'randomizeOptions': randomizeOptions,
      if (showResults != null) 'showResults': showResults,
      if (passingScore != null) 'passingScore': passingScore,
      if (startTime != null) 'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime.toIso8601String(),
    });
    if (response.success && response.data != null) {
      return ApiResult.success(QuizModel.fromJson(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to create quiz');
  }

  Future<ApiResult<List<Map<String, dynamic>>>> generateQuizQuestions({
    required String topic,
    required int count,
    required String difficulty,
  }) async {
    final response = await _apiService.post('/ai/generate-quiz', data: {
      'topic': topic,
      'count': count,
      'difficulty': difficulty,
    });
    if (response.success && response.data != null) {
      return ApiResult.success(
        List<Map<String, dynamic>>.from(response.data['questions'] ?? []),
      );
    }
    return ApiResult.failure(response.message ?? 'Failed to generate questions');
  }

  Future<List<QuizAttemptModel>> getQuizResults(String quizId) async {
    final response = await _apiService.get('/quizzes/$quizId/results');
    if (response.success && response.data != null) {
      return (response.data as List).map((e) => QuizAttemptModel.fromJson(e)).toList();
    }
    return [];
  }

  // Textbooks
  Future<List<TextbookModel>> getTextbooks({String? subjectId}) async {
    final response = await _apiService.get('/textbooks', queryParams: {
      if (subjectId != null) 'subjectId': subjectId,
    });
    if (response.success && response.data != null) {
      return (response.data as List).map((e) => TextbookModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<ApiResult<TextbookModel>> uploadTextbook({
    required File file,
    required String title,
    String? description,
    required String subjectId,
    required String classId,
  }) async {
    final response = await _apiService.uploadFile(
      '/textbooks',
      file,
      fieldName: 'file',
      data: {
        'title': title,
        'description': description ?? '',
        'subjectId': subjectId,
        'classId': classId,
      },
    );
    if (response.success && response.data != null) {
      return ApiResult.success(TextbookModel.fromJson(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to upload textbook');
  }

  Future<bool> deleteTextbook(String id) async {
    final response = await _apiService.delete('/textbooks/$id');
    return response.success;
  }

  // Chat
  Future<List<ChatMessageModel>> getChatHistory() async {
    final response = await _apiService.get('/chat/history');
    if (response.success && response.data != null) {
      return (response.data as List).map((e) => ChatMessageModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<ApiResult<String>> sendChatMessage(String message) async {
    final response = await _apiService.post('/chat/message', data: {
      'message': message,
    });
    if (response.success && response.data != null) {
      return ApiResult.success(response.data['response'] ?? '');
    }
    return ApiResult.failure(response.message ?? 'Failed to send message');
  }

  Future<bool> clearChatHistory() async {
    final response = await _apiService.delete('/chat/history');
    return response.success;
  }
}

