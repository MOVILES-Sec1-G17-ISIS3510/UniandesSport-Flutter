import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_sports.dart';
import '../../domain/models/user_role.dart';
import '../controllers/auth_controller.dart';

/// Pantalla de registro de cuenta.
///
/// Flujo funcional:
/// 1) Captura datos basicos del usuario y preferencias iniciales.
/// 2) Construye correo institucional con dominio Uniandes.
/// 3) Ejecuta AuthController.signUp(...).
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
        const SnackBar(content: Text('Cuenta creada exitosamente.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          controller.errorMessage ?? 'No fue posible crear la cuenta',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Registro'),
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
                  'Crea tu perfil deportivo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Completa tu perfil para acceder a retos, partidos y entrenamientos personalizados.',
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
                            labelText: 'Nombre completo',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Ingresa tu nombre';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            labelText: 'Usuario uniandes',
                            hintText: 'Ej: jperez',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty)
                              return 'Ingresa tu usuario Uniandes';
                            if (text.contains('@')) {
                              return 'Solo ingresa el usuario, sin @dominio';
                            }
                            final isValid = RegExp(
                              r'^[a-zA-Z0-9._-]+$',
                            ).hasMatch(text);
                            if (!isValid) {
                              return 'Usuario invalido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<UserRole>(
                          initialValue: _selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de usuario',
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
                            labelText: 'Contraseña',
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
                            if ((value ?? '').length < 6) {
                              return 'Mínimo 6 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirmar contraseña',
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
                            if (value != _passwordController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _programController,
                          decoration: const InputDecoration(
                            labelText: 'Programa académico (opcional)',
                            prefixIcon: Icon(Icons.menu_book_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _semesterController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Semestre',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty)
                              return 'El semestre es obligatorio';
                            final parsed = int.tryParse(text);
                            if (parsed == null || parsed <= 0) {
                              return 'Ingresa un semestre valido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSport,
                          decoration: const InputDecoration(
                            labelText: 'Deporte principal (opcional)',
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
                              : const Text('Crear cuenta'),
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
