// lib/alarm_callback_handler.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/preference_service.dart';

@pragma('vm:entry-point')
void alarmCallbackLogic(int id, Map<String, dynamic> params) async {
  debugPrint("INICIO alarmCallbackLogic - ID: $id");

  await WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.initializeCore();

  final preferenceService = PreferenceService();
  final firestoreService = FirestoreService();

  // --- INICIO DE LA MODIFICACIÓN ---
  // Obtenemos los datos necesarios del payload de la alarma
  final userId = params['userId'];
  final docId = params['docId'];
  final doseTime = DateTime.parse(params['doseTime']);
  final notificationId = params['currentNotificationId'] ?? Random().nextInt(100000);

  // Obtenemos los datos más recientes del tratamiento desde Firestore
  final doc = await firestoreService.getMedicamentoDocRef(userId, docId).get();
  if (!doc.exists) {
    debugPrint("ERROR en Callback: Tratamiento no encontrado. Cancelando alarma.");
    await NotificationService.cancelTreatmentAlarms(id);
    return;
  }
  final tratamiento = Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
  // --- FIN DE LA MODIFICACIÓN ---

  // Leemos la preferencia del usuario en el momento de la ejecución
  final bool isModeActive = await preferenceService.getNotificationMode();

  if (isModeActive) {
    debugPrint("Modo Activo detectado para: ${tratamiento.nombreMedicamento}");
    await firestoreService.updateDoseStatus(userId, docId, doseTime, DoseStatus.notificada);
    await NotificationService.showActiveNotification(
      id: notificationId,
      title: 'Hora de tomar: ${tratamiento.nombreMedicamento}',
      body: 'Por favor, confirma si tomaste tu dosis.',
      payload: 'active_notification|$userId|$docId|${doseTime.toIso8601String()}',
    );
  } else {
    debugPrint("Modo Pasivo detectado para: ${tratamiento.nombreMedicamento}");
    await firestoreService.updateDoseStatus(userId, docId, doseTime, DoseStatus.tomada);
    await NotificationService.showSimpleNotification(
      id: notificationId,
      title: 'Dosis registrada: ${tratamiento.nombreMedicamento}',
      body: 'Se ha marcado como tomada. Próxima dosis en ${tratamiento.intervaloDosis} horas.',
    );
    // En modo pasivo, reprogramamos la siguiente inmediatamente
    await NotificationService.rescheduleNextPendingDose(tratamiento, userId);
  }

  debugPrint("FIN alarmCallbackLogic - ID: $id");
}