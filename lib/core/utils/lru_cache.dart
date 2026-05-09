import 'dart:collection';

/// Generic LRU (Least Recently Used) Cache implementation.
/// Uses a LinkedHashMap to maintain insertion and access order.
class LruCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache;

  LruCache({required this.maxSize}) : _cache = LinkedHashMap<K, V>();

  /// Returns the value associated with the key if it exists, moving it to the
  /// front (most recently used). Returns null otherwise.
  V? get(K key) {
    if (_cache.containsKey(key)) {
      // Remove and re-insert to update access order
      final value = _cache.remove(key)!;
      _cache[key] = value;
      return value;
    }
    return null;
  }

  /// Inserts a key-value pair. If the cache is full, evicts the least
  /// recently used item (the first item in the LinkedHashMap).
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= maxSize) {
      // Remove the first (least recently used) key
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
    _cache[key] = value;
  }

  /// Removes all items from the cache.
  void clear() {
    _cache.clear();
  }

  /// Returns the current number of elements in the cache.
  int get length => _cache.length;

  /// Returns a boolean indicating whether the cache contains the specified key.
  bool containsKey(K key) => _cache.containsKey(key);
}
