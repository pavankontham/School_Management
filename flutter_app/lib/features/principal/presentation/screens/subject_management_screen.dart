import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../../common/presentation/widgets/custom_text_field.dart';
import '../../../common/presentation/widgets/loading_button.dart';
import '../../data/models/teacher_model.dart';
import '../providers/principal_providers.dart';

class SubjectManagementScreen extends ConsumerStatefulWidget {
  final String classId;

  const SubjectManagementScreen({super.key, required this.classId});

  @override
  ConsumerState<SubjectManagementScreen> createState() =>
      _SubjectManagementScreenState();
}

class _SubjectManagementScreenState
    extends ConsumerState<SubjectManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final classAsync = ref.watch(classProvider(widget.classId));
    final subjectsAsync = ref.watch(subjectsProvider(widget.classId));
    final teachersAsync = ref.watch(teachersProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: classAsync.when(
          data: (cls) => Text('Subjects - ${cls?.displayName ?? "Class"}'),
          loading: () => const Text('Subjects'),
          error: (_, __) => const Text('Subjects'),
        ),
      ),
      body: subjectsAsync.when(
        data: (subjects) => subjects.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.book_outlined,
                title: 'No Subjects',
                subtitle: 'Add subjects to this class',
              )
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(subjectsProvider(widget.classId)),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: subjects.length,
                  itemBuilder: (context, index) {
                    final subject = subjects[index];
                    return _SubjectCard(
                      subject: subject,
                      onEdit: () => _showEditSubjectDialog(subject),
                      onDelete: () => _confirmDelete(subject),
                      onAssignTeacher: () =>
                          _showAssignTeacherDialog(subject, teachersAsync),
                    );
                  },
                ),
              ),
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(subjectsProvider(widget.classId)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSubjectDialog(teachersAsync),
        icon: const Icon(Icons.add),
        label: const Text('Add Subject'),
      ),
    );
  }

  void _showAddSubjectDialog(AsyncValue<List<TeacherModel>> teachersAsync) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Subject'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameController,
                  label: 'Subject Name *',
                  hint: 'e.g., Mathematics',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: codeController,
                  label: 'Subject Code *',
                  hint: 'e.g., MATH-101',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: descController,
                  label: 'Description (Optional)',
                  maxLines: 2,
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
                final state = ref.watch(subjectManagementProvider);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          state.error!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 12),
                        ),
                      ),
                    LoadingButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty ||
                            codeController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Please enter subject name and code')),
                          );
                          return;
                        }
                        final success = await ref
                            .read(subjectManagementProvider.notifier)
                            .createSubject(
                              name: nameController.text.trim(),
                              code: codeController.text.trim(),
                              description: descController.text.trim().isEmpty
                                  ? null
                                  : descController.text.trim(),
                              classId: widget.classId,
                            );
                        if (success && context.mounted) {
                          Navigator.pop(context);
                          ref.invalidate(subjectsProvider(widget.classId));
                        }
                      },
                      isLoading: state.isLoading,
                      text: 'Add',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSubjectDialog(SubjectModel subject) {
    final nameController = TextEditingController(text: subject.name);
    final descController =
        TextEditingController(text: subject.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Subject'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(controller: nameController, label: 'Subject Name'),
            const SizedBox(height: 16),
            CustomTextField(
                controller: descController, label: 'Description', maxLines: 2),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(subjectManagementProvider);
              return LoadingButton(
                onPressed: () async {
                  final success = await ref
                      .read(subjectManagementProvider.notifier)
                      .updateSubject(
                        subject.id,
                        name: nameController.text.trim(),
                        description: descController.text.trim(),
                      );
                  if (success && context.mounted) {
                    Navigator.pop(context);
                    ref.invalidate(subjectsProvider(widget.classId));
                  }
                },
                isLoading: state.isLoading,
                text: 'Save',
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(SubjectModel subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject'),
        content: Text('Are you sure you want to delete ${subject.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(subjectManagementProvider.notifier)
          .deleteSubject(subject.id);
      ref.invalidate(subjectsProvider(widget.classId));
    }
  }

  void _showAssignTeacherDialog(
      SubjectModel subject, AsyncValue<List<TeacherModel>> teachersAsync) {
    String? selectedTeacherId = subject.teacherId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign Teacher'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subject: ${subject.name}'),
              const SizedBox(height: 16),
              teachersAsync.when(
                data: (teachers) => CustomDropdownField<String>(
                  label: 'Teacher',
                  hint: 'Select a teacher',
                  value: selectedTeacherId,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No teacher'),
                    ),
                    ...teachers.map((teacher) => DropdownMenuItem(
                          value: teacher.id,
                          child: Text(teacher.fullName),
                        )),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedTeacherId = value);
                  },
                ),
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            Consumer(
              builder: (context, ref, _) {
                final state = ref.watch(subjectManagementProvider);
                return LoadingButton(
                  onPressed: () async {
                    final success = await ref
                        .read(subjectManagementProvider.notifier)
                        .assignTeacher(
                          subjectId: subject.id,
                          teacherId: selectedTeacherId,
                        );
                    if (success && context.mounted) {
                      Navigator.pop(context);
                      ref.invalidate(subjectsProvider(widget.classId));
                    }
                  },
                  isLoading: state.isLoading,
                  text: 'Assign',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final SubjectModel subject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAssignTeacher;

  const _SubjectCard({
    required this.subject,
    required this.onEdit,
    required this.onDelete,
    required this.onAssignTeacher,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: const Icon(Icons.book, color: AppColors.primary),
        ),
        title: Text(subject.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subject.description != null)
              Text(subject.description!,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              subject.teacherName ?? 'No teacher assigned',
              style: TextStyle(
                  color: subject.teacherName != null
                      ? AppColors.success
                      : AppColors.textSecondary),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
                value: 'teacher', child: Text('Assign Teacher')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(
                value: 'delete',
                child:
                    Text('Delete', style: TextStyle(color: AppColors.error))),
          ],
          onSelected: (value) {
            switch (value) {
              case 'teacher':
                onAssignTeacher();
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
      ),
    );
  }
}
