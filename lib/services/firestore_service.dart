// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meditime/models/tratamiento.dart';

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

  Future<void> saveMedicamento({
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
    });
  }

  Future<void> deleteTratamiento(String userId, String docId) {
    return _db.collection('medicamentos').doc(userId).collection('userMedicamentos').doc(docId).delete();
  }
  
  DocumentReference getMedicamentoDocRef(String userId, String docId) {
    return _db.collection('medicamentos').doc(userId).collection('userMedicamentos').doc(docId);
  }
}