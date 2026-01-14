import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../data/models/student_data_models.dart';
import '../providers/student_providers.dart';

class StudentQuizAttemptScreen extends ConsumerStatefulWidget {
  final String quizId;

  const StudentQuizAttemptScreen({super.key, required this.quizId});

  @override
  ConsumerState<StudentQuizAttemptScreen> createState() =>
      _StudentQuizAttemptScreenState();
}

class _StudentQuizAttemptScreenState
    extends ConsumerState<StudentQuizAttemptScreen> {
  int _currentQuestionIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(quizAttemptProvider(widget.quizId).notifier).startQuiz();
    });
  }

  @override
  Widget build(BuildContext context) {
    final quizAsync = ref.watch(studentQuizProvider(widget.quizId));
    final attemptState = ref.watch(quizAttemptProvider(widget.quizId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Attempt'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmExit(),
        ),
      ),
      body: quizAsync.when(
        data: (quiz) => quiz == null
            ? const Center(child: Text('Quiz not found'))
            : _buildContent(quiz, attemptState),
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(studentQuizProvider(widget.quizId)),
        ),
      ),
    );
  }

  Widget _buildContent(StudentQuizModel quiz, QuizAttemptState state) {
    if (state.isSubmitted) {
      return _buildResult(state);
    }

    if (quiz.questions == null || quiz.questions!.isEmpty) {
      return const Center(child: Text('No questions available in this quiz.'));
    }

    final question = quiz.questions![_currentQuestionIndex];
    final selectedAnswer = state.answers[question.id];

    return Column(
      children: [
        _buildProgressHeader(quiz),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question ${_currentQuestionIndex + 1} of ${quiz.totalQuestions}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  question.questionText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                ...question.options.map((option) => _buildOption(
                      question.id,
                      option,
                      selectedAnswer == option,
                    )),
              ],
            ),
          ),
        ),
        _buildFooter(quiz),
      ],
    );
  }

  Widget _buildProgressHeader(StudentQuizModel quiz) {
    final progress = (_currentQuestionIndex + 1) / quiz.totalQuestions;
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.surfaceVariant,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: AppColors.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimer(),
              Text(
                'Marks: ${quiz.totalMarks}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimer() {
    // Timer implementation could be added using state
    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        const Text(
          '--:--', // TODO: Implement real timer
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildOption(String questionId, String option, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          ref
              .read(quizAttemptProvider(widget.quizId).notifier)
              .updateAnswer(questionId, option);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : AppColors.border,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(StudentQuizModel quiz) {
    final isLast = _currentQuestionIndex == quiz.totalQuestions - 1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentQuestionIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _currentQuestionIndex--);
                },
                child: const Text('Previous'),
              ),
            ),
          if (_currentQuestionIndex > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (isLast) {
                  _confirmSubmit();
                } else {
                  setState(() => _currentQuestionIndex++);
                }
              },
              child: Text(isLast ? 'Submit Quiz' : 'Next Question'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(QuizAttemptState state) {
    final result = state.result;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              result?.isPassed == true
                  ? Icons.check_circle
                  : Icons.error_outline,
              size: 80,
              color: result?.isPassed == true
                  ? AppColors.success
                  : AppColors.error,
            ),
            const SizedBox(height: 24),
            Text(
              result?.isPassed == true
                  ? 'Congratulations!'
                  : 'Better luck next time!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You scored ${result?.score?.toStringAsFixed(0) ?? '0'} marks (${result?.percentage?.toStringAsFixed(1) ?? '0'}%)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Back to Quizzes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSubmit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Quiz'),
        content: const Text(
            'Are you sure you want to submit? You cannot change your answers after submission.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(quizAttemptProvider(widget.quizId).notifier)
                  .submitQuiz();
              if (!success && mounted) {
                final error =
                    ref.read(quizAttemptProvider(widget.quizId)).error;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error ?? 'Submission failed'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Quiz?'),
        content: const Text(
            'Are you sure you want to exit? Your progress may not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
