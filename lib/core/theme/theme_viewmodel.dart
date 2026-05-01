import 'package:flutter/material.dart';
import '../local_storage/preferences_service.dart';

class ThemeViewModel extends ChangeNotifier {
  final PreferencesService _prefsService = PreferencesService();

  ThemeMode _currentTheme = ThemeMode.system;
  ThemeMode get currentTheme => _currentTheme;

  ThemeViewModel() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final themeString = await _prefsService.getThemeMode();
    if (themeString != null) {
      _currentTheme = ThemeMode.values.firstWhere(
        (e) => e.toString() == themeString,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }

  Future<void> changeTheme(ThemeMode mode) async {
    if (_currentTheme == mode) return;
    
    _currentTheme = mode;
    notifyListeners();
    
    await _prefsService.saveThemeMode(mode.toString());
  }
}
