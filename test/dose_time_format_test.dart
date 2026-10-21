import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/core/utils.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/theme/app_theme.dart';

void main() {
  group('AppUtils.formatDoseTime', () {
    test('formats midnight (00:00) as 12:00 a.m.', () {
      final dt = DateTime(2026, 10, 21, 0, 0);
      expect(AppUtils.formatDoseTime(dt), '12:00 a.m.');
    });

    test('formats early morning (05:47) as 05:47 a.m.', () {
      final dt = DateTime(2026, 10, 21, 5, 47);
      expect(AppUtils.formatDoseTime(dt), '05:47 a.m.');
    });

    test('formats late morning (11:59) as 11:59 a.m.', () {
      final dt = DateTime(2026, 10, 21, 11, 59);
      expect(AppUtils.formatDoseTime(dt), '11:59 a.m.');
    });

    test('formats noon (12:00) as 12:00 p.m.', () {
      final dt = DateTime(2026, 10, 21, 12, 0);
      expect(AppUtils.formatDoseTime(dt), '12:00 p.m.');
    });

    test('formats afternoon (17:47) as 05:47 p.m.', () {
      final dt = DateTime(2026, 10, 21, 17, 47);
      expect(AppUtils.formatDoseTime(dt), '05:47 p.m.');
    });

    test('formats late night (23:59) as 11:59 p.m.', () {
      final dt = DateTime(2026, 10, 21, 23, 59);
      expect(AppUtils.formatDoseTime(dt), '11:59 p.m.');
    });
  });

  group('AppUtils.formatDoseTimeOfDay', () {
    test('formats TimeOfDay correctly', () {
      expect(
        AppUtils.formatDoseTimeOfDay(const TimeOfDay(hour: 8, minute: 30)),
        '08:30 a.m.',
      );
      expect(
        AppUtils.formatDoseTimeOfDay(const TimeOfDay(hour: 20, minute: 15)),
        '08:15 p.m.',
      );
      expect(
        AppUtils.formatDoseTimeOfDay(const TimeOfDay(hour: 0, minute: 0)),
        '12:00 a.m.',
      );
      expect(
        AppUtils.formatDoseTimeOfDay(const TimeOfDay(hour: 12, minute: 0)),
        '12:00 p.m.',
      );
    });
  });

  group('AppUtils.getDoseStatusColor', () {
    test('returns successColor for tomada', () {
      expect(
        AppUtils.getDoseStatusColor(DoseStatus.tomada),
        AppTheme.successColor,
      );
    });

    test('returns errorColor for omitida', () {
      expect(
        AppUtils.getDoseStatusColor(DoseStatus.omitida),
        AppTheme.errorColor,
      );
    });

    test('returns orange for aplazada', () {
      expect(AppUtils.getDoseStatusColor(DoseStatus.aplazada), Colors.orange);
    });

    test('returns amber/yellow for notificada', () {
      final color = AppUtils.getDoseStatusColor(DoseStatus.notificada);
      expect(color, Colors.amber);
    });

    test('returns primaryColor for future pendiente', () {
      expect(
        AppUtils.getDoseStatusColor(DoseStatus.pendiente, isPast: false),
        AppTheme.primaryColor,
      );
    });

    test('returns amber/yellow for past pendiente', () {
      final color = AppUtils.getDoseStatusColor(
        DoseStatus.pendiente,
        isPast: true,
      );
      expect(color, Colors.amber);
    });
  });
}
