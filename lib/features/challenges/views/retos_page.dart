import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/step_sensor_service.dart';
import '../../../core/constants/app_field_limits.dart';
import '../../../core/services/ttl_image_cache_service.dart';
import '../../../core/local_storage/retos_local_storage_service.dart';
import '../../../core/local_storage/database_helper.dart';
import '../../../core/network/sync_engine_service.dart';
import '../../auth/models/user_profile.dart';
import '../services/challenge_repository.dart';
import '../services/challenge_recommendation_engine.dart';
import '../widgets/challenge_review_dialog.dart';

/// Pantalla de Retos que renderiza retos activos, recomendaciones y la UI de participación.
class RetosPage extends StatefulWidget {
  const RetosPage({
    super.key,
    required this.profile,
    required this.challengeDocs,
  });

  final UserProfile profile;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> challengeDocs;

  @override
  State<RetosPage> createState() => _RetosPageState();
}

class _RetosPageState extends State<RetosPage>
    with AutomaticKeepAliveClientMixin<RetosPage> {
  // UI filters
  String _selectedSportFilter = 'all';
  String _selectedTrackingFilter = 'all';
  List<double> _ratingFilterOptions = const [0.0, 3.0, 4.0, 5.0];
  double _selectedMinRatingFilter = 0.0;

  // State flags
  bool _isCreatingChallenge = false;
  bool _isCheckingConnectivity = true;
  bool _isLoadingCachedChallenges = false;
  bool _isOffline = false;

  // Services and caches
  late final ChallengeRecommendationEngine _recommendationEngine;
  late final StepSensorService _stepSensorService;
  final RetosLocalStorageService _localStorageService =
      RetosLocalStorageService();
  final ChallengeRepository _challengeRepository = ChallengeRepository();
  final TtlImageCacheService _ttlImageCache = TtlImageCacheService();

  late Stream<QuerySnapshot<Map<String, dynamic>>> _challengesStream;
  StreamSubscription<dynamic>? _connectivitySub;
  List<Map<String, dynamic>> _cachedChallengeRows = [];

  final int _defaultStepGoal = 8000;

  bool _isOfflineResult(dynamic result) {
    if (result is List<ConnectivityResult>) {
      if (result.isEmpty) return true;
      return result.contains(ConnectivityResult.none);
    }
    if (result is ConnectivityResult) {
      return result == ConnectivityResult.none;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _recommendationEngine = ChallengeRecommendationEngine();
    _stepSensorService = StepSensorService();
    _challengesStream = FirebaseFirestore.instance
        .collection('challenges')
        .snapshots();
    // Start connectivity check
    Connectivity().checkConnectivity().then((result) {
      setState(() {
        _isOffline = _isOfflineResult(result);
        _isCheckingConnectivity = false;
      });
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      final nowOffline = _isOfflineResult(result);
      if (mounted) {
        setState(() {
          _isOffline = nowOffline;
          _isCheckingConnectivity = false;
        });
      }
      if (!nowOffline) {
        // When back online, attempt to cache remote catalog
        final docsFuture = FirebaseFirestore.instance
            .collection('challenges')
            .limit(200)
            .get();
        docsFuture
            .then(
              (snap) => _localStorageService.cacheChallengeCatalogFromFirestore(
                snap.docs,
              ),
            )
            .ignore();
      }
    });

    // Load cached challenges for offline view
    _loadCachedChallenges();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _resetChallengeFilters() {
    setState(() {
      _selectedSportFilter = 'all';
      _selectedTrackingFilter = 'all';
      _selectedMinRatingFilter = 0.0;
    });
  }

  bool _matchesChallengeFilters(Map<String, dynamic> data) {
    final sport = (data['sport'] as String?)?.toLowerCase() ?? '';
    final tracking =
        (data['trackingMode'] as String?)?.toLowerCase() ??
        (data['tracking_mode'] as String?)?.toLowerCase() ??
        'manual';
    final rating = (data['ratingAverage'] as num?)?.toDouble() ?? 0.0;

    if (_selectedSportFilter != 'all' && sport != _selectedSportFilter)
      return false;
    if (_selectedTrackingFilter != 'all' && tracking != _selectedTrackingFilter)
      return false;
    if (rating < _selectedMinRatingFilter) return false;
    return true;
  }

  Map<String, dynamic> _mapCachedRow(Map<String, Object?> row) {
    return {
      'id': row['id']?.toString(),
      'title': row['title']?.toString() ?? 'Challenge',
      'sport': row['sport']?.toString() ?? 'general',
      'progress': (row['progress'] as num?)?.toDouble() ?? 0.0,
      'participantsCount': (row['participants_count'] as num?)?.toInt() ?? 0,
      'ratingAverage': (row['rating_average'] as num?)?.toDouble() ?? 0.0,
      'trackingMode': row['tracking_mode']?.toString() ?? 'manual',
      'endDate': row['end_date'] != null
          ? DateTime.tryParse(row['end_date'] as String)
          : null,
      'isSynced': (row['is_synced'] as int?) == 1,
    };
  }

  void _cacheLiveChallenges(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    // Update a lightweight local cache used for offline view reconstruction.
    final mapped = docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'title': (data['title'] as String?) ?? data['goalLabel'] ?? 'Challenge',
        'sport': (data['sport'] as String?) ?? 'general',
        'progress':
            (data['progressByUser']?[widget.profile.uid] as num?)?.toDouble() ??
            0.0,
        'participantsCount':
            (data['participantsCount'] as num?)?.toInt() ??
            (data['participants'] is List
                ? (data['participants'] as List).length
                : 0),
        'ratingAverage': (data['ratingAverage'] as num?)?.toDouble() ?? 0.0,
        'trackingMode': (data['trackingMode'] as String?) ?? 'manual',
        'endDate': (data['endDate'] as Timestamp?)?.toDate()?.toIso8601String(),
        'isSynced': true,
      };
    }).toList();

    _cachedChallengeRows = mapped;
    // Persist a copy for offline use (fire-and-forget)
    _localStorageService.cacheChallengeCatalogFromFirestore(docs).ignore();
  }

  Future<void> _loadCachedChallenges() async {
    setState(() => _isLoadingCachedChallenges = true);
    try {
      final rows = await _localStorageService
          .loadChallengeSnapshotsFromSqlite();
      _cachedChallengeRows = rows.map((r) => _mapCachedRow(r)).toList();
    } catch (_) {
      _cachedChallengeRows = [];
    } finally {
      if (mounted) setState(() => _isLoadingCachedChallenges = false);
    }
  }

  Future<void> _retryConnectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOffline = _isOfflineResult(connectivity);
      });
    }
  }

  bool _shouldTrackStepsByDefault({
    String? sport,
    String? goalText,
    String? descriptionText,
  }) {
    final s = (sport ?? '').toLowerCase();
    if (s.contains('run') || s == 'running') return true;
    return false;
  }

  Widget _buildChallengeFilters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All sports'),
              selected: _selectedSportFilter == 'all',
              onSelected: (_) => setState(() => _selectedSportFilter = 'all'),
            ),
            ChoiceChip(
              label: const Text('Running'),
              selected: _selectedSportFilter == 'running',
              onSelected: (_) =>
                  setState(() => _selectedSportFilter = 'running'),
            ),
            ChoiceChip(
              label: const Text('Soccer'),
              selected: _selectedSportFilter == 'soccer',
              onSelected: (_) =>
                  setState(() => _selectedSportFilter = 'soccer'),
            ),
            ChoiceChip(
              label: const Text('Calisthenics'),
              selected: _selectedSportFilter == 'calistenia',
              onSelected: (_) =>
                  setState(() => _selectedSportFilter = 'calistenia'),
            ),
            ChoiceChip(
              label: const Text('Tennis'),
              selected: _selectedSportFilter == 'tennis',
              onSelected: (_) =>
                  setState(() => _selectedSportFilter = 'tennis'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All modes'),
              selected: _selectedTrackingFilter == 'all',
              onSelected: (_) =>
                  setState(() => _selectedTrackingFilter = 'all'),
            ),
            ChoiceChip(
              label: const Text('Manual'),
              selected: _selectedTrackingFilter == 'manual',
              onSelected: (_) =>
                  setState(() => _selectedTrackingFilter = 'manual'),
            ),
            ChoiceChip(
              label: const Text('Steps'),
              selected: _selectedTrackingFilter == 'steps',
              onSelected: (_) =>
                  setState(() => _selectedTrackingFilter = 'steps'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Rating',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            for (final rating in _ratingFilterOptions)
              ChoiceChip(
                label: Text(
                  rating == 0 ? 'Any' : '${rating.toStringAsFixed(0)}+',
                ),
                selected: _selectedMinRatingFilter == rating,
                onSelected: (_) =>
                    setState(() => _selectedMinRatingFilter = rating),
              ),
            TextButton.icon(
              onPressed: _resetChallengeFilters,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUnifiedChallengeList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> liveDocs,
  ) {
    final filteredDocs = liveDocs
        .where((doc) => _matchesChallengeFilters(doc.data()))
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        await _retryConnectivity();
        await _loadCachedChallenges();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isOffline) ...[_OfflineConnectionBanner()],
          _buildChallengeFilters(context),
          const SizedBox(height: 16),
          if (filteredDocs.isEmpty)
            const _InfoBox(text: 'No challenges match these filters.')
          else
            ...filteredDocs.map(
              (doc) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ChallengeCard(
                  challengeDoc: doc,
                  userId: widget.profile.uid,
                  stepSensorService: _stepSensorService,
                  ttlImageCache: _ttlImageCache,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Retos')),
      floatingActionButton: FloatingActionButton(
        onPressed: _isCreatingChallenge
            ? null
            : () => _createChallengeSimple(context),
        child: const Icon(Icons.add),
      ),
      body: _isCheckingConnectivity
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _challengesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  if (_cachedChallengeRows.isNotEmpty) {
                    return _buildUnifiedChallengeList(
                      snapshot.data?.docs ?? widget.challengeDocs,
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                }

                if (_isOffline && _cachedChallengeRows.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [_InfoBox(text: 'Sin conexión')],
                  );
                }

                if (snapshot.hasError && _cachedChallengeRows.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _InfoBox(
                        text:
                            'Could not load challenges. Check your connection.',
                      ),
                    ],
                  );
                }

                final docs = snapshot.data?.docs ?? widget.challengeDocs;

                if (docs.isNotEmpty) {
                  _cacheLiveChallenges(docs);
                }

                if (docs.isEmpty && _cachedChallengeRows.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      _InfoBox(text: 'No challenges available yet.'),
                    ],
                  );
                }

                return _buildUnifiedChallengeList(docs);
              },
            ),
    );
  }

  Future<void> _createChallengeSimple(BuildContext context) async {
    final titleController = TextEditingController();
    final goalController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedSport = 'running';
    bool useStepTracking = false;

    await showDialog<void>(
      context: context,
      builder: (dctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Crear reto (offline-first)'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        maxLength: AppFieldLimits.challengeTitle,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            AppFieldLimits.challengeTitle,
                          ),
                        ],
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'El nombre es obligatorio';
                          if (value.length <
                              AppValidationRules.challengeTitleMinLength) {
                            return 'Nombre muy corto';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: goalController,
                        maxLength: AppFieldLimits.challengeGoal,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            AppFieldLimits.challengeGoal,
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Info del reto',
                          hintText: 'Qué se debe lograr',
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty)
                            return 'La info del reto es obligatoria';
                          if (value.length <
                              AppValidationRules.challengeGoalMinLength) {
                            return 'La info del reto es muy corta';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: descriptionController,
                        maxLength: AppFieldLimits.challengeDescription,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            AppFieldLimits.challengeDescription,
                          ),
                        ],
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                          hintText: 'Describe reglas o contexto del reto',
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty)
                            return 'La descripción es obligatoria';
                          if (value.length <
                              AppValidationRules
                                  .challengeDescriptionMinLength) {
                            return 'La descripción es muy corta';
                          }
                          return null;
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSport,
                        decoration: const InputDecoration(labelText: 'Deporte'),
                        items: const [
                          DropdownMenuItem(
                            value: 'running',
                            child: Text('Running'),
                          ),
                          DropdownMenuItem(
                            value: 'soccer',
                            child: Text('Soccer'),
                          ),
                          DropdownMenuItem(
                            value: 'calistenia',
                            child: Text('Calisthenics'),
                          ),
                          DropdownMenuItem(
                            value: 'tennis',
                            child: Text('Tennis'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => selectedSport = value);
                        },
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Usar sensor de pasos'),
                        subtitle: Text(
                          useStepTracking
                              ? 'Este reto sincronizará progreso con pasos.'
                              : 'El progreso se actualizará manualmente.',
                        ),
                        value: useStepTracking,
                        onChanged: (value) {
                          setDialogState(() => useStepTracking = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(dctx).pop();
                    setState(() => _isCreatingChallenge = true);
                    try {
                      await _challengeRepository.createChallengeLocalFirst(
                        title: titleController.text.trim(),
                        sport: selectedSport,
                        description: descriptionController.text.trim(),
                        goal: goalController.text.trim(),
                        endDate: DateTime.now().add(const Duration(days: 30)),
                        createdBy: widget.profile.uid,
                        useStepTracking: useStepTracking,
                        stepGoal: useStepTracking ? _defaultStepGoal : null,
                        difficulty: null,
                        reward: null,
                      );
                      await _loadCachedChallenges();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Reto creado localmente y encolado para sincronización.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    } finally {
                      if (mounted) setState(() => _isCreatingChallenge = false);
                    }
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    goalController.dispose();
    descriptionController.dispose();
  }
}

class _TtlCachedReviewImage extends StatefulWidget {
  const _TtlCachedReviewImage({required this.imageUrl, required this.cache});

  final String imageUrl;
  final TtlImageCacheService cache;

  @override
  State<_TtlCachedReviewImage> createState() => _TtlCachedReviewImageState();
}

class _TtlCachedReviewImageState extends State<_TtlCachedReviewImage> {
  Uint8List? imageBytes;
  bool isLoading = false;
  bool hasFailed = false;

  @override
  void initState() {
    super.initState();
    _bootstrapImage();
  }

  @override
  void didUpdateWidget(covariant _TtlCachedReviewImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      imageBytes = null;
      hasFailed = false;
      _bootstrapImage();
    }
  }

  Future<void> _bootstrapImage() async {
    final cachedBytes = widget.cache.get(widget.imageUrl);
    if (cachedBytes != null) {
      if (!mounted) return;
      setState(() {
        imageBytes = cachedBytes;
        isLoading = false;
        hasFailed = false;
      });
      return;
    }

    if (isLoading) return;

    setState(() {
      isLoading = true;
      hasFailed = false;
    });

    try {
      final data = await NetworkAssetBundle(
        Uri.parse(widget.imageUrl),
      ).load(widget.imageUrl);
      final bytes = data.buffer.asUint8List();
      widget.cache.put(widget.imageUrl, bytes);

      if (!mounted) return;
      setState(() {
        imageBytes = bytes;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        hasFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    if (imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          imageBytes!,
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }

    if (isLoading || !hasFailed) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          widget.imageUrl,
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              height: 120,
              child: ColoredBox(
                color: surfaceColor,
                child: const Center(child: CircularProgressIndicator()),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return SizedBox(
              height: 120,
              child: ColoredBox(
                color: surfaceColor,
                child: const Center(child: Icon(Icons.broken_image_outlined)),
              ),
            );
          },
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 120,
        color: surfaceColor,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

class _ChallengeCard extends StatefulWidget {
  const _ChallengeCard({
    required this.challengeDoc,
    required this.userId,
    required this.stepSensorService,
    required this.ttlImageCache,
    this.isRecommended = false,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> challengeDoc;
  final String userId;
  final StepSensorService stepSensorService;
  final TtlImageCacheService ttlImageCache;
  final bool isRecommended;

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncEngineService _syncEngine = SyncEngineService();
  bool _loading = false;
  bool _progressUpdating = false;
  bool _loadingDeviceSteps = false;
  int? _deviceSteps;

  @override
  void initState() {
    super.initState();
    _refreshDeviceSteps();
  }

  Future<void> _refreshDeviceSteps() async {
    final data = widget.challengeDoc.data();
    if (!_isStepTrackingMode(data)) return;

    if (mounted) {
      setState(() {
        _loadingDeviceSteps = true;
      });
    }

    final steps = await widget.stepSensorService.getCurrentTotalSteps();
    if (!mounted) return;
    setState(() {
      _deviceSteps = steps;
      _loadingDeviceSteps = false;
    });
  }

  bool _isStepTrackingMode(Map<String, dynamic> data) {
    final trackingMode = (data['trackingMode'] as String?)?.toLowerCase();
    return trackingMode == 'steps';
  }

  /// Devuelve el color de acento del deporte usado en chips, icono y progreso.
  Color _accentForSport(String sport) {
    switch (sport.toLowerCase()) {
      case 'running':
        return const Color(0xFF2E7DFA);
      case 'futbol':
      case 'soccer':
      case 'football':
        return const Color(0xFF2EAD67);
      case 'calistenia':
        return const Color(0xFFE88A1A);
      case 'tennis':
      case 'tenis':
        return const Color(0xFFD2B125);
      default:
        return const Color(0xFF0C8E8B);
    }
  }

  /// Convierte la clave cruda del deporte en una etiqueta legible para la UI.
  String _sportLabel(String sport) {
    switch (sport.toLowerCase()) {
      case 'futbol':
      case 'soccer':
      case 'football':
        return 'Soccer';
      case 'running':
        return 'Running';
      case 'calistenia':
        return 'Calisthenics';
      case 'tennis':
      case 'tenis':
        return 'Tennis';
      default:
        return sport.trim().isEmpty ? 'General' : sport;
    }
  }

  /// Selecciona un icono según el deporte para distinguir visualmente cada reto.
  IconData _iconForSport(String sport) {
    switch (sport.toLowerCase()) {
      case 'running':
        return Icons.directions_run;
      case 'futbol':
      case 'soccer':
      case 'football':
        return Icons.sports_soccer;
      case 'calistenia':
        return Icons.fitness_center;
      case 'tennis':
      case 'tenis':
        return Icons.sports_tennis;
      default:
        return Icons.emoji_events;
    }
  }

  /// Calcula la etiqueta del tiempo restante a partir de la fecha de fin del reto.
  String _daysLeft(DateTime? endDate) {
    if (endDate == null) return 'No end date';

    final now = DateTime.now();
    final left = endDate.difference(now).inDays;
    if (left < 0) return 'Completed';
    if (left == 0) return 'Ends today';
    if (left == 1) return '1 day left';
    return '$left days left';
  }

  bool _isChallengeFinishedForUser({
    required bool isJoined,
    required double progress,
    required DateTime? endDate,
  }) {
    if (!isJoined) return false;
    if (progress >= 1.0) return true;
    if (endDate == null) return false;
    return endDate.isBefore(DateTime.now());
  }

  Future<void> _openReviewDialog(String title) async {
    if (!mounted) return;

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return ChallengeReviewDialog(
          challengeId: widget.challengeDoc.id,
          challengeTitle: title,
        );
      },
    );
  }

  Widget _buildRatingSummary({
    required BuildContext context,
    required double ratingAverage,
    required int ratingCount,
    Color? color,
  }) {
    final themedColor = color ?? Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Icon(Icons.star, size: 18, color: Colors.amber[700]),
        const SizedBox(width: 4),
        Text(
          ratingCount > 0
              ? '${ratingAverage.toStringAsFixed(1)} ($ratingCount)'
              : 'No ratings yet',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: themedColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  /// Abre una hoja inferior con detalles extendidos y metadatos del reto.
  Future<void> _openChallengeDetails(
    Map<String, dynamic> data, {
    required bool canReview,
    required String challengeTitle,
  }) async {
    final title = (data['title'] as String?)?.trim().isNotEmpty == true
        ? data['title'] as String
        : ((data['goalLabel'] as String?)?.trim().isNotEmpty == true
              ? data['goalLabel'] as String
              : 'Challenge');

    final description = (data['description'] as String?)?.trim();
    final goalLabel = (data['goalLabel'] as String?)?.trim();
    final reward = (data['reward'] as String?)?.trim();
    final difficulty = (data['difficulty'] as String?)?.trim();
    final trackingMode = (data['trackingMode'] as String?)?.toLowerCase();
    final stepGoal = (data['stepGoal'] as num?)?.toInt();
    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    final sport = (data['sport'] as String?) ?? '';
    final ratingAverage = (data['ratingAverage'] as num?)?.toDouble() ?? 0.0;
    final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
    final reviewsFuture = FirebaseFirestore.instance
        .collection('challenges')
        .doc(widget.challengeDoc.id)
        .collection('reviews')
        .orderBy('updatedAt', descending: true)
        .limit(8)
        .get();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_iconForSport(sport), color: _accentForSport(sport)),
                      const SizedBox(width: 8),
                      Text(
                        _sportLabel(sport),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _daysLeft(endDate),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildRatingSummary(
                    context: context,
                    ratingAverage: ratingAverage,
                    ratingCount: ratingCount,
                  ),
                  if (difficulty != null && difficulty.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Difficulty: $difficulty',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (trackingMode == 'steps') ...[
                    const SizedBox(height: 6),
                    Text(
                      stepGoal == null
                          ? 'Tracking: Step sensor'
                          : 'Tracking: Step sensor ($stepGoal steps goal)',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (description != null && description.isNotEmpty)
                        ? description
                        : 'This challenge does not have a detailed description yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (goalLabel != null && goalLabel.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Goal',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      goalLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (reward != null && reward.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Reward',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(reward, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  if (canReview) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _openReviewDialog(challengeTitle);
                        },
                        icon: const Icon(Icons.rate_review),
                        label: const Text('Rate and review this challenge'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Reviews',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    future: reviewsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }

                      final docs =
                          snapshot.data?.docs ??
                          const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                      if (docs.isEmpty) {
                        return Text(
                          'No reviews yet. Be the first to rate this challenge.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        );
                      }

                      return Column(
                        children: docs.map((doc) {
                          final review = doc.data();
                          final userName =
                              (review['userName'] as String?)
                                      ?.trim()
                                      .isNotEmpty ==
                                  true
                              ? review['userName'] as String
                              : 'Anonymous';
                          final comment =
                              (review['comment'] as String?)?.trim() ?? '';
                          final imageUrl = (review['imageUrl'] as String?)
                              ?.trim();
                          final rating =
                              ((review['rating'] as num?)?.toInt() ?? 0).clamp(
                                0,
                                5,
                              );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        userName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    Row(
                                      children: List.generate(5, (index) {
                                        return Icon(
                                          Icons.star,
                                          size: 16,
                                          color: rating > index
                                              ? Colors.amber[700]
                                              : Colors.grey[400],
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                                if (comment.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    comment,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                                if (imageUrl != null &&
                                    imageUrl.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _TtlCachedReviewImage(
                                    imageUrl: imageUrl,
                                    cache: widget.ttlImageCache,
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Actualiza el progreso del usuario en el reto con garantía transaccional.
  ///
  /// [delta] es la cantidad que se suma al progreso actual (por ejemplo, 0.05 para +5%).
  /// El progreso se ajusta automáticamente al rango [0, 1].
  Future<void> _updateProgress(double delta) async {
    if (_progressUpdating || !mounted) return;

    setState(() => _progressUpdating = true);

    try {
      final challengeRef = FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeDoc.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(challengeRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final progressByUser = Map<String, dynamic>.from(
          data['progressByUser'] ?? const {},
        );

        // Calcula el nuevo progreso basado en el delta proporcionado.
        final currentProgress =
            (progressByUser[widget.userId] as num?)?.toDouble() ?? 0.0;
        final newProgress = (currentProgress + delta).clamp(0.0, 1.0);

        // Actualiza solo el progreso del usuario en esta transacción.
        transaction.update(challengeRef, {
          'progressByUser.${widget.userId}': newProgress,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update progress.')),
      );
    } finally {
      if (mounted) {
        setState(() => _progressUpdating = false);
      }
    }
  }

  /// Sincroniza el progreso del reto usando los pasos actuales del dispositivo.
  ///
  /// Flujo:
  /// 1) Leer los pasos acumulados actuales del dispositivo.
  /// 2) Calcular el delta desde la última sincronización del usuario para este reto.
  /// 3) Convertir los pasos acumulados en porcentaje de avance según `stepGoal`.
  Future<void> _syncProgressFromSensor() async {
    if (_progressUpdating || !mounted) return;

    setState(() => _progressUpdating = true);

    try {
      final currentSteps = await widget.stepSensorService
          .getCurrentTotalSteps();
      if (currentSteps == null) {
        final lastError = widget.stepSensorService.lastError;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lastError == null
                  ? 'Could not read step sensor. Walk a few steps and sync again.'
                  : 'Could not read step sensor. Check permission settings and try again.',
            ),
          ),
        );
        return;
      }

      final challengeRef = FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeDoc.id);

      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          !connectivity.contains(ConnectivityResult.none);

      if (!isOnline) {
        await _dbHelper.insert('sync_queue', {
          'event_id': widget.challengeDoc.id,
          'action': 'sync_challenge_steps',
          'payload': jsonEncode({
            'userId': widget.userId,
            'currentSteps': currentSteps,
            'queuedAt': DateTime.now().toIso8601String(),
          }),
          'status': 'pending',
          'retry_count': 0,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        Future.microtask(() => _syncEngine.processQueue());

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Step progress saved offline. It will sync when connectivity returns.',
            ),
          ),
        );
        return;
      }

      var firstCalibration = false;
      var syncedSteps = 0;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(challengeRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final stepGoal = (data['stepGoal'] as num?)?.toInt() ?? 8000;
        final stepProgressByUser = Map<String, dynamic>.from(
          data['stepProgressByUser'] ?? const {},
        );
        final stepSensorBaselineByUser = Map<String, dynamic>.from(
          data['stepSensorBaselineByUser'] ?? const {},
        );

        final previousSensorSteps =
            (stepSensorBaselineByUser[widget.userId] as num?)?.toInt() ?? 0;
        final currentTrackedSteps =
            (stepProgressByUser[widget.userId] as num?)?.toInt() ?? 0;

        final hasNoBaselineYet =
            previousSensorSteps == 0 && currentTrackedSteps == 0;
        firstCalibration = hasNoBaselineYet;
        final sensorDelta = hasNoBaselineYet
            ? 0
            : (currentSteps - previousSensorSteps).clamp(0, 1000000);
        syncedSteps = sensorDelta;
        final updatedTrackedSteps = currentTrackedSteps + sensorDelta;
        final updatedProgress = (updatedTrackedSteps / stepGoal).clamp(
          0.0,
          1.0,
        );

        transaction.update(challengeRef, {
          'stepProgressByUser.${widget.userId}': updatedTrackedSteps,
          'stepSensorBaselineByUser.${widget.userId}': currentSteps,
          'progressByUser.${widget.userId}': updatedProgress,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      if (firstCalibration) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Step sensor calibrated. Walk a bit and sync again to see progress.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncedSteps > 0
                  ? 'Progress synced (+$syncedSteps steps).'
                  : 'No new steps detected since your last sync.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sync progress from steps.')),
      );
    } finally {
      if (mounted) {
        setState(() => _progressUpdating = false);
      }
      _refreshDeviceSteps();
    }
  }

  /// Se une o abandona el reto dentro de una transacción de Firestore.
  ///
  /// La transacción garantiza que el contador de participantes y el progreso por usuario se mantengan sincronizados.
  Future<void> _toggleParticipation() async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      final snapshotData = widget.challengeDoc.data();
      final isStepTracking = _isStepTrackingMode(snapshotData);
      final baselineSteps = isStepTracking
          ? await widget.stepSensorService.getCurrentTotalSteps()
          : null;

      final challengeRef = FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeDoc.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(challengeRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final participants = List<String>.from(
          data['participants'] ?? const [],
        );
        final joined = participants.contains(widget.userId);

        if (joined) {
          transaction.update(challengeRef, {
            'participants': FieldValue.arrayRemove([widget.userId]),
            'participantsCount': FieldValue.increment(-1),
            'progressByUser.${widget.userId}': FieldValue.delete(),
            'stepProgressByUser.${widget.userId}': FieldValue.delete(),
            'stepSensorBaselineByUser.${widget.userId}': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(challengeRef, {
            'participants': FieldValue.arrayUnion([widget.userId]),
            'participantsCount': FieldValue.increment(1),
            'progressByUser.${widget.userId}': 0,
            'stepProgressByUser.${widget.userId}': 0,
            if (baselineSteps != null)
              'stepSensorBaselineByUser.${widget.userId}': baselineSteps,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update your participation.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Renderiza una tarjeta de reto con progreso, participantes y estado de llamada a la acción.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = widget.challengeDoc.data();

    final title = (data['title'] as String?)?.trim().isNotEmpty == true
        ? data['title'] as String
        : ((data['goalLabel'] as String?)?.trim().isNotEmpty == true
              ? data['goalLabel'] as String
              : 'Challenge');

    final participants = List<String>.from(data['participants'] ?? const []);
    final progressByUser = Map<String, dynamic>.from(
      data['progressByUser'] ?? const {},
    );
    final isJoined = participants.contains(widget.userId);
    final isStepTracking = _isStepTrackingMode(data);
    final stepGoal = (data['stepGoal'] as num?)?.toInt() ?? 0;
    final stepProgressByUser = Map<String, dynamic>.from(
      data['stepProgressByUser'] ?? const {},
    );
    final trackedSteps =
        (stepProgressByUser[widget.userId] as num?)?.toInt() ?? 0;

    final rawUserProgress = progressByUser[widget.userId];
    final userProgress = (rawUserProgress is num)
        ? rawUserProgress.toDouble()
        : 0.0;
    final clampedProgress = userProgress.clamp(0.0, 1.0);
    final ratingAverage = (data['ratingAverage'] as num?)?.toDouble() ?? 0.0;
    final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;

    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    const canReview = true;
    final sport = (data['sport'] as String?) ?? '';
    final accent = _accentForSport(sport);
    final participantsCount =
        (data['participantsCount'] as num?)?.toInt() ?? participants.length;

    // Colores dinámicos para modo oscuro
    final gradientStartColor = accent.withValues(alpha: isDark ? 0.08 : 0.10);
    final gradientEndColor = isDark
        ? Theme.of(context).colorScheme.surface
        : Colors.white;
    final borderColor = accent.withValues(alpha: isDark ? 0.25 : 0.30);
    final shadowColor = accent.withValues(alpha: isDark ? 0.15 : 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openChallengeDetails(
          data,
          canReview: canReview,
          challengeTitle: title,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [gradientStartColor, gradientEndColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _sportLabel(sport),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.isRecommended)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1C7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'RECOMMENDED',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF8A6B00),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (isJoined)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBF4E6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'JOINED',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF1F8F52),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    child: Icon(_iconForSport(sport), color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _daysLeft(endDate),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        _buildRatingSummary(
                          context: context,
                          ratingAverage: ratingAverage,
                          ratingCount: ratingCount,
                          color: Colors.grey[700],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(clampedProgress * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isJoined)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: clampedProgress,
                              minHeight: 12,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(accent),
                            ),
                          ),
                        ),
                        if (isStepTracking) ...[
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _progressUpdating
                                ? null
                                : _syncProgressFromSensor,
                            icon: const Icon(Icons.sensors),
                            label: const Text('Sync steps'),
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            onPressed: _progressUpdating
                                ? null
                                : () => _updateProgress(-0.05),
                            icon: const Icon(Icons.remove),
                            label: const Text('-5%'),
                          ),
                          const SizedBox(width: 6),
                          FilledButton.icon(
                            onPressed: _progressUpdating
                                ? null
                                : () => _updateProgress(0.05),
                            icon: const Icon(Icons.add),
                            label: const Text('+5%'),
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        _progressUpdating
                            ? 'Updating progress...'
                            : isStepTracking
                            ? 'Use Sync steps to update from your device sensor (${stepGoal > 0 ? '$trackedSteps/$stepGoal' : '$trackedSteps'}).'
                            : 'Use - and + buttons to update progress',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isStepTracking) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.directions_walk, size: 16, color: accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _loadingDeviceSteps
                                  ? 'Leyendo pasos del dispositivo...'
                                  : (_deviceSteps == null
                                        ? 'No se pudieron leer pasos del dispositivo.'
                                        : 'Pasos actuales del dispositivo: $_deviceSteps (disponible también offline)'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Actualizar pasos',
                            onPressed: _loadingDeviceSteps
                                ? null
                                : _refreshDeviceSteps,
                            icon: const Icon(Icons.refresh, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ],
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: clampedProgress,
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.groups_2_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$participantsCount participants',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _daysLeft(endDate),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _toggleParticipation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isJoined ? Colors.red[400] : accent,
                    minimumSize: const Size(0, 44),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isJoined ? 'Leave challenge' : 'Join challenge'),
                ),
              ),
              if (canReview) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openReviewDialog(title),
                    icon: const Icon(Icons.rate_review),
                    label: const Text('Rate challenge'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Caja informativa neutra que se muestra en estados de carga, error o vacío.
class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});

  final String text;

  /// Renderiza un contenedor de mensaje con énfasis sutil en el fondo.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}

/// Widget banner que indica que no hay conexión disponible.
class _OfflineConnectionBanner extends StatelessWidget {
  const _OfflineConnectionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3B341)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Color(0xFF8A5A00)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No hay conexión. Los cambios se sincronizarán cuando vuelva internet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6B4700),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget banner que muestra el resultado de la recomendación inteligente.
class _ChallengeRecommendationBox extends StatelessWidget {
  final ChallengeRecommendation recommendation;

  const _ChallengeRecommendationBox({required this.recommendation});

  /// Renderiza el título y la explicación de la recomendación.
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: colorScheme.onSecondaryContainer),
              const SizedBox(width: 8),
              Text(
                'Smart recommendation',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Start with "${recommendation.title}" (${recommendation.sportLabel}).',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'We suggest it because ${recommendation.reason}.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopRatedChallengesSection extends StatelessWidget {
  const _TopRatedChallengesSection({required this.challengeDocs});
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> challengeDocs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8D9A8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, color: Color(0xFF8A6B00)),
              const SizedBox(width: 8),
              Text(
                'Top rated challenges',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF6B5100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: challengeDocs.map((doc) {
                final data = doc.data();
                final title =
                    (data['title'] as String?)?.trim().isNotEmpty == true
                    ? data['title'] as String
                    : ((data['goalLabel'] as String?)?.trim().isNotEmpty == true
                          ? data['goalLabel'] as String
                          : 'Challenge');
                final sport = ((data['sport'] as String?) ?? '').trim();
                final ratingAverage =
                    (data['ratingAverage'] as num?)?.toDouble() ?? 0.0;
                final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;

                return Container(
                  width: 190,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE7DFC8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sport.isEmpty ? 'General' : sport,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            ratingCount > 0
                                ? '${ratingAverage.toStringAsFixed(1)} ($ratingCount)'
                                : 'No ratings',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel de acciones para la vista protegida sin conexión.
class _OfflineRetosActionPanel extends StatelessWidget {
  const _OfflineRetosActionPanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No cached challenges yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'If you open this tab with a connection at least once, the app will store the challenges in SQLite so you can browse them later without internet.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta sin conexión que muestra el contenido cacheado del reto.
class _OfflineChallengeCard extends StatelessWidget {
  const _OfflineChallengeCard({
    required this.challenge,
    required this.onSaveLocal,
    required this.onOpenDetails,
  });

  final Map<String, dynamic> challenge;
  final VoidCallback onSaveLocal;
  final VoidCallback onOpenDetails;

  Color _accentForSport(String sport) {
    switch (sport.toLowerCase()) {
      case 'running':
        return const Color(0xFF2E7DFA);
      case 'futbol':
      case 'soccer':
      case 'football':
        return const Color(0xFF2EAD67);
      case 'calistenia':
        return const Color(0xFFE88A1A);
      case 'tennis':
      case 'tenis':
        return const Color(0xFFD2B125);
      default:
        return const Color(0xFF0C8E8B);
    }
  }

  String _sportLabel(String sport) {
    switch (sport.toLowerCase()) {
      case 'futbol':
      case 'soccer':
      case 'football':
        return 'Soccer';
      case 'running':
        return 'Running';
      case 'calistenia':
        return 'Calisthenics';
      case 'tennis':
      case 'tenis':
        return 'Tennis';
      default:
        return sport.trim().isEmpty ? 'General' : sport;
    }
  }

  IconData _iconForSport(String sport) {
    switch (sport.toLowerCase()) {
      case 'running':
        return Icons.directions_run;
      case 'futbol':
      case 'soccer':
      case 'football':
        return Icons.sports_soccer;
      case 'calistenia':
        return Icons.fitness_center;
      case 'tennis':
      case 'tenis':
        return Icons.sports_tennis;
      default:
        return Icons.emoji_events;
    }
  }

  /// Construye un chip visual para indicar si el reto local ya fue sincronizado.
  Widget _buildSyncStatusChip(BuildContext context, bool isSynced) {
    final chipColor = isSynced
        ? const Color(0xFF1F8F45)
        : const Color(0xFFD97706);
    final icon = isSynced ? Icons.cloud_done : Icons.cloud_upload;
    final label = isSynced ? 'Synced' : 'Pending sync';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: chipColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sport = challenge['sport']?.toString() ?? 'general';
    final accent = _accentForSport(sport);
    final progress = (challenge['progress'] as num?)?.toDouble() ?? 0.0;
    final participantsCount =
        (challenge['participantsCount'] as num?)?.toInt() ?? 0;
    final ratingAverage =
        (challenge['ratingAverage'] as num?)?.toDouble() ?? 0.0;
    final trackingMode = challenge['trackingMode']?.toString() ?? 'manual';
    final isSynced = challenge['isSynced'] == true;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withValues(alpha: 0.10), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _sportLabel(sport),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                _buildSyncStatusChip(context, isSynced),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: accent.withValues(alpha: 0.15),
                  child: Icon(_iconForSport(sport), color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge['title']?.toString() ?? 'Challenge',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mode: $trackingMode',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.groups_2_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  '$participantsCount participants',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber[700]),
                    const SizedBox(width: 4),
                    Text(
                      ratingAverage > 0
                          ? ratingAverage.toStringAsFixed(1)
                          : 'No rating',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenDetails,
                    icon: const Icon(Icons.visibility),
                    label: const Text('View details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSaveLocal,
                    icon: const Icon(Icons.save),
                    label: const Text('Save locally'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
