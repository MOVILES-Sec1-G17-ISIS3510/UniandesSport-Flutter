import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/domain/models/user_profile.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/pages/auth_gate.dart';
import 'features/home/data/events_repository.dart';
import 'features/home/presentation/controllers/play_view_model.dart';
import 'core/services/notification_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uniandessport_flutter/features/coach/presentation/viewmodels/coaches_view_model.dart';
import 'package:uniandessport_flutter/features/home/data/coach_repository.dart';

/// Root widget de la aplicacion.
///
/// Responsabilidades principales:
/// 1) Inicializar Firebase una sola vez.
/// 2) Inicializar servicios que dependen de Firebase (p.ej. notificaciones).
/// 3) Construir el arbol de providers (repositorios + controladores).
class UniandesSportsApp extends StatefulWidget {
  const UniandesSportsApp({super.key});

  @override
  State<UniandesSportsApp> createState() => _UniandesSportsAppState();
}

class _UniandesSportsAppState extends State<UniandesSportsApp> {
  /// Future unico para toda la vida del State.
  ///
  /// Evita reinicializaciones de Firebase en cada rebuild.
  late final Future<void> _appInitFuture;
  late final Future<FirebaseApp> _firebaseInitFuture;
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();

    // Orden recomendado:
    // 1) Firebase.initializeApp()
    // 2) Servicios dependientes de Firebase
    // Si Firebase falla, _appInitFuture termina en error y se muestra
    // _FirebaseErrorPage con detalle util para diagnostico.
    _appInitFuture = Firebase.initializeApp().then((_) {
      // Las notificaciones se inicializan una vez que Firebase ya esta listo.
      return NotificationService.instance.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _appInitFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const _SplashLoadingPage(),
          );
        }
    _firebaseInitFuture = Firebase.initializeApp();
    _themeController = ThemeController();
    _themeController.startMonitoring();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _themeController,
      child: Builder(
        builder: (context) {
          final themeController = context.watch<ThemeController>();

          return FutureBuilder<FirebaseApp>(
            future: _firebaseInitFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.light,
                  darkTheme: AppTheme.dark,
                  themeMode: themeController.themeMode,
                  home: const _SplashLoadingPage(),
                );
              }

              if (snapshot.hasError) {
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.light,
                  darkTheme: AppTheme.dark,
                  themeMode: themeController.themeMode,
                  home: _FirebaseErrorPage(error: snapshot.error.toString()),
                );
              }

              return MultiProvider(
                providers: [
                  // ── Capa de datos ─────────────────────────────────────────────
                  // AuthRepository: instancia normal (1 por árbol, pero no Singleton
                  // porque podría necesitar distintas instancias en tests).
                  ChangeNotifierProvider(
                    create: (_) => CoachesViewModel(
                      CoachRepositoryImpl(
                        firestore: FirebaseFirestore.instance,
                      ),
                    )..loadCoaches(),
                  ),
                  Provider<AuthRepository>(create: (_) => AuthRepository()),
                  // EventsRepository: Singleton — se comparte la MISMA instancia
                  // en toda la app (PlayPage, HomePage, etc.) sin recrearla.
                  Provider<EventsRepository>(
                    create: (_) => EventsRepository.instance,
                  ),

                  // ── ViewModels (MVVM) ─────────────────────────────────────────
                  // AuthController depende de AuthRepository → ProxyProvider.
                  ChangeNotifierProxyProvider<AuthRepository, AuthController>(
                    create: (context) =>
                        AuthController(context.read<AuthRepository>()),
                    update: (context, repository, controller) =>
                        controller ?? AuthController(repository),
                  ),
                  // PlayViewModel depende de EventsRepository y del perfil del usuario.
                  // El perfil se inyecta más abajo desde AppShell cuando ya existe sesión.
                  // Aquí se provisiona con un perfil vacío que AppShell sobreescribe.
                  ChangeNotifierProxyProvider<EventsRepository, PlayViewModel>(
                    create: (context) => PlayViewModel(
                      repository: context.read<EventsRepository>(),
                      profile: UserProfile.empty(),
                    ),
                    update: (context, repo, vm) =>
                        vm ??
                        PlayViewModel(
                          repository: repo,
                          profile: UserProfile.empty(),
                        ),
                  ),
                ],
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  title: 'Uniandes Sports',
                  theme: AppTheme.light,
                  darkTheme: AppTheme.dark,
                  themeMode: themeController.themeMode,
                  home: const AuthGate(),
                ),
              );
            },
          );
        }

        return MultiProvider(
          providers: [
            // ── Capa de datos ─────────────────────────────────────────────
            // AuthRepository: instancia normal (1 por árbol, pero no Singleton
            // porque podría necesitar distintas instancias en tests).
            ChangeNotifierProvider(
              create: (_) => CoachesViewModel(
                CoachRepositoryImpl(firestore: FirebaseFirestore.instance),
              )..loadCoaches(),
            ),
            Provider<AuthRepository>(create: (_) => AuthRepository()),
            // EventsRepository: Singleton — se comparte la MISMA instancia
            // en toda la app (PlayPage, HomePage, etc.) sin recrearla.
            Provider<EventsRepository>(
              create: (_) => EventsRepository.instance,
            ),

            // ── ViewModels (MVVM) ─────────────────────────────────────────
            // AuthController depende de AuthRepository → ProxyProvider.
            ChangeNotifierProxyProvider<AuthRepository, AuthController>(
              create: (context) =>
                  AuthController(context.read<AuthRepository>()),
              update: (context, repository, controller) =>
                  controller ?? AuthController(repository),
            ),
            // PlayViewModel depende de EventsRepository y del perfil del usuario.
            // El perfil se inyecta más abajo desde AppShell cuando ya existe sesión.
            // Aquí se provisiona con un perfil vacío que AppShell sobreescribe.
            ChangeNotifierProxyProvider<EventsRepository, PlayViewModel>(
              create: (context) => PlayViewModel(
                repository: context.read<EventsRepository>(),
                profile: UserProfile.empty(),
              ),
              update: (context, repo, vm) =>
                  vm ??
                  PlayViewModel(repository: repo, profile: UserProfile.empty()),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Uniandes Sports',
            theme: AppTheme.light,
            home: const AuthGate(),
          ),
        );
      },
        },
      ),
    );
  }
}

class _SplashLoadingPage extends StatelessWidget {
  const _SplashLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _FirebaseErrorPage extends StatelessWidget {
  const _FirebaseErrorPage({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Error inicializando Firebase',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(error),
            ],
          ),
        ),
      ),
    );
  }
}
