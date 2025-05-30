import 'package:flutter/material.dart';

/// Modern Material Design 3 theme configuration matching the homepage design
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
  static const double borderRadiusSmall =
      8.0; // Increased for better Material 3 compliance
  static const double borderRadiusLarge = 24.0;

  // Spacing values
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

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

  static const BoxShadow boxShadowLarge = BoxShadow(
    color: Color.fromRGBO(167, 119, 227, 0.4),
    blurRadius: 32.0,
    offset: Offset(0, 8),
  );

  /// Light theme configuration with Material Design 3
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryColor,
      surface: backgroundLight,
      onSurface: textColorDark,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textColorDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textColorDark,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        margin: EdgeInsets.all(spacingS),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primaryColor.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusSmall),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingM,
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text theme
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textColorDark,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textColorDark,
          height: 1.2,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textColorDark,
          height: 1.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textColorDark,
          height: 1.3,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textColorDark,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textColorDark,
          height: 1.5,
        ),
      ),
    );
  }

  /// Dark theme configuration matching homepage design with Material Design 3
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      secondary: secondaryColor,
      surface: backgroundCard,
      onSurface: textColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundMain,
      fontFamily: 'Roboto',

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: backgroundCard,
        elevation: 8,
        shadowColor: primaryColor.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(
            color: secondaryColor.withValues(alpha: 0.27),
            width: 1.5,
          ),
        ),
        margin: EdgeInsets.all(spacingS),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: primaryColor.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusSmall),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingM,
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text theme
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.2,
        ),
        displayMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.2,
        ),
        headlineLarge: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.3,
        ),
        headlineMedium: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: primaryColor,
          height: 1.3,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textColor,
          height: 1.5,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textColor,
          height: 1.5,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textColorLight,
          height: 1.5,
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          borderSide: BorderSide(
            color: secondaryColor.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          borderSide: BorderSide(
            color: secondaryColor.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          borderSide: BorderSide(
            color: primaryColor,
            width: 2,
          ),
        ),
        labelStyle: const TextStyle(color: textColorLight),
        hintStyle: const TextStyle(color: textColorLight),
      ),
    );
  }

  /// Custom gradient button decoration
  static BoxDecoration get gradientButtonDecoration => BoxDecoration(
        gradient: buttonGradient,
        borderRadius: BorderRadius.circular(borderRadiusSmall),
        boxShadow: const [boxShadowSmall],
      );

  /// Custom card decoration with hover effect
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: backgroundCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: secondaryColor.withValues(alpha: 0.27),
          width: 1.5,
        ),
        boxShadow: const [boxShadow],
      );

  /// Custom card decoration with hover effect
  static BoxDecoration get cardDecorationHover => BoxDecoration(
        color: backgroundCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: primaryColor,
          width: 1.5,
        ),
        boxShadow: const [boxShadowLarge],
      );
}
