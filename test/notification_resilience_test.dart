import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/services/tratamiento_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      final now = DateTime.now();
      final doseTime = DateTime(now.year, now.month, now.day, 8, 0);
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

    test('canonicalFirstDoseDateTime eliminates creation grace-window drift', () {
      // Simula un tratamiento cuya primera dosis era 08:00, pero se guardó
      // con fechaInicioTratamiento corrida a las 08:02:15 por la ventana de gracia
      final driftedStart = DateTime(2026, 10, 11, 8, 2, 15);
      final fin = DateTime(2026, 10, 15, 8, 0);

      final t = Tratamiento(
        id: 't_drift',
        nombreMedicamento: 'Ibuprofeno',
        presentacion: 'tabletas',
        duracion: '4 días',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 8),
        prescriptionAlarmId: 202,
        fechaInicioTratamiento: driftedStart,
        fechaFinTratamiento: fin,
      );

      expect(t.canonicalFirstDoseDateTime, DateTime(2026, 10, 11, 8, 0, 0));

      final doses = TratamientoService.generarDosisTotales(t);
      expect(doses[0], DateTime(2026, 10, 11, 8, 0, 0));
      expect(doses[1], DateTime(2026, 10, 11, 16, 0, 0));
      expect(doses[2], DateTime(2026, 10, 12, 0, 0, 0));
    });

    test('Deferring or snoozing a single dose never shifts subsequent doses', () {
      final inicio = DateTime(2026, 10, 11, 8, 0);
      final fin = DateTime(2026, 10, 13, 8, 0);

      // La dosis de las 08:00 fue aplazada a las 08:30
      final t = Tratamiento(
        id: 't_defer',
        nombreMedicamento: 'Losartán',
        presentacion: 'tabletas',
        duracion: '2 días',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 8),
        prescriptionAlarmId: 303,
        fechaInicioTratamiento: inicio,
        fechaFinTratamiento: fin,
        doseStatus: {
          DateTime(2026, 10, 11, 8, 30).toIso8601String(): DoseStatus.aplazada,
        },
      );

      // A las 08:05, la próxima alarma a sonar debe ser la aplazada (08:30),
      // pero anclada a su ranura canónica (08:00).
      final targetAt805 = TratamientoService.findNextScheduledDose(
        tratamiento: t,
        referenceTime: DateTime(2026, 10, 11, 8, 5),
      );
      expect(targetAt805, isNotNull);
      expect(targetAt805!.fireTime, DateTime(2026, 10, 11, 8, 30));
      expect(targetAt805.canonicalDoseTime, DateTime(2026, 10, 11, 8, 0));
      expect(targetAt805.isDeferredOrEdited, isTrue);

      // Una vez pasa las 08:30, la siguiente dosis DEBE ser exactamente a las 16:00:00 (sin correrse a 16:30)
      final targetAfter830 = TratamientoService.findNextScheduledDose(
        tratamiento: t,
        referenceTime: DateTime(2026, 10, 11, 8, 30),
      );
      expect(targetAfter830, isNotNull);
      expect(targetAfter830!.fireTime, DateTime(2026, 10, 11, 16, 0));
      expect(targetAfter830.canonicalDoseTime, DateTime(2026, 10, 11, 16, 0));
    });

    test('Early-taken dose is skipped when scheduling next alarm', () {
      final inicio = DateTime(2026, 10, 11, 8, 0);
      final fin = DateTime(2026, 10, 13, 8, 0);

      // El usuario tomó la dosis de las 16:00 de forma anticipada a las 15:45
      final t = Tratamiento(
        id: 't_early',
        nombreMedicamento: 'Metformina',
        presentacion: 'tabletas',
        duracion: '2 días',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 8),
        prescriptionAlarmId: 404,
        fechaInicioTratamiento: inicio,
        fechaFinTratamiento: fin,
        doseStatus: {
          DateTime(2026, 10, 11, 8, 0).toIso8601String(): DoseStatus.tomada,
          DateTime(2026, 10, 11, 16, 0).toIso8601String(): DoseStatus.tomada,
        },
      );

      final nextAt1545 = TratamientoService.findNextScheduledDose(
        tratamiento: t,
        referenceTime: DateTime(2026, 10, 11, 15, 45),
      );

      expect(nextAt1545, isNotNull);
      expect(nextAt1545!.fireTime, DateTime(2026, 10, 12, 0, 0));
    });

    test('Offline multi-interval power-off recovery maintains exact canonical grid', () {
      // Tratamiento cada 8h empezando a las 08:00 del 11 de octubre.
      // El teléfono estuvo apagado desde las 07:50 hasta las 18:20 (se perdieron 08:00 y 16:00).
      final nextDose = TratamientoService.computeNextCanonicalDoseOffline(
        doseTime: DateTime(2026, 10, 11, 8, 15), // incluso si venía de un snooze
        intervaloHoras: 8,
        fechaFinTratamiento: DateTime(2026, 10, 15, 8, 0),
        fechaInicioTratamiento: DateTime(2026, 10, 11, 8, 0),
        horaPrimeraDosisHour: 8,
        horaPrimeraDosisMinute: 0,
        referenceNow: DateTime(2026, 10, 11, 18, 20),
      );

      // La siguiente dosis debe ser exactamente a las 00:00 del 12 de octubre (nunca 02:20 ni 00:15)
      expect(nextDose, DateTime(2026, 10, 12, 0, 0, 0));
    });

    test('Local offline dose ledger prevents overwriting completed doses with notificada', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PreferenceService();
      final now = DateTime.now();
      final doseTime = DateTime(now.year, now.month, now.day, 8, 0);

      await prefs.saveLocalDoseStatus(
        userId: 'u_1',
        docId: 'med_1',
        doseTime: doseTime,
        status: 'tomada',
      );

      // Si una alarma retrasada intenta marcarla como 'notificada', se ignora
      await prefs.saveLocalDoseStatus(
        userId: 'u_1',
        docId: 'med_1',
        doseTime: doseTime,
        status: 'notificada',
        preventOverwriteCompleted: true,
      );

      final statuses = await prefs.getLocalDoseStatuses('u_1', 'med_1');
      expect(statuses[doseTime.toIso8601String()], 'tomada');
    });
  });
}
