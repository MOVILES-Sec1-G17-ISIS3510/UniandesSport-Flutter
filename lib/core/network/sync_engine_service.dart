// ...existing code...

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../local_storage/database_helper.dart';

/// SyncEngineService es un singleton que se encarga de procesar la tabla `sync_queue`.
/// Ahora integrado con Firestore: sube eventos creados localmente a la colección 'events'.
class SyncEngineService {
  static final SyncEngineService _instance = SyncEngineService._internal();
  factory SyncEngineService() => _instance;
  SyncEngineService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicSyncTimer;
  bool _isProcessing = false;

  // Retries/backoff config
  static const int _maxRetries = 5;
  static const int _baseBackoffMs = 2000; // 2 seconds
  static const Duration _periodicSyncInterval = Duration(seconds: 30);

  /// Inicializa el escucha de conectividad. Llamar desde el arranque de la app (por ejemplo en main).
  void initialize() {
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      if (!_hasConnection(results)) {
        return;
      }
      processQueue();
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
      if (connectivity == ConnectivityResult.none) return;
      await processQueue();
    } catch (_) {
      // Si falla la verificación de conectividad, no rompemos el ciclo.
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Solo procesar tareas que su timestamp sea <= now (las programadas para ahora o antes).
      final pending = await _dbHelper.query(
        'sync_queue',
        where: '(status = ? OR status = ?) AND timestamp <= ?',
        whereArgs: ['pending', 'failed', now],
        orderBy: 'timestamp ASC',
      );

      for (final task in pending) {
        final int id = task['id'] as int;
        final String? eventId = task['event_id'] as String?;
        final String? action = task['action'] as String?;
        final String? payload = task['payload'] as String?;
        final int retryCount = (task['retry_count'] as int?) ?? 0;

        bool success = false;
        bool permanentFailure = false;

        if (action == 'create_play_event') {
          try {
            success = await _uploadPlayEventToFirestore(eventId);
          } on FirebaseException catch (fe) {
            if (fe.code == 'permission-denied' || fe.code == 'unauthenticated' || fe.code == 'invalid-argument') {
              permanentFailure = true;
              success = false;
            } else {
              success = false;
            }
          } catch (_) {
            success = false;
          }
        } else if (action == 'create') {
          try {
            success = await _uploadSimpleEventToFirestore(eventId);
          } on FirebaseException catch (fe) {
            if (fe.code == 'permission-denied' || fe.code == 'unauthenticated' || fe.code == 'invalid-argument') {
              permanentFailure = true;
              success = false;
            } else {
              success = false;
            }
          } catch (_) {
            success = false;
          }
        } else if (action == 'leave_play_event' || action == 'LEAVE_EVENT') {
          try {
            success = await _leavePlayEventInFirestore(_resolveEventId(eventId, payload));
          } on FirebaseException catch (fe) {
            if (fe.code == 'permission-denied' || fe.code == 'unauthenticated' || fe.code == 'invalid-argument' || fe.code == 'not-found') {
              permanentFailure = true;
              success = false;
            } else {
              success = false;
            }
          } catch (_) {
            success = false;
          }
        } else if (action == 'CANCEL_EVENT') {
          try {
            success = await _cancelPlayEventInFirestore(_resolveEventId(eventId, payload));
          } on FirebaseException catch (fe) {
            if (fe.code == 'permission-denied' || fe.code == 'unauthenticated' || fe.code == 'invalid-argument') {
              permanentFailure = true;
              success = false;
            } else if (fe.code == 'not-found') {
              success = true;
            } else {
              success = false;
            }
          } catch (_) {
            success = false;
          }
        } else {
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
              {'retry_count': _maxRetries, 'status': 'failed', 'timestamp': DateTime.now().millisecondsSinceEpoch},
              'id = ?',
              [id],
            );
          } else {
            final int newRetries = retryCount + 1;

            if (newRetries >= _maxRetries) {
              // Superó reintentos, marcar como failed y no programar más reintentos.
              await _dbHelper.update(
                'sync_queue',
                {'retry_count': newRetries, 'status': 'failed', 'timestamp': DateTime.now().millisecondsSinceEpoch},
                'id = ?',
                [id],
              );
            } else {
              // Calcular backoff exponencial y actualizar el timestamp para el próximo intento.
              final int delayMs = _baseBackoffMs * (1 << (newRetries - 1));
              final int nextAttempt = DateTime.now().millisecondsSinceEpoch + delayMs;

              await _dbHelper.update(
                'sync_queue',
                {'retry_count': newRetries, 'status': 'failed', 'timestamp': nextAttempt},
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

    final rows = await _dbHelper.query('play_events', where: 'id = ?', whereArgs: [eventId]);
    if (rows.isEmpty) return false;

    final event = rows.first;
    final payload = {
      'createdBy': event['created_by'],
      'title': event['title'],
      'sport': event['sport'],
      'modality': event['modality'],
      'description': event['description'],
      'location': event['location'],
      'scheduledAt': Timestamp.fromDate(DateTime.parse(event['scheduled_at'] as String)),
      'maxParticipants': event['max_participants'],
      'participants': jsonDecode(event['participants_json'] as String),
      'status': event['status'],
      'createdAt': Timestamp.fromDate(DateTime.parse(event['created_at'] as String)),
      'updatedAt': Timestamp.fromDate(DateTime.parse(event['updated_at'] as String)),
      'metadata': {
        'creatorSemester': event['creator_semester'],
      },
      'ownerUid': _auth.currentUser?.uid,
    };

    await _firestore.collection('events').doc(eventId).set(payload, SetOptions(merge: true));
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
    if
