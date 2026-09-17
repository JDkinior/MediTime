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
  static Color primaryColor = const Color(0xFF004AC6);

  /// Secondary color for secondary active elements.
  static Color secondaryColor = const Color(0xFF006C49);

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

  /// Track current theme mode state
  static bool currentIsDark = false;
  static bool currentIsAnimalMode = false;

  /// Updates static colors to match light or dark mode, high contrast, and animal mode.
  static void updateThemeColors(bool isDark, {bool highContrast = false, bool isAnimalMode = false}) {
    currentIsDark = isDark;
    currentIsAnimalMode = isAnimalMode;

    if (isAnimalMode) {
      primaryColor = const Color(0xFF15803D); // Verde veterinario esmeralda/médico
      secondaryColor = const Color(0xFF047857);
    } else {
      primaryColor = const Color(0xFF004AC6);
      secondaryColor = const Color(0xFF006C49);
    }

    if (highContrast) {
      backgroundColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
      primaryTextColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
      secondaryTextColor = isDark ? const Color(0xFFCCCCCC) : const Color(0xFF333333);
      surfaceColor = isDark ? const Color(0xFF16181F) : const Color(0xFFF0F0F0);
      cardColor = isDark ? const Color(0xFF1F232D) : const Color(0xFFFFFFFF);
      borderColor = isDark ? const Color(0xFF444444) : const Color(0xFFBBBBBB);
    } else if (isAnimalMode) {
      backgroundColor = isDark ? const Color(0xFF0D1711) : const Color(0xFFF3FAF6);
      primaryTextColor = isDark ? const Color(0xFFE2EBE5) : const Color(0xFF0B2618);
      secondaryTextColor = isDark ? const Color(0xFF8CA595) : const Color(0xFF3A5445);
      surfaceColor = isDark ? const Color(0xFF132219) : const Color(0xFFEDF8F1);
      cardColor = isDark ? const Color(0xFF18291F) : Colors.white;
      borderColor = isDark ? const Color(0xFF233E2F) : const Color(0xFFD6EFE0);
    } else {
      backgroundColor = isDark ? const Color(0xFF111318) : const Color(0xFFF8F9FF);
      primaryTextColor = isDark ? const Color(0xFFE2E2E9) : const Color(0xFF0B1C30);
      secondaryTextColor = isDark ? const Color(0xFF9093A5) : const Color(0xFF434655);
      surfaceColor = isDark ? const Color(0xFF191C24) : const Color(0xFFEFF4FF);
      cardColor = isDark ? const Color(0xFF1F232D) : Colors.white;
      borderColor = isDark ? const Color(0xFF2E3342) : const Color(0xFFEFF3F9);
    }
  }

  // -------------------
  // Gradients
  // -------------------

  /// Primary gradient used throughout the app
  static LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      primaryColor,
      currentIsAnimalMode ? const Color(0xFF22C55E) : const Color(0xFF2563EB),
    ],
  );

  /// Header gradient for app bars and headers
  static LinearGradient get headerGradient => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      primaryColor,
      currentIsAnimalMode ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
    ],
  );

  // -------------------
  // Shadows and Borders
  // -------------------

  /// Standard card shadow used throughout the application.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: currentIsDark ? Colors.black.withValues(alpha: 0.32) : const Color(0x0A000000),
      blurRadius: currentIsDark ? 10 : 15,
      spreadRadius: 0,
      offset: const Offset(0, 4),
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
  static TextStyle get pageTitleStyle => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: secondaryColor,
  );

  /// Section title style
  static TextStyle get sectionTitleStyle => TextStyle(
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
      borderSide: BorderSide(color: primaryColor, width: 2),
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
  static ElevatedButtonThemeData getElevatedButtonTheme({bool largeButtons = false}) => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: largeButtons ? const Size(64, 64) : null,
      backgroundColor: primaryColor,
      foregroundColor: whiteTextColor,
      textStyle: buttonTextStyle.copyWith(fontSize: largeButtons ? 18 : 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(defaultBorderRadius),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.largePadding,
        vertical: largeButtons ? 20 : AppConstants.defaultPadding,
      ),
    ),
  );

  /// Card theme
  static CardThemeData getCardTheme({bool showCardBorder = false}) => CardThemeData(
    color: cardColor,
    shadowColor: const Color.fromARGB(40, 0, 0, 0),
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(defaultBorderRadius),
      side: showCardBorder ? BorderSide(color: borderColor, width: 1) : BorderSide.none,
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
  static ThemeData getLightTheme({bool largeButtons = false, bool showCardBorder = false}) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    cardColor: cardColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      surface: backgroundColor,
      surfaceContainer: cardColor,
      surfaceContainerHigh: cardColor,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: backgroundColor,
    dialogTheme: DialogThemeData(
      backgroundColor: cardColor,
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: appBarTheme.copyWith(
      backgroundColor: backgroundColor,
      foregroundColor: primaryTextColor,
      systemOverlayStyle: SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light, systemNavigationBarColor: backgroundColor, systemNavigationBarIconBrightness: Brightness.dark, systemNavigationBarDividerColor: Colors.transparent, systemNavigationBarContrastEnforced: false),
      titleTextStyle: TextStyle(color: primaryTextColor, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    inputDecorationTheme: inputDecorationTheme,
    elevatedButtonTheme: getElevatedButtonTheme(largeButtons: largeButtons),
    cardTheme: getCardTheme(showCardBorder: showCardBorder),
    textTheme: TextTheme(
      headlineLarge: pageTitleStyle,
      headlineMedium: sectionTitleStyle,
      bodyLarge: bodyTextStyle,
      bodyMedium: subtitleTextStyle,
      labelLarge: buttonTextStyle,
      bodySmall: captionTextStyle,
    ),
  );

  /// Dark theme configuration
  static ThemeData getDarkTheme({bool largeButtons = false, bool showCardBorder = false}) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    cardColor: cardColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      surface: backgroundColor,
      surfaceContainer: cardColor,
      surfaceContainerHigh: cardColor,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: backgroundColor,
    dialogTheme: DialogThemeData(
      backgroundColor: cardColor,
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: appBarTheme.copyWith(
      backgroundColor: backgroundColor,
      foregroundColor: primaryTextColor,
      systemOverlayStyle: SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, statusBarBrightness: Brightness.dark, systemNavigationBarColor: backgroundColor, systemNavigationBarIconBrightness: Brightness.light, systemNavigationBarDividerColor: Colors.transparent, systemNavigationBarContrastEnforced: false),
      titleTextStyle: TextStyle(color: primaryTextColor, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    inputDecorationTheme: inputDecorationTheme,
    elevatedButtonTheme: getElevatedButtonTheme(largeButtons: largeButtons),
    cardTheme: getCardTheme(showCardBorder: showCardBorder),
    textTheme: TextTheme(
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
Color get kPrimaryColor => AppTheme.primaryColor;

/// @deprecated Use AppTheme.secondaryColor instead
Color get kSecondaryColor => AppTheme.secondaryColor;

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