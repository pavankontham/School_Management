import 'package:equatable/equatable.dart';

/// User model for Principal and Teacher
class UserModel extends Equatable {
  final String id;
  final String schoolId;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String? phone;
  final String? photo;
  final bool isActive;
  final DateTime createdAt;
  final SchoolModel? school;
  
  const UserModel({
    required this.id,
    required this.schoolId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.phone,
    this.photo,
    required this.isActive,
    required this.createdAt,
    this.school,
  });
  
  String get fullName => '$firstName $lastName';
  
  bool get isPrincipal => role == 'PRINCIPAL';
  bool get isTeacher => role == 'TEACHER';
  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      schoolId: json['schoolId'] ?? json['school']?['id'],
      email: json['email'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      role: json['role'],
      phone: json['phone'],
      photo: json['photo'],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      school: json['school'] != null ? SchoolModel.fromJson(json['school']) : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'schoolId': schoolId,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'phone': phone,
      'photo': photo,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'school': school?.toJson(),
    };
  }
  
  @override
  List<Object?> get props => [id, schoolId, email, firstName, lastName, role];
}

/// Student model
class StudentModel extends Equatable {
  final String id;
  final String schoolId;
  final String classId;
  final String rollNumber;
  final String firstName;
  final String lastName;
  final String? email;
  final String gender;
  final DateTime dateOfBirth;
  final String? photo;
  final String? parentName;
  final String? parentEmail;
  final String? parentPhone;
  final String? address;
  final bool isActive;
  final DateTime createdAt;
  final ClassModel? studentClass;
  final SchoolModel? school;
  
  const StudentModel({
    required this.id,
    required this.schoolId,
    required this.classId,
    required this.rollNumber,
    required this.firstName,
    required this.lastName,
    this.email,
    required this.gender,
    required this.dateOfBirth,
    this.photo,
    this.parentName,
    this.parentEmail,
    this.parentPhone,
    this.address,
    required this.isActive,
    required this.createdAt,
    this.studentClass,
    this.school,
  });
  
  String get fullName => '$firstName $lastName';
  
  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'],
      schoolId: json['schoolId'] ?? json['school']?['id'],
      classId: json['classId'] ?? json['class']?['id'],
      rollNumber: json['rollNumber'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      gender: json['gender'] ?? 'MALE',
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'])
          : DateTime(2000, 1, 1),
      photo: json['photo'],
      parentName: json['parentName'],
      parentEmail: json['parentEmail'],
      parentPhone: json['parentPhone'],
      address: json['address'],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      studentClass: json['class'] != null ? ClassModel.fromJson(json['class']) : null,
      school: json['school'] != null ? SchoolModel.fromJson(json['school']) : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'schoolId': schoolId,
      'classId': classId,
      'rollNumber': rollNumber,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'gender': gender,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'photo': photo,
      'parentName': parentName,
      'parentEmail': parentEmail,
      'parentPhone': parentPhone,
      'address': address,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  @override
  List<Object?> get props => [id, schoolId, classId, rollNumber, firstName, lastName];
}

/// School model
class SchoolModel extends Equatable {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final String? logo;
  final String? website;
  final bool isActive;
  final DateTime createdAt;
  
  const SchoolModel({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.logo,
    this.website,
    required this.isActive,
    required this.createdAt,
  });
  
  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    return SchoolModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'],
      phone: json['phone'],
      email: json['email'],
      logo: json['logo'],
      website: json['website'],
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
      'address': address,
      'phone': phone,
      'email': email,
      'logo': logo,
      'website': website,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  @override
  List<Object?> get props => [id, name];
}

/// Class model
class ClassModel extends Equatable {
  final String id;
  final String name;
  final String? section;
  final String grade;
  final bool isActive;
  
  const ClassModel({
    required this.id,
    required this.name,
    this.section,
    required this.grade,
    required this.isActive,
  });
  
  String get displayName => section != null ? '$name - $section' : name;
  
  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      section: json['section'],
      grade: json['grade'] ?? '',
      isActive: json['isActive'] ?? true,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'section': section,
      'grade': grade,
      'isActive': isActive,
    };
  }
  
  @override
  List<Object?> get props => [id, name, section, grade];
}

