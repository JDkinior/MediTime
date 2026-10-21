import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/core/utils.dart';

void main() {
  group('AppUtils.formatDoseTime', () {
    test('formats midnight (00:00) as 12:00 AM', () {
      final dt = DateTime(2026, 10, 21, 0, 0);
      expect(AppUtils.formatDoseTime(dt), '12:00 AM');
    });

    test('formats early morning (05:47) as 05:47 AM', () {
      final dt = DateTime(2026, 10, 21, 5, 47);
      expect(AppUtils.formatDoseTime(dt), '05:47 AM');
    });

    test('formats late morning (11:59) as 11:59 AM', () {
      final dt = DateTime(2026, 10, 21, 11, 59);
      expect(AppUtils.formatDoseTime(dt), '11:59 AM');
    });

    test('formats noon (12:00) as 12:00 PM', () {
      final dt = DateTime(2026, 10, 21, 12, 0);
      expect(AppUtils.formatDoseTime(dt), '12:00 PM');
    });

    test('formats afternoon (17:47) as 05:47 PM', () {
      final dt = DateTime(2026, 10, 21, 17, 47);
      expect(AppUtils.formatDoseTime(dt), '05:47 PM');
    });

    test('formats late night (23:59) as 11:59 PM', () {
      final dt = DateTime(2026, 10, 21, 23, 59);
      expect(AppUtils.formatDoseTime(dt), '11:59 PM');
    });
  });

  group('AppUtils.formatDoseTimeOfDay', () {
    test('formats TimeOfDay correctly', () {
      expect(
        AppUtils.formatDoseTimeOfDay(const TimeOfDay(hour: 8, minute: 30)),
        '08:30 AM',
      );
      expect(
        AppUtils.formatDoseTimeOfDay(const TimeOfDay(hour: 20, minute: 15)),
        '08:15 PM',
      );
      expect(
        AppUtils.formatDoseTimeOfDay(const TimeOfDay(hour: 0, minute: 0)),
        '12:00 AM',
      );
      expect(
        AppUtils.formatDoseTimeOfDay(const TimeOfDay(hour: 12, minute: 0)),
        '12:00 PM',
      );
    });
  });
}
