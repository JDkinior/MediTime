// lib/models/tratamiento.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meditime/core/constants.dart';

/// Enum para representar el estado de una dosis.
enum DoseStatus { 
  pendiente, 
  notificada, 
  tomada, 
  omitida, 
  aplazada;
  
  /// Convierte el enum a string para almacenamiento
  String get value => toString().split('.').last;
  
  /// Crea un DoseStatus desde un string
  static DoseStatus fromString(String status) {
    return DoseStatus.values.firstWhere(
      (e) => e.value == status,
      orElse: () => DoseStatus.pendiente,
    );
  }
  
  /// Obtiene el color asociado al estado
  Color get color {
    switch (this) {
      case DoseStatus.pendiente:
        return Colors.grey;
      case DoseStatus.notificada:
        return Colors.blue;
      case DoseStatus.tomada:
        return Colors.green;
      case DoseStatus.omitida:
        return Colors.red;
      case DoseStatus.aplazada:
        return Colors.orange;
    }
  }
  
  /// Obtiene el texto descriptivo del estado
  String get displayName {
    switch (this) {
      case DoseStatus.pendiente:
        return 'Pendiente';
      case DoseStatus.notificada:
        return 'Notificada';
      case DoseStatus.tomada:
        return 'Tomada';
      case DoseStatus.omitida:
        return 'Omitida';
      case DoseStatus.aplazada:
        return 'Aplazada';
    }
  }
}

/// Convierte un String a DoseStatus.
/// Usado al leer datos desde Firestore.
@Deprecated('Use DoseStatus.fromString instead')
DoseStatus doseStatusFromString(String status) {
  return DoseStatus.fromString(status);
}

/// Representa un tratamiento médico completo con validación y tipos mejorados.
@immutable
class Tratamiento {
  final String id;
  final String nombreMedicamento;
  final String presentacion;
  final String duracion;
  final TimeOfDay horaPrimeraDosis;
  final Duration intervaloDosis;
  final int prescriptionAlarmId;
  final DateTime fechaInicioTratamiento;
  final DateTime fechaFinTratamiento;
  final List<DateTime> skippedDoses;
  final String notas;

  /// Un mapa que almacena el estado de cada dosis individual.
  /// La clave es la fecha de la dosis en formato ISO 8601, y el valor es su [DoseStatus].
  final Map<String, DoseStatus> doseStatus;

  const Tratamiento({
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

  /// Validates the treatment data
  bool get isValid {
    return nombreMedicamento.isNotEmpty &&
           presentacion.isNotEmpty &&
           fechaFinTratamiento.isAfter(fechaInicioTratamiento) &&
           intervaloDosis.inHours > 0;
  }

  /// Gets the total number of doses for this treatment
  int get totalDoses {
    final totalDuration = fechaFinTratamiento.difference(fechaInicioTratamiento);
    return (totalDuration.inHours / intervaloDosis.inHours).ceil();
  }

  /// Gets the number of completed doses
  int get completedDoses {
    return doseStatus.values.where((status) => status == DoseStatus.tomada).length;
  }

  /// Gets the adherence percentage (0.0 to 1.0)
  double get adherencePercentage {
    if (totalDoses == 0) return 0.0;
    return completedDoses / totalDoses;
  }

  /// Creates a copy of this treatment with updated values
  Tratamiento copyWith({
    String? id,
    String? nombreMedicamento,
    String? presentacion,
    String? duracion,
    TimeOfDay? horaPrimeraDosis,
    Duration? intervaloDosis,
    int? prescriptionAlarmId,
    DateTime? fechaInicioTratamiento,
    DateTime? fechaFinTratamiento,
    List<DateTime>? skippedDoses,
    String? notas,
    Map<String, DoseStatus>? doseStatus,
  }) {
    return Tratamiento(
      id: id ?? this.id,
      nombreMedicamento: nombreMedicamento ?? this.nombreMedicamento,
      presentacion: presentacion ?? this.presentacion,
      duracion: duracion ?? this.duracion,
      horaPrimeraDosis: horaPrimeraDosis ?? this.horaPrimeraDosis,
      intervaloDosis: intervaloDosis ?? this.intervaloDosis,
      prescriptionAlarmId: prescriptionAlarmId ?? this.prescriptionAlarmId,
      fechaInicioTratamiento: fechaInicioTratamiento ?? this.fechaInicioTratamiento,
      fechaFinTratamiento: fechaFinTratamiento ?? this.fechaFinTratamiento,
      skippedDoses: skippedDoses ?? this.skippedDoses,
      notas: notas ?? this.notas,
      doseStatus: doseStatus ?? this.doseStatus,
    );
  }

  /// Converts to Map for Firestore storage
  Map<String, dynamic> toFirestoreMap() {
    return {
      AppConstants.nombreMedicamentoField: nombreMedicamento,
      AppConstants.presentacionField: presentacion,
      AppConstants.duracionField: duracion,
      AppConstants.horaPrimeraDosisField: '${horaPrimeraDosis.hour}:${horaPrimeraDosis.minute}',
      AppConstants.intervaloDosisField: intervaloDosis.inHours.toString(),
      AppConstants.prescriptionAlarmIdField: prescriptionAlarmId,
      AppConstants.fechaInicioTratamientoField: Timestamp.fromDate(fechaInicioTratamiento),
      AppConstants.fechaFinTratamientoField: Timestamp.fromDate(fechaFinTratamiento),
      AppConstants.skippedDosesField: skippedDoses.map((date) => Timestamp.fromDate(date)).toList(),
      AppConstants.notasField: notas,
      AppConstants.doseStatusField: doseStatus.map(
        (key, value) => MapEntry(key, value.value),
      ),
    };
  }

  /// Crea una instancia de [Tratamiento] a partir de un [DocumentSnapshot] de Firestore.
  /// Realiza un parseo seguro de los datos para evitar errores en tiempo de ejecución.
  factory Tratamiento.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    // Parse skipped doses safely
    final List<dynamic> skippedDosesRaw = data[AppConstants.skippedDosesField] ?? [];
    final List<DateTime> skippedDoses = skippedDosesRaw
        .map((ts) => (ts as Timestamp).toDate())
        .toList();
    
    // Parse dose status safely
    final Map<String, dynamic> rawDoseStatus = data[AppConstants.doseStatusField] ?? {};
    final Map<String, DoseStatus> processedDoseStatus = {};

    rawDoseStatus.forEach((key, value) {
      if (value is String) {
        processedDoseStatus[key] = DoseStatus.fromString(value);
      } else {
        debugPrint("Unexpected 'doseStatus' data type ignored. Key: $key, Type: ${value.runtimeType}");
      }
    });

    // Parse timestamps safely
    final inicioTimestamp = data[AppConstants.fechaInicioTratamientoField] as Timestamp?;
    final finTimestamp = data[AppConstants.fechaFinTratamientoField] as Timestamp?;
    final fechaInicio = inicioTimestamp?.toDate() ?? DateTime.now();
    final fechaFin = finTimestamp?.toDate() ?? DateTime.now();

    // Parse time of day from string
    final timeString = data[AppConstants.horaPrimeraDosisField] ?? AppConstants.defaultTimeFormat;
    final timeParts = timeString.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;
    final timeOfDay = TimeOfDay(hour: hour, minute: minute);

    // Parse interval duration from string
    final intervalString = data[AppConstants.intervaloDosisField] ?? AppConstants.defaultDuration;
    final intervalHours = int.tryParse(intervalString) ?? 0;
    final intervalDuration = Duration(hours: intervalHours);

    return Tratamiento(
      id: doc.id,
      nombreMedicamento: data[AppConstants.nombreMedicamentoField] ?? AppConstants.defaultMedicationName,
      presentacion: data[AppConstants.presentacionField] ?? AppConstants.defaultPresentation,
      duracion: data[AppConstants.duracionField] ?? AppConstants.defaultDuration,
      horaPrimeraDosis: timeOfDay,
      intervaloDosis: intervalDuration,
      prescriptionAlarmId: data[AppConstants.prescriptionAlarmIdField] ?? AppConstants.defaultAlarmId,
      fechaInicioTratamiento: fechaInicio,
      fechaFinTratamiento: fechaFin,
      skippedDoses: skippedDoses,
      notas: data[AppConstants.notasField] ?? AppConstants.defaultNotes,
      doseStatus: processedDoseStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tratamiento &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nombreMedicamento == other.nombreMedicamento &&
          presentacion == other.presentacion &&
          duracion == other.duracion &&
          horaPrimeraDosis == other.horaPrimeraDosis &&
          intervaloDosis == other.intervaloDosis &&
          prescriptionAlarmId == other.prescriptionAlarmId &&
          fechaInicioTratamiento == other.fechaInicioTratamiento &&
          fechaFinTratamiento == other.fechaFinTratamiento;

  @override
  int get hashCode =>
      id.hashCode ^
      nombreMedicamento.hashCode ^
      presentacion.hashCode ^
      duracion.hashCode ^
      horaPrimeraDosis.hashCode ^
      intervaloDosis.hashCode ^
      prescriptionAlarmId.hashCode ^
      fechaInicioTratamiento.hashCode ^
      fechaFinTratamiento.hashCode;

  @override
  String toString() {
    return 'Tratamiento{id: $id, nombreMedicamento: $nombreMedicamento, presentacion: $presentacion, adherence: ${(adherencePercentage * 100).toStringAsFixed(1)}%}';
  }
}