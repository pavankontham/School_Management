import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/app_widgets.dart';
import '../../../principal/data/models/teacher_model.dart';
import '../../data/models/quiz_model.dart';
import '../../data/repositories/teacher_repository.dart';
import '../providers/teacher_providers.dart';

class TextbookScreen extends ConsumerStatefulWidget {
  const TextbookScreen({super.key});

  @override
  ConsumerState<TextbookScreen> createState() => _TextbookScreenState();
}

class _TextbookScreenState extends ConsumerState<TextbookScreen> {
  String? _selectedSubjectId;

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(mySubjectsProvider(null));
    final textbooksAsync = ref.watch(textbooksProvider(_selectedSubjectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Textbooks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(textbooksProvider(_selectedSubjectId));
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
          // Textbook list
          Expanded(
            child: textbooksAsync.when(
              data: (textbooks) => _buildTextbookList(textbooks),
              loading: () => const LoadingWidget(),
              error: (e, _) => ErrorStateWidget(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(textbooksProvider(_selectedSubjectId)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadDialog(),
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
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

  Widget _buildTextbookList(List<TextbookModel> textbooks) {
    if (textbooks.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.menu_book_outlined,
        title: 'No Textbooks Yet',
        subtitle: 'Upload your first textbook to get started',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(textbooksProvider(_selectedSubjectId));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: textbooks.length,
        itemBuilder: (context, index) => _TextbookCard(
          textbook: textbooks[index],
          onView: () => _viewTextbook(textbooks[index]),
          onDelete: () => _confirmDeleteTextbook(textbooks[index]),
        ),
      ),
    );
  }

  void _showUploadDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _UploadTextbookForm(
        onUploaded: () {
          Navigator.pop(context);
          ref.invalidate(textbooksProvider(_selectedSubjectId));
        },
      ),
    );
  }

  Future<void> _viewTextbook(TextbookModel textbook) async {
    final baseUrl = AppConfig.baseUrl.replaceAll('/api/v1', '');
    final url = '$baseUrl${textbook.filePath}';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open textbook')),
        );
      }
    }
  }

  void _confirmDeleteTextbook(TextbookModel textbook) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Textbook'),
        content: Text('Are you sure you want to delete "${textbook.title}"?'),
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
              final success = await ref
                  .read(teacherRepositoryProvider)
                  .deleteTextbook(textbook.id);
              if (success) {
                ref.invalidate(textbooksProvider(_selectedSubjectId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Textbook deleted')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete textbook')),
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
}

class _TextbookCard extends StatelessWidget {
  final TextbookModel textbook;
  final VoidCallback onView;
  final VoidCallback onDelete;

  const _TextbookCard({
    required this.textbook,
    required this.onView,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _getFileColor().withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getFileIcon(),
                  color: _getFileColor(),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textbook.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      textbook.subjectName ?? 'Unknown Subject',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, yyyy').format(textbook.createdAt),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (textbook.fileSize != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.storage,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatFileSize(textbook.fileSize!),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'view') {
                    onView();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new),
                        SizedBox(width: 8),
                        Text('Open'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(color: AppColors.error)),
                      ],
                    ),
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
    if (type.contains('xls')) return Icons.table_chart;
    if (type.contains('ppt')) return Icons.slideshow;
    return Icons.insert_drive_file;
  }

  Color _getFileColor() {
    final type = textbook.fileType?.toLowerCase() ?? '';
    if (type.contains('pdf')) return Colors.red;
    if (type.contains('doc')) return Colors.blue;
    if (type.contains('xls')) return Colors.green;
    if (type.contains('ppt')) return Colors.orange;
    return AppColors.primary;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _UploadTextbookForm extends ConsumerStatefulWidget {
  final VoidCallback onUploaded;

  const _UploadTextbookForm({required this.onUploaded});

  @override
  ConsumerState<_UploadTextbookForm> createState() =>
      _UploadTextbookFormState();
}

class _UploadTextbookFormState extends ConsumerState<_UploadTextbookForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedSubjectId;
  String? _selectedClassId;
  File? _selectedFile;
  String? _selectedFileName;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(myClassesProvider);
    final subjectsAsync = ref.watch(mySubjectsProvider(_selectedClassId));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Upload Textbook',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // File picker
                InkWell(
                  onTap: _pickFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedFile != null
                            ? AppColors.success
                            : AppColors.border,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _selectedFile != null
                              ? Icons.check_circle
                              : Icons.cloud_upload_outlined,
                          size: 48,
                          color: _selectedFile != null
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedFileName ?? 'Tap to select a file',
                          style: TextStyle(
                            color: _selectedFile != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    hintText: 'Enter textbook title',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter description (optional)',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Class dropdown
                classesAsync.when(
                  data: (classes) => DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Class *',
                      prefixIcon: Icon(Icons.class_),
                    ),
                    items: classes
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedClassId = value;
                        _selectedSubjectId = null;
                      });
                    },
                    validator: (value) {
                      if (value == null) return 'Please select a class';
                      return null;
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Failed to load classes'),
                ),
                const SizedBox(height: 16),

                // Subject dropdown
                subjectsAsync.when(
                  data: (subjects) => DropdownButtonFormField<String>(
                    value: _selectedSubjectId,
                    decoration: const InputDecoration(
                      labelText: 'Subject *',
                      prefixIcon: Icon(Icons.subject),
                    ),
                    items: subjects
                        .map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedSubjectId = value);
                    },
                    validator: (value) {
                      if (value == null) return 'Please select a subject';
                      return null;
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Failed to load subjects'),
                ),
                const SizedBox(height: 24),

                // Upload button
                ElevatedButton(
                  onPressed: _isLoading ? null : _uploadTextbook,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Upload Textbook'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _selectedFileName = result.files.single.name;
        if (_titleController.text.isEmpty) {
          _titleController.text =
              result.files.single.name.replaceAll(RegExp(r'\.[^.]+$'), '');
        }
      });
    }
  }

  Future<void> _uploadTextbook() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ref.read(teacherRepositoryProvider).uploadTextbook(
          file: _selectedFile!,
          title: _titleController.text,
          description: _descriptionController.text,
          subjectId: _selectedSubjectId!,
          classId: _selectedClassId!,
        );

    setState(() => _isLoading = false);

    if (result.success) {
      widget.onUploaded();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to upload textbook')),
        );
      }
    }
  }
}
