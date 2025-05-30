import 'package:flutter/material.dart';

/// App theme configuration matching the homepage design
class AppTheme {
  // Color scheme matching static_homepage/css/theme.css
  static const Color primaryColor =
      Color(0xFFa777e3); // --color-primary: #a777e3
  static const Color secondaryColor =
      Color(0xFF6e8efb); // --color-secondary: #6e8efb
  static const Color accentColor = Color(0xFF00c58e); // --color-accent: #00c58e

  // Background colors
  static const Color backgroundMain = Color(0xFF181a20); // --bg-main: #181a20
  static const Color backgroundCard = Color(0xFF23243a); // --bg-card: #23243a
  static const Color backgroundLight = Color(0xFFf5f5f5); // --bg-light: #f5f5f5

  // Text colors
  static const Color textColor = Color(0xFFf1f1f1); // --text-color: #f1f1f1
  static const Color textColorLight =
      Color(0xFFb0b0b0); // --text-color-light: #b0b0b0
  static const Color textColorDark =
      Color(0xFF2c3e50); // --text-color-dark: #2c3e50

  // Status colors
  static const Color successColor =
      Color(0xFF4caf50); // --color-success: #4caf50
  static const Color warningColor =
      Color(0xFFffa726); // --color-warning: #ffa726
  static const Color dangerColor = Color(0xFFff5252); // --color-danger: #ff5252
  static const Color infoColor = Color(0xFF2196f3); // --color-info: #2196f3

  // Gradients matching homepage
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryColor, primaryColor], // 135deg, #6e8efb 0%, #a777e3 100%
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [secondaryColor, primaryColor], // 90deg, #6e8efb 0%, #a777e3 100%
  );

  // Border radius values
  static const double borderRadius = 16.0;
  static const double borderRadiusSmall = 4.0;

  // Box shadows
  static const BoxShadow boxShadow = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.4),
    blurRadius: 24.0,
    offset: Offset(0, 4),
  );

  static const BoxShadow boxShadowSmall = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.2),
    blurRadius: 12.0,
    offset: Offset(0, 2),
  );

  /// Light theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: backgroundLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusSmall),
          ),
        ),
      ),
    );
  }

  /// Dark theme configuration matching homepage design
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: backgroundCard,
      ),
      scaffoldBackgroundColor: backgroundMain,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: backgroundCard,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(
            color: secondaryColor.withValues(alpha: 0.27),
            width: 1.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusSmall),
          ),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textColor),
        bodyMedium: TextStyle(color: textColor),
        bodySmall: TextStyle(color: textColorLight),
        headlineLarge:
            TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        headlineMedium:
            TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        headlineSmall:
            TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}
