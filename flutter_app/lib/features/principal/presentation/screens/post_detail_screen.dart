import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/repositories/principal_repository.dart';
import '../providers/principal_providers.dart';

final postDetailProvider =
    FutureProvider.family<DashboardPostModel?, String>((ref, postId) async {
  final repository = ref.read(principalRepositoryProvider);
  return await repository.getPostById(postId);
});

class PostDetailScreen extends ConsumerWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postDetailProvider(postId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              postAsync.whenData((post) {
                if (post != null) _showEditPostDialog(context, ref, post);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: postAsync.when(
        data: (post) {
          if (post == null) {
            return const Center(child: Text('Post not found'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Post Type Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getTypeColor(post.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getTypeIcon(post.type),
                        size: 16,
                        color: _getTypeColor(post.type),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        post.type,
                        style: TextStyle(
                          color: _getTypeColor(post.type),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Metadata
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(post.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (post.isPinned) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.push_pin, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Pinned',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const Divider(height: 32),

                // Content
                Text(
                  post.content,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),

                // Media (if any)
                if (post.mediaUrls.isNotEmpty) ...[
                  const Text(
                    'Attachments',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...post.mediaUrls.map((url) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.attach_file),
                          title: Text(url.split('/').last),
                          trailing: IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () {
                              // TODO: Download file
                            },
                          ),
                        ),
                      )),
                ],
              ],
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(postDetailProvider(postId)),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(principalRepositoryProvider)
          .deleteDashboardPost(postId);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully')),
        );
        context.pop();
        ref.invalidate(dashboardPostsProvider);
      }
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'ANNOUNCEMENT':
        return AppColors.primary;
      case 'EVENT':
        return AppColors.success;
      case 'ACHIEVEMENT':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'ANNOUNCEMENT':
        return Icons.campaign;
      case 'EVENT':
        return Icons.event;
      case 'ACHIEVEMENT':
        return Icons.emoji_events;
      default:
        return Icons.article;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showEditPostDialog(
      BuildContext context, WidgetRef ref, DashboardPostModel post) {
    final titleController = TextEditingController(text: post.title);
    final contentController = TextEditingController(text: post.content);
    String type = post.type;
    bool isPinned = post.isPinned;
    bool isPublished = post.isPublished;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Post'),
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
                  controller: contentController,
                  decoration: const InputDecoration(labelText: 'Content'),
                  maxLines: 5,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: ['ANNOUNCEMENT', 'EVENT', 'CIRCULAR', 'NEWS']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => type = val!),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Pinned'),
                  value: isPinned,
                  onChanged: (val) => setDialogState(() => isPinned = val),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Published'),
                  value: isPublished,
                  onChanged: (val) => setDialogState(() => isPublished = val),
                  contentPadding: EdgeInsets.zero,
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
                final success =
                    await ref.read(postManagementProvider.notifier).updatePost(
                          post.id,
                          title: titleController.text,
                          content: contentController.text,
                          type: type,
                          isPinned: isPinned,
                          isPublished: isPublished,
                        );
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post updated successfully')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
