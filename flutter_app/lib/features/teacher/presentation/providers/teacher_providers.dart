import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_service.dart';
import '../../../principal/data/models/teacher_model.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/quiz_model.dart';
import '../../data/repositories/teacher_repository.dart';

// Classes & Subjects
final myClassesProvider = FutureProvider<List<ClassModel>>((ref) async {
  return ref.read(teacherRepositoryProvider).getMyClasses();
});

final mySubjectsProvider =
    FutureProvider.family<List<SubjectModel>, String?>((ref, classId) async {
  return ref.read(teacherRepositoryProvider).getMySubjects(classId: classId);
});

final classStudentsProvider =
    FutureProvider.family<List<StudentDetailModel>, String>(
        (ref, classId) async {
  return ref.read(teacherRepositoryProvider).getStudentsByClass(classId);
});

// Attendance
class AttendanceFilter {
  final String classId;
  final String subjectId;
  final DateTime? date;

  AttendanceFilter({required this.classId, required this.subjectId, this.date});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceFilter &&
          classId == other.classId &&
          subjectId == other.subjectId &&
          date?.day == other.date?.day;

  @override
  int get hashCode => classId.hashCode ^ subjectId.hashCode ^ (date?.day ?? 0);
}

final attendanceProvider =
    FutureProvider.family<List<AttendanceModel>, AttendanceFilter>(
        (ref, filter) async {
  return ref.read(teacherRepositoryProvider).getAttendance(
        classId: filter.classId,
        subjectId: filter.subjectId,
        date: filter.date,
      );
});

final classAttendanceSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, classId) async {
  final response =
      await ref.read(apiServiceProvider).get('/attendance/summary/$classId');
  if (response.success && response.data != null) {
    return Map<String, dynamic>.from(response.data);
  }
  return {};
});

// Attendance State
class AttendanceState {
  final bool isLoading;
  final bool isRecognizing;
  final String? error;
  final List<AttendanceRecord> records;

  const AttendanceState({
    this.isLoading = false,
    this.isRecognizing = false,
    this.error,
    this.records = const [],
  });

  AttendanceState copyWith({
    bool? isLoading,
    bool? isRecognizing,
    String? error,
    List<AttendanceRecord>? records,
  }) {
    return AttendanceState(
      isLoading: isLoading ?? this.isLoading,
      isRecognizing: isRecognizing ?? this.isRecognizing,
      error: error,
      records: records ?? this.records,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final TeacherRepository _repository;
  final Ref _ref;

  AttendanceNotifier(this._repository, this._ref)
      : super(const AttendanceState());

  void initializeRecords(List<StudentDetailModel> students) {
    state = state.copyWith(
      records: students
          .map((s) => AttendanceRecord.fromStudent({
                'id': s.id,
                'firstName': s.firstName,
                'lastName': s.lastName,
                'rollNumber': s.rollNumber,
                'profileImage': s.profileImage,
                'faceEncoding': s.hasFaceEncoding ? 'exists' : null,
              }))
          .toList(),
    );
  }

  void updateStatus(String studentId, AttendanceStatus status) {
    final records = [...state.records];
    final index = records.indexWhere((r) => r.studentId == studentId);
    if (index != -1) {
      records[index].status = status;
      state = state.copyWith(records: records);
    }
  }

  void markAllPresent() {
    final records = state.records.map((r) {
      r.status = AttendanceStatus.present;
      return r;
    }).toList();
    state = state.copyWith(records: records);
  }

  void markAllAbsent() {
    final records = state.records.map((r) {
      r.status = AttendanceStatus.absent;
      return r;
    }).toList();
    state = state.copyWith(records: records);
  }

  Future<bool> recognizeFaces(File photo, String classId) async {
    state = state.copyWith(isRecognizing: true, error: null);

    final result =
        await _repository.recognizeFaces(photo: photo, classId: classId);

    if (result.success && result.data != null) {
      final records = [...state.records];
      for (final recognized in result.data!) {
        final studentId = recognized['studentId'];
        final confidence = (recognized['confidence'] ?? 0).toDouble();
        final index = records.indexWhere((r) => r.studentId == studentId);
        if (index != -1) {
          records[index].status = AttendanceStatus.present;
          records[index].confidence = confidence;
        }
      }
      state = state.copyWith(isRecognizing: false, records: records);
      return true;
    }

    state = state.copyWith(isRecognizing: false, error: result.error);
    return false;
  }

  Future<bool> submitAttendance({
    required String classId,
    required String subjectId,
    required DateTime date,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final records = state.records
        .map((r) => {
              'studentId': r.studentId,
              'status': r.status == AttendanceStatus.present
                  ? 'PRESENT'
                  : r.status == AttendanceStatus.late
                      ? 'LATE'
                      : r.status == AttendanceStatus.excused
                          ? 'EXCUSED'
                          : 'ABSENT',
              'method': r.confidence != null ? 'FACE_RECOGNITION' : 'MANUAL',
              'confidence': r.confidence,
              'remarks': r.remarks,
            })
        .toList();

    final result = await _repository.submitAttendance(
      classId: classId,
      subjectId: subjectId,
      date: date,
      records: records,
    );

    if (result.success) {
      state = state.copyWith(isLoading: false);
      _ref.invalidate(attendanceProvider);
      return true;
    }

    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }

  void reset() {
    state = const AttendanceState();
  }
}

final attendanceNotifierProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  return AttendanceNotifier(ref.read(teacherRepositoryProvider), ref);
});

// Marks
class MarksFilter {
  final String? classId;
  final String? subjectId;
  final String? examType;

  MarksFilter({this.classId, this.subjectId, this.examType});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarksFilter &&
          classId == other.classId &&
          subjectId == other.subjectId &&
          examType == other.examType;

  @override
  int get hashCode => (classId ?? '').hashCode ^ (subjectId ?? '').hashCode;
}

final marksProvider =
    FutureProvider.family<List<MarksModel>, MarksFilter>((ref, filter) async {
  return ref.read(teacherRepositoryProvider).getMarks(
        classId: filter.classId,
        subjectId: filter.subjectId,
        examType: filter.examType,
      );
});

// Quizzes
final quizzesProvider =
    FutureProvider.family<List<QuizModel>, String?>((ref, subjectId) async {
  return ref.read(teacherRepositoryProvider).getQuizzes(subjectId: subjectId);
});

final quizProvider = FutureProvider.family<QuizModel?, String>((ref, id) async {
  return ref.read(teacherRepositoryProvider).getQuiz(id);
});

final quizResultsProvider =
    FutureProvider.family<List<QuizAttemptModel>, String>((ref, quizId) async {
  return ref.read(teacherRepositoryProvider).getQuizResults(quizId);
});

// Textbooks
final textbooksProvider =
    FutureProvider.family<List<TextbookModel>, String?>((ref, subjectId) async {
  return ref.read(teacherRepositoryProvider).getTextbooks(subjectId: subjectId);
});

// Chat
final chatHistoryProvider = FutureProvider<List<ChatMessageModel>>((ref) async {
  return ref.read(teacherRepositoryProvider).getChatHistory();
});

class ChatState {
  final bool isLoading;
  final String? error;
  final List<ChatMessageModel> messages;

  const ChatState({
    this.isLoading = false,
    this.error,
    this.messages = const [],
  });

  ChatState copyWith({
    bool? isLoading,
    String? error,
    List<ChatMessageModel>? messages,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      messages: messages ?? this.messages,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final TeacherRepository _repository;

  ChatNotifier(this._repository) : super(const ChatState());

  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true);
    final messages = await _repository.getChatHistory();
    state = state.copyWith(isLoading: false, messages: messages);
  }

  Future<bool> sendMessage(String message) async {
    // Add user message immediately
    final userMessage = ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: message,
      isUser: true,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
    );

    final result = await _repository.sendChatMessage(message);

    if (result.success && result.data != null) {
      final aiMessage = ChatMessageModel(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        content: result.data!,
        isUser: false,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, aiMessage],
        isLoading: false,
      );
      return true;
    }

    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }

  Future<void> clearHistory() async {
    await _repository.clearChatHistory();
    state = const ChatState();
  }
}

final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.read(teacherRepositoryProvider));
});
