import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MedicamentosData {
  static const String collectionName = 'medicamentos';

  // Obtener el ID del usuario actual
  static String? getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

// Guardar datos de la receta en Firestore
static Future<void> saveMedicamentoData({
  required String nombreMedicamento,
  required String presentacion,
  required String frecuencia,
  String? vecesPorDia,
  required TimeOfDay horaPrimeraDosis,
  required String intervaloDosis,
}) async {
  final userId = getCurrentUserId();
  if (userId == null) {
    throw Exception('Usuario no autenticado');
  }

  final firestore = FirebaseFirestore.instance;
  // Generar un documento con un ID único automáticamente
  await firestore.collection(collectionName).doc(userId).collection('userMedicamentos').add({
    'nombreMedicamento': nombreMedicamento,
    'presentacion': presentacion,
    'frecuencia': frecuencia,
    'vecesPorDia': vecesPorDia,
    'horaPrimeraDosis': '${horaPrimeraDosis.hour}:${horaPrimeraDosis.minute}',
    'intervaloDosis': intervaloDosis,
  });
}


  // Cargar datos de la receta desde Firestore
  static Future<Map<String, dynamic>?> loadMedicamentoData(String nombreMedicamento) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      throw Exception('Usuario no autenticado');
    }

    final firestore = FirebaseFirestore.instance;
    final doc = await firestore.collection(collectionName).doc(userId).collection('userMedicamentos').doc(nombreMedicamento).get();
    return doc.data();
  }

  // Obtener el nombre del medicamento
  static Future<String?> obtenerNombreMedicamento(String nombreMedicamento) async {
    final data = await loadMedicamentoData(nombreMedicamento);
    return data?['nombreMedicamento'];
  }

  // Obtener la hora de la primera dosis en formato TimeOfDay
  static Future<TimeOfDay?> obtenerHoraPrimeraDosis(String nombreMedicamento) async {
    final data = await loadMedicamentoData(nombreMedicamento);
    final horaString = data?['horaPrimeraDosis'];
    if (horaString == null) {
      return null;
    }
    final parts = horaString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  }

  // Obtener el número de veces por día
  static Future<String?> obtenerVecesPorDia(String nombreMedicamento) async {
    final data = await loadMedicamentoData(nombreMedicamento);
    return data?['vecesPorDia'];
  }

  // Borrar datos de la receta médica
  static Future<void> clearMedicamentoData(String nombreMedicamento) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      throw Exception('Usuario no autenticado');
    }

    final firestore = FirebaseFirestore.instance;
    await firestore.collection(collectionName).doc(userId).collection('userMedicamentos').doc(nombreMedicamento).delete();
  }
}
