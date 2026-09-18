import 'dart:ui';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/firebase_options.dart';

/// Punto de entrada para la ejecución de alarmas en segundo plano.
///
/// Esta función está marcada con `@pragma('vm:entry-point')`, lo que permite
/// que el sistema operativo Android la ejecute en un "Isolate" (hilo) separado,
/// incluso si la aplicación está completamente cerrada o el dispositivo no tiene internet.
///
/// [id] es el ID único de la alarma de `android_alarm_manager_plus`.
/// [params] es un mapa que contiene toda la información necesaria para procesar
/// la alarma, incluyendo los datos del tratamiento y del usuario. Esto es crucial
/// para permitir el funcionamiento 100% offline.
@pragma('vm:entry-point')
void alarmCallbackLogic(int id, Map<String, dynamic> params) async {
  debugPrint("🚨 INICIO alarmCallbackLogic (Offline-First) - ID: $id");
  debugPrint("Parámetros recibidos: ${params.keys.toList()}");

  try {
    // Asegura que los plugins estén registrados en el isolate de fondo (Android)
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Inicializar el servicio de notificaciones de inmediato
    await NotificationService.initializeCore();

    final preferenceService = PreferenceService();

    // 2. Extraer datos directamente del payload (100% offline)
    final userId = params['userId'] as String?;
    final docId = params['docId'] as String?;
    final doseTimeString = params['doseTime'] as String?;

    // Validaciones críticas
    if (userId == null || docId == null || doseTimeString == null) {
      debugPrint("ERROR: Parámetros críticos son null - userId: $userId, docId: $docId, doseTime: $doseTimeString");
      return;
    }

    final doseTime = DateTime.parse(doseTimeString);
    final notificationId = (params['currentNotificationId'] as int?) ?? Random().nextInt(100000);

    // Datos del tratamiento incluidos en el payload
    final nombreMedicamento = params['nombreMedicamento'] ?? 'Medicamento';
    final intervaloHoras = params['intervaloHoras'] ?? 8;
    final pacienteNombre = params['pacienteNombre'] as String?;
    final habitacion = params['habitacion'] as String?;
    final categoria = params['categoria'] as String?;
    final dosisPorToma = params['dosisPorToma'] ?? 1;
    final presentacion = params['presentacion'] as String? ?? 'dosis';

    // 3. Leer modo de recordatorio (automático, activo o alarma)
    DoseReminderMode reminderMode = DoseReminderMode.automatic;
    try {
      reminderMode = await preferenceService.getReminderMode();
    } catch (e) {
      debugPrint("ERROR leyendo preferencias: $e. Usando modo automático como default");
      reminderMode = DoseReminderMode.automatic;
    }

    // 4. Validación de usuario y revocación local (sin requerir internet)
    try {
      final currentUserId = await preferenceService.getCurrentUserId();
      final isRevoked = await preferenceService.isTreatmentRevoked(userId, docId);
      final int seriesId = (params['prescriptionAlarmId'] as int?) ?? 0;

      if (currentUserId == null || currentUserId != userId || isRevoked) {
        debugPrint(
          "Guard: Bloqueando notificación. currentUserId=$currentUserId, payloadUserId=$userId, revoked=$isRevoked",
        );
        if (seriesId != 0) {
          await NotificationService.cancelTreatmentAlarms(seriesId);
          debugPrint("Guard: Serie de alarmas cancelada para ID: $seriesId");
        }
        return; // No mostrar ni reprogramar nada si el tratamiento fue revocado o cambió de usuario
      }
    } catch (e) {
      debugPrint("ERROR en guard de usuario/revocado: $e");
    }

    // Perfil de paciente/cuidador si aplica
    CaregiverProfile? dummyProfile;
    final profileId = params['profileId'] as String?;
    if (profileId != null && profileId.isNotEmpty) {
      dummyProfile = CaregiverProfile(
        id: profileId,
        name: params['pacienteNombre'] as String? ?? '',
        relationship: 'dummy',
        colorHex: '#000000',
        isExternalUser: params['isExternalUser'] as bool? ?? false,
        linkedUid: params['linkedUid'] as String?,
      );
    }

    // Construcción de textos de notificación
    String notificationTitle = 'Hora de tomar: $nombreMedicamento';
    String notificationBody = 'Por favor, confirma si tomaste tu dosis.';

    if (pacienteNombre != null && pacienteNombre.isNotEmpty) {
      notificationTitle = 'Suministrar $nombreMedicamento a $pacienteNombre';

      String body = 'Es momento de darle $dosisPorToma $presentacion.';

      if (habitacion != null && habitacion.isNotEmpty) {
        if (categoria != null && categoria.isNotEmpty) {
          body += ' Se encuentra en la Hab. $habitacion ($categoria).';
        } else {
          body += ' Se encuentra en la Hab. $habitacion.';
        }
      } else if (categoria != null && categoria.isNotEmpty) {
        body += ' Ubicación: $categoria.';
      }

      notificationBody = body;
    }

    // 5. DISPARAR NOTIFICACIÓN Y ALARMA DE FORMA INMEDIATA (CRÍTICO: ANTES DE CUALQUIER RED)
    if (reminderMode == DoseReminderMode.alarm) {
      debugPrint("🚨 Modo Alarma disparándose de inmediato para: $nombreMedicamento");

      final alarmPayload =
          'alarm_mode|$userId|$docId|${doseTime.toIso8601String()}|$nombreMedicamento|$dosisPorToma|$presentacion|${pacienteNombre ?? ""}|${habitacion ?? ""}|$notificationId|${profileId ?? ""}';

      // NOTA: NotificationService.showAlarmModeNotification usa FLAG_INSISTENT y
      // audioAttributesUsage: AudioAttributesUsage.alarm en el canal de alarma.
      // El sistema operativo Android se encarga de reproducir el tono de alarma
      // y la vibración en bucle nativamente, y los detiene al instante cuando
      // la notificación se descarta o se presiona un botón de acción.
      // NO iniciar reproductores secundarios en este isolate para evitar sonidos fantasma.

      // Mostrar notificación de alta prioridad en pantalla completa
      await NotificationService.showAlarmModeNotification(
        id: notificationId,
        title: notificationTitle,
        body: notificationBody,
        payload: alarmPayload,
      );
    } else if (reminderMode == DoseReminderMode.active) {
      debugPrint("🔔 Modo Activo disparándose de inmediato para: $nombreMedicamento");

      await NotificationService.showActiveNotification(
        id: notificationId,
        title: notificationTitle,
        body: notificationBody,
        payload: 'active_notification|$userId|$docId|${doseTime.toIso8601String()}|${profileId ?? ""}',
      );
    } else {
      debugPrint("✅ Modo Automático detectado para: $nombreMedicamento");

      await NotificationService.showSimpleNotification(
        id: notificationId,
        title: notificationTitle,
        body: pacienteNombre != null && pacienteNombre.isNotEmpty
            ? notificationBody
            : 'Dosis registrada automáticamente. Próxima dosis en $intervaloHoras horas.',
      );
    }

    // 6. SINCRONIZACIÓN ASÍNCRONA CON FIREBASE (NO BLOQUEANTE, CON TIMEOUT CORTO)
    bool syncSuccess = false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 2));
      }

      final firestoreService = FirestoreService();
      final statusToUpdate = reminderMode == DoseReminderMode.automatic
          ? DoseStatus.tomada
          : DoseStatus.notificada;

      await firestoreService
          .updateDoseStatus(
            userId,
            docId,
            doseTime,
            statusToUpdate,
            dummyProfile,
          )
          .timeout(const Duration(seconds: 2));

      debugPrint("Estado sincronizado en Firestore: $statusToUpdate");
      syncSuccess = true;

      // Si es modo automático y hay red, reprogramar la siguiente con datos de Firestore
      if (reminderMode == DoseReminderMode.automatic) {
        await _reprogramarSiguienteDosis(params, userId, firestoreService, dummyProfile);
      }
    } catch (syncError) {
      debugPrint("Sincronización en segundo plano omitida o en cola offline (sin conexión): $syncError");
    }

    // 7. SI ES MODO AUTOMÁTICO Y NO HUBO SINCRONIZACIÓN EXITOSA, REPROGRAMAR OFFLINE INMEDIATAMENTE
    if (reminderMode == DoseReminderMode.automatic && !syncSuccess) {
      debugPrint("Reprogramando siguiente dosis en modo offline para modo automático...");
      await _reprogramarSiguienteDosisOffline(params);
    }

    debugPrint("FIN alarmCallbackLogic - ID: $id - SUCCESS");
  } catch (e) {
    debugPrint("ERROR CRÍTICO en alarmCallbackLogic: $e");

    // FALLBACK DE EMERGENCIA: Mostrar notificación básica
    try {
      final notificationId = (params['currentNotificationId'] as int?) ?? Random().nextInt(100000);
      final nombreMedicamento = (params['nombreMedicamento'] as String?) ?? 'Medicamento';

      await NotificationService.showSimpleNotification(
        id: notificationId,
        title: 'Hora de tomar: $nombreMedicamento',
        body: 'Confirma tu dosis en la aplicación.',
      );
      debugPrint("Notificación de emergencia mostrada");
    } catch (emergencyError) {
      debugPrint("ERROR CRÍTICO mostrando notificación de emergencia: $emergencyError");
    }
  }
}

/// Reprograma la siguiente dosis utilizando datos frescos de Firebase.
///
/// Este es el método preferido cuando hay conexión a internet. Lee el tratamiento
/// directamente de Firestore para asegurarse de que tiene el estado más actualizado
/// antes de encontrar y programar la siguiente dosis pendiente.
// NUEVA FUNCIÓN: Reprogramar siguiente dosis con acceso a Firebase
Future<void> _reprogramarSiguienteDosis(Map<String, dynamic> params, String userId, FirestoreService firestoreService, CaregiverProfile? dummyProfile) async {
  try {
    final docId = params['docId'] as String?;
    if (docId == null) {
      debugPrint("ERROR: docId es null en _reprogramarSiguienteDosis");
      return;
    }
    
    final doc = await firestoreService.getMedicamentoDocRef(userId, docId, dummyProfile).get()
        .timeout(Duration(seconds: 5));
    
    if (doc.exists) {
      final tratamiento = Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      await NotificationService.rescheduleNextPendingDose(tratamiento, userId, dummyProfile);
      debugPrint("Siguiente dosis reprogramada con datos de Firebase");
    }
  } catch (e) {
    debugPrint("ERROR reprogramando con Firebase: $e");
    // Fallback a reprogramación offline
    await _reprogramarSiguienteDosisOffline(params);
  }
}

/// Reprograma la siguiente dosis utilizando únicamente los datos pasados en [params].
///
/// Este es el método de fallback que se utiliza cuando no hay conexión a Firebase.
/// Calcula la hora de la siguiente dosis basándose en el intervalo y la hora de la dosis actual,
/// y la programa si aún está dentro del rango de fechas del tratamiento.
// NUEVA FUNCIÓN: Reprogramar siguiente dosis sin Firebase (offline)
Future<void> _reprogramarSiguienteDosisOffline(Map<String, dynamic> params) async {
  try {
    final doseTimeString = params['doseTime'] as String?;
    if (doseTimeString == null) {
      debugPrint("ERROR: doseTime es null en _reprogramarSiguienteDosisOffline");
      return;
    }
    
    final doseTime = DateTime.parse(doseTimeString);
    final intervaloHoras = (params['intervaloHoras'] as int?) ?? 8;
    final fechaFinTratamientoString = params['fechaFinTratamientoString'] as String?;
    final prescriptionAlarmId = (params['prescriptionAlarmId'] as int?) ?? 0;
    
    if (fechaFinTratamientoString == null || prescriptionAlarmId == 0) {
      debugPrint("Datos insuficientes para reprogramación offline - fechaFin: $fechaFinTratamientoString, alarmId: $prescriptionAlarmId");
      return;
    }

    final fechaFinTratamiento = DateTime.parse(fechaFinTratamientoString);
    DateTime siguienteDosis = doseTime.add(Duration(hours: intervaloHoras));
    final now = DateTime.now();

    // CRÍTICO: Si la siguiente dosis calculada ya pasó (ej. dispositivo apagado),
    // adelantamos el cálculo hasta encontrar la próxima dosis en el futuro.
    // Esto evita un bucle infinito de alarmas disparándose inmediatamente.
    while (siguienteDosis.isBefore(now) && siguienteDosis.isBefore(fechaFinTratamiento)) {
      siguienteDosis = siguienteDosis.add(Duration(hours: intervaloHoras));
    }

    // Solo reprogramar si la dosis futura calculada no pasa la fecha de fin
    if (siguienteDosis.isBefore(fechaFinTratamiento)) {
      await NotificationService.scheduleOfflineAlarm(
        scheduleTime: siguienteDosis,
        alarmId: prescriptionAlarmId,
        params: {
          ...params,
          'doseTime': siguienteDosis.toIso8601String(),
          'currentNotificationId': Random().nextInt(100000),
        },
      );
      debugPrint("Siguiente dosis reprogramada offline para: $siguienteDosis");
    } else {
      debugPrint("Tratamiento completado, no se reprograma más de forma offline");
    }
  } catch (e) {
    debugPrint("ERROR en reprogramación offline: $e");
  }
}