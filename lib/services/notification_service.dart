// lib/services/notification_service.dart
import 'dart:math';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:meditime/alarm_callback_handler.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/services/firestore_service.dart';
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
  /// **NUEVO MÉTODO**
  /// Programa la cadena de alarmas para un tratamiento nuevo.
  static Future<void> scheduleNewTreatment({
    required String nombreMedicamento,
    required String presentacion,
    required int intervaloEnHoras,
    required DateTime primeraDosisDateTime,
    required DateTime fechaFinTratamiento,
    required int prescriptionAlarmManagerId,
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
  }) async {
    debugPrint("OMIT: Cancelando alarma existente con ID de Serie: ${tratamiento.prescriptionAlarmId}");
    await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);

    final DateTime? proximaDosisReal = await _findNextUpcomingDose(tratamiento: tratamiento);

    if (proximaDosisReal != null) {
      debugPrint("OMIT: Reprogramando la alarma para las $proximaDosisReal con ID de Serie: ${tratamiento.prescriptionAlarmId}");
      await _rescheduleAlarm(proximaDosisReal, tratamiento);
    } else {
      debugPrint("OMIT: No hay más dosis futuras que programar.");
    }
  }

  /// **NUEVO MÉTODO**
  /// Anula la omisión de una dosis y reprograma la alarma correspondiente.
  static Future<void> undoOmissionAndReschedule({
    required Tratamiento tratamiento,
    required DocumentReference docRef,
  }) async {
    debugPrint("UNDO: Cancelando cualquier alarma existente con ID de Serie: ${tratamiento.prescriptionAlarmId} para reevaluar.");
    await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);

    final freshSnapshot = await docRef.get();
    // Creamos un nuevo objeto Tratamiento con los datos más recientes de Firestore
    final freshTratamiento = Tratamiento.fromFirestore(freshSnapshot as DocumentSnapshot<Map<String, dynamic>>);

    final DateTime? proximaDosisReal = await _findNextUpcomingDose(tratamiento: freshTratamiento);

    if (proximaDosisReal != null) {
      debugPrint("UNDO: La próxima alarma real es a las $proximaDosisReal. Reprogramando con ID de Serie: ${tratamiento.prescriptionAlarmId}");
      await _rescheduleAlarm(proximaDosisReal, freshTratamiento);
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
        if (tratamiento.prescriptionAlarmId == 0) {
          debugPrint("Saltando tratamiento '${tratamiento.nombreMedicamento}' por no tener alarmId.");
          continue;
        }

        await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);

        final DateTime? proximaDosis = await _findNextUpcomingDose(tratamiento: tratamiento);

        if (proximaDosis != null) {
          debugPrint("Reactivando alarma para '${tratamiento.nombreMedicamento}'. Próxima dosis: $proximaDosis (ID: ${tratamiento.prescriptionAlarmId})");
          await _rescheduleAlarm(proximaDosis, tratamiento);
        } else {
          debugPrint("No hay dosis futuras que reactivar para '${tratamiento.nombreMedicamento}'.");
        }
      }
    } catch (e) {
      debugPrint("Error catastrófico durante la reactivación de alarmas: $e");
    }
    debugPrint("--- Reactivación de alarmas completada ---");
  }

  // --- MÉTODOS PRIVADOS AUXILIARES ---

  /// **NUEVO MÉTODO PRIVADO**
  /// Lógica centralizada para reprogramar una alarma.
  static Future<void> _rescheduleAlarm(DateTime scheduleTime, Tratamiento tratamiento) async {
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
      ),
    );
  }
  /// **NUEVO MÉTODO PRIVADO**
  /// Construye el mapa de parámetros para una alarma.
  static Map<String, dynamic> _buildAlarmParams({
    required String nombreMedicamento,
    required String presentacion,
    required int intervaloHoras,
    required DateTime fechaFinTratamiento,
    required int prescriptionAlarmId,
  }) {
    return {
      'currentNotificationId': Random().nextInt(100000),
      'nombreMedicamento': nombreMedicamento,
      'presentacion': presentacion,
      'intervaloHoras': intervaloHoras,
      'fechaFinTratamientoString': fechaFinTratamiento.toIso8601String(),
      'prescriptionAlarmId': prescriptionAlarmId,
    };
  }

  /// **NUEVO MÉTODO**
  /// Omite la próxima dosis futura de un tratamiento y reprograma la siguiente.
  /// Retorna `true` si se pudo omitir, `false` si no había dosis futuras para omitir.
  static Future<bool> skipNextDoseAndReschedule({
    required Tratamiento tratamiento, // <-- AHORA RECIBE UN OBJETO TRATAMIENTO
    required DocumentReference docRef,
  }) async {
    // 1. Usamos el método privado para encontrar la próxima dosis válida
    final DateTime? proximaDosis =
        await _findNextUpcomingDose(tratamiento: tratamiento); // <-- SE LLAMA CORRECTAMENTE

    if (proximaDosis == null) {
      debugPrint("SKIP: No se encontraron dosis futuras para omitir.");
      return false;
    }

    debugPrint("SKIP: Omitiendo la dosis de las $proximaDosis.");

    // 2. Actualizamos Firestore
    await docRef.update({
      'skippedDoses': FieldValue.arrayUnion([Timestamp.fromDate(proximaDosis)])
    });

    // 3. Cancelamos la serie de alarmas actual
    await AndroidAlarmManager.cancel(tratamiento.prescriptionAlarmId);
    debugPrint("SKIP: Alarma existente con ID de Serie ${tratamiento.prescriptionAlarmId} cancelada.");

    // 4. Obtenemos los datos más recientes y creamos un nuevo objeto Tratamiento actualizado
    final freshSnapshot = await docRef.get();
    final freshTratamiento = Tratamiento.fromFirestore(freshSnapshot as DocumentSnapshot<Map<String, dynamic>>);

    // 5. Buscamos la siguiente dosis válida DESPUÉS de la que acabamos de omitir
    final DateTime? siguienteDosisValida =
        await _findNextUpcomingDose(tratamiento: freshTratamiento);

    if (siguienteDosisValida != null) {
      // 6. Si existe una siguiente dosis, la reprogramamos
      debugPrint("SKIP: Reprogramando la alarma para las $siguienteDosisValida con ID de Serie: ${freshTratamiento.prescriptionAlarmId}");
      await _rescheduleAlarm(siguienteDosisValida, freshTratamiento);
    } else {
      debugPrint("SKIP: No hay más dosis futuras que programar después de la omisión.");
    }

    return true;
  }

  /// **NUEVO MÉTODO PRIVADO**
  /// Lógica para encontrar la próxima dosis válida.
  /// Lógica para encontrar la próxima dosis válida.
  static Future<DateTime?> _findNextUpcomingDose({required Tratamiento tratamiento}) async {
    final DateTime inicio = tratamiento.fechaInicioTratamiento;
    final DateTime fechaFin = tratamiento.fechaFinTratamiento;
    final int intervalo = int.parse(tratamiento.intervaloDosis);
    final List<DateTime> dosisOmitidas = tratamiento.skippedDoses;

    DateTime dosisActual = inicio;

    while (dosisActual.isBefore(fechaFin)) {
      if (dosisActual.isAfter(DateTime.now())) {
        final esOmitida = dosisOmitidas.any((om) => om.isAtSameMomentAs(dosisActual));
        if (!esOmitida) {
          return dosisActual;
        }
      }
      dosisActual = dosisActual.add(Duration(hours: intervalo));
    }
    return null;
  }
  // ============== FIN DE LA CORRECCIÓN ==============
}