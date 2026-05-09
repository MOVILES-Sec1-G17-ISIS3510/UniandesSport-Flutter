import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _themeKey = 'theme_mode';
  static const String _lastCalisthenicsAnalysisKey = 'last_calisthenics_analysis_date';

  // Singleton
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  Future<void> saveThemeMode(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme);
  }

  Future<String?> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey);
  }

  Future<void> saveLastCalisthenicsAnalysisDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCalisthenicsAnalysisKey, date.toIso8601String());
  }

  Future<DateTime?> getLastCalisthenicsAnalysisDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_lastCalisthenicsAnalysisKey);
    if (dateString != null) {
      return DateTime.tryParse(dateString);
    }
    return null;
  }
}
