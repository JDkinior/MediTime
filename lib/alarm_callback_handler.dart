// lib/alarm_callback_handler.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/firebase_options.dart';

/// Punto de entrada para la ejecución de alarmas en segundo plano.
///
/// Esta función está marcada con `@pragma('vm:entry-point')`, lo que permite
/// que el sistema operativo Android la ejecute en un "Isolate" (hilo) separado,
/// incluso si la aplicación está completamente cerrada.
///
/// [id] es el ID único de la alarma de `android_alarm_manager_plus`.
/// [params] es un mapa que contiene toda la información necesaria para procesar
/// la alarma, incluyendo los datos del tratamiento y del usuario. Esto es crucial
/// para permitir el funcionamiento sin conexión.
@pragma('vm:entry-point')
void alarmCallbackLogic(int id, Map<String, dynamic> params) async {
  debugPrint("INICIO alarmCallbackLogic - ID: $id");
  debugPrint("Parámetros recibidos: ${params.keys.toList()}");

  try {
    WidgetsFlutterBinding.ensureInitialized();

    bool firebaseInitialized = false;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform, // Opciones críticas
      ).timeout(const Duration(seconds: 5));
      firebaseInitialized = true;
      debugPrint("Firebase inicializado correctamente en callback");
    } catch (e) {
      debugPrint("ERROR: Firebase no se pudo inicializar en callback: $e");
    }

    await NotificationService.initializeCore();

    final preferenceService = PreferenceService();
    
    // CAMBIO CRÍTICO: Extraer datos del payload sin depender de Firebase con validaciones null-safe
    final userId = params['userId'] as String?;
    final docId = params['docId'] as String?;
    final doseTimeString = params['doseTime'] as String?;
    
    // Validaciones críticas
    if (userId == null || docId == null || doseTimeString == null) {
      debugPrint("ERROR: Parámetros críticos son null - userId: $userId, docId: $docId, doseTime: $doseTimeString");
      return;
    }
    
    final doseTime = DateTime.parse(doseTimeString);
    final notificationId = params['currentNotificationId'] ?? Random().nextInt(100000);
    
    // NUEVOS PARÁMETROS: Datos del tratamiento incluidos en el payload
    final nombreMedicamento = params['nombreMedicamento'] ?? 'Medicamento';
    final intervaloHoras = params['intervaloHoras'] ?? 8;
    // Note: presentacion, fechaFinTratamientoString, and prescriptionAlarmId are available in params but not currently used

    // CAMBIO CRÍTICO: Leer preferencias con fallback local
    bool isModeActive = false;
    try {
      isModeActive = await preferenceService.getNotificationMode();
    } catch (e) {
      debugPrint("ERROR leyendo preferencias: $e. Usando modo pasivo como default");
      isModeActive = false;
    }

    // CAMBIO CRÍTICO: Procesar notificación independientemente del estado de Firebase
    if (isModeActive) {
      debugPrint("Modo Activo detectado para: $nombreMedicamento");
      
      // Mostrar notificación activa inmediatamente
      await NotificationService.showActiveNotification(
        id: notificationId,
        title: 'Hora de tomar: $nombreMedicamento',
        body: 'Por favor, confirma si tomaste tu dosis.',
        payload: 'active_notification|$userId|$docId|${doseTime.toIso8601String()}',
      );

      // CAMBIO CRÍTICO: Actualizar Firestore solo si está disponible
      if (firebaseInitialized) {
        try {
          final firestoreService = FirestoreService();
          await firestoreService.updateDoseStatus(userId, docId, doseTime, DoseStatus.notificada)
              .timeout(Duration(seconds: 3));
          debugPrint("Estado actualizado en Firestore: notificada");
        } catch (e) {
          debugPrint("ERROR actualizando Firestore (modo activo): $e");
          // La notificación ya se mostró, continuamos
        }
      }
    } else {
      debugPrint("Modo Pasivo detectado para: $nombreMedicamento");
      
      // Mostrar notificación simple inmediatamente
      await NotificationService.showSimpleNotification(
        id: notificationId,
        title: 'Dosis registrada: $nombreMedicamento',
        body: 'Se ha marcado como tomada. Próxima dosis en $intervaloHoras horas.',
      );

      // CAMBIO CRÍTICO: Actualizar Firestore y reprogramar solo si está disponible
      if (firebaseInitialized) {
        try {
          final firestoreService = FirestoreService();
          await firestoreService.updateDoseStatus(userId, docId, doseTime, DoseStatus.tomada)
              .timeout(Duration(seconds: 3));
          debugPrint("Estado actualizado en Firestore: tomada");

          // Reprogramar siguiente dosis
          await _reprogramarSiguienteDosis(params, userId, firestoreService);
        } catch (e) {
          debugPrint("ERROR actualizando Firestore (modo pasivo): $e");
          // FALLBACK: Reprogramar siguiente dosis usando solo parámetros
          await _reprogramarSiguienteDosisOffline(params);
        }
      } else {
        // FALLBACK: Reprogramar siguiente dosis usando solo parámetros
        await _reprogramarSiguienteDosisOffline(params);
      }
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
Future<void> _reprogramarSiguienteDosis(Map<String, dynamic> params, String userId, FirestoreService firestoreService) async {
  try {
    final docId = params['docId'] as String?;
    if (docId == null) {
      debugPrint("ERROR: docId es null en _reprogramarSiguienteDosis");
      return;
    }
    
    final doc = await firestoreService.getMedicamentoDocRef(userId, docId).get()
        .timeout(Duration(seconds: 5));
    
    if (doc.exists) {
      final tratamiento = Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      await NotificationService.rescheduleNextPendingDose(tratamiento, userId);
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
    final siguienteDosis = doseTime.add(Duration(hours: intervaloHoras));

    // Solo reprogramar si no hemos pasado la fecha de fin
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
      debugPrint("Tratamiento completado, no se reprograma más");
    }
  } catch (e) {
    debugPrint("ERROR en reprogramación offline: $e");
  }
}