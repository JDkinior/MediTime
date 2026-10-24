import 'package:meditime/core/utils.dart';
// lib/services/treatment_service.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/treatment_form_data.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/notification_service.dart';

/// Servicio para manejar la lógica de tratamientos
class TreatmentService {
  final FirestoreService _firestoreService;

  TreatmentService(this._firestoreService);

  /// Guarda un nuevo tratamiento y programa las notificaciones
  Future<DocumentReference> saveTreatment({
    required String userId,
    CaregiverProfile? profile,
    required TreatmentFormData formData,
  }) async {
    // Generar ID único positivo en rango seguro (< 90,000,000) para permitir IDs derivados de snooze
    final int prescriptionAlarmManagerId = Random().nextInt(89999999) + 100000;

    // Calcular fechas manteniendo el ancla canónica exacta (segundos y milisegundos en 0)
    final now = DateTime.now();
    DateTime primeraDosisCanonical = DateTime(
      now.year,
      now.month,
      now.day,
      formData.horaPrimeraDosis.hour,
      formData.horaPrimeraDosis.minute,
    );

    final int intervaloHoras = formData.intervaloDosis > 0 ? formData.intervaloDosis : 8;

    // Si la hora seleccionada coincide con el minuto actual o fue hace menos de 5 minutos:
    // Disparamos la primera alarma en 5 segundos, pero CONSERVAMOS primeraDosisCanonical
    // exactamente en la hora/minuto seleccionada para que las tomas siguientes NO se corran.
    DateTime primeraAlarmaFireTime;
    final difference = now.difference(primeraDosisCanonical);
    if (difference.inSeconds >= 0 && difference.inMinutes < 5) {
      primeraAlarmaFireTime = now.add(const Duration(seconds: 5));
    } else if (primeraDosisCanonical.isBefore(now)) {
      // Si la hora base ya pasó hoy por más de 5 minutos, avanzar las dosis del ciclo de hoy
      // según el intervalo (ej. 8:00 AM + 8h = 4:00 PM hoy), siempre sobre la rejilla exacta.
      while (primeraDosisCanonical.isBefore(now)) {
        primeraDosisCanonical = primeraDosisCanonical.add(Duration(hours: intervaloHoras));
      }
      primeraAlarmaFireTime = primeraDosisCanonical;
    } else {
      primeraAlarmaFireTime = primeraDosisCanonical;
    }

    final DateTime fechaInicioTratamiento = primeraDosisCanonical;
    final DateTime fechaFinTratamiento = formData.calculateEndDate(
      fechaInicioTratamiento,
    );

    final int cantidadTotalCaja = formData.cantidadTotalCaja > 0
        ? formData.cantidadTotalCaja
        : formData.cantidadActual;

    // Guardar en Firestore
    final DocumentReference docRef = await _firestoreService.saveMedicamento(
      userId: userId,
      profile: profile,
      nombreMedicamento: formData.nombreMedicamento,
      presentacion: formData.presentacion,
      duracion: formData.duracionEnDias.toString(),
      cantidadActual: formData.cantidadActual,
      cantidadTotalCaja: cantidadTotalCaja,
      dosisPorToma: formData.dosisPorToma,
      horaPrimeraDosis: formData.horaPrimeraDosis,
      intervaloDosis: Duration(hours: intervaloHoras),
      prescriptionAlarmId: prescriptionAlarmManagerId,
      fechaInicioTratamiento: fechaInicioTratamiento,
      fechaFinTratamiento: fechaFinTratamiento,
      notas: formData.notas,
    );

    // Programar notificaciones
    await _scheduleNotifications(
      formData: formData,
      primeraDosisDateTime: primeraAlarmaFireTime,
      canonicalDoseTime: primeraDosisCanonical,
      fechaInicioTratamiento: fechaInicioTratamiento,
      fechaFinTratamiento: fechaFinTratamiento,
      prescriptionAlarmManagerId: prescriptionAlarmManagerId,
      userId: userId,
      docId: docRef.id,
      profile: profile,
    );

    return docRef;
  }

  /// Actualiza un tratamiento existente y reprograma sus notificaciones
  Future<void> updateTreatment({
    required String userId,
    CaregiverProfile? profile,
    required String docId,
    required TreatmentFormData formData,
    required Tratamiento originalTratamiento,
  }) async {
    final now = DateTime.now();
    // Alinear la fecha de inicio con la nueva horaPrimeraDosis sin perder el día de inicio original
    final DateTime fechaInicioTratamiento = DateTime(
      originalTratamiento.fechaInicioTratamiento.year,
      originalTratamiento.fechaInicioTratamiento.month,
      originalTratamiento.fechaInicioTratamiento.day,
      formData.horaPrimeraDosis.hour,
      formData.horaPrimeraDosis.minute,
    );
    final DateTime fechaFinTratamiento = formData.calculateEndDate(fechaInicioTratamiento);

    DateTime proximaDosisCanonical = DateTime(
      now.year,
      now.month,
      now.day,
      formData.horaPrimeraDosis.hour,
      formData.horaPrimeraDosis.minute,
    );

    final int intervaloHoras = formData.intervaloDosis > 0 ? formData.intervaloDosis : 8;
    DateTime proximaAlarmaFireTime;
    final difference = now.difference(proximaDosisCanonical);
    if (difference.inSeconds >= 0 && difference.inMinutes < 5) {
      proximaAlarmaFireTime = now.add(const Duration(seconds: 5));
    } else {
      while (proximaDosisCanonical.isBefore(now)) {
        proximaDosisCanonical = proximaDosisCanonical.add(Duration(hours: intervaloHoras));
      }
      proximaAlarmaFireTime = proximaDosisCanonical;
    }

    final int cantidadTotalCaja = formData.cantidadTotalCaja > 0
        ? formData.cantidadTotalCaja
        : formData.cantidadActual;

    await _firestoreService.updateMedicamento(
      userId: userId,
      profile: profile,
      docId: docId,
      nombreMedicamento: formData.nombreMedicamento,
      presentacion: formData.presentacion,
      duracion: formData.duracionEnDias.toString(),
      cantidadActual: formData.cantidadActual,
      cantidadTotalCaja: cantidadTotalCaja,
      dosisPorToma: formData.dosisPorToma,
      horaPrimeraDosis: formData.horaPrimeraDosis,
      intervaloDosis: Duration(hours: intervaloHoras),
      fechaInicioTratamiento: fechaInicioTratamiento,
      fechaFinTratamiento: fechaFinTratamiento,
      notas: formData.notas,
    );

    // Cancelar alarmas anteriores y reprogramar
    try {
      await NotificationService.cancelTreatmentAlarms(
        originalTratamiento.prescriptionAlarmId,
        docId: docId,
      );
    } catch (e) {
      debugPrint('Error al cancelar alarmas previas del tratamiento: $e');
    }

    await _scheduleNotifications(
      formData: formData,
      primeraDosisDateTime: proximaAlarmaFireTime,
      canonicalDoseTime: proximaDosisCanonical,
      fechaInicioTratamiento: fechaInicioTratamiento,
      fechaFinTratamiento: fechaFinTratamiento,
      prescriptionAlarmManagerId: originalTratamiento.prescriptionAlarmId,
      userId: userId,
      docId: docId,
      profile: profile,
    );
  }

  /// Programa las notificaciones para el tratamiento
  Future<void> _scheduleNotifications({
    required TreatmentFormData formData,
    required DateTime primeraDosisDateTime,
    required DateTime canonicalDoseTime,
    required DateTime fechaInicioTratamiento,
    required DateTime fechaFinTratamiento,
    required int prescriptionAlarmManagerId,
    required String userId,
    required String docId,
    CaregiverProfile? profile,
  }) async {
    if (!canonicalDoseTime.isAfter(fechaFinTratamiento)) {
      debugPrint(
        "Programando PRIMERA alarma para ${formData.nombreMedicamento} "
        "a las $primeraDosisDateTime (canónica: $canonicalDoseTime) con ID: $prescriptionAlarmManagerId",
      );

      // Verificar permisos antes de programar
      final hasPermissions =
          await NotificationService.checkExactAlarmPermissions();
      if (!hasPermissions) {
        debugPrint("ADVERTENCIA: No se tienen permisos para alarmas exactas");
      }

      await NotificationService.scheduleNewTreatment(
        nombreMedicamento: formData.nombreMedicamento,
        presentacion: formData.presentacion,
        intervaloEnHoras: formData.intervaloDosis,
        primeraDosisDateTime: primeraDosisDateTime,
        canonicalDoseTime: canonicalDoseTime,
        fechaInicioTratamiento: fechaInicioTratamiento,
        horaPrimeraDosis: formData.horaPrimeraDosis,
        dosisPorToma: formData.dosisPorToma,
        fechaFinTratamiento: fechaFinTratamiento,
        prescriptionAlarmManagerId: prescriptionAlarmManagerId,
        userId: userId,
        docId: docId,
        profile: profile,
      );
    }
  }

  /// Valida los datos del formulario
  String? validateFormData(TreatmentFormData formData) {
    if (formData.nombreMedicamento.isEmpty) {
      return 'El nombre del medicamento es requerido';
    }

    if (formData.presentacion.isEmpty) {
      return 'La presentación es requerida';
    }

    if (formData.cantidadActual < 0) {
      formData.cantidadActual = 0;
    }

    if (formData.cantidadTotalCaja < 0) {
      formData.cantidadTotalCaja = 0;
    }

    if (formData.dosisPorToma <= 0) {
      formData.dosisPorToma = 1;
    }

    if (formData.intervaloDosis <= 0) {
      return 'El intervalo de dosis debe ser mayor a 0';
    }

    if (!formData.esIndefinido && formData.duracionNumero <= 0) {
      return 'La duración debe ser mayor a 0';
    }

    return null; // Sin errores
  }

  /// Calcula información de resumen del tratamiento
  Map<String, String> calculateSummaryInfo(TreatmentFormData formData, [String? localeCode]) {
    return {
      'dosesPerDay': formData.dosisPerDay.toString(),
      'totalDoses':
          formData.esIndefinido ? 'Indefinido' : formData.totalDoses.toString(),
      'durationText': formData.duracionText,
      'endDate':
          formData.esIndefinido
              ? 'Sin fecha límite'
              : _formatDate(formData.calculateEndDate(DateTime.now()), localeCode),
    };
  }

  /// Formatea una fecha para mostrar con 2 dígitos por día, mes y año según el idioma
  String _formatDate(DateTime date, [String? localeCode]) {
    return AppUtils.formatTwoDigitDate(date, localeCode);
  }
}
