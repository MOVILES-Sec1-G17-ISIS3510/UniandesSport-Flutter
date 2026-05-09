import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Persiste los coaches marcados como favoritos por el usuario.
///
/// Estrategia de storage: **Hive** (BD llave/valor tipada). Es la elección
/// correcta vs alternativas:
///   - SharedPreferences: requeriría serializar/deserializar JSON manualmente
///     y no expone API reactiva.
///   - SQLite (`coaches_cache`): overkill para una colección plana de IDs
///     sin schema relacional.
///   - Hive: API tipada (`Box<bool>`), persistencia rápida en disco binario,
///     y `listenable()` permite que la UI reaccione automáticamente sin
///     `setState` manual.
///
/// Modelo de datos:
///   - `key`   = `coachId` (String)
///   - `value` = `true` (la presencia de la key indica favorito; ausencia
///     = no favorito)
class FavoriteCoachesService {
  FavoriteCoachesService._internal();

  static final FavoriteCoachesService instance =
      FavoriteCoachesService._internal();

  static const String boxName = 'favorite_coaches';

  /// Abre el box en disco. Debe llamarse desde `main.dart` después de
  /// `Hive.initFlutter()` y antes de `runApp()`, igual que el patrón que
  /// ya sigue `TimeslotHiveService`.
  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<bool>(boxName);
    }
  }

  Box<bool> get _box => Hive.box<bool>(boxName);

  bool isFavorite(String coachId) {
    if (!Hive.isBoxOpen(boxName)) return false;
    return _box.containsKey(coachId);
  }

  /// Toggle: si era favorito lo quita; si no lo era lo agrega.
  Future<void> toggle(String coachId) async {
    if (!Hive.isBoxOpen(boxName)) {
      await init();
    }
    if (_box.containsKey(coachId)) {
      await _box.delete(coachId);
    } else {
      await _box.put(coachId, true);
    }
  }

  /// Devuelve la lista actual de IDs favoritos (útil para filtros).
  List<String> getFavoriteIds() {
    if (!Hive.isBoxOpen(boxName)) return const <String>[];
    return _box.keys.cast<String>().toList();
  }

  /// Listenable reactivo: cualquier widget que use ValueListenableBuilder
  /// con esto se reconstruirá automáticamente cuando cambie el contenido
  /// del box (toggle, delete, etc.).
  ValueListenable<Box<bool>> listenable() => _box.listenable();
}
