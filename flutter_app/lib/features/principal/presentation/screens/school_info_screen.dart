import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../providers/principal_providers.dart';

class SchoolInfoScreen extends ConsumerWidget {
  const SchoolInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolAsync = ref.watch(schoolInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('School Information'),
      ),
      body: schoolAsync.when(
        data: (school) => school == null
            ? const EmptyStateWidget(
                icon: Icons.school_outlined,
                title: 'No Data',
                subtitle: 'Failed to load school information',
              )
            : _buildContent(context, school),
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(schoolInfoProvider),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, dynamic school) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(school),
          const SizedBox(height: 32),
          _buildInfoSection(
            title: 'General Details',
            items: [
              _InfoTile(
                  label: 'School Name', value: school.name, icon: Icons.school),
              _InfoTile(
                  label: 'School Code',
                  value: school.code ?? 'N/A',
                  icon: Icons.qr_code),
              _InfoTile(
                  label: 'Website',
                  value: school.website ?? 'N/A',
                  icon: Icons.language),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoSection(
            title: 'Contact Information',
            items: [
              _InfoTile(
                  label: 'Phone',
                  value: school.phone ?? 'N/A',
                  icon: Icons.phone),
              _InfoTile(
                  label: 'Address',
                  value: school.address ?? 'N/A',
                  icon: Icons.location_on),
              _InfoTile(
                label: 'City/State',
                value: '${school.city ?? ''}, ${school.state ?? ''}'.trim(),
                icon: Icons.map,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (school.counts != null)
            _buildInfoSection(
              title: 'Statistics',
              items: [
                _InfoTile(
                    label: 'Total Teachers',
                    value: school.counts!['users']?.toString() ?? '0',
                    icon: Icons.people),
                _InfoTile(
                    label: 'Total Students',
                    value: school.counts!['students']?.toString() ?? '0',
                    icon: Icons.person_pin),
                _InfoTile(
                    label: 'Total Classes',
                    value: school.counts!['classes']?.toString() ?? '0',
                    icon: Icons.class_),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHero(dynamic school) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage:
                school.logo != null ? NetworkImage(school.logo!) : null,
            child: school.logo == null
                ? const Icon(Icons.school, size: 50, color: AppColors.primary)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            school.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          if (school.code != null)
            Text(
              'Code: ${school.code}',
              style: TextStyle(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
      {required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        Card(
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 20),
      title: Text(
        label,
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
