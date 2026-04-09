import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_sports.dart';
import '../../domain/models/user_role.dart';
import '../controllers/auth_controller.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _programController = TextEditingController();
  final _semesterController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  UserRole _selectedRole = UserRole.athlete;
  String? _selectedSport;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _programController.dispose();
    _semesterController.dispose();
    super.dispose();
  }

  String _buildUniandesEmail(String username) {
    final normalized = username.trim().toLowerCase();
    return '$normalized@uniandes.edu.co';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final semester = int.parse(_semesterController.text.trim());
    final controller = context.read<AuthController>();
    final institutionalEmail = _buildUniandesEmail(_emailController.text);

    final success = await controller.signUp(
      email: institutionalEmail,
      password: _passwordController.text,
      fullName: _nameController.text,
      role: _selectedRole,
      program: _programController.text,
      semester: semester,
      mainSport: _selectedSport,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(controller.errorMessage ?? 'Could not create the account')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Sign up'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create your sports profile',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete your profile to access challenges, matches, and personalized training.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            labelText: 'Uniandes username',
                            hintText: 'Ex: jperez',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'Enter your Uniandes username';
                            if (text.contains('@')) {
                              return 'Only enter the username, without @domain';
                            }
                            final isValid = RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(text);
                            if (!isValid) {
                              return 'Invalid username';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<UserRole>(
                          initialValue: _selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'User type',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          items: UserRole.values
                              .map(
                                (role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(role.label),
                                ),
                              )
                              .toList(),
                          onChanged: (role) {
                            if (role != null) {
                              setState(() => _selectedRole = role);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').length < 6) {
                              return 'Minimum 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(
                                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                                );
                              },
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _programController,
                          decoration: const InputDecoration(
                            labelText: 'Academic program (optional)',
                            prefixIcon: Icon(Icons.menu_book_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _semesterController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Semester',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'Semester is required';
                            final parsed = int.tryParse(text);
                            if (parsed == null || parsed <= 0) {
                              return 'Enter a valid semester';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSport,
                          decoration: const InputDecoration(
                            labelText: 'Favorite sport (optional)',
                            prefixIcon: Icon(Icons.sports_soccer_outlined),
                          ),
                          items: AppSports.sportKeys
                              .map(
                                (key) => DropdownMenuItem(
                                  value: key,
                                  child: Text(AppSports.getSport(key).name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedSport =
                                  value == null ? null : AppSports.normalizeSportKey(value);
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: controller.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.teal),
                          child: controller.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Create account'),
                        ),
                      ],
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
