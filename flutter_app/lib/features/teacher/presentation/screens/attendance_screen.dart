import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../../common/presentation/widgets/custom_text_field.dart';
import '../../../common/presentation/widgets/loading_button.dart';
import '../../../principal/data/models/teacher_model.dart';
import '../../data/models/attendance_model.dart';
import '../providers/teacher_providers.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  String? _selectedClassId;
  String? _selectedSubjectId;
  DateTime _selectedDate = DateTime.now();
  bool _isInitialized = false;

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(myClassesProvider);
    final subjectsAsync = ref.watch(mySubjectsProvider(_selectedClassId));
    final attendanceState = ref.watch(attendanceNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: 'Face Recognition',
            onPressed: _selectedClassId != null ? _openCamera : null,
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all_present', child: Text('Mark All Present')),
              const PopupMenuItem(value: 'all_absent', child: Text('Mark All Absent')),
              const PopupMenuItem(value: 'history', child: Text('View History')),
            ],
            onSelected: (value) {
              switch (value) {
                case 'all_present':
                  ref.read(attendanceNotifierProvider.notifier).markAllPresent();
                  break;
                case 'all_absent':
                  ref.read(attendanceNotifierProvider.notifier).markAllAbsent();
                  break;
                case 'history':
                  if (_selectedClassId != null && _selectedSubjectId != null) {
                    context.push('/teacher/attendance/history');
                  }
                  break;
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
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
                        data: (classes) => CustomDropdownField<String>(
                          label: 'Class',
                          hint: 'Select class',
                          value: _selectedClassId,
                          items: classes
                              .map((c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.displayName),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedClassId = value;
                              _selectedSubjectId = null;
                              _isInitialized = false;
                            });
                          },
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Error loading classes'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: subjectsAsync.when(
                        data: (subjects) => CustomDropdownField<String>(
                          label: 'Subject',
                          hint: 'Select subject',
                          value: _selectedSubjectId,
                          items: subjects
                              .map((s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text(s.name),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedSubjectId = value;
                              _isInitialized = false;
                            });
                            if (value != null && _selectedClassId != null) {
                              _loadStudents();
                            }
                          },
                          enabled: _selectedClassId != null,
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Error loading subjects'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomDateField(
                  label: 'Date',
                  value: _selectedDate,
                  lastDate: DateTime.now(),
                  onChanged: (date) {
                    setState(() => _selectedDate = date);
                    if (_selectedClassId != null && _selectedSubjectId != null) {
                      _loadStudents();
                    }
                  },
                ),
              ],
            ),
          ),

          // Error message
          if (attendanceState.error != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(attendanceState.error!)),
                ],
              ),
            ),

          // Face recognition indicator
          if (attendanceState.isRecognizing)
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.info.withOpacity(0.1),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Recognizing faces...'),
                ],
              ),
            ),

          // Attendance list
          Expanded(
            child: _selectedClassId == null || _selectedSubjectId == null
                ? const EmptyStateWidget(
                    icon: Icons.checklist,
                    title: 'Select Class and Subject',
                    subtitle: 'Choose a class and subject to take attendance',
                  )
                : attendanceState.records.isEmpty
                    ? const LoadingWidget(message: 'Loading students...')
                    : _buildAttendanceList(attendanceState.records),
          ),
        ],
      ),
      bottomNavigationBar: _selectedClassId != null &&
              _selectedSubjectId != null &&
              attendanceState.records.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: LoadingButton(
                  onPressed: _submitAttendance,
                  isLoading: attendanceState.isLoading,
                  text: 'Submit Attendance',
                  icon: Icons.check,
                ),
              ),
            )
          : null,
    );
  }

  void _loadStudents() {
    if (_selectedClassId == null) return;
    
    ref.read(classStudentsProvider(_selectedClassId!)).whenData((students) {
      if (!_isInitialized) {
        ref.read(attendanceNotifierProvider.notifier).initializeRecords(students);
        _isInitialized = true;
      }
    });
  }

  Widget _buildAttendanceList(List<AttendanceRecord> records) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _AttendanceCard(
          record: record,
          onStatusChanged: (status) {
            ref.read(attendanceNotifierProvider.notifier)
                .updateStatus(record.studentId, status);
          },
        );
      },
    );
  }

  Future<void> _openCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    
    if (image != null && _selectedClassId != null) {
      await ref.read(attendanceNotifierProvider.notifier)
          .recognizeFaces(File(image.path), _selectedClassId!);
    }
  }

  Future<void> _submitAttendance() async {
    if (_selectedClassId == null || _selectedSubjectId == null) return;

    final success = await ref.read(attendanceNotifierProvider.notifier)
        .submitAttendance(
          classId: _selectedClassId!,
          subjectId: _selectedSubjectId!,
          date: _selectedDate,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance submitted successfully')),
      );
      context.pop();
    }
  }
}

class _AttendanceCard extends StatelessWidget {
  final AttendanceRecord record;
  final void Function(AttendanceStatus) onStatusChanged;

  const _AttendanceCard({
    required this.record,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Stack(
              children: [
                UserAvatar(
                  name: record.studentName,
                  imageUrl: record.profileImage,
                  size: 44,
                ),
                if (record.confidence != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.face, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.studentName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Roll: ${record.rollNumber}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (record.confidence != null)
                    Text(
                      'Confidence: ${(record.confidence! * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 11, color: AppColors.success),
                    ),
                ],
              ),
            ),
            _StatusSelector(
              status: record.status,
              onChanged: onStatusChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  final AttendanceStatus status;
  final void Function(AttendanceStatus) onChanged;

  const _StatusSelector({required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AttendanceStatus>(
      segments: const [
        ButtonSegment(value: AttendanceStatus.present, label: Text('P')),
        ButtonSegment(value: AttendanceStatus.absent, label: Text('A')),
        ButtonSegment(value: AttendanceStatus.late, label: Text('L')),
      ],
      selected: {status},
      onSelectionChanged: (set) => onChanged(set.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

