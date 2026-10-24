// lib/services/notification_service.dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:meditime/alarm_callback_handler.dart' show alarmCallbackLogic;
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/tratamiento_service.dart';
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
        final profileId = parts.length >= 5 && parts[4].isNotEmpty ? parts[4] : null;
        
        NotificationService._navigateToDetail(userId, docId, dateTimeStr, profileId);
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

  /// Calcula un ID de notificación determinista basado en el documento y la dosis,
  /// permitiendo cancelar la notificación específica desde cualquier pantalla o widget.
  static int getNotificationIdForDose(String docId, [DateTime? doseTime]) {
    final baseHash = docId.hashCode.abs() % 400000;
    if (doseTime == null) return baseHash + 10000;
    final cleanMinute = DateTime(
      doseTime.year,
      doseTime.month,
      doseTime.day,
      doseTime.hour,
      doseTime.minute,
    );
    final timeHash = (cleanMinute.millisecondsSinceEpoch ~/ 60000).abs() % 400000;
    return ((baseHash ^ timeHash) % 800000) + 10000;
  }

  /// Calcula un ID de alarma dedicado para recordatorios aplazados (snooze)
  /// de modo que NUNCA sobrescriba ni cancele la alarma principal de la serie ([prescriptionAlarmId]).
  static int getSnoozeAlarmId(int prescriptionAlarmId) {
    return (prescriptionAlarmId.abs() % 89999999) + 100000000;
  }

  /// Calcula un ID de alarma de snooze determinista a partir del [docId].
  static int getSnoozeAlarmIdForDoc(String docId) {
    return (docId.hashCode.abs() % 89999999) + 200000000;
  }

  /// Cancela cualquier alarma o notificación de aplazamiento (snooze) activa para un tratamiento.
  static Future<void> cancelSnoozeForTreatment({
    int? prescriptionAlarmId,
    String? docId,
    DateTime? doseTime,
  }) async {
    try {
      if (prescriptionAlarmId != null && prescriptionAlarmId != 0) {
        await AndroidAlarmManager.cancel(getSnoozeAlarmId(prescriptionAlarmId));
      }
      if (docId != null && docId.isNotEmpty) {
        await AndroidAlarmManager.cancel(getSnoozeAlarmIdForDoc(docId));
        if (doseTime != null) {
          await _notificationsPlugin.cancel(getNotificationIdForDose(docId, doseTime));
          await _notificationsPlugin.cancel(doseTime.hashCode.abs());
        }
        await _notificationsPlugin.cancel(getNotificationIdForDose(docId));
      }
    } catch (e) {
      debugPrint("Aviso al cancelar snooze del tratamiento: $e");
    }
  }

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
      String? deviceTz;
      try {
        deviceTz = await const MethodChannel('com.meditime.app/alarm_sound')
            .invokeMethod<String>('getDeviceTimeZone');
      } catch (_) {}

      deviceTz ??= DateTime.now().timeZoneName;

      tz.Location? targetLoc;
      if (tz.timeZoneDatabase.locations.containsKey(deviceTz)) {
        targetLoc = tz.getLocation(deviceTz);
      } else {
        // Fallback: emparejar con una ubicación que coincida con el offset UTC local actual
        final currentOffset = DateTime.now().timeZoneOffset;
        for (final loc in tz.timeZoneDatabase.locations.values) {
          if (tz.TZDateTime.now(loc).timeZoneOffset == currentOffset) {
            targetLoc = loc;
            break;
          }
        }
      }

      tz.setLocalLocation(targetLoc ?? tz.getLocation('America/Bogota'));
      debugPrint("Zona horaria configurada con precisión: ${tz.local.name}");
    } catch (e) {
      debugPrint(
        "Error obteniendo/configurando zona horaria local: $e. Usando America/Bogota como default.",
      );
      try {
        tz.setLocalLocation(tz.getLocation('America/Bogota'));
      } catch (_) {}
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

  /// Cancela todas las notificaciones activas de los canales de alarma para asegurar
  /// que ningún tono continuo quede sonando en segundo plano en Android.
  static Future<void> cancelAllAlarmNotifications() async {
    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final active = await androidImplementation?.getActiveNotifications();
      if (active != null) {
        for (var n in active) {
          final chId = n.channelId ?? '';
          if ((chId.startsWith('meditime_alarm') ||
                  chId == 'meditime_active_dosis_channel' ||
                  chId == 'meditime_snooze_channel') &&
              n.id != null) {
            await _notificationsPlugin.cancel(n.id!);
            debugPrint("Notificación de dosis/alarma cancelada: ID ${n.id} (Canal: $chId)");
          }
        }
      }
    } catch (e) {
      debugPrint("Aviso cancelando notificaciones de alarma: $e");
    }
  }

  /// Detiene cualquier sonido y vibración continua de alarma reproduciéndose en el dispositivo
  static Future<void> stopAlarmSound() async {
    await AlarmSoundService.stopAlarm();
    await cancelAllAlarmNotifications();
  }

  /// Genera un identificador único de canal de notificación de alarma según el tono configurado.
  static String getAlarmChannelId({
    required String type,
    String? uri,
    String? resourceName,
  }) {
    if (type == 'custom' && resourceName != null && resourceName.isNotEmpty) {
      return 'meditime_alarm_custom_$resourceName';
    } else if (type == 'system_ringtone') {
      return 'meditime_alarm_sys_ringtone';
    } else if (type == 'phone_tone' && uri != null && uri.isNotEmpty) {
      final hash = uri.hashCode.abs();
      return 'meditime_alarm_phone_$hash';
    } else {
      return 'meditime_alarm_sys_default';
    }
  }

  /// Obtiene la instancia de AndroidNotificationSound correspondiente al tono configurado.
  static AndroidNotificationSound getAlarmSound({
    required String type,
    String? uri,
    String? resourceName,
  }) {
    if (type == 'custom' && resourceName != null && resourceName.isNotEmpty) {
      return RawResourceAndroidNotificationSound(resourceName);
    } else if (type == 'system_ringtone') {
      return const UriAndroidNotificationSound('content://settings/system/ringtone');
    } else if (uri != null && uri.isNotEmpty) {
      return UriAndroidNotificationSound(uri);
    } else {
      return const UriAndroidNotificationSound('content://settings/system/alarm_alert');
    }
  }

  /// Asegura que el canal de alarma para el tono especificado exista en el sistema Android.
  static Future<String> ensureAlarmChannel({
    required AndroidFlutterLocalNotificationsPlugin androidImplementation,
    required String type,
    String? uri,
    String? resourceName,
  }) async {
    final channelId = getAlarmChannelId(
      type: type,
      uri: uri,
      resourceName: resourceName,
    );
    final channelSound = getAlarmSound(
      type: type,
      uri: uri,
      resourceName: resourceName,
    );

    final AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
      channelId,
      'MediTime Alarma Despertador',
      description:
          'Canal de máxima prioridad para alarmas sonoras continuas de medicamentos.',
      importance: Importance.max,
      playSound: true,
      sound: channelSound,
      enableVibration: true,
      enableLights: true,
      ledColor: const Color.fromARGB(255, 255, 0, 0),
      showBadge: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    await androidImplementation.createNotificationChannel(alarmChannel);
    debugPrint("Canal de alarma asegurado en Android: $channelId");
    return channelId;
  }

  /// Actualiza o registra el canal de alarma cuando el usuario cambia el tono en ajustes.
  static Future<void> updateAlarmChannelSound({
    required String type,
    String? uri,
    String? resourceName,
  }) async {
    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImplementation != null) {
        await ensureAlarmChannel(
          androidImplementation: androidImplementation,
          type: type,
          uri: uri,
          resourceName: resourceName,
        );
      }
    } catch (e) {
      debugPrint("Error actualizando canal de alarma: $e");
    }
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
      const AndroidNotificationChannel activeChannel =
          AndroidNotificationChannel(
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

      await androidImplementation.createNotificationChannel(simpleChannel);
      await androidImplementation.createNotificationChannel(activeChannel);
      await androidImplementation.createNotificationChannel(snoozeChannel);

      // Limpiar canales obsoletos que causaban bucle de notificación
      try {
        await androidImplementation.deleteNotificationChannel('meditime_alarm_channel');
        await androidImplementation.deleteNotificationChannel('meditime_alarm_channel_v2');
      } catch (_) {}

      // Crear canal de alarma con el tono configurado por el usuario
      try {
        final prefService = PreferenceService();
        final soundType = await prefService.getAlarmSoundType();
        final soundUri = await prefService.getAlarmSoundUri();
        final soundResource = await prefService.getAlarmSoundResource();

        await ensureAlarmChannel(
          androidImplementation: androidImplementation,
          type: soundType,
          uri: soundUri,
          resourceName: soundResource,
        );
      } catch (e) {
        debugPrint("Error inicializando canal de alarma con tono: $e");
      }

      debugPrint(
        "Canales de notificación creados con configuraciones críticas y tono de alarma optimizado",
      );
    }
  }

  /// Muestra una notificación con intención de pantalla completa en Modo Alarma.
  ///
  /// Incluye botones Tomar/Omitir/Aplazar y reproduce el tono de alarma configurado en bucle.
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
        snoozeLabel,
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ];

    bool hideOnLockScreen = false;
    String soundType = 'system_alarm';
    String? soundUri;
    String? soundResource;

    try {
      final pref = PreferenceService();
      hideOnLockScreen = await pref.getHideMedicineNameOnLockScreen();
      soundType = await pref.getAlarmSoundType();
      soundUri = await pref.getAlarmSoundUri();
      soundResource = await pref.getAlarmSoundResource();
    } catch (_) {}

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    String channelId = 'meditime_alarm_sys_default';
    AndroidNotificationSound channelSound =
        const UriAndroidNotificationSound('content://settings/system/alarm_alert');

    if (androidImplementation != null) {
      channelId = await ensureAlarmChannel(
        androidImplementation: androidImplementation,
        type: soundType,
        uri: soundUri,
        resourceName: soundResource,
      );
      channelSound = getAlarmSound(
        type: soundType,
        uri: soundUri,
        resourceName: soundResource,
      );
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      'MediTime Alarma Despertador',
      channelDescription:
          'Canal de máxima prioridad para alarmas sonoras continuas de medicamentos.',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: true,
      sound: channelSound,
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
      timeoutAfter: 300000, // 5 minutos: auto-cancelar notificación si no hay interacción
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        htmlFormatBigText: true,
        htmlFormatContentTitle: true,
        summaryText: 'MediTime Alarma',
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

    debugPrint("Notificación MODO ALARMA mostrada en canal $channelId - ID: $id, Título: $title");
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
    int snoozeMinutes = 15;
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
        snoozeLabel,
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ];

    bool hideOnLockScreen = false;
    try {
      hideOnLockScreen = await PreferenceService().getHideMedicineNameOnLockScreen();
    } catch (_) {}

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
      ongoing: true,
      ticker: 'Acción requerida: Hora de tomar medicamento',
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
    debugPrint("Notificación ACTIVA mostrada - ID: $id, Título: $title");
  }

  /// Reprograma la siguiente dosis pendiente de un tratamiento.
  ///
  /// Cancela cualquier alarma anterior para esta serie y busca la próxima
  /// dosis con estado 'pendiente' o 'aplazada' manteniendo las dosis siguientes
  /// estrictamente ancladas a la rejilla canónica.
  static Future<void> rescheduleNextPendingDose(
    Tratamiento tratamiento,
    String userId, [
    CaregiverProfile? profile,
    DateTime? referenceTime,
  ]) async {
    await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);

    final target = await _findNextScheduledTarget(
      tratamiento: tratamiento,
      userId: userId,
      referenceTime: referenceTime,
    );

    if (target != null) {
      debugPrint(
        "REPROGRAMANDO: Próxima dosis para '${tratamiento.nombreMedicamento}' será a las ${target.fireTime} (canónica: ${target.canonicalDoseTime})",
      );
      await _rescheduleAlarm(
        target.fireTime,
        tratamiento,
        userId,
        profile,
        target.canonicalDoseTime,
      );
    } else {
      debugPrint(
        "REPROGRAMANDO: No hay más dosis pendientes para '${tratamiento.nombreMedicamento}'.",
      );
      if (tratamiento.isFinalizado) {
        await PreferenceService().removeTreatmentScheduleCache(userId, tratamiento.id);
      }
    }
  }

  /// Aplaza una notificación por un número determinado de minutos.
  ///
  /// Utiliza un ID de alarma dedicado (`getSnoozeAlarmIdForDoc`) con `AndroidAlarmManager`
  /// (y `zonedSchedule` como respaldo), de manera que NUNCA modifica ni desplaza
  /// la alarma principal de la serie del tratamiento.
  static Future<void> snoozeNotification(
    int? notificationId,
    String payload,
    DateTime originalDoseTime,
    int snoozeMinutes,
  ) async {
    final effectiveId = notificationId ?? originalDoseTime.hashCode.abs();

    await _notificationsPlugin.cancel(effectiveId);
    await stopAlarmSound();

    final int safeMinutes = snoozeMinutes > 0 ? snoozeMinutes : 10;
    final DateTime snoozeDateTime = DateTime.now().add(Duration(minutes: safeMinutes));
    final snoozeTzTime = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(minutes: safeMinutes));

    // Intentar programar primero mediante AndroidAlarmManager con ID dedicado de snooze
    // para garantizar despertar del dispositivo en Doze Mode sin alterar la serie principal.
    bool scheduledViaAlarmManager = false;
    final parts = payload.split('|');
    if (parts.length >= 4) {
      final userId = parts[1];
      final docId = parts[2];
      try {
        final prefs = PreferenceService();
        final cachedParams = await prefs.getTreatmentScheduleCache(userId, docId);
        final String nombreMed = parts.length >= 5 && parts[4].isNotEmpty
            ? parts[4]
            : (cachedParams?['nombreMedicamento'] as String? ?? 'Medicamento');
        final int dosisPorToma = parts.length >= 6
            ? (int.tryParse(parts[5]) ?? 1)
            : (cachedParams?['dosisPorToma'] as int? ?? 1);
        final String presentacion = parts.length >= 7 && parts[6].isNotEmpty
            ? parts[6]
            : (cachedParams?['presentacion'] as String? ?? 'dosis');
        final String? pacienteNombre = parts.length >= 8 && parts[7].isNotEmpty
            ? parts[7]
            : (cachedParams?['pacienteNombre'] as String?);
        final String? habitacion = parts.length >= 9 && parts[8].isNotEmpty
            ? parts[8]
            : (cachedParams?['habitacion'] as String?);
        final String? profileId = payload.startsWith('alarm_mode')
            ? (parts.length >= 11 && parts[10].isNotEmpty ? parts[10] : null)
            : (parts.length >= 5 && parts[4].isNotEmpty ? parts[4] : null);

        final snoozeParams = <String, dynamic>{
          if (cachedParams != null) ...cachedParams,
          'currentNotificationId': effectiveId,
          'userId': userId,
          'docId': docId,
          'doseTime': originalDoseTime.toIso8601String(),
          'canonicalDoseTime': (cachedParams?['canonicalDoseTime'] as String?) ??
              originalDoseTime.toIso8601String(),
          'nombreMedicamento': nombreMed,
          'presentacion': presentacion,
          'dosisPorToma': dosisPorToma,
          'pacienteNombre': pacienteNombre,
          'habitacion': habitacion,
          'profileId': profileId ?? cachedParams?['profileId'],
          'isSnooze': true,
        };

        scheduledViaAlarmManager = await AndroidAlarmManager.oneShotAt(
          snoozeDateTime,
          getSnoozeAlarmIdForDoc(docId),
          alarmCallbackLogic,
          exact: true,
          wakeup: true,
          alarmClock: true,
          rescheduleOnReboot: true,
          allowWhileIdle: true,
          params: snoozeParams,
        );
      } catch (e) {
        debugPrint("Aviso programando snooze vía AndroidAlarmManager: $e");
      }
    }

    if (scheduledViaAlarmManager) {
      debugPrint(
        "Snooze programado con exactitud vía AndroidAlarmManager para $snoozeDateTime (dosis original: $originalDoseTime).",
      );
      return;
    }

    // Fallback a zonedSchedule (por ejemplo en iOS o entorno de prueba sin AlarmManager)
    final bool isAlarmMode = payload.startsWith('alarm_mode');
    bool hideOnLockScreen = false;
    String soundType = 'system_alarm';
    String? soundUri;
    String? soundResource;

    try {
      final pref = PreferenceService();
      hideOnLockScreen = await pref.getHideMedicineNameOnLockScreen();
      soundType = await pref.getAlarmSoundType();
      soundUri = await pref.getAlarmSoundUri();
      soundResource = await pref.getAlarmSoundResource();
    } catch (_) {}

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    String channelId = 'meditime_snooze_channel';
    AndroidNotificationSound? channelSound;

    if (isAlarmMode && androidImplementation != null) {
      channelId = await ensureAlarmChannel(
        androidImplementation: androidImplementation,
        type: soundType,
        uri: soundUri,
        resourceName: soundResource,
      );
      channelSound = getAlarmSound(
        type: soundType,
        uri: soundUri,
        resourceName: soundResource,
      );
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      isAlarmMode ? 'MediTime Alarma Despertador' : 'MediTime Dosis Aplazadas',
      channelDescription: isAlarmMode
          ? 'Canal de máxima prioridad para alarmas sonoras continuas de medicamentos.'
          : 'Canal para recordatorios aplazados.',
      importance: Importance.max,
      priority: isAlarmMode ? Priority.max : Priority.high,
      playSound: true,
      sound: channelSound,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: isAlarmMode ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
      visibility: hideOnLockScreen ? NotificationVisibility.private : NotificationVisibility.public,
      autoCancel: false,
      ongoing: isAlarmMode,
      timeoutAfter: isAlarmMode ? 300000 : null,
      additionalFlags: isAlarmMode ? Int32List.fromList([4]) : null,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        'Es hora de tomar tu dosis de las ${DateFormat('hh:mm a').format(originalDoseTime)}',
        contentTitle: isAlarmMode ? '¡ALARMA APLAZADA!' : 'Recordatorio Aplazado',
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
          'Aplazar $safeMinutes min',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    await _notificationsPlugin.zonedSchedule(
      effectiveId,
      isAlarmMode ? '¡ALARMA APLAZADA!' : 'Recordatorio Aplazado',
      'Es hora de tomar tu dosis de las ${DateFormat('hh:mm a').format(originalDoseTime)}',
      snoozeTzTime,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
    debugPrint(
      "Notificación $effectiveId aplazada por $safeMinutes minutos (Modo: ${isAlarmMode ? 'Alarma' : 'Activo'}).",
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

  /// Programa la primera alarma para un tratamiento recién creado o actualizado.
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
    DateTime? canonicalDoseTime,
    DateTime? fechaInicioTratamiento,
    TimeOfDay? horaPrimeraDosis,
    int? dosisPorToma,
  }) async {
    final effectiveCanonical = canonicalDoseTime ??
        DateTime(
          primeraDosisDateTime.year,
          primeraDosisDateTime.month,
          primeraDosisDateTime.day,
          horaPrimeraDosis?.hour ?? primeraDosisDateTime.hour,
          horaPrimeraDosis?.minute ?? primeraDosisDateTime.minute,
        );

    if (!effectiveCanonical.isAfter(fechaFinTratamiento)) {
      final pref = PreferenceService();
      if (profile != null) {
        if (profile.isAnimal) {
          final isAnimalActive = await pref.getAnimalModeActive();
          final notifyPatientDoses = await pref.getCaregiverNotifyPatientDoses();
          if (!isAnimalActive || !notifyPatientDoses) {
            debugPrint("SCHEDULE OMITIDO: Alarma de mascota '$nombreMedicamento' no programada porque Modo Animales está desactivado.");
            return;
          }
          await pref.addAnimalAlarmId(prescriptionAlarmManagerId);
        } else {
          final isCaregiverActive = await pref.getCaregiverModeActive();
          final notifyPatientDoses = await pref.getCaregiverNotifyPatientDoses();
          if (!isCaregiverActive || !notifyPatientDoses) {
            debugPrint("SCHEDULE OMITIDO: Alarma de paciente '$nombreMedicamento' no programada porque Modo Cuidador está desactivado.");
            return;
          }
          await pref.addCaregiverAlarmId(prescriptionAlarmManagerId);
        }
      }

      debugPrint(
        "SCHEDULE: Programando primera alarma para $nombreMedicamento a las $primeraDosisDateTime (canónica: $effectiveCanonical) con ID de Serie: $prescriptionAlarmManagerId",
      );

      final Map<String, dynamic> completeParams = _buildAlarmParams(
        nombreMedicamento: nombreMedicamento,
        presentacion: presentacion,
        intervaloHoras: intervaloEnHoras,
        fechaFinTratamiento: fechaFinTratamiento,
        fechaInicioTratamiento: fechaInicioTratamiento ?? effectiveCanonical,
        horaPrimeraDosis: horaPrimeraDosis ??
            TimeOfDay(hour: effectiveCanonical.hour, minute: effectiveCanonical.minute),
        prescriptionAlarmId: prescriptionAlarmManagerId,
        userId: userId,
        docId: docId,
        doseTime: effectiveCanonical,
        canonicalDoseTime: effectiveCanonical,
        profileId: profile?.id,
        pacienteNombre: profile?.name,
        habitacion: profile?.roomNumber,
        categoria: profile?.category,
        dosisPorToma: dosisPorToma ?? 1,
        isExternalUser: profile?.isExternalUser,
        linkedUid: profile?.linkedUid,
        isAnimal: profile?.isAnimal ?? false,
      );

      await pref.saveTreatmentScheduleCache(completeParams);

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

  /// Cancela una serie de alarmas completa y cualquier snooze asociado. Útil al eliminar un tratamiento.
  static Future<void> cancelTreatmentAlarms(
    int prescriptionAlarmId, {
    String? docId,
  }) async {
    debugPrint(
      "CANCEL: Cancelando serie de alarmas completa con ID: $prescriptionAlarmId",
    );
    await AndroidAlarmManager.cancel(prescriptionAlarmId);
    await cancelSnoozeForTreatment(
      prescriptionAlarmId: prescriptionAlarmId,
      docId: docId,
    );
  }

  /// Desactiva y cancela todas las alarmas de tratamientos de pacientes de Modo Cuidador.
  static Future<void> deactivateCaregiverAlarms({
    required String userId,
    List<CaregiverProfile>? profiles,
    FirestoreService? firestoreService,
  }) async {
    debugPrint("🛑 Desactivando alarmas de Modo Cuidador para usuario: $userId");
    final fs = firestoreService ?? FirestoreService();
    final prefs = PreferenceService();

    try {
      final targetProfiles = profiles ?? await fs.getCaregiverProfiles(userId);
      for (final profile in targetProfiles.where((p) => !p.isAnimal)) {
        try {
          final treatments = await fs.getMedicamentos(userId, profile);
          for (final t in treatments) {
            if (t.prescriptionAlarmId != 0) {
              await cancelTreatmentAlarms(t.prescriptionAlarmId, docId: t.id);
              await prefs.removeCaregiverAlarmId(t.prescriptionAlarmId);
            }
          }
        } catch (e) {
          debugPrint("Error cancelando alarmas de perfil ${profile.id}: $e");
        }
      }
    } catch (e) {
      debugPrint("Error obteniendo perfiles de cuidador para desactivar alarmas: $e");
    }

    try {
      final cachedAlarmIds = await prefs.getCaregiverAlarmIds();
      for (final alarmId in cachedAlarmIds) {
        await cancelTreatmentAlarms(alarmId);
      }
      await prefs.clearCaregiverAlarmIds();
    } catch (e) {
      debugPrint("Error cancelando alarmas cacheadas de cuidador: $e");
    }

    await cancelAllAlarmNotifications();
    await stopAlarmSound();
    debugPrint("✅ Alarmas de Modo Cuidador desactivadas.");
  }

  /// Activa y reprograma las próximas dosis de todos los tratamientos de Modo Cuidador.
  static Future<void> activateCaregiverAlarms({
    required String userId,
    List<CaregiverProfile>? profiles,
    FirestoreService? firestoreService,
  }) async {
    debugPrint("🚀 Activando alarmas de Modo Cuidador para usuario: $userId");
    final fs = firestoreService ?? FirestoreService();
    final prefs = PreferenceService();

    try {
      final targetProfiles = profiles ?? await fs.getCaregiverProfiles(userId);
      final now = DateTime.now();
      final List<int> scheduledIds = [];

      for (final profile in targetProfiles.where((p) => !p.isAnimal)) {
        try {
          final treatments = await fs.getMedicamentos(userId, profile);
          for (final t in treatments) {
            if (t.fechaFinTratamiento.isAfter(now)) {
              await rescheduleNextPendingDose(t, userId, profile);
              if (t.prescriptionAlarmId != 0) {
                scheduledIds.add(t.prescriptionAlarmId);
              }
            }
          }
        } catch (e) {
          debugPrint("Error reprogramando alarmas de perfil ${profile.id}: $e");
        }
      }

      if (scheduledIds.isNotEmpty) {
        await prefs.saveCaregiverAlarmIds(scheduledIds);
      }
      debugPrint("✅ Alarmas de Modo Cuidador activadas (${scheduledIds.length} series).");
    } catch (e) {
      debugPrint("Error activando alarmas de cuidador: $e");
    }
  }

  /// Desactiva y cancela todas las alarmas de tratamientos de animales/mascotas de Modo Animales.
  static Future<void> deactivateAnimalAlarms({
    required String userId,
    List<CaregiverProfile>? profiles,
    FirestoreService? firestoreService,
  }) async {
    debugPrint("🛑 Desactivando alarmas de Modo Animales para usuario: $userId");
    final fs = firestoreService ?? FirestoreService();
    final prefs = PreferenceService();

    try {
      final targetProfiles = profiles ?? await fs.getCaregiverProfiles(userId);
      for (final profile in targetProfiles.where((p) => p.isAnimal)) {
        try {
          final treatments = await fs.getMedicamentos(userId, profile);
          for (final t in treatments) {
            if (t.prescriptionAlarmId != 0) {
              await cancelTreatmentAlarms(t.prescriptionAlarmId, docId: t.id);
              await prefs.removeAnimalAlarmId(t.prescriptionAlarmId);
            }
          }
        } catch (e) {
          debugPrint("Error cancelando alarmas de animal ${profile.id}: $e");
        }
      }
    } catch (e) {
      debugPrint("Error obteniendo perfiles de animales para desactivar alarmas: $e");
    }

    try {
      final cachedAlarmIds = await prefs.getAnimalAlarmIds();
      for (final alarmId in cachedAlarmIds) {
        await cancelTreatmentAlarms(alarmId);
      }
      await prefs.clearAnimalAlarmIds();
    } catch (e) {
      debugPrint("Error cancelando alarmas cacheadas de animales: $e");
    }

    await cancelAllAlarmNotifications();
    await stopAlarmSound();
    debugPrint("✅ Alarmas de Modo Animales desactivadas.");
  }

  /// Activa y reprograma las próximas dosis de todos los tratamientos de Modo Animales.
  static Future<void> activateAnimalAlarms({
    required String userId,
    List<CaregiverProfile>? profiles,
    FirestoreService? firestoreService,
  }) async {
    debugPrint("🚀 Activando alarmas de Modo Animales para usuario: $userId");
    final fs = firestoreService ?? FirestoreService();
    final prefs = PreferenceService();

    try {
      final targetProfiles = profiles ?? await fs.getCaregiverProfiles(userId);
      final now = DateTime.now();
      final List<int> scheduledIds = [];

      for (final profile in targetProfiles.where((p) => p.isAnimal)) {
        try {
          final treatments = await fs.getMedicamentos(userId, profile);
          for (final t in treatments) {
            if (t.fechaFinTratamiento.isAfter(now)) {
              await rescheduleNextPendingDose(t, userId, profile);
              if (t.prescriptionAlarmId != 0) {
                scheduledIds.add(t.prescriptionAlarmId);
              }
            }
          }
        } catch (e) {
          debugPrint("Error reprogramando alarmas de animal ${profile.id}: $e");
        }
      }

      if (scheduledIds.isNotEmpty) {
        await prefs.saveAnimalAlarmIds(scheduledIds);
      }
      debugPrint("✅ Alarmas de Modo Animales activadas (${scheduledIds.length} series).");
    } catch (e) {
      debugPrint("Error activando alarmas de animales: $e");
    }
  }

  /// Marca un tratamiento como revocado localmente (no se mostrarán notificaciones en callbacks offline)
  static Future<void> revokeTreatmentLocally(String userId, String docId) async {
    try {
      await PreferenceService().addRevokedTreatment(userId, docId);
      await cancelSnoozeForTreatment(docId: docId);
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
    await rescheduleNextPendingDose(tratamiento, userId);
  }

  /// Revierte la omisión de una dosis y reprograma la alarma correspondiente.
  static Future<void> undoOmissionAndReschedule({
    required Tratamiento tratamiento,
    required DocumentReference docRef,
    required String userId,
  }) async {
    await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);

    DocumentSnapshot freshSnapshot;
    try {
      freshSnapshot = await docRef.get().timeout(const Duration(seconds: 2));
    } catch (_) {
      freshSnapshot = await docRef.get(const GetOptions(source: Source.cache));
    }
    if (freshSnapshot.exists) {
      final freshTratamiento = Tratamiento.fromFirestore(
        freshSnapshot as DocumentSnapshot<Map<String, dynamic>>,
      );
      await rescheduleNextPendingDose(freshTratamiento, userId);
    }
  }

  /// Reactiva todas las alarmas pendientes para un usuario y sus perfiles de cuidador.
  ///
  /// Este método es crucial y se llama al iniciar la aplicación (`AuthWrapper`)
  /// para asegurar que las alarmas persistan después de que el sistema operativo cierre la app,
  /// el teléfono haya estado apagado o sin conexión a internet.
  static Future<void> reactivateAlarmsForUser(String userId) async {
    debugPrint(
      "--- Iniciando reactivación de alarmas para el usuario $userId ---",
    );
    final firestoreService = FirestoreService();
    final prefs = PreferenceService();

    try {
      // 0. Sincronizar primero cualquier acción tomada/omitida/aplazada offline
      try {
        await firestoreService.syncPendingOfflineActions(userId);
      } catch (e) {
        debugPrint("Aviso sincronizando acciones offline previas: $e");
      }

      int reactivatedCount = 0;

      // 1. Reactivar tratamientos personales del usuario (usando getMedicamentos con fallback a caché)
      try {
        final List<Tratamiento> todosLosTratamientos =
            await firestoreService.getMedicamentos(userId);

        for (var tratamiento in todosLosTratamientos) {
          await _reactivateSingleTreatment(tratamiento, userId, null);
          reactivatedCount++;
        }
      } catch (e) {
        debugPrint("Aviso al reactivar tratamientos personales: $e");
      }

      // 2. Reactivar tratamientos de perfiles asignados en Modo Cuidador / Animales
      try {
        final profiles = await firestoreService.getCaregiverProfiles(userId);

        for (var profile in profiles) {
          try {
            final profileTreatments =
                await firestoreService.getMedicamentos(userId, profile);

            for (var tratamiento in profileTreatments) {
              await _reactivateSingleTreatment(tratamiento, userId, profile);
              reactivatedCount++;
            }
          } catch (pe) {
            debugPrint("Aviso al reactivar tratamientos del perfil ${profile.name}: $pe");
          }
        }
      } catch (ce) {
        debugPrint("Aviso al cargar perfiles de cuidador para reactivación: $ce");
      }

      // 3. Respaldo 100% offline desde PreferenceService si la caché de Firestore estaba vacía
      if (reactivatedCount == 0) {
        final cachedSchedules =
            await prefs.getAllTreatmentScheduleCachesForUser(userId);
        for (final params in cachedSchedules) {
          final docId = params['docId'] as String?;
          final alarmId = params['prescriptionAlarmId'] as int?;
          final fechaFinStr = params['fechaFinTratamientoString'] as String?;
          final doseTimeStr = params['doseTime'] as String?;
          if (docId == null ||
              alarmId == null ||
              alarmId == 0 ||
              fechaFinStr == null ||
              doseTimeStr == null) {
            continue;
          }
          if (await prefs.isTreatmentRevoked(userId, docId)) continue;

          final fechaFin = DateTime.tryParse(fechaFinStr);
          final doseTime = DateTime.tryParse(doseTimeStr);
          if (fechaFin == null || doseTime == null) continue;

          final localRaw = await prefs.getLocalDoseStatuses(userId, docId);
          final localStatuses = localRaw.map(
            (k, v) => MapEntry(k, DoseStatus.fromString(v)),
          );

          final nextDose = TratamientoService.computeNextCanonicalDoseOffline(
            doseTime: doseTime,
            canonicalDoseTime: params['canonicalDoseTime'] != null
                ? DateTime.tryParse(params['canonicalDoseTime'] as String)
                : null,
            fechaInicioTratamiento: params['fechaInicioTratamientoString'] != null
                ? DateTime.tryParse(params['fechaInicioTratamientoString'] as String)
                : null,
            horaPrimeraDosisHour: params['horaPrimeraDosisHour'] as int?,
            horaPrimeraDosisMinute: params['horaPrimeraDosisMinute'] as int?,
            intervaloHoras: (params['intervaloHoras'] as int?) ?? 8,
            fechaFinTratamiento: fechaFin,
            referenceNow: DateTime.now(),
            localDoseStatuses: localStatuses,
          );

          if (nextDose != null) {
            await scheduleOfflineAlarm(
              scheduleTime: nextDose,
              alarmId: alarmId,
              params: {
                ...params,
                'doseTime': nextDose.toIso8601String(),
                'canonicalDoseTime': nextDose.toIso8601String(),
                'currentNotificationId': getNotificationIdForDose(docId, nextDose),
              },
            );
          }
        }
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

    final target = await _findNextScheduledTarget(
      tratamiento: tratamiento,
      userId: userId,
    );

    if (target != null) {
      debugPrint(
        "Reactivando alarma para '${tratamiento.nombreMedicamento}'. Próxima dosis: ${target.fireTime} (ID: ${tratamiento.prescriptionAlarmId})",
      );
      await _rescheduleAlarm(
        target.fireTime,
        tratamiento,
        userId,
        profile,
        target.canonicalDoseTime,
      );
    } else {
      debugPrint(
        "No hay dosis pendientes que reactivar para '${tratamiento.nombreMedicamento}'.",
      );
    }
  }

  /// Programa una alarma que puede funcionar sin conexión a internet.
  ///
  /// Esto es posible porque todos los datos necesarios para la siguiente alarma
  /// se pasan a través del mapa de `params` y se respaldan en [PreferenceService].
  static Future<void> scheduleOfflineAlarm({
    required DateTime scheduleTime,
    required int alarmId,
    required Map<String, dynamic> params,
  }) async {
    try {
      await PreferenceService().saveTreatmentScheduleCache(params);
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
    DateTime? canonicalDoseTime,
    DateTime? fechaInicioTratamiento,
    TimeOfDay? horaPrimeraDosis,
    String? profileId,
    String? pacienteNombre,
    String? habitacion,
    String? categoria,
    int? dosisPorToma,
    bool? isExternalUser,
    String? linkedUid,
    bool? isAnimal,
    bool? isSnooze,
  }) {
    final effectiveCanonical = canonicalDoseTime ?? doseTime;
    return {
      // IDs y configuración básica
      'currentNotificationId': getNotificationIdForDose(docId, effectiveCanonical),
      'prescriptionAlarmId': prescriptionAlarmId,
      'userId': userId,
      'docId': docId,
      'doseTime': doseTime.toIso8601String(),
      'canonicalDoseTime': effectiveCanonical.toIso8601String(),

      // Datos del medicamento y anclas de rejilla (CRÍTICO: para funcionamiento offline sin desfase)
      'nombreMedicamento': nombreMedicamento.replaceAll('|', '-'),
      'presentacion': presentacion.replaceAll('|', '-'),
      'intervaloHoras': intervaloHoras > 0 ? intervaloHoras : 8,
      'fechaInicioTratamientoString':
          (fechaInicioTratamiento ?? effectiveCanonical).toIso8601String(),
      'horaPrimeraDosisHour': horaPrimeraDosis?.hour ?? effectiveCanonical.hour,
      'horaPrimeraDosisMinute': horaPrimeraDosis?.minute ?? effectiveCanonical.minute,
      'fechaFinTratamientoString': fechaFinTratamiento.toIso8601String(),

      // Datos del paciente/cuidador
      'profileId': profileId,
      'pacienteNombre': pacienteNombre?.replaceAll('|', '-'),
      'habitacion': habitacion?.replaceAll('|', '-'),
      'categoria': categoria,
      'dosisPorToma': dosisPorToma ?? 1,
      'isExternalUser': isExternalUser,
      'linkedUid': linkedUid,
      'isAnimal': isAnimal ?? false,
      'isSnooze': isSnooze ?? false,

      // Metadatos adicionales
      'scheduledAt': DateTime.now().toIso8601String(),
      'version': '3.0',
    };
  }

  /// Lógica interna y centralizada para programar una alarma con `AndroidAlarmManager`.
  static Future<void> _rescheduleAlarm(
    DateTime scheduleTime,
    Tratamiento tratamiento,
    String userId, [
    CaregiverProfile? profile,
    DateTime? canonicalDoseTime,
  ]) async {
    final pref = PreferenceService();
    if (profile != null) {
      if (profile.isAnimal) {
        final isAnimalActive = await pref.getAnimalModeActive();
        final notifyPatientDoses = await pref.getCaregiverNotifyPatientDoses();
        if (!isAnimalActive || !notifyPatientDoses) {
          debugPrint("RESCHEDULE OMITIDO: Alarma de mascota '${tratamiento.nombreMedicamento}' cancelada porque Modo Animales está desactivado.");
          await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);
          await pref.removeAnimalAlarmId(tratamiento.prescriptionAlarmId);
          return;
        }
        await pref.addAnimalAlarmId(tratamiento.prescriptionAlarmId);
      } else {
        final isCaregiverActive = await pref.getCaregiverModeActive();
        final notifyPatientDoses = await pref.getCaregiverNotifyPatientDoses();
        if (!isCaregiverActive || !notifyPatientDoses) {
          debugPrint("RESCHEDULE OMITIDO: Alarma de paciente '${tratamiento.nombreMedicamento}' cancelada porque Modo Cuidador está desactivado.");
          await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);
          await pref.removeCaregiverAlarmId(tratamiento.prescriptionAlarmId);
          return;
        }
        await pref.addCaregiverAlarmId(tratamiento.prescriptionAlarmId);
      }
    }

    final int rawHours = tratamiento.intervaloDosis.inHours;
    final int safeHours = rawHours > 0 ? rawHours : 8;
    final DateTime effectiveCanonical = canonicalDoseTime ??
        TratamientoService.snapToCanonicalGrid(
          dateTime: scheduleTime,
          anchor: tratamiento.canonicalFirstDoseDateTime,
          intervaloHoras: safeHours,
        );

    final params = _buildAlarmParams(
      nombreMedicamento: tratamiento.nombreMedicamento,
      presentacion: tratamiento.presentacion,
      intervaloHoras: safeHours,
      fechaInicioTratamiento: tratamiento.canonicalFirstDoseDateTime,
      horaPrimeraDosis: tratamiento.horaPrimeraDosis,
      fechaFinTratamiento: tratamiento.fechaFinTratamiento,
      prescriptionAlarmId: tratamiento.prescriptionAlarmId,
      userId: userId,
      docId: tratamiento.id,
      doseTime: scheduleTime,
      canonicalDoseTime: effectiveCanonical,
      profileId: profile?.id ?? tratamiento.profileId,
      pacienteNombre: profile?.name,
      habitacion: profile?.roomNumber,
      categoria: profile?.category,
      dosisPorToma: tratamiento.dosisPorToma,
      isExternalUser: profile?.isExternalUser,
      linkedUid: profile?.linkedUid,
      isAnimal: profile?.isAnimal ?? false,
    );

    await pref.saveTreatmentScheduleCache(params);

    await AndroidAlarmManager.oneShotAt(
      scheduleTime,
      tratamiento.prescriptionAlarmId,
      alarmCallbackLogic,
      exact: true,
      wakeup: true,
      alarmClock: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
      params: params,
    );
    debugPrint("Alarma reprogramada para: $scheduleTime (canónica: $effectiveCanonical) (${profile?.name ?? 'Personal'})");
  }

  /// Busca el objetivo completo de la próxima dosis (hora de disparo y hora canónica),
  /// fusionando los datos de Firestore con cualquier estado local offline.
  static Future<ScheduledDoseTarget?> _findNextScheduledTarget({
    required Tratamiento tratamiento,
    String? userId,
    DateTime? referenceTime,
  }) async {
    Map<String, DoseStatus>? localDoseStatuses;
    if (userId != null && userId.isNotEmpty) {
      try {
        final rawLocal = await PreferenceService().getLocalDoseStatuses(
          userId,
          tratamiento.id,
        );
        if (rawLocal.isNotEmpty) {
          localDoseStatuses = rawLocal.map(
            (k, v) => MapEntry(k, DoseStatus.fromString(v)),
          );
        }
      } catch (_) {}
    }

    return TratamientoService.findNextScheduledDose(
      tratamiento: tratamiento,
      referenceTime: referenceTime,
      localDoseStatuses: localDoseStatuses,
    );
  }

  /// Busca la próxima dosis futura que deba programarse como alarma.
  static Future<DateTime?> _findNextPendingDose({
    required Tratamiento tratamiento,
    String? userId,
    DateTime? referenceTime,
  }) async {
    final target = await _findNextScheduledTarget(
      tratamiento: tratamiento,
      userId: userId,
      referenceTime: referenceTime,
    );
    return target?.fireTime;
  }

  /// Marca la próxima dosis futura como 'omitida' y reprograma la siguiente.
  /// Retorna `true` si se pudo omitir, `false` si no había dosis futuras para omitir.
  static Future<bool> skipNextDoseAndReschedule({
    required Tratamiento tratamiento,
    required DocumentReference docRef,
    required String userId,
  }) async {
    final DateTime? proximaDosis = await _findNextPendingDose(
      tratamiento: tratamiento,
      userId: userId,
    );

    if (proximaDosis == null) {
      debugPrint("SKIP: No se encontraron dosis futuras para omitir.");
      return false;
    }

    debugPrint("SKIP: Omitiendo la dosis de las $proximaDosis.");

    await FirestoreService().updateDoseStatus(
      userId,
      tratamiento.id,
      proximaDosis,
      DoseStatus.omitida,
    );

    await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);

    DocumentSnapshot freshSnapshot;
    try {
      freshSnapshot = await docRef.get().timeout(const Duration(seconds: 2));
    } catch (_) {
      freshSnapshot = await docRef.get(const GetOptions(source: Source.cache));
    }
    if (freshSnapshot.exists) {
      final freshTratamiento = Tratamiento.fromFirestore(
        freshSnapshot as DocumentSnapshot<Map<String, dynamic>>,
      );
      await rescheduleNextPendingDose(freshTratamiento, userId);
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
      if (notificationId != null) {
        await cancelFlutterLocalNotificationById(notificationId);
      }

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
    } catch (e) {
      debugPrint('ERROR en fallback: $e');
    }
  }

  /// Asegura que Firebase esté inicializado antes de intentar usarlo.
  static Future<bool> ensureFirebaseInitialized() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        return true;
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 3));

      return true;
    } catch (e) {
      debugPrint('ERROR inicializando Firebase: $e');
      return false;
    }
  }

  /// Muestra una notificación de prueba para fines de depuración.
  static Future<void> showTestNotification() async {
    await showActiveNotification(
      id: 99999,
      title: 'PRUEBA: Notificación de Prueba',
      body: 'Presiona un botón para probar el callback',
      payload: 'active_notification|test_user|test_doc|${DateTime.now().toIso8601String()}',
    );
  }

  /// Muestra una notificación de prueba para diagnosticar el funcionamiento de los callbacks.
  static Future<void> checkNotificationCallbacks() async {
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
  }

  /// Verifica si hay notificaciones activas al abrir la app.
  static Future<void> handlePendingNotificationActions() async {
    try {
      final List<ActiveNotification>? activeNotifications = 
          await _notificationsPlugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.getActiveNotifications();
      
      if (activeNotifications != null && activeNotifications.isNotEmpty) {
        debugPrint('📱 Encontradas ${activeNotifications.length} notificaciones activas');
      }
    } catch (e) {
      debugPrint('ERROR verificando notificaciones activas: $e');
    }
  }

  /// Procesa de forma asíncrona la acción realizada por el usuario en una notificación.
  /// Garantiza persistencia inmediata en disco y reprogramación exacta tanto online como 100% offline.
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
      
      final parts = payload.split('|');
      if (parts.length < 4) {
        debugPrint('🔥 PAYLOAD MALFORMADO - SALIENDO');
        return;
      }
      
      final userId = parts[1];
      final docId = parts[2];
      final doseTime = DateTime.parse(parts[3]);
      final String? profileId = payload.startsWith('alarm_mode')
          ? (parts.length >= 11 && parts[10].isNotEmpty ? parts[10] : null)
          : (parts.length >= 5 && parts[4].isNotEmpty ? parts[4] : null);
      
      final prefs = PreferenceService();

      // Guard: validar usuario actual y tratamiento no revocado
      try {
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

      // Siempre detener sonido de alarma inmediatamente
      await stopAlarmSound();

      // Si se tomó u omitió, cancelar cualquier snooze pendiente de este tratamiento
      if (actionId == 'TOMAR_ACTION' || actionId == 'OMITIR_ACTION') {
        await cancelSnoozeForTreatment(docId: docId, doseTime: doseTime);
      }

      // CRÍTICO: Persistir el estado localmente de inmediato (< 5ms, sin depender de internet ni Firebase)
      await prefs.saveLocalDoseStatus(
        userId: userId,
        docId: docId,
        doseTime: doseTime,
        status: newStatus.value,
        profileId: profileId,
        queueForSync: true,
      );

      // Si la acción es APLAZAR, programar el snooze local de inmediato
      if (actionId == 'APLAZAR_ACTION') {
        try {
          final snoozeMinutes = await prefs.getSnoozeDuration();
          await snoozeNotification(
            notificationId,
            payload,
            doseTime,
            snoozeMinutes,
          );
          debugPrint('🔥 NOTIFICACIÓN APLAZADA POR $snoozeMinutes MINUTOS');
        } catch (e) {
          debugPrint('🔥 ERROR APLAZANDO LOCALMENTE: $e');
        }
      }

      // Intentar sincronizar con Firebase y reprogramar siguiente dosis canónica
      bool firebaseReady = false;
      try {
        WidgetsFlutterBinding.ensureInitialized();
        firebaseReady = await ensureFirebaseInitialized();
      } catch (e) {
        debugPrint('🔥 ERROR INICIALIZANDO FIREBASE: $e');
      }

      bool rescheduledWithFirestore = false;
      if (firebaseReady) {
        try {
          final firestoreService = FirestoreService();
          final resolved = await firestoreService.resolveMedicamentoWithProfile(
            userId,
            docId,
            profileId: profileId,
          );
          final profile = resolved?.profile;

          await firestoreService.updateDoseStatus(userId, docId, doseTime, newStatus, profile);
          debugPrint('🔥 ESTADO ACTUALIZADO EN FIRESTORE: ${newStatus.value}');
          
          if (actionId == 'TOMAR_ACTION' || actionId == 'OMITIR_ACTION') {
            final docRef = resolved?.docRef ?? firestoreService.getMedicamentoDocRef(userId, docId, profile);
            DocumentSnapshot docSnap;
            try {
              docSnap = await docRef.get().timeout(const Duration(seconds: 2));
            } catch (_) {
              docSnap = await docRef.get(const GetOptions(source: Source.cache));
            }
            if (docSnap.exists) {
              final tratamiento = Tratamiento.fromFirestore(docSnap as DocumentSnapshot<Map<String, dynamic>>);
              await rescheduleNextPendingDose(tratamiento, userId, profile);
              rescheduledWithFirestore = true;
            }
          }
        } catch (e) {
          debugPrint('🔥 ERROR PROCESANDO CON FIREBASE: $e');
        }
      }

      // Fallback 100% offline para asegurar que la siguiente dosis canónica quede programada
      if ((actionId == 'TOMAR_ACTION' || actionId == 'OMITIR_ACTION') &&
          !rescheduledWithFirestore) {
        try {
          final cachedParams = await prefs.getTreatmentScheduleCache(userId, docId);
          if (cachedParams != null) {
            final alarmId = cachedParams['prescriptionAlarmId'] as int?;
            final fechaFinStr = cachedParams['fechaFinTratamientoString'] as String?;
            if (alarmId != null && alarmId != 0 && fechaFinStr != null) {
              final rawLocal = await prefs.getLocalDoseStatuses(userId, docId);
              final localStatuses = rawLocal.map(
                (k, v) => MapEntry(k, DoseStatus.fromString(v)),
              );
              final nextDose = TratamientoService.computeNextCanonicalDoseOffline(
                doseTime: doseTime,
                canonicalDoseTime: cachedParams['canonicalDoseTime'] != null
                    ? DateTime.tryParse(cachedParams['canonicalDoseTime'] as String)
                    : null,
                fechaInicioTratamiento: cachedParams['fechaInicioTratamientoString'] != null
                    ? DateTime.tryParse(cachedParams['fechaInicioTratamientoString'] as String)
                    : null,
                horaPrimeraDosisHour: cachedParams['horaPrimeraDosisHour'] as int?,
                horaPrimeraDosisMinute: cachedParams['horaPrimeraDosisMinute'] as int?,
                intervaloHoras: (cachedParams['intervaloHoras'] as int?) ?? 8,
                fechaFinTratamiento: DateTime.parse(fechaFinStr),
                referenceNow: DateTime.now(),
                localDoseStatuses: localStatuses,
              );
              if (nextDose != null) {
                await scheduleOfflineAlarm(
                  scheduleTime: nextDose,
                  alarmId: alarmId,
                  params: {
                    ...cachedParams,
                    'doseTime': nextDose.toIso8601String(),
                    'canonicalDoseTime': nextDose.toIso8601String(),
                    'currentNotificationId': getNotificationIdForDose(docId, nextDose),
                  },
                );
              }
            }
          }
        } catch (offlineErr) {
          debugPrint('🔥 ERROR EN REPROGRAMACIÓN OFFLINE POST-ACCIÓN: $offlineErr');
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
        if (launchDetails.notificationResponse != null) {
          await handleNotificationActionBackground(launchDetails.notificationResponse!);
        }
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

        final resolvedNotificationId = notificationId ??
            (parts.length >= 10 ? int.tryParse(parts[9]) : null);
        final profileId = parts.length >= 11 && parts[10].isNotEmpty ? parts[10] : null;

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
              notificationId: resolvedNotificationId,
              profileId: profileId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error en Deep Linking de alarma: $e');
    }
  }

  static void _navigateToDetail(String userId, String docId, String? dateTimeStr, [String? profileId]) async {
    try {
      final firestoreService = FirestoreService();
      final resolved = await firestoreService.resolveMedicamentoWithProfile(
        userId,
        docId,
        profileId: profileId,
      );
      final docRef = resolved?.docRef ?? firestoreService.getMedicamentoDocRef(userId, docId);
      DocumentSnapshot doc;
      try {
        doc = await docRef.get().timeout(const Duration(seconds: 2));
      } catch (_) {
        doc = await docRef.get(const GetOptions(source: Source.cache));
      }
      if (doc.exists) {
        final tratamiento = Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
        final date = dateTimeStr != null ? DateTime.tryParse(dateTimeStr) ?? DateTime.now() : DateTime.now();
        
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => DetalleRecetaPage(
              tratamiento: tratamiento,
              horaDosis: date,
              profile: resolved?.profile,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error en Deep Linking de notificación: $e');
    }
  }
}
