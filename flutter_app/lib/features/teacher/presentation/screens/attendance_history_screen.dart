import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../../principal/data/models/teacher_model.dart';
import '../../data/models/attendance_model.dart';
import '../providers/teacher_providers.dart';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState
    extends ConsumerState<AttendanceHistoryScreen> {
  String? _selectedClassId;
  String? _selectedSubjectId;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(myClassesProvider);
    final subjectsAsync = ref.watch(mySubjectsProvider(_selectedClassId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
      ),
      body: Column(
        children: [
          // Filters
          _buildFilters(classesAsync, subjectsAsync),
          // History List
          Expanded(
            child: _selectedClassId == null || _selectedSubjectId == null
                ? const EmptyStateWidget(
                    icon: Icons.history,
                    title: 'Select Class and Subject',
                    subtitle: 'Choose filters to view attendance history',
                  )
                : _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(AsyncValue<List<ClassModel>> classesAsync,
      AsyncValue<List<SubjectModel>> subjectsAsync) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: classesAsync.when(
                  data: (classes) => DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: classes
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.displayName),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedClassId = v;
                      _selectedSubjectId = null;
                    }),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Error'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: subjectsAsync.when(
                  data: (subjects) => DropdownButtonFormField<String>(
                    value: _selectedSubjectId,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    items: subjects
                        .map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedSubjectId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Error'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDateTile('From', _startDate, (date) {
                  setState(() => _startDate = date);
                }),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateTile('To', _endDate, (date) {
                  setState(() => _endDate = date);
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateTile(String label, DateTime date, Function(DateTime) onTap) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onTap(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(DateFormat('dd MMM yyyy').format(date)),
      ),
    );
  }

  Widget _buildHistoryList() {
    final filter = AttendanceFilter(
      classId: _selectedClassId!,
      subjectId: _selectedSubjectId!,
      // We need a way to pass range, but the current provider only takes one date or null.
      // For now, let's just fetch all and filter client side or update provider.
    );

    // Fetching all records for the class/subject
    final recordsAsync = ref.watch(attendanceProvider(filter));

    return recordsAsync.when(
      data: (records) {
        // Filter by date range
        final filteredRecords = records.where((r) {
          final date = DateTime(r.date.year, r.date.month, r.date.day);
          return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
              date.isBefore(_endDate.add(const Duration(days: 1)));
        }).toList();

        if (filteredRecords.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.search_off,
            title: 'No Records Found',
            subtitle: 'Try changing the date range or filters',
          );
        }

        // Group by date
        final Map<DateTime, List<AttendanceModel>> grouped = {};
        for (final record in filteredRecords) {
          final date =
              DateTime(record.date.year, record.date.month, record.date.day);
          grouped.putIfAbsent(date, () => []).add(record);
        }

        final sortedDates = grouped.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDates.length,
          itemBuilder: (context, index) {
            final date = sortedDates[index];
            final dateRecords = grouped[date]!;
            final presentCount = dateRecords
                .where((r) => r.status == AttendanceStatus.present)
                .length;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text(
                  DateFormat('EEEE, dd MMM yyyy').format(date),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Present: $presentCount / ${dateRecords.length}',
                  style: TextStyle(
                    color: presentCount == dateRecords.length
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
                children: dateRecords
                    .map((r) => ListTile(
                          leading: UserAvatar(name: r.studentName, size: 32),
                          title: Text(r.studentName),
                          subtitle:
                              Text('Roll: ${r.studentRollNumber ?? 'N/A'}'),
                          trailing: _buildStatusBadge(r.status),
                        ))
                    .toList(),
              ),
            );
          },
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => ErrorStateWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(attendanceProvider(filter)),
      ),
    );
  }

  Widget _buildStatusBadge(AttendanceStatus status) {
    Color color;
    String label;

    switch (status) {
      case AttendanceStatus.present:
        color = AppColors.success;
        label = 'P';
        break;
      case AttendanceStatus.absent:
        color = AppColors.error;
        label = 'A';
        break;
      case AttendanceStatus.late:
        color = AppColors.warning;
        label = 'L';
        break;
      case AttendanceStatus.excused:
        color = AppColors.info;
        label = 'E';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
