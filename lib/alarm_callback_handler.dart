// lib/alarm_callback_handler.dart
import 'dart:math';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:meditime/notification_service.dart';
import 'package:flutter/material.dart'; // Para debugPrint

@pragma('vm:entry-point')
void alarmCallbackLogic(int id, Map<String, dynamic> params) async {
  debugPrint("INICIO alarmCallbackLogic - ID de Alarma (AndroidAlarmManager): $id, params: $params");

  // Asegurar que el núcleo de NotificationService esté inicializado.
  // Esta llamada es segura ya que initializeCore() no solicita permisos.
  await NotificationService.initializeCore();

  final String nombreMedicamento = params['nombreMedicamento'] ?? 'Medicamento';
  final String presentacion = params['presentacion'] ?? 'tu dosis';
  final int intervaloHoras = params['intervaloHoras'] ?? 8;
  final String fechaFinTratamientoString = params['fechaFinTratamientoString'];
  final DateTime fechaFinTratamiento = DateTime.parse(fechaFinTratamientoString);
  final int prescriptionAlarmId = params['prescriptionAlarmId']; // El ID de la serie de AlarmManager

  final int currentNotificationId = params['currentNotificationId'] ?? Random().nextInt(100000);

  debugPrint("Mostrando notificación para: $nombreMedicamento con ID visual: $currentNotificationId");
  await NotificationService.showSimpleNotification(
    id: currentNotificationId,
    title: 'Hora de tomar: $nombreMedicamento',
    body: 'Tomar $presentacion. Próxima dosis en $intervaloHoras horas.',
  );

  DateTime horaEstaDosis = DateTime.now(); 
  DateTime proximaDosis = horaEstaDosis.add(Duration(hours: intervaloHoras));

  if (proximaDosis.isBefore(fechaFinTratamiento)) {
    final int nextLocalNotificationId = Random().nextInt(100000); 

    debugPrint("Reprogramando siguiente alarma para $nombreMedicamento a las $proximaDosis (ID de serie: $prescriptionAlarmId)");
    await AndroidAlarmManager.oneShotAt(
      proximaDosis,
      prescriptionAlarmId, // Usa el MISMO ID de serie de AlarmManager
      alarmCallbackLogic,
      exact: true,
      wakeup: true,
      alarmClock: true,
      rescheduleOnReboot: true,
      params: {
        'currentNotificationId': nextLocalNotificationId, // Nuevo ID para la próxima notificación visual
        'nombreMedicamento': nombreMedicamento,
        'presentacion': presentacion,
        'intervaloHoras': intervaloHoras,
        'fechaFinTratamientoString': fechaFinTratamientoString,
        'prescriptionAlarmId': prescriptionAlarmId,
      },
    );
  } else {
    debugPrint("Tratamiento para $nombreMedicamento finalizado. No se reprograman más alarmas.");
  }
  debugPrint("FIN alarmCallbackLogic - ID de Alarma (AndroidAlarmManager): $id");
}