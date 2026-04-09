import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/coach/domain/models/coach_model.dart';

/// Local cache for coach listings and the highlighted coach of the month.
///
/// The service uses SharedPreferences because the cached payload is small,
/// fast to read on startup, and does not require a full local database.
class CoachCacheService {
  CoachCacheService._internal();

  static final CoachCacheService instance = CoachCacheService._internal();

  static const String _cachedCoachesKey = 'cached_coaches_json';
  static const String _cachedCoachOfTheMonthKey = 'cached_coach_of_the_month';

  /// Stores the current coach list and the featured coach.
  Future<void> saveState({
    required List<Coach> coaches,
    Coach? coachOfTheMonth,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _cachedCoachesKey,
      jsonEncode(coaches.map((coach) => coach.toJson()).toList()),
    );

    if (coachOfTheMonth == null) {
      await prefs.remove(_cachedCoachOfTheMonthKey);
    } else {
      await prefs.setString(
        _cachedCoachOfTheMonthKey,
        jsonEncode(coachOfTheMonth.toJson()),
      );
    }
  }

  /// Restores the cached coach list.
  Future<List<Coach>> loadCachedCoaches() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_cachedCoachesKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => Coach.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Restores the cached featured coach, if present.
  Future<Coach?> loadCachedCoachOfTheMonth() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_cachedCoachOfTheMonthKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      return null;
    }

    return Coach.fromJson(Map<String, dynamic>.from(decoded));
  }
}
