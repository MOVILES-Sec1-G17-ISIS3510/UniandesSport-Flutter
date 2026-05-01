import 'package:flutter/material.dart';

import '../../auth/models/user_profile.dart';
import 'app_shell.dart';

/// HomeScreen es el punto de entrada principal de la app cuando ya hay sesión local.
///
/// Esta pantalla envuelve [AppShell] y permite decidir si se escuchan o no
/// actualizaciones remotas del perfil en Firestore.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    this.listenToProfileUpdates = true,
  });

  final UserProfile profile;
  final bool listenToProfileUpdates;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      profile: profile,
      listenToProfileUpdates: listenToProfileUpdates,
    );
  }
}

