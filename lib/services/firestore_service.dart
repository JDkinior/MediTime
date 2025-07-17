// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/services/tratamiento_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Perfil de Usuario ---

  Future<void> saveUserProfile(String userId, Map<String, dynamic> data) {
    return _db.collection('users').doc(userId).set(data, SetOptions(merge: true));
  }

  Future<DocumentSnapshot> getUserProfile(String userId) {
    return _db.collection('users').doc(userId).get();
  }

  // --- Medicamentos ---

  Stream<List<Tratamiento>> getMedicamentosStream(String userId) {
    final stream = _db
        .collection('medicamentos')
        .doc(userId)
        .collection('userMedicamentos')
        .snapshots();

    // Usamos .map() para transformar el Stream de QuerySnapshot a un Stream de List<Tratamiento>
    return stream.map((snapshot) {
      return snapshot.docs.map((doc) {
        // Por cada documento, usamos nuestro factory constructor para crear un objeto Tratamiento
        return Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      }).toList(); // Convertimos el resultado en una lista
    });
  }

  Future<DocumentReference> saveMedicamento({
    required String userId,
    required String nombreMedicamento,
    required String presentacion,
    required String duracion,
    required TimeOfDay horaPrimeraDosis,
    required String intervaloDosis,
    required int prescriptionAlarmId,
    required DateTime fechaInicioTratamiento,
    required DateTime fechaFinTratamiento,
    required String notas,
  }) {

    // Generamos el mapa inicial de dosis con estado 'pendiente'
    final tratamientoService = TratamientoService();
    final tempTratamiento = Tratamiento(
        id: '',
        nombreMedicamento: nombreMedicamento,
        presentacion: presentacion,
        duracion: duracion,
        horaPrimeraDosis: '${horaPrimeraDosis.hour}:${horaPrimeraDosis.minute}',
        intervaloDosis: intervaloDosis,
        prescriptionAlarmId: prescriptionAlarmId,
        fechaInicioTratamiento: fechaInicioTratamiento,
        fechaFinTratamiento: fechaFinTratamiento);

    final List<DateTime> todasLasDosis = tratamientoService.generarDosisTotales(tempTratamiento);
    final Map<String, String> doseStatusMap = {
      for (var dosis in todasLasDosis)
        dosis.toIso8601String(): DoseStatus.pendiente.toString().split('.').last
    };

    return _db.collection('medicamentos').doc(userId).collection('userMedicamentos').add({
      'nombreMedicamento': nombreMedicamento,
      'presentacion': presentacion,
      'duracion': duracion,
      'horaPrimeraDosis': '${horaPrimeraDosis.hour}:${horaPrimeraDosis.minute}',
      'intervaloDosis': intervaloDosis,
      'prescriptionAlarmId': prescriptionAlarmId,
      'fechaInicioTratamiento': Timestamp.fromDate(fechaInicioTratamiento),
      'fechaFinTratamiento': Timestamp.fromDate(fechaFinTratamiento),
      'skippedDoses': [],
      'notas': notas,
      'doseStatus': doseStatusMap,
    });
  }

  Future<void> deleteTratamiento(String userId, String docId) {
    return _db.collection('medicamentos').doc(userId).collection('userMedicamentos').doc(docId).delete();
  }
  
  DocumentReference getMedicamentoDocRef(String userId, String docId) {
    return _db.collection('medicamentos').doc(userId).collection('userMedicamentos').doc(docId);
  }
  // NUEVO MÉTODO para actualizar el estado de una dosis específica
  Future<void> updateDoseStatus(String userId, String docId, DateTime doseTime, DoseStatus newStatus) async {
    final docRef = getMedicamentoDocRef(userId, docId);
    debugPrint("Attempting to robustly update status for doc: ${docRef.path}");

    try {
      // Usamos una transacción para garantizar la consistencia de los datos
      await _db.runTransaction((transaction) async {
        // 1. Leer el documento dentro de la transacción.
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          debugPrint("ERROR: Document not found in transaction. Cannot update.");
          return;
        }

        // 2. Crear el objeto Tratamiento a partir de los datos.
        final tratamiento = Tratamiento.fromFirestore(snapshot as DocumentSnapshot<Map<String, dynamic>>);

        // 3. Modificar el mapa de estados en la memoria local.
        final updatedDoseStatus = Map<String, DoseStatus>.from(tratamiento.doseStatus);
        final doseKey = doseTime.toIso8601String();
        updatedDoseStatus[doseKey] = newStatus;

        // 4. Convertimos el mapa de Enum a un mapa de String para guardarlo en Firestore.
        final mapToSave = updatedDoseStatus.map(
          (key, value) => MapEntry(key, value.toString().split('.').last),
        );

        // 5. Actualizamos el campo 'doseStatus' completo en el documento.
        transaction.update(docRef, {'doseStatus': mapToSave});
      });

      debugPrint("SUCCESS: Document status updated via transaction.");
    } catch (e) {
      debugPrint("Firebase transaction error during updateDoseStatus: $e");
    }
  }
}