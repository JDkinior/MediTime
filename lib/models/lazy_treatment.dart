// lib/models/lazy_treatment.dart
import 'package:meditime/models/tratamiento.dart';

/// Modelo optimizado para tratamientos que genera dosis bajo demanda
class LazyTreatment {
  final Tratamiento baseTreatment;
  
  // Cache para dosis generadas
  final Map<String, DoseStatus> _cachedDoses = {};
  
  // Rango de fechas para el cual hemos generado dosis
  DateTime? _cacheStartDate;
  DateTime? _cacheEndDate;
  
  LazyTreatment(this.baseTreatment);

  /// Genera dosis para un rango específico de fechas
  Map<String, DoseStatus> getDosesForDateRange(DateTime startDate, DateTime endDate) {
    // Si el rango solicitado está fuera del cache, generamos nuevas dosis
    if (_cacheStartDate == null || 
        startDate.isBefore(_cacheStartDate!) || 
        endDate.isAfter(_cacheEndDate!)) {
      _generateDosesForRange(startDate, endDate);
    }
    
    // Filtramos solo las dosis del rango solicitado
    final filteredDoses = <String, DoseStatus>{};
    for (final entry in _cachedDoses.entries) {
      final doseDate = DateTime.tryParse(entry.key);
      if (doseDate != null && 
          !doseDate.isBefore(startDate) && 
          !doseDate.isAfter(endDate)) {
        filteredDoses[entry.key] = entry.value;
      }
    }
    
    return filteredDoses;
  }

  /// Genera dosis para un mes específico (optimizado para calendario)
  Map<String, DoseStatus> getDosesForMonth(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    return getDosesForDateRange(startOfMonth, endOfMonth);
  }

  /// Genera dosis para una semana específica
  Map<String, DoseStatus> getDosesForWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return getDosesForDateRange(weekStart, weekEnd);
  }

  /// Obtiene las dosis para un día específico
  List<DateTime> getDosesForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    
    final doses = <DateTime>[];
    DateTime currentDose = baseTreatment.fechaInicioTratamiento;
    
    // Solo generamos las dosis para este día específico
    while (currentDose.isBefore(baseTreatment.fechaFinTratamiento)) {
      if (!currentDose.isBefore(dayStart) && currentDose.isBefore(dayEnd)) {
        doses.add(currentDose);
      }
      
      // Si ya pasamos el día, no necesitamos seguir
      if (currentDose.isAfter(dayEnd)) break;
      
      currentDose = currentDose.add(baseTreatment.intervaloDosis);
    }
    
    return doses;
  }

  /// Genera dosis para un rango específico y las almacena en cache
  void _generateDosesForRange(DateTime startDate, DateTime endDate) {
    // Expandimos el cache para incluir el nuevo rango
    final newCacheStart = _cacheStartDate == null 
        ? startDate 
        : DateTime.fromMillisecondsSinceEpoch(
            [_cacheStartDate!.millisecondsSinceEpoch, startDate.millisecondsSinceEpoch].reduce((a, b) => a < b ? a : b)
          );
    
    final newCacheEnd = _cacheEndDate == null 
        ? endDate 
        : DateTime.fromMillisecondsSinceEpoch(
            [_cacheEndDate!.millisecondsSinceEpoch, endDate.millisecondsSinceEpoch].reduce((a, b) => a > b ? a : b)
          );

    // Generamos dosis solo para el nuevo rango
    DateTime currentDose = baseTreatment.fechaInicioTratamiento;
    
    while (currentDose.isBefore(baseTreatment.fechaFinTratamiento) && 
           currentDose.isBefore(newCacheEnd.add(const Duration(days: 1)))) {
      
      if (!currentDose.isBefore(newCacheStart) && !currentDose.isAfter(newCacheEnd)) {
        final doseKey = currentDose.toIso8601String();
        
        // Solo agregamos si no existe en el cache
        if (!_cachedDoses.containsKey(doseKey)) {
          // Verificamos si existe en el tratamiento base
          _cachedDoses[doseKey] = baseTreatment.doseStatus[doseKey] ?? DoseStatus.pendiente;
        }
      }
      
      currentDose = currentDose.add(baseTreatment.intervaloDosis);
    }
    
    _cacheStartDate = newCacheStart;
    _cacheEndDate = newCacheEnd;
  }

  /// Actualiza el estado de una dosis específica
  void updateDoseStatus(DateTime doseTime, DoseStatus status) {
    final doseKey = doseTime.toIso8601String();
    _cachedDoses[doseKey] = status;
  }

  /// Limpia el cache (útil para liberar memoria)
  void clearCache() {
    _cachedDoses.clear();
    _cacheStartDate = null;
    _cacheEndDate = null;
  }

  /// Obtiene el número de dosis en cache
  int get cachedDosesCount => _cachedDoses.length;

  /// Verifica si el tratamiento es indefinido
  bool get isIndefinite {
    final duration = baseTreatment.fechaFinTratamiento.difference(baseTreatment.fechaInicioTratamiento);
    return duration.inDays > 1000; // Consideramos indefinido si es más de ~3 años
  }

  /// Obtiene estadísticas básicas sin generar todas las dosis
  Map<String, dynamic> getBasicStats() {
    final now = DateTime.now();
    final treatmentDuration = baseTreatment.fechaFinTratamiento.difference(baseTreatment.fechaInicioTratamiento);
    final daysSinceStart = now.difference(baseTreatment.fechaInicioTratamiento).inDays;
    
    // Estimamos las dosis totales y completadas sin generarlas todas
    final estimatedTotalDoses = isIndefinite 
        ? -1 // Indefinido
        : (treatmentDuration.inHours / baseTreatment.intervaloDosis.inHours).ceil();
    
    final completedDoses = _cachedDoses.values.where((status) => status == DoseStatus.tomada).length;
    
    return {
      'estimatedTotalDoses': estimatedTotalDoses,
      'completedDoses': completedDoses,
      'daysSinceStart': daysSinceStart,
      'isIndefinite': isIndefinite,
      'cachedDosesCount': cachedDosesCount,
    };
  }
}