import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../providers/principal_providers.dart';

class StudentDetailScreen extends ConsumerWidget {
  final String studentId;

  const StudentDetailScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentProvider(studentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                context.push('/principal/students/$studentId/edit'),
          ),
        ],
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null) {
            return const Center(child: Text('Student not found'));
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
                          name: student.fullName,
                          imageUrl: student.profileImage,
                          size: 80,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          student.fullName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Roll No: ${student.rollNumber}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!student.isActive) StatusBadge.warning('Inactive'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Class Information
                _buildSectionCard(
                  context,
                  'Class Information',
                  Icons.class_,
                  [
                    _buildInfoRow('Class', student.className ?? 'Not assigned'),
                    _buildInfoRow('Roll Number', student.rollNumber),
                  ],
                ),
                const SizedBox(height: 16),

                // Contact Information
                _buildSectionCard(
                  context,
                  'Contact Information',
                  Icons.contact_mail,
                  [
                    if (student.email != null)
                      _buildInfoRow('Email', student.email!),
                    if (student.phone != null)
                      _buildInfoRow('Phone', student.phone!),
                  ],
                ),
                const SizedBox(height: 16),

                // Parent Information
                _buildSectionCard(
                  context,
                  'Parent Information',
                  Icons.family_restroom,
                  [
                    if (student.parentPhone != null)
                      _buildInfoRow('Parent Phone', student.parentPhone!),
                    if (student.parentEmail != null)
                      _buildInfoRow('Parent Email', student.parentEmail!),
                  ],
                ),
                const SizedBox(height: 16),

                // Additional Information
                _buildSectionCard(
                  context,
                  'Additional Information',
                  Icons.info,
                  [
                    if (student.address != null)
                      _buildInfoRow('Address', student.address!),
                    if (student.gender != null)
                      _buildInfoRow('Gender', student.gender!),
                    _buildInfoRow(
                        'Status', student.isActive ? 'Active' : 'Inactive'),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(studentProvider(studentId)),
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
            width: 120,
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
}
