import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_theme.dart';
import 'core/network/notification_service.dart';
import 'core/utils/theme_controller.dart';
import 'features/auth/models/user_profile.dart';
import 'features/auth/services/auth_repository.dart';
import 'features/auth/viewmodels/auth_view_model.dart';
import 'features/auth/views/auth_gate.dart';
import 'features/play/services/events_repository.dart';
import 'features/play/viewmodels/play_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uniandessport_flutter/features/coach/viewmodels/coaches_view_model.dart';
import 'package:uniandessport_flutter/features/coach/services/coach_repository.dart';

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
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();

    _themeController = ThemeController();
    _themeController.startMonitoring();

    // Firebase ya se inicializa en main.dart. Aquí solo arrancamos notificaciones
    // sin bloquear el render inicial de la app.
    unawaited(NotificationService.instance.initialize().catchError((error) {
      debugPrint('[UniandesSportsApp] Notification init error: $error');
    }));
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

          return MultiProvider(
            providers: [
              // ── Capa de datos ─────────────────────────────────────────────
              ChangeNotifierProvider(
                create: (_) => CoachesViewModel(
                  CoachRepositoryImpl(
                    firestore: FirebaseFirestore.instance,
                  ),
                )..loadCoaches(),
              ),
              Provider<AuthRepository>(create: (_) => AuthRepository()),
              Provider<EventsRepository>(
                create: (_) => EventsRepository.instance,
              ),

              // ── ViewModels (MVVM) ─────────────────────────────────────────
              ChangeNotifierProxyProvider<AuthRepository, AuthViewModel>(
                create: (context) => AuthViewModel(context.read<AuthRepository>()),
                update: (context, repository, controller) =>
                    controller ?? AuthViewModel(repository),
              ),
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
      ),
    );
  }
}
