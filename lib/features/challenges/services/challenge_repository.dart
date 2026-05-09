import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/local_storage/database_helper.dart';
import '../../../core/network/sync_engine_service.dart';

/// Repositorio offline-first para la creación de retos.
///
/// Flujo:
/// 1) Guarda el reto en SQLite (`challenge_snapshots`)
/// 2) Encola `create_challenge` en `sync_queue`
/// 3) Dispara `processQueue` en background
class ChallengeRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncEngineService _syncEngine = SyncEngineService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createChallengeLocalFirst({
    required String title,
    required String sport,
    required String description,
    required String goal,
    required DateTime endDate,
    required String createdBy,
    required bool useStepTracking,
    String? difficulty,
    String? reward,
    int? stepGoal,
  }) async {
    final challengeId = _firestore.collection('challenges').doc().id;

    await _dbHelper.transaction((txn) async {
      await txn.insert('challenge_snapshots', {
        'id': challengeId,
        'title': title,
        'sport': sport,
        'progress': 0.0,
        'notes': description.isNotEmpty ? description : null,
        'tracking_mode': useStepTracking ? 'steps' : 'manual',
        'step_goal': useStepTracking ? stepGoal : null,
        'rating_average': 0.0,
        'participants_count': 0,
        'goal_label': goal.isNotEmpty ? goal : null,
        'description': description.isNotEmpty ? description : null,
        'difficulty': (difficulty?.isNotEmpty ?? false) ? difficulty : null,
        'reward': (reward?.isNotEmpty ?? false) ? reward : null,
        'created_by': createdBy,
        'end_date': endDate.toIso8601String(),
        'status': 'active',
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      });

      await txn.insert('sync_queue', {
        'event_id': challengeId,
        'action': 'create_challenge',
        'status': 'pending',
        'retry_count': 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });

    Future.microtask(() => _syncEngine.processQueue());

    return challengeId;
  }
}
