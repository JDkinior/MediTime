// lib/repositories/treatment_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meditime/core/result.dart';
import 'package:meditime/models/tratamiento.dart';

/// Abstract repository interface for treatment operations.
/// 
/// This interface defines the contract for treatment data operations,
/// allowing for different implementations (Firestore, local storage, etc.)
abstract class TreatmentRepository {
  /// Gets a stream of treatments for a specific user
  Stream<Result<List<Tratamiento>>> getTreatmentStream(String userId);
  
  /// Gets treatments for a specific user (one-time fetch)
  Future<Result<List<Tratamiento>>> getTreatments(String userId);
  
  /// Saves a new treatment
  Future<Result<DocumentReference>> saveTreatment({
    required String userId,
    required String nombreMedicamento,
    required String presentacion,
    required String duracion,
    required TimeOfDay horaPrimeraDosis,
    required Duration intervaloDosis,
    required int prescriptionAlarmId,
    required DateTime fechaInicioTratamiento,
    required DateTime fechaFinTratamiento,
    required String notas,
  });
  
  /// Deletes a treatment
  Future<Result<void>> deleteTreatment(String userId, String docId);
  
  /// Updates the status of a specific dose
  Future<Result<void>> updateDoseStatus(
    String userId, 
    String docId, 
    DateTime doseTime, 
    DoseStatus newStatus
  );
}