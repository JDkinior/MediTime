import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Modos de recordatorio para la gestión de tomas de medicamentos.
enum DoseReminderMode {
  /// Notificación informativa breve. La toma se marca como tomada automáticamente.
  automatic,

  /// Notificación interactiva estándar con botones de acción (Tomar, Omitir, Aplazar).
  active,

  /// Alarma sonora continua (tono en bucle y vibración) con pantalla completa interactiva.
  alarm;

  static DoseReminderMode fromString(String? val) {
    switch (val) {
      case 'active':
        return DoseReminderMode.active;
      case 'alarm':
        return DoseReminderMode.alarm;
      case 'automatic':
      default:
        return DoseReminderMode.automatic;
    }
  }

  String toValue() {
    switch (this) {
      case DoseReminderMode.active:
        return 'active';
      case DoseReminderMode.alarm:
        return 'alarm';
      case DoseReminderMode.automatic:
        return 'automatic';
    }
  }
}

class PreferenceService {
  static const String _reminderModeKey = 'reminder_mode_type';
  static const String _notificationModeKey = 'notification_mode_active';
  static const String _snoozeDurationKey = 'snooze_duration_minutes';
  static const String _currentUserIdKey = 'current_user_id';
  static const String _revokedTreatmentsKey = 'revoked_treatments'; // String list of "userId|docId"
  static const String _tutorialShownPrefix = 'tutorial_shown_';
  static const String _calendarFormatKey = 'calendar_format_string';
  static const String _interfaceStyleKey = 'interface_style_string';
  static const String _themeModeKey = 'theme_mode_string';
  static const String _languageCodeKey = 'app_language_code';

  // Alarm Sound keys
  static const String _alarmSoundTypeKey = 'alarm_sound_type';
  static const String _alarmSoundTitleKey = 'alarm_sound_title';
  static const String _alarmSoundUriKey = 'alarm_sound_uri';
  static const String _alarmSoundResourceKey = 'alarm_sound_resource';

  // Accessibility keys
  static const String _highContrastKey = 'high_contrast_active';
  static const String _largeTextKey = 'large_text_active';
  static const String _largeButtonsKey = 'large_buttons_active';
  static const String _simplifiedInterfaceKey = 'simplified_interface_active';
  static const String _showCardBorderKey = 'show_card_border_active';
  static const String _enableScrollFadeKey = 'enable_scroll_fade_active';

  // Caregiver Mode keys
  static const String _caregiverModeActiveKey = 'caregiver_mode_active';
  static const String _caregiverModeTypeKey = 'caregiver_mode_type';
  static const String _caregiverActiveProfileKey = 'caregiver_active_profile';
  static const String _caregiverNotifyPatientDosesKey = 'caregiver_notify_patient_doses';
  static const String _caregiverIncludeLocationKey = 'caregiver_include_location';

  // Privacy keys
  static const String _hideMedicineNameOnLockScreenKey = 'hide_medicine_name_on_lock_screen';
  static const String _secureScreenKey = 'secure_screen_active';

  // Animal / Veterinary Mode keys
  static const String _animalModeActiveKey = 'animal_mode_active';
  static const String _animalModeTypeKey = 'animal_mode_type';
  static const String _animalActiveProfileKey = 'animal_active_profile';
  static const String _animalNotifyDosesKey = 'animal_notify_doses';
  static const String _animalIncludeLocationKey = 'animal_include_location';

  // Onboarding & Terms keys
  static const String _onboardingCompletedPrefix = 'onboarding_completed_';
  static const String _termsAcceptedPrefix = 'terms_accepted_';
  static const String _termsAcceptedAtPrefix = 'terms_accepted_at_';
  static const String _termsAcceptedVersionPrefix = 'terms_accepted_version_';

  // Profile cache keys
  static const String _cachedUserNameKey = 'cached_user_name';
  static const String _cachedProfileImageUrlKey = 'cached_profile_image_url';
  static const String _cachedProfileLocalPathKey = 'cached_profile_local_path';

  // Animal & Caregiver Profile & Alarm tracking keys
  static const String _animalProfileIdsKey = 'animal_profile_ids';
  static const String _caregiverProfileIdsKey = 'caregiver_profile_ids';
  static const String _caregiverAlarmIdsKey = 'caregiver_alarm_ids';
  static const String _animalAlarmIdsKey = 'animal_alarm_ids';

  /// Recarga una sola vez el estado en disco de SharedPreferences (útil para lecturas por lotes o en isolates de fondo).
  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }

  // Offline resilience: Local dose statuses, pending sync actions, and schedule cache
  static const String _localDoseStatusPrefix = 'local_dose_status_';
  static const String _pendingOfflineActionsKey = 'pending_offline_dose_actions';
  static const String _treatmentScheduleCacheKey = 'treatment_schedule_cache_map';

  Future<void> saveThemeMode(String themeStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, themeStr);
  }

  Future<String> getThemeMode({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getString(_themeModeKey) ?? 'system';
  }

  Future<void> saveLanguageCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, code);
  }

  Future<String> getLanguageCode({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getString(_languageCodeKey) ?? 'system';
  }

  Future<void> saveInterfaceStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_interfaceStyleKey, style);
  }

  Future<String> getInterfaceStyle({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getString(_interfaceStyleKey) ?? 'classic';
  }

  Future<void> saveEnableScrollFade(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableScrollFadeKey, value);
  }

  Future<bool> getEnableScrollFade({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getBool(_enableScrollFadeKey) ?? true;
  }

  Future<void> saveCalendarFormat(String format) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_calendarFormatKey, format);
  }

  Future<String> getCalendarFormat({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getString(_calendarFormatKey) ?? 'weekly';
  }

  Future<void> saveReminderMode(DoseReminderMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reminderModeKey, mode.toValue());
    // Mantener sincronizado el valor legacy para retrocompatibilidad
    await prefs.setBool(_notificationModeKey, mode == DoseReminderMode.active);
  }

  Future<DoseReminderMode> getReminderMode({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    final modeStr = prefs.getString(_reminderModeKey);
    if (modeStr != null && modeStr.isNotEmpty) {
      return DoseReminderMode.fromString(modeStr);
    }
    // Fallback a la clave legacy booleana si existe
    final legacyActive = prefs.getBool(_notificationModeKey);
    if (legacyActive != null) {
      return legacyActive ? DoseReminderMode.active : DoseReminderMode.automatic;
    }
    return DoseReminderMode.automatic;
  }

  Future<void> saveNotificationMode(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationModeKey, isActive);
    await prefs.setString(
      _reminderModeKey,
      isActive ? DoseReminderMode.active.toValue() : DoseReminderMode.automatic.toValue(),
    );
  }

  // --- INICIO DE LA MODIFICACIÓN ---
  Future<bool> getNotificationMode({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Forzamos la recarga de los datos desde el disco.
    // Esto es crucial para que el proceso en segundo plano obtenga el valor más reciente.
    if (reload) await prefs.reload();

    // 2. Si se guardó el nuevo modo, revisamos si es 'active'
    final modeStr = prefs.getString(_reminderModeKey);
    if (modeStr != null) {
      return modeStr == DoseReminderMode.active.toValue();
    }

    // 3. De lo contrario leemos el valor legacy
    return prefs.getBool(_notificationModeKey) ?? false;
  }

  Future<void> saveSnoozeDuration(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_snoozeDurationKey, minutes);
  }

  /// Obtiene la duración de aplazamiento guardada.
  /// Devuelve `10` minutos por defecto si no se ha guardado nada.
  Future<int> getSnoozeDuration({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getInt(_snoozeDurationKey) ?? 10;
  }

  Future<void> saveAlarmSound({
    required String type,
    required String title,
    String? uri,
    String? resourceName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alarmSoundTypeKey, type);
    await prefs.setString(_alarmSoundTitleKey, title);
    if (uri != null && uri.isNotEmpty) {
      await prefs.setString(_alarmSoundUriKey, uri);
    } else {
      await prefs.remove(_alarmSoundUriKey);
    }
    if (resourceName != null && resourceName.isNotEmpty) {
      await prefs.setString(_alarmSoundResourceKey, resourceName);
    } else {
      await prefs.remove(_alarmSoundResourceKey);
    }
  }

  Future<String> getAlarmSoundType({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getString(_alarmSoundTypeKey) ?? 'system_alarm';
  }

  Future<String> getAlarmSoundTitle({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getString(_alarmSoundTitleKey) ?? 'Alarma del teléfono (Predeterminada)';
  }

  Future<String?> getAlarmSoundUri({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    final type = prefs.getString(_alarmSoundTypeKey) ?? 'system_alarm';
    if (type == 'custom') {
      return null;
    }
    return prefs.getString(_alarmSoundUriKey) ?? 'content://settings/system/alarm_alert';
  }

  Future<String?> getAlarmSoundResource({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getString(_alarmSoundResourceKey);
  }

  // --- Accesibilidad ---
  Future<void> saveHighContrast(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highContrastKey, isActive);
  }

  Future<bool> getHighContrast({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getBool(_highContrastKey) ?? false;
  }

  Future<void> saveLargeText(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_largeTextKey, isActive);
  }

  Future<bool> getLargeText({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getBool(_largeTextKey) ?? false;
  }

  Future<void> saveLargeButtons(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_largeButtonsKey, isActive);
  }

  Future<bool> getLargeButtons({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getBool(_largeButtonsKey) ?? false;
  }

  Future<void> saveSimplifiedInterface(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_simplifiedInterfaceKey, isActive);
  }

  Future<bool> getSimplifiedInterface({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getBool(_simplifiedInterfaceKey) ?? false;
  }

  Future<void> saveShowCardBorder(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showCardBorderKey, isActive);
  }

  Future<bool> getShowCardBorder({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getBool(_showCardBorderKey) ?? false;
  }

  // --- Sesión de usuario actual ---
  Future<void> saveCurrentUserId(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId == null) {
      await prefs.remove(_currentUserIdKey);
    } else {
      await prefs.setString(_currentUserIdKey, userId);
    }
  }

  Future<String?> getCurrentUserId({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getString(_currentUserIdKey);
  }

  Future<void> clearCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserIdKey);
  }

  // --- Tratamientos revocados localmente (para cortar callbacks offline) ---
  Future<void> addRevokedTreatment(String userId, String docId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$userId|$docId';
    final list = (prefs.getStringList(_revokedTreatmentsKey) ?? <String>[]).toSet();
    list.add(key);
    await prefs.setStringList(_revokedTreatmentsKey, list.toList());
    await removeTreatmentScheduleCache(userId, docId);
    await clearLocalDoseStatusesForTreatment(userId, docId);
  }

  Future<void> removeRevokedTreatment(String userId, String docId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$userId|$docId';
    final list = (prefs.getStringList(_revokedTreatmentsKey) ?? <String>[]).toSet();
    list.remove(key);
    await prefs.setStringList(_revokedTreatmentsKey, list.toList());
  }

  Future<bool> isTreatmentRevoked(String userId, String docId, {bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    final key = '$userId|$docId';
    final list = prefs.getStringList(_revokedTreatmentsKey) ?? <String>[];
    return list.contains(key);
  }

  Future<void> clearRevokedTreatments() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_revokedTreatmentsKey);
  }

  // --- Tutorial de bienvenida (por usuario) ---
  Future<bool> hasTutorialBeenShown(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_tutorialShownPrefix$userId') ?? false;
  }

  Future<void> markTutorialShown(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_tutorialShownPrefix$userId', true);
  }

  // --- Caregiver Mode ---
  Future<void> saveCaregiverModeActive(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_caregiverModeActiveKey, isActive);
  }

  Future<bool> getCaregiverModeActive({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getBool(_caregiverModeActiveKey) ?? false;
  }

  Future<void> saveCaregiverModeType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_caregiverModeTypeKey, type);
  }

  Future<String> getCaregiverModeType({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getString(_caregiverModeTypeKey) ?? 'familiar';
  }

  Future<void> saveCaregiverActiveProfile(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    if (profileId == null) {
      await prefs.remove(_caregiverActiveProfileKey);
    } else {
      await prefs.setString(_caregiverActiveProfileKey, profileId);
    }
  }

  Future<String?> getCaregiverActiveProfile({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getString(_caregiverActiveProfileKey);
  }

  Future<void> saveCaregiverNotifyPatientDoses(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_caregiverNotifyPatientDosesKey, val);
  }

  Future<bool> getCaregiverNotifyPatientDoses({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getBool(_caregiverNotifyPatientDosesKey) ?? true;
  }

  Future<void> saveCaregiverIncludeLocation(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_caregiverIncludeLocationKey, val);
  }

  Future<bool> getCaregiverIncludeLocation({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getBool(_caregiverIncludeLocationKey) ?? true;
  }

  Future<void> saveHideMedicineNameOnLockScreen(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideMedicineNameOnLockScreenKey, val);
  }

  Future<bool> getHideMedicineNameOnLockScreen({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getBool(_hideMedicineNameOnLockScreenKey) ?? false;
  }

  Future<void> saveSecureScreen(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_secureScreenKey, val);
  }

  Future<bool> getSecureScreen({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getBool(_secureScreenKey) ?? false;
  }

  Future<void> saveOnboardingCompleted(String userId, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_onboardingCompletedPrefix$userId', val);
  }

  Future<bool> hasCompletedOnboarding(String userId, {bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getBool('$_onboardingCompletedPrefix$userId') ?? false;
  }

  Future<void> saveTermsAccepted(
    String userId, {
    required bool accepted,
    String version = '2.36.0',
    DateTime? timestamp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_termsAcceptedPrefix$userId', accepted);
    if (accepted) {
      final timeStr = (timestamp ?? DateTime.now()).toIso8601String();
      await prefs.setString('$_termsAcceptedAtPrefix$userId', timeStr);
      await prefs.setString('$_termsAcceptedVersionPrefix$userId', version);
    }
  }

  Future<bool> hasAcceptedTerms(String userId, {bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getBool('$_termsAcceptedPrefix$userId') ?? false;
  }

  Future<String?> getTermsAcceptedAt(String userId, {bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getString('$_termsAcceptedAtPrefix$userId');
  }

  Future<String?> getTermsAcceptedVersion(String userId, {bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getString('$_termsAcceptedVersionPrefix$userId');
  }

  // --- Animal / Veterinary Mode ---
  Future<void> saveAnimalModeActive(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_animalModeActiveKey, isActive);
  }

  Future<bool> getAnimalModeActive({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getBool(_animalModeActiveKey) ?? false;
  }

  Future<void> saveAnimalModeType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_animalModeTypeKey, type);
  }

  Future<String> getAnimalModeType({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getString(_animalModeTypeKey) ?? 'individual';
  }

  Future<void> saveAnimalActiveProfile(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    if (profileId == null) {
      await prefs.remove(_animalActiveProfileKey);
    } else {
      await prefs.setString(_animalActiveProfileKey, profileId);
    }
  }

  Future<String?> getAnimalActiveProfile({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getString(_animalActiveProfileKey);
  }

  Future<void> saveAnimalNotifyDoses(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_animalNotifyDosesKey, val);
  }

  Future<bool> getAnimalNotifyDoses({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getBool(_animalNotifyDosesKey) ?? true;
  }

  Future<void> saveAnimalIncludeLocation(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_animalIncludeLocationKey, val);
  }

  Future<bool> getAnimalIncludeLocation({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getBool(_animalIncludeLocationKey) ?? true;
  }

  // --- AI Treatment Tips Cache ---
  static const String _cachedAiTipsKey = 'cached_ai_tips_json';
  static const String _cachedAiTipsFingerprintKey = 'cached_ai_tips_fingerprint';
  static const String _cachedAiTipsTimestampKey = 'cached_ai_tips_timestamp';

  Future<void> saveCachedAiTips({
    required String fingerprint,
    required List<Map<String, String>> tips,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(tips);
      final now = DateTime.now().millisecondsSinceEpoch;
      // Guardar tanto en el slot global como en el slot específico por fingerprint/perfil
      await prefs.setString(_cachedAiTipsKey, jsonStr);
      await prefs.setString(_cachedAiTipsFingerprintKey, fingerprint);
      await prefs.setInt(_cachedAiTipsTimestampKey, now);

      final hashedKey = 'ai_tips_${fingerprint.hashCode}';
      await prefs.setString('${_cachedAiTipsKey}_$hashedKey', jsonStr);
      await prefs.setString('${_cachedAiTipsFingerprintKey}_$hashedKey', fingerprint);
      await prefs.setInt('${_cachedAiTipsTimestampKey}_$hashedKey', now);
    } catch (_) {}
  }

  Future<List<Map<String, String>>?> getCachedAiTips({
    required String currentFingerprint,
    Duration maxAge = const Duration(hours: 12),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hashedKey = 'ai_tips_${currentFingerprint.hashCode}';

      // 1. Intentar slot específico del perfil/modo
      String? savedFingerprint = prefs.getString('${_cachedAiTipsFingerprintKey}_$hashedKey');
      int? savedTimestamp = prefs.getInt('${_cachedAiTipsTimestampKey}_$hashedKey');
      String? savedJson = prefs.getString('${_cachedAiTipsKey}_$hashedKey');

      // 2. Si no existe, revisar slot global
      if (savedJson == null || savedFingerprint == null || savedTimestamp == null) {
        savedFingerprint = prefs.getString(_cachedAiTipsFingerprintKey);
        savedTimestamp = prefs.getInt(_cachedAiTipsTimestampKey);
        savedJson = prefs.getString(_cachedAiTipsKey);
      }

      if (savedJson == null || savedFingerprint == null || savedTimestamp == null) {
        return null;
      }

      if (savedFingerprint != currentFingerprint) {
        return null;
      }

      final age = DateTime.now().millisecondsSinceEpoch - savedTimestamp;
      if (age > maxAge.inMilliseconds) {
        return null;
      }

      final decoded = jsonDecode(savedJson);
      if (decoded is List) {
        final List<Map<String, String>> result = [];
        for (var item in decoded) {
          if (item is Map) {
            result.add({
              'title': item['title']?.toString() ?? '',
              'content': item['content']?.toString() ?? '',
              'isAi': item['isAi']?.toString() ?? 'true',
            });
          }
        }
        if (result.isNotEmpty) return result;
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveUserProfileCache({
    String? name,
    String? imageUrl,
    String? localImagePath,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (name != null) await prefs.setString(_cachedUserNameKey, name);
      if (imageUrl != null) await prefs.setString(_cachedProfileImageUrlKey, imageUrl);
      if (localImagePath != null) await prefs.setString(_cachedProfileLocalPathKey, localImagePath);
    } catch (_) {}
  }

  Future<Map<String, String?>> getUserProfileCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'name': prefs.getString(_cachedUserNameKey),
        'imageUrl': prefs.getString(_cachedProfileImageUrlKey),
        'localImagePath': prefs.getString(_cachedProfileLocalPathKey),
      };
    } catch (_) {
      return {'name': null, 'imageUrl': null, 'localImagePath': null};
    }
  }

  Future<void> clearUserProfileCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedUserNameKey);
      await prefs.remove(_cachedProfileImageUrlKey);
      await prefs.remove(_cachedProfileLocalPathKey);
    } catch (_) {}
  }

  /// Limpia absolutamente todos los datos locales asociados a un usuario eliminado (Derecho al Olvido / RGPD).
  Future<void> clearAllUserData(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keysToRemove = <String>{
        _currentUserIdKey,
        _revokedTreatmentsKey,
        _cachedUserNameKey,
        _cachedProfileImageUrlKey,
        _cachedProfileLocalPathKey,
        _cachedAiTipsKey,
        _cachedAiTipsFingerprintKey,
        _cachedAiTipsTimestampKey,
        _caregiverActiveProfileKey,
        _animalActiveProfileKey,
        _caregiverProfileIdsKey,
        _animalProfileIdsKey,
        _caregiverAlarmIdsKey,
        _animalAlarmIdsKey,
        '$_onboardingCompletedPrefix$userId',
        '$_termsAcceptedPrefix$userId',
        '$_termsAcceptedAtPrefix$userId',
        '$_termsAcceptedVersionPrefix$userId',
        '$_tutorialShownPrefix$userId',
      };

      for (final key in prefs.getKeys().toList()) {
        if (keysToRemove.contains(key) ||
            key.startsWith(_cachedAiTipsKey) ||
            key.startsWith(_cachedAiTipsFingerprintKey) ||
            key.startsWith(_cachedAiTipsTimestampKey) ||
            key.contains(userId)) {
          await prefs.remove(key);
        }
      }
    } catch (_) {}
  }

  // --- Profile categorization & Alarm ID tracking ---
  Future<void> saveAnimalProfileIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_animalProfileIdsKey, ids);
  }

  Future<List<String>> getAnimalProfileIds({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getStringList(_animalProfileIdsKey) ?? [];
  }

  Future<bool> isAnimalProfile(String profileId, {bool reload = true}) async {
    final ids = await getAnimalProfileIds(reload: reload);
    return ids.contains(profileId);
  }

  Future<void> saveCaregiverProfileIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_caregiverProfileIdsKey, ids);
  }

  Future<List<String>> getCaregiverProfileIds({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs.getStringList(_caregiverProfileIdsKey) ?? [];
  }

  Future<bool> isCaregiverProfile(String profileId, {bool reload = true}) async {
    final ids = await getCaregiverProfileIds(reload: reload);
    return ids.contains(profileId);
  }

  // --- Caregiver Alarm IDs ---
  Future<void> saveCaregiverAlarmIds(List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_caregiverAlarmIdsKey, ids.map((e) => e.toString()).toList());
  }

  Future<List<int>> getCaregiverAlarmIds({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    final list = prefs.getStringList(_caregiverAlarmIdsKey) ?? [];
    return list.map((e) => int.tryParse(e)).whereType<int>().toList();
  }

  Future<void> addCaregiverAlarmId(int id) async {
    final ids = await getCaregiverAlarmIds();
    if (!ids.contains(id)) {
      ids.add(id);
      await saveCaregiverAlarmIds(ids);
    }
  }

  Future<void> removeCaregiverAlarmId(int id) async {
    final ids = await getCaregiverAlarmIds();
    if (ids.remove(id)) {
      await saveCaregiverAlarmIds(ids);
    }
  }

  Future<void> clearCaregiverAlarmIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_caregiverAlarmIdsKey);
  }

  // --- Animal Alarm IDs ---
  Future<void> saveAnimalAlarmIds(List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_animalAlarmIdsKey, ids.map((e) => e.toString()).toList());
  }

  Future<List<int>> getAnimalAlarmIds({bool reload = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    final list = prefs.getStringList(_animalAlarmIdsKey) ?? [];
    return list.map((e) => int.tryParse(e)).whereType<int>().toList();
  }

  Future<void> addAnimalAlarmId(int id) async {
    final ids = await getAnimalAlarmIds();
    if (!ids.contains(id)) {
      ids.add(id);
      await saveAnimalAlarmIds(ids);
    }
  }

  Future<void> removeAnimalAlarmId(int id) async {
    final ids = await getAnimalAlarmIds();
    if (ids.remove(id)) {
      await saveAnimalAlarmIds(ids);
    }
  }

  Future<void> clearAnimalAlarmIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_animalAlarmIdsKey);
  }

  // --- Offline Dose Status Ledger & Pending Sync Queue ---

  String _doseLedgerKey(String userId, String docId) =>
      '$_localDoseStatusPrefix${userId}_$docId';

  /// Guarda inmediatamente en almacenamiento local el estado de una dosis.
  /// Si [preventOverwriteCompleted] es true y la dosis ya estaba marcada como
  /// 'tomada' u 'omitida' (dentro de la tolerancia), no se sobrescribe con 'notificada'.
  Future<bool> saveLocalDoseStatus({
    required String userId,
    required String docId,
    required DateTime doseTime,
    required String status,
    String? profileId,
    bool queueForSync = false,
    bool preventOverwriteCompleted = false,
    int toleranceMinutes = 60,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final key = _doseLedgerKey(userId, docId);
      final rawJson = prefs.getString(key);
      final Map<String, String> ledger = {};
      if (rawJson != null && rawJson.isNotEmpty) {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (k is String && v != null) {
              ledger[k] = v.toString();
            }
          });
        }
      }

      String targetIso = doseTime.toIso8601String();
      for (final existingIso in ledger.keys) {
        final dt = DateTime.tryParse(existingIso);
        if (dt != null && dt.difference(doseTime).inMinutes.abs() <= toleranceMinutes) {
          targetIso = existingIso;
          break;
        }
      }

      final previousStatus = ledger[targetIso];
      if (preventOverwriteCompleted &&
          (previousStatus == 'tomada' || previousStatus == 'omitida')) {
        return false;
      }

      ledger[targetIso] = status;

      // Podar entradas muy antiguas (> 14 días) para mantener el mapa ligero
      final cutoff = DateTime.now().subtract(const Duration(days: 14));
      ledger.removeWhere((iso, _) {
        final dt = DateTime.tryParse(iso);
        return dt != null && dt.isBefore(cutoff);
      });

      await prefs.setString(key, jsonEncode(ledger));

      if (queueForSync) {
        await enqueueOfflineDoseAction(
          userId: userId,
          docId: docId,
          doseTimeIso: targetIso,
          status: status,
          profileId: profileId,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Obtiene el mapa de estados de dosis guardados localmente para un tratamiento.
  Future<Map<String, String>> getLocalDoseStatuses(String userId, String docId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final rawJson = prefs.getString(_doseLedgerKey(userId, docId));
      if (rawJson == null || rawJson.isEmpty) return {};
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  /// Reemplaza una clave de dosis local (ej. al aplazar o editar una sola toma).
  Future<void> replaceLocalDoseKey({
    required String userId,
    required String docId,
    required DateTime oldDoseTime,
    required DateTime newDoseTime,
    required String status,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final key = _doseLedgerKey(userId, docId);
      final map = await getLocalDoseStatuses(userId, docId);
      map.remove(oldDoseTime.toIso8601String());
      map[newDoseTime.toIso8601String()] = status;
      await prefs.setString(key, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> clearLocalDoseStatusesForTreatment(String userId, String docId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_doseLedgerKey(userId, docId));
    } catch (_) {}
  }

  /// Encola una acción de dosis realizada offline para sincronizarla con Firestore.
  Future<void> enqueueOfflineDoseAction({
    required String userId,
    required String docId,
    required String doseTimeIso,
    required String status,
    String? profileId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final rawList = prefs.getString(_pendingOfflineActionsKey);
      final List<Map<String, dynamic>> queue = [];
      if (rawList != null && rawList.isNotEmpty) {
        final decoded = jsonDecode(rawList);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              queue.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }

      // Si ya existe una acción pendiente para la misma dosis, actualizarla
      final existingIdx = queue.indexWhere(
        (item) =>
            item['userId'] == userId &&
            item['docId'] == docId &&
            item['doseTimeIso'] == doseTimeIso,
      );

      final entry = <String, dynamic>{
        'userId': userId,
        'docId': docId,
        'doseTimeIso': doseTimeIso,
        'status': status,
        'profileId': profileId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (existingIdx >= 0) {
        queue[existingIdx] = entry;
      } else {
        queue.add(entry);
      }

      await prefs.setString(_pendingOfflineActionsKey, jsonEncode(queue));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getPendingOfflineDoseActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final rawList = prefs.getString(_pendingOfflineActionsKey);
      if (rawList == null || rawList.isEmpty) return [];
      final decoded = jsonDecode(rawList);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> removePendingOfflineDoseAction({
    required String userId,
    required String docId,
    required String doseTimeIso,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final queue = await getPendingOfflineDoseActions();
      queue.removeWhere(
        (item) =>
            item['userId'] == userId &&
            item['docId'] == docId &&
            item['doseTimeIso'] == doseTimeIso,
      );
      await prefs.setString(_pendingOfflineActionsKey, jsonEncode(queue));
    } catch (_) {}
  }

  // --- Caché Local de Horarios de Tratamientos (Respaldo Offline y Post-Reinicio) ---

  Future<void> saveTreatmentScheduleCache(Map<String, dynamic> params) async {
    try {
      final userId = params['userId'] as String?;
      final docId = params['docId'] as String?;
      if (userId == null || docId == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final rawMap = prefs.getString(_treatmentScheduleCacheKey);
      final Map<String, dynamic> allSchedules = {};
      if (rawMap != null && rawMap.isNotEmpty) {
        final decoded = jsonDecode(rawMap);
        if (decoded is Map) {
          allSchedules.addAll(Map<String, dynamic>.from(decoded));
        }
      }

      allSchedules['$userId|$docId'] = params;
      await prefs.setString(_treatmentScheduleCacheKey, jsonEncode(allSchedules));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getTreatmentScheduleCache(
    String userId,
    String docId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final rawMap = prefs.getString(_treatmentScheduleCacheKey);
      if (rawMap == null || rawMap.isEmpty) return null;
      final decoded = jsonDecode(rawMap);
      if (decoded is Map) {
        final item = decoded['$userId|$docId'];
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllTreatmentScheduleCachesForUser(
    String userId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final rawMap = prefs.getString(_treatmentScheduleCacheKey);
      if (rawMap == null || rawMap.isEmpty) return [];
      final decoded = jsonDecode(rawMap);
      if (decoded is Map) {
        final List<Map<String, dynamic>> result = [];
        decoded.forEach((key, value) {
          if (key.toString().startsWith('$userId|') && value is Map) {
            result.add(Map<String, dynamic>.from(value));
          }
        });
        return result;
      }
    } catch (_) {}
    return [];
  }

  Future<void> removeTreatmentScheduleCache(String userId, String docId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final rawMap = prefs.getString(_treatmentScheduleCacheKey);
      if (rawMap == null || rawMap.isEmpty) return;
      final decoded = jsonDecode(rawMap);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        if (map.remove('$userId|$docId') != null) {
          await prefs.setString(_treatmentScheduleCacheKey, jsonEncode(map));
        }
      }
    } catch (_) {}
  }
}
