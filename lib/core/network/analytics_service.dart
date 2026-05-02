import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_sports.dart';

/// Servicio centralizado de analitica para eventos de deportes.
///
/// Singleton eager: una unica instancia para toda la app.
class AnalyticsService {
  AnalyticsService._internal();

  static final AnalyticsService instance = AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> logSearchSportEvent({required String sportCategory}) async {
    final normalizedSport = _normalizeSportCategory(sportCategory);
    if (normalizedSport.isEmpty) return;

    await _safeLogEvent(
      name: 'search_sport_event',
      parameters: {
        'sport_category': normalizedSport,
      },
    );
  }

  Future<void> logJoinSportEvent({
    required String sportCategory,
    required String eventId,
  }) async {
    final normalizedSport = _normalizeSportCategory(sportCategory);
    final cleanEventId = eventId.trim();
    if (normalizedSport.isEmpty || cleanEventId.isEmpty) return;

    await _safeLogEvent(
      name: 'join_sport_event',
      parameters: {
        'sport_category': normalizedSport,
        'event_id': cleanEventId,
      },
    );
  }

  Future<void> logCreateSportEvent({required String sportCategory}) async {
    final normalizedSport = _normalizeSportCategory(sportCategory);
    if (normalizedSport.isEmpty) return;

    await _safeLogEvent(
      name: 'create_sport_event',
      parameters: {
        'sport_category': normalizedSport,
      },
    );
  }

  Future<void> logViewEventDetails({
    required String sportCategory,
    required String eventId,
  }) async {
    final normalizedSport = _normalizeSportCategory(sportCategory);
    final cleanEventId = eventId.trim();
    if (normalizedSport.isEmpty || cleanEventId.isEmpty) return;

    await _safeLogEvent(
      name: 'view_event_details',
      parameters: {
        'sport_category': normalizedSport,
        'event_id': cleanEventId,
      },
    );
  }

  Future<void> logInitiateRegistration({
    required String sportCategory,
    required String eventId,
  }) async {
    final normalizedSport = _normalizeSportCategory(sportCategory);
    final cleanEventId = eventId.trim();
    if (normalizedSport.isEmpty || cleanEventId.isEmpty) return;

    await _safeLogEvent(
      name: 'initiate_registration',
      parameters: {
        'sport_category': normalizedSport,
        'event_id': cleanEventId,
      },
    );
  }

  Future<void> logRegistrationFailure({
    required String sportCategory,
    required String eventId,
    required String errorReason,
  }) async {
    final normalizedSport = _normalizeSportCategory(sportCategory);
    final cleanEventId = eventId.trim();
    final cleanErrorReason = errorReason.trim();
    if (normalizedSport.isEmpty || cleanEventId.isEmpty || cleanErrorReason.isEmpty) return;

    await _safeLogEvent(
      name: 'registration_failure',
      parameters: {
        'sport_category': normalizedSport,
        'event_id': cleanEventId,
        'error_reason': cleanErrorReason,
      },
    );
  }

  String _normalizeSportCategory(String sportCategory) {
    return AppSports.normalizeSportKey(sportCategory);
  }

  Future<void> _safeLogEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    try {
      // Log local para validar en debug que el evento se dispara con sus parametros.
      debugPrint('[AnalyticsService] logEvent -> $name | params: $parameters');
      await _analytics.logEvent(name: name, parameters: parameters);
      debugPrint('[AnalyticsService] logEvent OK -> $name');
    } catch (e) {
      // No interrumpimos el flujo de UX por fallos de analitica.
      debugPrint('[AnalyticsService] Error registrando $name: $e');
    }
  }
}
