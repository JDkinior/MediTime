// lib/models/tratamiento.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Tratamiento {
  final String id;
  final String nombreMedicamento;
  final String presentacion;
  final String duracion;
  final String horaPrimeraDosis;
  final String intervaloDosis;
  final int prescriptionAlarmId;
  final DateTime fechaInicioTratamiento;
  final DateTime fechaFinTratamiento;
  final List<DateTime> skippedDoses;
  final String notas;

  Tratamiento({
    required this.id,
    required this.nombreMedicamento,
    required this.presentacion,
    required this.duracion,
    required this.horaPrimeraDosis,
    required this.intervaloDosis,
    required this.prescriptionAlarmId,
    required this.fechaInicioTratamiento,
    required this.fechaFinTratamiento,
    this.skippedDoses = const [],
    this.notas = '',
  });

  /// Factory constructor para crear una instancia de Tratamiento
  /// a partir de un documento de Firestore.
  factory Tratamiento.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    // Manejo seguro de la lista de dosis omitidas
    final List<dynamic> skippedDosesRaw = data['skippedDoses'] ?? [];
    final List<DateTime> skippedDoses = skippedDosesRaw
        .map((ts) => (ts as Timestamp).toDate())
        .toList();

    return Tratamiento(
      id: doc.id,
      nombreMedicamento: data['nombreMedicamento'] ?? 'N/A',
      presentacion: data['presentacion'] ?? 'N/A',
      duracion: data['duracion'] ?? '0',
      horaPrimeraDosis: data['horaPrimeraDosis'] ?? '00:00',
      intervaloDosis: data['intervaloDosis'] ?? '0',
      prescriptionAlarmId: data['prescriptionAlarmId'] ?? 0,
      fechaInicioTratamiento: (data['fechaInicioTratamiento'] as Timestamp).toDate(),
      fechaFinTratamiento: (data['fechaFinTratamiento'] as Timestamp).toDate(),
      skippedDoses: skippedDoses,
      notas: data['notas'] ?? '',
    );
  }
}