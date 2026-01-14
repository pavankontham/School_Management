import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/loading_button.dart';
import '../../data/repositories/teacher_repository.dart';
import '../providers/teacher_providers.dart';

class FaceRecognitionAttendanceScreen extends ConsumerStatefulWidget {
  const FaceRecognitionAttendanceScreen({super.key});

  @override
  ConsumerState<FaceRecognitionAttendanceScreen> createState() =>
      _FaceRecognitionAttendanceScreenState();
}

class _FaceRecognitionAttendanceScreenState
    extends ConsumerState<FaceRecognitionAttendanceScreen> {
  String? _selectedClassId;
  DateTime _selectedDate = DateTime.now();
  String _selectedSession = 'MORNING';
  final List<File> _groupPhotos = [];
  List<Map<String, dynamic>> _students = [];
  bool _isProcessing = false;
  bool _isSubmitting = false;

  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(myClassesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition Attendance'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Card
            Card(
              color: AppColors.info.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.info),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Upload group photos of students. The system will detect faces and mark attendance automatically. You can review and edit before submitting.',
                        style: TextStyle(color: AppColors.info, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Class Selection
            classesAsync.when(
              data: (classes) => DropdownButtonFormField<String>(
                value: _selectedClassId,
                decoration: const InputDecoration(
                  labelText: 'Select Class *',
                  prefixIcon: Icon(Icons.class_),
                  border: OutlineInputBorder(),
                ),
                items: classes
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.displayName),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedClassId = value;
                    _students = [];
                    _groupPhotos.clear();
                  });
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Failed to load classes'),
            ),
            const SizedBox(height: 16),

            // Date Selection
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
              ),
            ),
            const SizedBox(height: 16),

            // Session Selection
            DropdownButtonFormField<String>(
              value: _selectedSession,
              decoration: const InputDecoration(
                labelText: 'Session',
                prefixIcon: Icon(Icons.wb_sunny),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'MORNING', child: Text('Morning')),
                DropdownMenuItem(value: 'AFTERNOON', child: Text('Afternoon')),
              ],
              onChanged: (value) {
                setState(() => _selectedSession = value!);
              },
            ),
            const SizedBox(height: 24),

            // Photo Upload Section
            const Text(
              'Group Photos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Photo Grid
            if (_groupPhotos.isNotEmpty) ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _groupPhotos.length,
                itemBuilder: (context, index) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _groupPhotos[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          padding: const EdgeInsets.all(4),
                        ),
                        onPressed: () {
                          setState(() => _groupPhotos.removeAt(index));
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Add Photo Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('From Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Process Button
            if (_groupPhotos.isNotEmpty && _selectedClassId != null)
              LoadingButton(
                onPressed: _processPhotos,
                isLoading: _isProcessing,
                text: 'Process Photos',
              ),

            // Students List (after processing)
            if (_students.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Review Attendance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_students.where((s) => s['status'] == 'PRESENT').length}/${_students.length} Present',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Students List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _students.length,
                itemBuilder: (context, index) {
                  final student = _students[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: student['detected']
                            ? AppColors.success.withOpacity(0.2)
                            : AppColors.error.withOpacity(0.2),
                        child: Icon(
                          student['detected'] ? Icons.check : Icons.close,
                          color: student['detected']
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      title: Text(student['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Roll: ${student['rollNumber']}'),
                          if (student['detected'] && student['confidence'] > 0)
                            Text(
                              'Confidence: ${(student['confidence'] * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      trailing: DropdownButton<String>(
                        value: student['status'],
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                            value: 'PRESENT',
                            child: Text('Present',
                                style: TextStyle(color: AppColors.success)),
                          ),
                          DropdownMenuItem(
                            value: 'ABSENT',
                            child: Text('Absent',
                                style: TextStyle(color: AppColors.error)),
                          ),
                          DropdownMenuItem(
                            value: 'LATE',
                            child: Text('Late',
                                style: TextStyle(color: AppColors.warning)),
                          ),
                          DropdownMenuItem(
                            value: 'EXCUSED',
                            child: Text('Excused',
                                style: TextStyle(color: AppColors.info)),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _students[index]['status'] = value;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Submit Button
              LoadingButton(
                onPressed: _submitAttendance,
                isLoading: _isSubmitting,
                text: 'Submit Attendance',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _groupPhotos.add(File(image.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _processPhotos() async {
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result =
          await ref.read(teacherRepositoryProvider).processAttendancePhotos(
                classId: _selectedClassId!,
                date: _selectedDate,
                session: _selectedSession,
                photos: _groupPhotos,
              );

      if (result.success && result.data != null) {
        setState(() {
          _students =
              List<Map<String, dynamic>>.from(result.data!['students'] ?? []);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? 'Failed to process photos')),
          );
        }
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _submitAttendance() async {
    setState(() => _isSubmitting = true);

    try {
      final attendance = _students
          .map((s) => {
                'studentId': s['id'],
                'status': s['status'],
                'confidence': s['confidence'],
              })
          .toList();

      final result =
          await ref.read(teacherRepositoryProvider).confirmAttendance(
                classId: _selectedClassId!,
                date: _selectedDate,
                attendance: attendance,
              );

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attendance submitted successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(result.error ?? 'Failed to submit attendance')),
          );
        }
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}
