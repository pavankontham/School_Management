import 'package:equatable/equatable.dart';

class TeacherModel extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? profileImage;
  final bool isActive;
  final DateTime createdAt;
  final List<SubjectAssignment>? subjects;
  final List<ClassAssignment>? classes;

  const TeacherModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.profileImage,
    this.isActive = true,
    required this.createdAt,
    this.subjects,
    this.classes,
  });

  String get fullName => '$firstName $lastName';

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    return TeacherModel(
      id: json['id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      profileImage: json['profileImage'] ?? json['photo'],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      subjects: (json['subjects'] ?? json['teacherSubjects']) != null
          ? ((json['subjects'] ?? json['teacherSubjects']) as List)
              .map((e) => SubjectAssignment.fromJson(e))
              .toList()
          : null,
      classes: (json['classes'] ?? json['teacherClasses']) != null
          ? ((json['classes'] ?? json['teacherClasses']) as List)
              .map((e) => ClassAssignment.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'profileImage': profileImage,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, firstName, lastName, email, phone, isActive];
}

class SubjectAssignment extends Equatable {
  final String id;
  final String subjectId;
  final String subjectName;
  final String classId;
  final String className;

  const SubjectAssignment({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.classId,
    required this.className,
  });

  factory SubjectAssignment.fromJson(Map<String, dynamic> json) {
    // Backend returns either direct fields or a nested 'subject'/'class' object
    final subject = json['subject'] as Map<String, dynamic>?;
    final cls = json['class'] as Map<String, dynamic>?;

    return SubjectAssignment(
      id: json['id'] ?? '',
      subjectId: json['subjectId'] ?? subject?['id'] ?? '',
      subjectName: json['subjectName'] ?? subject?['name'] ?? '',
      classId: json['classId'] ?? cls?['id'] ?? '',
      className: json['className'] ?? cls?['name'] ?? '',
    );
  }

  @override
  List<Object?> get props => [id, subjectId, subjectName, classId, className];
}

class ClassAssignment extends Equatable {
  final String id;
  final String name;
  final String? section;
  final int studentCount;

  const ClassAssignment({
    required this.id,
    required this.name,
    this.section,
    this.studentCount = 0,
  });

  factory ClassAssignment.fromJson(Map<String, dynamic> json) {
    // Backend returns either direct fields or a nested 'class' object
    final cls = json['class'] as Map<String, dynamic>?;

    return ClassAssignment(
      id: json['id'] ?? cls?['id'] ?? '',
      name: json['name'] ?? cls?['name'] ?? '',
      section: json['section'] ?? cls?['section'],
      studentCount: json['studentCount'] ??
          json['_count']?['students'] ??
          cls?['_count']?['students'] ??
          0,
    );
  }

  @override
  List<Object?> get props => [id, name, section, studentCount];
}

class SubjectModel extends Equatable {
  final String id;
  final String name;
  final String code;
  final String? description;
  final String classId;
  final String? className;
  final String? teacherId;
  final String? teacherName;
  final bool isActive;

  const SubjectModel({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    required this.classId,
    this.className,
    this.teacherId,
    this.teacherName,
    this.isActive = true,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      description: json['description'],
      classId: json['classId'] ?? '',
      className: json['class']?['name'],
      teacherId: json['teacherId'],
      teacherName: json['teacher'] != null
          ? '${json['teacher']['firstName']} ${json['teacher']['lastName']}'
          : null,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'classId': classId,
      'teacherId': teacherId,
    };
  }

  @override
  List<Object?> get props => [id, name, classId, teacherId];
}

class ClassModel extends Equatable {
  final String id;
  final String name;
  final String? section;
  final String? academicYear;
  final int studentCount;
  final int subjectCount;
  final bool isActive;
  final DateTime createdAt;

  const ClassModel({
    required this.id,
    required this.name,
    this.section,
    this.academicYear,
    this.studentCount = 0,
    this.subjectCount = 0,
    this.isActive = true,
    required this.createdAt,
  });

  String get displayName => section != null ? '$name - $section' : name;

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      section: json['section'],
      academicYear: json['academicYear'],
      studentCount: json['studentCount'] ?? json['_count']?['students'] ?? 0,
      subjectCount: json['subjectCount'] ?? json['_count']?['subjects'] ?? 0,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'section': section,
      'academicYear': academicYear,
    };
  }

  @override
  List<Object?> get props => [id, name, section, academicYear];
}

class StudentDetailModel extends Equatable {
  final String id;
  final String rollNumber;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? parentPhone;
  final String? parentEmail;
  final String? address;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? profileImage;
  final String classId;
  final String? className;
  final bool hasFaceEncoding;
  final bool isActive;
  final DateTime createdAt;

  const StudentDetailModel({
    required this.id,
    required this.rollNumber,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.parentPhone,
    this.parentEmail,
    this.address,
    this.dateOfBirth,
    this.gender,
    this.profileImage,
    required this.classId,
    this.className,
    this.hasFaceEncoding = false,
    this.isActive = true,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  factory StudentDetailModel.fromJson(Map<String, dynamic> json) {
    return StudentDetailModel(
      id: json['id'] ?? '',
      rollNumber: json['rollNumber'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'],
      phone: json['phone'],
      parentPhone: json['parentPhone'],
      parentEmail: json['parentEmail'],
      address: json['address'],
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'])
          : null,
      gender: json['gender'],
      profileImage: json['profileImage'] ?? json['photo'],
      classId: json['classId'] ?? '',
      className: json['class']?['name'],
      hasFaceEncoding: json['faceEncoding'] != null,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rollNumber': rollNumber,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'parentPhone': parentPhone,
      'parentEmail': parentEmail,
      'address': address,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'classId': classId,
    };
  }

  @override
  List<Object?> get props => [id, rollNumber, firstName, lastName, classId];
}
