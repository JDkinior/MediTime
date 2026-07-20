import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Primary color for active elements.
  static const Color primaryColor = Color(0xFF004AC6);

  /// Secondary color for secondary active elements.
  static const Color secondaryColor = Color(0xFF006C49);

  /// Main background color for most screens.
  static Color backgroundColor = const Color(0xFFF8F9FF);

  /// Color for success states (green).
  static const Color successColor = Color(0xFF10B981);

  /// Color for error/warning states (red).
  static const Color errorColor = Color(0xFFBA1A1A);

  /// Color for informational elements.
  static const Color infoColor = Color(0xFF2563EB);

  /// Text colors
  static Color primaryTextColor = const Color(0xFF0B1C30);
  static Color secondaryTextColor = const Color(0xFF434655);
  static const Color whiteTextColor = Colors.white;

  /// Surface colors
  static Color surfaceColor = const Color(0xFFEFF4FF);
  static Color cardColor = Colors.white;
  static Color borderColor = const Color(0xFFEFF3F9);

  /// Updates static colors to match light or dark mode.
  static void updateThemeColors(bool isDark) {
    backgroundColor = isDark ? const Color(0xFF111318) : const Color(0xFFF8F9FF);
    primaryTextColor = isDark ? const Color(0xFFE2E2E9) : const Color(0xFF0B1C30);
    secondaryTextColor = isDark ? const Color(0xFF9093A5) : const Color(0xFF434655);
    surfaceColor = isDark ? const Color(0xFF1D2027) : const Color(0xFFEFF4FF);
    cardColor = isDark ? const Color(0xFF1A1C23) : Colors.white;
    borderColor = isDark ? const Color(0xFF2A2D3C) : const Color(0xFFEFF3F9);
  }

  // -------------------
  // Gradients
  // -------------------

  /// Primary gradient used throughout the app
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryColor, Color(0xFF2563EB)],
  );

  /// Header gradient for app bars and headers
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF004AC6),
      Color(0xFF2563EB),
    ],
  );

  // -------------------
  // Shadows and Borders
  // -------------------

  /// Standard card shadow used throughout the application.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000), // ~4% Black
      blurRadius: 15,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
  ];

  /// Light shadow for subtle elevation
  static const List<BoxShadow> lightShadow = [
    BoxShadow(
      color: Color(0x05000000), // ~2% Black
      blurRadius: 6,
      spreadRadius: 0,
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
    color: primaryColor,
  );

  /// Body text style
  static const TextStyle bodyTextStyle = TextStyle(
    fontSize: 16,
  );

  /// Subtitle text style
  static const TextStyle subtitleTextStyle = TextStyle(
    fontSize: 14,
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
  static CardThemeData get cardTheme => CardThemeData(
    color: cardColor,
    shadowColor: const Color.fromARGB(20, 47, 109, 180),
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(defaultBorderRadius),
    ),
  );

  /// App bar theme
  static AppBarTheme get appBarTheme => AppBarTheme(
    backgroundColor: backgroundColor,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: const TextStyle(
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
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      surface: backgroundColor,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: backgroundColor,
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: appBarTheme.copyWith(
      backgroundColor: backgroundColor,
      foregroundColor: primaryTextColor,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(color: primaryTextColor, fontSize: 20, fontWeight: FontWeight.bold),
    ),
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

  /// Dark theme configuration
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      surface: backgroundColor,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: backgroundColor,
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF1E2027),
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: appBarTheme.copyWith(
      backgroundColor: backgroundColor,
      foregroundColor: primaryTextColor,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(color: primaryTextColor, fontSize: 20, fontWeight: FontWeight.bold),
    ),
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
final kBackgroundColor = AppTheme.backgroundColor;

/// @deprecated Use AppTheme.successColor instead
const kSuccessColor = AppTheme.successColor;

/// @deprecated Use AppTheme.errorColor instead
const kErrorColor = AppTheme.errorColor;

/// @deprecated Use AppTheme.infoColor instead
const kInfoColor = AppTheme.infoColor;

/// @deprecated Use AppTheme.cardShadow instead
final kCustomBoxShadow = AppTheme.cardShadow;

/// @deprecated Use AppTheme.pageTitleStyle instead
final kPageTitleStyle = AppTheme.pageTitleStyle;

/// @deprecated Use AppTheme.sectionTitleStyle instead
final kSectionTitleStyle = AppTheme.sectionTitleStyle;

/// @deprecated Use AppTheme.bodyTextStyle instead
final kBodyTextStyle = AppTheme.bodyTextStyle;

/// @deprecated Use AppTheme.subtitleTextStyle instead
final kSubtitleTextStyle = AppTheme.subtitleTextStyle;