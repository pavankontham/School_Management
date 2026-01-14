import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/teacher_model.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/models/school_model.dart';
import '../../data/repositories/principal_repository.dart';

// Dashboard Stats Provider
final dashboardStatsProvider = FutureProvider<DashboardStats?>((ref) async {
  return ref.read(principalRepositoryProvider).getDashboardStats();
});

final dashboardPostsProvider =
    FutureProvider.family<List<DashboardPostModel>, String?>((ref, type) async {
  return ref.read(principalRepositoryProvider).getDashboardPosts(type: type);
});

final schoolInfoProvider = FutureProvider<SchoolModel?>((ref) async {
  return ref.read(principalRepositoryProvider).getSchoolInfo();
});

final postManagementProvider =
    StateNotifierProvider<PostManagementNotifier, TeacherManagementState>(
        (ref) {
  return PostManagementNotifier(ref.read(principalRepositoryProvider), ref);
});

class PostManagementNotifier extends StateNotifier<TeacherManagementState> {
  final PrincipalRepository _repository;
  final Ref _ref;

  PostManagementNotifier(this._repository, this._ref)
      : super(const TeacherManagementState());

  Future<bool> createPost({
    required String title,
    required String content,
    required String type,
    bool isPinned = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.createDashboardPost(
      title: title,
      content: content,
      type: type,
      isPinned: isPinned,
    );

    if (result.success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(dashboardPostsProvider);
      _ref.invalidate(dashboardStatsProvider);
      return true;
    }

    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }

  Future<bool> updatePost(
    String id, {
    String? title,
    String? content,
    String? type,
    bool? isPinned,
    bool? isPublished,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.updateDashboardPost(
      id,
      title: title,
      content: content,
      type: type,
      isPinned: isPinned,
      isPublished: isPublished,
    );

    if (result.success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(dashboardPostsProvider);
      return true;
    }

    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }
}

// Teachers Providers
final teachersProvider =
    FutureProvider.family<List<TeacherModel>, String?>((ref, search) async {
  return ref.read(principalRepositoryProvider).getTeachers(search: search);
});

final teacherProvider =
    FutureProvider.family<TeacherModel?, String>((ref, id) async {
  return ref.read(principalRepositoryProvider).getTeacher(id);
});

// Classes Providers
final classesProvider =
    FutureProvider.family<List<ClassModel>, String?>((ref, search) async {
  return ref.read(principalRepositoryProvider).getClasses(search: search);
});

final classProvider =
    FutureProvider.family<ClassModel?, String>((ref, id) async {
  return ref.read(principalRepositoryProvider).getClass(id);
});

// Subjects Providers
final subjectsProvider =
    FutureProvider.family<List<SubjectModel>, String?>((ref, classId) async {
  return ref.read(principalRepositoryProvider).getSubjects(classId: classId);
});

// Students Providers
class StudentFilter {
  final String? classId;
  final String? search;

  StudentFilter({this.classId, this.search});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentFilter &&
          runtimeType == other.runtimeType &&
          classId == other.classId &&
          search == other.search;

  @override
  int get hashCode => classId.hashCode ^ search.hashCode;
}

final studentsProvider =
    FutureProvider.family<List<StudentDetailModel>, StudentFilter>(
        (ref, filter) async {
  return ref.read(principalRepositoryProvider).getStudents(
        classId: filter.classId,
        search: filter.search,
      );
});

final studentProvider =
    FutureProvider.family<StudentDetailModel?, String>((ref, id) async {
  return ref.read(principalRepositoryProvider).getStudent(id);
});

// Teacher Management State
class TeacherManagementState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const TeacherManagementState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  TeacherManagementState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return TeacherManagementState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class TeacherManagementNotifier extends StateNotifier<TeacherManagementState> {
  final PrincipalRepository _repository;
  final Ref _ref;

  TeacherManagementNotifier(this._repository, this._ref)
      : super(const TeacherManagementState());

  Future<bool> createTeacher({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
    List<String>? classIds,
    List<String>? subjectIds,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.createTeacher(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      phone: phone,
      classIds: classIds,
      subjectIds: subjectIds,
    );

    if (result.success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(teachersProvider);
      _ref.invalidate(dashboardStatsProvider);
      return true;
    }

    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }

  Future<bool> updateTeacher(
    String id, {
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.updateTeacher(
      id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      isActive: isActive,
    );

    if (result.success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(teachersProvider);
      _ref.invalidate(teacherProvider(id));
      return true;
    }

    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }

  Future<bool> deleteTeacher(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    final success = await _repository.deleteTeacher(id);

    if (success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(teachersProvider);
      _ref.invalidate(dashboardStatsProvider);
      return true;
    }

    state = state.copyWith(isLoading: false, error: 'Failed to delete teacher');
    return false;
  }

  void reset() {
    state = const TeacherManagementState();
  }
}

final teacherManagementProvider =
    StateNotifierProvider<TeacherManagementNotifier, TeacherManagementState>(
        (ref) {
  return TeacherManagementNotifier(
    ref.read(principalRepositoryProvider),
    ref,
  );
});

// Class Management State
class ClassManagementNotifier extends StateNotifier<TeacherManagementState> {
  final PrincipalRepository _repository;
  final Ref _ref;

  ClassManagementNotifier(this._repository, this._ref)
      : super(const TeacherManagementState());

  Future<bool> createClass({
    required String name,
    required String grade,
    String? section,
    String? academicYear,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.createClass(
      name: name,
      grade: grade,
      section: section,
      academicYear: academicYear,
    );

    if (result.success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(classesProvider);
      _ref.invalidate(dashboardStatsProvider);
      return true;
    }

    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }

  Future<bool> updateClass(
    String id, {
    String? name,
    String? section,
    String? academicYear,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.updateClass(
      id,
      name: name,
      section: section,
      academicYear: academicYear,
      isActive: isActive,
    );

    if (result.success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(classesProvider);
      _ref.invalidate(classProvider(id));
      return true;
    }

    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }

  Future<bool> deleteClass(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    final success = await _repository.deleteClass(id);

    if (success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(classesProvider);
      _ref.invalidate(dashboardStatsProvider);
      return true;
    }

    state = state.copyWith(isLoading: false, error: 'Failed to delete class');
    return false;
  }

  void reset() {
    state = const TeacherManagementState();
  }
}

final classManagementProvider =
    StateNotifierProvider<ClassManagementNotifier, TeacherManagementState>(
        (ref) {
  return ClassManagementNotifier(
    ref.read(principalRepositoryProvider),
    ref,
  );
});

// Student Management State
class StudentManagementNotifier extends StateNotifier<TeacherManagementState> {
  final PrincipalRepository _repository;
  final Ref _ref;

  StudentManagementNotifier(this._repository, this._ref)
      : super(const TeacherManagementState());

  Future<bool> createStudent({
    required String rollNumber,
    required String firstName,
    required String lastName,
    required String classId,
    String? password,
    String? email,
    String? phone,
    required String parentName,
    required String parentPhone,
    String? parentEmail,
    String? address,
    DateTime? dateOfBirth,
    String? gender,
    File? facePhoto,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.createStudent(
      rollNumber: rollNumber,
      firstName: firstName,
      lastName: lastName,
      classId: classId,
      password: password ?? '',
      email: email,
      phone: phone,
      parentName: parentName,
      parentPhone: parentPhone,
      parentEmail: parentEmail,
      address: address,
      dateOfBirth: dateOfBirth,
      gender: gender,
    );

    if (result.success && result.data != null) {
      // Upload face photo if provided
      if (facePhoto != null) {
        final studentId = result.data!.id;
        await _repository.uploadStudentFacePhoto(
          studentId: studentId,
          photo: facePhoto,
        );
      }

      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(studentsProvider);
      _ref.invalidate(dashboardStatsProvider);
      return true;
    }

    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }

  Future<bool> updateStudent(
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
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.updateStudent(
      id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      parentPhone: parentPhone,
      parentEmail: parentEmail,
      address: address,
      dateOfBirth: dateOfBirth,
      gender: gender,
      classId: classId,
      isActive: isActive,
    );

    if (result.success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(studentsProvider);
      _ref.invalidate(studentProvider(id));
      return true;
    }

    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }

  Future<bool> deleteStudent(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    final success = await _repository.deleteStudent(id);

    if (success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(studentsProvider);
      _ref.invalidate(dashboardStatsProvider);
      return true;
    }

    state = state.copyWith(isLoading: false, error: 'Failed to delete student');
    return false;
  }

  void reset() {
    state = const TeacherManagementState();
  }
}

final studentManagementProvider =
    StateNotifierProvider<StudentManagementNotifier, TeacherManagementState>(
        (ref) {
  return StudentManagementNotifier(
    ref.read(principalRepositoryProvider),
    ref,
  );
});

// Subject Management Provider
final subjectManagementProvider =
    StateNotifierProvider<SubjectManagementNotifier, TeacherManagementState>(
        (ref) {
  return SubjectManagementNotifier(ref.read(principalRepositoryProvider));
});

class SubjectManagementNotifier extends StateNotifier<TeacherManagementState> {
  final PrincipalRepository _repository;

  SubjectManagementNotifier(this._repository)
      : super(const TeacherManagementState());

  Future<bool> createSubject({
    required String name,
    required String code,
    String? description,
    String? classId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.createSubject(
      name: name,
      code: code,
      description: description,
      classId: classId,
    );
    if (result.success) {
      state = state.copyWith(isLoading: false);
      return true;
    }
    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }

  Future<bool> updateSubject(String id,
      {String? name, String? description, String? teacherId}) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.updateSubject(id,
        name: name, description: description, teacherId: teacherId);
    if (result.success) {
      state = state.copyWith(isLoading: false);
      return true;
    }
    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }

  Future<bool> deleteSubject(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.deleteSubject(id);
    if (result.success) {
      state = state.copyWith(isLoading: false);
      return true;
    }
    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }

  Future<bool> assignTeacher({
    required String subjectId,
    String? teacherId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.assignTeacherToSubject(
      subjectId: subjectId,
      teacherId: teacherId,
    );
    if (result.success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    }
    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }
}
