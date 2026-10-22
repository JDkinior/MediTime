import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/core/utils.dart';

void main() {
  group('AppUtils.formatTwoDigitDate Tests', () {
    final testDate = DateTime(2026, 10, 23);
    final singleDigitDate = DateTime(2026, 4, 5);

    test('formats English (en) with 2 digits MM/dd/yy', () {
      expect(AppUtils.formatTwoDigitDate(testDate, 'en'), '10/23/26');
      expect(AppUtils.formatTwoDigitDate(testDate, 'en_US'), '10/23/26');
      expect(AppUtils.formatTwoDigitDate(singleDigitDate, 'en'), '04/05/26');
    });

    test('formats Spanish (es) with 2 digits dd/MM/yy', () {
      expect(AppUtils.formatTwoDigitDate(testDate, 'es'), '23/10/26');
      expect(AppUtils.formatTwoDigitDate(testDate, 'es_ES'), '23/10/26');
      expect(AppUtils.formatTwoDigitDate(singleDigitDate, 'es'), '05/04/26');
    });

    test('formats Portuguese (pt) with 2 digits dd/MM/yy', () {
      expect(AppUtils.formatTwoDigitDate(testDate, 'pt'), '23/10/26');
      expect(AppUtils.formatTwoDigitDate(testDate, 'pt_BR'), '23/10/26');
      expect(AppUtils.formatTwoDigitDate(singleDigitDate, 'pt'), '05/04/26');
    });

    test('defaults to dd/MM/yy when localeCode is null', () {
      expect(AppUtils.formatTwoDigitDate(testDate), '23/10/26');
      expect(AppUtils.formatTwoDigitDate(singleDigitDate), '05/04/26');
    });
  });
}
