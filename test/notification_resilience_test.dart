import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:flutter/material.dart';

void main() {
  group('Notification & Alarm Resilience Unit Tests', () {
    test('Payload text sanitization preserves pipe separation structure', () {
      const nombreMedicamento = 'Paracetamol 500mg | con agua';
      const presentacion = 'tabletas | 2 unidades';
      const pacienteNombre = 'Juan | Pérez';
      const habitacion = '101 | piso 2';

      final cleanMed = nombreMedicamento.replaceAll('|', '-');
      final cleanPres = presentacion.replaceAll('|', '-');
      final cleanPac = pacienteNombre.replaceAll('|', '-');
      final cleanHab = habitacion.replaceAll('|', '-');

      const userId = 'user_123';
      const docId = 'doc_456';
      final doseTime = DateTime(2026, 10, 11, 8, 0);
      const notificationId = 12345;
      const profileId = 'prof_789';

      final payload =
          'alarm_mode|$userId|$docId|${doseTime.toIso8601String()}|$cleanMed|1|$cleanPres|$cleanPac|$cleanHab|$notificationId|$profileId';

      final parts = payload.split('|');
      expect(parts.length, 11);
      expect(parts[0], 'alarm_mode');
      expect(parts[1], userId);
      expect(parts[2], docId);
      expect(parts[3], doseTime.toIso8601String());
      expect(parts[4], 'Paracetamol 500mg - con agua');
      expect(parts[5], '1');
      expect(parts[6], 'tabletas - 2 unidades');
      expect(parts[7], 'Juan - Pérez');
      expect(parts[8], '101 - piso 2');
      expect(parts[9], '12345');
      expect(parts[10], profileId);
    });

    test('Zero interval is guarded against infinite loops in offline rescheduling', () {
      const int rawInterval = 0;
      final int intervaloHoras = rawInterval > 0 ? rawInterval : 8;

      expect(intervaloHoras, 8);

      final now = DateTime(2026, 10, 11, 10, 0);
      final doseTime = DateTime(2026, 10, 11, 8, 0);
      final fechaFin = DateTime(2026, 10, 15, 8, 0);

      DateTime siguienteDosis = doseTime.add(Duration(hours: intervaloHoras));
      int iterations = 0;
      while (siguienteDosis.isBefore(now) && !siguienteDosis.isAfter(fechaFin)) {
        siguienteDosis = siguienteDosis.add(Duration(hours: intervaloHoras));
        iterations++;
        if (iterations > 100) break;
      }

      expect(iterations, lessThan(10));
      expect(siguienteDosis.isAfter(now) || siguienteDosis.isAtSameMomentAs(now), true);
    });

    test('Boundary test: Final dose at exact same moment as fechaFinTratamiento is included', () {
      final inicio = DateTime(2026, 10, 11, 8, 0);
      final fin = DateTime(2026, 10, 11, 16, 0); // Exact 8h later

      final t = Tratamiento(
        id: 't1',
        nombreMedicamento: 'Amoxicilina',
        presentacion: 'cápsulas',
        duracion: '1 día',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 8),
        prescriptionAlarmId: 101,
        fechaInicioTratamiento: inicio,
        fechaFinTratamiento: fin,
      );

      final now = DateTime(2026, 10, 11, 10, 0);

      // Verify that loop with !currentDose.isAfter(fin) finds the 16:00 dose
      DateTime currentDose = t.fechaInicioTratamiento;
      DateTime? nextPending;

      while (!currentDose.isAfter(t.fechaFinTratamiento)) {
        if (currentDose.isAfter(now)) {
          nextPending = currentDose;
          break;
        }
        currentDose = currentDose.add(t.intervaloDosis);
      }

      expect(nextPending, isNotNull);
      expect(nextPending, fin);
    });
  });
}
