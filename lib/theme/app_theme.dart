import 'package:flutter/material.dart';
import 'package:meditime/core/constants.dart';

/// Enhanced application theme with better organization and consistency.
/// 
/// This class provides a centralized theme configuration for the entire application,
/// ensuring consistent styling across all screens and components.
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // -------------------
  // Color Palette
  // -------------------

  /// Primary color for gradients and active elements (light blue).
  static const Color primaryColor = Color(0xFF3FB8EE);

  /// Secondary color for important texts and gradients (dark blue).
  static const Color secondaryColor = Color(0xFF4092E4);

  /// Main background color for most screens.
  static const Color backgroundColor = Color(0xFFF3F3F3);

  /// Color for success states (green).
  static const Color successColor = Colors.green;

  /// Color for error/warning states (red).
  static const Color errorColor = Colors.red;

  /// Color for informational elements (blue).
  static const Color infoColor = Colors.blue;

  /// Text colors
  static const Color primaryTextColor = Colors.black87;
  static const Color secondaryTextColor = Color.fromARGB(255, 55, 55, 55);
  static const Color whiteTextColor = Colors.white;

  /// Surface colors
  static const Color surfaceColor = Color(0xFFF3F3F3);
  static const Color cardColor = Colors.white;

  // -------------------
  // Gradients
  // -------------------

  /// Primary gradient used throughout the app
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryColor, secondaryColor],
  );

  /// Header gradient for app bars and headers
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color.fromARGB(255, 73, 194, 255),
      Color.fromARGB(255, 47, 109, 180),
    ],
  );

  // -------------------
  // Shadows and Borders
  // -------------------

  /// Standard card shadow used throughout the application.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color.fromARGB(20, 47, 109, 180),
      blurRadius: 6,
      spreadRadius: 3,
      offset: Offset(0, 4),
    ),
  ];

  /// Light shadow for subtle elevation
  static const List<BoxShadow> lightShadow = [
    BoxShadow(
      color: Color.fromARGB(10, 0, 0, 0),
      blurRadius: 4,
      spreadRadius: 1,
      offset: Offset(0, 2),
    ),
  ];

  /// Border radius values
  static const double defaultBorderRadius = AppConstants.defaultBorderRadius;
  static const double smallBorderRadius = AppConstants.smallBorderRadius;

  // -------------------
  // Text Styles
  // -------------------

  /// Page title style
  static const TextStyle pageTitleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: secondaryColor,
  );

  /// Section title style
  static const TextStyle sectionTitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: primaryTextColor,
  );

  /// Body text style
  static const TextStyle bodyTextStyle = TextStyle(
    fontSize: 16,
    color: primaryTextColor,
  );

  /// Subtitle text style
  static const TextStyle subtitleTextStyle = TextStyle(
    fontSize: 14,
    color: secondaryTextColor,
  );

  /// Button text style
  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: whiteTextColor,
  );

  /// Caption text style
  static const TextStyle captionTextStyle = TextStyle(
    fontSize: 12,
    color: secondaryTextColor,
  );

  /// Drawer header text styles
  static const TextStyle drawerGreetingStyle = TextStyle(
    color: whiteTextColor,
    fontSize: 23,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle drawerNameStyle = TextStyle(
    color: whiteTextColor,
    fontSize: 20,
  );

  // -------------------
  // Component Themes
  // -------------------

  /// Input decoration theme
  static InputDecorationTheme get inputDecorationTheme => InputDecorationTheme(
    filled: true,
    fillColor: surfaceColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(defaultBorderRadius),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(defaultBorderRadius),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(defaultBorderRadius),
      borderSide: const BorderSide(color: primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(defaultBorderRadius),
      borderSide: const BorderSide(color: errorColor, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppConstants.defaultPadding,
      vertical: 14,
    ),
  );

  /// Elevated button theme
  static ElevatedButtonThemeData get elevatedButtonTheme => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: whiteTextColor,
      textStyle: buttonTextStyle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(defaultBorderRadius),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.largePadding,
        vertical: AppConstants.defaultPadding,
      ),
    ),
  );

  /// Card theme
  static CardTheme get cardTheme => CardTheme(
    color: cardColor,
    shadowColor: const Color.fromARGB(20, 47, 109, 180),
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(defaultBorderRadius),
    ),
  );

  /// App bar theme
  static AppBarTheme get appBarTheme => const AppBarTheme(
    backgroundColor: backgroundColor,
    foregroundColor: primaryTextColor,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: primaryTextColor,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  );

  // -------------------
  // Main Theme Data
  // -------------------

  /// Light theme configuration
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: secondaryColor,
      surface: backgroundColor,
    ),
    scaffoldBackgroundColor: backgroundColor,
    appBarTheme: appBarTheme,
    inputDecorationTheme: inputDecorationTheme,
    elevatedButtonTheme: elevatedButtonTheme,
    cardTheme: cardTheme,
    textTheme: const TextTheme(
      headlineLarge: pageTitleStyle,
      headlineMedium: sectionTitleStyle,
      bodyLarge: bodyTextStyle,
      bodyMedium: subtitleTextStyle,
      labelLarge: buttonTextStyle,
      bodySmall: captionTextStyle,
    ),
  );
}

// -------------------
// Legacy Constants (for backward compatibility)
// -------------------

/// @deprecated Use AppTheme.primaryColor instead
const kPrimaryColor = AppTheme.primaryColor;

/// @deprecated Use AppTheme.secondaryColor instead
const kSecondaryColor = AppTheme.secondaryColor;

/// @deprecated Use AppTheme.backgroundColor instead
const kBackgroundColor = AppTheme.backgroundColor;

/// @deprecated Use AppTheme.successColor instead
const kSuccessColor = AppTheme.successColor;

/// @deprecated Use AppTheme.errorColor instead
const kErrorColor = AppTheme.errorColor;

/// @deprecated Use AppTheme.infoColor instead
const kInfoColor = AppTheme.infoColor;

/// @deprecated Use AppTheme.cardShadow instead
const kCustomBoxShadow = AppTheme.cardShadow;

/// @deprecated Use AppTheme.pageTitleStyle instead
const kPageTitleStyle = AppTheme.pageTitleStyle;

/// @deprecated Use AppTheme.sectionTitleStyle instead
const kSectionTitleStyle = AppTheme.sectionTitleStyle;

/// @deprecated Use AppTheme.bodyTextStyle instead
const kBodyTextStyle = AppTheme.bodyTextStyle;

/// @deprecated Use AppTheme.subtitleTextStyle instead
const kSubtitleTextStyle = AppTheme.subtitleTextStyle;