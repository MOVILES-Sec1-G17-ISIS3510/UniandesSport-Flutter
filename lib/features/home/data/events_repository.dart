import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

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
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('sport', isEqualTo: sport)
          .where('modality', isEqualTo: modality.code)
          .where('status', isEqualTo: status)
          .orderBy('scheduledAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => SportEvent.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error buscando eventos: $e');
    }
  }

  /// Obtener un evento específico por ID
  Future<SportEvent?> getEventById(String eventId) async {
    try {
      final doc = await _firestore.collection('events').doc(eventId).get();

      if (!doc.exists) return null;

      return SportEvent.fromFirestore(doc);
    } catch (e) {
      throw Exception('Error obteniendo evento: $e');
    }
  }

  /// Crear un nuevo evento
  Future<String> createEvent({
    required String createdBy,
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

      final docRef = await _firestore
          .collection('events')
          .add(event.toJson());

      return docRef.id;
    } catch (e) {
      throw Exception('Error creando evento: $e');
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
      throw Exception('Error uniéndose al evento: $e');
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
      throw Exception('Error abandonando el evento: $e');
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

      return snapshot.docs
          .map((doc) => SportEvent.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error obteniendo eventos del usuario: $e');
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

      return snapshot.docs
          .map((doc) => SportEvent.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error obteniendo eventos del usuario: $e');
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
      throw Exception('Error actualizando estado del evento: $e');
    }
  }

  /// Eliminar un evento (solo el creador)
  Future<void> deleteEvent(String eventId) async {
    try {
      await _firestore.collection('events').doc(eventId).delete();
    } catch (e) {
      throw Exception('Error eliminando evento: $e');
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
      debugPrint('[registerUserInEvent] Intentando registrar userId=$userId en eventId=$eventId');

      final result = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        final eventRef = _firestore.collection('events').doc(eventId);
        final snapshot = await transaction.get(eventRef);

        if (!snapshot.exists) {
          debugPrint('[registerUserInEvent] El evento $eventId no existe');
          return {
            'success': false,
            'message': 'El evento no existe',
          };
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final participants = List<String>.from(data['participants'] ?? []);
        final maxParticipants = (data['maxParticipants'] ?? 0) as int;
        final title = data['title'] ?? 'Evento desconocido';

        debugPrint('[registerUserInEvent] Evento: $title | Participantes: ${participants.length}/$maxParticipants');

        if (participants.contains(userId)) {
          debugPrint('[registerUserInEvent] Usuario $userId ya estaba registrado');
          return {
            'success': true,
            'message': 'Ya estabas registrado en este evento',
          };
        }

        if (participants.length >= maxParticipants) {
          debugPrint('[registerUserInEvent] Evento $eventId está lleno');
          return {
            'success': false,
            'message': 'El evento está lleno',
          };
        }

        debugPrint('[registerUserInEvent] Agregando $userId a participantes');
        transaction.update(eventRef, {
          'participants': FieldValue.arrayUnion([userId]),
          'updatedAt': Timestamp.now(),
        });

        return {
          'success': true,
          'message': 'Registrado exitosamente',
        };
      });

      debugPrint('[registerUserInEvent] Resultado: $result');
      return result;
    } on FirebaseException catch (e) {
      debugPrint('[registerUserInEvent] FirebaseException: ${e.code} - ${e.message}');

      String message;
      if (e.code == 'permission-denied') {
        message = 'Permiso denegado. Verifica las reglas de seguridad.';
      } else if (e.code == 'not-found') {
        message = 'El evento no existe';
      } else {
        message = 'Error Firebase: ${e.message}';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      debugPrint('[registerUserInEvent] Error inesperado: $e');
      return {
        'success': false,
        'message': 'Error al registrar: ${e.toString()}',
      };
    }
  }

  /// Versión simplificada (mantener para compatibilidad)
  Future<bool> registerUserInEvent({
    required String eventId,
    required String userId,
  }) async {
    final result = await registerUserInEventWithMessage(eventId: eventId, userId: userId);
    return result['success'] as bool;
  }
}
