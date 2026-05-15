import 'dart:async';
import 'dart:collection';

/// Servicio genérico de caché en memoria con LRU + TTL.
/// Guarda objetos dinámicos (Map/List/primitive) referenciados por una clave.
class TtlMemoryCacheService {
  final LinkedHashMap<String, _MemEntry> _cache = LinkedHashMap();
  final Map<String, Timer> _timers = {};

  final int defaultTtlMs;
  final int maxEntries;

  int _totalRequests = 0;
  int _hits = 0;
  int _misses = 0;
  int _lruEvictions = 0;
  int _ttlEvictions = 0;

  TtlMemoryCacheService({
    this.defaultTtlMs = 5 * 60 * 1000,
    this.maxEntries = 200,
  });

  dynamic get(String key) {
    _totalRequests++;
    final entry = _cache.remove(key);
    if (entry == null) {
      _misses++;
      return null;
    }

    if (_isExpired(entry)) {
      _timers[key]?.cancel();
      _timers.remove(key);
      _ttlEvictions++;
      _misses++;
      return null;
    }

    entry.accessCount++;
    entry.lastAccessMs = DateTime.now().millisecondsSinceEpoch;
    _cache[key] = entry; // move to recent
    _hits++;
    return entry.value;
  }

  void put(String key, dynamic value, {int? ttlMs}) {
    if (maxEntries <= 0) return;

    _timers[key]?.cancel();
    _cache.remove(key);

    while (_cache.length >= maxEntries && _cache.isNotEmpty) {
      _evictLru();
    }

    _cache[key] = _MemEntry(
      value: value,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    _timers[key]?.cancel();
    _timers[key] = Timer(Duration(milliseconds: ttlMs ?? defaultTtlMs), () {
      if (_cache.remove(key) != null) _ttlEvictions++;
      _timers.remove(key);
    });
  }

  void remove(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
    _cache.remove(key);
  }

  void clear() {
    for (final t in _timers.values) t.cancel();
    _timers.clear();
    _cache.clear();
  }

  bool _isExpired(_MemEntry entry) {
    final age = DateTime.now().millisecondsSinceEpoch - entry.createdAtMs;
    return age >= defaultTtlMs;
  }

  void _evictLru() {
    final lruKey = _cache.keys.first;
    _timers[lruKey]?.cancel();
    _timers.remove(lruKey);
    _cache.remove(lruKey);
    _lruEvictions++;
  }

  Map<String, dynamic> getStats() {
    final hitRate = _totalRequests > 0
        ? (_hits / _totalRequests * 100).toStringAsFixed(2)
        : '0.00';
    final utilization = maxEntries <= 0
        ? '0.0'
        : ((_cache.length / maxEntries) * 100).toStringAsFixed(1);

    return {
      'totalRequests': _totalRequests,
      'hits': _hits,
      'misses': _misses,
      'hitRate': '$hitRate%',
      'currentEntries': _cache.length,
      'maxEntries': maxEntries,
      'lruEvictions': _lruEvictions,
      'ttlEvictions': _ttlEvictions,
      'utilizationPercent': utilization,
    };
  }
}

class _MemEntry {
  final dynamic value;
  final int createdAtMs;
  int accessCount = 0;
  int lastAccessMs;

  _MemEntry({required this.value, required this.createdAtMs})
    : lastAccessMs = DateTime.now().millisecondsSinceEpoch;
}
