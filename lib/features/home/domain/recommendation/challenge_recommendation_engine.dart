import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_sports.dart';
import '../../../auth/domain/entities/user_profile.dart';

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

class ChallengeRecommendationEngine {
  const ChallengeRecommendationEngine();

  List<QueryDocumentSnapshot<Map<String, dynamic>>> rankChallenges({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> challenges,
    required UserProfile profile,
  }) {
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
    if (challenges.isEmpty) return null;

    final scored =
        challenges
            .map((doc) => _scoreChallenge(doc: doc, profile: profile))
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    if (scored.isEmpty) return null;
    final best = scored.first;

    final reasons = <String>[
      if (best.matchesMainSport) 'it matches your main sport',
      if (best.preferenceScore >= 0.5) 'it aligns with your interests',
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

    final sportRaw = (data['sport'] as String?)?.trim() ?? '';
    final sportKey = AppSports.normalizeSportKey(sportRaw);
    final sportLabel = AppSports.formatSportLabel(sportRaw);

    final title = (data['title'] as String?)?.trim().isNotEmpty == true
        ? data['title'] as String
        : ((data['goalLabel'] as String?)?.trim().isNotEmpty == true
              ? data['goalLabel'] as String
              : 'Challenge');

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

    final daysScore = daysLeft < 0
        ? 0.0
        : (daysLeft >= 5 ? 1.0 : (daysLeft / 5).clamp(0.0, 1.0));

    final explicitDifficulty = ((data['difficulty'] as String?) ?? '')
        .toLowerCase();
    final difficultyEase = switch (explicitDifficulty) {
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
    required double userProgress,
    required bool matchesMainSport,
  }) {
    final mainSportBoost = matchesMainSport ? 0.25 : 0.0;

    return (0.45 * preferenceScore) +
        (0.30 * easeScore) +
        (0.25 * daysScore) +
        mainSportBoost;
  }
}

class _ConsistencyScoringStrategy implements _ChallengeScoringStrategy {
  const _ConsistencyScoringStrategy();

  @override
  double computeScore({
    required double preferenceScore,
    required double easeScore,
    required double daysScore,
    required double userProgress,
    required bool matchesMainSport,
  }) {
    final continuationBoost = 0.20 + (userProgress * 0.30);
    final mainSportBoost = matchesMainSport ? 0.10 : 0.0;

    return (0.35 * preferenceScore) +
        (0.20 * easeScore) +
        (0.15 * daysScore) +
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
  final int daysLeft;
  final bool matchesMainSport;

  const _ScoredChallenge({
    required this.id,
    required this.title,
    required this.sportLabel,
    required this.score,
    required this.preferenceScore,
    required this.easeScore,
    required this.daysLeft,
    required this.matchesMainSport,
  });
}
