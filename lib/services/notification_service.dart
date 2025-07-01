// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart'; // Para debugPrint

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isCoreInitialized = false;
  static bool _permissionsHaveBeenRequested = false;

  static Future<void> initializeCore() async {
    if (_isCoreInitialized) {
      return;
    }

    tz.initializeTimeZones();
    try {
      final String currentTimeZone = await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.getNotificationChannels()
          .then((channels) => tz.local.name) ?? 'America/Bogota'; // Default
      tz.setLocalLocation(tz.getLocation(currentTimeZone));
    } catch (e) {
      debugPrint("Error obteniendo/configurando zona horaria local: $e. Usando America/Bogota como default.");
      tz.setLocalLocation(tz.getLocation('America/Bogota')); // Fallback
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notificación tocada (onDidReceiveNotificationResponse): ${response.payload}');
      },
    );
    _isCoreInitialized = true;
    debugPrint("NotificationService Core Inicializado.");
  }

  static Future<void> requestAllNecessaryPermissions() async {
    if (!_isCoreInitialized) {
      debugPrint("ADVERTENCIA: Se están solicitando permisos antes de inicializar el núcleo de NotificationService.");
      await initializeCore();
    }
    if (_permissionsHaveBeenRequested) {
      return;
    }

    debugPrint("Solicitando permisos de notificación (Android)...");
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      debugPrint("Solicitando permisos de alarma exacta (Android)...");
      await androidImplementation.requestExactAlarmsPermission();
      
      // MEJORA: Solicitar permisos adicionales para evitar restricciones
      debugPrint("Solicitando permisos adicionales para alarmas...");
      await androidImplementation.requestNotificationsPermission();
    }

    debugPrint("Solicitando permisos de notificación (iOS)...");
    final IOSFlutterLocalNotificationsPlugin? iOSImplementation =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

    if (iOSImplementation != null) {
      await iOSImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _permissionsHaveBeenRequested = true;
    debugPrint("Solicitud de permisos completada.");
  }

  static Future<void> showSimpleNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isCoreInitialized) {
      debugPrint("NotificationService Core no está inicializado. Intentando inicializar para mostrar notificación...");
      await initializeCore();
      if (!_isCoreInitialized) {
        debugPrint("Fallo al inicializar NotificationService Core en showSimpleNotification. No se puede mostrar la notificación.");
        return;
      }
    }

    // MEJORA: Configuración más agresiva para notificaciones críticas
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'meditime_dosis_channel',
      'MediTime Recordatorios de Dosis',
      channelDescription: 'Canal para recordatorios de dosis de medicamentos.',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
     /* sound: RawResourceAndroidNotificationSound('notification_sound'),  Asegúrate de tener este archivo*/
      fullScreenIntent: true, // NUEVA OPCIÓN: Muestra la notificación en pantalla completa
      category: AndroidNotificationCategory.alarm, // NUEVA OPCIÓN: Categoriza como alarma
      visibility: NotificationVisibility.public, // NUEVA OPCIÓN: Visible en pantalla de bloqueo
      autoCancel: false, // NUEVA OPCIÓN: No se cancela automáticamente
      ongoing: false, // Puede ser true si quieres que persista
      ticker: 'Hora de tomar medicamento', // NUEVA OPCIÓN: Texto que aparece en la barra de estado
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical, // NUEVA OPCIÓN: Nivel crítico para iOS
    );

    const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails);

    await _notificationsPlugin.show(id, title, body, notificationDetails, payload: payload);
    debugPrint("Notificación local mostrada - ID: $id, Título: $title, Hora: ${DateTime.now()}");
  }

  static Future<void> cancelAllFlutterLocalNotifications() async {
    await _notificationsPlugin.cancelAll();
    debugPrint("Todas las notificaciones de flutter_local_notifications han sido canceladas.");
  }

  static Future<void> cancelFlutterLocalNotificationById(int id) async {
    await _notificationsPlugin.cancel(id);
    debugPrint("Notificación de flutter_local_notifications con ID: $id cancelada.");
  }

  static Future<bool> checkNotificationPermissions() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      return await androidImplementation.areNotificationsEnabled() ?? false;
    }
    
    return false;
  }

  // NUEVA FUNCIÓN: Para verificar si las alarmas exactas están permitidas
  static Future<bool> checkExactAlarmPermissions() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      return await androidImplementation.canScheduleExactNotifications() ?? false;
    }
    
    return false;
  }
}