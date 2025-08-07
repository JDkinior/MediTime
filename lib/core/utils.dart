// lib/core/utils.dart
import 'package:flutter/material.dart';
import 'package:meditime/core/constants.dart';

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
    if (hour >= AppConstants.morningStartHour && hour < AppConstants.afternoonStartHour) {
      return AppConstants.morningGreeting;
    } else if (hour >= AppConstants.afternoonStartHour && hour < AppConstants.eveningStartHour) {
      return AppConstants.afternoonGreeting;
    } else {
      return AppConstants.eveningGreeting;
    }
  }

  /// Formats a DateTime to a user-friendly date string
  static String formatDate(DateTime date) {
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
      return '${date.day}/${date.month}/${date.year}';
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
  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
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
      builder: (context) => AlertDialog(
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
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
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
      return Colors.red;
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