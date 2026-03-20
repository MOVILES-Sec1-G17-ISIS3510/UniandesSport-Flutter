import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/theme/app_sports.dart';
import '../domain/models/event_modality.dart';
import '../domain/models/sport_event.dart';

class EventsRepository {
  final FirebaseFirestore _firestore;

  EventsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Buscar eventos por deporte, modalidad y estado
  Future<List<SportEvent>> searchEvents({
    required String sport,
    required EventModality modality,
    String status = 'active',
  }) async {
    // 1. Registrar la búsqueda en segundo plano (Fire-and-forget)
    try {
      FirebaseFunctions.instance.httpsCallable('logSportSearch')
      // Usamos toLowerCase() por si el usuario escribe "Fútbol" en mayúscula
      .call({'sport': AppSports.normalizeSportKey(sport)});
    } catch (e) {
      // Si la función falla (ej. problemas de red), no queremos que la app explote.
      // Solo imprimimos el error en consola, pero dejamos que la búsqueda continúe.
      debugPrint('Warning: Failed to register +1 search count: $e');
    }

    // 2. Tu consulta original de búsqueda
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('sport', isEqualTo: sport)
          .where('modality', isEqualTo: modality.code)
          .where('status', isEqualTo: status)
          .orderBy('scheduledAt', descending: false)
          .limit(10)
          .get();

      final events = snapshot.docs
          .map((doc) => SportEvent.fromFirestore(doc))
          .toList();
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
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      if (userData == null) return [];

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
        if (mainSport == null || mainSport.trim().isEmpty) return [];
        topSports = [AppSports.normalizeSportKey(mainSport)];
      } else {
        final sorted = prefs.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        topSports = sorted
            .take(3)
            .map((e) => AppSports.normalizeSportKey(e.key))
            .toList();
      }

      if (topSports.isEmpty) return [];

      final snapshot = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'active')
          .where('sport', whereIn: topSports)
          .limit(limit)
          .get();

      final events = snapshot.docs
          .map(SportEvent.fromFirestore)
          // No recomendar eventos del propio usuario ni eventos donde ya participa.
          .where(
            (event) =>
                event.createdBy != userId &&
                !event.participants.contains(userId),
          )
          .toList();

      events.sort((a, b) {
        final aScore = (prefs[a.sport] ?? 0).toDouble();
        final bScore = (prefs[b.sport] ?? 0).toDouble();
        final byScore = bScore.compareTo(aScore);
        if (byScore != 0) return byScore;
        return a.scheduledAt.compareTo(b.scheduledAt);
      });

      // Mostrar solo 5 recomendaciones, priorizando variedad entre deportes.
      return _pickVariedRecommendedEvents(
        events,
        topSports: topSports,
        maxResults: 5,
      );
    } catch (e) {
      throw Exception('Error fetching recommendations: $e');
    }
  }

  List<SportEvent> _pickVariedRecommendedEvents(
    List<SportEvent> events, {
    required List<String> topSports,
    required int maxResults,
  }) {
    if (events.length <= maxResults) return events;

    final buckets = <String, List<SportEvent>>{
      for (final sport in topSports) sport: [],
    };

    for (final event in events) {
      final sport = AppSports.normalizeSportKey(event.sport);
      if (buckets.containsKey(sport)) {
        buckets[sport]!.add(event);
      }
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

    return selected;
  }

  /// Obtener un evento específico por ID
  Future<SportEvent?> getEventById(String eventId) async {
    try {
      final doc = await _firestore.collection('events').doc(eventId).get();

      if (!doc.exists) return null;

      return SportEvent.fromFirestore(doc);
    } catch (e) {
      throw Exception('Error fetching event: $e');
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

      final event = SportEvent(
        id: '', // Se asigna al crear
        createdBy: createdBy,
        title: title,
        sport: sport,
        modality: modality,
        description: description,
        location: location,
        scheduledAt: scheduledAt,
        maxParticipants: maxParticipants,
        participants: [createdBy], // El creador es automáticamente participante
        status: 'active',
        createdAt: now,
        updatedAt: now,
      );

      final eventJson = event.toJson();
      eventJson['metadata'] = {'creatorSemester': creatorSemester};

      final docRef = await _firestore.collection('events').add(eventJson);

      return docRef.id;
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

  /// Abandonar un evento (remover usuario de participantes)
  Future<void> leaveEvent({
    required String eventId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'participants': FieldValue.arrayRemove([userId]),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
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
      throw Exception('Error fetching user events: $e');
    }
  }

  /// Obtener eventos en los que participa un usuario
  Future<List<SportEvent>> getUserParticipatingEvents(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('participants', arrayContains: userId)
          .orderBy('scheduledAt', descending: false)
          .get();

      return snapshot.docs.map((doc) => SportEvent.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Error fetching user events: $e');
    }
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
  }) async {
    try {
      debugPrint(
        '[registerUserInEvent] Trying to register userId=$userId in eventId=$eventId',
      );

      final result = await _firestore.runTransaction<Map<String, dynamic>>((
        transaction,
      ) async {
        final eventRef = _firestore.collection('events').doc(eventId);
        final snapshot = await transaction.get(eventRef);

        if (!snapshot.exists) {
          debugPrint('[registerUserInEvent] Event $eventId does not exist');
          return {'success': false, 'message': 'The event does not exist'};
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final participants = List<String>.from(data['participants'] ?? []);
        final maxParticipants = (data['maxParticipants'] ?? 0) as int;
        final title = data['title'] ?? 'Unknown event';

        debugPrint(
          '[registerUserInEvent] Event: $title | Participants: ${participants.length}/$maxParticipants',
        );

        if (participants.contains(userId)) {
          debugPrint(
            '[registerUserInEvent] User $userId was already registered',
          );
          return {
            'success': true,
            'message': 'You were already registered in this event',
          };
        }

        if (participants.length >= maxParticipants) {
          debugPrint('[registerUserInEvent] Event $eventId is full');
          return {'success': false, 'message': 'The event is full'};
        }

        debugPrint('[registerUserInEvent] Adding $userId to participants');
        transaction.update(eventRef, {
          'participants': FieldValue.arrayUnion([userId]),
          'updatedAt': Timestamp.now(),
        });

        return {'success': true, 'message': 'Successfully registered'};
      });

      debugPrint('[registerUserInEvent] Result: $result');
      return result;
    } on FirebaseException catch (e) {
      debugPrint(
        '[registerUserInEvent] FirebaseException: ${e.code} - ${e.message}',
      );

      String message;
      if (e.code == 'permission-denied') {
        message = 'Permission denied. Check your security rules.';
      } else if (e.code == 'not-found') {
        message = 'The event does not exist';
      } else {
        message = 'Firebase error: ${e.message}';
      }

      return {'success': false, 'message': message};
    } catch (e) {
      debugPrint('[registerUserInEvent] Unexpected error: $e');
      return {
        'success': false,
        'message': 'Registration error: ${e.toString()}',
      };
    }
  }

  /// Versión simplificada (mantener para compatibilidad)
  Future<bool> registerUserInEvent({
    required String eventId,
    required String userId,
  }) async {
    final result = await registerUserInEventWithMessage(
      eventId: eventId,
      userId: userId,
    );
    return result['success'] as bool;
  }
}
