import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const gold = Color(0xFFE3C477);
  static const obsidian = Color(0xFF0B1011);
  static const emerald = Color(0xFF143C32);
  static const panel = Color(0xFF172020);

  static ThemeData dark({String languageCode = 'en'}) => ThemeData(
    useMaterial3: true,
    fontFamily: languageCode == 'bn' ? 'Karnaphuli' : 'Exo2',
    fontFamilyFallback: languageCode == 'bn'
        ? const ['Karnaphuli', 'Exo2']
        : const ['Karnaphuli', 'Nikosh', 'NikoshBAN'],
    brightness: Brightness.dark,
    scaffoldBackgroundColor: obsidian,
    colorScheme: ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.dark,
      primary: gold,
      surface: panel,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: obsidian,
      foregroundColor: gold,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}
