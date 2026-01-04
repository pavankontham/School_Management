import 'package:equatable/equatable.dart';

enum AttendanceStatus { present, absent, late, excused }

enum AttendanceMethod { manual, faceRecognition }

class AttendanceModel extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String? studentRollNumber;
  final String classId;
  final String? className;
  final String subjectId;
  final String? subjectName;
  final DateTime date;
  final AttendanceStatus status;
  final AttendanceMethod method;
  final double? confidence;
  final String? remarks;
  final DateTime createdAt;

  const AttendanceModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.studentRollNumber,
    required this.classId,
    this.className,
    required this.subjectId,
    this.subjectName,
    required this.date,
    required this.status,
    required this.method,
    this.confidence,
    this.remarks,
    required this.createdAt,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['student'] != null
          ? '${json['student']['firstName']} ${json['student']['lastName']}'
          : json['studentName'] ?? '',
      studentRollNumber:
          json['student']?['rollNumber'] ?? json['studentRollNumber'],
      classId: json['classId'] ?? '',
      className: json['class']?['name'] ?? json['className'],
      subjectId: json['subjectId'] ?? '',
      subjectName: json['subject']?['name'] ?? json['subjectName'],
      date:
          json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      status: _parseStatus(json['status'] ?? 'ABSENT'),
      method: json['method'] == 'FACE_RECOGNITION'
          ? AttendanceMethod.faceRecognition
          : AttendanceMethod.manual,
      confidence: json['confidence']?.toDouble(),
      remarks: json['remarks'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  static AttendanceStatus _parseStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return AttendanceStatus.present;
      case 'ABSENT':
        return AttendanceStatus.absent;
      case 'LATE':
        return AttendanceStatus.late;
      case 'EXCUSED':
        return AttendanceStatus.excused;
      default:
        return AttendanceStatus.absent;
    }
  }

  String get statusString {
    switch (status) {
      case AttendanceStatus.present:
        return 'PRESENT';
      case AttendanceStatus.absent:
        return 'ABSENT';
      case AttendanceStatus.late:
        return 'LATE';
      case AttendanceStatus.excused:
        return 'EXCUSED';
    }
  }

  @override
  List<Object?> get props => [id, studentId, date, status];
}

class AttendanceRecord extends Equatable {
  final String studentId;
  final String studentName;
  final String rollNumber;
  final String? profileImage;
  final bool hasFaceEncoding;
  AttendanceStatus status;
  double? confidence;
  String? remarks;

  AttendanceRecord({
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    this.profileImage,
    this.hasFaceEncoding = false,
    this.status = AttendanceStatus.absent,
    this.confidence,
    this.remarks,
  });

  factory AttendanceRecord.fromStudent(Map<String, dynamic> json) {
    return AttendanceRecord(
      studentId: json['id'],
      studentName: '${json['firstName']} ${json['lastName']}',
      rollNumber: json['rollNumber'],
      profileImage: json['profileImage'],
      hasFaceEncoding: json['faceEncoding'] != null,
    );
  }

  @override
  List<Object?> get props => [studentId, status];
}

class AttendanceSummary extends Equatable {
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int excusedDays;
  final double attendancePercentage;

  const AttendanceSummary({
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.excusedDays,
    required this.attendancePercentage,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      totalDays: json['totalDays'] ?? 0,
      presentDays: json['presentDays'] ?? 0,
      absentDays: json['absentDays'] ?? 0,
      lateDays: json['lateDays'] ?? 0,
      excusedDays: json['excusedDays'] ?? 0,
      attendancePercentage: (json['attendancePercentage'] ?? 0).toDouble(),
    );
  }

  @override
  List<Object?> get props => [totalDays, presentDays, absentDays];
}

class MarksModel extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String? studentRollNumber;
  final String subjectId;
  final String? subjectName;
  final String examType;
  final double marksObtained;
  final double totalMarks;
  final double percentage;
  final String? grade;
  final String? remarks;
  final DateTime examDate;
  final DateTime createdAt;

  const MarksModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.studentRollNumber,
    required this.subjectId,
    this.subjectName,
    required this.examType,
    required this.marksObtained,
    required this.totalMarks,
    required this.percentage,
    this.grade,
    this.remarks,
    required this.examDate,
    required this.createdAt,
  });

  factory MarksModel.fromJson(Map<String, dynamic> json) {
    final obtained = (json['marksObtained'] ?? 0).toDouble();
    final total = (json['totalMarks'] ?? 100).toDouble();

    return MarksModel(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['student'] != null
          ? '${json['student']['firstName']} ${json['student']['lastName']}'
          : json['studentName'] ?? '',
      studentRollNumber:
          json['student']?['rollNumber'] ?? json['studentRollNumber'],
      subjectId: json['subjectId'] ?? '',
      subjectName: json['subject']?['name'] ?? json['subjectName'],
      examType: json['examType'] ?? 'TEST',
      marksObtained: obtained,
      totalMarks: total,
      percentage: total > 0 ? (obtained / total) * 100 : 0,
      grade: json['grade'],
      remarks: json['remarks'],
      examDate: json['examDate'] != null
          ? DateTime.parse(json['examDate'])
          : (json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now()),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, studentId, subjectId, examType];
}

class RemarkModel extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String type;
  final String title;
  final String description;
  final bool isPrivate;
  final DateTime createdAt;

  const RemarkModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.type,
    required this.title,
    required this.description,
    required this.isPrivate,
    required this.createdAt,
  });

  factory RemarkModel.fromJson(Map<String, dynamic> json) {
    return RemarkModel(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['student'] != null
          ? '${json['student']['firstName']} ${json['student']['lastName']}'
          : json['studentName'] ?? '',
      type: json['type'] ?? 'GENERAL',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      isPrivate: json['isPrivate'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, studentId, type];
}
