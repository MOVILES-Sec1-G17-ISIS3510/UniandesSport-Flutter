// ...existing code...

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../local_storage/database_helper.dart';

/// SyncEngineService es un singleton que se encarga de procesar la tabla `sync_queue`.
/// Integra con Firestore: sube eventos creados localmente a la colección 'events'.
class SyncEngineService {
  static final SyncEngineService _instance = SyncEngineService._internal();
  factory SyncEngineService() => _instance;
  SyncEngineService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<dynamic>? _connectivitySub;
  Timer? _periodicSyncTimer;
  bool _isProcessing = false;
  bool _isConnected = true; // Tracks actual network state

  // Retries/backoff config
  static const int _maxRetries = 5;
  static const int _baseBackoffMs = 2000; // 2 seconds
  static const Duration _periodicSyncInterval = Duration(seconds: 30);

  /// Inicializa el escucha de conectividad. Llamar desde el arranque de la app (por ejemplo en main).
  void initialize() {
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((dynamic result) {
      final bool hasConn = _hasConnectionDynamic(result);
      _isConnected = hasConn;
      
      if (hasConn) {
        // Automatically trigger sync when connection is recovered
        processQueue();
      }
    });

    _periodicSyncTimer ??= Timer.periodic(_periodicSyncInterval, (_) {
      _trySyncPendingQueue();
    });

    // Intentar procesar al inicializar por si ya hay conexión.
    _trySyncPendingQueue();
  }

  Future<void> _trySyncPendingQueue() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!_hasConnection(connectivity)) return;
      await processQueue();
    } catch (_) {
      // Si falla la verificación de conectividad, no rompemos el ciclo.
    }
  }

  bool _hasConnectionDynamic(dynamic result) {
    // Normalizar diferentes formas de notificación que puedas encontrar.
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    if (result is List<ConnectivityResult>) {
      return result.isNotEmpty && !result.contains(ConnectivityResult.none);
    }
    return false;
  }

  /// Procesa la cola de sincronización local con Firestore.
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Solo procesar tareas que su timestamp sea <= now (las programadas para ahora o antes).
      final List<Map<String, dynamic>> pending = (await _dbHelper.query(
        'sync_queue',
        where: '(status = ? OR status = ?) AND timestamp <= ?',
        whereArgs: ['pending', 'failed', now],
        orderBy: 'timestamp ASC',
      )).cast<Map<String, dynamic>>();

      for (final task in pending) {
        // Detener inmediatamente si se pierde la conexión
        if (!_isConnected) {
          _isProcessing = false;
          break;
        }

        final int id = task['id'] as int;
        final String? eventId = task['event_id'] as String?;
        final String? action = task['action'] as String?;
        final String? payload = task['payload'] as String?;
        final int retryCount = (task['retry_count'] as int?) ?? 0;

        bool success = false;
        bool permanentFailure = false;

        try {
          if (action == 'create_play_event') {
            success = await _uploadPlayEventToFirestore(eventId);
          } else if (action == 'create') {
            success = await _uploadSimpleEventToFirestore(eventId);
          } else if (action == 'leave_play_event' || action == 'LEAVE_EVENT') {
            final resolved = _resolveEventId(eventId, payload);
            success = await _leavePlayEventInFirestore(resolved);
          } else if (action == 'CANCEL_EVENT') {
            final resolved = _resolveEventId(eventId, payload);
            success = await _cancelPlayEventInFirestore(resolved);
          } else {
            success = false;
          }
        } on FirebaseException catch (fe) {
          // Errores permanentes: permisos, autenticación, argumentos inválidos
          if (fe.code == 'permission-denied' || fe.code == 'unauthenticated' || fe.code == 'invalid-argument') {
            permanentFailure = true;
            success = false;
          } else if (fe.code == 'not-found') {
            // Para cancelaciones, si no existe el evento lo tratamos como éxito
            if (action == 'CANCEL_EVENT') {
              success = true;
            } else {
              success = false;
            }
          } else {
            success = false;
          }
        } catch (_) {
          success = false;
        }

        if (success) {
          await _dbHelper.delete('sync_queue', 'id = ?', [id]);

          if (eventId != null && action == 'create_play_event') {
            await _dbHelper.update(
              'play_events',
              {'is_synced': 1},
              'id = ?',
              [eventId],
            );
          } else if (eventId != null && action == 'create') {
            await _dbHelper.update(
              'events',
              {'isSynced': 1},
              'id = ?',
              [eventId],
            );
          } else if (eventId != null && action == 'CANCEL_EVENT') {
            await _dbHelper.delete('play_events', 'id = ?', [eventId]);
            await _dbHelper.delete('events', 'id = ?', [eventId]);
          }
        } else {
          if (permanentFailure) {
            // Marcar como failed permanentemente: establecemos retry_count a max para que no se reintente.
            await _dbHelper.update(
              'sync_queue',
              {
                'retry_count': _maxRetries,
                'status': 'failed',
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              },
              'id = ?',
              [id],
            );
          } else {
            final int newRetries = retryCount + 1;

            if (newRetries >= _maxRetries) {
              // Superó reintentos, marcar como failed y no programar más reintentos.
              await _dbHelper.update(
                'sync_queue',
                {
                  'retry_count': newRetries,
                  'status': 'failed',
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                },
                'id = ?',
                [id],
              );
            } else {
              // Calcular backoff exponencial y actualizar el timestamp para el próximo intento.
              final int delayMs = _baseBackoffMs * (1 << (newRetries - 1));
              final int nextAttempt =
                  DateTime.now().millisecondsSinceEpoch + delayMs;

              await _dbHelper.update(
                'sync_queue',
                {
                  'retry_count': newRetries,
                  'status': 'failed',
                  'timestamp': nextAttempt,
                },
                'id = ?',
                [id],
              );
            }
          }
        }

        // Pequeño delay local entre tareas para evitar ráfagas.
        await Future.delayed(const Duration(milliseconds: 150));
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Sube un evento local a Firestore en la colección 'events'.
  /// Retorna true si la operación fue exitosa.
  Future<bool> _uploadPlayEventToFirestore(String? eventId) async {
    if (eventId == null) return false;

    final rows = await _dbHelper.query(
      'play_events',
      where: 'id = ?',
      whereArgs: [eventId],
    );
    if (rows.isEmpty) return false;

    final event = rows.first;
    final payload = {
      'createdBy': event['created_by'],
      'title': event['title'],
      'sport': event['sport'],
      'modality': event['modality'],
      'description': event['description'],
      'location': event['location'],
      'scheduledAt': Timestamp.fromDate(
        DateTime.parse(event['scheduled_at'] as String),
      ),
      'maxParticipants': event['max_participants'],
      'participants': jsonDecode(event['participants_json'] as String),
      'status': event['status'],
      'createdAt': Timestamp.fromDate(
        DateTime.parse(event['created_at'] as String),
      ),
      'updatedAt': Timestamp.fromDate(
        DateTime.parse(event['updated_at'] as String),
      ),
      'metadata': {'creatorSemester': event['creator_semester']},
      'ownerUid': _auth.currentUser?.uid,
    };

    await _firestore
        .collection('events')
        .doc(eventId)
        .set(payload, SetOptions(merge: true));
    return true;
  }

  Future<bool> _leavePlayEventInFirestore(String? eventId) async {
    if (eventId == null) return false;
    final userUid = _auth.currentUser?.uid;
    if (userUid == null) return false;

    await _firestore.collection('events').doc(eventId).update({
      'participants': FieldValue.arrayRemove([userUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  Future<bool> _cancelPlayEventInFirestore(String? eventId) async {
    if (eventId == null) return false;

    // Intentamos marcar como "cancelled" en lugar de borrar para mantener historial
    await _firestore.collection('events').doc(eventId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // También intentamos eliminar la entrada local si existe
    await _dbHelper.delete('play_events', 'id = ?', [eventId]);
    await _dbHelper.delete('events', 'id = ?', [eventId]);

    return true;
  }

  /// Sube un evento simple (no play_events) a Firestore desde la tabla 'events'.
  Future<bool> _uploadSimpleEventToFirestore(String? eventId) async {
    if (eventId == null) return false;

    final rows = await _dbHelper.query(
      'events',
      where: 'id = ?',
      whereArgs: [eventId],
    );
    if (rows.isEmpty) return false;

    final event = rows.first;

    final Map<String, dynamic> payload = {
      'title': event['title'],
      'description': event['description'],
      'location': event['location'],
      'scheduledAt': event['scheduled_at'] != null ? Timestamp.fromDate(DateTime.parse(event['scheduled_at'] as String)) : null,
      'createdBy': event['created_by'],
      'status': event['status'],
      'createdAt': event['created_at'] != null ? Timestamp.fromDate(DateTime.parse(event['created_at'] as String)) : FieldValue.serverTimestamp(),
      'updatedAt': event['updated_at'] != null ? Timestamp.fromDate(DateTime.parse(event['updated_at'] as String)) : FieldValue.serverTimestamp(),
      'metadata': event['metadata'] ?? {},
      'ownerUid': _auth.currentUser?.uid,
    }..removeWhere((key, value) => value == null);

    await _firestore.collection('events').doc(eventId).set(payload, SetOptions(merge: true));
    return true;
  }

  /// Resuelve el event id a partir del campo eventId o del payload JSON.
  /// Formatos soportados:
  /// - eventId (si proviene del record local)
  /// - payload JSON con {"eventId": "..."} o {"id": "..."}
  String? _resolveEventId(String? eventId, String? payload) {
    if (eventId != null && eventId.isNotEmpty) return eventId;
    if (payload == null || payload.isEmpty) return null;

    try {
      final Map<String, dynamic> parsed = jsonDecode(payload) as Map<String, dynamic>;
      if (parsed.containsKey('eventId')) return parsed['eventId'] as String?;
      if (parsed.containsKey('id')) return parsed['id'] as String?;
    } catch (_) {
      // Si el payload no es JSON válido, intentar extraer con regex simple
      final match = RegExp(r'"eventId"\s*:\s*"([^"]+)"').firstMatch(payload);
      if (match != null && match.groupCount >= 1) return match.group(1);
    }

    return null;
  }

  /// Libera recursos (cancelar suscripciones y timers). Llamar al cerrar la app.
  void dispose() {
    _connectivitySub?.cancel();
    _periodicSyncTimer?.cancel();
  }
}
