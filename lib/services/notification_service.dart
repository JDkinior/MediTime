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
import 'package:meditime/alarm_callback_handler.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/firebase_options.dart';

import 'package:meditime/core/navigator_key.dart';
import 'package:meditime/screens/medication/detalle_receta_page.dart';

@pragma('vm:entry-point')
Future<void> handleNotificationActionBackground(
  NotificationResponse notificationResponse,
) async {
  print('🔥🔥🔥 CALLBACK EJECUTÁNDOSE 🔥🔥🔥');
  print('🔥 ACCIÓN: ${notificationResponse.actionId ?? "NULL"}');
  print('🔥 ID: ${notificationResponse.id ?? "NULL"}');
  print('🔥 PAYLOAD: ${notificationResponse.payload ?? "NULL"}');
  
  try {
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();
    await NotificationService.initializeCore();
    final payload = notificationResponse.payload;
    final actionId = notificationResponse.actionId;
    
    if (payload == null) {
      print('🔥 PAYLOAD NULO - SALIENDO');
      return;
    }
    
    // Si el usuario toca el cuerpo de la notificación (no los botones de acción)
    if (actionId == null) {
      print('🔥 DEEP LINKING: El usuario pulsó la notificación.');
      final parts = payload.split('|');
      if (parts.length >= 3) {
        final userId = parts[1];
        final docId = parts[2];
        final dateTimeStr = parts.length >= 4 ? parts[3] : null;
        
        NotificationService._navigateToDetail(userId, docId, dateTimeStr);
      }
      return;
    }
    
    print('🔥 PROCESANDO ACCIÓN: $actionId');
    
    if (notificationResponse.id != null) {
      await NotificationService.cancelFlutterLocalNotificationById(notificationResponse.id!);
      print('🔥 NOTIFICACIÓN CANCELADA');
    }
    
    await NotificationService.processNotificationActionAsync(
      payload: payload,
      actionId: actionId,
      notificationId: notificationResponse.id,
    );
    
    print('🔥 CALLBACK COMPLETADO EXITOSAMENTE');
  } catch (e) {
    print('🔥 ERROR CRÍTICO EN CALLBACK: $e');
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
      visibility: NotificationVisibility.public,
      autoCancel: false,
      ongoing: false,
      ticker: 'Hora de tomar medicamento',
      // NUEVO: Configuraciones adicionales para fondo
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      usesChronometer: false,
      channelShowBadge: true,
      onlyAlertOnce: false,
      // CRÍTICO: Configurar como alarma del sistema
      timeoutAfter: null, // Sin timeout
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

      await androidImplementation.createNotificationChannel(simpleChannel);
      await androidImplementation.createNotificationChannel(activeChannel);
      await androidImplementation.createNotificationChannel(snoozeChannel);

      debugPrint(
        "Canales de notificación creados con configuraciones críticas",
      );
    }
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
    print('🔔 CREANDO NOTIFICACIÓN ACTIVA');
    print('🔔 ID: $id');
    print('🔔 PAYLOAD: $payload');
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
        cancelNotification: false, // NO cancelar automáticamente - lo hace el callback
      ),
      AndroidNotificationAction(
        'OMITIR_ACTION',
        'Omitir',
    showsUserInterface: false, // Procesar en segundo plano sin abrir la app
        cancelNotification: false, // NO cancelar automáticamente - lo hace el callback
      ),
      AndroidNotificationAction(
        'APLAZAR_ACTION',
        snoozeLabel,
    showsUserInterface: false, // Procesar en segundo plano sin abrir la app
        cancelNotification: false, // NO cancelar automáticamente - lo hace el callback
      ),
    ];

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
      visibility: NotificationVisibility.public,
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
    print('🔔 NOTIFICACIÓN ACTIVA CREADA EXITOSAMENTE');
    print('🔔 ACCIONES DISPONIBLES: TOMAR_ACTION, OMITIR_ACTION, APLAZAR_ACTION');
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
          actions: [
            AndroidNotificationAction(
              'TOMAR_ACTION',
              'Tomar',
              showsUserInterface: false,
            ),
            AndroidNotificationAction(
              'OMITIR_ACTION',
              'Omitir',
              showsUserInterface: false,
            ),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
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

  /// Reactiva todas las alarmas pendientes para un usuario.
  ///
  /// Este método es crucial y se llama al iniciar la aplicación (`AuthWrapper`)
  /// para asegurar que las alarmas persistan después de que el sistema operativo cierre la app.
  static Future<void> reactivateAlarmsForUser(String userId) async {
    debugPrint(
      "--- Iniciando reactivación de alarmas para el usuario $userId ---",
    );
    final firestoreService = FirestoreService();
    try {
      final List<Tratamiento> todosLosTratamientos =
          await firestoreService.getMedicamentosStream(userId).first;
      for (var tratamiento in todosLosTratamientos) {
        if (tratamiento.prescriptionAlarmId == 0) continue;

        await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);

        // Encontrar la próxima dosis que esté realmente 'pendiente'
        final DateTime? proximaDosis = await _findNextPendingDose(
          tratamiento: tratamiento,
        );

        if (proximaDosis != null) {
          debugPrint(
            "Reactivando alarma para '${tratamiento.nombreMedicamento}'. Próxima dosis: $proximaDosis (ID: ${tratamiento.prescriptionAlarmId})",
          );
          await _rescheduleAlarm(proximaDosis, tratamiento, userId);
        } else {
          debugPrint(
            "No hay dosis pendientes que reactivar para '${tratamiento.nombreMedicamento}'.",
          );
        }
      }
    } catch (e) {
      debugPrint("Error catastrófico durante la reactivación de alarmas: $e");
    }
    debugPrint("--- Reactivación de alarmas completada ---");
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

  /// Busca la próxima dosis futura que tenga el estado `DoseStatus.pendiente`.
  ///
  /// Itera sobre el mapa de estados de dosis del tratamiento en orden cronológico.
  static Future<DateTime?> _findNextPendingDose({
    required Tratamiento tratamiento,
  }) async {
    // Ordenamos las claves del mapa (que son fechas en string) para iterar en orden cronológico
    final sortedDoseKeys = tratamiento.doseStatus.keys.toList()..sort();

    for (final key in sortedDoseKeys) {
      final doseTime = DateTime.parse(key);
      final status = tratamiento.doseStatus[key];

      // Buscamos la primera dosis futura que esté pendiente
      if (doseTime.isAfter(DateTime.now()) && status == DoseStatus.pendiente) {
        return doseTime;
      }
    }
    return null; // No se encontraron dosis pendientes futuras
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
    print('🔍 VERIFICANDO CALLBACKS DE NOTIFICACIÓN');
    
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
    
    print('🔍 Notificación de prueba creada - ID: 88888');
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
    print('🔥 INICIANDO PROCESAMIENTO ASYNC');
    
    try {
  if (!payload.startsWith('active_notification')) {
        print('🔥 NO ES NOTIFICACIÓN ACTIVA - SALIENDO');
        return;
      }
      
      // Parsear payload
      final parts = payload.split('|');
      if (parts.length < 4) {
        print('🔥 PAYLOAD MALFORMADO - SALIENDO');
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
          print('🔥 GUARD ACTIVADO - Bloqueando acción. currentUserId=$currentUserId revoked=$revoked');
          if (notificationId != null) {
            await cancelFlutterLocalNotificationById(notificationId);
          }
          return;
        }
      } catch (e) {
        print('🔥 ERROR EN GUARD: $e');
      }

      print('🔥 PROCESANDO ACCIÓN: $actionId para usuario: $userId');
      
      // Inicializar Firebase de forma segura
      bool firebaseReady = false;
      try {
        WidgetsFlutterBinding.ensureInitialized();
        firebaseReady = await ensureFirebaseInitialized();
        print('🔥 FIREBASE LISTO: $firebaseReady');
      } catch (e) {
        print('🔥 ERROR INICIALIZANDO FIREBASE: $e');
      }
      
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
              print('🔥 ACCIÓN NO RECONOCIDA: $actionId');
              return;
          }
          
          await firestoreService.updateDoseStatus(userId, docId, doseTime, newStatus);
          print('🔥 ESTADO ACTUALIZADO EN FIRESTORE: ${newStatus.toString().split('.').last}');
          
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
              print('🔥 NOTIFICACIÓN APLAZADA POR $snoozeMinutes MINUTOS');
            } catch (e) {
              print('🔥 ERROR APLAZANDO: $e');
            }
          }
          
        } catch (e) {
          print('🔥 ERROR PROCESANDO CON FIREBASE: $e');
        }
      } else {
        print('🔥 FIREBASE NO DISPONIBLE - USANDO FALLBACK');
        // Mostrar notificación de confirmación sin Firebase
        await showSimpleNotification(
          id: (notificationId ?? 0) + 1000,
          title: 'Acción registrada',
          body: 'Se procesará cuando tengas conexión.',
        );
      }
      
      print('🔥 PROCESAMIENTO ASYNC COMPLETADO');
    } catch (e) {
      print('🔥 ERROR EN PROCESAMIENTO ASYNC: $e');
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
