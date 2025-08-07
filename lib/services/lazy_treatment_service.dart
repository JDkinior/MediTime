// lib/services/lazy_treatment_service.dart
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/lazy_treatment.dart';
import 'package:meditime/services/firestore_service.dart';

/// Servicio para manejar tratamientos con carga lazy
class LazyTreatmentService {
  final FirestoreService _firestoreService;
  
  // Cache de tratamientos lazy
  final Map<String, LazyTreatment> _lazyTreatments = {};
  
  LazyTreatmentService(this._firestoreService);

  /// Obtiene un tratamiento lazy, creándolo si no existe
  LazyTreatment getLazyTreatment(Tratamiento treatment) {
    if (!_lazyTreatments.containsKey(treatment.id)) {
      _lazyTreatments[treatment.id] = LazyTreatment(treatment);
    }
    return _lazyTreatments[treatment.id]!;
  }

  /// Obtiene dosis para el calendario de un mes específico
  Map<String, List<LazyTreatment>> getDosesForCalendarMonth(
    List<Tratamiento> treatments, 
    DateTime month
  ) {
    final monthDoses = <String, List<LazyTreatment>>{};
    
    for (final treatment in treatments) {
      final lazyTreatment = getLazyTreatment(treatment);
      final doses = lazyTreatment.getDosesForMonth(month);
      
      for (final doseKey in doses.keys) {
        final doseDate = DateTime.tryParse(doseKey);
        if (doseDate != null) {
          final dayKey = '${doseDate.year}-${doseDate.month.toString().padLeft(2, '0')}-${doseDate.day.toString().padLeft(2, '0')}';
          
          if (!monthDoses.containsKey(dayKey)) {
            monthDoses[dayKey] = [];
          }
          
          // Solo agregamos si no está ya en la lista para este día
          if (!monthDoses[dayKey]!.any((lt) => lt.baseTreatment.id == treatment.id)) {
            monthDoses[dayKey]!.add(lazyTreatment);
          }
        }
      }
    }
    
    return monthDoses;
  }

  /// Obtiene las dosis detalladas para un día específico
  List<Map<String, dynamic>> getDetailedDosesForDay(
    List<Tratamiento> treatments, 
    DateTime day
  ) {
    final dayDoses = <Map<String, dynamic>>[];
    
    for (final treatment in treatments) {
      final lazyTreatment = getLazyTreatment(treatment);
      final doses = lazyTreatment.getDosesForDay(day);
      
      for (final doseTime in doses) {
        final doseKey = doseTime.toIso8601String();
        final status = lazyTreatment.baseTreatment.doseStatus[doseKey] ?? DoseStatus.pendiente;
        
        dayDoses.add({
          'treatment': treatment,
          'lazyTreatment': lazyTreatment,
          'doseTime': doseTime,
          'status': status,
        });
      }
    }
    
    // Ordenamos por hora
    dayDoses.sort((a, b) => (a['doseTime'] as DateTime).compareTo(b['doseTime'] as DateTime));
    
    return dayDoses;
  }

  /// Actualiza el estado de una dosis
  Future<void> updateDoseStatus(
    String userId,
    String treatmentId, 
    DateTime doseTime, 
    DoseStatus newStatus
  ) async {
    // Actualizamos en el cache lazy
    if (_lazyTreatments.containsKey(treatmentId)) {
      _lazyTreatments[treatmentId]!.updateDoseStatus(doseTime, newStatus);
    }
    
    // Actualizamos en Firestore
    await _firestoreService.updateDoseStatus(
      userId,
      treatmentId, 
      doseTime, 
      newStatus
    );
  }

  /// Limpia el cache para liberar memoria
  void clearCache() {
    for (final lazyTreatment in _lazyTreatments.values) {
      lazyTreatment.clearCache();
    }
    _lazyTreatments.clear();
  }

  /// Limpia el cache de un tratamiento específico
  void clearTreatmentCache(String treatmentId) {
    if (_lazyTreatments.containsKey(treatmentId)) {
      _lazyTreatments[treatmentId]!.clearCache();
      _lazyTreatments.remove(treatmentId);
    }
  }

  /// Inicializa dosis para un tratamiento si no existen en Firestore
  Future<void> initializeDosesIfNeeded(String userId, Tratamiento treatment) async {
    // Solo inicializamos si el tratamiento no tiene dosis en su mapa
    if (treatment.doseStatus.isEmpty) {
      final lazyTreatment = getLazyTreatment(treatment);
      
      // Generamos dosis para los próximos 30 días
      final now = DateTime.now();
      final futureDate = now.add(const Duration(days: 30));
      
      final doses = lazyTreatment.getDosesForDateRange(
        treatment.fechaInicioTratamiento.isAfter(now) 
            ? treatment.fechaInicioTratamiento 
            : now,
        futureDate.isBefore(treatment.fechaFinTratamiento) 
            ? futureDate 
            : treatment.fechaFinTratamiento,
      );
      
      // Actualizamos en Firestore con las dosis iniciales
      if (doses.isNotEmpty) {
        final doseStatusMap = doses.map(
          (key, value) => MapEntry(key, value.toString().split('.').last),
        );
        
        await _firestoreService.updateTreatmentDoses(userId, treatment.id, doseStatusMap);
      }
    }
  }

  /// Obtiene estadísticas de memoria del cache
  Map<String, dynamic> getCacheStats() {
    int totalCachedDoses = 0;
    int indefiniteTreatments = 0;
    
    for (final lazyTreatment in _lazyTreatments.values) {
      totalCachedDoses += lazyTreatment.cachedDosesCount;
      if (lazyTreatment.isIndefinite) {
        indefiniteTreatments++;
      }
    }
    
    return {
      'totalLazyTreatments': _lazyTreatments.length,
      'totalCachedDoses': totalCachedDoses,
      'indefiniteTreatments': indefiniteTreatments,
    };
  }

  /// Optimiza el cache eliminando datos antiguos
  void optimizeCache() {
    final now = DateTime.now();
    final oneMonthAgo = now.subtract(const Duration(days: 30));
    
    for (final lazyTreatment in _lazyTreatments.values) {
      // Si el tratamiento terminó hace más de un mes, limpiamos su cache
      if (lazyTreatment.baseTreatment.fechaFinTratamiento.isBefore(oneMonthAgo)) {
        lazyTreatment.clearCache();
      }
    }
  }
}