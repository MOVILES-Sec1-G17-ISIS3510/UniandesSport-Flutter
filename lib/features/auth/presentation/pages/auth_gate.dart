import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../home/presentation/pages/app_shell.dart';
import '../../data/auth_repository.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_role.dart';
import 'login_page.dart';

/// Puerta de entrada de autenticacion.
///
/// Decide la pantalla inicial segun dos fuentes de Firebase:
/// 1) FirebaseAuth.authStateChanges() para saber si hay sesion activa
/// 2) Firestore /users/{uid} para cargar el perfil de dominio
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<AuthRepository>();

    return StreamBuilder<User?>(
      stream: repository.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          return const LoginPage();
        }

        // Si hay sesion, resolvemos perfil de Firestore.
        // En caso de perfil ausente, se construye un fallback minimo
        // para no bloquear navegacion y mantener continuidad de UX.
        return FutureBuilder<UserProfile?>(
          future: repository.getUserProfile(firebaseUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnapshot.data;
            if (profile == null) {
              return AppShell(
                profile: UserProfile(
                  uid: firebaseUser.uid,
                  email: firebaseUser.email ?? '',
                  fullName: firebaseUser.displayName ?? 'Usuario',
                  role: UserRole.athlete,
                ),
              );
            }

            return AppShell(profile: profile);
          },
        );
      },
    );
  }
}
