import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:meditime/services/preference_service.dart';

/// Modelo de datos que representa una opción de tono de alarma.
class AlarmSoundOption {
  final String id;
  final String title;
  final String subtitle;
  final String category; // 'phone' o 'custom'
  final String? resourceName;
  final String? uri;

  const AlarmSoundOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    this.resourceName,
    this.uri,
  });

  /// Lista de tonos personalizados diseñados para MediTime e incluidos en res/raw
  static const List<AlarmSoundOption> customTones = [
    AlarmSoundOption(
      id: 'custom_meditime_campana',
      title: 'Campana Médica',
      subtitle: 'Acordes armónicos suaves de doble campana',
      category: 'custom',
      resourceName: 'meditime_campana',
    ),
    AlarmSoundOption(
      id: 'custom_meditime_clasica',
      title: 'Alarma Clásica',
      subtitle: 'Timbre rítmico tradicional estilo despertador',
      category: 'custom',
      resourceName: 'meditime_clasica',
    ),
    AlarmSoundOption(
      id: 'custom_meditime_digital',
      title: 'Pulso Digital',
      subtitle: 'Secuencia electrónica moderna y nítida',
      category: 'custom',
      resourceName: 'meditime_digital',
    ),
    AlarmSoundOption(
      id: 'custom_meditime_suave',
      title: 'Melodía Suave',
      subtitle: 'Arpegio tranquilo y cálido tipo marimba',
      category: 'custom',
      resourceName: 'meditime_suave',
    ),
  ];

  /// Tonos del teléfono principales (predeterminados del sistema)
  static const AlarmSoundOption systemAlarmDefault = AlarmSoundOption(
    id: 'system_alarm',
    title: 'Alarma del teléfono (Predeterminada)',
    subtitle: 'Tono predeterminado de alarma de tu dispositivo',
    category: 'phone',
    uri: 'content://settings/system/alarm_alert',
  );

  static const AlarmSoundOption systemRingtoneDefault = AlarmSoundOption(
    id: 'system_ringtone',
    title: 'Tono de llamada del teléfono',
    subtitle: 'Tono de llamadas entrantes del sistema',
    category: 'phone',
    uri: 'content://settings/system/ringtone',
  );
}

/// Servicio unificado para el sonido y vibración de alarmas en MediTime.
///
/// Gestiona la interacción con la capa nativa (MediaPlayer + Vibrator + RingtoneManager),
/// reproducción en primer plano, pruebas interactivas (isTest) y vistas previas.
class AlarmSoundService {
  static const MethodChannel _channel =
      MethodChannel('com.meditime.app/alarm_sound');

  /// Duración máxima que la alarma puede sonar antes de auto-detenerse (5 minutos).
  static const Duration maxAlarmDuration = Duration(minutes: 5);

  /// Timer de seguridad que detiene la alarma automáticamente.
  static Timer? _autoStopTimer;

  /// Inicia la reproducción continua del tono de alarma y la vibración en bucle.
  /// Si no se especifican argumentos, se leen los ajustes guardados del usuario.
  static Future<void> startAlarm({
    String? uri,
    String? resourceName,
    String? soundType,
  }) async {
    debugPrint("🚨 AlarmSoundService: Iniciando sonido y vibración continua...");

    _autoStopTimer?.cancel();

    // Si no se proporcionaron parámetros, obtener los configurados por el usuario
    if (uri == null && resourceName == null && soundType == null) {
      try {
        final prefService = PreferenceService();
        soundType = await prefService.getAlarmSoundType();
        uri = await prefService.getAlarmSoundUri();
        resourceName = await prefService.getAlarmSoundResource();
      } catch (e) {
        debugPrint("Error leyendo preferencias de sonido para alarma: $e");
      }
    }

    try {
      await _channel.invokeMethod('start', {
        'uri': uri,
        'resourceName': resourceName,
        'soundType': soundType,
      });
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

  /// Reproduce una vista previa corta (máximo 5 segundos, sin vibración) del tono seleccionado.
  static Future<void> playPreview({
    String? uri,
    String? resourceName,
    String? soundType,
  }) async {
    try {
      await _channel.invokeMethod('playPreview', {
        'uri': uri,
        'resourceName': resourceName,
        'soundType': soundType,
      });
    } catch (e) {
      debugPrint("Error reproduciendo preview de tono: $e");
    }
  }

  /// Detiene cualquier vista previa de audio que se esté reproduciendo actualmente.
  static Future<void> stopPreview() async {
    try {
      await _channel.invokeMethod('stopPreview');
    } catch (_) {}
  }

  /// Obtiene los tonos de alarma instalados en el teléfono mediante RingtoneManager.
  static Future<List<Map<String, String>>> getRingtones() async {
    try {
      final List<dynamic>? result =
          await _channel.invokeMethod<List<dynamic>>('getRingtones');
      if (result != null) {
        return result.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return {
            'id': map['id']?.toString() ?? '',
            'title': map['title']?.toString() ?? 'Tono del sistema',
            'uri': map['uri']?.toString() ?? '',
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("Error obteniendo tonos del sistema: $e");
    }
    return [];
  }

  /// Abre el selector de tonos nativo de Android (RingtoneManager Picker).
  /// Retorna un mapa con {'title': ..., 'uri': ...} o null si el usuario canceló.
  static Future<Map<String, String>?> openRingtonePicker({
    String? currentUri,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'openRingtonePicker',
        {'currentUri': currentUri},
      );
      if (result != null) {
        return {
          'title': result['title']?.toString() ?? 'Tono del teléfono',
          'uri': result['uri']?.toString() ?? '',
        };
      }
    } catch (e) {
      debugPrint("Error abriendo selector de tonos nativo: $e");
    }
    return null;
  }

  /// Obtiene la URI del tono de alarma predeterminado del sistema operativo.
  static Future<String?> getDefaultAlarmUri() async {
    try {
      return await _channel.invokeMethod<String>('getDefaultAlarmUri');
    } catch (_) {
      return 'content://settings/system/alarm_alert';
    }
  }

  /// Obtiene la URI del tono de llamada predeterminado del sistema operativo.
  static Future<String?> getDefaultRingtoneUri() async {
    try {
      return await _channel.invokeMethod<String>('getDefaultRingtoneUri');
    } catch (_) {
      return 'content://settings/system/ringtone';
    }
  }
}
