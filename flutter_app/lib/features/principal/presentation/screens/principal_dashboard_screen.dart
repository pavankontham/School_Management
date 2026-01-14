import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../data/repositories/principal_repository.dart';
import '../providers/principal_providers.dart';
import '../../data/models/dashboard_models.dart';
import '../../../common/presentation/widgets/notification_icon_button.dart';

class PrincipalDashboardScreen extends ConsumerWidget {
  const PrincipalDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back,',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              user?.fullName ?? 'Principal',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          NotificationIconButton(
            onTap: () => context.push('/principal/notifications'),
          ),
          PopupMenuButton<String>(
            icon: UserAvatar(name: user?.fullName ?? 'P', size: 36),
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Profile'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'teacher_dashboard',
                child: ListTile(
                  leading: Icon(Icons.school),
                  title: Text('Teacher Dashboard'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'school',
                child: ListTile(
                  leading: Icon(Icons.school_outlined),
                  title: Text('School Info'),
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
                case 'profile':
                  context.push('/principal/profile');
                  break;
                case 'teacher_dashboard':
                  context.push('/teacher');
                  break;
                case 'school':
                  context.push('/principal/school');
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
          ref.invalidate(dashboardStatsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Grid
              statsAsync.when(
                data: (stats) => _buildStatsGrid(context, stats),
                loading: () => const LoadingWidget(),
                error: (e, _) => ErrorStateWidget(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(dashboardStatsProvider),
                ),
              ),

              const SizedBox(height: 24),

              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildQuickActions(context),

              const SizedBox(height: 24),

              // Recent Activity
              SectionHeader(
                title: 'Dashboard Posts',
                actionLabel: 'View All',
                onAction: () => context.push('/principal/posts'),
              ),
              const SizedBox(height: 8),
              statsAsync.when(
                data: (stats) =>
                    _buildRecentPosts(context, ref, stats?.recentPosts ?? []),
                loading: () => const LoadingWidget(),
                error: (e, _) => Text('Error: $e'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/principal/posts/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Post'),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, DashboardStats? stats) {
    if (stats == null) {
      return const EmptyStateWidget(
        icon: Icons.analytics_outlined,
        title: 'No data available',
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          title: 'Teachers',
          value: stats.totalTeachers.toString(),
          icon: Icons.people,
          color: AppColors.primary,
          onTap: () => context.go('/principal/teachers'),
        ),
        _StatCard(
          title: 'Students',
          value: stats.totalStudents.toString(),
          icon: Icons.school,
          color: AppColors.secondary,
          onTap: () => context.go('/principal/students'),
        ),
        _StatCard(
          title: 'Classes',
          value: stats.totalClasses.toString(),
          icon: Icons.class_,
          color: AppColors.accent,
          onTap: () => context.go('/principal/classes'),
        ),
        _StatCard(
          title: 'Attendance',
          value: '${stats.attendanceRate.toStringAsFixed(1)}%',
          icon: Icons.check_circle,
          color: AppColors.success,
          onTap: () => context.push('/principal/attendance'),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _QuickActionChip(
          label: 'Add Teacher',
          icon: Icons.person_add,
          onTap: () => context.push('/principal/teachers/add'),
        ),
        _QuickActionChip(
          label: 'Add Student',
          icon: Icons.person_add_alt,
          onTap: () => context.push('/principal/students/add'),
        ),
        _QuickActionChip(
          label: 'Add Class',
          icon: Icons.add_box,
          onTap: () => context.push('/principal/classes/add'),
        ),
        _QuickActionChip(
          label: 'Attendance',
          icon: Icons.checklist,
          onTap: () => context.push('/principal/attendance'),
        ),
        _QuickActionChip(
          label: 'Marks',
          icon: Icons.grade,
          onTap: () => context.push('/principal/marks'),
        ),
        _QuickActionChip(
          label: 'Quizzes',
          icon: Icons.quiz,
          onTap: () => context.push('/principal/quizzes'),
        ),
        _QuickActionChip(
          label: 'Textbooks',
          icon: Icons.book,
          onTap: () => context.push('/principal/textbooks'),
        ),
        _QuickActionChip(
          label: 'AI Chat',
          icon: Icons.chat,
          onTap: () => context.push('/principal/chat'),
        ),
      ],
    );
  }

  Widget _buildRecentPosts(
      BuildContext context, WidgetRef ref, List<DashboardPostModel> posts) {
    if (posts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(
                Icons.article_outlined,
                size: 48,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 8),
              Text(
                'No recent posts',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/principal/posts/create'),
                child: const Text('Create your first post'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Icon(
                post.type == 'EVENT' ? Icons.event : Icons.article,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            title: Text(
              post.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${post.type} • ${_formatDate(post.createdAt)}',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push('/principal/posts/${post.id}'),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
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

class _QuickActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
