import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../../common/presentation/widgets/custom_text_field.dart';
import '../../data/models/teacher_model.dart';
import '../providers/principal_providers.dart';

class StudentManagementScreen extends ConsumerStatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  ConsumerState<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState
    extends ConsumerState<StudentManagementScreen> {
  final _searchController = TextEditingController();
  String? _searchQuery;
  String? _selectedClassId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = StudentFilter(classId: _selectedClassId, search: _searchQuery);
    final studentsAsync = ref.watch(studentsProvider(filter));
    final classesAsync = ref.watch(classesProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context, classesAsync),
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
              hint: 'Search students...',
              onChanged: (value) {
                setState(() => _searchQuery = value.isEmpty ? null : value);
              },
              onClear: () {
                setState(() => _searchQuery = null);
              },
            ),
          ),

          // Class filter chips
          if (_selectedClassId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Chip(
                    label: Text('Class: ${_getClassName(classesAsync)}'),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => setState(() => _selectedClassId = null),
                  ),
                ],
              ),
            ),

          // Students list
          Expanded(
            child: studentsAsync.when(
              data: (students) => _buildStudentsList(students),
              loading: () => const LoadingWidget(),
              error: (e, _) => ErrorStateWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(studentsProvider(filter)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/principal/students/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Student'),
      ),
    );
  }

  String _getClassName(AsyncValue<List<ClassModel>> classesAsync) {
    return classesAsync.when(
      data: (classes) {
        final cls = classes.where((c) => c.id == _selectedClassId).firstOrNull;
        return cls?.displayName ?? 'Unknown';
      },
      loading: () => 'Loading...',
      error: (_, __) => 'Unknown',
    );
  }

  Widget _buildStudentsList(List<StudentDetailModel> students) {
    if (students.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.school_outlined,
        title: 'No students found',
        subtitle: _searchQuery != null || _selectedClassId != null
            ? 'Try different filters'
            : 'Add your first student to get started',
        actionLabel: _searchQuery == null && _selectedClassId == null ? 'Add Student' : null,
        onAction: _searchQuery == null && _selectedClassId == null
            ? () => context.push('/principal/students/add')
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(studentsProvider(
          StudentFilter(classId: _selectedClassId, search: _searchQuery),
        ));
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          return _StudentCard(
            student: student,
            onTap: () => context.push('/principal/students/${student.id}'),
            onEdit: () => context.push('/principal/students/${student.id}/edit'),
            onDelete: () => _confirmDelete(student),
          );
        },
      ),
    );
  }

  void _showFilterSheet(
    BuildContext context,
    AsyncValue<List<ClassModel>> classesAsync,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Students',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Select Class'),
            const SizedBox(height: 8),
            classesAsync.when(
              data: (classes) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All Classes'),
                    selected: _selectedClassId == null,
                    onSelected: (selected) {
                      setState(() => _selectedClassId = null);
                      Navigator.pop(context);
                    },
                  ),
                  ...classes.map((cls) => ChoiceChip(
                        label: Text(cls.displayName),
                        selected: _selectedClassId == cls.id,
                        onSelected: (selected) {
                          setState(() => _selectedClassId = selected ? cls.id : null);
                          Navigator.pop(context);
                        },
                      )),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Failed to load classes'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(StudentDetailModel student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text(
          'Are you sure you want to delete ${student.fullName}? This action cannot be undone.',
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
          await ref.read(studentManagementProvider.notifier).deleteStudent(student.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student deleted successfully')),
        );
      }
    }
  }
}

class _StudentCard extends StatelessWidget {
  final StudentDetailModel student;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StudentCard({
    required this.student,
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
              Stack(
                children: [
                  UserAvatar(
                    name: student.fullName,
                    imageUrl: student.profileImage,
                    size: 50,
                  ),
                  if (student.hasFaceEncoding)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.face,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
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
                            student.fullName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!student.isActive) StatusBadge.warning('Inactive'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Roll: ${student.rollNumber}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (student.className != null) ...[
                          const Text(' • '),
                          Text(
                            student.className!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
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

