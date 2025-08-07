// lib/models/treatment_form_data.dart
import 'package:flutter/material.dart';

/// Enum para las unidades de duración del tratamiento
enum DurationUnit {
  days('Días'),
  months('Meses'),
  years('Años');

  const DurationUnit(this.displayName);
  final String displayName;

  /// Convierte la duración a días
  int toDays(int value) {
    switch (this) {
      case DurationUnit.days:
        return value;
      case DurationUnit.months:
        return value * 30;
      case DurationUnit.years:
        return value * 365;
    }
  }

  /// Obtiene el texto descriptivo para la duración
  String getDisplayText(int value) {
    switch (this) {
      case DurationUnit.days:
        return '$value día${value > 1 ? 's' : ''}';
      case DurationUnit.months:
        return '$value mes${value > 1 ? 'es' : ''}';
      case DurationUnit.years:
        return '$value año${value > 1 ? 's' : ''}';
    }
  }
}

/// Modelo que representa los datos del formulario de tratamiento
class TreatmentFormData {
  String nombreMedicamento;
  String presentacion;
  TimeOfDay horaPrimeraDosis;
  int intervaloDosis; // en horas
  int duracionNumero;
  DurationUnit duracionUnidad;
  bool esIndefinido;
  String notas;

  TreatmentFormData({
    this.nombreMedicamento = '',
    this.presentacion = '',
    TimeOfDay? horaPrimeraDosis,
    this.intervaloDosis = 8,
    this.duracionNumero = 1,
    this.duracionUnidad = DurationUnit.days,
    this.esIndefinido = false,
    this.notas = '',
  }) : horaPrimeraDosis = horaPrimeraDosis ?? TimeOfDay.now();

  /// Calcula la duración total en días
  int get duracionEnDias {
    if (esIndefinido) {
      // Para tratamientos indefinidos, usamos un valor más pequeño
      // El sistema lazy se encargará de generar dosis bajo demanda
      return 90; // Solo 3 meses iniciales
    }
    return duracionUnidad.toDays(duracionNumero);
  }

  /// Calcula el número de dosis por día
  int get dosisPerDay {
    if (intervaloDosis <= 0) return 0;
    return (24 / intervaloDosis).round();
  }

  /// Calcula el total de dosis del tratamiento
  int get totalDoses {
    if (esIndefinido) return -1; // Indefinido
    return dosisPerDay * duracionEnDias;
  }

  /// Obtiene el texto descriptivo de la duración
  String get duracionText {
    if (esIndefinido) return "Indefinido";
    return duracionUnidad.getDisplayText(duracionNumero);
  }

  /// Calcula la fecha de fin del tratamiento
  DateTime calculateEndDate(DateTime startDate) {
    if (esIndefinido) {
      return startDate.add(Duration(days: duracionEnDias));
    }
    return startDate.add(Duration(days: duracionEnDias));
  }

  /// Genera los horarios de las dosis del día
  List<TimeOfDay> generateDailySchedule() {
    if (intervaloDosis <= 0) return [];

    final List<TimeOfDay> schedule = [];
    DateTime currentTime = DateTime(
      2020,
      1,
      1,
      horaPrimeraDosis.hour,
      horaPrimeraDosis.minute,
    );

    for (int i = 0; i < dosisPerDay; i++) {
      schedule.add(TimeOfDay.fromDateTime(currentTime));
      currentTime = currentTime.add(Duration(hours: intervaloDosis));
    }

    return schedule;
  }

  /// Valida si los datos del formulario son válidos
  bool get isValid {
    return nombreMedicamento.isNotEmpty &&
        presentacion.isNotEmpty &&
        intervaloDosis > 0 &&
        (esIndefinido || duracionNumero > 0);
  }

  /// Crea una copia con valores actualizados
  TreatmentFormData copyWith({
    String? nombreMedicamento,
    String? presentacion,
    TimeOfDay? horaPrimeraDosis,
    int? intervaloDosis,
    int? duracionNumero,
    DurationUnit? duracionUnidad,
    bool? esIndefinido,
    String? notas,
  }) {
    return TreatmentFormData(
      nombreMedicamento: nombreMedicamento ?? this.nombreMedicamento,
      presentacion: presentacion ?? this.presentacion,
      horaPrimeraDosis: horaPrimeraDosis ?? this.horaPrimeraDosis,
      intervaloDosis: intervaloDosis ?? this.intervaloDosis,
      duracionNumero: duracionNumero ?? this.duracionNumero,
      duracionUnidad: duracionUnidad ?? this.duracionUnidad,
      esIndefinido: esIndefinido ?? this.esIndefinido,
      notas: notas ?? this.notas,
    );
  }
}
