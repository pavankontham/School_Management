import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../data/repositories/teacher_repository.dart';
import '../providers/teacher_providers.dart';

class QuizGenerateScreen extends ConsumerStatefulWidget {
  const QuizGenerateScreen({super.key});

  @override
  ConsumerState<QuizGenerateScreen> createState() => _QuizGenerateScreenState();
}

class _QuizGenerateScreenState extends ConsumerState<QuizGenerateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _titleController = TextEditingController();
  final _timeLimitController = TextEditingController(text: '30');

  String? _selectedClassId;
  String? _selectedSubjectId;
  int _questionCount = 10;
  String _questionType = 'MCQ';
  bool _saveAsQuiz = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _topicController.dispose();
    _titleController.dispose();
    _timeLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(myClassesProvider);
    final subjectsAsync = ref.watch(mySubjectsProvider(_selectedClassId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Quiz Generator'),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _topicController,
                      decoration: const InputDecoration(
                        labelText: 'Topic',
                        hintText: 'e.g. Photosynthesis, Algebra, etc.',
                        prefixIcon: Icon(Icons.topic_outlined),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    classesAsync.when(
                      data: (classes) => DropdownButtonFormField<String>(
                        value: _selectedClassId,
                        decoration: const InputDecoration(
                          labelText: 'Class',
                          prefixIcon: Icon(Icons.class_outlined),
                        ),
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
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Error loading classes'),
                    ),
                    const SizedBox(height: 16),
                    subjectsAsync.when(
                      data: (subjects) => DropdownButtonFormField<String>(
                        value: _selectedSubjectId,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          prefixIcon: Icon(Icons.book_outlined),
                        ),
                        items: subjects
                            .map((s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.name),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedSubjectId = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Error loading subjects'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _questionCount,
                            decoration: const InputDecoration(
                              labelText: 'Questions',
                              prefixIcon: Icon(Icons.numbers),
                            ),
                            items: [5, 10, 15, 20]
                                .map((i) => DropdownMenuItem(
                                      value: i,
                                      child: Text('$i Questions'),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _questionCount = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _questionType,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                              prefixIcon: Icon(Icons.help_outline),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'MCQ', child: Text('MCQ')),
                              DropdownMenuItem(
                                  value: 'TRUE_FALSE', child: Text('T/F')),
                            ],
                            onChanged: (v) =>
                                setState(() => _questionType = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_saveAsQuiz) ...[
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Quiz Title',
                          hintText: 'Enter quiz title',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (v) => _saveAsQuiz && v?.isEmpty == true
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _timeLimitController,
                        decoration: const InputDecoration(
                          labelText: 'Time Limit (mins)',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => _saveAsQuiz && v?.isEmpty == true
                            ? 'Required'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Save as Active Quiz'),
                      subtitle: const Text(
                          'Automatically make the quiz available to students'),
                      value: _saveAsQuiz,
                      onChanged: (v) => setState(() => _saveAsQuiz = v),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _generateQuiz,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Generate with AI'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.accent, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Powered Generation',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.accent,
                  ),
                ),
                Text(
                  'Our AI will create a comprehensive quiz based on your topic and grade level.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.accent.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LoadingWidget(),
          const SizedBox(height: 24),
          const Text(
            'Gemini AI is generating your quiz...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'This may take 30-60 seconds depending on the complexity of the topic.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateQuiz() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ref.read(teacherRepositoryProvider).generateQuiz(
            topic: _topicController.text,
            subjectId: _selectedSubjectId!,
            classId: _selectedClassId!,
            count: _questionCount,
            questionType: _questionType,
            title:
                _titleController.text.isNotEmpty ? _titleController.text : null,
            timeLimit: int.tryParse(_timeLimitController.text),
            saveQuiz: _saveAsQuiz,
          );

      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quiz generated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.invalidate(quizzesProvider(null));
        context.pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to generate quiz'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
