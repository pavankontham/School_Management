import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../../principal/data/models/teacher_model.dart';
import '../../data/models/quiz_model.dart';
import '../../data/repositories/teacher_repository.dart';
import '../providers/teacher_providers.dart';

class QuizManagementScreen extends ConsumerStatefulWidget {
  const QuizManagementScreen({super.key});

  @override
  ConsumerState<QuizManagementScreen> createState() =>
      _QuizManagementScreenState();
}

class _QuizManagementScreenState extends ConsumerState<QuizManagementScreen> {
  String? _selectedSubjectId;

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(mySubjectsProvider(null));
    final quizzesAsync = ref.watch(quizzesProvider(_selectedSubjectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(quizzesProvider(_selectedSubjectId));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Subject filter
          subjectsAsync.when(
            data: (subjects) => _buildSubjectFilter(subjects),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Quiz list
          Expanded(
            child: quizzesAsync.when(
              data: (quizzes) => _buildQuizList(quizzes),
              loading: () => const LoadingWidget(),
              error: (e, _) => ErrorStateWidget(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(quizzesProvider(_selectedSubjectId)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateQuizDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Create Quiz'),
      ),
    );
  }

  Widget _buildSubjectFilter(List<SubjectModel> subjects) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All Subjects', _selectedSubjectId == null, () {
              setState(() => _selectedSubjectId = null);
            }),
            ...subjects.map((subject) => _buildFilterChip(
                  subject.name,
                  _selectedSubjectId == subject.id,
                  () => setState(() => _selectedSubjectId = subject.id),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withAlpha(50),
        checkmarkColor: AppColors.primary,
      ),
    );
  }

  Widget _buildQuizList(List<QuizModel> quizzes) {
    if (quizzes.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.quiz_outlined,
        title: 'No Quizzes Yet',
        subtitle: 'Create your first quiz to get started',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(quizzesProvider(_selectedSubjectId));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: quizzes.length,
        itemBuilder: (context, index) => _QuizCard(
          quiz: quizzes[index],
          onTap: () => _showQuizDetails(quizzes[index]),
          onEdit: () => _showEditQuizDialog(quizzes[index]),
          onDelete: () => _confirmDeleteQuiz(quizzes[index]),
          onViewResults: () => _showQuizResults(quizzes[index]),
        ),
      ),
    );
  }

  void _showCreateQuizDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _CreateQuizForm(
          scrollController: scrollController,
          onCreated: () {
            Navigator.pop(context);
            ref.invalidate(quizzesProvider(_selectedSubjectId));
          },
        ),
      ),
    );
  }

  void _showEditQuizDialog(QuizModel quiz) {
    final titleController = TextEditingController(text: quiz.title);
    final descriptionController = TextEditingController(text: quiz.description);
    final durationController =
        TextEditingController(text: quiz.duration.toString());
    bool isActive = quiz.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Quiz'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: durationController,
                  decoration:
                      const InputDecoration(labelText: 'Duration (minutes)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
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
                final result =
                    await ref.read(teacherRepositoryProvider).updateQuiz(
                          quiz.id,
                          title: titleController.text,
                          description: descriptionController.text,
                          duration: int.tryParse(durationController.text) ?? 30,
                          isActive: isActive,
                        );

                if (result.success) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ref.invalidate(quizzesProvider(_selectedSubjectId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Quiz updated successfully')),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(result.error ?? 'Update failed'),
                          backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteQuiz(QuizModel quiz) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quiz'),
        content: Text('Are you sure you want to delete "${quiz.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final result =
                  await ref.read(teacherRepositoryProvider).deleteQuiz(quiz.id);
              if (result.success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Quiz deleted successfully')),
                  );
                  ref.invalidate(quizzesProvider(_selectedSubjectId));
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(result.error ?? 'Failed to delete quiz')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showQuizDetails(QuizModel quiz) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _QuizDetailsSheet(quiz: quiz),
    );
  }

  void _showQuizResults(QuizModel quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _QuizResultsScreen(quiz: quiz),
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final QuizModel quiz;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewResults;

  const _QuizCard({
    required this.quiz,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onViewResults,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.quiz,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quiz.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          quiz.subjectName ?? 'Unknown Subject',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                      Icons.help_outline, '${quiz.totalQuestions} Q'),
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.timer_outlined, '${quiz.duration} min'),
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.star_outline, '${quiz.totalMarks} pts'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onViewResults,
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: const Text('Results'),
                  ),
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: AppColors.error),
                    label: Text('Delete',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final isActive = quiz.isActive;
    final now = DateTime.now();
    final isScheduled = quiz.startTime != null && quiz.startTime!.isAfter(now);
    final isExpired = quiz.endTime != null && quiz.endTime!.isBefore(now);

    String text;
    Color color;

    if (!isActive) {
      text = 'Inactive';
      color = AppColors.textSecondary;
    } else if (isExpired) {
      text = 'Expired';
      color = AppColors.error;
    } else if (isScheduled) {
      text = 'Scheduled';
      color = AppColors.warning;
    } else {
      text = 'Active';
      color = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CreateQuizForm extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final VoidCallback onCreated;

  const _CreateQuizForm({
    required this.scrollController,
    required this.onCreated,
  });

  @override
  ConsumerState<_CreateQuizForm> createState() => _CreateQuizFormState();
}

class _CreateQuizFormState extends ConsumerState<_CreateQuizForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController(text: '30');

  String? _selectedClassId;
  String? _selectedSubjectId;
  bool _isLoading = false;
  final List<Map<String, dynamic>> _questions = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(myClassesProvider);
    final subjectsAsync = ref.watch(mySubjectsProvider(_selectedClassId));

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Create New Quiz',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Quiz Title',
                hintText: 'Enter quiz title',
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Enter quiz description',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            classesAsync.when(
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
                validator: (v) => v == null ? 'Required' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error loading classes'),
            ),
            const SizedBox(height: 16),
            subjectsAsync.when(
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
                validator: (v) => v == null ? 'Required' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error loading subjects'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
                hintText: 'Enter duration',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v?.isEmpty == true) return 'Required';
                if (int.tryParse(v!) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Questions (${_questions.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Question'),
                ),
              ],
            ),
            if (_questions.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No questions added yet.\nTap "Add Question" to create questions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ..._questions.asMap().entries.map((entry) => _buildQuestionCard(
                    entry.key,
                    entry.value,
                  )),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createQuiz,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Quiz'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, Map<String, dynamic> question) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question['question'] ?? 'Question ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _editQuestion(index),
                ),
                IconButton(
                  icon: Icon(Icons.delete, size: 18, color: AppColors.error),
                  onPressed: () => _removeQuestion(index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addQuestion() {
    _showQuestionDialog();
  }

  void _editQuestion(int index) {
    _showQuestionDialog(existingQuestion: _questions[index], index: index);
  }

  void _removeQuestion(int index) {
    setState(() => _questions.removeAt(index));
  }

  void _showQuestionDialog(
      {Map<String, dynamic>? existingQuestion, int? index}) {
    final questionController = TextEditingController(
      text: existingQuestion?['question'] ?? '',
    );
    final option1Controller = TextEditingController(
      text: existingQuestion?['options']?[0] ?? '',
    );
    final option2Controller = TextEditingController(
      text: existingQuestion?['options']?[1] ?? '',
    );
    final option3Controller = TextEditingController(
      text: existingQuestion?['options']?[2] ?? '',
    );
    final option4Controller = TextEditingController(
      text: existingQuestion?['options']?[3] ?? '',
    );
    String correctAnswer = existingQuestion?['correctAnswer'] ?? '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title:
              Text(existingQuestion != null ? 'Edit Question' : 'Add Question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  decoration: const InputDecoration(labelText: 'Question'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: option1Controller,
                  decoration: InputDecoration(
                    labelText: 'Option A',
                    suffixIcon: Radio<String>(
                      value: option1Controller.text,
                      groupValue: correctAnswer,
                      onChanged: (v) => setDialogState(
                          () => correctAnswer = option1Controller.text),
                    ),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                TextField(
                  controller: option2Controller,
                  decoration: InputDecoration(
                    labelText: 'Option B',
                    suffixIcon: Radio<String>(
                      value: option2Controller.text,
                      groupValue: correctAnswer,
                      onChanged: (v) => setDialogState(
                          () => correctAnswer = option2Controller.text),
                    ),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                TextField(
                  controller: option3Controller,
                  decoration: InputDecoration(
                    labelText: 'Option C',
                    suffixIcon: Radio<String>(
                      value: option3Controller.text,
                      groupValue: correctAnswer,
                      onChanged: (v) => setDialogState(
                          () => correctAnswer = option3Controller.text),
                    ),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                TextField(
                  controller: option4Controller,
                  decoration: InputDecoration(
                    labelText: 'Option D',
                    suffixIcon: Radio<String>(
                      value: option4Controller.text,
                      groupValue: correctAnswer,
                      onChanged: (v) => setDialogState(
                          () => correctAnswer = option4Controller.text),
                    ),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the correct answer using the radio buttons',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
              onPressed: () {
                if (questionController.text.isEmpty) return;
                final question = {
                  'question': questionController.text,
                  'type': 'MCQ',
                  'options': [
                    option1Controller.text,
                    option2Controller.text,
                    option3Controller.text,
                    option4Controller.text,
                  ].where((o) => o.isNotEmpty).toList(),
                  'correctAnswer': correctAnswer,
                  'marks': 1,
                };
                setState(() {
                  if (index != null) {
                    _questions[index] = question;
                  } else {
                    _questions.add(question);
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createQuiz() async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one question')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ref.read(teacherRepositoryProvider).createQuiz(
            title: _titleController.text,
            description: _descriptionController.text.isEmpty
                ? null
                : _descriptionController.text,
            subjectId: _selectedSubjectId!,
            classId: _selectedClassId!,
            timeLimit: int.parse(_durationController.text),
            questions: _questions,
          );

      if (result.success) {
        widget.onCreated();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? 'Failed to create quiz')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _QuizDetailsSheet extends ConsumerWidget {
  final QuizModel quiz;

  const _QuizDetailsSheet({required this.quiz});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizAsync = ref.watch(quizProvider(quiz.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              quiz.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (quiz.description != null) ...[
              const SizedBox(height: 8),
              Text(
                quiz.description!,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            _buildInfoRow('Subject', quiz.subjectName ?? 'Unknown'),
            _buildInfoRow('Class', quiz.className ?? 'Unknown'),
            _buildInfoRow('Duration', '${quiz.duration} minutes'),
            _buildInfoRow('Total Questions', '${quiz.totalQuestions}'),
            _buildInfoRow('Total Marks', '${quiz.totalMarks}'),
            _buildInfoRow('Status', quiz.isActive ? 'Active' : 'Inactive'),
            if (quiz.startTime != null)
              _buildInfoRow(
                'Start Time',
                DateFormat('MMM d, yyyy h:mm a').format(quiz.startTime!),
              ),
            if (quiz.endTime != null)
              _buildInfoRow(
                'End Time',
                DateFormat('MMM d, yyyy h:mm a').format(quiz.endTime!),
              ),
            const SizedBox(height: 24),
            const Text(
              'Questions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            quizAsync.when(
              data: (quizDetail) {
                if (quizDetail?.questions == null ||
                    quizDetail!.questions!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('No questions available'),
                    ),
                  );
                }
                return Column(
                  children: quizDetail.questions!
                      .asMap()
                      .entries
                      .map(
                          (entry) => _buildQuestionItem(entry.key, entry.value))
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error loading questions'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildQuestionItem(int index, QuizQuestionModel question) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question.question,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${question.marks} pts',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (question.options.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...question.options.asMap().entries.map((entry) {
                final isCorrect = entry.value == question.correctAnswer;
                return Padding(
                  padding: const EdgeInsets.only(left: 32, top: 4),
                  child: Row(
                    children: [
                      Icon(
                        isCorrect
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: isCorrect
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 13,
                            color: isCorrect
                                ? AppColors.success
                                : AppColors.textPrimary,
                            fontWeight:
                                isCorrect ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuizResultsScreen extends ConsumerWidget {
  final QuizModel quiz;

  const _QuizResultsScreen({required this.quiz});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(quizResultsProvider(quiz.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('${quiz.title} - Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(quizResultsProvider(quiz.id)),
          ),
        ],
      ),
      body: resultsAsync.when(
        data: (results) => _buildResultsList(results),
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(quizResultsProvider(quiz.id)),
        ),
      ),
    );
  }

  Widget _buildResultsList(List<QuizAttemptModel> results) {
    if (results.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.analytics_outlined,
        title: 'No Results Yet',
        subtitle: 'No students have attempted this quiz yet',
      );
    }

    // Calculate statistics
    final totalAttempts = results.length;
    final avgScore =
        results.fold<double>(0, (sum, r) => sum + r.percentage) / totalAttempts;
    final passedCount = results.where((r) => r.percentage >= 50).length;

    return Column(
      children: [
        // Statistics header
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Attempts', '$totalAttempts'),
              _buildStatItem('Avg Score', '${avgScore.toStringAsFixed(1)}%'),
              _buildStatItem('Passed', '$passedCount/$totalAttempts'),
            ],
          ),
        ),
        // Results list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            itemBuilder: (context, index) => _buildResultCard(results[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
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

  Widget _buildResultCard(QuizAttemptModel attempt) {
    final isPassed = attempt.percentage >= 50;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isPassed
                  ? AppColors.success.withAlpha(25)
                  : AppColors.error.withAlpha(25),
              child: Icon(
                isPassed ? Icons.check : Icons.close,
                color: isPassed ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attempt.studentName ?? 'Unknown Student',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    attempt.completedAt != null
                        ? 'Completed: ${DateFormat('MMM d, h:mm a').format(attempt.completedAt!)}'
                        : 'In Progress',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${attempt.score}/${attempt.totalMarks}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPassed
                        ? AppColors.success.withAlpha(25)
                        : AppColors.error.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${attempt.percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isPassed ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
