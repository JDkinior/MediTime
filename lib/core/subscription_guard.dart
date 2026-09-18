// lib/core/subscription_guard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/notifiers/subscription_notifier.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/screens/subscription/subscription_page.dart';

/// Centralized guard for checking feature access and gating in MediTime.
class SubscriptionGuard {
  SubscriptionGuard._();

  /// Checks if the user can add a new treatment.
  /// If limit is reached, opens SubscriptionPage and returns false.
  static Future<bool> canAddTreatment(BuildContext context) async {
    final subNotifier = context.read<SubscriptionNotifier>();
    if (subNotifier.isPremium) return true;

    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final userId = authService.currentUser?.uid;
    if (userId == null) return true;

    List<Tratamiento>? treatments = firestoreService.getCachedMedicamentos(userId);
    if (treatments == null || treatments.isEmpty) {
      try {
        treatments = await firestoreService
            .getMedicamentosStream(userId)
            .first
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        return true;
      }
    }

    final now = DateTime.now();
    final activeCount = treatments.where((t) => t.fechaFinTratamiento.isAfter(now)).length;

    if (!subNotifier.canAddTreatment(activeCount)) {
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SubscriptionPage(
              sourceFeature: 'más de 3 tratamientos a la vez',
            ),
          ),
        );
      }
      return false;
    }
    return true;
  }

  /// Checks if the user can add a caregiver / animal profile.
  /// If limit is reached, opens SubscriptionPage and returns false.
  static Future<bool> canAddProfile(BuildContext context, {bool isAnimal = false}) async {
    final subNotifier = context.read<SubscriptionNotifier>();
    if (subNotifier.isPremium) return true;

    final caregiverNotifier = context.read<CaregiverNotifier>();
    final currentCount = caregiverNotifier.managedProfiles.length;

    if (!subNotifier.canAddCaregiverProfile(currentCount)) {
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubscriptionPage(
              sourceFeature: isAnimal
                  ? 'perfiles ilimitados de mascotas'
                  : 'perfiles ilimitados de pacientes',
            ),
          ),
        );
      }
      return false;
    }
    return true;
  }

  /// Checks if the user can export PDF reports.
  /// If not premium, opens SubscriptionPage and returns false.
  static Future<bool> canExportPdf(BuildContext context) async {
    final subNotifier = context.read<SubscriptionNotifier>();
    if (subNotifier.canExportPdf) return true;

    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SubscriptionPage(
            sourceFeature: 'la exportación de reportes en PDF para el médico',
          ),
        ),
      );
    }
    return false;
  }

  /// Checks if the user can use voice assistant.
  /// If not premium, opens SubscriptionPage and returns false.
  static Future<bool> canUseVoiceAssistant(BuildContext context) async {
    final subNotifier = context.read<SubscriptionNotifier>();
    if (subNotifier.canUseVoiceAssistant) return true;

    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SubscriptionPage(
            sourceFeature: 'el asistente por voz con Inteligencia Artificial',
          ),
        ),
      );
    }
    return false;
  }

  /// Checks if the user can activate Caregiver Mode.
  /// If not premium, opens SubscriptionPage and returns false.
  static Future<bool> canActivateCaregiverMode(BuildContext context) async {
    final subNotifier = context.read<SubscriptionNotifier>();
    if (subNotifier.isPremium) return true;

    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SubscriptionPage(
            sourceFeature: 'el Modo Cuidador (gestión de familiares y pacientes)',
          ),
        ),
      );
    }
    return false;
  }

  /// Checks if the user can activate Animal Mode.
  /// If not premium, opens SubscriptionPage and returns false.
  static Future<bool> canActivateAnimalMode(BuildContext context) async {
    final subNotifier = context.read<SubscriptionNotifier>();
    if (subNotifier.isPremium) return true;

    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SubscriptionPage(
            sourceFeature: 'el Modo Animales (atención veterinaria y mascotas)',
          ),
        ),
      );
    }
    return false;
  }
}
