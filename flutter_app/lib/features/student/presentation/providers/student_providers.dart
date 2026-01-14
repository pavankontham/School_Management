import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../teacher/data/models/quiz_model.dart';
import '../../data/repositories/student_repository.dart';

// Attendance Provider
class AttendanceFilter {
  final int? month;
  final int? year;

  AttendanceFilter({this.month, this.year});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceFilter &&
          runtimeType == other.runtimeType &&
          month == other.month &&
          year == other.year;

  @override
  int get hashCode => month.hashCode ^ year.hashCode;
}

final studentAttendanceProvider =
    FutureProvider.family<StudentAttendanceData, AttendanceFilter>(
        (ref, filter) async {
  return ref.read(studentRepositoryProvider).getAttendance(
        month: filter.month,
        year: filter.year,
      );
});

// Marks Provider
final studentMarksProvider = FutureProvider<StudentMarksData>((ref) async {
  return ref.read(studentRepositoryProvider).getMarks();
});

// Quizzes Provider
final studentQuizzesProvider =
    FutureProvider<List<StudentQuizModel>>((ref) async {
  return ref.read(studentRepositoryProvider).getQuizzes();
});

final studentQuizProvider =
    FutureProvider.family<StudentQuizModel?, String>((ref, id) async {
  return ref.read(studentRepositoryProvider).getQuiz(id);
});

// Textbooks Provider
final studentTextbooksProvider =
    FutureProvider<List<StudentTextbookModel>>((ref) async {
  return ref.read(studentRepositoryProvider).getTextbooks();
});

// Chat Provider
class StudentChatState {
  final bool isLoading;
  final String? error;
  final List<ChatMessageModel> messages;

  const StudentChatState({
    this.isLoading = false,
    this.error,
    this.messages = const [],
  });

  StudentChatState copyWith({
    bool? isLoading,
    String? error,
    List<ChatMessageModel>? messages,
  }) {
    return StudentChatState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      messages: messages ?? this.messages,
    );
  }
}

class StudentChatNotifier extends StateNotifier<StudentChatState> {
  final StudentRepository _repository;

  StudentChatNotifier(this._repository) : super(const StudentChatState());

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
        content: result.data!.response,
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

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final studentChatNotifierProvider =
    StateNotifierProvider<StudentChatNotifier, StudentChatState>((ref) {
  return StudentChatNotifier(ref.read(studentRepositoryProvider));
});

// Quiz Attempt State
class QuizAttemptState {
  final bool isLoading;
  final String? error;
  final Map<String, String> answers;
  final QuizAttemptResult? result;
  final int remainingSeconds;
  final bool isSubmitted;

  const QuizAttemptState({
    this.isLoading = false,
    this.error,
    this.answers = const {},
    this.result,
    this.remainingSeconds = 0,
    this.isSubmitted = false,
  });

  QuizAttemptState copyWith({
    bool? isLoading,
    String? error,
    Map<String, String>? answers,
    QuizAttemptResult? result,
    int? remainingSeconds,
    bool? isSubmitted,
  }) {
    return QuizAttemptState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      answers: answers ?? this.answers,
      result: result ?? this.result,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isSubmitted: isSubmitted ?? this.isSubmitted,
    );
  }
}

class QuizAttemptNotifier extends StateNotifier<QuizAttemptState> {
  final StudentRepository _repository;
  final String _quizId;
  final Ref _ref;

  QuizAttemptNotifier(this._repository, this._quizId, this._ref)
      : super(const QuizAttemptState());

  Future<void> startQuiz() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.startQuiz(_quizId);

    if (result.success && result.data != null) {
      state = state.copyWith(
        isLoading: false,
        result: result.data,
      );
    } else {
      state = state.copyWith(isLoading: false, error: result.error);
    }
  }

  void updateAnswer(String questionId, String answer) {
    state = state.copyWith(
      answers: {...state.answers, questionId: answer},
    );
  }

  Future<bool> submitQuiz() async {
    if (state.answers.isEmpty) return false;

    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.submitQuiz(_quizId, state.answers);

    if (result.success && result.data != null) {
      state = state.copyWith(
        isLoading: false,
        isSubmitted: true,
        result: result.data,
      );
      _ref.invalidate(studentQuizzesProvider);
      return true;
    }

    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }
}

final quizAttemptProvider =
    StateNotifierProvider.family<QuizAttemptNotifier, QuizAttemptState, String>(
        (ref, quizId) {
  return QuizAttemptNotifier(
    ref.read(studentRepositoryProvider),
    quizId,
    ref,
  );
});
