import 'package:flutter/material.dart';

/// Estilos de deportes con colores, iconos y nombres
class AppSports {
  static const Map<String, SportStyle> sports = {
    'futbol': SportStyle(
      name: 'Soccer',
      icon: Icons.sports_soccer,
      color: Color(0xFF4CAF50), // Verde
    ),
    'calistenia': SportStyle(
      name: 'Calisthenics',
      icon: Icons.fitness_center,
      color: Color(0xFFFF9800), // Naranja
    ),
    'running': SportStyle(
      name: 'Running',
      icon: Icons.directions_run,
      color: Color(0xFF2196F3), // Azul
    ),
    'basketball': SportStyle(
      name: 'Basketball',
      icon: Icons.sports_basketball,
      color: Color(0xFFFF5722), // Naranja rojizo
    ),
    'tennis': SportStyle(
      name: 'Tennis',
      icon: Icons.sports_tennis,
      color: Color(0xFFFFC107), // Amarillo
    ),
    'natacion': SportStyle(
      name: 'Swimming',
      icon: Icons.pool,
      color: Color(0xFF00BCD4), // Cyan
    ),
    'pingpong': SportStyle(
      name: 'Ping Pong',
      icon: Icons.sports,
      color: Color(0xFF9C27B0), // Morado
    ),
    'squash': SportStyle(
      name: 'Squash',
      icon: Icons.sports_golf,
      color: Color(0xFF795548), // Marrón
    ),
  };

  static List<String> get sportKeys => sports.keys.toList();

  static SportStyle getSport(String key) {
    return sports[key] ?? sports['futbol']!;
  }

  /// Normaliza el valor para almacenamiento en DB: minusculas y sin espacios.
  static String normalizeSportKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  /// Etiqueta legible para UI.
  /// Si existe en el catalogo oficial, usa su nombre (ej: Ping Pong).
  /// Si no existe, intenta capitalizar de forma simple.
  static String formatSportLabel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }

    final key = normalizeSportKey(value);
    final style = sports[key];
    if (style != null) {
      return style.name;
    }

    final compact = key.replaceAll('_', ' ');
    return compact
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  static Map<String, double> buildInitialInferredPreferences({
    String? favoriteSport,
  }) {
    if (favoriteSport == null || favoriteSport.trim().isEmpty) {
      return <String, double>{};
    }

    final normalizedFavorite = normalizeSportKey(favoriteSport);
    return <String, double>{normalizedFavorite: 10.0};
  }
}

class SportStyle {
  final String name;
  final IconData icon;
  final Color color;

  const SportStyle({
    required this.name,
    required this.icon,
    required this.color,
  });
}
