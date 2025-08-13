// En el archivo lib/services/preference_service.dart

import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  static const String _notificationModeKey = 'notification_mode_active';
  static const String _snoozeDurationKey = 'snooze_duration_minutes';
  static const String _currentUserIdKey = 'current_user_id';
  static const String _revokedTreatmentsKey = 'revoked_treatments'; // String list of "userId|docId"

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

}