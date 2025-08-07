// lib/services/treatment_service.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    required TreatmentFormData formData,
  }) async {
    // Generar ID único para las alarmas
    final int prescriptionAlarmManagerId = Random().nextInt(2147483647);

    // Calcular fechas
    final now = DateTime.now();
    DateTime primeraDosisDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      formData.horaPrimeraDosis.hour,
      formData.horaPrimeraDosis.minute,
    );

    // Si la primera dosis es en el pasado, programarla para mañana
    if (primeraDosisDateTime.isBefore(now)) {
      primeraDosisDateTime = primeraDosisDateTime.add(const Duration(days: 1));
    }

    final DateTime fechaInicioTratamiento = primeraDosisDateTime;
    final DateTime fechaFinTratamiento = formData.calculateEndDate(fechaInicioTratamiento);

    // Guardar en Firestore
    final DocumentReference docRef = await _firestoreService.saveMedicamento(
      userId: userId,
      nombreMedicamento: formData.nombreMedicamento,
      presentacion: formData.presentacion,
      duracion: formData.duracionEnDias.toString(),
      horaPrimeraDosis: formData.horaPrimeraDosis,
      intervaloDosis: Duration(hours: formData.intervaloDosis),
      prescriptionAlarmId: prescriptionAlarmManagerId,
      fechaInicioTratamiento: fechaInicioTratamiento,
      fechaFinTratamiento: fechaFinTratamiento,
      notas: formData.notas,
    );

    // Programar notificaciones
    await _scheduleNotifications(
      formData: formData,
      primeraDosisDateTime: primeraDosisDateTime,
      fechaFinTratamiento: fechaFinTratamiento,
      prescriptionAlarmManagerId: prescriptionAlarmManagerId,
      userId: userId,
      docId: docRef.id,
    );

    return docRef;
  }

  /// Programa las notificaciones para el tratamiento
  Future<void> _scheduleNotifications({
    required TreatmentFormData formData,
    required DateTime primeraDosisDateTime,
    required DateTime fechaFinTratamiento,
    required int prescriptionAlarmManagerId,
    required String userId,
    required String docId,
  }) async {
    if (primeraDosisDateTime.isBefore(fechaFinTratamiento)) {
      debugPrint(
        "Programando PRIMERA alarma para ${formData.nombreMedicamento} "
        "a las $primeraDosisDateTime con ID: $prescriptionAlarmManagerId",
      );

      // Verificar permisos antes de programar
      final hasPermissions = await NotificationService.checkExactAlarmPermissions();
      if (!hasPermissions) {
        debugPrint("ADVERTENCIA: No se tienen permisos para alarmas exactas");
      }

      await NotificationService.scheduleNewTreatment(
        nombreMedicamento: formData.nombreMedicamento,
        presentacion: formData.presentacion,
        intervaloEnHoras: formData.intervaloDosis,
        primeraDosisDateTime: primeraDosisDateTime,
        fechaFinTratamiento: fechaFinTratamiento,
        prescriptionAlarmManagerId: prescriptionAlarmManagerId,
        userId: userId,
        docId: docId,
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
    
    if (formData.intervaloDosis <= 0) {
      return 'El intervalo de dosis debe ser mayor a 0';
    }
    
    if (!formData.esIndefinido && formData.duracionNumero <= 0) {
      return 'La duración debe ser mayor a 0';
    }

    return null; // Sin errores
  }

  /// Calcula información de resumen del tratamiento
  Map<String, String> calculateSummaryInfo(TreatmentFormData formData) {
    return {
      'dosesPerDay': formData.dosisPerDay.toString(),
      'totalDoses': formData.esIndefinido ? 'Indefinido' : formData.totalDoses.toString(),
      'durationText': formData.duracionText,
      'endDate': formData.esIndefinido 
          ? 'Sin fecha límite' 
          : _formatDate(formData.calculateEndDate(DateTime.now())),
    };
  }

  /// Formatea una fecha para mostrar
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}