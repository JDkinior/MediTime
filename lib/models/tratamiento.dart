// lib/models/tratamiento.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Importante para debugPrint

/// Enum para representar el estado de una dosis.
enum DoseStatus { pendiente, notificada, tomada, omitida, aplazada }

/// Convierte un String a DoseStatus.
/// Usado al leer datos desde Firestore.
DoseStatus doseStatusFromString(String status) {
  return DoseStatus.values.firstWhere(
    (e) => e.toString().split('.').last == status,
    orElse: () => DoseStatus.pendiente, // Valor por defecto
  );
}

/// Representa un tratamiento médico completo.
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

  /// Un mapa que almacena el estado de cada dosis individual.
  /// La clave es la fecha de la dosis en formato ISO 8601, y el valor es su [DoseStatus].
  final Map<String, DoseStatus> doseStatus;

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
    this.doseStatus = const {},
  });

  /// Crea una instancia de [Tratamiento] a partir de un [DocumentSnapshot] de Firestore.
  /// Realiza un parseo seguro de los datos para evitar errores en tiempo de ejecución.
  factory Tratamiento.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    final List<dynamic> skippedDosesRaw = data['skippedDoses'] ?? [];
    final List<DateTime> skippedDoses = skippedDosesRaw
        .map((ts) => (ts as Timestamp).toDate())
        .toList();
    
    // --- INICIO DE LA MODIFICACIÓN: Lógica de procesamiento robusta ---
    final Map<String, dynamic> rawDoseStatus = data['doseStatus'] ?? {};
    final Map<String, DoseStatus> processedDoseStatus = {};

    // Iteramos de forma segura sobre el mapa
    rawDoseStatus.forEach((key, value) {
      // Comprobamos si el valor es del tipo que esperamos (String)
      if (value is String) {
        processedDoseStatus[key] = doseStatusFromString(value);
      } else {
        // Si no es un String, lo ignoramos y mostramos un mensaje de depuración.
        // Esto evita que la aplicación se bloquee.
        debugPrint("Dato de 'doseStatus' inesperado y omitido. Clave: $key, Tipo: ${value.runtimeType}");
      }
    });
    // --- FIN DE LA MODIFICACIÓN ---

    final inicioTimestamp = data['fechaInicioTratamiento'] as Timestamp?;
    final finTimestamp = data['fechaFinTratamiento'] as Timestamp?;
    final fechaInicio = inicioTimestamp?.toDate() ?? DateTime.now();
    final fechaFin = finTimestamp?.toDate() ?? DateTime.now();

    return Tratamiento(
      id: doc.id,
      nombreMedicamento: data['nombreMedicamento'] ?? 'N/A',
      presentacion: data['presentacion'] ?? 'N/A',
      duracion: data['duracion'] ?? '0',
      horaPrimeraDosis: data['horaPrimeraDosis'] ?? '00:00',
      intervaloDosis: data['intervaloDosis'] ?? '0',
      prescriptionAlarmId: data['prescriptionAlarmId'] ?? 0,
      fechaInicioTratamiento: fechaInicio,
      fechaFinTratamiento: fechaFin,
      skippedDoses: skippedDoses,
      notas: data['notas'] ?? '',
      doseStatus: processedDoseStatus, // Usamos el mapa procesado de forma segura
    );
  }
}