import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

/// Estructura interna para almacenar imagen + metadata de expiración
class _CacheEntry {
  /// Datos binarios de la imagen cacheada
  final Uint8List imageData;

  /// Timestamp de creación (ms desde epoch)
  final int createdAtMs;

  /// Número de veces que se accedió a esta entrada
  int accessCount = 0;

  /// Timestamp del último acceso (para estadísticas)
  int lastAccessMs;

  _CacheEntry({required this.imageData, required this.createdAtMs})
    : lastAccessMs = DateTime.now().millisecondsSinceEpoch;
}

/// Servicio de caché de imágenes con estrategia LRU + TTL.
///
/// Estrategias implementadas:
/// - **Capa de memoria rápida**: acceso inmediato a imágenes ya vistas.
/// - **LRU real**: al leer una URL, se mueve al final del mapa para marcarla
///   como "más recientemente usada"; cuando se llena, se elimina la primera.
/// - **TTL**: cada entrada expira automáticamente después de `defaultTtlMs`.
/// - **Capacidad limitada**: `maxEntries` evita crecimiento indefinido en RAM.
/// - **Métricas**: hit/miss/evictions para justificar rendimiento.
///
/// Ejemplo de flujo en Retos:
/// 1. Usuario carga reviews con imágenes
/// 2. Imagen 1 se carga desde red y se almacena en memoria
/// 3. Usuario vuelve a ver imagen 1 y se recupera desde caché
/// 4. Ese acceso la mueve al final del LRU como entrada reciente
/// 5. Si la caché llega a `maxEntries`, sale la menos usada recientemente
/// 6. Si pasa el TTL, la entrada expira aunque todavía haya capacidad
///
/// Comparable conceptualmente a la capa de memoria de Glide/Picasso/Coil.
///
/// Parámetros de configuración:
/// - defaultTtlMs: Tiempo de vida en milisegundos (default: 5 minutos)
/// - maxEntries: Límite de imágenes en memoria (default: 20)
class TtlImageCacheService {
  /// Diccionario ordenado: la primera entrada es la menos usada recientemente.
  final LinkedHashMap<String, _CacheEntry> _cache =
      LinkedHashMap<String, _CacheEntry>();

  /// Timers de expiración: URL → Timer (para limpiar después de TTL)
  final Map<String, Timer> _expirationTimers = {};

  /// Tiempo de vida en milisegundos para cada entrada
  final int defaultTtlMs;

  /// Capacidad máxima de entradas en caché
  final int maxEntries;

  /// Estadísticas de rendimiento
  int _totalRequests = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _lruEvictions = 0;
  int _ttlEvictions = 0;

  TtlImageCacheService({
    this.defaultTtlMs = 5 * 60 * 1000, // 5 minutos por defecto
    this.maxEntries = 20,
  });

  /// Intenta obtener una imagen del caché.
  ///
  /// Si existe, actualiza metadata y la mueve al final del `LinkedHashMap`,
  /// convirtiéndola en la entrada más recientemente usada.
  Uint8List? get(String url) {
    _totalRequests++;

    final entry = _cache.remove(url);
    if (entry == null) {
      _cacheMisses++;
      return null;
    }

    if (_isExpired(entry)) {
      _expirationTimers[url]?.cancel();
      _expirationTimers.remove(url);
      _ttlEvictions++;
      _cacheMisses++;
      return null;
    }

    entry.accessCount++;
    entry.lastAccessMs = DateTime.now().millisecondsSinceEpoch;
    _cache[url] = entry;

    _cacheHits++;
    return entry.imageData;
  }

  /// Almacena una imagen en caché con expiración automática.
  ///
  /// Si se alcanza `maxEntries`, elimina la primera llave del `LinkedHashMap`,
  /// que corresponde a la entrada menos usada recientemente.
  void put(String url, Uint8List imageData) {
    if (maxEntries <= 0) return;

    _expirationTimers[url]?.cancel();
    _cache.remove(url);

    while (_cache.length >= maxEntries && _cache.isNotEmpty) {
      _evictLeastRecentlyUsed();
    }

    _cache[url] = _CacheEntry(
      imageData: imageData,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    // Configura timer de expiración
    _expirationTimers[url]?.cancel();
    _expirationTimers[url] = Timer(Duration(milliseconds: defaultTtlMs), () {
      if (_cache.remove(url) != null) {
        _ttlEvictions++;
      }
      _expirationTimers.remove(url);
    });
  }

  bool _isExpired(_CacheEntry entry) {
    final ageMs = DateTime.now().millisecondsSinceEpoch - entry.createdAtMs;
    return ageMs >= defaultTtlMs;
  }

  void _evictLeastRecentlyUsed() {
    final lruUrl = _cache.keys.first;
    _expirationTimers[lruUrl]?.cancel();
    _expirationTimers.remove(lruUrl);
    _cache.remove(lruUrl);
    _lruEvictions++;
  }

  /// Limpia una URL específica del caché
  void remove(String url) {
    _expirationTimers[url]?.cancel();
    _cache.remove(url);
    _expirationTimers.remove(url);
  }

  /// Limpia todo el caché y cancela todos los timers
  void clear() {
    for (final timer in _expirationTimers.values) {
      timer.cancel();
    }
    _cache.clear();
    _expirationTimers.clear();
  }

  /// Retorna estadísticas de rendimiento
  Map<String, dynamic> getStats() {
    final hitRate = _totalRequests > 0
        ? (_cacheHits / _totalRequests * 100).toStringAsFixed(2)
        : '0.00';
    final utilizationPercent = maxEntries <= 0
        ? '0.0'
        : ((_cache.length / maxEntries) * 100).toStringAsFixed(1);

    return {
      'totalRequests': _totalRequests,
      'cacheHits': _cacheHits,
      'cacheMisses': _cacheMisses,
      'hitRate': '$hitRate%',
      'currentEntries': _cache.length,
      'maxEntries': maxEntries,
      'lruEvictions': _lruEvictions,
      'ttlEvictions': _ttlEvictions,
      'utilizationPercent': utilizationPercent,
    };
  }

  /// Retorna información detallada de todas las entradas en caché
  List<Map<String, dynamic>> getCacheDetails() {
    var lruPosition = 0;
    return _cache.entries.map((entry) {
      final ageMs =
          DateTime.now().millisecondsSinceEpoch - entry.value.createdAtMs;
      final detail = {
        'lruPosition': lruPosition,
        'isLeastRecentlyUsed': lruPosition == 0,
        'isMostRecentlyUsed': lruPosition == _cache.length - 1,
        'url': entry.key,
        'ageMs': ageMs,
        'ttlMs': defaultTtlMs,
        'ageSeconds': (ageMs / 1000).toStringAsFixed(1),
        'accessCount': entry.value.accessCount,
        'sizeBytes': entry.value.imageData.lengthInBytes,
        'lastAccessMs': entry.value.lastAccessMs,
      };
      lruPosition++;
      return detail;
    }).toList();
  }

  /// Retorna el tamaño total en bytes de todas las imágenes en caché
  int getTotalSizeBytes() {
    return _cache.values.fold(
      0,
      (sum, entry) => sum + entry.imageData.lengthInBytes,
    );
  }

  /// Resetea las estadísticas (sin limpiar el caché)
  void resetStats() {
    _totalRequests = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
    _lruEvictions = 0;
    _ttlEvictions = 0;
  }
}
import 'dart:async';
import 'dart:typed_data';

/// Estructura interna para almacenar imagen + metadata de expiración
class _CacheEntry {
  /// Datos binarios de la imagen cacheada
  final Uint8List imageData;

  /// Timestamp de creación (ms desde epoch)
  final int createdAtMs;

  /// Número de veces que se accedió a esta entrada
  int accessCount = 0;

  /// Timestamp del último acceso (para estadísticas)
  int lastAccessMs;

  _CacheEntry({required this.imageData, required this.createdAtMs})
    : lastAccessMs = DateTime.now().millisecondsSinceEpoch;
}

/// Servicio de caché de imágenes con estrategia TTL (Time-To-Live).
///
/// Esta estrategia complementa a CachedNetworkImage (disco) proporcionando:
/// - **Capa de memoria rápida**: Acceso casi instantáneo a imágenes recientemente vistas
/// - **Expiración automática**: Las imágenes se eliminan de memoria después de TTL ms
/// - **Capacidad limitada**: Máximo de entradas para evitar consumo excesivo de RAM
/// - **Diferente a LRU**: En lugar de evicción basada en uso, usa expiración temporal
///
/// Ejemplo de flujo en Retos:
/// 1. Usuario carga reviews con imágenes
/// 2. Imagen 1 se carga desde red → se almacena en TTL cache + disco (CachedNetworkImage)
/// 3. Usuario vuelve a ver imagen 1 → se recupera de memoria TTL (muy rápido)
/// 4. Después de TTL ms, se elimina de memoria pero sigue en disco
/// 5. Si se solicita nuevamente, se carga del disco (más rápido que red, más lento que memoria)
///
/// Comparable a: Glide/Picasso (memory + disk layering)
///
/// Parámetros de configuración:
/// - defaultTtlMs: Tiempo de vida en milisegundos (default: 5 minutos)
/// - maxEntries: Límite de imágenes en memoria (default: 20)
class TtlImageCacheService {
  /// Diccionario principal: URL → _CacheEntry
  final Map<String, _CacheEntry> _cache = {};

  /// Timers de expiración: URL → Timer (para limpiar después de TTL)
  final Map<String, Timer> _expirationTimers = {};

  /// Tiempo de vida en milisegundos para cada entrada
  final int defaultTtlMs;

  /// Capacidad máxima de entradas en caché
  final int maxEntries;

  /// Estadísticas de rendimiento
  int _totalRequests = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;

  TtlImageCacheService({
    this.defaultTtlMs = 5 * 60 * 1000, // 5 minutos por defecto
    this.maxEntries = 20,
  });

  /// Intenta obtener una imagen del caché TTL.
  /// Retorna null si no existe o ha expirado.
  /// Incrementa accessCount si se encuentra.
  Uint8List? get(String url) {
    _totalRequests++;

    if (!_cache.containsKey(url)) {
      _cacheMisses++;
      return null;
    }

    final entry = _cache[url]!;
    entry.accessCount++;
    entry.lastAccessMs = DateTime.now().millisecondsSinceEpoch;

    _cacheHits++;
    return entry.imageData;
  }

  /// Almacena una imagen en caché con expiración automática.
  /// Si se alcanza maxEntries, elimina la entrada más antigua (FIFO).
  void put(String url, Uint8List imageData) {
    // Si ya existe, actualiza y reinicia el timer de expiración
    if (_cache.containsKey(url)) {
      _expirationTimers[url]?.cancel();
      _cache[url] = _CacheEntry(
        imageData: imageData,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      // Si se alcanza capacidad, elimina la entrada más antigua
      if (_cache.length >= maxEntries) {
        final oldestUrl = _cache.entries
            .reduce((a, b) => a.value.createdAtMs < b.value.createdAtMs ? a : b)
            .key;
        _expirationTimers[oldestUrl]?.cancel();
        _cache.remove(oldestUrl);
        _expirationTimers.remove(oldestUrl);
      }

      // Añade nueva entrada
      _cache[url] = _CacheEntry(
        imageData: imageData,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    }

    // Configura timer de expiración
    _expirationTimers[url]?.cancel();
    _expirationTimers[url] = Timer(Duration(milliseconds: defaultTtlMs), () {
      _cache.remove(url);
      _expirationTimers.remove(url);
    });
  }

  /// Limpia una URL específica del caché
  void remove(String url) {
    _expirationTimers[url]?.cancel();
    _cache.remove(url);
    _expirationTimers.remove(url);
  }

  /// Limpia todo el caché y cancela todos los timers
  void clear() {
    for (final timer in _expirationTimers.values) {
      timer.cancel();
    }
    _cache.clear();
    _expirationTimers.clear();
  }

  /// Retorna estadísticas de rendimiento
  Map<String, dynamic> getStats() {
    final hitRate = _totalRequests > 0
        ? (_cacheHits / _totalRequests * 100).toStringAsFixed(2)
        : '0.00';

    return {
      'totalRequests': _totalRequests,
      'cacheHits': _cacheHits,
      'cacheMisses': _cacheMisses,
      'hitRate': '$hitRate%',
      'currentEntries': _cache.length,
      'maxEntries': maxEntries,
      'utilizationPercent': ((_cache.length / maxEntries) * 100)
          .toStringAsFixed(1),
    };
  }

  /// Retorna información detallada de todas las entradas en caché
  List<Map<String, dynamic>> getCacheDetails() {
    return _cache.entries.map((entry) {
      final ageMs =
          DateTime.now().millisecondsSinceEpoch - entry.value.createdAtMs;
      return {
        'url': entry.key,
        'ageMs': ageMs,
        'ageSeconds': (ageMs / 1000).toStringAsFixed(1),
        'accessCount': entry.value.accessCount,
        'sizeBytes': entry.value.imageData.lengthInBytes,
        'lastAccessMs': entry.value.lastAccessMs,
      };
    }).toList();
  }

  /// Retorna el tamaño total en bytes de todas las imágenes en caché
  int getTotalSizeBytes() {
    return _cache.values.fold(
      0,
      (sum, entry) => sum + entry.imageData.lengthInBytes,
    );
  }

  /// Resetea las estadísticas (sin limpiar el caché)
  void resetStats() {
    _totalRequests = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
  }
}
