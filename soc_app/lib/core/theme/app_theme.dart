import 'package:flutter/material.dart';

class AppTheme {
  static const _seedColor = Color(0xFF2E7D32);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}
