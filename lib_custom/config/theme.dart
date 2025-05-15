import 'package:flutter/material.dart';

class AppTheme {
  // Design System Colors
  static const Color primary = Color(0xFFA777E3); // purple
  static const Color primary2 = Color(0xFF6E8EFB); // blue
  static const Color accent = Color(0xFF00C58E);
  static const Color warning = Color(0xFFFFA726);
  static const Color danger = Color(0xFFFF5252);
  static const Color success = Color(0xFF4CAF50);
  static const Color info = Color(0xFF2196F3);
  static const Color bg = Color(0xFF181A20);
  static const Color bgCard = Color(0xFF23243A);
  static const Color text = Color(0xFFF1F1F1);
  static const Color textMuted = Color(0xFFB0B0B0);

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: primary2,
      onSecondary: Colors.white,
      error: danger,
      onError: Colors.white,
      background: Colors.white,
      onBackground: bg,
      surface: bgCard,
      onSurface: text,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: bg,
    ),
    cardTheme: CardTheme(
      color: bgCard,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // design system
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4), // design system
      ),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4), // design system
        ),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: bg),
      bodyMedium: TextStyle(color: bg),
      bodySmall: TextStyle(color: textMuted),
      titleLarge: TextStyle(color: primary, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: primary2, fontWeight: FontWeight.bold),
      titleSmall: TextStyle(color: accent),
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: Colors.white,
      secondary: primary2,
      onSecondary: Colors.white,
      error: danger,
      onError: Colors.white,
      background: bg,
      onBackground: text,
      surface: bgCard,
      onSurface: text,
    ),
    scaffoldBackgroundColor: bg,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Color(0xFF181A20),
      foregroundColor: text,
    ),
    cardTheme: CardTheme(
      color: bgCard,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // design system
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4), // design system
      ),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4), // design system
        ),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: text),
      bodyMedium: TextStyle(color: text),
      bodySmall: TextStyle(color: textMuted),
      titleLarge: TextStyle(color: primary, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: primary2, fontWeight: FontWeight.bold),
      titleSmall: TextStyle(color: accent),
    ),
  );
}
