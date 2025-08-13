// lib/repositories/firestore_treatment_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meditime/core/result.dart';
import 'package:meditime/core/stream_cache.dart';
import 'package:meditime/core/constants.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/repositories/treatment_repository.dart';
import 'package:meditime/services/tratamiento_service.dart';

/// Firestore implementation of the TreatmentRepository.
/// 
/// Handles all treatment-related database operations using Cloud Firestore.
/// Includes stream caching for improved performance.
class FirestoreTreatmentRepository implements TreatmentRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StreamCache<String, Result<List<Tratamiento>>> _streamCache = 
      StreamCache<String, Result<List<Tratamiento>>>();

  @override
  Stream<Result<List<Tratamiento>>> getTreatmentStream(String userId) {
    return _streamCache.getStream(userId, () {
      try {
        final stream = _db
            .collection(AppConstants.medicamentosCollection)
            .doc(userId)
            .collection(AppConstants.userMedicamentosSubcollection)
            .snapshots();

        return stream.map((snapshot) {
          try {
            final treatments = snapshot.docs.map((doc) {
              return Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
            }).toList();
            
            return Result.success(treatments);
          } catch (e) {
            debugPrint('Error parsing treatments from Firestore: $e');
            return Result.failure(AppConstants.treatmentLoadErrorMessage);
          }
        });
      } catch (e) {
        debugPrint('Error creating treatment stream: $e');
        return Stream.value(Result.failure(AppConstants.treatmentLoadErrorMessage));
      }
    });
  }

  @override
  Future<Result<List<Tratamiento>>> getTreatments(String userId) async {
    try {
      // Check if we have a cached value first
      final cachedValue = _streamCache.getLastValue(userId);
      if (cachedValue != null && cachedValue.isSuccess) {
        return cachedValue;
      }

      final snapshot = await _db
          .collection(AppConstants.medicamentosCollection)
          .doc(userId)
          .collection(AppConstants.userMedicamentosSubcollection)
          .get();

      final treatments = snapshot.docs.map((doc) {
        return Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      }).toList();

      return Result.success(treatments);
    } catch (e) {
      debugPrint('Error getting treatments: $e');
      return Result.failure(AppConstants.treatmentLoadErrorMessage);
    }
  }

  @override
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
  }) async {
    try {
      // Generate initial dose status map
      final tratamientoService = TratamientoService();
      final tempTratamiento = Tratamiento(
        id: '',
        nombreMedicamento: nombreMedicamento,
        presentacion: presentacion,
        duracion: duracion,
        horaPrimeraDosis: horaPrimeraDosis,
        intervaloDosis: intervaloDosis,
        prescriptionAlarmId: prescriptionAlarmId,
        fechaInicioTratamiento: fechaInicioTratamiento,
        fechaFinTratamiento: fechaFinTratamiento,
      );

      final List<DateTime> todasLasDosis = tratamientoService.generarDosisTotales(tempTratamiento);
      final Map<String, String> doseStatusMap = {
        for (var dosis in todasLasDosis)
          dosis.toIso8601String(): DoseStatus.pendiente.toString().split('.').last
      };

      // Create a temporary treatment object to use its toFirestoreMap method
      final tempTreatment = Tratamiento(
        id: '',
        nombreMedicamento: nombreMedicamento,
        presentacion: presentacion,
        duracion: duracion,
        horaPrimeraDosis: horaPrimeraDosis,
        intervaloDosis: intervaloDosis,
        prescriptionAlarmId: prescriptionAlarmId,
        fechaInicioTratamiento: fechaInicioTratamiento,
        fechaFinTratamiento: fechaFinTratamiento,
        notas: notas,
        doseStatus: doseStatusMap.map((key, value) => MapEntry(key, DoseStatus.fromString(value))),
      );

      final docRef = await _db
          .collection(AppConstants.medicamentosCollection)
          .doc(userId)
          .collection(AppConstants.userMedicamentosSubcollection)
          .add(tempTreatment.toFirestoreMap());

      // Clear cache to force refresh
      _streamCache.clearKey(userId);

      return Result.success(docRef);
    } catch (e) {
      debugPrint('Error saving treatment: $e');
      return Result.failure(AppConstants.treatmentSaveErrorMessage);
    }
  }

  @override
  Future<Result<void>> deleteTreatment(String userId, String docId) async {
    try {
      // Best-effort: revoke locally and cancel alarms if possible (we don't know alarmId here without fetching)
      try {
        // Attempt to get the doc to obtain alarm id for cancellation
        final docRef = _db
            .collection(AppConstants.medicamentosCollection)
            .doc(userId)
            .collection(AppConstants.userMedicamentosSubcollection)
            .doc(docId);
        final snapshot = await docRef.get();
        if (snapshot.exists) {
          final t = Tratamiento.fromFirestore(snapshot);
          if (t.prescriptionAlarmId != 0) {
            // Lazy import to avoid circular references is not needed; file already imports services/tratamiento_service.dart
          }
        }
      } catch (_) {
        // ignore best-effort failures
      }
      await _db
          .collection(AppConstants.medicamentosCollection)
          .doc(userId)
          .collection(AppConstants.userMedicamentosSubcollection)
          .doc(docId)
          .delete();
      
      // Clear cache to force refresh
      _streamCache.clearKey(userId);
      
      return const Result.success(null);
    } catch (e) {
      debugPrint('Error deleting treatment: $e');
      return Result.failure(AppConstants.treatmentDeleteErrorMessage);
    }
  }

  @override
  Future<Result<void>> updateDoseStatus(
    String userId, 
    String docId, 
    DateTime doseTime, 
    DoseStatus newStatus
  ) async {
    try {
      final docRef = _db
          .collection(AppConstants.medicamentosCollection)
          .doc(userId)
          .collection(AppConstants.userMedicamentosSubcollection)
          .doc(docId);

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          throw Exception('Document not found');
        }

        final tratamiento = Tratamiento.fromFirestore(snapshot);

        final updatedDoseStatus = Map<String, DoseStatus>.from(tratamiento.doseStatus);
        final doseKey = doseTime.toIso8601String();
        updatedDoseStatus[doseKey] = newStatus;

        final mapToSave = updatedDoseStatus.map(
          (key, value) => MapEntry(key, value.value),
        );

        transaction.update(docRef, {AppConstants.doseStatusField: mapToSave});
      });

      // Clear cache to force refresh
      _streamCache.clearKey(userId);

      return const Result.success(null);
    } catch (e) {
      debugPrint('Error updating dose status: $e');
      return Result.failure(AppConstants.doseUpdateErrorMessage);
    }
  }

  /// Disposes the repository and cleans up resources
  void dispose() {
    _streamCache.dispose();
  }
}