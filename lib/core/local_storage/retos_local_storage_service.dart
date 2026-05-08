import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_helper.dart';

/// Servicio de almacenamiento local que agrupa las estrategias usadas en Retos.
///
/// Estrategias cubiertas:
/// - Base de datos local relacional con sqflite
/// - Base de datos llave/valor con Hive
/// - Archivos locales con `dart:io`
/// - Preferencias con SharedPreferences
class RetosLocalStorageService {
  static const String _hiveBoxName = 'retos_local_storage_box';
  static const String _prefsSelectedFilterKey = 'retos_selected_filter';
  static const String _prefsOfflineModeKey = 'retos_offline_mode_enabled';
  static const String _prefsLastChallengeKey = 'retos_last_challenge_id';

  final DatabaseHelper _databaseHelper = DatabaseHelper();

  /// Guarda un snapshot del reto en SQLite para persistir almacenamiento relacional.
  ///
  /// Esta función también permite persistir metadatos extra para que la vista
  /// offline de Retos pueda reconstruir tarjetas, filtros y detalles básicos.
  Future<void> saveChallengeSnapshotToSqlite({
    required String challengeId,
    required String title,
    required String sport,
    required double progress,
    String? notes,
    String? trackingMode,
    int? stepGoal,
    double? ratingAverage,
    int? participantsCount,
    String? goalLabel,
    String? description,
    String? difficulty,
    String? reward,
    String? createdBy,
    DateTime? endDate,
    String? status,
    bool isSynced = false,
  }) async {
    await _databaseHelper.insert('challenge_snapshots', {
      'id': challengeId,
      'title': title,
      'sport': sport,
      'progress': progress,
      'notes': notes,
      'tracking_mode': trackingMode,
      'step_goal': stepGoal,
      'rating_average': ratingAverage,
      'participants_count': participantsCount,
      'goal_label': goalLabel,
      'description': description,
      'difficulty': difficulty,
      'reward': reward,
      'created_by': createdBy,
      'end_date': endDate?.toIso8601String(),
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Lee los snapshots desde SQLite para explicar consultas y ordenamiento local.
  Future<List<Map<String, Object?>>> loadChallengeSnapshotsFromSqlite() async {
    return _databaseHelper.query(
      'challenge_snapshots',
      orderBy: 'updated_at DESC',
    );
  }

  /// Guarda un reto favorito en Hive como un objeto pequeño llave/valor.
  Future<void> saveChallengeBookmarkToHive({
    required String challengeId,
    required String title,
    required String sport,
    required double progress,
  }) async {
    final box = await Hive.openBox<Map>(_hiveBoxName);
    await box.put(challengeId, {
      'id': challengeId,
      'title': title,
      'sport': sport,
      'progress': progress,
      'savedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Carga todos los favoritos guardados en Hive.
  Future<List<Map<String, dynamic>>> loadChallengeBookmarksFromHive() async {
    final box = await Hive.openBox<Map>(_hiveBoxName);
    return box.values.map((entry) => Map<String, dynamic>.from(entry)).toList();
  }

  /// Persiste preferencias ligeras de Retos usando SharedPreferences.
  Future<void> saveChallengePreferences({
    required String selectedFilter,
    required bool offlineModeEnabled,
    required String? lastChallengeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsSelectedFilterKey, selectedFilter);
    await prefs.setBool(_prefsOfflineModeKey, offlineModeEnabled);
    if (lastChallengeId == null || lastChallengeId.isEmpty) {
      await prefs.remove(_prefsLastChallengeKey);
    } else {
      await prefs.setString(_prefsLastChallengeKey, lastChallengeId);
    }
  }

  /// Carga las preferencias para explicar el patrón de almacenamiento llave/valor.
  Future<Map<String, dynamic>> loadChallengePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'selectedFilter': prefs.getString(_prefsSelectedFilterKey) ?? 'all',
      'offlineModeEnabled': prefs.getBool(_prefsOfflineModeKey) ?? false,
      'lastChallengeId': prefs.getString(_prefsLastChallengeKey),
    };
  }

  /// Guarda una lista de retos remotos como caché local para soportar el modo offline.
  ///
  /// Se usa cuando la app sí tiene conexión y Firestore entrega el catálogo.
  /// Luego, si la conexión se pierde, la pantalla de Retos puede reconstruirse
  /// con esta información sin mostrar un mensaje vacío.
  Future<void> cacheChallengeCatalogFromFirestore(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    for (final doc in docs) {
      final data = doc.data();
      final title = (data['title'] as String?)?.trim().isNotEmpty == true
          ? data['title'] as String
          : ((data['goalLabel'] as String?)?.trim().isNotEmpty == true
                ? data['goalLabel'] as String
                : 'Challenge');

      await saveChallengeSnapshotToSqlite(
        challengeId: doc.id,
        title: title,
        sport: (data['sport'] as String?) ?? 'general',
        progress: _extractProgress(data),
        notes: (data['description'] as String?)?.trim(),
        trackingMode: (data['trackingMode'] as String?)?.trim(),
        stepGoal: (data['stepGoal'] as num?)?.toInt(),
        ratingAverage: (data['ratingAverage'] as num?)?.toDouble(),
        participantsCount:
            (data['participantsCount'] as num?)?.toInt() ??
            (data['participants'] is List
                ? (data['participants'] as List).length
                : null),
        goalLabel: (data['goalLabel'] as String?)?.trim(),
        description: (data['description'] as String?)?.trim(),
        difficulty: (data['difficulty'] as String?)?.trim(),
        reward: (data['reward'] as String?)?.trim(),
        createdBy: (data['createdBy'] as String?)?.trim(),
        endDate: (data['endDate'] as Timestamp?)?.toDate(),
        status: (data['status'] as String?)?.trim(),
        isSynced: true,
      );
    }
  }

  /// Carga el catálogo de retos cacheado localmente para usarlo como fallback.
  Future<List<Map<String, Object?>>> loadCachedChallengeCatalog() async {
    return _databaseHelper.query(
      'challenge_snapshots',
      orderBy: 'updated_at DESC',
    );
  }

  double _extractProgress(Map<String, dynamic> data) {
    final progress = data['progress'];
    if (progress is num) {
      return progress.toDouble();
    }
    return 0.0;
  }

  /// Exporta un archivo JSON local con el estado actual de Retos.
  Future<String> exportChallengeStateToFile({
    required Map<String, dynamic> state,
  }) async {
    final exportDirectory = Directory(
      path.join(Directory.systemTemp.path, 'uniandes_sport'),
    );
    if (!await exportDirectory.exists()) {
      await exportDirectory.create(recursive: true);
    }

    final exportFile = File(
      path.join(exportDirectory.path, 'retos_state_export.json'),
    );
    await exportFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state),
    );
    return exportFile.path;
  }
}
