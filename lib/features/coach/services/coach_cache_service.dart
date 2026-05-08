import 'dart:convert';

import '../../../core/local_storage/database_helper.dart';
import '../models/coach_model.dart';

/// Caché local con respaldo en SQLite para la lista de coaches y el coach
/// destacado del mes (Coach of the Month).
///
/// La estrategia es de doble propósito:
///   - Local storage: persiste la última lista exitosa traída de Firestore
///     en la tabla `coaches_cache` para que la app abra rápido y funcione
///     sin red.
///   - Caching: aplica un TTL ([_cacheTtl]) sobre cada lectura. Si los
///     datos en la tabla son más viejos que el TTL, se devuelven vacíos para
///     forzar al ViewModel a refrescar desde la fuente remota.
class CoachCacheService {
  CoachCacheService._internal();

  static final CoachCacheService instance = CoachCacheService._internal();

  static const String _table = 'coaches_cache';

  /// Tiempo de vida de las entradas en caché. Pasado este lapso desde el
  /// último `saveState`, las lecturas devolverán vacío y el ViewModel hará
  /// fetch a Firestore.
  static const Duration _cacheTtl = Duration(hours: 1);

  /// Tamaño máximo de items en el caché. Cumple la regla del libro
  /// ("SIEMPRE define límite de tamaño en caches") y previene que la
  /// tabla crezca indefinidamente si el catálogo remoto crece.
  ///
  /// Eviction policy: priority-based — cuando el snapshot supera este
  /// número, se conservan los coaches con mejor `rating` y se descartan
  /// los demás. El coach destacado del mes se preserva siempre, aunque
  /// su rating sea bajo, para que la UX del Coach of the Month no se
  /// rompa cuando hay muchos coaches.
  static const int _maxCachedCoaches = 50;

  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Reemplaza por completo el caché con la lista provista. La estrategia es
  /// de overwrite (no merge) para mantener consistencia con el snapshot de
  /// la fuente remota más reciente.
  ///
  /// Aplica eviction antes de persistir: si el snapshot supera
  /// [_maxCachedCoaches], la lista se reduce con [_applySizeLimit].
  Future<void> saveState({
    required List<Coach> coaches,
    Coach? coachOfTheMonth,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final featuredId = coachOfTheMonth?.id;

    final coachesToCache = _applySizeLimit(coaches, coachOfTheMonth);

    await _dbHelper.transaction((txn) async {
      await txn.delete(_table);

      for (final coach in coachesToCache) {
        final id = coach.id;
        if (id == null || id.isEmpty) continue;

        await txn.insert(_table, {
          'id': id,
          'data': jsonEncode(coach.toJson()),
          'is_coach_of_month': featuredId == id ? 1 : 0,
          'cached_at': now,
        });
      }
    });
  }

  /// Eviction de tamaño máximo: si la lista cabe entera dentro del
  /// límite, se devuelve tal cual. Si lo excede, se ordena por `rating`
  /// descendente y se conservan los top N. Si el coach destacado del
  /// mes no quedó en el top por su rating, se inyecta forzadamente
  /// reemplazando al de menor rating del top, para que el feature de
  /// "Coach of the Month" siga funcionando offline.
  List<Coach> _applySizeLimit(List<Coach> coaches, Coach? featured) {
    if (coaches.length <= _maxCachedCoaches) return coaches;

    final sorted = [...coaches]
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    final result = sorted.take(_maxCachedCoaches).toList();

    final featuredId = featured?.id;
    if (featured != null &&
        featuredId != null &&
        !result.any((c) => c.id == featuredId)) {
      if (result.isNotEmpty) result.removeLast();
      result.add(featured);
    }

    return result;
  }

  /// Restaura la lista cacheada si todavía está dentro del TTL. Devuelve
  /// lista vacía cuando el caché expiró o no existe, lo que el ViewModel
  /// interpreta como "necesito traer datos frescos".
  Future<List<Coach>> loadCachedCoaches() async {
    final rows = await _dbHelper.query(_table, orderBy: 'cached_at DESC');
    if (rows.isEmpty) return const <Coach>[];

    final freshest = rows.first['cached_at'] as int;
    if (_isExpired(freshest)) return const <Coach>[];

    return rows.map(_rowToCoach).toList(growable: false);
  }

  /// Restaura el coach destacado si existe y el caché aún es válido.
  Future<Coach?> loadCachedCoachOfTheMonth() async {
    final rows = await _dbHelper.query(
      _table,
      where: 'is_coach_of_month = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;

    final cachedAt = rows.first['cached_at'] as int;
    if (_isExpired(cachedAt)) return null;

    return _rowToCoach(rows.first);
  }

  Coach _rowToCoach(Map<String, Object?> row) {
    final raw = row['data'] as String;
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return Coach.fromJson(Map<String, dynamic>.from(decoded));
    }
    return const Coach();
  }

  bool _isExpired(int cachedAtMs) {
    final age = DateTime.now().millisecondsSinceEpoch - cachedAtMs;
    return age > _cacheTtl.inMilliseconds;
  }
}
