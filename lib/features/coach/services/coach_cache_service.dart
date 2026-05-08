import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/coach_model.dart';

class CoachCacheService {
  CoachCacheService._();

  static final CoachCacheService instance = CoachCacheService._();

  static const String _cachedCoachesKey = 'coach_cached_list_v1';
  static const String _cachedCoachOfTheMonthKey = 'coach_cached_month_v1';

  Future<void> saveState({
    required List<Coach> coaches,
    required Coach? coachOfTheMonth,
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

  Future<List<Coach>> loadCachedCoaches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedCoachesKey);
    if (raw == null || raw.isEmpty) {
      return <Coach>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Coach>[];

      return decoded
          .whereType<Map>()
          .map((item) => Coach.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[CoachCacheService] Failed to decode cached coaches: $error',
        );
      }
      return <Coach>[];
    }
  }

  Future<Coach?> loadCachedCoachOfTheMonth() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedCoachOfTheMonthKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Coach.fromJson(decoded.cast<String, dynamic>());
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[CoachCacheService] Failed to decode cached coach of the month: $error',
        );
      }
      return null;
    }
  }
}
