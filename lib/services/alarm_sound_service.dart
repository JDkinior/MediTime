import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Servicio unificado para el sonido y vibración continua de alarmas de MediTime.
///
/// Combina:
/// 1. [FlutterRingtonePlayer] en el canal del sistema `USAGE_ALARM` con bucle.
/// 2. [AlarmSoundPlugin] en Kotlin con `MediaPlayer` y `Vibrator` nativos en bucle.
/// 3. Broadcast global `com.example.meditime.STOP_ALARM` para silenciar
///    instantáneamente cualquier isolate o proceso secundario en Android.
class AlarmSoundService {
  static const MethodChannel _channel =
      MethodChannel('com.example.meditime/alarm_sound');

  /// Inicia la reproducción continua del tono de alarma y la vibración en bucle.
  static Future<void> startAlarm() async {
    debugPrint("🚨 AlarmSoundService: Iniciando sonido y vibración continua...");

    // 1. Iniciar FlutterRingtonePlayer
    try {
      await FlutterRingtonePlayer().playAlarm(
        looping: true,
        volume: 1.0,
        asAlarm: true,
      );
      debugPrint("🔊 AlarmSoundService: FlutterRingtonePlayer activado.");
    } catch (e) {
      debugPrint("Advertencia en FlutterRingtonePlayer: $e");
    }

    // 2. Iniciar capa nativa redundante en Kotlin (MediaPlayer + Vibrator)
    try {
      await _channel.invokeMethod('start');
      debugPrint("🔊 AlarmSoundService: AlarmSoundPlugin nativo activado.");
    } catch (e) {
      debugPrint("Advertencia en canal nativo de alarma: $e");
    }
  }

  /// Detiene inmediatamente el sonido y la vibración de alarma en todos los canales y procesos.
  static Future<void> stopAlarm() async {
    debugPrint("🔕 AlarmSoundService: Deteniendo alarma en todos los canales...");

    // 1. Detener FlutterRingtonePlayer
    try {
      await FlutterRingtonePlayer().stop();
    } catch (e) {
      debugPrint("Error deteniendo FlutterRingtonePlayer: $e");
    }

    // 2. Detener reproductor nativo
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}

    // 3. Enviar broadcast global para asegurar que cualquier isolate/engine detenga el audio
    try {
      await _channel.invokeMethod('sendStopBroadcast');
    } catch (_) {}

    debugPrint("✅ AlarmSoundService: Alarma detenida exitosamente.");
  }
}
