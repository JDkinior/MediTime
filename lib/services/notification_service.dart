// lib/services/notification_service.dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:meditime/alarm_callback_handler.dart' show alarmCallbackLogic;
import 'package:meditime/services/firestore_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/services/alarm_sound_service.dart';
import 'package:meditime/firebase_options.dart';

import 'package:meditime/core/navigator_key.dart';
import 'package:meditime/screens/medication/detalle_receta_page.dart';
import 'package:meditime/screens/alarm/alarm_ringing_page.dart';
@pragma('vm:entry-point')
Future<void> handleNotificationActionBackground(
  NotificationResponse notificationResponse,
) async {
  debugPrint('🔥🔥🔥 CALLBACK EJECUTÁNDOSE 🔥🔥🔥');
  debugPrint('🔥 ACCIÓN: ${notificationResponse.actionId ?? "NULL"}');
  debugPrint('🔥 ID: ${notificationResponse.id ?? "NULL"}');
  debugPrint('🔥 PAYLOAD: ${notificationResponse.payload ?? "NULL"}');
  
  try {
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();

    final payload = notificationResponse.payload;
    final actionId = notificationResponse.actionId;
    final isAlarmMode = payload != null && payload.startsWith('alarm_mode');

    // ═══════════════════════════════════════════════════════════════════════
    // CRÍTICO: Si el usuario presionó un BOTÓN DE ACCIÓN, detener sonido
    // y cancelar notificación INMEDIATAMENTE, antes de cualquier
    // inicialización pesada.
    //
    // Si el usuario tocó el CUERPO de la notificación:
    //   - Modo Alarma: NO detener sonido, AlarmRingingPage lo gestiona.
    //   - Otros modos: Detener sonido y cancelar notificación.
    // ═══════════════════════════════════════════════════════════════════════
    final bool shouldStopSoundNow = actionId != null || !isAlarmMode;

    if (shouldStopSoundNow) {
      try {
        await AlarmSoundService.stopAlarm();
        debugPrint('🔥 SONIDO DE ALARMA DETENIDO (pre-procesamiento)');
      } catch (e) {
        debugPrint('🔥 Error deteniendo sonido pre-procesamiento: $e');
      }

      if (notificationResponse.id != null) {
        try {
          await NotificationService.initializeCore();
          await NotificationService.cancelFlutterLocalNotificationById(notificationResponse.id!);
          debugPrint('🔥 NOTIFICACIÓN ${notificationResponse.id} CANCELADA (pre-procesamiento)');
        } catch (e) {
          debugPrint('🔥 Error cancelando notificación pre-procesamiento: $e');
        }
      }
    }

    await NotificationService.initializeCore();
    
    if (payload == null) {
      debugPrint('🔥 PAYLOAD NULO - SALIENDO');
      return;
    }
    
    // Si el usuario toca el cuerpo de la notificación (no los botones de acción)
    if (actionId == null) {
      debugPrint('🔥 DEEP LINKING: El usuario pulsó la notificación.');
      
      final parts = payload.split('|');
      
      // Si es una alarma de pantalla completa, navegar a AlarmRingingPage
      // (el sonido sigue activo, AlarmRingingPage lo detendrá cuando el usuario actúe)
      if (isAlarmMode) {
        NotificationService._navigateToAlarmScreen(
          payload,
          notificationId: notificationResponse.id,
        );
      } else if (parts.length >= 3) {
        // Para notificaciones activas normales, ir a detalles
        final userId = parts[1];
        final docId = parts[2];
        final dateTimeStr = parts.length >= 4 ? parts[3] : null;
        
        NotificationService._navigateToDetail(userId, docId, dateTimeStr);
      }
      return;
    }
    
    debugPrint('🔥 PROCESANDO ACCIÓN: $actionId');
    
    await NotificationService.processNotificationActionAsync(
      payload: payload,
      actionId: actionId,
      notificationId: notificationResponse.id,
    );
    
    debugPrint('🔥 CALLBACK COMPLETADO EXITOSAMENTE');
  } catch (e) {
    debugPrint('🔥 ERROR CRÍTICO EN CALLBACK: $e');
    // Último intento de detener sonido en caso de error
    try {
      await AlarmSoundService.stopAlarm();
    } catch (_) {}
  }
}

/// Servicio para gestionar todo lo relacionado con notificaciones y alarmas.
///
/// Encapsula la lógica para:
/// - `flutter_local_notifications`: Mostrar notificaciones en primer plano.
/// - `android_alarm_manager_plus`: Programar tareas que se ejecutan en segundo plano (alarmas).
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isCoreInitialized = false;

  static bool _permissionsHaveBeenRequested = false;

  /// Inicializa los componentes principales del servicio de notificaciones.
  ///
  /// Configura la zona horaria, los ajustes de inicialización para Android/iOS
  /// y registra los callbacks para manejar las interacciones con las notificaciones.
  static Future<void> initializeCore() async {
    if (_isCoreInitialized) {
      return;
    }
    
    debugPrint('🔧 INICIALIZANDO NOTIFICATION SERVICE CORE');

    tz.initializeTimeZones();
    try {
      final String currentTimeZone =
          await FlutterLocalNotificationsPlugin()
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.getNotificationChannels()
              .then((channels) => tz.local.name) ??
          'America/Bogota';
      tz.setLocalLocation(tz.getLocation(currentTimeZone));
    } catch (e) {
      debugPrint(
        "Error obteniendo/configurando zona horaria local: $e. Usando America/Bogota como default.",
      );
      tz.setLocalLocation(tz.getLocation('America/Bogota'));
    }

    // CONFIGURACIÓN CRÍTICA: Configuraciones para Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // CONFIGURACIÓN CRÍTICA: Configuraciones para iOS
    DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          // NUEVO: Configuraciones adicionales para iOS
          defaultPresentAlert: true,
          defaultPresentBadge: true,
          defaultPresentSound: true,
          notificationCategories: [
            DarwinNotificationCategory(
              'MEDITIME_ALARM',
              actions: <DarwinNotificationAction>[
                DarwinNotificationAction.plain('TOMAR_ACTION', 'Tomar'),
                DarwinNotificationAction.plain('OMITIR_ACTION', 'Omitir'),
                DarwinNotificationAction.plain('APLAZAR_ACTION', 'Aplazar'),
              ],
            ),
          ],
        );

    InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
  onDidReceiveNotificationResponse: handleNotificationActionBackground,
  onDidReceiveBackgroundNotificationResponse: handleNotificationActionBackground,
    );
    
    debugPrint('CRÍTICO: Callbacks de notificación registrados correctamente');

    // CRÍTICO: Crear canales de notificación con configuraciones específicas
    await _createNotificationChannels();

    _isCoreInitialized = true;
    debugPrint(
      "NotificationService Core Inicializado con configuraciones críticas.",
    );
  }

  /// Solicita todos los permisos necesarios para que las notificaciones y alarmas
  /// funcionen correctamente en Android e iOS.
  static Future<void> requestAllNecessaryPermissions() async {
    if (!_isCoreInitialized) {
      debugPrint(
        "ADVERTENCIA: Se están solicitando permisos antes de inicializar el núcleo de NotificationService.",
      );
      await initializeCore();
    }
    if (_permissionsHaveBeenRequested) {
      return;
    }

    debugPrint("Solicitando permisos de notificación (Android)...");
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

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
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();

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

  /// Muestra una notificación simple (pasiva).
  ///
  /// Se utiliza en el "Modo Pasivo", donde la dosis se marca como tomada
  /// automáticamente y solo se informa al usuario.
  static Future<void> showSimpleNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isCoreInitialized) {
      debugPrint(
        "NotificationService Core no está inicializado. Intentando inicializar para mostrar notificación...",
      );
      await initializeCore();
      if (!_isCoreInitialized) {
        debugPrint(
          "Fallo al inicializar NotificationService Core en showSimpleNotification. No se puede mostrar la notificación.",
        );
        return;
      }
    }

    final hideOnLockScreen = await PreferenceService().getHideMedicineNameOnLockScreen();

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'meditime_dosis_channel',
      'MediTime Recordatorios de Dosis',
      channelDescription: 'Canal para recordatorios de dosis de medicamentos.',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: hideOnLockScreen ? NotificationVisibility.private : NotificationVisibility.public,
      autoCancel: false,
      ongoing: false,
      ticker: 'Hora de tomar medicamento',
      // NUEVO: Configuraciones adicionales para fondo
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      usesChronometer: false,
      channelShowBadge: true,
      onlyAlertOnce: false,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        htmlFormatBigText: true,
        htmlFormatContentTitle: true,
        summaryText: 'MediTime',
      ),
      silent: false,
      enableLights: true,
      ledColor: const Color.fromARGB(255, 255, 0, 0),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
      // NUEVO: Configuraciones adicionales para iOS
      categoryIdentifier: 'MEDITIME_ALARM',
      threadIdentifier: 'meditime_thread',
    );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
    debugPrint(
      "Notificación local mostrada - ID: $id, Título: $title, Hora: ${DateTime.now()}",
    );
  }

  /// Detiene cualquier sonido y vibración continua de alarma reproduciéndose en el dispositivo
  static Future<void> stopAlarmSound() async {
    await AlarmSoundService.stopAlarm();
  }

  static Future<void> _createNotificationChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      // Canal para notificaciones simples
      const AndroidNotificationChannel simpleChannel =
          AndroidNotificationChannel(
            'meditime_dosis_channel',
            'MediTime Recordatorios de Dosis',
            description: 'Canal para recordatorios de dosis de medicamentos.',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            ledColor: Color.fromARGB(255, 255, 0, 0),
            showBadge: true,
          );

      // Canal para notificaciones activas
      const AndroidNotificationChannel
      activeChannel = AndroidNotificationChannel(
        'meditime_active_dosis_channel',
        'MediTime Dosis Activas',
        description:
            'Canal para notificaciones de dosis que requieren acción del usuario.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color.fromARGB(255, 255, 0, 0),
        showBadge: true,
      );

      // Canal para notificaciones aplazadas
      const AndroidNotificationChannel snoozeChannel =
          AndroidNotificationChannel(
            'meditime_snooze_channel',
            'MediTime Dosis Aplazadas',
            description: 'Canal para recordatorios aplazados.',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            ledColor: Color.fromARGB(255, 255, 0, 0),
            showBadge: true,
          );

      // Canal legacy para modo alarma
      const AndroidNotificationChannel alarmChannel =
          AndroidNotificationChannel(
            'meditime_alarm_channel',
            'MediTime Alarma Despertador',
            description:
                'Canal de máxima prioridad para alarmas sonoras continuas de medicamentos.',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            ledColor: Color.fromARGB(255, 255, 0, 0),
            showBadge: true,
          );

      // Canal v2 para modo alarma con USAGE_ALARM (máxima prioridad)
      const AndroidNotificationChannel alarmChannelV2 =
          AndroidNotificationChannel(
            'meditime_alarm_channel_v2',
            'MediTime Alarma Despertador',
            description:
                'Canal de máxima prioridad para alarmas sonoras continuas de medicamentos.',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            ledColor: Color.fromARGB(255, 255, 0, 0),
            showBadge: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          );

      await androidImplementation.createNotificationChannel(simpleChannel);
      await androidImplementation.createNotificationChannel(activeChannel);
      await androidImplementation.createNotificationChannel(snoozeChannel);
      await androidImplementation.createNotificationChannel(alarmChannel);
      await androidImplementation.createNotificationChannel(alarmChannelV2);

      debugPrint(
        "Canales de notificación creados con configuraciones críticas (incluyendo alarm_channel_v2)",
      );
    }
  }

  /// Muestra una notificación con intención de pantalla completa en Modo Alarma.
  ///
  /// Incluye botones Tomar/Omitir/Aplazar.
  static Future<void> showAlarmModeNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    debugPrint('🚨 CREANDO NOTIFICACIÓN EN MODO ALARMA');
    debugPrint('🚨 ID: $id');
    debugPrint('🚨 PAYLOAD: $payload');

    int snoozeMinutes = 10;
    try {
      snoozeMinutes = await PreferenceService().getSnoozeDuration();
    } catch (e) {
      debugPrint("Error leyendo duración de aplazamiento: $e");
    }

    final String snoozeLabel = 'Aplazar $snoozeMinutes min';

    final List<AndroidNotificationAction> actions = <AndroidNotificationAction>[
      AndroidNotificationAction(
        'TOMAR_ACTION',
        'Tomar',
        showsUserInterface: false,
        cancelNotification: true, // CRÍTICO: Cancelar notificación inmediatamente para detener FLAG_INSISTENT
      ),
      AndroidNotificationAction(
        'OMITIR_ACTION',
        'Omitir',
        showsUserInterface: false,
        cancelNotification: true, // CRÍTICO: Cancelar notificación inmediatamente para detener FLAG_INSISTENT
      ),
      AndroidNotificationAction(
        'APLAZAR_ACTION',
        snoozeLabel,
        showsUserInterface: false,
        cancelNotification: true, // CRÍTICO: Cancelar notificación inmediatamente para detener FLAG_INSISTENT
      ),
    ];

    bool hideOnLockScreen = false;
    try {
      hideOnLockScreen = await PreferenceService().getHideMedicineNameOnLockScreen();
    } catch (_) {}

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'meditime_alarm_channel_v2',
      'MediTime Alarma Despertador',
      channelDescription:
          'Canal de máxima prioridad para alarmas sonoras continuas de medicamentos.',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: true,
      actions: actions,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: hideOnLockScreen ? NotificationVisibility.private : NotificationVisibility.public,
      autoCancel: false,
      ongoing: true,
      ticker: '¡ALARMA: Hora de tomar tu medicamento!',
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      usesChronometer: false,
      channelShowBadge: true,
      onlyAlertOnce: false,
      timeoutAfter: 300000, // 5 minutos: auto-cancelar notificación si no hay interacción (sincronizado con AlarmSoundService.maxAlarmDuration)
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        htmlFormatBigText: true,
        htmlFormatContentTitle: true,
        summaryText: '🚨 MediTime Alarma',
      ),
      silent: false,
      enableLights: true,
      ledColor: const Color.fromARGB(255, 255, 0, 0),
      ledOnMs: 1000,
      ledOffMs: 500,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      additionalFlags: Int32List.fromList([4]), // 4 = FLAG_INSISTENT
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
      categoryIdentifier: 'MEDITIME_ALARM',
      threadIdentifier: 'meditime_alarm_thread',
    );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    // CRÍTICO: Adjuntar deleteIntent para que al descartar la notificación
    // (swipe, clear all, timeout) se detenga automáticamente el sonido.
    await AlarmSoundService.attachDismissListener(id);

    debugPrint("Notificación MODO ALARMA mostrada - ID: $id, Título: $title");
  }

  /// Muestra una notificación activa con botones de acción (Tomar, Omitir, Aplazar).
  ///
  /// Se utiliza en el "Modo Activo", requiriendo la interacción del usuario
  /// para confirmar el estado de la dosis.
  static Future<void> showActiveNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    debugPrint('🔔 CREANDO NOTIFICACIÓN ACTIVA');
    debugPrint('🔔 ID: $id');
    debugPrint('🔔 PAYLOAD: $payload');
    debugPrint('Creando notificación activa con botones');
    // Leemos la preferencia para obtener la duración del aplazamiento
    int snoozeMinutes = 15; // Default fallback
    try {
      snoozeMinutes = await PreferenceService().getSnoozeDuration();
    } catch (e) {
      debugPrint("Error leyendo duración de aplazamiento: $e");
    }

    final String snoozeLabel = 'Aplazar $snoozeMinutes min';

    // Definimos las acciones con el texto dinámico
  final List<AndroidNotificationAction> actions = <AndroidNotificationAction>[
      AndroidNotificationAction(
        'TOMAR_ACTION',
        'Tomar',
    showsUserInterface: false, // Procesar en segundo plano sin abrir la app
        cancelNotification: true, // CRÍTICO: Cancelar inmediatamente para evitar sonido persistente
      ),
      AndroidNotificationAction(
        'OMITIR_ACTION',
        'Omitir',
    showsUserInterface: false, // Procesar en segundo plano sin abrir la app
        cancelNotification: true, // CRÍTICO: Cancelar inmediatamente para evitar sonido persistente
      ),
      AndroidNotificationAction(
        'APLAZAR_ACTION',
        snoozeLabel,
    showsUserInterface: false, // Procesar en segundo plano sin abrir la app
        cancelNotification: true, // CRÍTICO: Cancelar inmediatamente para evitar sonido persistente
      ),
    ];

    bool hideOnLockScreen = false;
    try {
      hideOnLockScreen = await PreferenceService().getHideMedicineNameOnLockScreen();
    } catch (_) {}

    // CONFIGURACIÓN CRÍTICA: Máxima prioridad para notificaciones activas
    final AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'meditime_active_dosis_channel',
      'MediTime Dosis Activas',
      channelDescription:
          'Canal para notificaciones de dosis que requieren acción del usuario.',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      actions: actions,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: hideOnLockScreen ? NotificationVisibility.private : NotificationVisibility.public,
      autoCancel: false,
      ongoing: true, // CRÍTICO: Mantener visible hasta que el usuario actúe
      ticker: 'Acción requerida: Hora de tomar medicamento',
      // NUEVO: Configuraciones adicionales para máxima visibilidad
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      usesChronometer: false,
      channelShowBadge: true,
      onlyAlertOnce: false,
      timeoutAfter: null,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        htmlFormatBigText: true,
        htmlFormatContentTitle: true,
        summaryText: 'MediTime Dosis',
      ),
      silent: false,
      enableLights: true,
      ledColor: const Color.fromARGB(255, 255, 0, 0),
      ledOnMs: 1000,
      ledOffMs: 500,
      // CRÍTICO: Configurar vibración personalizada
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
    debugPrint('🔔 NOTIFICACIÓN ACTIVA CREADA EXITOSAMENTE');
    debugPrint('🔔 ACCIONES DISPONIBLES: TOMAR_ACTION, OMITIR_ACTION, APLAZAR_ACTION');
    debugPrint("Notificación ACTIVA mostrada - ID: $id, Título: $title");
  }

  /// Reprograma la siguiente dosis pendiente de un tratamiento.
  ///
  /// Cancela cualquier alarma anterior para esta serie y busca la próxima
  /// dosis con estado 'pendiente' para programar una nueva alarma.
  static Future<void> rescheduleNextPendingDose(
    Tratamiento tratamiento,
    String userId, [
    CaregiverProfile? profile,
  ]) async {
    // Cancelamos cualquier alarma que pudiera estar programada para esta serie
    await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);

    // Buscamos la próxima dosis que esté pendiente
    final proximaDosis = await _findNextPendingDose(tratamiento: tratamiento);

    if (proximaDosis != null) {
      debugPrint(
        "REPROGRAMANDO: Próxima dosis para '${tratamiento.nombreMedicamento}' será a las $proximaDosis",
      );
      await _rescheduleAlarm(proximaDosis, tratamiento, userId, profile);
    } else {
      debugPrint(
        "REPROGRAMANDO: No hay más dosis pendientes para '${tratamiento.nombreMedicamento}'.",
      );
    }
  }

  /// Aplaza una notificación por un número determinado de minutos.
  ///
  /// Cancela la notificación actual y programa una nueva notificación `zonedSchedule`
  /// para el futuro.
  static Future<void> snoozeNotification(
    int? notificationId,
    String payload,
    DateTime originalDoseTime,
    int snoozeMinutes,
  ) async {
    if (notificationId == null) return;

    await _notificationsPlugin.cancel(notificationId);

    // Usamos la duración recibida como parámetro
    final snoozeTime = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(minutes: snoozeMinutes));

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      'Recordatorio Aplazado',
      'Es hora de tomar tu dosis de las ${DateFormat('hh:mm a').format(originalDoseTime)}',
      snoozeTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'meditime_snooze_channel',
          'MediTime Dosis Aplazadas',
          channelDescription: 'Canal para recordatorios aplazados.',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            'Es hora de tomar tu dosis de las ${DateFormat('hh:mm a').format(originalDoseTime)}',
            contentTitle: 'Recordatorio Aplazado',
            htmlFormatBigText: true,
            htmlFormatContentTitle: true,
            summaryText: 'MediTime Aplazado',
          ),
          actions: [
            AndroidNotificationAction(
              'TOMAR_ACTION',
              'Tomar',
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              'OMITIR_ACTION',
              'Omitir',
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              'APLAZAR_ACTION',
              'Aplazar',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // CRÍTICO: NO usar matchDateTimeComponents, el aplazamiento debe ser un disparo único
      payload: payload,
    );
    debugPrint(
      "Notificación $notificationId aplazada por $snoozeMinutes minutos.",
    );
  }

  /// Cancela todas las notificaciones locales visibles.
  static Future<void> cancelAllFlutterLocalNotifications() async {
    await _notificationsPlugin.cancelAll();
    debugPrint(
      "Todas las notificaciones de flutter_local_notifications han sido canceladas.",
    );
  }

  /// Cancela todas las notificaciones actualmente activas en Android (visibles en la bandeja)
  static Future<void> cancelAllActiveAndroidNotifications() async {
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final List<ActiveNotification>? active = await androidImpl?.getActiveNotifications();
      if (active != null) {
        for (final n in active) {
          if (n.id != null) {
            await _notificationsPlugin.cancel(n.id!);
          }
        }
        debugPrint("${active.length} notificaciones activas canceladas");
      }
    } catch (e) {
      debugPrint("Error cancelando notificaciones activas: $e");
    }
  }

  /// Cancela una notificación local específica por su ID.
  static Future<void> cancelFlutterLocalNotificationById(int id) async {
    await _notificationsPlugin.cancel(id);
    debugPrint(
      "Notificación de flutter_local_notifications con ID: $id cancelada.",
    );
  }

  /// Verifica si la aplicación tiene permisos para mostrar notificaciones.
  static Future<bool> checkNotificationPermissions() async {
    final androidImplementation =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              /// Verifica si la aplicación tiene permisos para mostrar notificaciones.
              ///
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      return await androidImplementation.areNotificationsEnabled() ?? false;
    }

    return false;
  }

  /// Verifica si la aplicación tiene permisos para programar alarmas exactas en Android.
  static Future<bool> checkExactAlarmPermissions() async {
    final androidImplementation =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      return await androidImplementation.canScheduleExactNotifications() ??
          false;
    }

    return false;
  }

  /// Programa la primera alarma para un tratamiento recién creado.
  ///
  /// Esta alarma, al ejecutarse, llamará a `alarmCallbackLogic`, que se encargará de reprogramar la siguiente.
  static Future<void> scheduleNewTreatment({
    required String nombreMedicamento,
    required String presentacion,
    required int intervaloEnHoras,
    required DateTime primeraDosisDateTime,
    required DateTime fechaFinTratamiento,
    required int prescriptionAlarmManagerId,
    required String userId,
    required String docId,
    CaregiverProfile? profile,
  }) async {
    if (primeraDosisDateTime.isBefore(fechaFinTratamiento)) {
      debugPrint(
        "SCHEDULE: Programando primera alarma para $nombreMedicamento a las $primeraDosisDateTime con ID de Serie: $prescriptionAlarmManagerId",
      );

      // CAMBIO CRÍTICO: Incluir todos los datos necesarios para funcionamiento offline
      final Map<String, dynamic> completeParams = _buildAlarmParams(
        nombreMedicamento: nombreMedicamento,
        presentacion: presentacion,
        intervaloHoras: intervaloEnHoras,
        fechaFinTratamiento: fechaFinTratamiento,
        prescriptionAlarmId: prescriptionAlarmManagerId,
        userId: userId,
        docId: docId,
        doseTime: primeraDosisDateTime,
        profileId: profile?.id,
        pacienteNombre: profile?.name,
        habitacion: profile?.roomNumber,
        categoria: profile?.category,
        dosisPorToma: 1, // Default or fetch from formData if needed, but 1 is safe default here if not passed
      );
      
      // We pass isExternalUser and linkedUid through _buildAlarmParams by modifying it
      if (profile != null) {
        completeParams['isExternalUser'] = profile.isExternalUser;
        completeParams['linkedUid'] = profile.linkedUid;
      }

      await AndroidAlarmManager.oneShotAt(
        primeraDosisDateTime,
        prescriptionAlarmManagerId,
        alarmCallbackLogic,
        exact: true,
        wakeup: true,
        alarmClock: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true,
        params: completeParams,
      );
    }
  }

  /// Cancela una serie de alarmas completa. Útil al eliminar un tratamiento.
  ///
  /// Utiliza el `prescriptionAlarmId` que es único para cada cadena de alarmas de un tratamiento.
  static Future<void> cancelTreatmentAlarms(int prescriptionAlarmId) async {
    debugPrint(
      "CANCEL: Cancelando serie de alarmas completa con ID: $prescriptionAlarmId",
    );
    await AndroidAlarmManager.cancel(prescriptionAlarmId);
  }

  /// Marca un tratamiento como revocado localmente (no se mostrarán notificaciones en callbacks offline)
  static Future<void> revokeTreatmentLocally(String userId, String docId) async {
    try {
      await PreferenceService().addRevokedTreatment(userId, docId);
      // Además, cancelar cualquier notificación activa para minimizar ruido inmediato
      await cancelAllActiveAndroidNotifications();
    } catch (e) {
      debugPrint("Error revocando tratamiento localmente: $e");
    }
  }

  /// Omite una dosis y reprograma la siguiente.
  static Future<void> omitDoseAndReschedule({
    required Tratamiento tratamiento,
    required DocumentReference docRef,
    required String userId,
  }) async {
    debugPrint(
      "OMIT: Cancelando alarma existente con ID de Serie: ${tratamiento.prescriptionAlarmId}",
    );
    await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);

    final DateTime? proximaDosisReal = await _findNextPendingDose(
      tratamiento: tratamiento,
    );

    if (proximaDosisReal != null) {
      debugPrint(
        "OMIT: Reprogramando la alarma para las $proximaDosisReal con ID de Serie: ${tratamiento.prescriptionAlarmId}",
      );
      await _rescheduleAlarm(proximaDosisReal, tratamiento, userId);
    } else {
      debugPrint("OMIT: No hay más dosis futuras que programar.");
    }
  }

  /// Revierte la omisión de una dosis y reprograma la alarma correspondiente.
  static Future<void> undoOmissionAndReschedule({
    required Tratamiento tratamiento,
    required DocumentReference docRef,
    required String userId,
  }) async {
    debugPrint(
      "UNDO: Cancelando cualquier alarma existente con ID de Serie: ${tratamiento.prescriptionAlarmId} para reevaluar.",
    );
    await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);

    final freshSnapshot = await docRef.get();
    // Creamos un nuevo objeto Tratamiento con los datos más recientes de Firestore
    final freshTratamiento = Tratamiento.fromFirestore(
      freshSnapshot as DocumentSnapshot<Map<String, dynamic>>,
    );

    final DateTime? proximaDosisReal = await _findNextPendingDose(
      tratamiento: freshTratamiento,
    );

    if (proximaDosisReal != null) {
      debugPrint(
        "UNDO: La próxima alarma real es a las $proximaDosisReal. Reprogramando con ID de Serie: ${tratamiento.prescriptionAlarmId}",
      );
      await _rescheduleAlarm(proximaDosisReal, freshTratamiento, userId);
    } else {
      debugPrint("UNDO: No hay más dosis futuras que programar.");
    }
  }

  /// Reactiva todas las alarmas pendientes para un usuario y sus perfiles de cuidador.
  ///
  /// Este método es crucial y se llama al iniciar la aplicación (`AuthWrapper`)
  /// para asegurar que las alarmas persistan después de que el sistema operativo cierre la app.
  static Future<void> reactivateAlarmsForUser(String userId) async {
    debugPrint(
      "--- Iniciando reactivación de alarmas para el usuario $userId ---",
    );
    final firestoreService = FirestoreService();
    try {
      // 1. Reactivar tratamientos personales del usuario
      try {
        final List<Tratamiento> todosLosTratamientos = await firestoreService
            .getMedicamentosStream(userId)
            .first
            .timeout(const Duration(seconds: 4));

        for (var tratamiento in todosLosTratamientos) {
          await _reactivateSingleTreatment(tratamiento, userId, null);
        }
      } catch (e) {
        debugPrint("Aviso al reactivar tratamientos personales: $e");
      }

      // 2. Reactivar tratamientos de perfiles asignados en Modo Cuidador
      try {
        final profiles = await firestoreService
            .getCaregiverProfiles(userId)
            .timeout(const Duration(seconds: 3));

        for (var profile in profiles) {
          try {
            final profileTreatments = await firestoreService
                .getMedicamentosStream(userId, profile)
                .first
                .timeout(const Duration(seconds: 3));

            for (var tratamiento in profileTreatments) {
              await _reactivateSingleTreatment(tratamiento, userId, profile);
            }
          } catch (pe) {
            debugPrint("Aviso al reactivar tratamientos del perfil ${profile.name}: $pe");
          }
        }
      } catch (ce) {
        debugPrint("Aviso al cargar perfiles de cuidador para reactivación: $ce");
      }
    } catch (e) {
      debugPrint("Error durante la reactivación de alarmas: $e");
    }
    debugPrint("--- Reactivación de alarmas completada ---");
  }

  static Future<void> _reactivateSingleTreatment(
    Tratamiento tratamiento,
    String userId, [
    CaregiverProfile? profile,
  ]) async {
    if (tratamiento.prescriptionAlarmId == 0) return;

    // Encontrar la próxima dosis que esté realmente pendiente
    final DateTime? proximaDosis = await _findNextPendingDose(
      tratamiento: tratamiento,
    );

    if (proximaDosis != null) {
      debugPrint(
        "Reactivando alarma para '${tratamiento.nombreMedicamento}'. Próxima dosis: $proximaDosis (ID: ${tratamiento.prescriptionAlarmId})",
      );
      await _rescheduleAlarm(proximaDosis, tratamiento, userId, profile);
    } else {
      debugPrint(
        "No hay dosis pendientes que reactivar para '${tratamiento.nombreMedicamento}'.",
      );
    }
  }

  /// Programa una alarma que puede funcionar sin conexión a internet.
  ///
  /// Esto es posible porque todos los datos necesarios para la siguiente alarma
  /// se pasan a través del mapa de `params`.
  static Future<void> scheduleOfflineAlarm({
    required DateTime scheduleTime,
    required int alarmId,
    required Map<String, dynamic> params,
  }) async {
    try {
      await AndroidAlarmManager.oneShotAt(
        scheduleTime,
        alarmId,
        alarmCallbackLogic,
        exact: true,
        wakeup: true,
        alarmClock: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true,
        params: params,
      );
      debugPrint(
        "Alarma offline programada para: $scheduleTime con ID: $alarmId",
      );
    } catch (e) {
      debugPrint("ERROR programando alarma offline: $e");
    }
  }

  // --- MÉTODOS PRIVADOS AUXILIARES ---

  /// Construye el mapa de parámetros completo que se pasará a `alarmCallbackLogic`.
  static Map<String, dynamic> _buildAlarmParams({
    required String nombreMedicamento,
    required String presentacion,
    required int intervaloHoras,
    required DateTime fechaFinTratamiento,
    required int prescriptionAlarmId,
    required String userId,
    required String docId,
    required DateTime doseTime,
    String? profileId,
    String? pacienteNombre,
    String? habitacion,
    String? categoria,
    int? dosisPorToma,
    bool? isExternalUser,
    String? linkedUid,
  }) {
    return {
      // IDs y configuración básica
      'currentNotificationId': Random().nextInt(100000),
      'prescriptionAlarmId': prescriptionAlarmId,
      'userId': userId,
      'docId': docId,
      'doseTime': doseTime.toIso8601String(),

      // Datos del medicamento (CRÍTICO: para funcionamiento offline)
      'nombreMedicamento': nombreMedicamento,
      'presentacion': presentacion,
      'intervaloHoras': intervaloHoras,
      'fechaFinTratamientoString': fechaFinTratamiento.toIso8601String(),

      // Datos del paciente/cuidador
      'profileId': profileId,
      'pacienteNombre': pacienteNombre,
      'habitacion': habitacion,
      'categoria': categoria,
      'dosisPorToma': dosisPorToma ?? 1,
      'isExternalUser': isExternalUser,
      'linkedUid': linkedUid,

      // Metadatos adicionales
      'scheduledAt': DateTime.now().toIso8601String(),
      'version': '2.0', // Para tracking de versiones del payload
    };
  }

  /// Lógica interna y centralizada para programar una alarma con `AndroidAlarmManager`.
  static Future<void> _rescheduleAlarm(
    DateTime scheduleTime,
    Tratamiento tratamiento,
    String userId, [
    CaregiverProfile? profile,
  ]) async {
    await AndroidAlarmManager.oneShotAt(
      scheduleTime,
      tratamiento.prescriptionAlarmId,
      alarmCallbackLogic,
      exact: true,
      wakeup: true,
      alarmClock: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
      params: _buildAlarmParams(
        nombreMedicamento: tratamiento.nombreMedicamento,
        presentacion: tratamiento.presentacion,
        intervaloHoras: tratamiento.intervaloDosis.inHours,
        fechaFinTratamiento: tratamiento.fechaFinTratamiento,
        prescriptionAlarmId: tratamiento.prescriptionAlarmId,
        userId: userId,
        docId: tratamiento.id,
        doseTime: scheduleTime,
        profileId: profile?.id,
        pacienteNombre: profile?.name,
        habitacion: profile?.roomNumber,
        categoria: profile?.category,
        dosisPorToma: tratamiento.dosisPorToma,
        isExternalUser: profile?.isExternalUser,
        linkedUid: profile?.linkedUid,
      ),
    );
    debugPrint("Alarma reprogramada para: $scheduleTime con datos completos (${profile?.name ?? 'Personal'})");
  }

  /// Busca la próxima dosis futura que deba programarse como alarma.
  ///
  /// Es 100% compatible tanto con tratamientos tradicionales como con tratamientos de carga lazy
  /// (donde `doseStatus` no contiene las dosis futuras precalculadas en Firestore).
  static Future<DateTime?> _findNextPendingDose({
    required Tratamiento tratamiento,
  }) async {
    final now = DateTime.now();

    // 1. Verificar si existe alguna dosis futura explícitamente pendiente o aplazada en el mapa doseStatus
    DateTime? earliestExplicitPending;
    final sortedDoseKeys = tratamiento.doseStatus.keys.toList()..sort();
    for (final key in sortedDoseKeys) {
      final doseTime = DateTime.tryParse(key);
      if (doseTime != null && doseTime.isAfter(now)) {
        final status = tratamiento.doseStatus[key];
        if (status == DoseStatus.pendiente || status == DoseStatus.aplazada) {
          earliestExplicitPending = doseTime;
          break;
        }
      }
    }

    // 2. Generar iterativamente la serie de dosis según el intervalo y fecha de inicio.
    // Esto garantiza encontrar la próxima dosis real en tratamientos lazy.
    final interval = tratamiento.intervaloDosis.inMinutes > 0
        ? tratamiento.intervaloDosis
        : const Duration(hours: 8);

    DateTime currentDose = tratamiento.fechaInicioTratamiento;

    while (currentDose.isBefore(tratamiento.fechaFinTratamiento)) {
      if (currentDose.isAfter(now)) {
        // Verificar si esta dosis fue omitida en skippedDoses
        final isSkipped = tratamiento.skippedDoses.any(
          (d) => d.difference(currentDose).inMinutes.abs() <= 15,
        );

        // Verificar si tiene un estado registrado en doseStatus
        DoseStatus? recordedStatus;
        for (final entry in tratamiento.doseStatus.entries) {
          final dt = DateTime.tryParse(entry.key);
          if (dt != null && dt.difference(currentDose).inMinutes.abs() <= 15) {
            recordedStatus = entry.value;
            break;
          }
        }

        // Si no fue tomada ni omitida, es una dosis pendiente
        if (!isSkipped &&
            recordedStatus != DoseStatus.tomada &&
            recordedStatus != DoseStatus.omitida) {
          if (earliestExplicitPending != null &&
              earliestExplicitPending.isBefore(currentDose)) {
            return earliestExplicitPending;
          }
          return currentDose;
        }
      }
      currentDose = currentDose.add(interval);
    }

    return earliestExplicitPending;
  }

  /// Marca la próxima dosis futura como 'omitida' y reprograma la siguiente.
  /// Retorna `true` si se pudo omitir, `false` si no había dosis futuras para omitir.
  static Future<bool> skipNextDoseAndReschedule({
    required Tratamiento tratamiento,
    required DocumentReference docRef,
    required String userId, // Añadimos userId
  }) async {
    // 1. Buscamos la próxima dosis PENDIENTE
    final DateTime? proximaDosis = await _findNextPendingDose(
      tratamiento: tratamiento,
    );

    if (proximaDosis == null) {
      debugPrint("SKIP: No se encontraron dosis futuras para omitir.");
      return false;
    }

    debugPrint("SKIP: Omitiendo la dosis de las $proximaDosis.");

    // 2. Actualizamos Firestore a OMITIDA
    await FirestoreService().updateDoseStatus(
      userId,
      tratamiento.id,
      proximaDosis,
      DoseStatus.omitida,
    );

    // 3. Cancelamos la serie de alarmas actual
    await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);
    debugPrint(
      "SKIP: Alarma existente con ID de Serie ${tratamiento.prescriptionAlarmId} cancelada.",
    );

    // 4. Obtenemos los datos más recientes y creamos un nuevo objeto Tratamiento actualizado
    final freshSnapshot = await docRef.get();
    final freshTratamiento = Tratamiento.fromFirestore(
      freshSnapshot as DocumentSnapshot<Map<String, dynamic>>,
    );

    // 5. Buscamos la siguiente dosis PENDIENTE después de la que acabamos de omitir
    final DateTime? siguienteDosisValida = await _findNextPendingDose(
      tratamiento: freshTratamiento,
    );

    if (siguienteDosisValida != null) {
      // 6. Si existe una siguiente dosis, la reprogramamos
      debugPrint(
        "SKIP: Reprogramando la alarma para las $siguienteDosisValida con ID de Serie: ${freshTratamiento.prescriptionAlarmId}",
      );
      await _rescheduleAlarm(siguienteDosisValida, freshTratamiento, userId);
    } else {
      debugPrint(
        "SKIP: No hay más dosis futuras que programar después de la omisión.",
      );
    }

    return true;
  }

  /// Maneja una acción de notificación en modo fallback (sin conexión a Firebase).
  static Future<void> handleNotificationActionFallback({
    required String actionId,
    required String userId,
    required String docId,
    required DateTime doseTime,
    required int? notificationId,
  }) async {
    debugPrint('=== FALLBACK: Manejando acción $actionId sin Firebase ===');

    try {
      // Cancelar la notificación actual
      if (notificationId != null) {
        await cancelFlutterLocalNotificationById(notificationId);
        debugPrint('Notificación $notificationId cancelada en modo fallback');
      }

      // Mostrar notificación de confirmación
      final String confirmationMessage;
      switch (actionId) {
        case 'TOMAR_ACTION':
          confirmationMessage = 'Dosis marcada como tomada (sin conexión)';
          break;
        case 'OMITIR_ACTION':
          confirmationMessage = 'Dosis omitida (sin conexión)';
          break;
        case 'APLAZAR_ACTION':
          confirmationMessage = 'Dosis aplazada (sin conexión)';
          break;
        default:
          confirmationMessage = 'Acción procesada (sin conexión)';
      }

      await showSimpleNotification(
        id: Random().nextInt(100000),
        title: 'Acción registrada',
        body: '$confirmationMessage. Se sincronizará cuando tengas conexión.',
      );

      debugPrint('=== FALLBACK: Acción procesada correctamente ===');
    } catch (e) {
      debugPrint('ERROR en fallback: $e');
    }
  }

  /// Asegura que Firebase esté inicializado antes de intentar usarlo.
  static Future<bool> ensureFirebaseInitialized() async {
    try {
      // Verificar si Firebase ya está inicializado
      if (Firebase.apps.isNotEmpty) {
        debugPrint('Firebase ya está inicializado');
        return true;
      }

      // Intentar inicializar Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 10));

      debugPrint('Firebase inicializado correctamente');
      return true;
    } catch (e) {
      debugPrint('ERROR inicializando Firebase: $e');
      return false;
    }
  }

  /// Muestra una notificación de prueba para fines de depuración.
  static Future<void> showTestNotification() async {
    debugPrint('=== CREANDO NOTIFICACIÓN DE PRUEBA ===');
    
    await showActiveNotification(
      id: 99999,
      title: 'PRUEBA: Notificación de Prueba',
      body: 'Presiona un botón para probar el callback',
      payload: 'active_notification|test_user|test_doc|${DateTime.now().toIso8601String()}',
    );
    
    debugPrint('Notificación de prueba creada con ID: 99999');
  }

  /// Muestra una notificación de prueba para diagnosticar el funcionamiento de los callbacks.
  static Future<void> checkNotificationCallbacks() async {
    debugPrint('🔍 VERIFICANDO CALLBACKS DE NOTIFICACIÓN');
    
    // Crear una notificación simple para probar
    await _notificationsPlugin.show(
      88888,
      'Test Callback',
      'Toca esta notificación para probar',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Channel',
          importance: Importance.max,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction(
              'TEST_ACTION',
              'Probar',
              showsUserInterface: false,
            ),
          ],
        ),
      ),
      payload: 'active_notification|test|test|${DateTime.now().toIso8601String()}',
    );
    
    debugPrint('🔍 Notificación de prueba creada - ID: 88888');
  }

  /// Verifica si hay notificaciones activas al abrir la app.
  static Future<void> handlePendingNotificationActions() async {
    debugPrint('🔄 Verificando acciones de notificación pendientes...');
    
    try {
      // Obtener notificaciones activas
      final List<ActiveNotification>? activeNotifications = 
          await _notificationsPlugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.getActiveNotifications();
      
      if (activeNotifications != null && activeNotifications.isNotEmpty) {
        debugPrint('📱 Encontradas ${activeNotifications.length} notificaciones activas');
        for (var notification in activeNotifications) {
          debugPrint('📱 Notificación activa ID: ${notification.id}, Título: ${notification.title}');
        }
      } else {
        debugPrint('📱 No hay notificaciones activas');
      }
    } catch (e) {
      debugPrint('ERROR verificando notificaciones activas: $e');
    }
  }

  /// Procesa de forma asíncrona la acción realizada por el usuario en una notificación.
  static Future<void> processNotificationActionAsync({
    required String payload,
    required String actionId,
    required int? notificationId,
  }) async {
    debugPrint('🔥 INICIANDO PROCESAMIENTO ASYNC');
    
    try {
      if (!payload.startsWith('active_notification') && !payload.startsWith('alarm_mode')) {
        debugPrint('🔥 NO ES NOTIFICACIÓN DE ACCIÓN VÁLIDA - SALIENDO');
        return;
      }
      
      // Parsear payload
      final parts = payload.split('|');
      if (parts.length < 4) {
        debugPrint('🔥 PAYLOAD MALFORMADO - SALIENDO');
        return;
      }
      
      final userId = parts[1];
      final docId = parts[2];
      final doseTime = DateTime.parse(parts[3]);
      
      // Guard: validar usuario actual y tratamiento no revocado
      try {
        final prefs = PreferenceService();
        final currentUserId = await prefs.getCurrentUserId();
        final revoked = await prefs.isTreatmentRevoked(userId, docId);
        if (currentUserId == null || currentUserId != userId || revoked) {
          debugPrint('🔥 GUARD ACTIVADO - Bloqueando acción. currentUserId=$currentUserId revoked=$revoked');
          if (notificationId != null) {
            await cancelFlutterLocalNotificationById(notificationId);
          }
          return;
        }
      } catch (e) {
        debugPrint('🔥 ERROR EN GUARD: $e');
      }

      debugPrint('🔥 PROCESANDO ACCIÓN: $actionId para usuario: $userId');
      
      // Inicializar Firebase de forma segura
      bool firebaseReady = false;
      try {
        WidgetsFlutterBinding.ensureInitialized();
        firebaseReady = await ensureFirebaseInitialized();
        debugPrint('🔥 FIREBASE LISTO: $firebaseReady');
      } catch (e) {
        debugPrint('🔥 ERROR INICIALIZANDO FIREBASE: $e');
      }
      
      // Siempre detener sonido de alarma inmediatamente
      await stopAlarmSound();

      // Procesar la acción si Firebase está listo
      if (firebaseReady) {
        try {
          final firestoreService = FirestoreService();
          DoseStatus newStatus;
          
          switch (actionId) {
            case 'TOMAR_ACTION':
              newStatus = DoseStatus.tomada;
              break;
            case 'OMITIR_ACTION':
              newStatus = DoseStatus.omitida;
              break;
            case 'APLAZAR_ACTION':
              newStatus = DoseStatus.aplazada;
              break;
            default:
              debugPrint('🔥 ACCIÓN NO RECONOCIDA: $actionId');
              return;
          }
          
          await firestoreService.updateDoseStatus(userId, docId, doseTime, newStatus);
          debugPrint('🔥 ESTADO ACTUALIZADO EN FIRESTORE: ${newStatus.toString().split('.').last}');
          
          // Reprogramar siguiente dosis al tomar u omitir
          if (actionId == 'TOMAR_ACTION' || actionId == 'OMITIR_ACTION') {
            try {
              final docRef = firestoreService.getMedicamentoDocRef(userId, docId);
              final docSnap = await docRef.get().timeout(const Duration(seconds: 3));
              if (docSnap.exists) {
                final tratamiento = Tratamiento.fromFirestore(docSnap as DocumentSnapshot<Map<String, dynamic>>);
                await rescheduleNextPendingDose(tratamiento, userId);
              }
            } catch (e) {
              debugPrint('🔥 ERROR REPROGRAMANDO SIGUIENTE DOSIS CON FIREBASE: $e');
            }
          }

          // Manejar aplazamiento
          if (actionId == 'APLAZAR_ACTION') {
            try {
              final preferenceService = PreferenceService();
              final snoozeMinutes = await preferenceService.getSnoozeDuration();
              await snoozeNotification(
                notificationId,
                payload,
                doseTime,
                snoozeMinutes,
              );
              debugPrint('🔥 NOTIFICACIÓN APLAZADA POR $snoozeMinutes MINUTOS');
            } catch (e) {
              debugPrint('🔥 ERROR APLAZANDO: $e');
            }
          }
          
        } catch (e) {
          debugPrint('🔥 ERROR PROCESANDO CON FIREBASE: $e');
          // Si falló Firebase pero era aplazar, aseguramos el aplazamiento local
          if (actionId == 'APLAZAR_ACTION') {
            final preferenceService = PreferenceService();
            final snoozeMinutes = await preferenceService.getSnoozeDuration();
            await snoozeNotification(
              notificationId,
              payload,
              doseTime,
              snoozeMinutes,
            );
          }
        }
      } else {
        debugPrint('🔥 FIREBASE NO DISPONIBLE - USANDO FALLBACK');
        if (actionId == 'APLAZAR_ACTION') {
          final preferenceService = PreferenceService();
          final snoozeMinutes = await preferenceService.getSnoozeDuration();
          await snoozeNotification(
            notificationId,
            payload,
            doseTime,
            snoozeMinutes,
          );
        } else {
          // Mostrar notificación de confirmación sin Firebase
          await showSimpleNotification(
            id: (notificationId ?? 0) + 1000,
            title: 'Acción registrada',
            body: actionId == 'TOMAR_ACTION'
                ? 'Dosis registrada como tomada. Se sincronizará al tener conexión.'
                : 'Dosis registrada como omitida. Se sincronizará al tener conexión.',
          );
        }
      }
      
      debugPrint('🔥 PROCESAMIENTO ASYNC COMPLETADO');
    } catch (e) {
      debugPrint('🔥 ERROR EN PROCESAMIENTO ASYNC: $e');
    }
  }

  /// Verifica si la aplicación fue iniciada por el usuario al tocar una notificación.
  static Future<void> checkAppLaunchedFromNotification() async {
    try {
      final NotificationAppLaunchDetails? launchDetails = 
          await _notificationsPlugin.getNotificationAppLaunchDetails();
      
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        debugPrint('🚀 APP ABIERTA POR NOTIFICACIÓN');
        debugPrint('🚀 Payload: ${launchDetails.notificationResponse?.payload}');
        debugPrint('🚀 Acción: ${launchDetails.notificationResponse?.actionId}');
        
        // Si hay una respuesta de notificación, procesarla
        if (launchDetails.notificationResponse != null) {
          debugPrint('🚀 PROCESANDO ACCIÓN DE LANZAMIENTO');
          await handleNotificationActionBackground(launchDetails.notificationResponse!);
        }
      } else {
        debugPrint('🚀 App NO abierta por notificación');
      }
    } catch (e) {
      debugPrint('ERROR verificando lanzamiento por notificación: $e');
    }
  }

  static void _navigateToAlarmScreen(String payload, {int? notificationId}) {
    try {
      final parts = payload.split('|');
      if (parts.length >= 4) {
        final userId = parts[1];
        final docId = parts[2];
        final doseTime = DateTime.tryParse(parts[3]) ?? DateTime.now();
        final nombreMedicamento = parts.length >= 5 && parts[4].isNotEmpty ? parts[4] : 'Medicamento';
        final dosisPorToma = parts.length >= 6 ? int.tryParse(parts[5]) ?? 1 : 1;
        final presentacion = parts.length >= 7 && parts[6].isNotEmpty ? parts[6] : 'dosis';
        final pacienteNombre = parts.length >= 8 && parts[7].isNotEmpty ? parts[7] : null;
        final habitacion = parts.length >= 9 && parts[8].isNotEmpty ? parts[8] : null;

        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => AlarmRingingPage(
              userId: userId,
              docId: docId,
              doseTime: doseTime,
              nombreMedicamento: nombreMedicamento,
              dosisPorToma: dosisPorToma,
              presentacion: presentacion,
              pacienteNombre: pacienteNombre,
              habitacion: habitacion,
              notificationId: notificationId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error en Deep Linking de alarma: $e');
    }
  }

  static void _navigateToDetail(String userId, String docId, String? dateTimeStr) async {
    try {
      final doc = await FirestoreService().getMedicamentoDocRef(userId, docId).get();
      if (doc.exists) {
        final tratamiento = Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
        final date = dateTimeStr != null ? DateTime.tryParse(dateTimeStr) ?? DateTime.now() : DateTime.now();
        
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => DetalleRecetaPage(
              tratamiento: tratamiento,
              horaDosis: date,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error en Deep Linking de notificación: $e');
    }
  }
}
