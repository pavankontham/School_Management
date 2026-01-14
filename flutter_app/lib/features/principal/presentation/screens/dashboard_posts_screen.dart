import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';

class DashboardPostsScreen extends ConsumerWidget {
  const DashboardPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Placeholder posts data
    final posts = <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Posts'),
      ),
      body: posts.isEmpty
          ? EmptyStateWidget(
              icon: Icons.article_outlined,
              title: 'No posts yet',
              subtitle:
                  'Create your first post to share updates with your school',
              actionLabel: 'Create Post',
              onAction: () => context.push('/principal/posts/create'),
            )
          : RefreshIndicator(
              onRefresh: () async {
                // Refresh posts
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return _PostCard(
                    title: post['title'],
                    content: post['content'],
                    type: post['type'],
                    date: post['date'],
                    onEdit: () {},
                    onDelete: () {},
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/principal/posts/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Post'),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final String title;
  final String content;
  final String type;
  final DateTime date;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PostCard({
    required this.title,
    required this.content,
    required this.type,
    required this.date,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildTypeChip(type),
                const Spacer(),
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'ANNOUNCEMENT':
        icon = Icons.campaign;
        color = AppColors.primary;
        break;
      case 'EVENT':
        icon = Icons.event;
        color = AppColors.accent;
        break;
      case 'NOTICE':
        icon = Icons.info;
        color = AppColors.secondary;
        break;
      case 'ACHIEVEMENT':
        icon = Icons.emoji_events;
        color = AppColors.success;
        break;
      default:
        icon = Icons.article;
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            type,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
