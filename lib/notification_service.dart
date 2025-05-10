// notification_service.dart (modificado)
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    // Establecer la zona horaria local (importante para programar correctamente)
    tz.setLocalLocation(tz.getLocation('America/Mexico_City')); // Ajusta a tu zona horaria
    
    // Configuración para Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    // Configuración para iOS si es necesario
    // const IOSInitializationSettings initializationSettingsIOS =
    //     IOSInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notificación recibida: ${response.payload}');
      },
    );
    
    // Solicitar permisos explícitamente
    await _requestPermissions();
  }
  
  static Future<void> _requestPermissions() async {
    // Para Android 13+ (API nivel 33+)
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
        
    // Para permisos exactos de alarma en Android 12+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

static Future<void> scheduleNotification({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledTime,
  required String interval,
}) async {
  try {
    if (scheduledTime.isBefore(DateTime.now())) return;

    final androidDetails = AndroidNotificationDetails(
      'meditime_channel',
      'MediTime Notificaciones',
      channelDescription: 'Canal para recordatorios de medicamentos',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
    );

    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
    
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledTime,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // Elimina matchDateTimeComponents para evitar repetición diaria
    );
    
  } catch (e) {
    debugPrint('Error al programar notificación: $e');
  }
}

  // Método para cancelar todas las notificaciones
  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
  
  // Método para verificar permisos de notificación
  static Future<bool> checkNotificationPermissions() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
            
    if (androidImplementation != null) {
      return await androidImplementation.areNotificationsEnabled() ?? false;
    }
    return false;
  }
}