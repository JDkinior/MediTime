// lib/services/notification_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:meditime/models/tratamiento.dart';
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

@pragma('vm:entry-point')
Future<void> _handleNotificationAction(NotificationResponse notificationResponse) async {
  // Aseguramos que Firebase esté inicializado para operaciones en segundo plano.
  await WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final firestoreService = FirestoreService();
  final preferenceService = PreferenceService();

  debugPrint('Acción de notificación recibida. Acción: ${notificationResponse.actionId}');
  final payload = notificationResponse.payload;

  if (payload == null || !payload.startsWith('active_notification')) return;

  final parts = payload.split('|');
  final userId = parts[1];
  final docId = parts[2];
  final doseTime = DateTime.parse(parts[3]);

  DoseStatus newStatus;

  switch (notificationResponse.actionId) {
    case 'TOMAR_ACTION':
      newStatus = DoseStatus.tomada;
      break;
    case 'OMITIR_ACTION':
      newStatus = DoseStatus.omitida;
      break;
    case 'APLAZAR_ACTION':
      await firestoreService.updateDoseStatus(userId, docId, doseTime, DoseStatus.aplazada);
      // --- INICIO DE LA MODIFICACIÓN ---
      // Leemos la duración guardada y la pasamos a la función de aplazar
      final int snoozeMinutes = await preferenceService.getSnoozeDuration();
      await NotificationService.snoozeNotification(
          notificationResponse.id, payload, doseTime, snoozeMinutes);
      // --- FIN DE LA MODIFICACIÓN ---
      return;
    default:
      return;
  }

  // Actualizamos el estado en Firestore.
  await firestoreService.updateDoseStatus(userId, docId, doseTime, newStatus);
  await NotificationService.cancelFlutterLocalNotificationById(notificationResponse.id!);

  // Reprogramamos la siguiente alarma de la serie.
  final doc = await firestoreService.getMedicamentoDocRef(userId, docId).get();
  if (doc.exists) {
    final tratamiento = Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
    await NotificationService.rescheduleNextPendingDose(tratamiento, userId);
  }
}

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
      // Se ejecuta cuando la app está en primer plano.
      onDidReceiveNotificationResponse: _handleNotificationAction,
      // Se ejecuta cuando la app está en segundo plano o terminada.
      onDidReceiveBackgroundNotificationResponse: _handleNotificationAction,
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

  static Future<void> showActiveNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Leemos la preferencia para obtener la duración del aplazamiento
    final int snoozeMinutes = await PreferenceService().getSnoozeDuration();
    final String snoozeLabel = 'Aplazar $snoozeMinutes min';

    // Definimos las acciones con el texto dinámico
    final List<AndroidNotificationAction> actions = <AndroidNotificationAction>[
      AndroidNotificationAction('TOMAR_ACTION', 'Tomar', showsUserInterface: true),
      AndroidNotificationAction('OMITIR_ACTION', 'Omitir', showsUserInterface: true),
      // Usamos la etiqueta dinámica
      AndroidNotificationAction('APLAZAR_ACTION', snoozeLabel, showsUserInterface: true),
    ];

    // Detalles de la notificación para Android con acciones
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'meditime_active_dosis_channel', // Un ID de canal diferente para notificaciones activas
      'MediTime Dosis Activas',
      channelDescription: 'Canal para notificaciones de dosis que requieren acción del usuario.',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      actions: actions, // Añadimos las acciones aquí
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      autoCancel: false,
      ongoing: false, // Hacemos la notificación persistente hasta que el usuario actúe
      ticker: 'Acción requerida: Hora de tomar medicamento',
    );


    NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(id, title, body, notificationDetails, payload: payload);
    debugPrint("Notificación ACTIVA mostrada - ID: $id, Título: $title");
  }

  // NUEVO MÉTODO PÚBLICO para reprogramar, que puede ser llamado desde varios lugares
  static Future<void> rescheduleNextPendingDose(Tratamiento tratamiento, String userId) async {
    // Cancelamos cualquier alarma que pudiera estar programada para esta serie
    await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);

    // Buscamos la próxima dosis que esté pendiente
    final proximaDosis = await _findNextPendingDose(tratamiento: tratamiento);

    if (proximaDosis != null) {
      debugPrint("REPROGRAMANDO: Próxima dosis para '${tratamiento.nombreMedicamento}' será a las $proximaDosis");
      await _rescheduleAlarm(proximaDosis, tratamiento, userId);
    } else {
      debugPrint("REPROGRAMANDO: No hay más dosis pendientes para '${tratamiento.nombreMedicamento}'.");
    }
  }

  // NUEVO MÉTODO para aplazar una notificación
  static Future<void> snoozeNotification(int? notificationId, String payload, DateTime originalDoseTime, int snoozeMinutes) async {
    if (notificationId == null) return;
    
    await _notificationsPlugin.cancel(notificationId);

    // Usamos la duración recibida como parámetro
    final snoozeTime = tz.TZDateTime.now(tz.local).add(Duration(minutes: snoozeMinutes));

    await _notificationsPlugin.zonedSchedule(
        notificationId,
        'Recordatorio Aplazado',
        'Es hora de tomar tu dosis de las ${DateFormat('hh:mm a').format(originalDoseTime)}',
        snoozeTime,
        NotificationDetails(
            android: AndroidNotificationDetails(
                'meditime_snooze_channel', 'MediTime Dosis Aplazadas',
                channelDescription: 'Canal para recordatorios aplazados.',
                importance: Importance.max,
                priority: Priority.high,
                actions: [
                    AndroidNotificationAction('TOMAR_ACTION', 'Tomar', showsUserInterface: true),
                    AndroidNotificationAction('OMITIR_ACTION', 'Omitir', showsUserInterface: true),
                ]
            )
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
    );
    debugPrint("Notificación $notificationId aplazada por $snoozeMinutes minutos.");
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
  /// **NUEVO MÉTODO**
  /// Programa la cadena de alarmas para un tratamiento nuevo.
  static Future<void> scheduleNewTreatment({
    required String nombreMedicamento,
    required String presentacion,
    required int intervaloEnHoras,
    required DateTime primeraDosisDateTime,
    required DateTime fechaFinTratamiento,
    required int prescriptionAlarmManagerId,
    required String userId,
    required String docId, // El ID del documento recién creado    
  }) async {
    if (primeraDosisDateTime.isBefore(fechaFinTratamiento)) {
      debugPrint(
          "SCHEDULE: Programando primera alarma para $nombreMedicamento a las $primeraDosisDateTime con ID de Serie: $prescriptionAlarmManagerId");

      await AndroidAlarmManager.oneShotAt(
        primeraDosisDateTime,
        prescriptionAlarmManagerId,
        alarmCallbackLogic,
        exact: true,
        wakeup: true,
        alarmClock: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true,
        params: _buildAlarmParams(
          nombreMedicamento: nombreMedicamento,
          presentacion: presentacion,
          intervaloHoras: intervaloEnHoras,
          fechaFinTratamiento: fechaFinTratamiento,
          prescriptionAlarmId: prescriptionAlarmManagerId,
          userId: userId,
          docId: docId,
          doseTime: primeraDosisDateTime,

        ),
      );
    }
  }

  /// **NUEVO MÉTODO**
  /// Cancela una serie de alarmas completa. Útil al eliminar un tratamiento.
  static Future<void> cancelTreatmentAlarms(int prescriptionAlarmId) async {
    debugPrint(
        "CANCEL: Cancelando serie de alarmas completa con ID: $prescriptionAlarmId");
    await AndroidAlarmManager.cancel(prescriptionAlarmId);
  }

  /// **NUEVO MÉTODO**
  /// Omite una dosis y reprograma la siguiente.
  static Future<void> omitDoseAndReschedule({
    required Tratamiento tratamiento,
    required DocumentReference docRef,
    required String userId
  }) async {
    debugPrint("OMIT: Cancelando alarma existente con ID de Serie: ${tratamiento.prescriptionAlarmId}");
    await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);

    final DateTime? proximaDosisReal = await _findNextPendingDose(tratamiento: tratamiento);

    if (proximaDosisReal != null) {
      debugPrint("OMIT: Reprogramando la alarma para las $proximaDosisReal con ID de Serie: ${tratamiento.prescriptionAlarmId}");
      await _rescheduleAlarm(proximaDosisReal, tratamiento, userId);
    } else {
      debugPrint("OMIT: No hay más dosis futuras que programar.");
    }
  }

  /// **NUEVO MÉTODO**
  /// Anula la omisión de una dosis y reprograma la alarma correspondiente.
  static Future<void> undoOmissionAndReschedule({
    required Tratamiento tratamiento,
    required DocumentReference docRef,
    required String userId
  }) async {
    debugPrint("UNDO: Cancelando cualquier alarma existente con ID de Serie: ${tratamiento.prescriptionAlarmId} para reevaluar.");
    await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);

    final freshSnapshot = await docRef.get();
    // Creamos un nuevo objeto Tratamiento con los datos más recientes de Firestore
    final freshTratamiento = Tratamiento.fromFirestore(freshSnapshot as DocumentSnapshot<Map<String, dynamic>>);

    final DateTime? proximaDosisReal = await _findNextPendingDose(tratamiento: freshTratamiento);

    if (proximaDosisReal != null) {
      debugPrint("UNDO: La próxima alarma real es a las $proximaDosisReal. Reprogramando con ID de Serie: ${tratamiento.prescriptionAlarmId}");
      await _rescheduleAlarm(proximaDosisReal, freshTratamiento, userId);
    } else {
      debugPrint("UNDO: No hay más dosis futuras que programar.");
    }
  }

  /// Reactiva todas las alarmas para un usuario, por ejemplo, al iniciar sesión.
  static Future<void> reactivateAlarmsForUser(String userId) async {
    debugPrint("--- Iniciando reactivación de alarmas para el usuario $userId ---");
    final firestoreService = FirestoreService();
    try {
      final List<Tratamiento> todosLosTratamientos = await firestoreService.getMedicamentosStream(userId).first;
      for (var tratamiento in todosLosTratamientos) {
        if (tratamiento.prescriptionAlarmId == 0) continue;
        
        await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);

        // Encontrar la próxima dosis que esté realmente 'pendiente'
        final DateTime? proximaDosis = await _findNextPendingDose(tratamiento: tratamiento);

        if (proximaDosis != null) {
          debugPrint("Reactivando alarma para '${tratamiento.nombreMedicamento}'. Próxima dosis: $proximaDosis (ID: ${tratamiento.prescriptionAlarmId})");
          await _rescheduleAlarm(proximaDosis, tratamiento, userId);
        } else {
          debugPrint("No hay dosis pendientes que reactivar para '${tratamiento.nombreMedicamento}'.");
        }
      }
    } catch (e) {
      debugPrint("Error catastrófico durante la reactivación de alarmas: $e");
    }
    debugPrint("--- Reactivación de alarmas completada ---");
  }

  

  // --- MÉTODOS PRIVADOS AUXILIARES ---

  /// **NUEVO MÉTODO PRIVADO**
  /// Construye el mapa de parámetros para una alarma.
  static Map<String, dynamic> _buildAlarmParams({
    required String nombreMedicamento,
    required String presentacion,
    required int intervaloHoras,
    required DateTime fechaFinTratamiento,
    required int prescriptionAlarmId,
    // Nuevos parámetros requeridos
    required String userId,
    required String docId,
    required DateTime doseTime,
  }) {
    return {
      'currentNotificationId': Random().nextInt(100000),
      'nombreMedicamento': nombreMedicamento,
      'presentacion': presentacion,
      'intervaloHoras': intervaloHoras,
      'fechaFinTratamientoString': fechaFinTratamiento.toIso8601String(),
      'prescriptionAlarmId': prescriptionAlarmId,
      // Pasamos los nuevos datos
      'userId': userId,
      'docId': docId,
      'doseTime': doseTime.toIso8601String(),
    };
  }

    /// **NUEVO MÉTODO PRIVADO**
  /// Lógica centralizada para reprogramar una alarma.
  static Future<void> _rescheduleAlarm(DateTime scheduleTime, Tratamiento tratamiento, String userId) async {
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
        intervaloHoras: int.parse(tratamiento.intervaloDosis),
        fechaFinTratamiento: tratamiento.fechaFinTratamiento,
        prescriptionAlarmId: tratamiento.prescriptionAlarmId,
        // Pasamos los nuevos datos
        userId: userId,
        docId: tratamiento.id,
        doseTime: scheduleTime,
      ),
    );
  }

  // NUEVO MÉTODO PRIVADO para buscar la siguiente dosis PENDIENTE
  static Future<DateTime?> _findNextPendingDose({required Tratamiento tratamiento}) async {
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

  /// **NUEVO MÉTODO**
  /// Omite la próxima dosis futura de un tratamiento y reprograma la siguiente.
  /// Retorna `true` si se pudo omitir, `false` si no había dosis futuras para omitir.
  static Future<bool> skipNextDoseAndReschedule({
    required Tratamiento tratamiento,
    required DocumentReference docRef,
    required String userId, // Añadimos userId
  }) async {
    // 1. Buscamos la próxima dosis PENDIENTE
    final DateTime? proximaDosis = await _findNextPendingDose(tratamiento: tratamiento);

    if (proximaDosis == null) {
      debugPrint("SKIP: No se encontraron dosis futuras para omitir.");
      return false;
    }

    debugPrint("SKIP: Omitiendo la dosis de las $proximaDosis.");

    // 2. Actualizamos Firestore a OMITIDA
    await FirestoreService().updateDoseStatus(userId, tratamiento.id, proximaDosis, DoseStatus.omitida);

    // 3. Cancelamos la serie de alarmas actual
    await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);
    debugPrint("SKIP: Alarma existente con ID de Serie ${tratamiento.prescriptionAlarmId} cancelada.");

    // 4. Obtenemos los datos más recientes y creamos un nuevo objeto Tratamiento actualizado
    final freshSnapshot = await docRef.get();
    final freshTratamiento = Tratamiento.fromFirestore(freshSnapshot as DocumentSnapshot<Map<String, dynamic>>);

    // 5. Buscamos la siguiente dosis PENDIENTE después de la que acabamos de omitir
    final DateTime? siguienteDosisValida = await _findNextPendingDose(tratamiento: freshTratamiento);

    if (siguienteDosisValida != null) {
      // 6. Si existe una siguiente dosis, la reprogramamos
      debugPrint("SKIP: Reprogramando la alarma para las $siguienteDosisValida con ID de Serie: ${freshTratamiento.prescriptionAlarmId}");
      await _rescheduleAlarm(siguienteDosisValida, freshTratamiento, userId);
    } else {
      debugPrint("SKIP: No hay más dosis futuras que programar después de la omisión.");
    }

    return true;
  }
}