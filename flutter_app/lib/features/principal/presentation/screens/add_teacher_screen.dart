import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/custom_text_field.dart';
import '../../../common/presentation/widgets/loading_button.dart';
import '../providers/principal_providers.dart';

class AddTeacherScreen extends ConsumerStatefulWidget {
  const AddTeacherScreen({super.key});

  @override
  ConsumerState<AddTeacherScreen> createState() => _AddTeacherScreenState();
}

class _AddTeacherScreenState extends ConsumerState<AddTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    final success = await ref.read(teacherManagementProvider.notifier).createTeacher(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher added successfully')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherManagementProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Teacher'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error message
              if (state.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: const TextStyle(color: AppColors.error, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Personal Information Section
              const Text(
                'Personal Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      hint: 'Enter first name',
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      hint: 'Enter last name',
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              CustomTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'Enter email address',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Required';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)) {
                    return 'Invalid email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              CustomTextField(
                controller: _phoneController,
                label: 'Phone (Optional)',
                hint: 'Enter phone number',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 24),

              // Account Section
              const Text(
                'Account Credentials',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Create a password',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Required';
                  if (v!.length < 8) return 'Min 8 characters';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              CustomTextField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                hint: 'Confirm password',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscureConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Required';
                  if (v != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),

              const SizedBox(height: 32),

              LoadingButton(
                onPressed: _handleSubmit,
                isLoading: state.isLoading,
                text: 'Add Teacher',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

