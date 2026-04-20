import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/validation/app_field_limits.dart';
import '../viewmodels/auth_view_model.dart';
import 'register_page.dart';

/// Pantalla de inicio de sesion.
///
/// Flujo funcional:
/// 1) Valida email y contrasena en formulario.
/// 2) Llama AuthViewModel.signIn(...).
/// 3) Si login falla, muestra mensaje legible en SnackBar.
/// 4) Si login es exitoso, AuthGate detecta la sesion y redirige a AppShell.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Ejecuta el intento de login.
  ///
  /// Notas:
  /// - No navega manualmente al home.
  /// - La navegacion se resuelve por AuthGate escuchando authStateChanges().
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = context.read<AuthViewModel>();
    final success = await controller.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted || success) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(controller.errorMessage ?? 'Could not sign in')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthViewModel>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              Text(
                'UNIANDES SPORTS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.teal,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome 👋',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Sign in to find matches, challenges, and coaches.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 30),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sign in',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          maxLength: AppFieldLimits.email,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppFieldLimits.email,
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Institutional email',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'Enter your email';
                            final emailRegex = RegExp(
                              r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                            );
                            if (!emailRegex.hasMatch(text)) {
                              return 'Invalid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
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
                              onPressed: () => setState(() {
                                _obscurePassword = !_obscurePassword;
                              }),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final password = value ?? '';
                            if (password.isEmpty) {
                              return 'Enter your password';
                            }
                            if (password.length <
                                AppValidationRules.passwordMinLength) {
                              return 'Minimum 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: authController.isLoading ? null : _submit,
                          child: authController.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Sign in'),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed: authController.isLoading
                                ? null
                                : () {
                                    authController.clearError();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterPage(),
                                      ),
                                    );
                                  },
                            child: const Text("Don't have an account? Sign up"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
