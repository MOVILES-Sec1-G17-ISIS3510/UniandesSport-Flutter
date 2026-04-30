import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_sports.dart';
import '../../../core/constants/app_field_limits.dart';
import '../models/user_role.dart';
import '../viewmodels/auth_view_model.dart';

/// Pantalla de registro de cuenta.
///
/// Flujo funcional:
/// 1) Captura datos basicos del usuario y preferencias iniciales.
/// 2) Construye correo institucional con dominio Uniandes.
/// 3) Ejecuta AuthViewModel.signUp(...).
/// 4) Si el registro es exitoso, vuelve al login.
///
/// Persistencia asociada:
/// - Firebase Auth crea la credencial email/password.
/// - Firestore crea /users/{uid} con el perfil deportivo.
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

  /// Ejecuta registro de cuenta y muestra feedback al usuario.
  ///
  /// Los campos enviados se reflejan en UserProfile en Firestore.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final semester = int.parse(_semesterController.text.trim());
    final controller = context.read<AuthViewModel>();
    final institutionalEmail = _buildUniandesEmail(_emailController.text);

    final success = await controller.signUp(
      email: institutionalEmail,
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
      role: _selectedRole,
      program: _programController.text.trim(),
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
      SnackBar(
        content: Text(
          controller.errorMessage ?? 'Could not create the account',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthViewModel>();

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
                          textInputAction: TextInputAction.next,
                          maxLength: AppFieldLimits.fullName,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppFieldLimits.fullName,
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.isEmpty) {
                              return 'Enter your name';
                            }
                            if (text.length <
                                AppValidationRules.fullNameMinLength) {
                              return 'At least 3 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          maxLength: AppFieldLimits.username,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppFieldLimits.username,
                            ),
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9._-]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Uniandes username',
                            hintText: 'Ex: jperez',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty)
                              return 'Enter your Uniandes username';
                            if (text.contains('@')) {
                              return 'Only enter the username, without @domain';
                            }
                            if (text.length <
                                AppValidationRules.usernameMinLength) {
                              return 'At least 3 characters';
                            }
                            final isValid = RegExp(
                              r'^[a-zA-Z0-9._-]+$',
                            ).hasMatch(text);
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
                          textInputAction: TextInputAction.next,
                          maxLength: AppFieldLimits.password,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppFieldLimits.password,
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final text = value ?? '';
                            if (text.length <
                                AppValidationRules.passwordMinLength) {
                              return 'Minimum 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.next,
                          maxLength: AppFieldLimits.password,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppFieldLimits.password,
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Confirm password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
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
                            if ((value ?? '').isEmpty) {
                              return 'Confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _programController,
                          textInputAction: TextInputAction.next,
                          maxLength: AppFieldLimits.program,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppFieldLimits.program,
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Academic program (optional)',
                            prefixIcon: Icon(Icons.menu_book_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _semesterController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          maxLength: AppFieldLimits.semesterDigits,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppFieldLimits.semesterDigits,
                            ),
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Semester',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'Semester is required';
                            final parsed = int.tryParse(text);
                            if (parsed == null ||
                                parsed < AppValidationRules.semesterMin ||
                                parsed > AppValidationRules.semesterMax) {
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
                              _selectedSport = value == null
                                  ? null
                                  : AppSports.normalizeSportKey(value);
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: controller.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.teal,
                          ),
                          child: controller.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
