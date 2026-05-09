// ...existing code...

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
      if (!_hasConnection(connectivity)) return;
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
            if (fe.code == 'permission-denied' ||
                fe.code == 'unauthenticated' ||
                fe.code == 'invalid-argument') {
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
            if (fe.code == 'permission-denied' ||
                fe.code == 'unauthenticated' ||
                fe.code == 'invalid-argument') {
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
            final resolved = _resolveEventId(eventId, payload);
            success = await _leavePlayEventInFirestore(resolved);
          } on FirebaseException catch (fe) {
            if (fe.code == 'permission-denied' ||
                fe.code == 'unauthenticated' ||
                fe.code == 'invalid-argument' ||
                fe.code == 'not-found') {
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
            final resolved = _resolveEventId(eventId, payload);
            success = await _cancelPlayEventInFirestore(resolved);
          } on FirebaseException catch (fe) {
            if (fe.code == 'not-found') {
              success = true;
            } else if (fe.code == 'permission-denied' ||
                fe.code == 'unauthenticated' ||
                fe.code == 'invalid-argument') {
              permanentFailure = true;
              success = false;
            } else {
              success = false;
            }
          } catch (_) {
            success = false;
          }
        } else if (action == 'create_challenge') {
          try {
            success = await _uploadChallengeToFirestore(eventId);
          } on FirebaseException catch (fe) {
            if (fe.code == 'permission-denied' ||
                fe.code == 'unauthenticated' ||
                fe.code == 'invalid-argument') {
              permanentFailure = true;
              success = false;
            } else {
              success = false;
            }
          } catch (_) {
            success = false;
          }
        } else if (action == 'upsert_challenge_review') {
          try {
            success = await _uploadChallengeReviewToFirestore(
              challengeId: eventId,
              rawPayload: payload,
            );
          } on FirebaseException catch (fe) {
            if (fe.code == 'permission-denied' ||
                fe.code == 'unauthenticated' ||
                fe.code == 'invalid-argument') {
              permanentFailure = true;
              success = false;
            } else {
              success = false;
            }
          } catch (_) {
            success = false;
          }
        } else if (action == 'sync_challenge_steps') {
          try {
            success = await _syncChallengeStepsToFirestore(
              challengeId: eventId,
              rawPayload: payload,
            );
          } on FirebaseException catch (fe) {
            if (fe.code == 'permission-denied' ||
                fe.code == 'unauthenticated' ||
                fe.code == 'invalid-argument') {
              permanentFailure = true;
              success = false;
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

          if (eventId != null) {
            if (action == 'create_play_event' ||
                action == 'leave_play_event' ||
                action == 'LEAVE_EVENT') {
              await _dbHelper.update(
                'play_events',
                {'is_synced': 1},
                'id = ?',
                [eventId],
              );
            } else if (action == 'create_challenge') {
              await _dbHelper.update(
                'challenge_snapshots',
                {'is_synced': 1},
                'id = ?',
                [eventId],
              );
            } else if (action == 'upsert_challenge_review') {
              // La reseña ya se subió; no hay tabla local específica para marcar.
            } else if (action == 'sync_challenge_steps') {
              // El progreso se actualiza en Firestore dentro de la transacción.
            } else if (action == 'CANCEL_EVENT') {
              await _dbHelper.delete('play_events', 'id = ?', [eventId]);
              await _dbHelper.delete('events', 'id = ?', [eventId]);
            } else {
              await _dbHelper.update(
                'events',
                {'isSynced': 1},
                'id = ?',
                [eventId],
              );
            }
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

    await _firestore.collection('events').doc(eventId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _dbHelper.delete('play_events', 'id = ?', [eventId]);
    await _dbHelper.delete('events', 'id = ?', [eventId]);

    return true;
  }

  Future<bool> _uploadSimpleEventToFirestore(String? eventId) async {
    if (eventId == null) return false;

    final rows = await _dbHelper.query(
      'events',
      where: 'id = ?',
      whereArgs: [eventId],
    );
    if (rows.isEmpty) return false;

    final event = rows.first;
    final payload = {
      'clientId': event['id'],
      'title': event['title'],
      'date': event['date'],
      'updatedAt': FieldValue.serverTimestamp(),
      'ownerUid': _auth.currentUser?.uid,
    };

    await _firestore
        .collection('events')
        .doc(event['id'] as String)
        .set(payload, SetOptions(merge: true));
    return true;
  }

  Future<bool> _uploadChallengeToFirestore(String? challengeId) async {
    if (challengeId == null) return false;

    final rows = await _dbHelper.query(
      'challenge_snapshots',
      where: 'id = ?',
      whereArgs: [challengeId],
    );
    if (rows.isEmpty) return false;

    final challenge = rows.first;
    final String? endDateRaw = challenge['end_date'] as String?;
    final DateTime? endDate = endDateRaw == null
        ? null
        : DateTime.tryParse(endDateRaw);

    final payload = {
      'title': challenge['title'],
      'sport': challenge['sport'],
      'description': challenge['description'],
      'goalLabel': challenge['goal_label'],
      'trackingMode': challenge['tracking_mode'] ?? 'manual',
      'stepGoal': challenge['step_goal'],
      'difficulty': challenge['difficulty'],
      'reward': challenge['reward'],
      'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
      'status': challenge['status'] ?? 'active',
      'createdBy': challenge['created_by'] ?? _auth.currentUser?.uid,
      'participantsCount': challenge['participants_count'] ?? 0,
      'progressByUser': {},
      'stepProgressByUser': {},
      'stepSensorBaselineByUser': {},
      'ratingAverage': (challenge['rating_average'] as num?)?.toDouble() ?? 0.0,
      'ratingCount': 0,
      'reviewsCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('challenges')
        .doc(challengeId)
        .set(payload, SetOptions(merge: true));

    return true;
  }

  Future<String?> _uploadReviewImageFromPath({
    required String challengeId,
    required String imagePath,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child(
      'challenge_reviews/$challengeId/$fileName',
    );
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<bool> _uploadChallengeReviewToFirestore({
    required String? challengeId,
    required String? rawPayload,
  }) async {
    if (challengeId == null || rawPayload == null || rawPayload.isEmpty) {
      return false;
    }

    final decoded = jsonDecode(rawPayload);
    if (decoded is! Map<String, dynamic>) {
      return false;
    }

    final userId = decoded['userId'] as String?;
    final userName = decoded['userName'] as String?;
    final challengeTitle = decoded['challengeTitle'] as String?;
    final comment = decoded['comment'] as String?;
    final rating = (decoded['rating'] as num?)?.toInt();
    final imagePath = decoded['imagePath'] as String?;

    if (userId == null ||
        userId.isEmpty ||
        comment == null ||
        comment.isEmpty ||
        rating == null ||
        rating <= 0) {
      return false;
    }

    final uploadedImageUrl = (imagePath != null && imagePath.isNotEmpty)
        ? await _uploadReviewImageFromPath(
            challengeId: challengeId,
            imagePath: imagePath,
          )
        : null;

    final challengeRef = _firestore.collection('challenges').doc(challengeId);
    final reviewRef = challengeRef.collection('reviews').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final challengeSnapshot = await transaction.get(challengeRef);
      if (!challengeSnapshot.exists) {
        throw StateError('Challenge not found');
      }

      final reviewSnapshot = await transaction.get(reviewRef);
      final existingData = reviewSnapshot.data() ?? const <String, dynamic>{};
      final previousRating = (existingData['rating'] as num?)?.toDouble();
      final existingImageUrl = (existingData['imageUrl'] as String?)?.trim();

      final challengeData =
          challengeSnapshot.data() ?? const <String, dynamic>{};
      final currentCount = (challengeData['ratingCount'] as num?)?.toInt() ?? 0;
      final currentAverage =
          (challengeData['ratingAverage'] as num?)?.toDouble() ?? 0.0;

      double totalScore = currentAverage * currentCount;
      int nextCount = currentCount;

      if (previousRating != null && currentCount > 0) {
        totalScore -= previousRating;
      } else {
        nextCount += 1;
      }

      totalScore += rating;
      final nextAverage = nextCount > 0 ? (totalScore / nextCount) : 0.0;

      final finalImageUrl =
          uploadedImageUrl ??
          ((existingImageUrl != null && existingImageUrl.isNotEmpty)
              ? existingImageUrl
              : null);

      final reviewPayload = <String, dynamic>{
        'challengeId': challengeId,
        'challengeTitle': challengeTitle,
        'userId': userId,
        'userName': userName,
        'rating': rating,
        'comment': comment,
        'updatedAt': FieldValue.serverTimestamp(),
        if (previousRating == null) 'createdAt': FieldValue.serverTimestamp(),
        if (finalImageUrl != null) 'imageUrl': finalImageUrl,
      };

      transaction.set(reviewRef, reviewPayload, SetOptions(merge: true));
      transaction.update(challengeRef, {
        'ratingAverage': double.parse(nextAverage.toStringAsFixed(2)),
        'ratingCount': nextCount,
        'reviewsCount': nextCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return true;
  }

  Future<bool> _syncChallengeStepsToFirestore({
    required String? challengeId,
    required String? rawPayload,
  }) async {
    if (challengeId == null || rawPayload == null || rawPayload.isEmpty) {
      return false;
    }

    final decoded = jsonDecode(rawPayload);
    if (decoded is! Map<String, dynamic>) return false;

    final userId = decoded['userId'] as String?;
    final currentSteps = (decoded['currentSteps'] as num?)?.toInt();
    if (userId == null || userId.isEmpty || currentSteps == null) return false;

    final challengeRef = _firestore.collection('challenges').doc(challengeId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(challengeRef);
      if (!snapshot.exists) {
        throw StateError('Challenge not found');
      }

      final data = snapshot.data() ?? const <String, dynamic>{};
      final stepGoal = (data['stepGoal'] as num?)?.toInt() ?? 8000;
      final stepProgressByUser = Map<String, dynamic>.from(
        data['stepProgressByUser'] ?? const {},
      );
      final stepSensorBaselineByUser = Map<String, dynamic>.from(
        data['stepSensorBaselineByUser'] ?? const {},
      );

      final previousSensorSteps =
          (stepSensorBaselineByUser[userId] as num?)?.toInt() ?? 0;
      final currentTrackedSteps =
          (stepProgressByUser[userId] as num?)?.toInt() ?? 0;

      final hasNoBaselineYet =
          previousSensorSteps == 0 && currentTrackedSteps == 0;
      final sensorDelta = hasNoBaselineYet
          ? 0
          : (currentSteps - previousSensorSteps).clamp(0, 1000000);
      final updatedTrackedSteps = currentTrackedSteps + sensorDelta;
      final updatedProgress = (updatedTrackedSteps / stepGoal).clamp(0.0, 1.0);

      transaction.update(challengeRef, {
        'stepProgressByUser.$userId': updatedTrackedSteps,
        'stepSensorBaselineByUser.$userId': currentSteps,
        'progressByUser.$userId': updatedProgress,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return true;
  }

  String? _resolveEventId(String? eventId, String? payload) {
    if (eventId != null && eventId.isNotEmpty) return eventId;
    if (payload == null || payload.isEmpty) return null;

    try {
      final Map<String, dynamic> parsed =
          jsonDecode(payload) as Map<String, dynamic>;
      if (parsed.containsKey('eventId')) return parsed['eventId'] as String?;
      if (parsed.containsKey('id')) return parsed['id'] as String?;
    } catch (_) {
      final match = RegExp(r'"eventId"\s*:\s*"([^"]+)"').firstMatch(payload);
      if (match != null && match.groupCount >= 1) return match.group(1);
    }

    return null;
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }
}
