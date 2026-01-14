import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../providers/teacher_providers.dart';
import '../../../common/presentation/widgets/notification_icon_button.dart';

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final classesAsync = ref.watch(myClassesProvider);
    final subjectsAsync = ref.watch(mySubjectsProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back,',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            Text(
              user?.fullName ?? 'Teacher',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          NotificationIconButton(
            onTap: () => context.push('/teacher/notifications'),
          ),
          PopupMenuButton<String>(
            icon: UserAvatar(name: user?.fullName ?? 'T', size: 36),
            itemBuilder: (context) => [
              if (user?.role == 'PRINCIPAL')
                const PopupMenuItem<String>(
                  value: 'principal_dashboard',
                  child: ListTile(
                    leading: Icon(Icons.dashboard),
                    title: Text('Principal Dashboard'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem<String>(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Profile'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: AppColors.error),
                  title:
                      Text('Logout', style: TextStyle(color: AppColors.error)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) async {
              switch (value) {
                case 'principal_dashboard':
                  context.go('/principal');
                  break;
                case 'profile':
                  context.push('/teacher/profile');
                  break;
                case 'logout':
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                  break;
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myClassesProvider);
          ref.invalidate(mySubjectsProvider(null));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildQuickActions(context),

              const SizedBox(height: 24),

              // My Classes
              SectionHeader(
                title: 'My Classes',
                actionLabel: 'View All',
                onAction: () => context.push('/teacher/attendance'),
              ),
              const SizedBox(height: 8),
              classesAsync.when(
                data: (classes) => classes.isEmpty
                    ? const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('No classes assigned'),
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: classes.length,
                          itemBuilder: (context, index) {
                            final cls = classes[index];
                            return _ClassCard(
                              name: cls.displayName,
                              studentCount: cls.studentCount,
                              onTap: () =>
                                  context.push('/principal/classes/${cls.id}'),
                            );
                          },
                        ),
                      ),
                loading: () => const LoadingWidget(),
                error: (e, _) => ErrorStateWidget(message: e.toString()),
              ),

              const SizedBox(height: 24),

              // My Subjects
              SectionHeader(
                title: 'My Subjects',
                actionLabel: 'View All',
                onAction: () => context.push('/teacher/textbooks'),
              ),
              const SizedBox(height: 8),
              subjectsAsync.when(
                data: (subjects) => subjects.isEmpty
                    ? const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('No subjects assigned'),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: subjects.length > 5 ? 5 : subjects.length,
                        itemBuilder: (context, index) {
                          final subject = subjects[index];
                          return _SubjectTile(
                            name: subject.name,
                            className: subject.className ?? '',
                            onTap: () => context.push('/teacher/textbooks'),
                          );
                        },
                      ),
                loading: () => const LoadingWidget(),
                error: (e, _) => ErrorStateWidget(message: e.toString()),
              ),

              const SizedBox(height: 24),

              // Quick Navigation
              const SectionHeader(title: "Quick Navigation"),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _TaskItem(
                        icon: Icons.check_circle_outline,
                        title: 'Take Attendance',
                        subtitle: 'Mark attendance for your classes',
                        onTap: () => context.go('/teacher/attendance'),
                      ),
                      const Divider(),
                      _TaskItem(
                        icon: Icons.grade_outlined,
                        title: 'Enter Marks',
                        subtitle: 'Record student marks',
                        onTap: () => context.go('/teacher/marks'),
                      ),
                      const Divider(),
                      _TaskItem(
                        icon: Icons.quiz_outlined,
                        title: 'Create Quiz',
                        subtitle: 'Create a new quiz for students',
                        onTap: () => context.push('/teacher/quizzes/create'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.camera_alt,
            label: 'Face\nAttendance',
            color: AppColors.primary,
            onTap: () => context.push('/teacher/attendance/camera'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.edit_note,
            label: 'Manual\nAttendance',
            color: AppColors.secondary,
            onTap: () => context.go('/teacher/attendance'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.auto_awesome,
            label: 'AI Quiz\nGenerator',
            color: AppColors.accent,
            onTap: () => context.push('/teacher/quizzes/generate'),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final String name;
  final int studentCount;
  final VoidCallback onTap;

  const _ClassCard({
    required this.name,
    required this.studentCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.class_, color: AppColors.primary),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$studentCount students',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final String name;
  final String className;
  final VoidCallback onTap;

  const _SubjectTile({
    required this.name,
    required this.className,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.book, color: AppColors.secondary, size: 20),
        ),
        title: Text(name),
        subtitle: Text(className),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TaskItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
