import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../../common/presentation/widgets/custom_text_field.dart';
import '../../../common/presentation/widgets/loading_button.dart';
import '../../data/models/teacher_model.dart';
import '../providers/principal_providers.dart';

class ClassManagementScreen extends ConsumerStatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  ConsumerState<ClassManagementScreen> createState() =>
      _ClassManagementScreenState();
}

class _ClassManagementScreenState extends ConsumerState<ClassManagementScreen> {
  final _searchController = TextEditingController();
  String? _searchQuery;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomSearchField(
              controller: _searchController,
              hint: 'Search classes...',
              onChanged: (value) {
                setState(() => _searchQuery = value.isEmpty ? null : value);
              },
              onClear: () {
                setState(() => _searchQuery = null);
              },
            ),
          ),

          // Classes list
          Expanded(
            child: classesAsync.when(
              data: (classes) => _buildClassesList(classes),
              loading: () => const LoadingWidget(),
              error: (e, _) => ErrorStateWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(classesProvider(_searchQuery)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddClassDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Class'),
      ),
    );
  }

  Widget _buildClassesList(List<ClassModel> classes) {
    if (classes.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.class_outlined,
        title: 'No classes found',
        subtitle: _searchQuery != null
            ? 'Try a different search term'
            : 'Add your first class to get started',
        actionLabel: _searchQuery == null ? 'Add Class' : null,
        onAction: _searchQuery == null ? () => _showAddClassDialog(context) : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(classesProvider(_searchQuery));
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: classes.length,
        itemBuilder: (context, index) {
          final cls = classes[index];
          return _ClassCard(
            classModel: cls,
            onTap: () => context.push('/principal/classes/${cls.id}'),
            onEdit: () => _showEditClassDialog(context, cls),
            onDelete: () => _confirmDelete(cls),
            onManageSubjects: () => context.push('/principal/classes/${cls.id}/subjects'),
          );
        },
      ),
    );
  }

  void _showAddClassDialog(BuildContext context) {
    final nameController = TextEditingController();
    final sectionController = TextEditingController();
    final gradeController = TextEditingController();
    final yearController = TextEditingController(
      text: DateTime.now().year.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Class'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameController,
                label: 'Class Name',
                hint: 'e.g., Grade 10',
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: gradeController,
                label: 'Grade',
                hint: 'e.g., 10, 11, 12',
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: sectionController,
                label: 'Section (Optional)',
                hint: 'e.g., A, B, C',
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: yearController,
                label: 'Academic Year',
                hint: 'e.g., 2024',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(classManagementProvider);
              return LoadingButton(
                onPressed: () async {
                  if (nameController.text.isEmpty || gradeController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter class name and grade')),
                    );
                    return;
                  }
                  final success = await ref.read(classManagementProvider.notifier).createClass(
                    name: nameController.text.trim(),
                    grade: gradeController.text.trim(),
                    section: sectionController.text.trim().isEmpty
                        ? null
                        : sectionController.text.trim(),
                    academicYear: yearController.text.trim(),
                  );
                  if (success && context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Class added successfully')),
                    );
                  }
                },
                isLoading: state.isLoading,
                text: 'Add',
                height: 40,
              );
            },
          ),
        ],
      ),
    );
  }

  void _showEditClassDialog(BuildContext context, ClassModel cls) {
    final nameController = TextEditingController(text: cls.name);
    final sectionController = TextEditingController(text: cls.section ?? '');
    final yearController = TextEditingController(text: cls.academicYear ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Class'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameController,
                label: 'Class Name',
                hint: 'e.g., Grade 10',
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: sectionController,
                label: 'Section (Optional)',
                hint: 'e.g., A, B, C',
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: yearController,
                label: 'Academic Year',
                hint: 'e.g., 2024',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(classManagementProvider);
              return LoadingButton(
                onPressed: () async {
                  final success = await ref.read(classManagementProvider.notifier).updateClass(
                    cls.id,
                    name: nameController.text.trim(),
                    section: sectionController.text.trim().isEmpty
                        ? null
                        : sectionController.text.trim(),
                    academicYear: yearController.text.trim(),
                  );
                  if (success && context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Class updated successfully')),
                    );
                  }
                },
                isLoading: state.isLoading,
                text: 'Save',
                height: 40,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(ClassModel cls) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text(
          'Are you sure you want to delete ${cls.displayName}? This will also delete all associated subjects and student assignments.',
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
          await ref.read(classManagementProvider.notifier).deleteClass(cls.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class deleted successfully')),
        );
      }
    }
  }
}

class _ClassCard extends StatelessWidget {
  final ClassModel classModel;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onManageSubjects;

  const _ClassCard({
    required this.classModel,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onManageSubjects,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.class_, color: AppColors.accent),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classModel.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (classModel.academicYear != null)
                          Text(
                            'Academic Year: ${classModel.academicYear}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'subjects', child: Text('Manage Subjects')),
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'subjects':
                          onManageSubjects();
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
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatChip(
                    icon: Icons.people,
                    label: '${classModel.studentCount} Students',
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.book,
                    label: '${classModel.subjectCount} Subjects',
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

