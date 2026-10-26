// lib/core/utils.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/core/constants.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/services/tratamiento_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';

/// Alias for TratamientoService date utility functions
typedef TreatmentDateUtils = TratamientoService;

/// Utility class containing common helper functions used throughout the application.
///
/// This class provides static methods for common operations like time formatting,
/// validation, and UI helpers to avoid code duplication.
class AppUtils {
  // Private constructor to prevent instantiation
  AppUtils._();

  // -------------------
  // Time and Date Utilities
  // -------------------

  /// Formats a TimeOfDay to a string in HH:MM format
  static String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Parses a time string (HH:MM) to TimeOfDay
  static TimeOfDay parseTimeString(String timeString) {
    final parts = timeString.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Formats a DateTime into a standardized 12-hour dose time string (e.g. '05:47 a.m.').
  ///
  /// Guarantees a consistent standard ('hh:mm a.m.' / 'hh:mm p.m.') across all
  /// locales, preventing localized differences like extra spaces (e.g. 'a. m.').
  static String formatDoseTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final hourStr = hour.toString().padLeft(2, '0');
    final minuteStr = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'a.m.' : 'p.m.';
    return '$hourStr:$minuteStr $period';
  }

  /// Formats a TimeOfDay into a standardized 12-hour dose time string (e.g. '05:47 a.m.').
  static String formatDoseTimeOfDay(TimeOfDay time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final hourStr = hour.toString().padLeft(2, '0');
    final minuteStr = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'a.m.' : 'p.m.';
    return '$hourStr:$minuteStr $period';
  }

  /// Returns the indicator color for a dose time based on its status.
  ///
  /// - tomada: green (AppTheme.successColor)
  /// - omitida: red (AppTheme.errorColor)
  /// - notificada / pendiente pasada: yellow (Colors.amber)
  /// - aplazada: orange (Colors.orange)
  /// - pendiente futura: AppTheme.primaryColor
  static Color getDoseStatusColor(DoseStatus status, {bool isPast = false}) {
    switch (status) {
      case DoseStatus.tomada:
        return AppTheme.successColor;
      case DoseStatus.omitida:
        return AppTheme.errorColor;
      case DoseStatus.aplazada:
        return Colors.orange;
      case DoseStatus.notificada:
        return Colors.amber;
      case DoseStatus.pendiente:
        return isPast ? Colors.amber : AppTheme.primaryColor;
    }
  }

  /// Formats a Duration to a human-readable string
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} día${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hora${duration.inHours > 1 ? 's' : ''}';
    } else {
      return '${duration.inMinutes} minuto${duration.inMinutes > 1 ? 's' : ''}';
    }
  }

  /// Gets the appropriate greeting based on current time
  static String getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= AppConstants.morningStartHour &&
        hour < AppConstants.afternoonStartHour) {
      return AppConstants.morningGreeting;
    } else if (hour >= AppConstants.afternoonStartHour &&
        hour < AppConstants.eveningStartHour) {
      return AppConstants.afternoonGreeting;
    } else {
      return AppConstants.eveningGreeting;
    }
  }

  /// Gets the appropriate greeting based on current time and app language
  static String getLocalizedGreeting(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hour = DateTime.now().hour;
    if (hour >= AppConstants.morningStartHour &&
        hour < AppConstants.afternoonStartHour) {
      return l10n?.homeGreetingMorning ?? AppConstants.morningGreeting;
    } else if (hour >= AppConstants.afternoonStartHour &&
        hour < AppConstants.eveningStartHour) {
      return l10n?.homeGreetingAfternoon ?? AppConstants.afternoonGreeting;
    } else {
      return l10n?.homeGreetingEvening ?? AppConstants.eveningGreeting;
    }
  }

  /// Localizes a medication presentation (e.g. Sobres -> Sachets)
  static String localizePresentation(
    BuildContext context,
    String presentation,
  ) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return presentation;
    switch (presentation.toLowerCase().trim()) {
      case 'comprimidos':
        return l10n.presentationComprimidos;
      case 'grageas':
        return l10n.presentationGrageas;
      case 'cápsulas':
      case 'capsulas':
        return l10n.presentationCapsulas;
      case 'sobres':
        return l10n.presentationSobres;
      case 'jarabes':
        return l10n.presentationJarabes;
      case 'gotas':
        return l10n.presentationGotas;
      case 'suspensiones':
        return l10n.presentationSuspensiones;
      case 'emulsiones':
        return l10n.presentationEmulsiones;
      default:
        return presentation;
    }
  }

  /// Formats a DateTime using 2 numeric digits for day, month and year
  /// according to the specified language/locale (e.g., 'MM/dd/yy' for English, 'dd/MM/yy' for Spanish/Portuguese).
  static String formatTwoDigitDate(DateTime date, [String? localeCode]) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = (date.year % 100).toString().padLeft(2, '0');
    final lang = (localeCode ?? 'es').toLowerCase();
    if (lang.startsWith('en') && !lang.startsWith('en_gb')) {
      return '$mm/$dd/$yy';
    }
    return '$dd/$mm/$yy';
  }

  /// Formats a DateTime to a user-friendly date string
  static String formatDate(DateTime date, [String? localeCode]) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Hoy';
    } else if (dateToCheck == today.subtract(const Duration(days: 1))) {
      return 'Ayer';
    } else if (dateToCheck == today.add(const Duration(days: 1))) {
      return 'Mañana';
    } else {
      return formatTwoDigitDate(date, localeCode);
    }
  }

  // -------------------
  // Validation Utilities
  // -------------------

  /// Validates an email address
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validates a password
  static bool isValidPassword(String password) {
    return password.length >= AppConstants.minPasswordLength;
  }

  /// Validates a name
  static bool isValidName(String name) {
    return name.isNotEmpty &&
        name.length <= AppConstants.maxNameLength &&
        RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(name);
  }

  /// Validates a phone number (basic validation)
  static bool isValidPhone(String phone) {
    return RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(phone);
  }

  // -------------------
  // UI Utilities
  // -------------------

  /// Shows a snackbar with the given message
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : null,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppConstants.defaultPadding),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
        ),
      ),
    );
  }

  /// Shows a loading dialog
  static void showLoadingDialog(BuildContext context, {String? message}) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                if (message != null) ...[
                  const SizedBox(height: AppConstants.defaultPadding),
                  Text(message),
                ],
              ],
            ),
          ),
    );
  }

  /// Dismisses any open dialogs
  static void dismissDialog(BuildContext context) {
    if (context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  /// Shows a confirmation dialog
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
  }) async {
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.40),
      builder: (dialogCtx) {
        PreferenceNotifier? pref;
        try {
          pref = dialogCtx.watch<PreferenceNotifier>();
        } catch (_) {}
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        final isModern = pref?.interfaceStyle == 'modern' || pref == null;
        final highContrast = pref?.highContrast ?? false;
        final useGlass = isModern && !highContrast;

        if (!useGlass) {
          return AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: Text(cancelText),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: Text(confirmText),
              ),
            ],
          );
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          elevation: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: useGlass
                      ? (isDark
                          ? Theme.of(dialogCtx).cardColor.withValues(alpha: 0.78)
                          : Colors.white.withValues(alpha: 0.85))
                      : Theme.of(dialogCtx).cardColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: useGlass
                        ? (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.15 : 0.08)
                        : ((pref?.showCardBorder ?? false) || highContrast ? AppTheme.borderColor : Colors.transparent),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.secondaryTextColor,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(cancelText, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  // -------------------
  // String Utilities
  // -------------------

  /// Capitalizes the first letter of a string
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Truncates a string to the specified length with ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Removes extra whitespace and normalizes a string
  static String normalizeString(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  // -------------------
  // Color Utilities
  // -------------------

  /// Gets a color based on adherence percentage
  static Color getAdherenceColor(double percentage) {
    if (percentage >= 0.8) {
      return Colors.green;
    } else if (percentage >= 0.6) {
      return Colors.orange;
    } else {
      return AppTheme.errorColor;
    }
  }

  /// Converts a hex color string to Color
  static Color hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex'; // Add alpha if not provided
    }
    return Color(int.parse(hex, radix: 16));
  }

  // -------------------
  // List Utilities
  // -------------------

  /// Safely gets an item from a list at the specified index
  static T? safeGet<T>(List<T> list, int index) {
    if (index >= 0 && index < list.length) {
      return list[index];
    }
    return null;
  }

  /// Chunks a list into smaller lists of the specified size
  static List<List<T>> chunk<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (int i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, (i + chunkSize).clamp(0, list.length)));
    }
    return chunks;
  }
}
