import 'package:flutter/material.dart';

/// CloudToLocalLLM custom theme configuration
/// Matches the homepage design for visual consistency
class AppTheme {
  // Brand Colors (matching homepage CSS)
  static const Color primaryColor =
      Color(0xFFa777e3); // --color-primary: #a777e3
  static const Color secondaryColor =
      Color(0xFF6e8efb); // --color-secondary: #6e8efb
  static const Color accentColor = Color(0xFF00c58e); // --color-accent: #00c58e

  // Background Colors
  static const Color backgroundMain = Color(0xFF181a20); // --bg-main: #181a20
  static const Color backgroundCard = Color(0xFF23243a); // --bg-card: #23243a
  static const Color backgroundLight = Color(0xFFf5f5f5); // --bg-light: #f5f5f5

  // Text Colors
  static const Color textColor = Color(0xFFf1f1f1); // --text-color: #f1f1f1
  static const Color textColorLight =
      Color(0xFFb0b0b0); // --text-color-light: #b0b0b0
  static const Color textColorDark =
      Color(0xFF2c3e50); // --text-color-dark: #2c3e50

  // Status Colors
  static const Color successColor =
      Color(0xFF4caf50); // --color-success: #4caf50
  static const Color warningColor =
      Color(0xFFffa726); // --color-warning: #ffa726
  static const Color dangerColor = Color(0xFFff5252); // --color-danger: #ff5252
  static const Color infoColor = Color(0xFF2196f3); // --color-info: #2196f3

  // Border Radius (matching homepage)
  static const double borderRadius = 16.0; // --border-radius: 16px
  static const double borderRadiusSmall = 4.0; // --border-radius-sm: 4px

  /// Light Theme Configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: backgroundLight,
        surfaceContainer: Colors.white,
        onSurface: textColorDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        error: dangerColor,
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(
            color: primaryColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        elevation: 4,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusSmall),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }

  /// Dark Theme Configuration (matching homepage design)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: backgroundMain,
        surfaceContainer: backgroundCard,
        onSurface: textColor,
        onSurfaceVariant: textColorLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        error: dangerColor,
        tertiary: accentColor,
      ),
      cardTheme: CardThemeData(
        color: backgroundCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(
            color: primaryColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusSmall),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          elevation: 4,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundCard,
        foregroundColor: textColor,
        elevation: 2,
      ),
      scaffoldBackgroundColor: backgroundMain,
    );
  }

  /// Gradient definitions (matching homepage CSS gradients)
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryColor, primaryColor],
    stops: [0.0, 1.0],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [secondaryColor, primaryColor],
    stops: [0.0, 1.0],
  );
}
