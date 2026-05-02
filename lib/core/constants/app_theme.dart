import 'package:flutter/material.dart';

class AppTheme {
  static const Color navy = Color(0xFF001845);
  static const Color teal = Color(0xFF0C8E8B);
  static const Color softTeal = Color(0xFFE8F6F5);
  static const Color background = Color(0xFFF6F8FB);
  static const Color darkBackground = Color(0xFF07111F);
  static const Color darkSurface = Color(0xFF0E1728);
  static const Color darkSurfaceAlt = Color(0xFF131F33);

  static ThemeData get light {
    return _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      surfaceColor: Colors.white,
      surfaceBorderColor: const Color(0xFFE6EBF2),
      inputFillColor: Colors.white,
      textPrimaryColor: navy,
      textSecondaryColor: const Color(0xFF4B6588),
      iconColor: const Color(0xFF334A68),
      buttonBackgroundColor: navy,
      buttonForegroundColor: Colors.white,
      bottomNavBackgroundColor: Colors.white,
      bottomNavSelectedColor: teal,
      bottomNavUnselectedColor: const Color(0xFF6C7C95),
    );
  }

  static ThemeData get dark {
    return _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      surfaceColor: darkSurface,
      surfaceBorderColor: const Color(0xFF243147),
      inputFillColor: darkSurfaceAlt,
      textPrimaryColor: Colors.white,
      textSecondaryColor: const Color(0xFFB7C4D9),
      iconColor: const Color(0xFFD8E2F1),
      buttonBackgroundColor: const Color(0xFF1AB7B3),
      buttonForegroundColor: Colors.white,
      bottomNavBackgroundColor: darkSurface,
      bottomNavSelectedColor: const Color(0xFF47D7D2),
      bottomNavUnselectedColor: const Color(0xFF98A7C0),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color scaffoldBackgroundColor,
    required Color surfaceColor,
    required Color surfaceBorderColor,
    required Color inputFillColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required Color iconColor,
    required Color buttonBackgroundColor,
    required Color buttonForegroundColor,
    required Color bottomNavBackgroundColor,
    required Color bottomNavSelectedColor,
    required Color bottomNavUnselectedColor,
  }) {
    final colorScheme =
        ColorScheme.fromSeed(seedColor: teal, brightness: brightness).copyWith(
          primary: teal,
          secondary: teal,
          surface: surfaceColor,
          onSurface: textPrimaryColor,
          error: const Color(0xFFEF5350),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackgroundColor,
        foregroundColor: textPrimaryColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      iconTheme: IconThemeData(color: iconColor),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: textPrimaryColor,
        ),
        headlineSmall: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: textPrimaryColor,
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimaryColor,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimaryColor,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: textSecondaryColor),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondaryColor),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textSecondaryColor,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        hintStyle: TextStyle(color: textSecondaryColor),
        labelStyle: TextStyle(color: textSecondaryColor),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: surfaceBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: surfaceBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: teal, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBackgroundColor,
          foregroundColor: buttonForegroundColor,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: surfaceBorderColor),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: textPrimaryColor),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bottomNavBackgroundColor,
        selectedItemColor: bottomNavSelectedColor,
        unselectedItemColor: bottomNavUnselectedColor,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: teal.withValues(alpha: 0.16),
        labelStyle: TextStyle(color: textPrimaryColor),
        side: BorderSide(color: surfaceBorderColor),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
