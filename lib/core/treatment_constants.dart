// lib/core/treatment_constants.dart

/// Constantes relacionadas con tratamientos
class TreatmentConstants {
  /// Duración inicial para tratamientos indefinidos (optimizada)
  /// Solo se crean dosis para este período inicial, luego se generan bajo demanda
  static const int initialIndefiniteDurationDays = 90; // 3 meses
  
  /// Duración máxima para tratamientos definidos
  static const int maxDefiniteDurationDays = 3650; // 10 años
  
  /// Intervalo mínimo entre dosis en horas
  static const int minDoseIntervalHours = 1;
  
  /// Intervalo máximo entre dosis en horas
  static const int maxDoseIntervalHours = 168; // 1 semana
  
  /// Duración mínima de tratamiento en días
  static const int minTreatmentDurationDays = 1;
  
  /// Número máximo de dosis a generar de una vez (para rendimiento)
  static const int maxDosesPerBatch = 100;
  
  /// Días hacia adelante para pre-cargar en el calendario
  static const int calendarPreloadDays = 60; // 2 meses
  
  /// Días hacia atrás para mantener en cache
  static const int cacheRetentionDays = 30; // 1 mes
}