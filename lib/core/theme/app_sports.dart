import 'package:flutter/material.dart';

/// Estilos de deportes con colores, iconos y nombres
class AppSports {
  static const Map<String, SportStyle> sports = {
    'futbol': SportStyle(
      name: 'Fútbol',
      icon: Icons.sports_soccer,
      color: Color(0xFF4CAF50), // Verde
    ),
    'calistenia': SportStyle(
      name: 'Calistenia',
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
      name: 'Natación',
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

