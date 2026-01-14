import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../data/models/teacher_model.dart';
import '../providers/principal_providers.dart';

class ClassDetailScreen extends ConsumerWidget {
  final String classId;

  const ClassDetailScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classAsync = ref.watch(classProvider(classId));
    final subjectsAsync = ref.watch(subjectsProvider(classId));
    final studentsAsync =
        ref.watch(studentsProvider(StudentFilter(classId: classId)));

    return Scaffold(
      appBar: AppBar(
        title: classAsync.when(
          data: (cls) => Text(cls?.displayName ?? 'Class Details'),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Error'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              classAsync.whenData((cls) {
                if (cls != null) _showEditClassDialog(context, ref, cls);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              _confirmDelete(context, ref);
            },
          ),
        ],
      ),
      body: classAsync.when(
        data: (cls) {
          if (cls == null) return const Center(child: Text('Class not found'));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCard(cls),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  title: 'Subjects',
                  count: cls.subjectCount,
                  onAction: () =>
                      context.push('/principal/classes/$classId/subjects'),
                ),
                const SizedBox(height: 12),
                _buildSubjectsList(subjectsAsync),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  title: 'Students',
                  count: cls.studentCount,
                  onAction: () =>
                      context.push('/principal/students?classId=$classId'),
                ),
                const SizedBox(height: 12),
                _buildStudentsList(studentsAsync, context),
              ],
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(classProvider(classId)),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(ClassModel cls) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.class_,
                      color: AppColors.primary, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cls.displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Academic Year: ${cls.academicYear ?? "N/A"}',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                cls.isActive
                    ? StatusBadge.success('Active')
                    : StatusBadge.error('Inactive'),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Students', cls.studentCount.toString(),
                    Icons.people_outline),
                _buildStatItem('Subjects', cls.subjectCount.toString(),
                    Icons.book_outlined),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textTertiary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required VoidCallback onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: onAction,
          child: const Text('View All'),
        ),
      ],
    );
  }

  Widget _buildSubjectsList(AsyncValue<List<SubjectModel>> subjectsAsync) {
    return subjectsAsync.when(
      data: (subjects) {
        if (subjects.isEmpty) {
          return const Center(child: Text('No subjects added yet'));
        }
        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              return Card(
                margin: const EdgeInsets.only(right: 12),
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        subject.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subject.teacherName ?? 'No teacher',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Widget _buildStudentsList(AsyncValue<List<StudentDetailModel>> studentsAsync,
      BuildContext context) {
    return studentsAsync.when(
      data: (students) {
        if (students.isEmpty) {
          return const Center(child: Text('No students in this class'));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: students.length > 5 ? 5 : students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return ListTile(
              leading: UserAvatar(
                  name: student.fullName, imageUrl: student.profileImage),
              title: Text(student.fullName),
              subtitle: Text('Roll No: ${student.rollNumber}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/principal/students/${student.id}'),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }

  void _showEditClassDialog(
      BuildContext context, WidgetRef ref, ClassModel cls) {
    final nameController = TextEditingController(text: cls.name);
    final sectionController = TextEditingController(text: cls.section);
    final yearController = TextEditingController(text: cls.academicYear);
    bool isActive = cls.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Class'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Class Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: sectionController,
                  decoration: const InputDecoration(labelText: 'Section'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: yearController,
                  decoration: const InputDecoration(labelText: 'Academic Year'),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (val) => setDialogState(() => isActive = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await ref
                    .read(classManagementProvider.notifier)
                    .updateClass(
                      cls.id,
                      name: nameController.text,
                      section: sectionController.text,
                      academicYear: yearController.text,
                      isActive: isActive,
                    );
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Class updated successfully')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class'),
        content: const Text(
            'Are you sure you want to delete this class? This will affect all students and subjects linked to it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await ref.read(classManagementProvider.notifier).deleteClass(classId);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class deleted successfully')),
        );
        context.pop();
      }
    }
  }
}
