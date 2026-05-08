import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ImageCacheDemoDialog extends StatefulWidget {
  const ImageCacheDemoDialog({super.key});

  @override
  State<ImageCacheDemoDialog> createState() => _ImageCacheDemoDialogState();
}

class _ImageCacheDemoDialogState extends State<ImageCacheDemoDialog> {
  final _recentImages = _SimpleLruCache<String, String>(maxEntries: 3);
  final List<_ImageSample> _samples = const [
    _ImageSample(
      title: 'Mountain trail',
      url: 'https://picsum.photos/id/1018/900/600',
      explanation:
          'Good candidate for memory and disk caching because the same URL is revisited frequently.',
    ),
    _ImageSample(
      title: 'City lights',
      url: 'https://picsum.photos/id/1011/900/600',
      explanation:
          'Large image that benefits from downsampling and a bounded cache entry count.',
    ),
    _ImageSample(
      title: 'Ocean view',
      url: 'https://picsum.photos/id/1016/900/600',
      explanation:
          'Useful for testing placeholder, error handling and warm cache behavior.',
    ),
    _ImageSample(
      title: 'Forest path',
      url: 'https://picsum.photos/id/1020/900/600',
      explanation:
          'Shows how the cache keeps recent items alive while older ones are evicted.',
    ),
  ];

  bool _prewarmed = false;
  int _hits = 0;
  int _misses = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmUpCache();
    });
  }

  Future<void> _warmUpCache() async {
    for (final sample in _samples.take(2)) {
      await precacheImage(CachedNetworkImageProvider(sample.url), context);
    }

    if (!mounted) return;
    setState(() {
      _prewarmed = true;
    });
  }

  void _touchSample(_ImageSample sample) {
    setState(() {
      if (_recentImages.containsKey(sample.url)) {
        _hits += 1;
      } else {
        _misses += 1;
      }

      _recentImages.put(sample.url, sample.title);
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageCache = PaintingBinding.instance.imageCache;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940, maxHeight: 840),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C8E8B).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.image_search,
                      color: Color(0xFF0C8E8B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Image caching strategy lab',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Flutter equivalent to Glide, Picasso, Kingfisher and Coil, plus a manual LRU cache.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StrategyChip(label: 'CachedNetworkImage'),
                  _StrategyChip(label: 'Framework ImageCache'),
                  _StrategyChip(label: 'Manual LRU'),
                  _StrategyChip(label: 'Native analogues'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: _samples.map((sample) {
                        final isRecent = _recentImages.containsKey(sample.url);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _touchSample(sample),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isRecent
                                      ? const Color(0xFF0C8E8B)
                                      : const Color(0xFFD7DCE6),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: CachedNetworkImage(
                                        imageUrl: sample.url,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) {
                                          return Container(
                                            color: const Color(0xFFF2F4F8),
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        },
                                        errorWidget: (context, url, error) {
                                          return Container(
                                            color: const Color(0xFFF2F4F8),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.broken_image_outlined,
                                              size: 40,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  sample.title,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                              ),
                                              if (isRecent)
                                                const Chip(
                                                  label: Text('Recent'),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            sample.explanation,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoCard(
                          title: 'Framework cache settings',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Warm up complete: ${_prewarmed ? 'yes' : 'in progress'}",
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'ImageCache.maximumSize: ${imageCache.maximumSize}',
                              ),
                              Text(
                                'ImageCache.maximumSizeBytes: ${imageCache.maximumSizeBytes}',
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Decision: keep the framework cache bounded and let the engine evict older images automatically when memory pressure increases.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _InfoCard(
                          title: 'Manual LRU cache',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Capacity: ${_recentImages.maxEntries} entries',
                              ),
                              Text('Hits: $_hits'),
                              Text('Misses: $_misses'),
                              const SizedBox(height: 8),
                              const Text(
                                'Decision: a LinkedHashMap preserves insertion order so the oldest image can be evicted in O(1) when the capacity is exceeded.',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Recent keys: ${_recentImages.keys.isEmpty ? 'none' : _recentImages.keys.join(' | ')}",
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _InfoCard(
                          title: 'Native data-structure mapping',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'LRU: eviction policy for the least recently used item; ideal for image lists and thumbnail grids.',
                              ),
                              SizedBox(height: 6),
                              Text(
                                'SparseArray: best for int keys with low overhead; in Flutter/Dart, a Map<int, T> is the closest portable fit.',
                              ),
                              SizedBox(height: 6),
                              Text(
                                'ArrayMap: compact map for small collections; useful when the cache has few entries and memory matters.',
                              ),
                              SizedBox(height: 6),
                              Text(
                                'NSCache: auto-evicting cache on iOS; the nearest Flutter analogue is the framework image cache plus a disk cache manager.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'How this maps to mobile libraries',
                child: const Text(
                  'Glide, Picasso, Kingfisher and Coil are the native-library references for Android and iOS. In Flutter, CachedNetworkImage covers the disk/memory image layer while the framework ImageCache handles decoded image reuse. Together they cover the same interview point: cache network images, bound memory usage and choose eviction rules explicitly.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageSample {
  const _ImageSample({
    required this.title,
    required this.url,
    required this.explanation,
  });

  final String title;
  final String url;
  final String explanation;
}

class _StrategyChip extends StatelessWidget {
  const _StrategyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: const Color(0xFFEAF7F6),
      side: const BorderSide(color: Color(0xFFBFE4E2)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7DCE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SimpleLruCache<K, V> {
  _SimpleLruCache({required this.maxEntries}) : assert(maxEntries > 0);

  final int maxEntries;
  final LinkedHashMap<K, V> _entries = LinkedHashMap<K, V>();

  bool containsKey(K key) => _entries.containsKey(key);

  V? get(K key) {
    final value = _entries.remove(key);
    if (value == null) {
      return null;
    }

    _entries[key] = value;
    return value;
  }

  void put(K key, V value) {
    if (_entries.containsKey(key)) {
      _entries.remove(key);
    } else if (_entries.length >= maxEntries) {
      _entries.remove(_entries.keys.first);
    }

    _entries[key] = value;
  }

  Iterable<K> get keys => _entries.keys;
}
