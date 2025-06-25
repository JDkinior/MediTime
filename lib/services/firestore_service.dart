// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  Stream<QuerySnapshot> getMedicamentosStream(String userId) {
    return _db.collection('medicamentos').doc(userId).collection('userMedicamentos').snapshots();
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