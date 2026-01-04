import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../../common/presentation/widgets/custom_text_field.dart';
import '../../data/models/teacher_model.dart';
import '../providers/principal_providers.dart';

class TeacherManagementScreen extends ConsumerStatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  ConsumerState<TeacherManagementScreen> createState() =>
      _TeacherManagementScreenState();
}

class _TeacherManagementScreenState
    extends ConsumerState<TeacherManagementScreen> {
  final _searchController = TextEditingController();
  String? _searchQuery;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(teachersProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teachers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomSearchField(
              controller: _searchController,
              hint: 'Search teachers...',
              onChanged: (value) {
                setState(() => _searchQuery = value.isEmpty ? null : value);
              },
              onClear: () {
                setState(() => _searchQuery = null);
              },
            ),
          ),

          // Teachers list
          Expanded(
            child: teachersAsync.when(
              data: (teachers) => _buildTeachersList(teachers),
              loading: () => const LoadingWidget(),
              error: (e, _) => ErrorStateWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(teachersProvider(_searchQuery)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/principal/teachers/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Teacher'),
      ),
    );
  }

  Widget _buildTeachersList(List<TeacherModel> teachers) {
    if (teachers.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.people_outline,
        title: 'No teachers found',
        subtitle: _searchQuery != null
            ? 'Try a different search term'
            : 'Add your first teacher to get started',
        actionLabel: _searchQuery == null ? 'Add Teacher' : null,
        onAction:
            _searchQuery == null ? () => context.push('/principal/teachers/add') : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(teachersProvider(_searchQuery));
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: teachers.length,
        itemBuilder: (context, index) {
          final teacher = teachers[index];
          return _TeacherCard(
            teacher: teacher,
            onTap: () => context.push('/principal/teachers/${teacher.id}'),
            onEdit: () => context.push('/principal/teachers/${teacher.id}/edit'),
            onDelete: () => _confirmDelete(teacher),
          );
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Teachers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('Active Only'),
              trailing: Switch(value: true, onChanged: (v) {}),
            ),
            ListTile(
              leading: const Icon(Icons.sort),
              title: const Text('Sort by Name'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(TeacherModel teacher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Teacher'),
        content: Text(
          'Are you sure you want to delete ${teacher.fullName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await ref.read(teacherManagementProvider.notifier).deleteTeacher(teacher.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teacher deleted successfully')),
        );
      }
    }
  }
}

class _TeacherCard extends StatelessWidget {
  final TeacherModel teacher;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TeacherCard({
    required this.teacher,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              UserAvatar(
                name: teacher.fullName,
                imageUrl: teacher.profileImage,
                size: 50,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            teacher.fullName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!teacher.isActive)
                          StatusBadge.warning('Inactive'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      teacher.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (teacher.phone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        teacher.phone!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: ListTile(
                      leading: Icon(Icons.visibility),
                      title: Text('View Details'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: AppColors.error),
                      title: Text('Delete', style: TextStyle(color: AppColors.error)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'view':
                      onTap();
                      break;
                    case 'edit':
                      onEdit();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

