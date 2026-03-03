import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../home/presentation/pages/home_page.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/user_role.dart';
import 'login_page.dart';

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
              return HomePage(
                profile: UserProfile(
                  uid: firebaseUser.uid,
                  email: firebaseUser.email ?? '',
                  fullName: firebaseUser.displayName ?? 'Usuario',
                  role: UserRole.athlete,
                ),
              );
            }

            return HomePage(profile: profile);
          },
        );
      },
    );
  }
}
