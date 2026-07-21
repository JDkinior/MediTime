// En el archivo lib/services/preference_service.dart

import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  static const String _notificationModeKey = 'notification_mode_active';
  static const String _snoozeDurationKey = 'snooze_duration_minutes';
  static const String _currentUserIdKey = 'current_user_id';
  static const String _revokedTreatmentsKey = 'revoked_treatments'; // String list of "userId|docId"
  static const String _tutorialShownPrefix = 'tutorial_shown_';
  static const String _calendarFormatKey = 'calendar_format_string';
  static const String _interfaceStyleKey = 'interface_style_string';
  static const String _themeModeKey = 'theme_mode_string';

  // Accessibility keys
  static const String _highContrastKey = 'high_contrast_active';
  static const String _largeTextKey = 'large_text_active';
  static const String _largeButtonsKey = 'large_buttons_active';
  static const String _simplifiedInterfaceKey = 'simplified_interface_active';

  // Caregiver Mode keys
  static const String _caregiverModeActiveKey = 'caregiver_mode_active';
  static const String _caregiverModeTypeKey = 'caregiver_mode_type';
  static const String _caregiverActiveProfileKey = 'caregiver_active_profile';

  Future<void> saveThemeMode(String themeStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, themeStr);
  }

  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_themeModeKey) ?? 'system';
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

  Future<void> saveCalendarFormat(String format) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_calendarFormatKey, format);
  }

  Future<String> getCalendarFormat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_calendarFormatKey) ?? 'weekly';
  }

  Future<void> saveNotificationMode(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationModeKey, isActive);
  }

  // --- INICIO DE LA MODIFICACIÓN ---
  Future<bool> getNotificationMode() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Forzamos la recarga de los datos desde el disco.
    // Esto es crucial para que el proceso en segundo plano obtenga el valor más reciente.
    await prefs.reload(); 
    
    // 2. Ahora leemos el valor, que está garantizado que es el más actual.
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

}