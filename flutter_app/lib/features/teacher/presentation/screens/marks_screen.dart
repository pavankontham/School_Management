import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../../common/presentation/widgets/custom_text_field.dart';
import '../../../common/presentation/widgets/loading_button.dart';
import '../../../principal/data/models/teacher_model.dart';
import '../../data/models/attendance_model.dart';
import '../../data/repositories/teacher_repository.dart';
import '../providers/teacher_providers.dart';

class MarksScreen extends ConsumerStatefulWidget {
  const MarksScreen({super.key});

  @override
  ConsumerState<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends ConsumerState<MarksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedClassId;
  String? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(myClassesProvider);
    final subjectsAsync = ref.watch(mySubjectsProvider(_selectedClassId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marks'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Enter Marks'),
            Tab(text: 'View Records'),
          ],
        ),
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
            child: Row(
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
                        });
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Error'),
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
                        setState(() => _selectedSubjectId = value);
                      },
                      enabled: _selectedClassId != null,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Error'),
                  ),
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _EnterMarksTab(
                  classId: _selectedClassId,
                  subjectId: _selectedSubjectId,
                ),
                _ViewMarksTab(
                  classId: _selectedClassId,
                  subjectId: _selectedSubjectId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnterMarksTab extends ConsumerStatefulWidget {
  final String? classId;
  final String? subjectId;

  const _EnterMarksTab({this.classId, this.subjectId});

  @override
  ConsumerState<_EnterMarksTab> createState() => _EnterMarksTabState();
}

class _EnterMarksTabState extends ConsumerState<_EnterMarksTab> {
  final _formKey = GlobalKey<FormState>();
  String _examType = 'TEST';
  double _totalMarks = 100;
  DateTime _examDate = DateTime.now();
  final Map<String, TextEditingController> _marksControllers = {};
  bool _isSubmitting = false;

  @override
  void dispose() {
    for (final controller in _marksControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.classId == null || widget.subjectId == null) {
      return const EmptyStateWidget(
        icon: Icons.grade,
        title: 'Select Class and Subject',
        subtitle: 'Choose a class and subject to enter marks',
      );
    }

    final studentsAsync = ref.watch(classStudentsProvider(widget.classId!));

    return studentsAsync.when(
      data: (students) {
        // Initialize controllers
        for (final student in students) {
          _marksControllers.putIfAbsent(
            student.id,
            () => TextEditingController(),
          );
        }

        return Form(
          key: _formKey,
          child: Column(
            children: [
              // Exam details
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomDropdownField<String>(
                        label: 'Exam Type',
                        value: _examType,
                        items: const [
                          DropdownMenuItem(value: 'TEST', child: Text('Test')),
                          DropdownMenuItem(value: 'QUIZ', child: Text('Quiz')),
                          DropdownMenuItem(value: 'MIDTERM', child: Text('Midterm')),
                          DropdownMenuItem(value: 'FINAL', child: Text('Final')),
                          DropdownMenuItem(value: 'ASSIGNMENT', child: Text('Assignment')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _examType = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        label: 'Total Marks',
                        initialValue: _totalMarks.toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _totalMarks = double.tryParse(value) ?? 100;
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Students list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            UserAvatar(
                              name: '${student.firstName} ${student.lastName}',
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${student.firstName} ${student.lastName}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Roll: ${student.rollNumber}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: _marksControllers[student.id],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: '0',
                                  suffixText: '/$_totalMarks',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    final marks = double.tryParse(value);
                                    if (marks == null || marks < 0 || marks > _totalMarks) {
                                      return 'Invalid';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Submit button
              Container(
                padding: const EdgeInsets.all(16),
                child: LoadingButton(
                  onPressed: _submitMarks,
                  isLoading: _isSubmitting,
                  text: 'Submit Marks',
                  icon: Icons.check,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => ErrorStateWidget(message: e.toString()),
    );
  }

  Future<void> _submitMarks() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.subjectId == null) return;

    setState(() => _isSubmitting = true);

    final marks = <Map<String, dynamic>>[];
    for (final entry in _marksControllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) {
        marks.add({
          'studentId': entry.key,
          'marksObtained': double.parse(value),
        });
      }
    }

    if (marks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter marks for at least one student')),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    final result = await ref.read(teacherRepositoryProvider).submitMarks(
      subjectId: widget.subjectId!,
      examType: _examType,
      totalMarks: _totalMarks,
      examDate: _examDate,
      marks: marks,
    );

    setState(() => _isSubmitting = false);

    if (result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marks submitted successfully')),
      );
      // Clear controllers
      for (final controller in _marksControllers.values) {
        controller.clear();
      }
      ref.invalidate(marksProvider);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to submit marks')),
      );
    }
  }
}

class _ViewMarksTab extends ConsumerWidget {
  final String? classId;
  final String? subjectId;

  const _ViewMarksTab({this.classId, this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (classId == null || subjectId == null) {
      return const EmptyStateWidget(
        icon: Icons.grade,
        title: 'Select Class and Subject',
        subtitle: 'Choose a class and subject to view marks',
      );
    }

    final marksAsync = ref.watch(marksProvider(
      MarksFilter(classId: classId, subjectId: subjectId),
    ));

    return marksAsync.when(
      data: (marks) {
        if (marks.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.grade_outlined,
            title: 'No marks recorded',
            subtitle: 'Enter marks to see them here',
          );
        }

        // Group by exam type
        final grouped = <String, List<MarksModel>>{};
        for (final mark in marks) {
          grouped.putIfAbsent(mark.examType, () => []).add(mark);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final examType = grouped.keys.elementAt(index);
            final examMarks = grouped[examType]!;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                title: Text(examType),
                subtitle: Text('${examMarks.length} students'),
                children: examMarks.map((mark) => ListTile(
                  leading: UserAvatar(name: mark.studentName, size: 36),
                  title: Text(mark.studentName),
                  subtitle: Text('Roll: ${mark.studentRollNumber ?? 'N/A'}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${mark.marksObtained.toStringAsFixed(0)}/${mark.totalMarks.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${mark.percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: mark.percentage >= 60
                              ? AppColors.success
                              : mark.percentage >= 40
                                  ? AppColors.warning
                                  : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            );
          },
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => ErrorStateWidget(message: e.toString()),
    );
  }
}

