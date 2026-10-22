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

  Future<void> saveThemeMode(String themeStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, themeStr);
  }

  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_themeModeKey) ?? 'system';
  }

  Future<void> saveLanguageCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, code);
  }

  Future<String> getLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_languageCodeKey) ?? 'system';
  }

  Future<void> saveInterfaceStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_interfaceStyleKey, style);
  }

  Future<String> getInterfaceStyle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_interfaceStyleKey) ?? 'classic';
  }

  Future<void> saveEnableScrollFade(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableScrollFadeKey, value);
  }

  Future<bool> getEnableScrollFade() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_enableScrollFadeKey) ?? true;
  }

  Future<void> saveCalendarFormat(String format) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_calendarFormatKey, format);
  }

  Future<String> getCalendarFormat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_calendarFormatKey) ?? 'weekly';
  }

  Future<void> saveReminderMode(DoseReminderMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reminderModeKey, mode.toValue());
    // Mantener sincronizado el valor legacy para retrocompatibilidad
    await prefs.setBool(_notificationModeKey, mode == DoseReminderMode.active);
  }

  Future<DoseReminderMode> getReminderMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
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
  Future<bool> getNotificationMode() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Forzamos la recarga de los datos desde el disco.
    // Esto es crucial para que el proceso en segundo plano obtenga el valor más reciente.
    await prefs.reload(); 
    
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
  Future<int> getSnoozeDuration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
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

  Future<String> getAlarmSoundType() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_alarmSoundTypeKey) ?? 'system_alarm';
  }

  Future<String> getAlarmSoundTitle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_alarmSoundTitleKey) ?? 'Alarma del teléfono (Predeterminada)';
  }

  Future<String?> getAlarmSoundUri() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final type = prefs.getString(_alarmSoundTypeKey) ?? 'system_alarm';
    if (type == 'custom') {
      return null;
    }
    return prefs.getString(_alarmSoundUriKey) ?? 'content://settings/system/alarm_alert';
  }

  Future<String?> getAlarmSoundResource() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_alarmSoundResourceKey);
  }

  // --- Accesibilidad ---
  Future<void> saveHighContrast(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highContrastKey, isActive);
  }

  Future<bool> getHighContrast() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_highContrastKey) ?? false;
  }

  Future<void> saveLargeText(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_largeTextKey, isActive);
  }

  Future<bool> getLargeText() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_largeTextKey) ?? false;
  }

  Future<void> saveLargeButtons(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_largeButtonsKey, isActive);
  }

  Future<bool> getLargeButtons() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_largeButtonsKey) ?? false;
  }

  Future<void> saveSimplifiedInterface(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_simplifiedInterfaceKey, isActive);
  }

  Future<bool> getSimplifiedInterface() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_simplifiedInterfaceKey) ?? false;
  }

  Future<void> saveShowCardBorder(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showCardBorderKey, isActive);
  }

  Future<bool> getShowCardBorder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
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

  Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
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
  }

  Future<void> removeRevokedTreatment(String userId, String docId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$userId|$docId';
    final list = (prefs.getStringList(_revokedTreatmentsKey) ?? <String>[]).toSet();
    list.remove(key);
    await prefs.setStringList(_revokedTreatmentsKey, list.toList());
  }

  Future<bool> isTreatmentRevoked(String userId, String docId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
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

  Future<bool> getCaregiverModeActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_caregiverModeActiveKey) ?? false;
  }

  Future<void> saveCaregiverModeType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_caregiverModeTypeKey, type);
  }

  Future<String> getCaregiverModeType() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
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

  Future<String?> getCaregiverActiveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_caregiverActiveProfileKey);
  }

  Future<void> saveCaregiverNotifyPatientDoses(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_caregiverNotifyPatientDosesKey, val);
  }

  Future<bool> getCaregiverNotifyPatientDoses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_caregiverNotifyPatientDosesKey) ?? true;
  }

  Future<void> saveCaregiverIncludeLocation(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_caregiverIncludeLocationKey, val);
  }

  Future<bool> getCaregiverIncludeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_caregiverIncludeLocationKey) ?? true;
  }

  Future<void> saveHideMedicineNameOnLockScreen(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideMedicineNameOnLockScreenKey, val);
  }

  Future<bool> getHideMedicineNameOnLockScreen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_hideMedicineNameOnLockScreenKey) ?? false;
  }

  Future<void> saveSecureScreen(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_secureScreenKey, val);
  }

  Future<bool> getSecureScreen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_secureScreenKey) ?? false;
  }

  Future<void> saveOnboardingCompleted(String userId, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_onboardingCompletedPrefix$userId', val);
  }

  Future<bool> hasCompletedOnboarding(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
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

  Future<bool> hasAcceptedTerms(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool('$_termsAcceptedPrefix$userId') ?? false;
  }

  Future<String?> getTermsAcceptedAt(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString('$_termsAcceptedAtPrefix$userId');
  }

  Future<String?> getTermsAcceptedVersion(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString('$_termsAcceptedVersionPrefix$userId');
  }

  // --- Animal / Veterinary Mode ---
  Future<void> saveAnimalModeActive(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_animalModeActiveKey, isActive);
  }

  Future<bool> getAnimalModeActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_animalModeActiveKey) ?? false;
  }

  Future<void> saveAnimalModeType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_animalModeTypeKey, type);
  }

  Future<String> getAnimalModeType() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
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

  Future<String?> getAnimalActiveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_animalActiveProfileKey);
  }

  Future<void> saveAnimalNotifyDoses(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_animalNotifyDosesKey, val);
  }

  Future<bool> getAnimalNotifyDoses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_animalNotifyDosesKey) ?? true;
  }

  Future<void> saveAnimalIncludeLocation(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_animalIncludeLocationKey, val);
  }

  Future<bool> getAnimalIncludeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
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

  // --- Profile categorization & Alarm ID tracking ---
  Future<void> saveAnimalProfileIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_animalProfileIdsKey, ids);
  }

  Future<List<String>> getAnimalProfileIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getStringList(_animalProfileIdsKey) ?? [];
  }

  Future<bool> isAnimalProfile(String profileId) async {
    final ids = await getAnimalProfileIds();
    return ids.contains(profileId);
  }

  Future<void> saveCaregiverProfileIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_caregiverProfileIdsKey, ids);
  }

  Future<List<String>> getCaregiverProfileIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getStringList(_caregiverProfileIdsKey) ?? [];
  }

  Future<bool> isCaregiverProfile(String profileId) async {
    final ids = await getCaregiverProfileIds();
    return ids.contains(profileId);
  }

  // --- Caregiver Alarm IDs ---
  Future<void> saveCaregiverAlarmIds(List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_caregiverAlarmIdsKey, ids.map((e) => e.toString()).toList());
  }

  Future<List<int>> getCaregiverAlarmIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
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

  Future<List<int>> getAnimalAlarmIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
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
}