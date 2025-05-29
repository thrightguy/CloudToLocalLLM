import 'package:flutter/material.dart';

/// Theme for CloudToLocalLLM matching the static website
class CloudToLocalLLMTheme {
  // Colors from the static website CSS
  static const Color primaryColor = Color(0xFFA777E3);
  static const Color secondaryColor = Color(0xFF6E8EFB);
  static const Color accentColor = Color(0xFF00C58E);
  static const Color bgMain = Color(0xFF181A20);
  static const Color bgCard = Color(0xFF23243A);
  static const Color textColor = Color(0xFFF1F1F1);
  static const Color textColorLight = Color(0xFFB0B0B0);

  // Gradients
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryColor, primaryColor],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [secondaryColor, primaryColor],
  );

  // Theme data
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: bgCard,
        background: bgMain,
      ),
      scaffoldBackgroundColor: bgMain,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: textColor,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textColor,
        displayColor: textColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: primaryColor,
        secondary: secondaryColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
