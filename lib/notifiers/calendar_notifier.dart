// lib/notifiers/calendar_notifier.dart
import 'package:flutter/material.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/lazy_treatment.dart';
import 'package:meditime/services/lazy_treatment_service.dart';
import 'package:meditime/services/firestore_service.dart';

/// Notifier optimizado para el calendario que maneja carga lazy
class CalendarNotifier extends ChangeNotifier {
  final LazyTreatmentService _lazyTreatmentService;
  final FirestoreService _firestoreService;

  CalendarNotifier(this._lazyTreatmentService, this._firestoreService);

  // Estado del calendario
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  List<Tratamiento> _treatments = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Cache para el mes actual
  Map<String, List<LazyTreatment>> _currentMonthDoses = {};
  DateTime? _cachedMonth;

  // Getters
  DateTime get selectedDate => _selectedDate;
  DateTime get focusedDate => _focusedDate;
  List<Tratamiento> get treatments => _treatments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Actualiza la fecha seleccionada
  void updateSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  /// Actualiza la fecha enfocada y carga datos si es necesario
  void updateFocusedDate(DateTime date) {
    _focusedDate = date;

    // Si cambiamos de mes, cargamos los datos del nuevo mes
    if (_cachedMonth == null ||
        _cachedMonth!.year != date.year ||
        _cachedMonth!.month != date.month) {
      _loadMonthData(date);
    }

    notifyListeners();
  }

  /// Carga los tratamientos del usuario
  Future<void> loadTreatments(String userId) async {
    _setLoading(true);
    try {
      final treatmentsStream = _firestoreService.getMedicamentosStream(userId);

      await for (final treatments in treatmentsStream) {
        _treatments = treatments;

        // Recargamos los datos del mes actual
        if (_cachedMonth != null) {
          _loadMonthData(_focusedDate);
        }

        _setLoading(false);
        break; // Solo tomamos la primera emisión para la carga inicial
      }
    } catch (e) {
      _setError('Error al cargar tratamientos: $e');
    }
  }

  /// Carga los datos de un mes específico
  void _loadMonthData(DateTime month) {
    try {
      _currentMonthDoses = _lazyTreatmentService.getDosesForCalendarMonth(
        _treatments,
        month,
      );
      _cachedMonth = DateTime(month.year, month.month);
      notifyListeners();
    } catch (e) {
      _setError('Error al cargar datos del mes: $e');
    }
  }

  /// Obtiene las dosis para un día específico
  List<LazyTreatment> getDosesForDay(DateTime day) {
    final dayKey =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return _currentMonthDoses[dayKey] ?? [];
  }

  /// Obtiene las dosis detalladas para un día específico
  List<Map<String, dynamic>> getDetailedDosesForDay(DateTime day) {
    return _lazyTreatmentService.getDetailedDosesForDay(_treatments, day);
  }

  /// Verifica si un día tiene dosis programadas
  bool hasDosesForDay(DateTime day) {
    return getDosesForDay(day).isNotEmpty;
  }

  /// Actualiza el estado de una dosis
  Future<void> updateDoseStatus(
    String userId,
    String treatmentId,
    DateTime doseTime,
    DoseStatus newStatus,
  ) async {
    try {
      await _lazyTreatmentService.updateDoseStatus(
        userId,
        treatmentId,
        doseTime,
        newStatus,
      );

      // Recargamos los datos del mes actual para reflejar el cambio
      _loadMonthData(_focusedDate);
    } catch (e) {
      _setError('Error al actualizar dosis: $e');
    }
  }

  /// Optimiza el cache eliminando datos antiguos
  void optimizeCache() {
    _lazyTreatmentService.optimizeCache();
  }

  /// Obtiene estadísticas del cache
  Map<String, dynamic> getCacheStats() {
    return _lazyTreatmentService.getCacheStats();
  }

  /// Limpia todo el cache
  void clearCache() {
    _lazyTreatmentService.clearCache();
    _currentMonthDoses.clear();
    _cachedMonth = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    // Limpiamos el cache al destruir el notifier
    clearCache();
    super.dispose();
  }
}
