import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/treatment_form_data.dart';

void main() {
  group('TreatmentFormData Duration & Interval Validation', () {
    test('Default TreatmentFormData initializes with intervaloDosis = 0 and duracionNumero = 0', () {
      final formData = TreatmentFormData();

      expect(formData.intervaloDosis, 0);
      expect(formData.duracionNumero, 0);
      expect(formData.esIndefinido, false);
      expect(formData.isValid, false);
    });

    test('TreatmentFormData is invalid when intervaloDosis is 0', () {
      final formData = TreatmentFormData(
        nombreMedicamento: 'Paracetamol',
        presentacion: 'Comprimidos',
        intervaloDosis: 0,
        duracionNumero: 7,
      );

      expect(formData.isValid, false);
    });

    test('TreatmentFormData is invalid when duracionNumero is 0 and not indefinite', () {
      final formData = TreatmentFormData(
        nombreMedicamento: 'Paracetamol',
        presentacion: 'Comprimidos',
        intervaloDosis: 8,
        duracionNumero: 0,
        esIndefinido: false,
      );

      expect(formData.isValid, false);
    });

    test('TreatmentFormData is valid when both intervaloDosis > 0 and duracionNumero > 0', () {
      final formData = TreatmentFormData(
        nombreMedicamento: 'Paracetamol',
        presentacion: 'Comprimidos',
        intervaloDosis: 8,
        duracionNumero: 7,
      );

      expect(formData.intervaloDosis, 8);
      expect(formData.duracionNumero, 7);
      expect(formData.isValid, true);
    });

    test('TreatmentFormData is valid when intervaloDosis > 0 and esIndefinido is true even if duracionNumero is 0', () {
      final formData = TreatmentFormData(
        nombreMedicamento: 'Paracetamol',
        presentacion: 'Comprimidos',
        intervaloDosis: 8,
        duracionNumero: 0,
        esIndefinido: true,
      );

      expect(formData.duracionNumero, 0);
      expect(formData.esIndefinido, true);
      expect(formData.isValid, true);
    });
  });

  group('Tratamiento Optional Inventory and Stock Alerts', () {
    test('When inventory is not filled (0/0), hasStockBajo is false and procesarToma does not alert', () {
      final now = DateTime.now();
      final tratamientoSinStock = Tratamiento(
        id: 't1',
        nombreMedicamento: 'Ibuprofeno',
        presentacion: 'Comprimidos',
        duracion: '7',
        cantidadActual: 0,
        cantidadTotalCaja: 0,
        dosisPorToma: 1,
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 8),
        prescriptionAlarmId: 101,
        fechaInicioTratamiento: now,
        fechaFinTratamiento: now.add(const Duration(days: 7)),
      );

      expect(tratamientoSinStock.hasInventarioConfigurado, false);
      expect(tratamientoSinStock.hasStockBajo, false);

      final resultadoToma = tratamientoSinStock.procesarToma();
      expect(resultadoToma.stockBajo, false);
      expect(resultadoToma.evento, isNull);
    });

    test('When inventory is configured, hasStockBajo triggers properly when below threshold', () {
      final now = DateTime.now();
      final tratamientoConStockBajo = Tratamiento(
        id: 't2',
        nombreMedicamento: 'Amoxicilina',
        presentacion: 'Cápsulas',
        duracion: '7',
        cantidadActual: 3,
        cantidadTotalCaja: 20,
        dosisPorToma: 1,
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 8),
        prescriptionAlarmId: 102,
        fechaInicioTratamiento: now,
        fechaFinTratamiento: now.add(const Duration(days: 7)),
      );

      expect(tratamientoConStockBajo.hasInventarioConfigurado, true);
      expect(tratamientoConStockBajo.hasStockBajo, true);

      final resultadoToma = tratamientoConStockBajo.procesarToma();
      expect(resultadoToma.stockBajo, true);
      expect(resultadoToma.evento, 'Stock Bajo');
      expect(resultadoToma.dosisRestantes, 2);
    });
  });
}
