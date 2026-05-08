import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uniandessport_flutter/core/network/analytics_service.dart';
import 'package:uniandessport_flutter/features/coach/services/coach_cache_service.dart';
import 'package:uniandessport_flutter/core/utils/pending_reviews_service.dart';
import 'package:uniandessport_flutter/features/coach/models/coach_model.dart';
import 'package:uniandessport_flutter/features/coach/services/coach_repository.dart';

class CoachesViewModel extends ChangeNotifier {
  final CoachRepository _repository;

  List<Coach> _allCoaches = [];
  List<Coach> _filteredCoaches = [];
  bool _isLoading = false;
  String? _error;
  String _selectedSport = "All Coaches";
  String _searchQuery = "";
  Coach? _coachOfTheMonth;
  bool _isOffline = false;
  int _pendingReviewsCount = 0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final CoachCacheService _cacheService = CoachCacheService.instance;

  // Filtros avanzados
  double _minRating = 1;
  double _maxPrice = 50;
  bool _onlyVerified = false;

  List<Coach> get coaches => _filteredCoaches;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedSport => _selectedSport;
  Coach? get coachOfTheMonth => _coachOfTheMonth;
  bool get isOffline => _isOffline;
  double get minRating => _minRating;
  double get maxPrice => _maxPrice;
  bool get onlyVerified => _onlyVerified;
  bool get hasActiveFilters =>
      _minRating > 1 || _maxPrice < 50 || _onlyVerified;
  int get pendingReviewsCount => _pendingReviewsCount;

  CoachesViewModel(this._repository) {
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      final wasOffline = _isOffline;
      final newIsOffline = results.every((r) => r == ConnectivityResult.none);

      // Solo actuar si el estado realmente cambió
      if (newIsOffline == wasOffline) return;

      _isOffline = newIsOffline;
      notifyListeners();

      // Si acaba de recuperar conexión, sincronizar reviews pendientes.
      // Marcamos el instante de reconexión ANTES de sincronizar para que
      // el servicio pueda calcular el delta por review (BQ #2).
      if (wasOffline && !_isOffline) {
        await PendingReviewsService.instance.notifyReconnect();
        await _syncPendingReviews();
      }
    });
  }

  Future<void> _syncPendingReviews() async {
    final synced = await PendingReviewsService.instance.syncToFirestore();
    if (synced > 0) {
      _pendingReviewsCount = 0;
      notifyListeners();
      await loadCoaches();
    }
  }

  Future<bool> checkIsOffline() async {
    final results = await Connectivity().checkConnectivity();
    _isOffline = results.every((r) => r == ConnectivityResult.none);
    return _isOffline;
  }

  void incrementPendingReviews() {
    _pendingReviewsCount++;
    notifyListeners();
  }

  /// Estrategia de caching #5 del libro: CACHE THEN NETWORK
  /// (stale-while-revalidate).
  ///
  /// Fase 1: si hay cache local válido (TTL no expirado), se muestra al
  /// instante para que la UI responda en 0ms aunque la red tarde.
  /// Fase 2: en paralelo se pide la versión fresca a Firestore. Cuando
  /// llega, sobrescribe la lista visible y se persiste al cache para la
  /// próxima apertura.
  Future<void> loadCoaches() async {
    _error = null;

    // ── Fase 1 — STALE: pinta cache si lo hay ──────────────────────────
    await _restoreCachedStateIfAvailable();
    final hadCachedData = _allCoaches.isNotEmpty;

    // Si había cache, oculta spinner; si no, mantiene el spinner de
    // primera carga para no dejar la pantalla vacía.
    _isLoading = !hadCachedData;
    notifyListeners();

    // ── Fase 2 — REVALIDATE: refresca contra Firestore ─────────────────
    try {
      _allCoaches = await _repository.getCoaches();
      _applyFilters();
      try {
        await loadCoachOfTheMonth();
      } catch (_) {
        // Si las queries de ranking fallan, conservamos el coach destacado
        // que vino del cache (si lo había) y seguimos.
      }
      await _cacheCurrentState();
    } catch (e) {
      // Si la red falla pero ya estábamos pintando cache, seguimos así.
      // Solo reportamos error si no había NADA para mostrar.
      if (_allCoaches.isEmpty) {
        _error = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCoachOfTheMonth() async {
    if (_allCoaches.isEmpty) return;

    final now = DateTime.now();
    final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);
    final lastDayOfCurrentMonth = DateTime(
      now.year,
      now.month + 1,
      0,
      23,
      59,
      59,
    );

    final validCoaches = _allCoaches.where((c) => c.id != null).toList();

    // ── Step 1 (main) — queries Firestore en paralelo ───────────────────
    // I/O bound: `await` libera el main thread durante la espera de red,
    // así que NO necesita isolate. Future.wait dispara N requests
    // concurrentemente.
    final futures = validCoaches.map((coach) {
      return FirebaseFirestore.instance
          .collection('profesores')
          .doc(coach.id)
          .collection('reviews')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfCurrentMonth),
          )
          .where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(lastDayOfCurrentMonth),
          )
          .get();
    }).toList();

    final snapshots = await Future.wait(futures);

    // ── Step 2 (main) — extraer datos serializables ─────────────────────
    // Los QuerySnapshot/DocumentSnapshot de Firestore tienen referencias
    // internas al cliente que NO son enviables a otro isolate. Por eso
    // colapsamos los datos relevantes en un List<Map> plano antes del
    // compute().
    final coachData = <Map<String, dynamic>>[];
    for (int i = 0; i < validCoaches.length; i++) {
      final coach = validCoaches[i];
      final reviews = snapshots[i].docs;
      final reviewCount = reviews.length.toDouble();

      double avgRating = 0;
      if (reviews.isNotEmpty) {
        final totalRating = reviews.fold<double>(
          0,
          (accumulator, doc) =>
              accumulator + ((doc.data()['rating'] as num?)?.toDouble() ?? 0),
        );
        avgRating = totalRating / reviews.length;
      }

      coachData.add({
        'coachId': coach.id!,
        'reviewCount': reviewCount,
        'avgRating': avgRating,
        'overallRating': (coach.rating ?? 0).toDouble(),
        'verified': coach.verified == true,
      });
    }

    // ── Step 3 (isolate) — scoring en thread paralelo ───────────────────
    // CPU bound: el algoritmo escala O(N) con coaches y O(M) con reviews
    // por coach, así que crece como N*M. Para catálogos grandes bloquearía
    // el main thread y causaría GUI lags. compute() lo mueve a un isolate
    // dedicado, dejando el main libre para pintar UI.
    final bestId = await compute(_scoreCoachesIsolate, coachData);

    // ── Step 4 (main) — mapear el id ganador a su Coach ─────────────────
    if (bestId != null) {
      _coachOfTheMonth = validCoaches.firstWhere(
        (c) => c.id == bestId,
        orElse: () => validCoaches.first,
      );
    }
  }

  /// Stores the latest successful coach snapshot for offline fallback.
  Future<void> _cacheCurrentState() async {
    await _cacheService.saveState(
      coaches: _allCoaches,
      coachOfTheMonth: _coachOfTheMonth,
    );
  }

  /// Restores the last successful coach snapshot when the network is absent.
  Future<void> _restoreCachedStateIfAvailable() async {
    final cachedCoaches = await _cacheService.loadCachedCoaches();
    if (cachedCoaches.isEmpty) {
      return;
    }

    _allCoaches = cachedCoaches;
    _filteredCoaches = List.from(cachedCoaches);
    _coachOfTheMonth = await _cacheService.loadCachedCoachOfTheMonth();
    _applyFilters();
    _error = null;
  }

  void applyAdvancedFilters({
    required double minRating,
    required double maxPrice,
    required bool onlyVerified,
  }) {
    _minRating = minRating;
    _maxPrice = maxPrice;
    _onlyVerified = onlyVerified;
    _applyFilters();
  }

  void resetAdvancedFilters() {
    _minRating = 1;
    _maxPrice = 50;
    _onlyVerified = false;
    _applyFilters();
  }

  void filterBySport(String sport) {
    _selectedSport = sport;
    _applyFilters();
    if (sport != "All Coaches") {
      AnalyticsService.instance.logSearchSportEvent(sportCategory: sport);
    }
  }

  void search(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void _applyFilters() {
    List<Coach> filtered = List.from(_allCoaches);

    if (_selectedSport != "All Coaches") {
      filtered = filtered
          .where((coach) => coach.deporte == _selectedSport)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (coach) =>
                coach.nombre?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false,
          )
          .toList();
    }

    // Filtro por rating mínimo. Los coaches sin reviews (totalReviews == 0)
    // NO se filtran por rating: rating 0 significa "sin calificar todavía",
    // no "mala calificación". Solo se aplica el umbral cuando ya hay reviews.
    filtered = filtered.where((coach) {
      final reviews = coach.totalReviews ?? 0;
      if (reviews == 0) return true;
      return (coach.rating ?? 0) >= _minRating;
    }).toList();

    // Filtro por precio máximo
    filtered = filtered.where((coach) {
      final priceStr = coach.precio ?? '';
      final numericPrice =
          double.tryParse(priceStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      return numericPrice <= _maxPrice;
    }).toList();

    // Filtro solo verificados
    if (_onlyVerified) {
      filtered = filtered.where((coach) => coach.verified == true).toList();
    }

    _filteredCoaches = filtered;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

/// Scoring algorithm para Coach of the Month, ejecutado en un isolate
/// separado vía `compute()`.
///
/// Top-level a propósito: `compute()` exige funciones top-level o
/// estáticas porque las funciones miembro de una clase capturan `this`
/// y los objetos con referencias no pueden serializarse para enviarse
/// entre isolates.
///
/// Fórmula de scoring (idéntica a la versión single-thread previa):
///   score = avgRating * 2
///         + reviewCount * 0.5
///         + overallRating * 1
///         + (verified ? 3 : 0)
///
/// Devuelve el `coachId` del coach con mayor score, o `null` si la
/// lista llega vacía.
String? _scoreCoachesIsolate(List<Map<String, dynamic>> coachData) {
  double bestScore = -1;
  String? bestId;

  for (final entry in coachData) {
    final reviewCount = (entry['reviewCount'] as num).toDouble();
    final avgRating = (entry['avgRating'] as num).toDouble();
    final overallRating = (entry['overallRating'] as num).toDouble();
    final verified = (entry['verified'] as bool) ? 3.0 : 0.0;

    final score = (avgRating * 2) +
        (reviewCount * 0.5) +
        (overallRating * 1) +
        verified;

    if (score > bestScore) {
      bestScore = score;
      bestId = entry['coachId'] as String;
    }
  }

  return bestId;
}
