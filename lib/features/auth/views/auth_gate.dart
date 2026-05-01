import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../home/views/home_screen.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';
import 'login_page.dart';

/// Puerta de entrada de autenticacion.
///
/// Flujo de arranque:
/// 1) Si FirebaseAuth.instance.currentUser != null -> HomeScreen inmediato.
/// 2) Si no hay sesión, se verifica conectividad.
/// 3) Si no hay internet, se muestra un mensaje claro en pantalla.
/// 4) Si hay internet, se muestra LoginPage.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<List<ConnectivityResult>>? _connectivityFuture;

  @override
  void initState() {
    super.initState();
    _connectivityFuture = Connectivity().checkConnectivity();
  }

  void _retryConnectivity() {
    setState(() {
      _connectivityFuture = Connectivity().checkConnectivity();
    });
  }

  bool _hasInternet(List<ConnectivityResult> results) {
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }

  UserProfile _buildFallbackProfile(User user) {
    return UserProfile(
      uid: user.uid,
      email: user.email ?? '',
      fullName: user.displayName ?? 'Usuario',
      role: UserRole.athlete,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, authSnapshot) {
        final firebaseUser = authSnapshot.data;

        // Prioridad absoluta: sesión local activa => HomeScreen inmediato.
        if (firebaseUser != null) {
          return HomeScreen(
            profile: _buildFallbackProfile(firebaseUser),
            listenToProfileUpdates: false,
          );
        }

        // Sin sesión: revisar conectividad para decidir Login o mensaje de sin internet.
        return FutureBuilder<List<ConnectivityResult>>(
          future: _connectivityFuture,
          builder: (context, connectivitySnapshot) {
            if (connectivitySnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final results = connectivitySnapshot.data ?? const <ConnectivityResult>[];
            final hasInternet = _hasInternet(results);

            if (!hasInternet) {
              return _NoInternetScreen(onRetry: _retryConnectivity);
            }

            return const LoginPage();
          },
        );
      },
    );
  }
}

class _NoInternetScreen extends StatelessWidget {
  const _NoInternetScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 72),
                const SizedBox(height: 16),
                Text(
                  'Necesitas conectarte a internet para poder abrir la aplicación e iniciar sesión',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
