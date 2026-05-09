import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniandessport_flutter/core/services/ttl_image_cache_service.dart';

void main() {
  group('TtlImageCacheService', () {
    Uint8List bytes(int value) => Uint8List.fromList([value]);

    test('evicts the least recently used entry when capacity is reached', () {
      final cache = TtlImageCacheService(maxEntries: 2);

      cache.put('image-a', bytes(1));
      cache.put('image-b', bytes(2));

      expect(cache.get('image-a'), bytes(1));

      cache.put('image-c', bytes(3));

      expect(cache.get('image-b'), isNull);
      expect(cache.get('image-a'), bytes(1));
      expect(cache.get('image-c'), bytes(3));
      expect(cache.getStats()['lruEvictions'], 1);

      cache.clear();
    });

    test('expires entries after the configured ttl', () async {
      final cache = TtlImageCacheService(defaultTtlMs: 20, maxEntries: 2);

      cache.put('short-lived-image', bytes(4));
      expect(cache.get('short-lived-image'), bytes(4));

      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(cache.get('short-lived-image'), isNull);
      expect(cache.getStats()['ttlEvictions'], 1);

      cache.clear();
    });

    test('reports cache hits and misses', () {
      final cache = TtlImageCacheService(maxEntries: 2);

      cache.put('image-a', bytes(1));
      cache.get('image-a');
      cache.get('missing-image');

      final stats = cache.getStats();

      expect(stats['totalRequests'], 2);
      expect(stats['cacheHits'], 1);
      expect(stats['cacheMisses'], 1);
      expect(stats['hitRate'], '50.00%');

      cache.clear();
    });
  });
}
