import 'package:equatable/equatable.dart';

enum QuestionType { multipleChoice, trueFalse, shortAnswer }

class QuizModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String subjectId;
  final String? subjectName;
  final String classId;
  final String? className;
  final int duration; // in minutes
  final int totalQuestions;
  final int totalMarks;
  final bool isActive;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime createdAt;
  final List<QuizQuestionModel>? questions;

  const QuizModel({
    required this.id,
    required this.title,
    this.description,
    required this.subjectId,
    this.subjectName,
    required this.classId,
    this.className,
    required this.duration,
    required this.totalQuestions,
    required this.totalMarks,
    this.isActive = true,
    this.startTime,
    this.endTime,
    required this.createdAt,
    this.questions,
  });

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    return QuizModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      subjectId: json['subjectId'] ?? '',
      subjectName: json['subject']?['name'] ?? json['subjectName'],
      classId: json['classId'] ?? '',
      className: json['class']?['name'] ?? json['className'],
      duration: json['duration'] ?? 30,
      totalQuestions: json['totalQuestions'] ?? json['questions']?.length ?? 0,
      totalMarks: json['totalMarks'] ?? 0,
      isActive: json['isActive'] ?? true,
      startTime:
          json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      questions: json['questions'] != null
          ? (json['questions'] as List)
              .map((q) => QuizQuestionModel.fromJson(q))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'subjectId': subjectId,
      'classId': classId,
      'duration': duration,
      'totalMarks': totalMarks,
      'isActive': isActive,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, title, subjectId, classId];
}

class QuizQuestionModel extends Equatable {
  final String id;
  final String quizId;
  final String question;
  final QuestionType type;
  final List<String> options;
  final String correctAnswer;
  final int marks;
  final String? explanation;
  final int order;

  const QuizQuestionModel({
    required this.id,
    required this.quizId,
    required this.question,
    required this.type,
    required this.options,
    required this.correctAnswer,
    required this.marks,
    this.explanation,
    required this.order,
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return QuizQuestionModel(
      id: json['id'] ?? '',
      quizId: json['quizId'] ?? '',
      question: json['question'] ?? '',
      type: _parseType(json['type']),
      options:
          json['options'] != null ? List<String>.from(json['options']) : [],
      correctAnswer: json['correctAnswer'] ?? '',
      marks: json['marks'] ?? 1,
      explanation: json['explanation'],
      order: json['order'] ?? 0,
    );
  }

  static QuestionType _parseType(String? type) {
    switch (type?.toUpperCase()) {
      case 'TRUE_FALSE':
        return QuestionType.trueFalse;
      case 'SHORT_ANSWER':
        return QuestionType.shortAnswer;
      default:
        return QuestionType.multipleChoice;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'type': type == QuestionType.trueFalse
          ? 'TRUE_FALSE'
          : type == QuestionType.shortAnswer
              ? 'SHORT_ANSWER'
              : 'MULTIPLE_CHOICE',
      'options': options,
      'correctAnswer': correctAnswer,
      'marks': marks,
      'explanation': explanation,
      'order': order,
    };
  }

  @override
  List<Object?> get props => [id, question, type];
}

class QuizAttemptModel extends Equatable {
  final String id;
  final String quizId;
  final String studentId;
  final String? studentName;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int score;
  final int totalMarks;
  final double percentage;
  final Map<String, dynamic>? answers;

  const QuizAttemptModel({
    required this.id,
    required this.quizId,
    required this.studentId,
    this.studentName,
    required this.startedAt,
    this.completedAt,
    required this.score,
    required this.totalMarks,
    required this.percentage,
    this.answers,
  });

  factory QuizAttemptModel.fromJson(Map<String, dynamic> json) {
    final score = (json['score'] ?? 0).toDouble();
    final total = (json['totalMarks'] ?? 100).toDouble();

    return QuizAttemptModel(
      id: json['id'] ?? '',
      quizId: json['quizId'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['student'] != null
          ? '${json['student']['firstName']} ${json['student']['lastName']}'
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'])
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      score: score.toInt(),
      totalMarks: total.toInt(),
      percentage: total > 0 ? (score / total) * 100 : 0,
      answers: json['answers'],
    );
  }

  @override
  List<Object?> get props => [id, quizId, studentId];
}

class TextbookModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String subjectId;
  final String? subjectName;
  final String classId;
  final String? className;
  final String filePath;
  final String? fileType;
  final int? fileSize;
  final String uploadedById;
  final String? uploadedByName;
  final DateTime createdAt;

  const TextbookModel({
    required this.id,
    required this.title,
    this.description,
    required this.subjectId,
    this.subjectName,
    required this.classId,
    this.className,
    required this.filePath,
    this.fileType,
    this.fileSize,
    required this.uploadedById,
    this.uploadedByName,
    required this.createdAt,
  });

  factory TextbookModel.fromJson(Map<String, dynamic> json) {
    return TextbookModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      subjectId: json['subjectId'] ?? '',
      subjectName: json['subject']?['name'] ?? json['subjectName'],
      classId: json['classId'] ?? '',
      className: json['class']?['name'] ?? json['className'],
      filePath: json['filePath'] ?? '',
      fileType: json['fileType'],
      fileSize: json['fileSize'],
      uploadedById: json['uploadedById'] ?? '',
      uploadedByName: json['uploadedBy'] != null
          ? '${json['uploadedBy']['firstName']} ${json['uploadedBy']['lastName']}'
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  String get fileSizeFormatted {
    if (fileSize == null) return 'Unknown';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  List<Object?> get props => [id, title, subjectId];
}

class ChatMessageModel extends Equatable {
  final String id;
  final String content;
  final bool isUser;
  final DateTime createdAt;

  const ChatMessageModel({
    required this.id,
    required this.content,
    required this.isUser,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      isUser: json['role'] == 'USER',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, content, isUser];
}
