import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../services/storage_service.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_school_screen.dart';
import '../../features/auth/presentation/screens/student_login_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/principal/presentation/screens/principal_dashboard_screen.dart';
import '../../features/principal/presentation/screens/teacher_management_screen.dart';
import '../../features/principal/presentation/screens/add_teacher_screen.dart';
import '../../features/principal/presentation/screens/teacher_detail_screen.dart';
import '../../features/principal/presentation/screens/edit_teacher_screen.dart';
import '../../features/principal/presentation/screens/student_management_screen.dart';
import '../../features/principal/presentation/screens/add_student_screen.dart';
import '../../features/principal/presentation/screens/student_detail_screen.dart';
import '../../features/principal/presentation/screens/edit_student_screen.dart';
import '../../features/principal/presentation/screens/class_management_screen.dart';
import '../../features/principal/presentation/screens/class_detail_screen.dart';
import '../../features/principal/presentation/screens/subject_management_screen.dart';
import '../../features/principal/presentation/screens/notification_screen.dart';
import '../../features/principal/presentation/screens/dashboard_posts_screen.dart';
import '../../features/principal/presentation/screens/create_post_screen.dart';
import '../../features/principal/presentation/screens/post_detail_screen.dart';
import '../../features/principal/presentation/screens/school_info_screen.dart';
import '../../features/teacher/presentation/screens/teacher_dashboard_screen.dart';
import '../../features/teacher/presentation/screens/attendance_screen.dart';
import '../../features/teacher/presentation/screens/marks_screen.dart';
import '../../features/teacher/presentation/screens/quiz_management_screen.dart';
import '../../features/teacher/presentation/screens/textbook_screen.dart';
import '../../features/teacher/presentation/screens/teacher_chat_screen.dart';
import '../../features/teacher/presentation/screens/face_recognition_attendance_screen.dart';
import '../../features/teacher/presentation/screens/quiz_generate_screen.dart';
import '../../features/teacher/presentation/screens/attendance_history_screen.dart';
import '../../features/student/presentation/screens/student_dashboard_screen.dart';
import '../../features/student/presentation/screens/student_attendance_screen.dart';
import '../../features/student/presentation/screens/student_marks_screen.dart';
import '../../features/student/presentation/screens/student_quiz_screen.dart';
import '../../features/student/presentation/screens/student_quiz_attempt_screen.dart';
import '../../features/student/presentation/screens/student_textbook_screen.dart';
import '../../features/student/presentation/screens/student_chat_screen.dart';
import '../../features/common/presentation/screens/profile_screen.dart';
import '../../features/common/presentation/screens/notifications_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final isLoggedIn = await StorageService.getAccessToken() != null;
      final userType = StorageService.getUserType();
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/student-login' ||
          state.matchedLocation == '/';

      // If not logged in and not on auth route, redirect to splash
      if (!isLoggedIn && !isAuthRoute) {
        return '/';
      }

      // If logged in and on auth route, redirect to appropriate dashboard
      if (isLoggedIn && isAuthRoute && state.matchedLocation != '/') {
        switch (userType) {
          case UserType.principal:
            return '/principal';
          case UserType.teacher:
            return '/teacher';
          case UserType.student:
            return '/student';
          default:
            return '/';
        }
      }

      return null;
    },
    routes: [
      // Splash Screen
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterSchoolScreen(),
      ),
      GoRoute(
        path: '/student-login',
        builder: (context, state) => const StudentLoginScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Principal Routes
      ShellRoute(
        builder: (context, state, child) => PrincipalShell(child: child),
        routes: [
          GoRoute(
            path: '/principal',
            builder: (context, state) => const PrincipalDashboardScreen(),
            routes: [
              GoRoute(
                path: 'teachers',
                builder: (context, state) => const TeacherManagementScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) => const AddTeacherScreen(),
                  ),
                  GoRoute(
                    path: ':teacherId',
                    builder: (context, state) {
                      final teacherId = state.pathParameters['teacherId']!;
                      return TeacherDetailScreen(teacherId: teacherId);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) {
                          final teacherId = state.pathParameters['teacherId']!;
                          return EditTeacherScreen(teacherId: teacherId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'students',
                builder: (context, state) => const StudentManagementScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) => const AddStudentScreen(),
                  ),
                  GoRoute(
                    path: ':studentId',
                    builder: (context, state) {
                      final studentId = state.pathParameters['studentId']!;
                      return StudentDetailScreen(studentId: studentId);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) {
                          final studentId = state.pathParameters['studentId']!;
                          return EditStudentScreen(studentId: studentId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'classes',
                builder: (context, state) => const ClassManagementScreen(),
                routes: [
                  GoRoute(
                    path: ':classId',
                    builder: (context, state) {
                      final classId = state.pathParameters['classId']!;
                      return ClassDetailScreen(classId: classId);
                    },
                    routes: [
                      GoRoute(
                        path: 'subjects',
                        builder: (context, state) {
                          final classId = state.pathParameters['classId']!;
                          return SubjectManagementScreen(classId: classId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'notifications',
                builder: (context, state) => const NotificationScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => const NotificationScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: 'posts',
                builder: (context, state) => const DashboardPostsScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => const CreatePostScreen(),
                  ),
                  GoRoute(
                    path: ':postId',
                    builder: (context, state) {
                      final postId = state.pathParameters['postId']!;
                      return PostDetailScreen(postId: postId);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'attendance',
                builder: (context, state) => const AttendanceScreen(),
              ),
              GoRoute(
                path: 'marks',
                builder: (context, state) => const MarksScreen(),
              ),
              GoRoute(
                path: 'quizzes',
                builder: (context, state) => const QuizManagementScreen(),
              ),
              GoRoute(
                path: 'textbooks',
                builder: (context, state) => const TextbookScreen(),
              ),
              GoRoute(
                path: 'chat',
                builder: (context, state) => const TeacherChatScreen(),
              ),
              GoRoute(
                path: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
              GoRoute(
                path: 'school',
                builder: (context, state) => const SchoolInfoScreen(),
              ),
            ],
          ),
        ],
      ),

      // Teacher Routes
      ShellRoute(
        builder: (context, state, child) => TeacherShell(child: child),
        routes: [
          GoRoute(
            path: '/teacher',
            builder: (context, state) => const TeacherDashboardScreen(),
            routes: [
              GoRoute(
                path: 'attendance',
                builder: (context, state) => const AttendanceScreen(),
                routes: [
                  GoRoute(
                    path: 'camera',
                    builder: (context, state) =>
                        const FaceRecognitionAttendanceScreen(),
                  ),
                  GoRoute(
                    path: 'history',
                    builder: (context, state) =>
                        const AttendanceHistoryScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: 'marks',
                builder: (context, state) => const MarksScreen(),
              ),
              GoRoute(
                path: 'quizzes',
                builder: (context, state) => const QuizManagementScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) =>
                        const QuizManagementScreen(), // Opens create dialog
                  ),
                  GoRoute(
                    path: 'generate',
                    builder: (context, state) => const QuizGenerateScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: 'textbooks',
                builder: (context, state) => const TextbookScreen(),
              ),
              GoRoute(
                path: 'chat',
                builder: (context, state) => const TeacherChatScreen(),
              ),
              GoRoute(
                path: 'notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
              GoRoute(
                path: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Student Routes
      ShellRoute(
        builder: (context, state, child) => StudentShell(child: child),
        routes: [
          GoRoute(
            path: '/student',
            builder: (context, state) => const StudentDashboardScreen(),
            routes: [
              GoRoute(
                path: 'attendance',
                builder: (context, state) => const StudentAttendanceScreen(),
              ),
              GoRoute(
                path: 'marks',
                builder: (context, state) => const StudentMarksScreen(),
              ),
              GoRoute(
                path: 'quizzes',
                builder: (context, state) => const StudentQuizScreen(),
                routes: [
                  GoRoute(
                    path: ':quizId/attempt',
                    builder: (context, state) {
                      final quizId = state.pathParameters['quizId']!;
                      return StudentQuizAttemptScreen(quizId: quizId);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'textbooks',
                builder: (context, state) => const StudentTextbookScreen(),
              ),
              GoRoute(
                path: 'chat',
                builder: (context, state) => const StudentChatScreen(),
              ),
              GoRoute(
                path: 'notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
              GoRoute(
                path: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
});

// Shell widgets for navigation
class PrincipalShell extends StatelessWidget {
  final Widget child;
  const PrincipalShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

class TeacherShell extends StatelessWidget {
  final Widget child;
  const TeacherShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

class StudentShell extends StatelessWidget {
  final Widget child;
  const StudentShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
