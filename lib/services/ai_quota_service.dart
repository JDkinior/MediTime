import 'package:shared_preferences/shared_preferences.dart';

/// Servicio responsable de gestionar los límites de uso diario, protección de cuotas,
/// control de ráfagas (burst cooldown) y políticas de uso justo para el asistente Midi.
class AiQuotaService {
  const AiQuotaService();

  /// Límite diario de consultas para usuarios del plan Gratuito.
  static const int freeDailyLimit = 20;

  /// Límite diario de consultas para usuarios del plan Premium (protección contra bucles/abuso).
  static const int premiumDailyLimit = 120;

  /// Intervalo mínimo entre mensajes consecutivos para evitar ráfagas o dobles envíos.
  static const Duration burstCooldown = Duration(milliseconds: 2000);

  static const String _quotaDatePrefix = 'ai_quota_date_';
  static const String _quotaCountPrefix = 'ai_quota_count_';
  static const String _lastMessageEpochPrefix = 'ai_last_message_epoch_';

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Obtiene el límite máximo diario según el plan de suscripción del usuario.
  int getDailyLimit({required bool isPremium}) {
    return isPremium ? premiumDailyLimit : freeDailyLimit;
  }

  /// Retorna la cantidad de mensajes consumidos hoy por el usuario especificado.
  Future<int> getUsedCount(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final today = _todayDateString();
    final savedDate = prefs.getString('$_quotaDatePrefix$userId');

    if (savedDate != today) {
      // Nuevo día: el contador inicia en 0 automáticamente
      return 0;
    }
    return prefs.getInt('$_quotaCountPrefix$userId') ?? 0;
  }

  /// Retorna la cantidad de mensajes restantes que el usuario puede enviar hoy.
  Future<int> getRemainingMessages(String userId, {required bool isPremium}) async {
    final used = await getUsedCount(userId);
    final limit = getDailyLimit(isPremium: isPremium);
    final remaining = limit - used;
    return remaining > 0 ? remaining : 0;
  }

  /// Determina si el usuario tiene cuota disponible para enviar un mensaje hoy.
  Future<bool> canSendMessage(String userId, {required bool isPremium}) async {
    final used = await getUsedCount(userId);
    final limit = getDailyLimit(isPremium: isPremium);
    return used < limit;
  }

  /// Determina si el usuario está bajo enfriamiento (evita ráfagas menores a [cooldown]).
  Future<bool> isCoolingDown(String userId, {Duration cooldown = burstCooldown}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lastEpoch = prefs.getInt('$_lastMessageEpochPrefix$userId');
    if (lastEpoch == null) return false;

    final elapsed = DateTime.now().millisecondsSinceEpoch - lastEpoch;
    return elapsed < cooldown.inMilliseconds;
  }

  /// Registra el envío de un mensaje, actualizando la fecha, el contador del día y la estampa de tiempo.
  Future<void> recordMessageSent(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayDateString();
    final savedDate = prefs.getString('$_quotaDatePrefix$userId');

    int currentCount = 0;
    if (savedDate == today) {
      currentCount = prefs.getInt('$_quotaCountPrefix$userId') ?? 0;
    }

    await prefs.setString('$_quotaDatePrefix$userId', today);
    await prefs.setInt('$_quotaCountPrefix$userId', currentCount + 1);
    await prefs.setInt('$_lastMessageEpochPrefix$userId', DateTime.now().millisecondsSinceEpoch);
  }

  /// Reinicia la cuota de un usuario (para pruebas o reset administrativo).
  Future<void> resetQuota(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_quotaDatePrefix$userId');
    await prefs.remove('$_quotaCountPrefix$userId');
    await prefs.remove('$_lastMessageEpochPrefix$userId');
  }
}
