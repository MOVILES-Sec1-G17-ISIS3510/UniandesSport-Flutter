import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_sports.dart';
import '../../auth/models/user_profile.dart';
import '../../../core/services/ttl_memory_cache_service.dart';

/// Motor de recomendaciones y ranking de retos.
///
/// Este módulo expone tipos ligeros (`ChallengeRecommendation`,
/// `ChallengeRankingInsights`) y la clase `ChallengeRecommendationEngine`
/// que encapsula la lógica para:
/// - Clasificar retos por relevancia para un usuario (`rankChallenges`).
/// - Seleccionar los retos mejor valorados (`topRatedChallenges`).
/// - Construir una recomendación simple que explique por qué un reto
///   es adecuado para el usuario (`buildRecommendation`).
///
/// Rendimiento y concurrencia:
/// - El cálculo pesado puede ejecutarse en un isolate con `compute()`
///   (función `_computeChallengeInsights`) para no bloquear la UI.
/// - Para evitar recalcular con frecuencia, se utiliza una caché en
///   memoria (`TtlMemoryCacheService`) con TTL y LRU. La clave de caché
///   incluye el `uid` del usuario, los ids de retos y el parámetro
///   `topRatedMaxResults`.

/// Resultado simple de recomendación para mostrar al usuario.
///
/// Contiene la referencia al reto recomendado (`challengeId`), un título
/// amigable (`title`), la etiqueta del deporte (`sportLabel`) y una
/// explicación breve (`reason`) que puede usarse en la UI para justificar
/// la recomendación.
class ChallengeRecommendation {
  final String challengeId;
  final String title;
  final String sportLabel;
  final String reason;

  const ChallengeRecommendation({
    required this.challengeId,
    required this.title,
    required this.sportLabel,
    required this.reason,
  });
}

/// Insights agregados tras computar el ranking de retos.
///
/// - `rankedIds`: lista de ids ordenada por relevancia.
/// - `topRatedIds`: sublista de ids con mejores valoraciones (útil para
///    secciones tipo "más valorados").
/// - `recommendation`: recomendación puntual con una explicación.
class ChallengeRankingInsights {
  final List<String> rankedIds;
  final List<String> topRatedIds;
  final ChallengeRecommendation? recommendation;

  const ChallengeRankingInsights({
    required this.rankedIds,
    required this.topRatedIds,
    required this.recommendation,
  });

  /// Construye un `ChallengeRankingInsights` a partir del `Map` que
  /// produce `_computeChallengeInsights` (o la versión en isolate).
  ///
  /// Esta fábrica hace las conversiones de tipos y aplica valores por
  /// defecto seguros si faltara algún campo.
  factory ChallengeRankingInsights.fromComputeResult(
    Map<String, dynamic> result,
  ) {
    final recommendationData =
        result['recommendation'] as Map<String, dynamic>?;

    return ChallengeRankingInsights(
      rankedIds: List<String>.from(result['rankedIds'] as List? ?? const []),
      topRatedIds: List<String>.from(
        result['topRatedIds'] as List? ?? const [],
      ),
      recommendation: recommendationData == null
          ? null
          : ChallengeRecommendation(
              challengeId: (recommendationData['challengeId'] as String?) ?? '',
              title: (recommendationData['title'] as String?) ?? 'Challenge',
              sportLabel:
                  (recommendationData['sportLabel'] as String?) ?? 'Challenge',
              reason: (recommendationData['reason'] as String?) ?? '',
            ),
    );
  }
}

class ChallengeRecommendationEngine {
  const ChallengeRecommendationEngine();

  // Cache to avoid recomputing insights too often.
  static final TtlMemoryCacheService _insightsCache = TtlMemoryCacheService(
    defaultTtlMs: 2 * 60 * 1000,
    maxEntries: 50,
  );

  /// Calcula los insights de retos para un usuario dado.
  ///
  /// Intenta primero obtener el resultado desde la caché en memoria para
  /// evitar recomputaciones. Si no está en caché, lanza la computación a
  /// un isolate con `compute()` (para no bloquear la UI). El resultado
  /// se convierte a `ChallengeRankingInsights` usando la fábrica.
  Future<ChallengeRankingInsights> buildInsightsAsync({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> challenges,
    required UserProfile profile,
    int topRatedMaxResults = 5,
  }) async {
    try {
      final payload = <String, dynamic>{
        'mainSport': profile.mainSport,
        'preferences': (profile.inferredPreferences ?? const <String, double>{})
            .map((key, value) => MapEntry(key, value.toDouble())),
        'topRatedMaxResults': topRatedMaxResults,
        'challenges': challenges.map((doc) {
          final data = doc.data();
          final endDate = (data['endDate'] as Timestamp?)?.toDate();

          return <String, dynamic>{
            'id': doc.id,
            'title': data['title'],
            'goalLabel': data['goalLabel'],
            'sport': data['sport'],
            'difficulty': data['difficulty'],
            'endDateMs': endDate?.millisecondsSinceEpoch,
            'ratingAverage': data['ratingAverage'],
            'ratingCount': data['ratingCount'],
            'participantsCount': data['participantsCount'],
            'isJoined': (List<String>.from(
              data['participants'] ?? const [],
            )).contains(profile.uid),
            'userProgress':
                ((Map<String, dynamic>.from(
                          data['progressByUser'] ?? const {},
                        ))[profile.uid]
                        as num?)
                    ?.toDouble() ??
                0.0,
          };
        }).toList(),
      };

      // Construye una clave de caché sencilla basada en el usuario y los ids
      // de los retos. Incluir `topRatedMaxResults` evita colisiones cuando
      // el mismo conjunto de retos se consulta con parámetros distintos.
      final ids = challenges.map((d) => d.id).join(',');
      final cacheKey = 'insights_${profile.uid}_$ids\_${topRatedMaxResults}';

      // Consulta la caché en memoria (LRU + TTL). Si el resultado existe
      // y no ha expirado, lo reutilizamos inmediatamente.
      final cached = _insightsCache.get(cacheKey);
      if (cached is Map<String, dynamic>) {
        return ChallengeRankingInsights.fromComputeResult(cached);
      }

      // Ejecuta la función pesada en un isolate para mantener la UI
      // responsiva. `compute` recibe un `Map` serializable.
      final result = await compute(_computeChallengeInsights, payload);

      // Intenta almacenar el resultado en caché. Se atrapa cualquier error
      // silenciosamente para no romper la experiencia si la caché falla.
      if (result is Map<String, dynamic>) {
        try {
          _insightsCache.put(cacheKey, result);
        } catch (_) {}
      }

      return ChallengeRankingInsights.fromComputeResult(result);
    } catch (_) {
      return _buildInsightsSync(
        challenges: challenges,
        profile: profile,
        topRatedMaxResults: topRatedMaxResults,
      );
    }
  }

  ChallengeRankingInsights _buildInsightsSync({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> challenges,
    required UserProfile profile,
    int topRatedMaxResults = 5,
  }) {
    // Versión síncrona/alternativa que se usa como fallback si la
    // computación en isolate lanza una excepción. Reusa las funciones
    // puras `rankChallenges` y `topRatedChallenges`.
    final rankedDocs = rankChallenges(challenges: challenges, profile: profile);
    final topRatedDocs = topRatedChallenges(
      challenges: challenges,
      maxResults: topRatedMaxResults,
    );
    final recommendation = buildRecommendation(
      challenges: rankedDocs,
      profile: profile,
    );

    return ChallengeRankingInsights(
      rankedIds: rankedDocs.map((doc) => doc.id).toList(),
      topRatedIds: topRatedDocs.map((doc) => doc.id).toList(),
      recommendation: recommendation,
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> topRatedChallenges({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> challenges,
    int maxResults = 4,
    int minReviews = 1,
  }) {
    // Filtra por número mínimo de reseñas y ordena por puntuación y
    // confianza (score que mezcla media y cantidad de reviews).
    if (challenges.isEmpty || maxResults <= 0) {
      return const [];
    }

    final eligible = challenges.where((doc) {
      final data = doc.data();
      final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
      return ratingCount >= minReviews;
    }).toList();

    final source = eligible.isNotEmpty ? eligible : [...challenges];

    source.sort((a, b) {
      final aData = a.data();
      final bData = b.data();

      final aAverage = (aData['ratingAverage'] as num?)?.toDouble() ?? 0.0;
      final bAverage = (bData['ratingAverage'] as num?)?.toDouble() ?? 0.0;

      final aCount = (aData['ratingCount'] as num?)?.toInt() ?? 0;
      final bCount = (bData['ratingCount'] as num?)?.toInt() ?? 0;

      final aNormalized = (aAverage / 5.0).clamp(0.0, 1.0);
      final bNormalized = (bAverage / 5.0).clamp(0.0, 1.0);
      final aConfidence = (aCount / 12.0).clamp(0.0, 1.0);
      final bConfidence = (bCount / 12.0).clamp(0.0, 1.0);

      final aScore = (0.75 * aNormalized) + (0.25 * aConfidence);
      final bScore = (0.75 * bNormalized) + (0.25 * bConfidence);

      final byScore = bScore.compareTo(aScore);
      if (byScore != 0) return byScore;

      final byCount = bCount.compareTo(aCount);
      if (byCount != 0) return byCount;

      return bAverage.compareTo(aAverage);
    });

    return source.take(maxResults).toList();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> rankChallenges({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> challenges,
    required UserProfile profile,
  }) {
    // Ordena los retos aplicando el scoring por cada documento y luego
    // ordenando por puntaje. En caso de empate se usan fechas de fin
    // para priorizar retos con fecha más próxima.
    if (challenges.isEmpty) return const [];

    final scored = challenges
        .map((doc) => _scoreChallenge(doc: doc, profile: profile))
        .toList();

    final scoreById = {for (final item in scored) item.id: item.score};

    final ranked = [...challenges]
      ..sort((a, b) {
        final aScore = scoreById[a.id] ?? double.negativeInfinity;
        final bScore = scoreById[b.id] ?? double.negativeInfinity;
        final byScore = bScore.compareTo(aScore);
        if (byScore != 0) return byScore;

        final aDate = (a.data()['endDate'] as Timestamp?)?.toDate();
        final bDate = (b.data()['endDate'] as Timestamp?)?.toDate();
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });

    return ranked;
  }

  ChallengeRecommendation? buildRecommendation({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> challenges,
    required UserProfile profile,
  }) {
    // Construye una recomendación textual simple basada en los dos
    // motivos principales que mejor describen por qué el reto es
    // recomendado (p. ej. coincide con deporte principal, es fácil,
    // tiene buena valoración, etc.).
    if (challenges.isEmpty) return null;

    final scored =
        challenges
            .map((doc) => _scoreChallenge(doc: doc, profile: profile))
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    if (scored.isEmpty) return null;
    final best = scored.first;

    // Lista de motivos (en inglés original) — aquí se eligen las dos
    // causas más relevantes para formar una frase explicativa corta.
    final reasons = <String>[
      if (best.matchesMainSport) 'it matches your main sport',
      if (best.preferenceScore >= 0.5) 'it aligns with your interests',
      if (best.ratingScore >= 0.65) 'users rated it highly',
      if (best.daysLeft >= 0 && best.daysLeft <= 10)
        'it has a near and achievable goal',
      if (best.easeScore >= 0.55) 'it looks easier to start with',
    ];

    final reason = reasons.isEmpty
        ? 'it is a good starting point based on your recent activity'
        : reasons.take(2).join(' and ');

    return ChallengeRecommendation(
      challengeId: best.id,
      title: best.title,
      sportLabel: best.sportLabel,
      reason: reason,
    );
  }

  _ScoredChallenge _scoreChallenge({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required UserProfile profile,
  }) {
    final data = doc.data();

    // Extrae campos básicos y normaliza valores.
    final sportRaw = (data['sport'] as String?)?.trim() ?? '';
    final sportKey = AppSports.normalizeSportKey(sportRaw);
    final sportLabel = AppSports.formatSportLabel(sportRaw);

    final title = (data['title'] as String?)?.trim().isNotEmpty == true
        ? data['title'] as String
        : ((data['goalLabel'] as String?)?.trim().isNotEmpty == true
              ? data['goalLabel'] as String
              : 'Challenge');

    // Determina si el usuario ya participa y su progreso actual.
    final participants = List<String>.from(data['participants'] ?? const []);
    final isJoined = participants.contains(profile.uid);

    final progressByUser = Map<String, dynamic>.from(
      data['progressByUser'] ?? const {},
    );
    final userProgress =
        (progressByUser[profile.uid] as num?)?.toDouble() ?? 0.0;

    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    final daysLeft = endDate == null
        ? 30
        : endDate.difference(DateTime.now()).inDays;

    // Preferencias del usuario para deportes; se intenta acceder por
    // llave normalizada y por el nombre bruto como fallback.
    final prefs = profile.inferredPreferences ?? const <String, double>{};
    final preferenceScore = (prefs[sportKey] ?? prefs[sportRaw] ?? 0.0).clamp(
      0.0,
      1.0,
    );

    final normalizedMain = profile.mainSport == null
        ? ''
        : AppSports.normalizeSportKey(profile.mainSport!);
    final matchesMainSport =
        normalizedMain.isNotEmpty && normalizedMain == sportKey;

    final participantsCount =
        (data['participantsCount'] as num?)?.toInt() ?? participants.length;
    final socialEase = (participantsCount / 20).clamp(0.0, 1.0);

    final ratingAverage = (data['ratingAverage'] as num?)?.toDouble() ?? 0.0;
    final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
    final normalizedAverage = (ratingAverage / 5.0).clamp(0.0, 1.0);
    final confidence = (ratingCount / 8.0).clamp(0.0, 1.0);
    final ratingScore =
        ((normalizedAverage * 0.6) + (normalizedAverage * confidence * 0.4))
            .clamp(0.0, 1.0);

    final daysScore = daysLeft < 0
        ? 0.0
        : (daysLeft >= 5 ? 1.0 : (daysLeft / 5).clamp(0.0, 1.0));

    final explicitDifficulty = ((data['difficulty'] as String?) ?? '')
        .toLowerCase();
    // Mapea dificultad explícita a una heurística de "facilidad".
    final difficultyEase = switch (explicitDifficulty) {
      'easy' || 'facil' => 1.0,
      'medium' || 'intermedio' => 0.65,
      'hard' || 'dificil' => 0.35,
      _ => 0.55,
    };

    final easeScore =
        (0.50 * difficultyEase) + (0.30 * socialEase) + (0.20 * daysScore);

    // Selecciona la estrategia de scoring según si el usuario ya está
    // inscrito o tiene progreso en el reto (consistencia vs exploración).
    final strategy = _ChallengeScoringStrategyFactory.resolve(
      isJoined: isJoined,
      progress: userProgress,
    );

    final total = strategy.computeScore(
      preferenceScore: preferenceScore,
      easeScore: easeScore,
      daysScore: daysScore,
      ratingScore: ratingScore,
      userProgress: userProgress,
      matchesMainSport: matchesMainSport,
    );

    return _ScoredChallenge(
      id: doc.id,
      title: title,
      sportLabel: sportLabel,
      score: total,
      preferenceScore: preferenceScore,
      easeScore: easeScore,
      ratingScore: ratingScore,
      daysLeft: daysLeft,
      matchesMainSport: matchesMainSport,
    );
  }
}

abstract class _ChallengeScoringStrategy {
  double computeScore({
    required double preferenceScore,
    required double easeScore,
    required double daysScore,
    required double ratingScore,
    required double userProgress,
    required bool matchesMainSport,
  });
}

class _ExplorationScoringStrategy implements _ChallengeScoringStrategy {
  const _ExplorationScoringStrategy();

  @override
  double computeScore({
    required double preferenceScore,
    required double easeScore,
    required double daysScore,
    required double ratingScore,
    required double userProgress,
    required bool matchesMainSport,
  }) {
    final mainSportBoost = matchesMainSport ? 0.25 : 0.0;

    return (0.45 * preferenceScore) +
        (0.22 * easeScore) +
        (0.15 * daysScore) +
        (0.18 * ratingScore) +
        mainSportBoost;
  }
}

/// Estrategia para usuarios que ya están involucrados en el reto.
///
/// Prioriza la continuidad (progreso acumulado) y la coherencia con
/// la actividad previa del usuario, por eso aplica un `continuationBoost`.
class _ConsistencyScoringStrategy implements _ChallengeScoringStrategy {
  const _ConsistencyScoringStrategy();

  @override
  double computeScore({
    required double preferenceScore,
    required double easeScore,
    required double daysScore,
    required double ratingScore,
    required double userProgress,
    required bool matchesMainSport,
  }) {
    final continuationBoost = 0.20 + (userProgress * 0.30);
    final mainSportBoost = matchesMainSport ? 0.10 : 0.0;

    return (0.35 * preferenceScore) +
        (0.12 * easeScore) +
        (0.08 * daysScore) +
        (0.15 * ratingScore) +
        continuationBoost +
        mainSportBoost;
  }
}

class _ChallengeScoringStrategyFactory {
  static _ChallengeScoringStrategy resolve({
    required bool isJoined,
    required double progress,
  }) {
    if (isJoined || progress > 0) {
      return const _ConsistencyScoringStrategy();
    }

    return const _ExplorationScoringStrategy();
  }
}

class _ScoredChallenge {
  final String id;
  final String title;
  final String sportLabel;
  final double score;
  final double preferenceScore;
  final double easeScore;
  final double ratingScore;
  final int daysLeft;
  final bool matchesMainSport;

  const _ScoredChallenge({
    required this.id,
    required this.title,
    required this.sportLabel,
    required this.score,
    required this.preferenceScore,
    required this.easeScore,
    required this.ratingScore,
    required this.daysLeft,
    required this.matchesMainSport,
  });
}

/// Función pura que realiza el cálculo de insights a partir de un
/// `payload` serializable. Está diseñada para ejecutarse en un isolate
/// usando `compute()`.
///
/// Formato esperado del `payload`:
/// - `mainSport`: String con el deporte principal del usuario (opcional).
/// - `preferences`: Map<String,double> con preferencias por deporte.
/// - `topRatedMaxResults`: int con el tamaño de la lista "top rated".
/// - `challenges`: List<Map> con los campos mínimos por reto:
///     - `id`, `title`, `goalLabel`, `sport`, `difficulty`, `endDateMs`,
///       `ratingAverage`, `ratingCount`, `participantsCount`,
///       `isJoined`, `userProgress`.
///
/// Salida: `Map<String,dynamic>` con llaves: `rankedIds`, `topRatedIds`,
/// `recommendation` (o `null`).
Map<String, dynamic> _computeChallengeInsights(Map<String, dynamic> payload) {
  final challenges = List<Map<String, dynamic>>.from(
    payload['challenges'] as List? ?? const [],
  );
  final preferences = Map<String, dynamic>.from(
    payload['preferences'] as Map? ?? const {},
  );
  final mainSportRaw = (payload['mainSport'] as String?)?.trim() ?? '';
  final normalizedMainSport = AppSports.normalizeSportKey(mainSportRaw);
  final topRatedMaxResults =
      (payload['topRatedMaxResults'] as num?)?.toInt() ?? 5;
  final now = DateTime.now();

  double readDouble(dynamic value, [double fallback = 0.0]) {
    return (value as num?)?.toDouble() ?? fallback;
  }

  int readInt(dynamic value, [int fallback = 0]) {
    return (value as num?)?.toInt() ?? fallback;
  }

  String readString(dynamic value, [String fallback = '']) {
    final text = (value as String?)?.trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  final scored = challenges.map((challenge) {
    final id = readString(challenge['id']);
    final sportRaw = readString(challenge['sport']);
    final sportKey = AppSports.normalizeSportKey(sportRaw);
    final title = readString(
      challenge['title'],
      readString(challenge['goalLabel'], 'Challenge'),
    );
    final ratingAverage = readDouble(challenge['ratingAverage']);
    final ratingCount = readInt(challenge['ratingCount']);
    final participantsCount = readInt(challenge['participantsCount']);
    final isJoined = challenge['isJoined'] as bool? ?? false;
    final userProgress = readDouble(challenge['userProgress']);
    final endDateMs = readInt(challenge['endDateMs']);
    final difficulty = readString(challenge['difficulty']).toLowerCase();

    final preferenceScore =
        (preferences[sportKey] ?? preferences[sportRaw] ?? 0).toDouble().clamp(
          0.0,
          1.0,
        );
    final matchesMainSport =
        normalizedMainSport.isNotEmpty && normalizedMainSport == sportKey;

    final daysLeft = endDateMs <= 0
        ? 30
        : DateTime.fromMillisecondsSinceEpoch(endDateMs).difference(now).inDays;
    final socialEase = (participantsCount / 20).clamp(0.0, 1.0);
    final normalizedAverage = (ratingAverage / 5.0).clamp(0.0, 1.0);
    final confidence = (ratingCount / 8.0).clamp(0.0, 1.0);
    final ratingScore =
        ((normalizedAverage * 0.6) + (normalizedAverage * confidence * 0.4))
            .clamp(0.0, 1.0);
    final daysScore = daysLeft < 0
        ? 0.0
        : (daysLeft >= 5 ? 1.0 : (daysLeft / 5).clamp(0.0, 1.0));
    final difficultyEase = switch (difficulty) {
      'easy' || 'facil' => 1.0,
      'medium' || 'intermedio' => 0.65,
      'hard' || 'dificil' => 0.35,
      _ => 0.55,
    };
    final easeScore =
        (0.50 * difficultyEase) + (0.30 * socialEase) + (0.20 * daysScore);

    final strategy = _ChallengeScoringStrategyFactory.resolve(
      isJoined: isJoined,
      progress: userProgress,
    );

    final total = strategy.computeScore(
      preferenceScore: preferenceScore,
      easeScore: easeScore,
      daysScore: daysScore,
      ratingScore: ratingScore,
      userProgress: userProgress,
      matchesMainSport: matchesMainSport,
    );

    return <String, dynamic>{
      'id': id,
      'title': title,
      'sportLabel': AppSports.formatSportLabel(sportRaw),
      'score': total,
      'preferenceScore': preferenceScore,
      'easeScore': easeScore,
      'ratingScore': ratingScore,
      'daysLeft': daysLeft,
      'matchesMainSport': matchesMainSport,
      'ratingAverage': ratingAverage,
      'ratingCount': ratingCount,
      'endDateMs': endDateMs,
    };
  }).toList();

  scored.sort((a, b) {
    final aScore = (a['score'] as num).toDouble();
    final bScore = (b['score'] as num).toDouble();
    final byScore = bScore.compareTo(aScore);
    if (byScore != 0) return byScore;

    final aEndDate = (a['endDateMs'] as num?)?.toInt() ?? 0;
    final bEndDate = (b['endDateMs'] as num?)?.toInt() ?? 0;
    if (aEndDate == 0 && bEndDate == 0) return 0;
    if (aEndDate == 0) return 1;
    if (bEndDate == 0) return -1;
    return aEndDate.compareTo(bEndDate);
  });

  final rankedIds = scored
      .map((item) => item['id'] as String)
      .where((id) => id.isNotEmpty)
      .toList();

  final topRatedScored = scored.where((item) {
    final ratingCount = (item['ratingCount'] as num?)?.toInt() ?? 0;
    return ratingCount >= 1;
  }).toList();

  final topRatedSource = topRatedScored.isNotEmpty ? topRatedScored : scored;
  topRatedSource.sort((a, b) {
    final aAverage = (a['ratingAverage'] as num?)?.toDouble() ?? 0.0;
    final bAverage = (b['ratingAverage'] as num?)?.toDouble() ?? 0.0;
    final aCount = (a['ratingCount'] as num?)?.toInt() ?? 0;
    final bCount = (b['ratingCount'] as num?)?.toInt() ?? 0;

    final aNormalized = (aAverage / 5.0).clamp(0.0, 1.0);
    final bNormalized = (bAverage / 5.0).clamp(0.0, 1.0);
    final aConfidence = (aCount / 12.0).clamp(0.0, 1.0);
    final bConfidence = (bCount / 12.0).clamp(0.0, 1.0);

    final aScore = (0.75 * aNormalized) + (0.25 * aConfidence);
    final bScore = (0.75 * bNormalized) + (0.25 * bConfidence);

    final byScore = bScore.compareTo(aScore);
    if (byScore != 0) return byScore;

    final byCount = bCount.compareTo(aCount);
    if (byCount != 0) return byCount;

    return bAverage.compareTo(aAverage);
  });

  Map<String, dynamic>? recommendation;
  if (scored.isNotEmpty) {
    final best = scored.first;
    final preferenceScore = (best['preferenceScore'] as num).toDouble();
    final ratingScore = (best['ratingScore'] as num).toDouble();
    final easeScore = (best['easeScore'] as num).toDouble();
    final daysLeft = (best['daysLeft'] as num).toInt();
    final matchesMainSport = best['matchesMainSport'] as bool? ?? false;

    final reasons = <String>[
      if (matchesMainSport) 'it matches your main sport',
      if (preferenceScore >= 0.5) 'it aligns with your interests',
      if (ratingScore >= 0.65) 'users rated it highly',
      if (daysLeft >= 0 && daysLeft <= 10) 'it has a near and achievable goal',
      if (easeScore >= 0.55) 'it looks easier to start with',
    ];

    final reason = reasons.isEmpty
        ? 'it is a good starting point based on your recent activity'
        : reasons.take(2).join(' and ');

    recommendation = <String, dynamic>{
      'challengeId': best['id'],
      'title': best['title'],
      'sportLabel': best['sportLabel'],
      'reason': reason,
    };
  }

  return <String, dynamic>{
    'rankedIds': rankedIds,
    'topRatedIds': topRatedSource
        .take(topRatedMaxResults)
        .map((item) => item['id'] as String)
        .where((id) => id.isNotEmpty)
        .toList(),
    'recommendation': recommendation,
  };
}
