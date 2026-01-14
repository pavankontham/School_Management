import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../../teacher/data/models/attendance_model.dart'
    show AttendanceStatus;
import '../../data/repositories/student_repository.dart';
import '../providers/student_providers.dart';

class StudentAttendanceScreen extends ConsumerStatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  ConsumerState<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState
    extends ConsumerState<StudentAttendanceScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final filter = AttendanceFilter(month: _selectedMonth, year: _selectedYear);
    final attendanceAsync = ref.watch(studentAttendanceProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          Expanded(
            child: attendanceAsync.when(
              data: (data) => _buildAttendanceContent(data),
              loading: () => const LoadingWidget(),
              error: (e, _) => ErrorStateWidget(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(studentAttendanceProvider(filter)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousMonth,
          ),
          GestureDetector(
            onTap: () => _selectMonth(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                DateFormat('MMMM yyyy').format(
                  DateTime(_selectedYear, _selectedMonth),
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _canGoNext() ? _nextMonth : null,
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceContent(StudentAttendanceData data) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(studentAttendanceProvider(
          AttendanceFilter(month: _selectedMonth, year: _selectedYear),
        ));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryCards(data.summary),
            const SizedBox(height: 24),
            _buildCalendarView(data.records),
            const SizedBox(height: 24),
            _buildAttendanceList(data.records),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(AttendanceSummary summary) {
    return Column(
      children: [
        // Percentage Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                '${summary.percentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                'Attendance Rate',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Stats Row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Present',
                summary.presentDays.toString(),
                AppColors.success,
                Icons.check_circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Absent',
                summary.absentDays.toString(),
                AppColors.error,
                Icons.cancel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Late',
                summary.lateDays.toString(),
                AppColors.warning,
                Icons.access_time,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(List<StudentAttendanceRecord> records) {
    final firstDay = DateTime(_selectedYear, _selectedMonth, 1);
    final lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0);
    final daysInMonth = lastDay.day;
    final startWeekday = firstDay.weekday;

    // Create a map for quick lookup
    final Map<int, AttendanceStatus> attendanceMap = {};
    for (final record in records) {
      if (record.date.month == _selectedMonth &&
          record.date.year == _selectedYear) {
        attendanceMap[record.date.day] = record.status;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Calendar View',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Weekday headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map((d) => SizedBox(
                        width: 36,
                        child: Text(
                          d,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            // Calendar grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: (startWeekday % 7) + daysInMonth,
              itemBuilder: (context, index) {
                final dayOffset = startWeekday % 7;
                if (index < dayOffset) {
                  return const SizedBox();
                }
                final day = index - dayOffset + 1;
                final status = attendanceMap[day];
                return _buildCalendarDay(day, status);
              },
            ),
            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Present', AppColors.success),
                const SizedBox(width: 16),
                _buildLegendItem('Absent', AppColors.error),
                const SizedBox(width: 16),
                _buildLegendItem('Late', AppColors.warning),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarDay(int day, AttendanceStatus? status) {
    Color? bgColor;
    Color textColor = AppColors.textPrimary;

    if (status != null) {
      switch (status) {
        case AttendanceStatus.present:
          bgColor = AppColors.success;
          textColor = Colors.white;
          break;
        case AttendanceStatus.absent:
          bgColor = AppColors.error;
          textColor = Colors.white;
          break;
        case AttendanceStatus.late:
          bgColor = AppColors.warning;
          textColor = Colors.white;
          break;
        case AttendanceStatus.excused:
          bgColor = AppColors.info;
          textColor = Colors.white;
          break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor ?? AppColors.surfaceVariant,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        day.toString(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceList(List<StudentAttendanceRecord> records) {
    if (records.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('No attendance records for this month'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Records',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...records.take(10).map((record) => _buildRecordTile(record)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordTile(StudentAttendanceRecord record) {
    Color statusColor;
    String statusText;
    IconData icon;

    switch (record.status) {
      case AttendanceStatus.present:
        statusColor = AppColors.success;
        statusText = 'Present';
        icon = Icons.check_circle;
        break;
      case AttendanceStatus.absent:
        statusColor = AppColors.error;
        statusText = 'Absent';
        icon = Icons.cancel;
        break;
      case AttendanceStatus.late:
        statusColor = AppColors.warning;
        statusText = 'Late';
        icon = Icons.access_time;
        break;
      case AttendanceStatus.excused:
        statusColor = AppColors.info;
        statusText = 'Excused';
        icon = Icons.info;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMM d').format(record.date),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (record.remarks != null)
                  Text(
                    record.remarks!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _previousMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
  }

  bool _canGoNext() {
    final now = DateTime.now();
    return _selectedYear < now.year ||
        (_selectedYear == now.year && _selectedMonth < now.month);
  }

  Future<void> _selectMonth(BuildContext context) async {
    final result = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear, _selectedMonth),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (result != null) {
      setState(() {
        _selectedMonth = result.month;
        _selectedYear = result.year;
      });
    }
  }
}
