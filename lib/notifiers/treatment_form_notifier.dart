// lib/notifiers/treatment_form_notifier.dart
import 'package:flutter/material.dart';
import 'package:meditime/models/treatment_form_data.dart';
import 'package:meditime/services/treatment_service.dart';
import 'package:meditime/services/auth_service.dart';

/// Notifier para manejar el estado del formulario de tratamiento
class TreatmentFormNotifier extends ChangeNotifier {
  final TreatmentService _treatmentService;
  final AuthService _authService;

  TreatmentFormNotifier(this._treatmentService, this._authService);

  TreatmentFormData _formData = TreatmentFormData();
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  TreatmentFormData get formData => _formData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Lista de presentaciones disponibles
  final List<String> presentaciones = [
    'Comprimidos',
    'Grageas',
    'Cápsulas',
    'Sobres',
    'Jarabes',
    'Gotas',
    'Suspensiones',
    'Emulsiones',
  ];

  /// Actualiza el nombre del medicamento
  void updateNombreMedicamento(String nombre) {
    _formData = _formData.copyWith(nombreMedicamento: nombre);
    _clearError();
    notifyListeners();
  }

  /// Actualiza la presentación
  void updatePresentacion(String presentacion) {
    _formData = _formData.copyWith(presentacion: presentacion);
    _clearError();
    notifyListeners();
  }

  /// Actualiza la hora de la primera dosis
  void updateHoraPrimeraDosis(TimeOfDay hora) {
    _formData = _formData.copyWith(horaPrimeraDosis: hora);
    notifyListeners();
  }

  /// Actualiza el intervalo de dosis
  void updateIntervaloDosis(int intervalo) {
    _formData = _formData.copyWith(intervaloDosis: intervalo);
    _clearError();
    notifyListeners();
  }

  /// Actualiza la duración numérica
  void updateDuracionNumero(int numero) {
    _formData = _formData.copyWith(duracionNumero: numero);
    _clearError();
    notifyListeners();
  }

  /// Actualiza la unidad de duración
  void updateDuracionUnidad(DurationUnit unidad) {
    _formData = _formData.copyWith(duracionUnidad: unidad);
    notifyListeners();
  }

  /// Actualiza si es indefinido
  void updateEsIndefinido(bool esIndefinido) {
    _formData = _formData.copyWith(esIndefinido: esIndefinido);
    _clearError();
    notifyListeners();
  }

  /// Actualiza las notas
  void updateNotas(String notas) {
    _formData = _formData.copyWith(notas: notas);
    notifyListeners();
  }

  /// Valida si un paso específico es válido
  bool isStepValid(int step) {
    switch (step) {
      case 0: // Nombre del medicamento
        return _formData.nombreMedicamento.isNotEmpty;
      case 1: // Presentación
        return _formData.presentacion.isNotEmpty;
      case 2: // Hora primera dosis
        return true; // Siempre válido
      case 3: // Intervalo de dosis
        return _formData.intervaloDosis > 0;
      case 4: // Duración
        return _formData.esIndefinido || _formData.duracionNumero > 0;
      case 5: // Notas
        return true; // Siempre válido (opcional)
      case 6: // Resumen
        return true;
      default:
        return false;
    }
  }

  /// Guarda el tratamiento
  Future<bool> saveTreatment() async {
    final user = _authService.currentUser;
    if (user == null) {
      _setError('Error: Usuario no encontrado.');
      return false;
    }

    // Validar datos
    final validationError = _treatmentService.validateFormData(_formData);
    if (validationError != null) {
      _setError(validationError);
      return false;
    }

    _setLoading(true);
    try {
      await _treatmentService.saveTreatment(
        userId: user.uid,
        formData: _formData,
      );
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al guardar el tratamiento: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Obtiene información de resumen
  Map<String, String> getSummaryInfo() {
    return _treatmentService.calculateSummaryInfo(_formData);
  }

  /// Reinicia el formulario
  void resetForm() {
    _formData = TreatmentFormData();
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _isLoading = false;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}