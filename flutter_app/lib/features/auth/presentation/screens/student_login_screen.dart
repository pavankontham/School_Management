import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/custom_text_field.dart';
import '../../../common/presentation/widgets/loading_button.dart';
import '../providers/auth_provider.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user_model.dart';

class StudentLoginScreen extends ConsumerStatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  ConsumerState<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends ConsumerState<StudentLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolIdController = TextEditingController();
  final _rollNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  SchoolModel? _selectedSchool;
  bool _isLoadingSchool = false;

  @override
  void dispose() {
    _schoolIdController.dispose();
    _rollNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSchoolInfo() async {
    if (_schoolIdController.text.isEmpty) return;
    
    setState(() => _isLoadingSchool = true);
    
    final school = await ref.read(authRepositoryProvider).getSchoolInfo(
      _schoolIdController.text.trim(),
    );
    
    setState(() {
      _selectedSchool = school;
      _isLoadingSchool = false;
    });
    
    if (school == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('School not found')),
      );
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedSchool == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid school ID')),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).loginStudent(
      schoolId: _selectedSchool!.id,
      rollNumber: _rollNumberController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      context.go('/student');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Login'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          size: 40,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Student Portal',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in with your student credentials',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Error message
                if (authState.error != null) ...[
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
                            authState.error!,
                            style: const TextStyle(color: AppColors.error, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // School ID field
                CustomTextField(
                  controller: _schoolIdController,
                  label: 'School ID',
                  hint: 'Enter your school ID',
                  prefixIcon: Icons.school_outlined,
                  onChanged: (_) => setState(() => _selectedSchool = null),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter school ID';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 8),
                
                // Verify school button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isLoadingSchool ? null : _loadSchoolInfo,
                    icon: _isLoadingSchool
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search, size: 18),
                    label: const Text('Verify School'),
                  ),
                ),
                
                // School info card
                if (_selectedSchool != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedSchool!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (_selectedSchool!.address != null)
                                Text(
                                  _selectedSchool!.address!,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Roll number field
                CustomTextField(
                  controller: _rollNumberController,
                  label: 'Roll Number',
                  hint: 'Enter your roll number',
                  prefixIcon: Icons.badge_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your roll number';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Password field
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Enter your password',
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textTertiary,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 32),
                
                // Login button
                LoadingButton(
                  onPressed: _handleLogin,
                  isLoading: authState.isLoading,
                  text: 'Sign In',
                ),
                
                const SizedBox(height: 24),
                
                // Help text
                Center(
                  child: Text(
                    'Contact your school administrator if you forgot your password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

