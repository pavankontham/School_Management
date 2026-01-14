import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../data/repositories/student_repository.dart';
import '../providers/student_providers.dart';

class StudentQuizScreen extends ConsumerWidget {
  const StudentQuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizzesAsync = ref.watch(studentQuizzesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Quizzes'),
      ),
      body: quizzesAsync.when(
        data: (quizzes) => _QuizzesContent(quizzes: quizzes),
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(studentQuizzesProvider),
        ),
      ),
    );
  }
}

class _QuizzesContent extends StatefulWidget {
  final List<StudentQuizModel> quizzes;

  const _QuizzesContent({required this.quizzes});

  @override
  State<_QuizzesContent> createState() => _QuizzesContentState();
}

class _QuizzesContentState extends State<_QuizzesContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Pending: active, not attempted, and not expired
    final pending = widget.quizzes.where((q) {
      final isExpired = q.endTime != null && q.endTime!.isBefore(now);
      return q.isActive && !q.hasAttempted && !isExpired;
    }).toList();
    // Completed: has attempts
    final completed = widget.quizzes.where((q) => q.hasAttempted).toList();
    // Expired: end time passed and not attempted
    final expired = widget.quizzes.where((q) {
      final isExpired = q.endTime != null && q.endTime!.isBefore(now);
      return isExpired && !q.hasAttempted;
    }).toList();

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Pending (${pending.length})'),
              Tab(text: 'Completed (${completed.length})'),
              Tab(text: 'Expired (${expired.length})'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildQuizList(pending, 'pending'),
              _buildQuizList(completed, 'completed'),
              _buildQuizList(expired, 'expired'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuizList(List<StudentQuizModel> quizzes, String type) {
    if (quizzes.isEmpty) {
      return EmptyStateWidget(
        icon: type == 'pending'
            ? Icons.quiz_outlined
            : type == 'completed'
                ? Icons.check_circle_outline
                : Icons.timer_off_outlined,
        title: type == 'pending'
            ? 'No Pending Quizzes'
            : type == 'completed'
                ? 'No Completed Quizzes'
                : 'No Expired Quizzes',
        subtitle: type == 'pending'
            ? 'New quizzes will appear here'
            : type == 'completed'
                ? 'Your completed quizzes will appear here'
                : 'Expired quizzes will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Provider will be invalidated by parent
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: quizzes.length,
        itemBuilder: (context, index) => _QuizCard(
          quiz: quizzes[index],
          type: type,
        ),
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final StudentQuizModel quiz;
  final String type;

  const _QuizCard({required this.quiz, required this.type});

  // Get the latest attempt if any
  QuizAttemptInfo? get _latestAttempt =>
      quiz.attempts?.isNotEmpty == true ? quiz.attempts!.last : null;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _handleTap(context),
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
                      color: _getStatusColor().withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatusIcon(),
                      color: _getStatusColor(),
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
              const SizedBox(height: 16),
              // Quiz details
              Row(
                children: [
                  _buildInfoChip(
                    Icons.help_outline,
                    '${quiz.totalQuestions} Questions',
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    Icons.timer_outlined,
                    '${quiz.duration} min',
                  ),
                  if (_latestAttempt?.score != null) ...[
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      Icons.star_outline,
                      '${_latestAttempt!.score!.toStringAsFixed(0)}%',
                      color: _getScoreColor(_latestAttempt!.score!),
                    ),
                  ],
                ],
              ),
              if (type == 'pending' && quiz.endTime != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getDueDateColor().withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: _getDueDateColor(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Due: ${DateFormat('MMM d, yyyy h:mm a').format(quiz.endTime!)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _getDueDateColor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (type == 'completed' &&
                  _latestAttempt?.submittedAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Completed: ${DateFormat('MMM d, yyyy h:mm a').format(_latestAttempt!.submittedAt!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (type == 'pending') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _startQuiz(context),
                    child: const Text('Start Quiz'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor().withAlpha(25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _getStatusText(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _getStatusColor(),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {Color? color}) {
    final chipColor = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: chipColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (type) {
      case 'pending':
        return AppColors.warning;
      case 'completed':
        return AppColors.success;
      case 'expired':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon() {
    switch (type) {
      case 'pending':
        return Icons.pending_actions;
      case 'completed':
        return Icons.check_circle;
      case 'expired':
        return Icons.timer_off;
      default:
        return Icons.quiz;
    }
  }

  String _getStatusText() {
    switch (type) {
      case 'pending':
        return 'Pending';
      case 'completed':
        return 'Completed';
      case 'expired':
        return 'Expired';
      default:
        return 'Unknown';
    }
  }

  Color _getDueDateColor() {
    if (quiz.endTime == null) return AppColors.textSecondary;
    final now = DateTime.now();
    final diff = quiz.endTime!.difference(now);
    if (diff.isNegative) return AppColors.error;
    if (diff.inHours < 24) return AppColors.warning;
    return AppColors.info;
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  void _handleTap(BuildContext context) {
    if (type == 'completed') {
      _showQuizResult(context);
    } else if (type == 'pending') {
      _startQuiz(context);
    }
  }

  void _startQuiz(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Quiz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to start "${quiz.title}"?'),
            const SizedBox(height: 16),
            Text(
              '• ${quiz.totalQuestions} questions\n'
              '• ${quiz.duration} minutes time limit\n'
              '• You cannot pause once started',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/student/quizzes/${quiz.id}/attempt');
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  void _showQuizResult(BuildContext context) {
    final attempt = _latestAttempt;
    final score = attempt?.score ?? attempt?.percentage ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
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
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                quiz.subjectName ?? 'Unknown Subject',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              // Score display
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getScoreColor(score.toDouble()).withAlpha(25),
                    border: Border.all(
                      color: _getScoreColor(score.toDouble()),
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${score.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(score.toDouble()),
                          ),
                        ),
                        Text(
                          'Score',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Questions',
                      quiz.totalQuestions.toString(),
                      Icons.help_outline,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Duration',
                      '${quiz.duration} min',
                      Icons.timer_outlined,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Attempts',
                      '${quiz.attempts?.length ?? 0}',
                      Icons.repeat,
                    ),
                  ),
                ],
              ),
              if (attempt?.submittedAt != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Completed on ${DateFormat('MMMM d, yyyy at h:mm a').format(attempt!.submittedAt!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
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
    );
  }
}
