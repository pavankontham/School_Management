import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/presentation/widgets/custom_text_field.dart';
import '../../../common/presentation/widgets/loading_button.dart';
import '../../../../core/theme/app_theme.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;
  String _notificationType = 'ANNOUNCEMENT';
  String _targetType = 'ALL';
  final Set<String> _selectedChannels = {'IN_APP'};

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Notification'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification Type
              const Text(
                'Notification Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTypeChip('ANNOUNCEMENT', Icons.campaign),
                  _buildTypeChip('NOTICE', Icons.info),
                  _buildTypeChip('ALERT', Icons.warning),
                  _buildTypeChip('REMINDER', Icons.alarm),
                  _buildTypeChip('EVENT', Icons.event),
                ],
              ),
              const SizedBox(height: 24),

              // Target Audience
              const Text(
                'Send To',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTargetChip('ALL', 'Everyone'),
                  _buildTargetChip('TEACHERS', 'Teachers'),
                  _buildTargetChip('STUDENTS', 'Students'),
                ],
              ),
              const SizedBox(height: 24),

              // Notification Channels
              const Text(
                'Delivery Channels',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('In-App Notification'),
                subtitle: const Text('Show in app notification center'),
                value: _selectedChannels.contains('IN_APP'),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedChannels.add('IN_APP');
                    } else {
                      _selectedChannels.remove('IN_APP');
                    }
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Email'),
                subtitle: const Text('Send via email'),
                value: _selectedChannels.contains('EMAIL'),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedChannels.add('EMAIL');
                    } else {
                      _selectedChannels.remove('EMAIL');
                    }
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('SMS'),
                subtitle: const Text('Send via text message'),
                value: _selectedChannels.contains('SMS'),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedChannels.add('SMS');
                    } else {
                      _selectedChannels.remove('SMS');
                    }
                  });
                },
              ),
              const SizedBox(height: 24),

              // Title and Message
              CustomTextField(
                controller: _titleController,
                label: 'Title',
                hint: 'Enter notification title',
                prefixIcon: Icons.title,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  if (value.length < 3) {
                    return 'Title must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _messageController,
                label: 'Message',
                hint: 'Enter notification message',
                prefixIcon: Icons.message,
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a message';
                  }
                  if (value.length < 10) {
                    return 'Message must be at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Send Button
              SizedBox(
                width: double.infinity,
                child: LoadingButton(
                  onPressed: _handleSendNotification,
                  isLoading: _isLoading,
                  text: 'Send Notification',
                  icon: Icons.send,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, IconData icon) {
    final isSelected = _notificationType == type;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(type),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _notificationType = type);
        }
      },
    );
  }

  Widget _buildTargetChip(String type, String label) {
    final isSelected = _targetType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _targetType = type);
        }
      },
    );
  }

  Future<void> _handleSendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedChannels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one delivery channel')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notification sent to $_targetType via ${_selectedChannels.join(", ")}',
          ),
        ),
      );
      context.pop();
    }
  }
}
