import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/local_storage/database_helper.dart';
import '../../../core/network/analytics_service.dart';
import '../../../core/network/sync_engine_service.dart';
import '../../../core/constants/app_sports.dart';
import '../models/event_modality.dart';
import '../models/sport_event.dart';
import '../../home/models/time_slot.dart';

/// Repositorio de eventos deportivos.
///
/// Implementa el patrón **Singleton** para garantizar que exista una sola
/// instancia en toda la aplicación. Esto tiene sentido porque:
/// - No tiene estado mutable propio (solo coordina llamadas a Firestore).
/// - Firebase gestiona internamente su propio pool de conexiones.
/// - Evita crear/destruir objetos innecesariamente cuando múltiples widgets
///   lo necesitan al mismo tiempo (PlayPage, HomePage, AppShell).
///
/// Uso:  `final repo = EventsRepository.instance;`
class EventsRepository {
  // Constructor privado: nadie fuera de esta clase puede hacer `EventsRepository()`.
  EventsRepository._internal()
      : _firestore = FirebaseFirestore.instance,
        _dbHelper = DatabaseHelper(),
        _syncEngine = SyncEngineService();

  /// Única instancia global de la clase (Singleton eager).
  static final EventsRepository instance = EventsRepository._internal();

  final FirebaseFirestore _firestore;
  final DatabaseHelper _dbHelper;
  final SyncEngineService _syncEngine;

  /// Puerta de acceso a Cloud Functions callable usadas por BQ3/BQ4.
  ///
  /// Se mantiene como dependencia interna para que la capa UI solo use
  /// el repositorio y no conozca detalles de infraestructura.
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Buscar eventos por deporte, modalidad y estado.
  /// Solo devuelve eventos cuya fecha de inicio sea futura respecto a ahora.
  Future<List<SportEvent>> searchEvents({
    required String sport,
    required EventModality modality,
    String status = 'active',
  }) async {
    // 1. Registrar la búsqueda en analitica y en backend (fire-and-forget)
    AnalyticsService.instance.logSearchSportEvent(sportCategory: sport);

    try {
      FirebaseFunctions.instance.httpsCallable('logSportSearch').call({
        'sport': AppSports.normalizeSportKey(sport),
      });
    } catch (e) {
      debugPrint('Warning: Could not log search increment: $e');
    }

    // 2. Consulta simplificada para evitar problemas de índices compuestos.
    try {
      final normalizedSport = AppSports.normalizeSportKey(sport);
      final now = DateTime.now();

      final snapshot = await _firestore
          .collection('events')
          .where('sport', isEqualTo: normalizedSport)
          .where('status', isEqualTo: status)
          .get(const GetOptions(source: Source.server));

      final events =
          snapshot.docs
              .map((doc) => SportEvent.fromFirestore(doc))
              .where(
                (event) => event.modality == modality && event.status == status,
              )
              // Filtrar: solo eventos que comienzan a partir de ahora
              .where((event) => event.scheduledAt.isAfter(now))
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

      return _pickVariedEvents(events, maxResults: 5);
    } catch (e) {
      throw Exception('Error searching events: $e');
    }
  }

  List<SportEvent> _pickVariedEvents(
    List<SportEvent> events, {
    required int maxResults,
  }) {
    if (events.length <= maxResults) return events;

    final selected = <SportEvent>[];
    final step = (events.length - 1) / (maxResults - 1);
    for (var i = 0; i < maxResults; i++) {
      final index = (i * step).round();
      selected.add(events[index]);
    }
    return selected;
  }

  Future<List<SportEvent>> getRecommendedEvents(
    String userId, {
    int limit = 10,
  }) async {
    try {
      debugPrint(
        '[Recommendations] Start getRecommendedEvents | userId=$userId | limit=$limit',
      );

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      if (userData == null) {
        debugPrint(
          '[Recommendations] User profile not found in /users/$userId. Using active-events fallback.',
        );
        // Fallback robusto para cuentas sin documento de perfil.
        return _fetchAnyActiveEvents(limit: limit);
      }

      final rawPrefs = userData['inferredPreferences'];
      final prefs = <String, num>{};
      if (rawPrefs is Map) {
        rawPrefs.forEach((key, value) {
          if (key is String && value is num) {
            prefs[key] = value;
          }
        });
      }

      List<String> topSports;
      if (prefs.isEmpty) {
        final mainSport = userData['mainSport'] as String?;
        topSports = (mainSport == null || mainSport.trim().isEmpty)
            ? <String>[]
            : <String>[AppSports.normalizeSportKey(mainSport)];
      } else {
        final sorted = prefs.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        topSports = sorted
            .take(3)
            .map((e) => AppSports.normalizeSportKey(e.key))
            .toList();
      }

      debugPrint(
        '[Recommendations] Profile loaded | prefs=${prefs.length} | topSports=$topSports',
      );

      final events = await _fetchRecommendedOrFallbackEvents(
        userId: userId,
        topSports: topSports,
        prefs: prefs,
        limit: limit,
      );

      if (events.isEmpty) {
        debugPrint(
          '[Recommendations] Result empty after prioritized + fallback queries.',
        );
        return [];
      }

      events.sort((a, b) {
        final aScore = (prefs[a.sport] ?? 0).toDouble();
        final bScore = (prefs[b.sport] ?? 0).toDouble();
        final byScore = bScore.compareTo(aScore);
        if (byScore != 0) return byScore;
        return a.scheduledAt.compareTo(b.scheduledAt);
      });

      // Mostrar solo 5 recomendaciones, priorizando variedad entre deportes.
      final finalEvents = _pickVariedRecommendedEvents(
        events,
        topSports: topSports,
        maxResults: 5,
      );

      debugPrint(
        '[Recommendations] Final list size=${finalEvents.length} | rawSize=${events.length}',
      );

      return finalEvents;
    } catch (e) {
      throw Exception('Error getting recommendations: $e');
    }
  }

  Future<List<SportEvent>> _fetchRecommendedOrFallbackEvents({
    required String userId,
    required List<String> topSports,
    required Map<String, num> prefs,
    required int limit,
  }) async {
    // 1) Intento principal: usar deportes priorizados por el perfil.
    if (topSports.isNotEmpty) {
      final prioritizedSnapshot = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'active')
          .where('sport', whereIn: topSports)
          .limit(limit)
          .get();

      debugPrint(
        '[Recommendations] Prioritized query docs=${prioritizedSnapshot.docs.length} | sports=$topSports',
      );

      final prioritizedEvents = prioritizedSnapshot.docs
          .map(SportEvent.fromFirestore)
          .where(
            (event) =>
                event.createdBy != userId &&
                !event.participants.contains(userId) &&
                event.scheduledAt.isAfter(DateTime.now()),
          )
          .toList();

      debugPrint(
        '[Recommendations] Prioritized after user filters=${prioritizedEvents.length}',
      );

      if (prioritizedEvents.isNotEmpty) {
        return prioritizedEvents;
      }
    }

    // 2) Fallback: mostrar eventos activos recientes aunque no coincidan
    // con la preferencia del usuario. Esto evita la pantalla vacia.
    final fallbackSnapshot = await _firestore
        .collection('events')
        .where('status', isEqualTo: 'active')
        .limit(limit)
        .get();

    debugPrint(
      '[Recommendations] Fallback active query docs=${fallbackSnapshot.docs.length}',
    );

    final fallbackEvents = fallbackSnapshot.docs
        .map(SportEvent.fromFirestore)
        .where(
          (event) =>
              event.createdBy != userId && 
              !event.participants.contains(userId) &&
              event.scheduledAt.isAfter(DateTime.now()),
        )
        .toList();

    debugPrint(
      '[Recommendations] Fallback after user filters=${fallbackEvents.length}',
    );

    if (fallbackEvents.isEmpty) {
      // Ultimo fallback: en ambientes de prueba puede que solo existan eventos
      // creados por el mismo usuario. En ese caso mostramos activos sin filtro.
      debugPrint(
        '[Recommendations] Strict fallback empty. Using ANY active events fallback.',
      );
      return _fetchAnyActiveEvents(limit: limit);
    }

    fallbackEvents.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return fallbackEvents;
  }

  Future<List<SportEvent>> _fetchAnyActiveEvents({required int limit}) async {
    final snapshot = await _firestore
        .collection('events')
        .where('status', isEqualTo: 'active')
        .limit(limit)
        .get();

    debugPrint(
      '[Recommendations] Any-active fallback docs=${snapshot.docs.length}',
    );

    final events = snapshot.docs
        .map(SportEvent.fromFirestore)
        .where((event) => event.scheduledAt.isAfter(DateTime.now()))
        .toList();
    events.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return events;
  }

  List<SportEvent> _pickVariedRecommendedEvents(
    List<SportEvent> events, {
    required List<String> topSports,
    required int maxResults,
  }) {
    if (events.length <= maxResults) return events;

    // Si no hay deportes priorizados en perfil, conserva los primeros eventos
    // ordenados y evita vaciar la lista por round-robin sin buckets.
    if (topSports.isEmpty) {
      return events.take(maxResults).toList();
    }

    final buckets = <String, List<SportEvent>>{
      for (final sport in topSports) sport: [],
    };

    for (final event in events) {
      final sport = AppSports.normalizeSportKey(event.sport);
      if (buckets.containsKey(sport)) {
        buckets[sport]!.add(event);
      }
    }

    if (buckets.values.every((queue) => queue.isEmpty)) {
      // Ningun evento coincide con los deportes priorizados; devolvemos la
      // lista base para no dejar la seccion vacia.
      return events.take(maxResults).toList();
    }

    final selected = <SportEvent>[];

    // Round-robin por deportes preferidos para evitar concentracion en uno solo.
    while (selected.length < maxResults) {
      var addedInCycle = false;

      for (final sport in topSports) {
        final queue = buckets[sport];
        if (queue != null && queue.isNotEmpty && selected.length < maxResults) {
          selected.add(queue.removeAt(0));
          addedInCycle = true;
        }
      }

      if (!addedInCycle) break;
    }

    if (selected.isEmpty) {
      // Si el round-robin no pudo seleccionar nada, devolvemos la base.
      return events.take(maxResults).toList();
    }

    return selected;
  }

  /// Obtener un evento específico por ID
  Future<SportEvent?> getEventById(String eventId) async {
    try {
      final doc = await _firestore.collection('events').doc(eventId).get();

      if (!doc.exists) return null;

      return SportEvent.fromFirestore(doc);
    } catch (e) {
      throw Exception('Error getting event: $e');
    }
  }

  /// Crear un nuevo evento
  Future<String> createEvent({
    required String createdBy,
    required int creatorSemester,
    required String title,
    required String sport,
    required EventModality modality,
    required String description,
    required String location,
    required DateTime scheduledAt,
    required int maxParticipants,
  }) async {
    try {
      final now = DateTime.now();
      final eventId = _firestore.collection('events').doc().id;

      final event = SportEvent(
        id: eventId,
        createdBy: createdBy,
        creatorSemester: creatorSemester,
        title: title,
        sport: sport,
        modality: modality,
        description: description,
        location: location,
        scheduledAt: scheduledAt,
        maxParticipants: maxParticipants,
        participants: [createdBy],
        status: 'active',
        createdAt: now,
        updatedAt: now,
      );

      // 1) Guardado local primero (SQLite)
      await _dbHelper.transaction((txn) async {
        await txn.insert(
          'play_events',
          event.toLocalMap(isSynced: false),
        );

        // 2) Encolamos la sincronización para cuando haya conectividad.
        await txn.insert('sync_queue', {
          'event_id': eventId,
          'action': 'create_play_event',
          'status': 'pending',
          'retry_count': 0,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      });

      // 3) Intento inmediato de sync en background si hay conexión.
      Future.microtask(() => _syncEngine.processQueue());

      // Registro de analitica no bloqueante para no afectar la UX.
      AnalyticsService.instance.logCreateSportEvent(sportCategory: sport);

      return eventId;
    } catch (e) {
      throw Exception('Error creating event: $e');
    }
  }

  /// Unirse a un evento (agregar usuario a participantes)
  Future<void> joinEvent({
    required String eventId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'participants': FieldValue.arrayUnion([userId]),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error joining event: $e');
    }
  }

  /// Cancelar un evento como dueño (borra el evento completo de forma local-first).
  Future<void> cancelEvent({
    required String eventId,
    required String userId,
  }) async {
    try {
      await _dbHelper.transaction((txn) async {
        // Borrado local inmediato: el evento desaparece de la UI sin esperar red.
        await txn.delete('play_events', where: 'id = ?', whereArgs: [eventId]);
        await txn.delete('events', where: 'id = ?', whereArgs: [eventId]);

        // Encolamos el borrado remoto para sincronización eventual.
        await txn.insert('sync_queue', {
          'event_id': eventId,
          'action': 'CANCEL_EVENT',
          'payload': jsonEncode({'eventId': eventId, 'userId': userId}),
          'status': 'pending',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'retry_count': 0,
        });
      });

      Future.microtask(() => _syncEngine.processQueue());
    } catch (e) {
      debugPrint('[cancelEvent] Fallo al guardar cancelación local: $e');
      throw Exception('Error canceling event: $e');
    }
  }

  /// Abandonar un evento (remover usuario de participantes) de forma Offline-First
  Future<void> leaveEvent({
    required String eventId,
    required String userId,
  }) async {
    try {
      await _dbHelper.transaction((txn) async {
        // 1. Borramos el evento de la caché local para reflejar la UI optimista.
        await txn.delete('play_events', where: 'id = ?', whereArgs: [eventId]);
        await txn.delete('events', where: 'id = ?', whereArgs: [eventId]);

        // 2. Encolamos la acción para sincronización eventual.
        await txn.insert('sync_queue', {
          'event_id': eventId,
          'action': 'LEAVE_EVENT',
          'payload': jsonEncode({'eventId': eventId}),
          'status': 'pending',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'retry_count': 0,
        });
      });

      // 3. Disparamos el sync en segundo plano sin bloquear la UI.
      Future.microtask(() => _syncEngine.processQueue());
    } catch (e) {
      debugPrint('[leaveEvent] Fallo al guardar salida local: $e');
      throw Exception('Error leaving event: $e');
    }
  }

  /// Obtener eventos creados por un usuario
  Future<List<SportEvent>> getUserEvents(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('createdBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => SportEvent.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Error getting user events: $e');
    }
  }

  /// Obtener eventos en los que participa un usuario
  Future<List<SportEvent>> getUserParticipatingEvents(String userId) async {
    try {
      final localRows = await _dbHelper.query('play_events', orderBy: 'scheduled_at ASC');
      if (localRows.isNotEmpty) {
        final localEvents = localRows
            .map((row) => SportEvent.fromLocalMap(row))
            .where(
              (event) =>
                  event.createdBy == userId || event.participants.contains(userId),
            )
            .toList();

        // Si ya hay caché local, confiamos en ella (incluso si está vacía porque el usuario
        // acaba de abandonar todos sus eventos). Evitamos el fallback a Firestore para
        // prevenir condiciones de carrera con el Sync Engine.
        return localEvents;
      }

      final snapshot = await _firestore
          .collection('events')
          .where('participants', arrayContains: userId)
          .get();

      final remoteEvents = snapshot.docs
          .map((doc) => SportEvent.fromFirestore(doc))
          .toList();

      if (remoteEvents.isNotEmpty) {
        await _cachePlayEvents(remoteEvents);
      }

      return remoteEvents;
    } catch (e) {
      throw Exception('Error getting participating events: $e');
    }
  }

  Future<void> _cachePlayEvents(List<SportEvent> events) async {
    final rows = events.map((event) => event.toLocalMap(isSynced: true)).toList();
    await _dbHelper.batchInsert('play_events', rows, replaceOnConflict: true);
  }

  /// Actualizar estado de un evento
  Future<void> updateEventStatus({
    required String eventId,
    required String status,
  }) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'status': status,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error updating event status: $e');
    }
  }

  /// Eliminar un evento (solo el creador)
  Future<void> deleteEvent(String eventId) async {
    try {
      await _firestore.collection('events').doc(eventId).delete();
    } catch (e) {
      throw Exception('Error deleting event: $e');
    }
  }

  /// Registra a un usuario en un evento si hay cupo disponible.
  /// Devuelve un mapa con `success` (bool) y `message` (String).
  /// Casos:
  /// - true, "Registrado exitosamente" → Se registró
  /// - true, "Ya estabas registrado" → Ya era participante
  /// - false, "El evento está lleno" → Sin cupos
  /// - false, "El evento no existe" → Evento inválido
  /// - false, "Permiso denegado" → Sin permisos
  /// - false, "Error al registrar: ..." → Error inesperado
  Future<Map<String, dynamic>> registerUserInEventWithMessage({
    required String eventId,
    required String userId,

    /// Opcional: id de notificacion usada para atribuir conversion BQ4.
    ///
    /// Si viene informado y el evento es torneo, se registra interacción
    /// tipo `clicked` en backend para completar trazabilidad del embudo.
    String? notificationId,
  }) async {
    try {
      debugPrint(
        '[registerUserInEvent] Intentando registrar userId=$userId en eventId=$eventId',
      );

      final eventBeforeJoin = await _firestore
          .collection('events')
          .doc(eventId)
          .get();
      final beforeData = eventBeforeJoin.data();
      final sportCategory = (beforeData?['sport'] as String?) ?? '';

      if (sportCategory.isNotEmpty) {
        // Intento de registro para medir embudo completo (inicia registro).
        AnalyticsService.instance.logInitiateRegistration(
          sportCategory: sportCategory,
          eventId: eventId,
        );
      }

      final result = await _firestore.runTransaction<Map<String, dynamic>>((
        transaction,
      ) async {
        final eventRef = _firestore.collection('events').doc(eventId);
        final snapshot = await transaction.get(eventRef);

        if (!snapshot.exists) {
          debugPrint('[registerUserInEvent] El evento $eventId no existe');
          return {'success': false, 'message': 'Event does not exist'};
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final participants = List<String>.from(data['participants'] ?? []);
        final maxParticipants = (data['maxParticipants'] ?? 0) as int;
        final title = data['title'] ?? 'Evento desconocido';

        debugPrint(
          '[registerUserInEvent] Evento: $title | Participantes: ${participants.length}/$maxParticipants',
        );

        if (participants.contains(userId)) {
          debugPrint(
            '[registerUserInEvent] Usuario $userId ya estaba registrado',
          );
          return {
            'success': true,
            'message': 'You are already registered in this event',
            'sportCategory': data['sport'] ?? '',
          };
        }

        if (participants.length >= maxParticipants) {
          debugPrint('[registerUserInEvent] Evento $eventId está lleno');
          return {'success': false, 'message': 'The event is full'};
        }

        debugPrint('[registerUserInEvent] Agregando $userId a participantes');
        transaction.update(eventRef, {
          'participants': FieldValue.arrayUnion([userId]),
          'updatedAt': Timestamp.now(),
        });

        return {
          'success': true,
          'message': 'Registered successfully',
          'sportCategory': data['sport'] ?? '',
        };
      });

      if (result['success'] == true &&
          result['message'] == 'Registered successfully') {
        final sportCategory = (result['sportCategory'] as String?) ?? '';
        AnalyticsService.instance.logJoinSportEvent(
          sportCategory: sportCategory,
          eventId: eventId,
        );

        final modality = ((beforeData?['modality'] as String?) ?? '')
            .toLowerCase();
        if (notificationId != null &&
            notificationId.trim().isNotEmpty &&
            modality == 'tournament') {
          // Atribuye el registro a una notificación automatizada en backend (BQ4).
          try {
            await _functions
                .httpsCallable('logAutomatedNotificationInteraction')
                .call({
                  'notificationId': notificationId.trim(),
                  'interactionType': 'clicked',
                });
          } catch (e) {
            debugPrint(
              '[registerUserInEvent] No se pudo registrar interacción de notificación: $e',
            );
          }
        }
      } else {
        final message = (result['message'] as String?) ?? 'unknown_error';
        if (sportCategory.isNotEmpty) {
          AnalyticsService.instance.logRegistrationFailure(
            sportCategory: sportCategory,
            eventId: eventId,
            errorReason: message,
          );
        }
      }

      debugPrint('[registerUserInEvent] Resultado: $result');
      return result;
    } on FirebaseException catch (e) {
      debugPrint(
        '[registerUserInEvent] FirebaseException: ${e.code} - ${e.message}',
      );

      String message;
      if (e.code == 'permission-denied') {
        message = 'Permission denied. Check your security rules.';
      } else if (e.code == 'not-found') {
        message = 'Event does not exist';
      } else {
        message = 'Firebase error: ${e.message}';
      }

      return {'success': false, 'message': message};
    } catch (e) {
      debugPrint('[registerUserInEvent] Error inesperado: $e');
      return {
        'success': false,
        'message': 'Error registering: ${e.toString()}',
      };
    }
  }

  /// Versión simplificada (mantener para compatibilidad)
  Future<bool> registerUserInEvent({
    required String eventId,
    required String userId,
    String? notificationId,
  }) async {
    final result = await registerUserInEventWithMessage(
      eventId: eventId,
      userId: userId,
      notificationId: notificationId,
    );
    return result['success'] as bool;
  }

  /// BQ3: Retorna el deporte mas agendado.
  ///
  /// [scope] soporta:
  /// - `user` (default): usa el usuario autenticado.
  /// - `global`: agrega todos los usuarios.
  ///
  /// [sources] es opcional y permite filtrar el calculo por origen:
  /// - `event_created`
  /// - `event_joined`
  /// - `coach_request`
  ///
  /// Si [sources] es null o vacio, se usa el total acumulado.
  ///
  /// Respuesta esperada (keys principales):
  /// - `mostScheduledSport`
  /// - `totalSchedules`
  /// - `ranking`
  /// - `appliedSources`
  /// - `sourceBreakdown`
  /// - `sports`
  Future<Map<String, dynamic>> getBq3MostScheduledSport({
    String scope = 'user',
    List<String>? sources,
  }) async {
    try {
      final callable = _functions.httpsCallable('getBq3MostScheduledSport');
      final response = await callable.call({
        'scope': scope,
        if (sources != null && sources.isNotEmpty) 'sources': sources,
      });
      return Map<String, dynamic>.from(response.data as Map);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unavailable') {
        debugPrint(
          '[BQ3] Callable no disponible (${e.code}). Usando fallback local con Firestore.',
        );
        return _getBq3FallbackFromFirestore(scope: scope, sources: sources);
      }
      rethrow;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return {
          'scope': scope.trim().toLowerCase(),
          'userId': FirebaseAuth.instance.currentUser?.uid,
          'appliedSources': (sources == null || sources.isEmpty)
              ? ['all']
              : sources,
          'hasData': false,
          'mostScheduledSport': null,
          'totalSchedules': 0,
          'sourceBreakdown': <String, dynamic>{},
          'ranking': const <Map<String, dynamic>>[],
          'recommendedHomeFeedSport': null,
          'sports': <String, dynamic>{},
          'fallback': true,
          'fallbackReason': 'permission_denied',
        };
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _getBq3FallbackFromFirestore({
    required String scope,
    List<String>? sources,
  }) async {
    final normalizedScope = scope.trim().toLowerCase();
    final normalizedSources = (sources ?? const <String>[])
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
    final hasFilter = normalizedSources.isNotEmpty;

    Map<String, dynamic> sports = {};
    String? userId;

    try {
      if (normalizedScope == 'global') {
        try {
          final globalDoc = await _firestore
              .collection('business_metrics')
              .doc('bq3_global')
              .get();
          final data = globalDoc.data();
          sports = Map<String, dynamic>.from((data?['sports'] ?? {}) as Map);
        } on FirebaseException catch (e) {
          if (e.code != 'permission-denied') rethrow;
          debugPrint(
            '[BQ3] Sin permisos para business_metrics/bq3_global. Retornando vacio en scope global.',
          );
          sports = {};
        }
      } else {
        userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null || userId.isEmpty) {
          throw Exception(
            'No hay sesión activa para calcular BQ3 en fallback.',
          );
        }

        Map<String, dynamic> existingSports = {};
        try {
          final userAggDoc = await _firestore
              .collection('bq3_user_sport_counts')
              .doc(userId)
              .get();
          final userAggData = userAggDoc.data();
          existingSports = Map<String, dynamic>.from(
            (userAggData?['sports'] ?? {}) as Map,
          );
        } on FirebaseException catch (e) {
          if (e.code != 'permission-denied') rethrow;
          debugPrint(
            '[BQ3] Sin permisos para bq3_user_sport_counts/$userId. Reconstruyendo en cliente.',
          );
        }

        if (existingSports.isNotEmpty) {
          sports = existingSports;
        } else {
          sports = await _rebuildUserBq3Locally(userId);
        }
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      debugPrint(
        '[BQ3] Fallback bloqueado por reglas. Retornando respuesta vacia.',
      );
      sports = {};
    }

    final ranking = <Map<String, dynamic>>[];
    sports.forEach((sport, payload) {
      final payloadMap = Map<String, dynamic>.from((payload as Map?) ?? {});
      final sourceBreakdown = Map<String, dynamic>.from(
        (payloadMap['sources'] ?? {}) as Map,
      );

      final total = hasFilter
          ? normalizedSources.fold<int>(0, (acc, source) {
              return acc + ((sourceBreakdown[source] as num?)?.toInt() ?? 0);
            })
          : ((payloadMap['total'] as num?)?.toInt() ?? 0);

      if (total > 0) {
        ranking.add({
          'sport': sport,
          'total': total,
          'sourceBreakdown': sourceBreakdown,
        });
      }
    });

    ranking.sort((a, b) {
      final bTotal = (b['total'] as num?)?.toInt() ?? 0;
      final aTotal = (a['total'] as num?)?.toInt() ?? 0;
      return bTotal.compareTo(aTotal);
    });

    final top = ranking.isNotEmpty ? ranking.first : null;

    return {
      'scope': normalizedScope,
      'userId': normalizedScope == 'global' ? null : userId,
      'appliedSources': hasFilter ? normalizedSources : ['all'],
      'hasData': ranking.isNotEmpty,
      'mostScheduledSport': top?['sport'],
      'totalSchedules': top?['total'] ?? 0,
      'sourceBreakdown': top?['sourceBreakdown'] ?? <String, dynamic>{},
      'ranking': ranking,
      'recommendedHomeFeedSport': top?['sport'],
      'sports': sports,
      'fallback': true,
      'fallbackReason': 'cloud_function_not_available',
    };
  }

  Future<Map<String, dynamic>> _rebuildUserBq3Locally(String userId) async {
    final totals = <String, Map<String, dynamic>>{};

    void addCount(String sport, String source) {
      final normalizedSport = AppSports.normalizeSportKey(sport);
      if (normalizedSport.isEmpty) return;

      final sportBucket = totals.putIfAbsent(
        normalizedSport,
        () => {'total': 0, 'sources': <String, int>{}},
      );
      sportBucket['total'] = ((sportBucket['total'] as int?) ?? 0) + 1;

      final sourceMap = Map<String, int>.from(
        (sportBucket['sources'] as Map?) ?? {},
      );
      sourceMap[source] = (sourceMap[source] ?? 0) + 1;
      sportBucket['sources'] = sourceMap;
    }

    try {
      final activeEvents = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'active')
          .limit(300)
          .get();

      for (final doc in activeEvents.docs) {
        final data = doc.data();
        final sport = (data['sport'] as String?) ?? '';
        final createdBy = (data['createdBy'] as String?) ?? '';
        final participants = List<String>.from(
          data['participants'] ?? const [],
        );

        if (createdBy == userId) {
          addCount(sport, 'event_created');
        }

        if (participants.contains(userId)) {
          addCount(sport, 'event_joined');
        }
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      debugPrint('[BQ3] Sin permisos para leer events en fallback local.');
    }

    try {
      final coachRequests = await _firestore
          .collection('coach_requests')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in coachRequests.docs) {
        final sport = (doc.data()['sport'] as String?) ?? '';
        addCount(sport, 'coach_request');
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      debugPrint('[BQ3] Sin permisos para coach_requests en fallback local.');
    }

    if (totals.isEmpty) {
      try {
        final profile = await _firestore.collection('users').doc(userId).get();
        final inferred = Map<String, dynamic>.from(
          (profile.data()?['inferredPreferences'] ?? {}) as Map,
        );

        inferred.forEach((sport, value) {
          final normalizedSport = AppSports.normalizeSportKey(sport);
          final count = (value as num?)?.toInt() ?? 0;
          if (normalizedSport.isEmpty || count <= 0) return;

          totals[normalizedSport] = {
            'total': count,
            'sources': {'profile_inferred': count},
          };
        });
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
        debugPrint('[BQ3] Sin permisos para users/$userId en fallback local.');
      }
    }

    return totals.map(
      (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
    );
  }

  /// BQ4: Obtiene el KPI de conversion de notificaciones a registros de torneo.
  ///
  /// Formula usada en backend:
  /// `conversionRate = (effectiveRegistrations / notificationsSent) * 100`
  Future<Map<String, dynamic>> getBq4TournamentNotificationConversion() async {
    final callable = _functions.httpsCallable(
      'getBq4TournamentNotificationConversion',
    );
    final response = await callable.call();
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// BQ4: Registra envio de notificacion automatizada (top-of-funnel).
  ///
  /// Recomendado llamarlo justo despues de enviar la push/local notification.
  /// Para contar en el KPI global, [modality] debe ser `tournament`.
  Future<void> logAutomatedNotificationSent({
    required String notificationId,
    required String eventId,
    required String userId,
    required String modality,
    String source = 'automated',
  }) async {
    final callable = _functions.httpsCallable('logAutomatedNotificationSent');
    await callable.call({
      'notificationId': notificationId,
      'eventId': eventId,
      'userId': userId,
      'modality': modality,
      'source': source,
    });
  }

  /// BQ4: Registra interaccion de notificacion.
  ///
  /// [interactionType] permitido: `opened` o `clicked`.
  /// Esto alimenta analitica de embudo y facilita la atribucion de conversion.
  Future<void> logAutomatedNotificationInteraction({
    required String notificationId,
    required String interactionType,
  }) async {
    final callable = _functions.httpsCallable(
      'logAutomatedNotificationInteraction',
    );
    await callable.call({
      'notificationId': notificationId,
      'interactionType': interactionType,
    });
  }

  /// BQ5: Calcula la brecha de preparacion para competencias proximas.
  ///
  /// La respuesta incluye:
  /// - ultima senal persistida de coaching/tutoria
  /// - competencias proximas del usuario
  /// - horas desde la ultima sesion
  /// - horas restantes hasta la competencia
  ///
  /// Nota: el backend usa `coach_requests.createdAt` como fuente de coaching
  /// porque el proyecto no tiene una coleccion separada de sesiones confirmadas.
  Future<Map<String, dynamic>> getBq5ReadinessGapForUpcomingCompetitions({
    int limit = 5,
  }) async {
    final callable = _functions.httpsCallable(
      'getBq5ReadinessGapForUpcomingCompetitions',
    );
    final response = await callable.call({'limit': limit});
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// BQ5: Historial de tiempos registrados al unirse a torneos/retos.
  ///
  /// Cada fila representa una inscripcion detectada y contiene:
  /// - baselineType: `coaching_touch` o `app_registration`
  /// - elapsedHoursSinceBaseline
  /// - readinessGapHoursToCompetition
  Future<Map<String, dynamic>> getBq5ReadinessTimeLogs({int limit = 20}) async {
    final callable = _functions.httpsCallable('getBq5ReadinessTimeLogs');
    final response = await callable.call({'limit': limit});
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// BQ6: Obtiene la capacidad disponible de torneos proximos segun intereses.
  ///
  /// La respuesta incluye:
  /// - deportes candidatos del perfil
  /// - torneos proximos con cupos disponibles
  /// - capacidad total disponible
  /// - desglose por deporte
  /// - candidatos de notificacion urgente basados en intencion demostrada
  Future<Map<String, dynamic>> getBq6UpcomingTournamentCapacity({
    int limit = 20,
    int lowCapacityThreshold = 3,
    double highUtilizationThreshold = 85,
  }) async {
    final callable = _functions.httpsCallable(
      'getBq6UpcomingTournamentCapacity',
    );
    final response = await callable.call({
      'limit': limit,
      'lowCapacityThreshold': lowCapacityThreshold,
      'highUtilizationThreshold': highUtilizationThreshold,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  // TODO: restaurar cuando se suba lib/core/network/google_calendar_service.dart
  // al repo. El tipo TimeSlot está definido en ese archivo, que no existe.
  //
  // /// Devuelve una recomendación única para hoy según deporte y disponibilidad.
  // Future<SportEvent?> getDailyRecommendedEvent({
  //   required String sport,
  //   List<TimeSlot>? userAvailableSlots,
  // }) async {
  //   try {
  //     final now = DateTime.now();
  //     final startOfDay = DateTime(now.year, now.month, now.day);
  //     final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
  //
  //     final normalizedSport = AppSports.normalizeSportKey(sport);
  //     final snapshot = await _firestore
  //         .collection('events')
  //         .where('sport', isEqualTo: normalizedSport)
  //         .where('status', isEqualTo: 'active')
  //         .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
  //         .where('scheduledAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
  //         .get();
  //
  //     final candidates = snapshot.docs
  //         .map(SportEvent.fromFirestore)
  //         .where((event) => !event.isFull)
  //         .where((event) => event.scheduledAt.isAfter(now))
  //         .toList()
  //       ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  //
  //     if (candidates.isEmpty) return null;
  //
  //     if (userAvailableSlots == null || userAvailableSlots.isEmpty) {
  //       return candidates.first;
  //     }
  //
  //     for (final event in candidates) {
  //       if (_isEventInAnyAvailableSlot(event, userAvailableSlots)) {
  //         return event;
  //       }
  //     }
  //
  //     return null;
  //   } catch (e) {
  //     throw Exception('Error getting daily recommended event: $e');
  //   }
  // }
  //
  // bool _isEventInAnyAvailableSlot(SportEvent event, List<TimeSlot> slots) {
  //   final eventStart = event.scheduledAt;
  //   final eventEnd = eventStart.add(const Duration(hours: 1));
  //
  //   for (final slot in slots) {
  //     final startsInside = !eventStart.isBefore(slot.start);
  //     final endsInside = !eventEnd.isAfter(slot.end);
  //     if (startsInside && endsInside) {
  //       return true;
  //     }
  //   }
  //
  //   return false;
  // }
}
