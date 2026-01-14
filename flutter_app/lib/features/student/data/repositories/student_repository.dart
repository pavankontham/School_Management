import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_service.dart';
import '../../../principal/data/repositories/principal_repository.dart';
import '../../../teacher/data/models/quiz_model.dart';
import '../models/student_data_models.dart';

export '../models/student_data_models.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(ref.read(apiServiceProvider));
});

class StudentRepository {
  final ApiService _apiService;

  StudentRepository(this._apiService);

  // Profile
  Future<Map<String, dynamic>?> getProfile() async {
    final response = await _apiService.get('/student/profile');
    if (response.success && response.data != null) {
      return response.data;
    }
    return null;
  }

  // Attendance
  Future<StudentAttendanceData> getAttendance({int? month, int? year}) async {
    final response = await _apiService.get('/student/attendance', queryParams: {
      if (month != null) 'month': month.toString(),
      if (year != null) 'year': year.toString(),
    });
    if (response.success && response.data != null) {
      return StudentAttendanceData.fromJson(response.data);
    }
    return StudentAttendanceData.empty();
  }

  // Marks
  Future<StudentMarksData> getMarks() async {
    final response = await _apiService.get('/student/marks');
    if (response.success && response.data != null) {
      return StudentMarksData.fromJson(response.data);
    }
    return StudentMarksData.empty();
  }

  // Report Card
  Future<Map<String, dynamic>?> getReportCard() async {
    final response = await _apiService.get('/student/report-card');
    if (response.success && response.data != null) {
      return response.data;
    }
    return null;
  }

  // Quizzes
  Future<List<StudentQuizModel>> getQuizzes() async {
    final response = await _apiService.get('/student/quizzes');
    if (response.success && response.data != null) {
      return (response.data as List)
          .map((e) => StudentQuizModel.fromJson(e))
          .toList();
    }
    return [];
  }

  Future<StudentQuizModel?> getQuiz(String id) async {
    final response = await _apiService.get('/student/quizzes/$id');
    if (response.success && response.data != null) {
      return StudentQuizModel.fromJson(response.data);
    }
    return null;
  }

  Future<ApiResult<QuizAttemptResult>> startQuiz(String quizId) async {
    final response = await _apiService.post('/student/quizzes/$quizId/start');
    if (response.success && response.data != null) {
      return ApiResult.success(QuizAttemptResult.fromJson(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to start quiz');
  }

  Future<ApiResult<QuizAttemptResult>> submitQuiz(
    String quizId,
    Map<String, String> answers,
  ) async {
    final response = await _apiService.post(
      '/student/quizzes/$quizId/submit',
      data: {'answers': answers},
    );
    if (response.success && response.data != null) {
      return ApiResult.success(QuizAttemptResult.fromJson(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to submit quiz');
  }

  // Textbooks
  Future<List<StudentTextbookModel>> getTextbooks() async {
    final response = await _apiService.get('/student/textbooks');
    if (response.success && response.data != null) {
      return (response.data as List)
          .map((e) => StudentTextbookModel.fromJson(e))
          .toList();
    }
    return [];
  }

  // Chat
  Future<List<ChatMessageModel>> getChatHistory() async {
    final response = await _apiService.get('/chat/student/history');
    if (response.success && response.data != null) {
      final data = response.data;
      if (data['messages'] != null) {
        return (data['messages'] as List)
            .map((e) => ChatMessageModel.fromJson(e))
            .toList();
      }
    }
    return [];
  }

  Future<ApiResult<ChatResponse>> sendChatMessage(String message) async {
    final response = await _apiService.post('/chat/student/message', data: {
      'message': message,
    });
    if (response.success && response.data != null) {
      return ApiResult.success(ChatResponse.fromJson(response.data));
    }
    return ApiResult.failure(response.message ?? 'Failed to send message');
  }
}
