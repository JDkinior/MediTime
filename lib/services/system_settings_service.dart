import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SystemSettingsService {
  static const MethodChannel _channel =
      MethodChannel('com.example.meditime/system_settings');

  /// Verifica si la aplicación tiene deshabilitada la optimización de batería
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking battery optimization: $e');
      return false;
    }
  }

  /// Verifica si la aplicación puede programar alarmas exactas (Android 12+)
  static Future<bool> canScheduleExactAlarms() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('canScheduleExactAlarms');
      return result ?? true;
    } catch (e) {
      debugPrint('Error checking exact alarms permission: $e');
      return true;
    }
  }

  /// Verifica si las notificaciones están activas en el sistema
  static Future<bool> areNotificationsEnabled() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('areNotificationsEnabled');
      return result ?? true;
    } catch (e) {
      debugPrint('Error checking notifications permission: $e');
      return true;
    }
  }

  /// Verifica si la aplicación tiene permiso de pantalla completa en Android 14+ (API 34+)
  static Future<bool> canUseFullScreenIntent() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('canUseFullScreenIntent');
      return result ?? true;
    } catch (e) {
      debugPrint('Error checking full screen intent permission: $e');
      return true;
    }
  }

  /// Abre la pantalla de configuración para autorizar avisos a pantalla completa (Android 14+)
  static Future<bool> openFullScreenIntentSettings() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('openFullScreenIntentSettings');
      return result ?? false;
    } catch (e) {
      debugPrint('Error opening full screen intent settings: $e');
      return false;
    }
  }

  /// Obtiene la marca / fabricante del dispositivo
  static Future<String> getManufacturer() async {
    try {
      final String? result =
          await _channel.invokeMethod<String>('getManufacturer');
      return result ?? 'Android';
    } catch (e) {
      debugPrint('Error getting manufacturer: $e');
      return 'Android';
    }
  }

  /// Establece si la aplicación se debe mostrar sobre la pantalla de bloqueo y encender la pantalla.
  static Future<bool> setLockScreenVisibility(bool visible) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'setLockScreenVisibility', 
        {'visible': visible}
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Error setting lock screen visibility: $e');
      return false;
    }
  }

  /// Abre la pantalla de optimización de batería o solicita exención
  static Future<bool> openBatteryOptimizationSettings() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('openBatteryOptimizationSettings');
      return result ?? false;
    } catch (e) {
      debugPrint('Error opening battery settings: $e');
      return false;
    }
  }

  /// Abre la pantalla de configuración de alarmas exactas (Android 12+)
  static Future<bool> openExactAlarmSettings() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('openExactAlarmSettings');
      return result ?? false;
    } catch (e) {
      debugPrint('Error opening exact alarm settings: $e');
      return false;
    }
  }

  /// Abre la configuración de notificaciones de la app
  static Future<bool> openNotificationSettings() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('openNotificationSettings');
      return result ?? false;
    } catch (e) {
      debugPrint('Error opening notification settings: $e');
      return false;
    }
  }

  /// Abre los ajustes detallados de la aplicación (Permisos, almacenamiento, etc.)
  static Future<bool> openAppDetailsSettings() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('openAppDetailsSettings');
      return result ?? false;
    } catch (e) {
      debugPrint('Error opening app details settings: $e');
      return false;
    }
  }

  /// Intenta abrir el gestor de inicio automático (*Autostart*) según el fabricante
  static Future<bool> openAutoStartSettings() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('openAutoStartSettings');
      return result ?? false;
    } catch (e) {
      debugPrint('Error opening autostart settings: $e');
      return false;
    }
  }

  /// Abre el portal web DontKillMyApp con la guía específica para el fabricante
  static Future<bool> openDontKillMyApp([String? brand]) async {
    String url = 'https://dontkillmyapp.com/';
    if (brand != null && brand.isNotEmpty) {
      final b = brand.toLowerCase();
      if (b.contains('xiaomi') || b.contains('redmi') || b.contains('poco')) {
        url = 'https://dontkillmyapp.com/xiaomi';
      } else if (b.contains('samsung')) {
        url = 'https://dontkillmyapp.com/samsung';
      } else if (b.contains('huawei') || b.contains('honor')) {
        url = 'https://dontkillmyapp.com/huawei';
      } else if (b.contains('oneplus')) {
        url = 'https://dontkillmyapp.com/oneplus';
      } else if (b.contains('oppo') || b.contains('realme')) {
        url = 'https://dontkillmyapp.com/oppo';
      } else if (b.contains('vivo')) {
        url = 'https://dontkillmyapp.com/vivo';
      } else if (b.contains('meizu')) {
        url = 'https://dontkillmyapp.com/meizu';
      } else if (b.contains('asus')) {
        url = 'https://dontkillmyapp.com/asus';
      } else if (b.contains('sony')) {
        url = 'https://dontkillmyapp.com/sony';
      }
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error opening DontKillMyApp URL: $e');
    }
    return false;
  }
}
