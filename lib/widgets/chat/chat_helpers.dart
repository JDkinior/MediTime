// lib/widgets/chat/chat_helpers.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';

/// Obtiene el perfil de cuidador o mascota activo según el modo actual de la aplicación.
CaregiverProfile? getActiveCaregiverProfile(BuildContext context) {
  try {
    final prefNotifier = context.read<PreferenceNotifier>();
    final caregiverNotifier = context.read<CaregiverNotifier>();
    final isAnimal = prefNotifier.isAnimalMode;
    return (caregiverNotifier.isCaregiverModeActive || isAnimal)
        ? caregiverNotifier.getEffectiveActiveProfile(isAnimalMode: isAnimal)
        : null;
  } catch (_) {
    return null;
  }
}
