import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meditime/core/legal_content.dart';
import 'package:meditime/services/preference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LegalContent Compliance & Structure Tests', () {
    test('LegalContent defines proper version and non-empty metadata', () {
      expect(LegalContent.version, isNotEmpty);
      expect(LegalContent.lastUpdated, isNotEmpty);
      expect(LegalContent.supportEmail, equals('soporte@meditime.app'));
      expect(LegalContent.contactEmail, equals('privacidad@meditime.app'));
    });

    test('Terms of Service contains 10 rigorous sections including critical medical disclaimer', () {
      expect(LegalContent.termsOfService.length, equals(10));

      final medicalSection = LegalContent.termsOfService.firstWhere(
        (s) => s.title.contains('Deslinde de Responsabilidad Médica'),
      );
      expect(medicalSection.content, contains('NO ES UN DISPOSITIVO MÉDICO'));
      expect(medicalSection.content, contains('911'));

      // Check Caregiver and Animal mode terms
      final caregiverSection = LegalContent.termsOfService.firstWhere(
        (s) => s.title.contains('Cuidador y Animales'),
      );
      expect(caregiverSection.content, contains('consentimiento'));
      expect(caregiverSection.content, contains('veterinario'));

      // Check AI disclaimer
      final aiSection = LegalContent.termsOfService.firstWhere(
        (s) => s.title.contains('Inteligencia Artificial (Midi)'),
      );
      expect(aiSection.content, contains('informativo, pedagógico y de apoyo general'));
    });

    test('Privacy Policy contains 10 exhaustive sections compliant with health apps regulations', () {
      expect(LegalContent.privacyPolicy.length, equals(10));

      final section1 = LegalContent.privacyPolicy.first;
      expect(section1.title, contains('Compromiso Ético y Marco Regulatorio'));
      expect(section1.content, contains('Google Play'));
      expect(section1.content, contains('RGPD'));

      // Strict prohibition of medical data sale
      final noSaleSection = LegalContent.privacyPolicy.firstWhere(
        (s) => s.title.contains('Prohibición Absoluta de Venta'),
      );
      expect(noSaleSection.content, contains('NUNCA venderá'));
      expect(noSaleSection.content, contains('publicitarias'));

      // Gemini AI privacy guarantees
      final aiPrivacySection = LegalContent.privacyPolicy.firstWhere(
        (s) => s.title.contains('Asistente IA (Midi)'),
      );
      expect(aiPrivacySection.content, contains('sin retención para fines de entrenamiento'));

      // Deletion and right to be forgotten
      final deletionSection = LegalContent.privacyPolicy.firstWhere(
        (s) => s.title.contains('Derechos del Usuario'),
      );
      expect(deletionSection.content, contains('Eliminar mi cuenta'));
      expect(deletionSection.content, contains('definitivo'));
    });
  });

  group('PreferenceService Legal Terms Persistence Tests', () {
    const testUserId = 'test_user_123';
    final prefService = PreferenceService();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Default hasAcceptedTerms is false when not configured', () async {
      final accepted = await prefService.hasAcceptedTerms(testUserId);
      expect(accepted, isFalse);

      final version = await prefService.getTermsAcceptedVersion(testUserId);
      expect(version, isNull);

      final date = await prefService.getTermsAcceptedAt(testUserId);
      expect(date, isNull);
    });

    test('saveTermsAccepted stores acceptance, version and timestamp', () async {
      await prefService.saveTermsAccepted(
        testUserId,
        accepted: true,
        version: '2.34.0',
      );

      final accepted = await prefService.hasAcceptedTerms(testUserId);
      expect(accepted, isTrue);

      final version = await prefService.getTermsAcceptedVersion(testUserId);
      expect(version, equals('2.34.0'));

      final date = await prefService.getTermsAcceptedAt(testUserId);
      expect(date, isNotNull);
      expect(DateTime.tryParse(date!), isNotNull);
    });

    test('saveTermsAccepted false clears acceptance', () async {
      await prefService.saveTermsAccepted(
        testUserId,
        accepted: true,
        version: '2.34.0',
      );
      expect(await prefService.hasAcceptedTerms(testUserId), isTrue);

      await prefService.saveTermsAccepted(testUserId, accepted: false);
      expect(await prefService.hasAcceptedTerms(testUserId), isFalse);
    });
  });
}
