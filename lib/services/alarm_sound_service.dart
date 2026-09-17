import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Servicio unificado para el sonido y vibración de alarmas en primer plano y pruebas de MediTime.
///
/// Las alarmas programadas en segundo plano reproducen el tono nativo del sistema
/// directamente a través de Android NotificationManager (FLAG_INSISTENT).
/// Este servicio se usa para pruebas en pantalla (isTest) y control manual.
class AlarmSoundService {
  static const MethodChannel _channel =
      MethodChannel('com.example.meditime/alarm_sound');

  /// Duración máxima que la alarma puede sonar antes de auto-detenerse.
  static const Duration maxAlarmDuration = Duration(minutes: 5);

  /// Timer de seguridad que detiene la alarma automáticamente.
  static Timer? _autoStopTimer;

  /// Inicia la reproducción continua del tono de alarma y la vibración en bucle.
  static Future<void> startAlarm() async {
    debugPrint("🚨 AlarmSoundService: Iniciando sonido y vibración continua...");

    // Cancelar cualquier timer anterior antes de iniciar uno nuevo
    _autoStopTimer?.cancel();

    // Iniciar capa nativa en Kotlin (MediaPlayer + Vibrator)
    try {
      await _channel.invokeMethod('start');
      debugPrint("🔊 AlarmSoundService: AlarmSoundPlugin nativo activado.");
    } catch (e) {
      debugPrint("Advertencia en canal nativo de alarma: $e");
    }

    // Timer de seguridad: Auto-detener después de maxAlarmDuration
    _autoStopTimer = Timer(maxAlarmDuration, () {
      debugPrint("⏱️ AlarmSoundService: Auto-stop por timeout ($maxAlarmDuration).");
      stopAlarm();
    });
  }

  /// Detiene inmediatamente el sonido y la vibración de alarma en todos los canales y procesos.
  static Future<void> stopAlarm() async {
    debugPrint("🔕 AlarmSoundService: Deteniendo alarma...");

    // Cancelar timer de auto-stop
    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    // 1. Detener reproductor nativo
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}

    // 2. Enviar broadcast global para asegurar que cualquier componente detenga el audio
    try {
      await _channel.invokeMethod('sendStopBroadcast');
    } catch (_) {}

    debugPrint("✅ AlarmSoundService: Alarma detenida exitosamente.");
  }

  /// Adjunta un listener de descarte a una notificación existente.
  ///
  /// Cuando la notificación con [notificationId] sea descartada por cualquier razón
  /// (swipe, "Borrar todo", timeout, sistema), Android automáticamente enviará
  /// el broadcast `STOP_ALARM` que detendrá el sonido y la vibración.
  static Future<void> attachDismissListener(int notificationId) async {
    try {
      await _channel.invokeMethod('attachDismissListener', {
        'notificationId': notificationId,
      });
      debugPrint("🔗 AlarmSoundService: deleteIntent adjuntado a notificación $notificationId");
    } catch (e) {
      debugPrint("Advertencia adjuntando deleteIntent: $e");
    }
  }
}

