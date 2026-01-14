import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../providers/principal_providers.dart';

class TeacherDetailScreen extends ConsumerWidget {
  final String teacherId;

  const TeacherDetailScreen({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherAsync = ref.watch(teacherProvider(teacherId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                context.push('/principal/teachers/$teacherId/edit'),
          ),
        ],
      ),
      body: teacherAsync.when(
        data: (teacher) {
          if (teacher == null) {
            return const Center(child: Text('Teacher not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        UserAvatar(
                          name: teacher.fullName,
                          imageUrl: teacher.profileImage,
                          size: 80,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          teacher.fullName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Teacher',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!teacher.isActive) StatusBadge.warning('Inactive'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Contact Information
                _buildSectionCard(
                  context,
                  'Contact Information',
                  Icons.contact_mail,
                  [
                    _buildInfoRow('Email', teacher.email),
                    if (teacher.phone != null)
                      _buildInfoRow('Phone', teacher.phone!),
                  ],
                ),
                const SizedBox(height: 16),

                // Classes
                if (teacher.classes != null && teacher.classes!.isNotEmpty) ...[
                  _buildSectionCard(
                    context,
                    'Assigned Classes',
                    Icons.class_,
                    teacher.classes!
                        .map(
                          (c) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.class_outlined),
                            title: Text(c.name),
                            subtitle: c.section != null
                                ? Text('Section: ${c.section}')
                                : null,
                            trailing: Text('${c.studentCount} students'),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Subjects
                if (teacher.subjects != null &&
                    teacher.subjects!.isNotEmpty) ...[
                  _buildSectionCard(
                    context,
                    'Assigned Subjects',
                    Icons.book,
                    teacher.subjects!
                        .map(
                          (s) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.book_outlined),
                            title: Text(s.subjectName),
                            subtitle: Text('Class: ${s.className}'),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Account Status
                _buildSectionCard(
                  context,
                  'Account Status',
                  Icons.info,
                  [
                    _buildInfoRow(
                        'Status', teacher.isActive ? 'Active' : 'Inactive'),
                    _buildInfoRow('Created', _formatDate(teacher.createdAt)),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(teacherProvider(teacherId)),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
