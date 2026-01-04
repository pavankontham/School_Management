import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

/// Auth state
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserType? userType;
  final UserModel? user;
  final StudentModel? student;
  final String? error;
  
  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.userType,
    this.user,
    this.student,
    this.error,
  });
  
  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserType? userType,
    UserModel? user,
    StudentModel? student,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userType: userType ?? this.userType,
      user: user ?? this.user,
      student: student ?? this.student,
      error: error,
    );
  }
}

/// Auth notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  
  AuthNotifier(this._repository) : super(const AuthState());
  
  /// Check authentication status on app start
  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true);

    try {
      final isLoggedIn = await _repository.isLoggedIn();
      if (isLoggedIn) {
        final userType = _repository.getUserType();

        if (userType == UserType.student) {
          final student = await _repository.getCurrentStudent();
          if (student != null) {
            state = AuthState(
              isAuthenticated: true,
              userType: userType,
              student: student,
            );
          } else {
            // Corrupted data - clear and logout
            await _repository.logout();
            state = const AuthState();
          }
        } else if (userType != null) {
          final user = await _repository.getCurrentUser();
          if (user != null) {
            state = AuthState(
              isAuthenticated: true,
              userType: userType,
              user: user,
            );
          } else {
            // Corrupted data - clear and logout
            await _repository.logout();
            state = const AuthState();
          }
        } else {
          // No user type - clear and logout
          await _repository.logout();
          state = const AuthState();
        }
      } else {
        state = const AuthState();
      }
    } catch (e) {
      // On any error, clear storage and reset state
      try {
        await _repository.logout();
      } catch (_) {}
      state = const AuthState();
    }
  }
  
  /// Register school
  Future<bool> registerSchool({
    required String schoolName,
    required String address,
    required String city,
    required String state,
    required String country,
    required String postalCode,
    required String schoolPhone,
    required String schoolEmail,
    String? website,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
  }) async {
    this.state = this.state.copyWith(isLoading: true, error: null);

    try {
      final result = await _repository.registerSchool(
        schoolName: schoolName,
        address: address,
        city: city,
        state: state,
        country: country,
        postalCode: postalCode,
        schoolPhone: schoolPhone,
        schoolEmail: schoolEmail,
        website: website,
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        phone: phone,
      );

      if (result.success) {
        this.state = AuthState(
          isAuthenticated: true,
          userType: UserType.principal,
          user: result.user,
        );
        return true;
      }

      this.state = this.state.copyWith(isLoading: false, error: result.error);
      return false;
    } catch (e, stackTrace) {
      print('Register error: $e');
      print('Stack trace: $stackTrace');
      this.state = this.state.copyWith(isLoading: false, error: 'Registration failed: $e');
      return false;
    }
  }
  
  /// Login for Principal/Teacher
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _repository.login(
        email: email,
        password: password,
      );

      if (result.success) {
        final userType = result.user!.isPrincipal
            ? UserType.principal
            : UserType.teacher;
        state = AuthState(
          isAuthenticated: true,
          userType: userType,
          user: result.user,
        );
        return true;
      }

      state = state.copyWith(isLoading: false, error: result.error);
      return false;
    } catch (e, stackTrace) {
      print('Login error: $e');
      print('Stack trace: $stackTrace');
      state = state.copyWith(isLoading: false, error: 'Login failed: $e');
      return false;
    }
  }
  
  /// Login for Student
  Future<bool> loginStudent({
    required String schoolId,
    required String rollNumber,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _repository.loginStudent(
        schoolId: schoolId,
        rollNumber: rollNumber,
        password: password,
      );

      if (result.success) {
        state = AuthState(
          isAuthenticated: true,
          userType: UserType.student,
          student: result.student,
        );
        return true;
      }

      state = state.copyWith(isLoading: false, error: result.error);
      return false;
    } catch (e, stackTrace) {
      print('Student login error: $e');
      print('Stack trace: $stackTrace');
      state = state.copyWith(isLoading: false, error: 'Login failed: $e');
      return false;
    }
  }
  
  /// Logout
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _repository.logout();
    state = const AuthState();
  }
  
  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for auth state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

/// Provider for checking if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

/// Provider for current user type
final userTypeProvider = Provider<UserType?>((ref) {
  return ref.watch(authProvider).userType;
});

/// Provider for current user (Principal/Teacher)
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});

/// Provider for current student
final currentStudentProvider = Provider<StudentModel?>((ref) {
  return ref.watch(authProvider).student;
});

