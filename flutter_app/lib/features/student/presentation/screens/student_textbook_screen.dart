import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../data/models/student_data_models.dart';
import '../providers/student_providers.dart';

class StudentTextbookScreen extends ConsumerWidget {
  const StudentTextbookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textbooksAsync = ref.watch(studentTextbooksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Textbooks'),
      ),
      body: textbooksAsync.when(
        data: (textbooks) => _TextbooksContent(textbooks: textbooks),
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(studentTextbooksProvider),
        ),
      ),
    );
  }
}

class _TextbooksContent extends StatefulWidget {
  final List<StudentTextbookModel> textbooks;

  const _TextbooksContent({required this.textbooks});

  @override
  State<_TextbooksContent> createState() => _TextbooksContentState();
}

class _TextbooksContentState extends State<_TextbooksContent> {
  String _searchQuery = '';
  String? _selectedSubject;

  List<StudentTextbookModel> get _filteredTextbooks {
    var filtered = widget.textbooks;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) {
        return t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (t.description
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false);
      }).toList();
    }

    if (_selectedSubject != null) {
      filtered =
          filtered.where((t) => t.subjectName == _selectedSubject).toList();
    }

    return filtered;
  }

  List<String> get _subjects {
    return widget.textbooks
        .map((t) => t.subjectName)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.textbooks.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.menu_book_outlined,
        title: 'No Textbooks Available',
        subtitle: 'Textbooks will appear here when uploaded by your teachers',
      );
    }

    return Column(
      children: [
        _buildSearchAndFilter(),
        Expanded(
          child: _filteredTextbooks.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.search_off,
                  title: 'No Results',
                  subtitle: 'Try adjusting your search or filter',
                )
              : RefreshIndicator(
                  onRefresh: () async {},
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredTextbooks.length,
                    itemBuilder: (context, index) =>
                        _TextbookCard(textbook: _filteredTextbooks[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
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
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search textbooks...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 12),
          // Subject filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', _selectedSubject == null, () {
                  setState(() => _selectedSubject = null);
                }),
                ..._subjects.map((subject) => _buildFilterChip(
                      subject,
                      _selectedSubject == subject,
                      () => setState(() => _selectedSubject = subject),
                    )),
              ],
            ),
          ),
        ],
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
}

class _TextbookCard extends StatelessWidget {
  final StudentTextbookModel textbook;

  const _TextbookCard({required this.textbook});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openTextbook(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Book icon/thumbnail
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  color: _getSubjectColor().withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getFileIcon(),
                  color: _getSubjectColor(),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              // Book details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textbook.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (textbook.subjectName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getSubjectColor().withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          textbook.subjectName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getSubjectColor(),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (textbook.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        textbook.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          textbook.fileSizeFormatted,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            textbook.author ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () => _openTextbook(context),
                    tooltip: 'Open',
                  ),
                  IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () => _downloadTextbook(context),
                    tooltip: 'Download',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon() {
    final type = textbook.fileType?.toLowerCase() ?? '';
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('doc')) return Icons.description;
    if (type.contains('ppt')) return Icons.slideshow;
    if (type.contains('xls')) return Icons.table_chart;
    return Icons.menu_book;
  }

  Color _getSubjectColor() {
    final subject = textbook.subjectName?.toLowerCase() ?? '';
    if (subject.contains('math')) return Colors.blue;
    if (subject.contains('science') || subject.contains('physics')) {
      return Colors.green;
    }
    if (subject.contains('english') || subject.contains('language')) {
      return Colors.orange;
    }
    if (subject.contains('history') || subject.contains('social')) {
      return Colors.brown;
    }
    if (subject.contains('chemistry')) return Colors.purple;
    if (subject.contains('biology')) return Colors.teal;
    return AppColors.primary;
  }

  Future<void> _openTextbook(BuildContext context) async {
    final baseUrl = AppConfig.baseUrl.replaceAll('/api/v1', '');
    final url = '$baseUrl${textbook.filePath}';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(textbook.title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (textbook.description != null) ...[
                  Text(textbook.description!),
                  const SizedBox(height: 16),
                ],
                Text('File: ${textbook.filePath.split('/').last}'),
                Text('Type: ${textbook.fileType ?? 'Unknown'}'),
                Text('Size: ${textbook.fileSizeFormatted}'),
                if (textbook.author != null) Text('Author: ${textbook.author}'),
                const SizedBox(height: 16),
                const Text('Note: Could not open the file directly.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _downloadTextbook(BuildContext context) {
    // Show a message that download functionality requires additional setup
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download feature requires server file hosting setup'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}
