import 'package:equatable/equatable.dart';

import '../../../teacher/data/models/attendance_model.dart';

/// Student Attendance Data
class StudentAttendanceData extends Equatable {
  final List<StudentAttendanceRecord> records;
  final AttendanceSummary summary;

  const StudentAttendanceData({
    required this.records,
    required this.summary,
  });

  factory StudentAttendanceData.fromJson(Map<String, dynamic> json) {
    final records = (json['attendance'] as List? ?? [])
        .map((e) => StudentAttendanceRecord.fromJson(e))
        .toList();

    final stats = json['stats'] as Map<String, dynamic>? ?? {};
    return StudentAttendanceData(
      records: records,
      summary: AttendanceSummary(
        totalDays: stats['total'] ?? records.length,
        presentDays: stats['present'] ?? 0,
        absentDays: stats['absent'] ?? 0,
        lateDays: stats['late'] ?? 0,
        percentage: (stats['percentage'] ?? 0).toDouble(),
      ),
    );
  }

  factory StudentAttendanceData.empty() => const StudentAttendanceData(
        records: [],
        summary: AttendanceSummary(
          totalDays: 0,
          presentDays: 0,
          absentDays: 0,
          lateDays: 0,
          percentage: 0,
        ),
      );

  @override
  List<Object?> get props => [records, summary];
}

class StudentAttendanceRecord extends Equatable {
  final String id;
  final DateTime date;
  final AttendanceStatus status;
  final String? remarks;

  const StudentAttendanceRecord({
    required this.id,
    required this.date,
    required this.status,
    this.remarks,
  });

  factory StudentAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceRecord(
      id: json['id'] ?? '',
      date:
          json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      status: _parseStatus(json['status']),
      remarks: json['remarks'],
    );
  }

  static AttendanceStatus _parseStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'PRESENT':
        return AttendanceStatus.present;
      case 'LATE':
        return AttendanceStatus.late;
      case 'EXCUSED':
        return AttendanceStatus.excused;
      default:
        return AttendanceStatus.absent;
    }
  }

  @override
  List<Object?> get props => [id, date, status];
}

class AttendanceSummary extends Equatable {
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final double percentage;

  const AttendanceSummary({
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.percentage,
  });

  @override
  List<Object?> get props => [totalDays, presentDays, absentDays, lateDays];
}

/// Student Marks Data
class StudentMarksData extends Equatable {
  final List<SubjectMarks> subjects;
  final double overallPercentage;
  final String? overallGrade;

  const StudentMarksData({
    required this.subjects,
    required this.overallPercentage,
    this.overallGrade,
  });

  factory StudentMarksData.fromJson(Map<String, dynamic> json) {
    final marksList = json['marks'] as List? ?? [];
    final Map<String, List<dynamic>> groupedBySubject = {};

    for (final mark in marksList) {
      final subjectId = mark['subjectId'] ?? '';
      groupedBySubject.putIfAbsent(subjectId, () => []).add(mark);
    }

    final subjects = groupedBySubject.entries.map((entry) {
      final marks = entry.value;
      final firstMark = marks.first;
      return SubjectMarks(
        subjectId: entry.key,
        subjectName: firstMark['subject']?['name'] ?? 'Unknown',
        subjectCode: firstMark['subject']?['code'],
        exams: marks.map((m) => ExamMark.fromJson(m)).toList(),
      );
    }).toList();

    double totalPercentage = 0;
    int count = 0;
    for (final subject in subjects) {
      if (subject.averagePercentage > 0) {
        totalPercentage += subject.averagePercentage;
        count++;
      }
    }

    return StudentMarksData(
      subjects: subjects,
      overallPercentage: count > 0 ? totalPercentage / count : 0,
      overallGrade: json['overallGrade'],
    );
  }

  factory StudentMarksData.empty() => const StudentMarksData(
        subjects: [],
        overallPercentage: 0,
      );

  @override
  List<Object?> get props => [subjects, overallPercentage];
}

class SubjectMarks extends Equatable {
  final String subjectId;
  final String subjectName;
  final String? subjectCode;
  final List<ExamMark> exams;

  const SubjectMarks({
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    required this.exams,
  });

  double get averagePercentage {
    if (exams.isEmpty) return 0;
    return exams.map((e) => e.percentage).reduce((a, b) => a + b) /
        exams.length;
  }

  double get totalObtained =>
      exams.fold(0.0, (sum, e) => sum + e.marksObtained);
  double get totalMarks => exams.fold(0.0, (sum, e) => sum + e.totalMarks);

  @override
  List<Object?> get props => [subjectId, subjectName, exams];
}

class ExamMark extends Equatable {
  final String id;
  final String examType;
  final double marksObtained;
  final double totalMarks;
  final double percentage;
  final String? grade;
  final String? remarks;
  final DateTime examDate;

  const ExamMark({
    required this.id,
    required this.examType,
    required this.marksObtained,
    required this.totalMarks,
    required this.percentage,
    this.grade,
    this.remarks,
    required this.examDate,
  });

  factory ExamMark.fromJson(Map<String, dynamic> json) {
    final obtained = (json['marksObtained'] ?? 0).toDouble();
    final total = (json['totalMarks'] ?? 100).toDouble();
    return ExamMark(
      id: json['id'] ?? '',
      examType: json['examType'] ?? 'TEST',
      marksObtained: obtained,
      totalMarks: total,
      percentage: total > 0 ? (obtained / total) * 100 : 0,
      grade: json['grade'],
      remarks: json['remarks'],
      examDate: json['examDate'] != null
          ? DateTime.parse(json['examDate'])
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, examType, marksObtained, totalMarks];
}

/// Student Quiz Models
class StudentQuizModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String subjectId;
  final String? subjectName;
  final int duration;
  final int totalQuestions;
  final int totalMarks;
  final bool isActive;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? teacherName;
  final List<StudentQuizQuestion>? questions;
  final List<QuizAttemptInfo>? attempts;
  final int? maxAttempts;

  const StudentQuizModel({
    required this.id,
    required this.title,
    this.description,
    required this.subjectId,
    this.subjectName,
    required this.duration,
    required this.totalQuestions,
    required this.totalMarks,
    this.isActive = true,
    this.startTime,
    this.endTime,
    this.teacherName,
    this.questions,
    this.attempts,
    this.maxAttempts,
  });

  bool get hasAttempted => attempts?.isNotEmpty ?? false;
  bool get canAttempt {
    if (maxAttempts != null && (attempts?.length ?? 0) >= maxAttempts!) {
      return false;
    }
    return true;
  }

  factory StudentQuizModel.fromJson(Map<String, dynamic> json) {
    return StudentQuizModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      subjectId: json['subjectId'] ?? '',
      subjectName: json['subject']?['name'],
      duration: json['timeLimit'] ?? json['duration'] ?? 30,
      totalQuestions:
          json['_count']?['questions'] ?? json['totalQuestions'] ?? 0,
      totalMarks: json['totalMarks'] ?? 0,
      isActive: json['isActive'] ?? true,
      startTime:
          json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      teacherName: json['teacher'] != null
          ? '${json['teacher']['firstName']} ${json['teacher']['lastName']}'
          : null,
      questions: json['questions'] != null
          ? (json['questions'] as List)
              .map((q) => StudentQuizQuestion.fromJson(q))
              .toList()
          : null,
      attempts: json['attempts'] != null
          ? (json['attempts'] as List)
              .map((a) => QuizAttemptInfo.fromJson(a))
              .toList()
          : null,
      maxAttempts: json['maxAttempts'],
    );
  }

  @override
  List<Object?> get props => [id, title, subjectId];
}

class StudentQuizQuestion extends Equatable {
  final String id;
  final String questionText;
  final String questionType;
  final List<String> options;
  final int points;
  final int orderIndex;

  const StudentQuizQuestion({
    required this.id,
    required this.questionText,
    required this.questionType,
    required this.options,
    required this.points,
    required this.orderIndex,
  });

  factory StudentQuizQuestion.fromJson(Map<String, dynamic> json) {
    return StudentQuizQuestion(
      id: json['id'] ?? '',
      questionText: json['questionText'] ?? '',
      questionType: json['questionType'] ?? 'MCQ',
      options:
          json['options'] != null ? List<String>.from(json['options']) : [],
      points: json['points'] ?? 1,
      orderIndex: json['orderIndex'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, questionText];
}

class QuizAttemptInfo extends Equatable {
  final String id;
  final double? score;
  final double? percentage;
  final DateTime? submittedAt;

  const QuizAttemptInfo({
    required this.id,
    this.score,
    this.percentage,
    this.submittedAt,
  });

  factory QuizAttemptInfo.fromJson(Map<String, dynamic> json) {
    return QuizAttemptInfo(
      id: json['id'] ?? '',
      score: json['score']?.toDouble(),
      percentage: json['percentage']?.toDouble(),
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'])
          : null,
    );
  }

  @override
  List<Object?> get props => [id, score, percentage];
}

class QuizAttemptResult extends Equatable {
  final String attemptId;
  final double? score;
  final double? percentage;
  final bool? isPassed;
  final Map<String, dynamic>? results;

  const QuizAttemptResult({
    required this.attemptId,
    this.score,
    this.percentage,
    this.isPassed,
    this.results,
  });

  factory QuizAttemptResult.fromJson(Map<String, dynamic> json) {
    return QuizAttemptResult(
      attemptId: json['attemptId'] ?? json['id'] ?? '',
      score: json['score']?.toDouble(),
      percentage: json['percentage']?.toDouble(),
      isPassed: json['isPassed'],
      results: json['results'],
    );
  }

  @override
  List<Object?> get props => [attemptId, score, percentage];
}

/// Student Textbook Model
class StudentTextbookModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String subjectId;
  final String? subjectName;
  final String? subjectCode;
  final String filePath;
  final String? fileType;
  final int? fileSize;
  final String? author;

  const StudentTextbookModel({
    required this.id,
    required this.title,
    this.description,
    required this.subjectId,
    this.subjectName,
    this.subjectCode,
    required this.filePath,
    this.fileType,
    this.fileSize,
    this.author,
  });

  factory StudentTextbookModel.fromJson(Map<String, dynamic> json) {
    return StudentTextbookModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      subjectId: json['subjectId'] ?? '',
      subjectName: json['subject']?['name'],
      subjectCode: json['subject']?['code'],
      filePath: json['filePath'] ?? '',
      fileType: json['fileType'],
      fileSize: json['fileSize'],
      author: json['author'],
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

/// Chat Response Model
class ChatResponse extends Equatable {
  final Map<String, dynamic>? userMessage;
  final Map<String, dynamic>? assistantMessage;

  const ChatResponse({this.userMessage, this.assistantMessage});

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      userMessage: json['userMessage'],
      assistantMessage: json['assistantMessage'],
    );
  }

  String get response => assistantMessage?['content'] ?? '';

  @override
  List<Object?> get props => [userMessage, assistantMessage];
}
