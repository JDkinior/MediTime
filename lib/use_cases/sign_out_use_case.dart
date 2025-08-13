// lib/use_cases/sign_out_use_case.dart
import 'package:flutter/material.dart';
import 'package:meditime/core/result.dart';
import 'package:meditime/repositories/treatment_repository.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/preference_service.dart';

/// Use case for handling user sign out operations.
/// 
/// This class encapsulates the business logic for signing out a user,
/// including canceling all treatment alarms and notifications.
class SignOutUseCase {
  final TreatmentRepository _treatmentRepository;

  const SignOutUseCase(this._treatmentRepository);

  /// Executes the sign out process for a user.
  /// 
  /// This includes:
  /// - Canceling all treatment alarms for the user
  /// - Canceling all local notifications
  /// 
  /// Returns a Result indicating success or failure.
  Future<Result<void>> execute(String userId) async {
    try {
      debugPrint('SignOutUseCase: Starting sign out process for user $userId');
  final prefs = PreferenceService();
  // Persist the current user id before clear, to allow guards to compare
  await prefs.saveCurrentUserId(userId);
      
      // Get user treatments to cancel their alarms
      final treatmentsResult = await _treatmentRepository.getTreatments(userId);
      
      if (treatmentsResult.isFailure) {
        debugPrint('SignOutUseCase: Failed to get treatments: ${treatmentsResult.error}');
        // Continue with sign out even if we can't get treatments
        // This ensures the user can still sign out if there's a data issue
      } else {
        final treatments = treatmentsResult.data!;
        
        // Cancel alarms for each treatment
        for (var tratamiento in treatments) {
          final alarmId = tratamiento.prescriptionAlarmId;
          if (alarmId != 0) {
            try {
              await NotificationService.cancelTreatmentAlarms(alarmId);
              debugPrint('SignOutUseCase: Canceled alarms for treatment ${tratamiento.id}');
            } catch (e) {
              debugPrint('SignOutUseCase: Error canceling alarms for treatment ${tratamiento.id}: $e');
              // Continue with other treatments even if one fails
            }
          }
          // Mark each treatment as revoked locally to block offline callbacks
          try {
            await NotificationService.revokeTreatmentLocally(userId, tratamiento.id);
          } catch (_) {}
        }
      }
      
      // Cancel all local notifications
      try {
        await NotificationService.cancelAllFlutterLocalNotifications();
        debugPrint('SignOutUseCase: Canceled all local notifications');
      } catch (e) {
        debugPrint('SignOutUseCase: Error canceling local notifications: $e');
        // Continue with sign out even if notification cancellation fails
      }
      // Also cancel any active visible notifications
      await NotificationService.cancelAllActiveAndroidNotifications();
      // Clear any remembered current user, so future callbacks are blocked by guard
      await prefs.clearCurrentUserId();
      // Optionally clear revoked list (not strictly necessary, but keeps it clean)
      await prefs.clearRevokedTreatments();
      
      debugPrint('SignOutUseCase: Sign out process completed successfully');
      return const Result.success(null);
      
    } catch (e) {
      debugPrint('SignOutUseCase: Unexpected error during sign out: $e');
      return Result.failure('Error durante el cierre de sesión: $e');
    }
  }
}