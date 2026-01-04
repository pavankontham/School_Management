import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/presentation/widgets/custom_text_field.dart';
import '../../../common/presentation/widgets/loading_button.dart';
import '../../data/models/teacher_model.dart';
import '../providers/principal_providers.dart';

class AddStudentScreen extends ConsumerStatefulWidget {
  const AddStudentScreen({super.key});

  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rollNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _parentEmailController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String? _selectedClassId;
  String? _selectedGender;
  DateTime? _dateOfBirth;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _rollNumberController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    _parentEmailController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class')),
      );
      return;
    }

    final success = await ref.read(studentManagementProvider.notifier).createStudent(
      rollNumber: _rollNumberController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      classId: _selectedClassId!,
      password: _passwordController.text.isEmpty ? null : _passwordController.text,
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      parentName: _parentNameController.text.trim(),
      parentPhone: _parentPhoneController.text.trim(),
      parentEmail: _parentEmailController.text.trim().isEmpty ? null : _parentEmailController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      dateOfBirth: _dateOfBirth,
      gender: _selectedGender,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student added successfully')),
      );
      context.pop();
    }
  }

  Future<void> _selectDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 10)),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studentManagementProvider);
    final classesAsync = ref.watch(classesProvider(null));

    return Scaffold(
      appBar: AppBar(title: const Text('Add Student')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(state.error!, style: const TextStyle(color: AppColors.error)),
                ),
                const SizedBox(height: 16),
              ],

              // Class Selection
              const Text('Class *', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              classesAsync.when(
                data: (classes) => DropdownButtonFormField<String>(
                  value: _selectedClassId,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  hint: const Text('Select Class'),
                  items: classes.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.displayName),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedClassId = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Failed to load classes'),
              ),
              const SizedBox(height: 16),

              // Roll Number
              CustomTextField(
                controller: _rollNumberController,
                label: 'Roll Number *',
                hint: 'Enter roll number',
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Name
              Row(children: [
                Expanded(child: CustomTextField(
                  controller: _firstNameController,
                  label: 'First Name *',
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                )),
                const SizedBox(width: 16),
                Expanded(child: CustomTextField(
                  controller: _lastNameController,
                  label: 'Last Name *',
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                )),
              ]),
              const SizedBox(height: 16),

              // Contact Info
              CustomTextField(
                controller: _emailController,
                label: 'Email (Optional)',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _phoneController,
                label: 'Phone (Optional)',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              // Parent Info
              const Text('Parent/Guardian Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _parentNameController,
                label: 'Parent Name *',
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _parentPhoneController,
                label: 'Parent Phone *',
                keyboardType: TextInputType.phone,
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _parentEmailController,
                label: 'Parent Email (Optional)',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _addressController,
                label: 'Address (Optional)',
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Additional Info
              const Text('Additional Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Gender
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'MALE', child: Text('Male')),
                  DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _selectedGender = v),
              ),
              const SizedBox(height: 16),

              // Date of Birth
              InkWell(
                onTap: _selectDateOfBirth,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date of Birth', border: OutlineInputBorder()),
                  child: Text(_dateOfBirth != null
                    ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                    : 'Select date'),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              CustomTextField(
                controller: _passwordController,
                label: 'Password (Optional)',
                hint: 'Leave empty for auto-generated',
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 32),

              LoadingButton(
                onPressed: _handleSubmit,
                isLoading: state.isLoading,
                text: 'Add Student',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

