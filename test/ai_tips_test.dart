import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/services/gemini_service.dart';

void main() {
  group('Tratamiento isActivo and isFinalizado tests', () {
    test('Correctly identifies active vs historical treatments', () {
      final now = DateTime.now();

      final activeTreatment = Tratamiento(
        id: 't_active',
        nombreMedicamento: 'Omeprazol',
        presentacion: 'Cápsulas',
        duracion: '30 días',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 24),
        prescriptionAlarmId: 101,
        fechaInicioTratamiento: now.subtract(const Duration(days: 5)),
        fechaFinTratamiento: now.add(const Duration(days: 25)),
      );

      final expiredTreatment = Tratamiento(
        id: 't_expired',
        nombreMedicamento: 'Amoxicilina Pasada',
        presentacion: 'Comprimidos',
        duracion: '7 días',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 8),
        prescriptionAlarmId: 102,
        fechaInicioTratamiento: now.subtract(const Duration(days: 30)),
        fechaFinTratamiento: now.subtract(const Duration(days: 23)),
      );

      expect(activeTreatment.isActivo, isTrue);
      expect(activeTreatment.isFinalizado, isFalse);

      expect(expiredTreatment.isActivo, isFalse);
      expect(expiredTreatment.isFinalizado, isTrue);
    });
  });

  group('GeminiService AI Health Tips tests', () {
    late GeminiService geminiService;

    setUp(() {
      geminiService = GeminiService();
    });

    test('Generates medication-specific tips and excludes historical treatments', () {
      final now = DateTime.now();

      final activeMeds = [
        Tratamiento(
          id: '1',
          nombreMedicamento: 'Omeprazol 20mg',
          presentacion: 'Cápsulas',
          duracion: '14 días',
          horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
          intervaloDosis: const Duration(hours: 24),
          prescriptionAlarmId: 1,
          fechaInicioTratamiento: now.subtract(const Duration(days: 2)),
          fechaFinTratamiento: now.add(const Duration(days: 12)),
        ),
        // Finished / Historical treatment from 2 months ago
        Tratamiento(
          id: '2',
          nombreMedicamento: 'Ibuprofeno Historial',
          presentacion: 'Comprimidos',
          duracion: '5 días',
          horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
          intervaloDosis: const Duration(hours: 8),
          prescriptionAlarmId: 2,
          fechaInicioTratamiento: now.subtract(const Duration(days: 60)),
          fechaFinTratamiento: now.subtract(const Duration(days: 55)),
        ),
      ];

      final tips = geminiService.getFallbackTips(
        treatments: activeMeds,
        pendingCount: 1,
        takenCount: 1,
        adherenceRate: 50.0,
      );

      expect(tips, isNotEmpty);
      // Must contain tip for Omeprazol (active)
      expect(tips.any((t) => t['title'] == 'Toma en ayunas' || t['content']!.contains('Omeprazol')), isTrue);
      // Must NOT contain tip for Ibuprofeno (expired/history)
      expect(tips.any((t) => t['content']!.contains('Ibuprofeno Historial')), isFalse);
      // Retains general hydration tip
      expect(tips.any((t) => t['title'] == 'Hidratación clave' || t['content']!.contains('vaso')), isTrue);
    });

    test('Adapts tips to Modo Mascotas (animal mode)', () {
      final now = DateTime.now();
      final petProfile = CaregiverProfile(
        id: 'pet_1',
        name: 'Max',
        relationship: 'Perro',
        colorHex: '#10B981',
        isExternalUser: false,
        isAnimal: true,
        species: 'Canino',
        breed: 'Golden Retriever',
        weight: '28 kg',
      );

      final petMeds = [
        Tratamiento(
          id: 'p1',
          nombreMedicamento: 'Amoxicilina Veterinaria',
          presentacion: 'Comprimidos',
          duracion: '10 días',
          horaPrimeraDosis: const TimeOfDay(hour: 9, minute: 0),
          intervaloDosis: const Duration(hours: 12),
          prescriptionAlarmId: 201,
          fechaInicioTratamiento: now.subtract(const Duration(days: 1)),
          fechaFinTratamiento: now.add(const Duration(days: 9)),
        ),
      ];

      final tips = geminiService.getFallbackTips(
        treatments: petMeds,
        pendingCount: 1,
        takenCount: 0,
        adherenceRate: 0.0,
        isAnimalMode: true,
        profile: petProfile,
      );

      expect(tips, isNotEmpty);
      // Should include pet icon and pet-adapted tips
      expect(tips.any((t) => t['title']!.contains('🐾') || t['content']!.contains('Max')), isTrue);
    });

    test('Adapts tips to Modo Cuidador Clínico', () {
      final now = DateTime.now();
      final clinicalProfile = CaregiverProfile(
        id: 'patient_204',
        name: 'Roberto Gómez',
        relationship: 'Paciente',
        colorHex: '#3B82F6',
        isExternalUser: false,
        roomNumber: '204-B',
        bloodType: 'O+',
      );

      final clinicalMeds = [
        Tratamiento(
          id: 'c1',
          nombreMedicamento: 'Losartán 50mg',
          presentacion: 'Comprimidos',
          duracion: '30 días',
          horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
          intervaloDosis: const Duration(hours: 24),
          prescriptionAlarmId: 301,
          fechaInicioTratamiento: now.subtract(const Duration(days: 3)),
          fechaFinTratamiento: now.add(const Duration(days: 27)),
        ),
      ];

      final tips = geminiService.getFallbackTips(
        treatments: clinicalMeds,
        pendingCount: 0,
        takenCount: 1,
        adherenceRate: 100.0,
        caregiverModeType: CaregiverModeType.clinico,
        profile: clinicalProfile,
      );

      expect(tips, isNotEmpty);
      // Should include clinical tips (e.g. 5 correctos or control de TA)
      expect(tips.any((t) => t['title']!.contains('🩺') || t['content']!.contains('presión') || t['content']!.contains('correctos')), isTrue);
    });

    test('Adapts tips to Modo Cuidador Familiar', () {
      final now = DateTime.now();
      final familyProfile = CaregiverProfile(
        id: 'fam_1',
        name: 'Mamá Carmen',
        relationship: 'Madre',
        colorHex: '#8B5CF6',
        isExternalUser: false,
      );

      final familyMeds = [
        Tratamiento(
          id: 'f1',
          nombreMedicamento: 'Metformina 850mg',
          presentacion: 'Tabletas',
          duracion: '60 días',
          horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
          intervaloDosis: const Duration(hours: 12),
          prescriptionAlarmId: 401,
          fechaInicioTratamiento: now.subtract(const Duration(days: 5)),
          fechaFinTratamiento: now.add(const Duration(days: 55)),
        ),
      ];

      final tips = geminiService.getFallbackTips(
        treatments: familyMeds,
        pendingCount: 1,
        takenCount: 1,
        adherenceRate: 50.0,
        caregiverModeType: CaregiverModeType.familiar,
        profile: familyProfile,
      );

      expect(tips, isNotEmpty);
      // Should include family caregiver tips
      expect(tips.any((t) => t['title']!.contains('👨‍👩‍👧') || t['content']!.contains('Mamá Carmen')), isTrue);
    });

    test('Generates tips in English when language is en', () {
      final now = DateTime.now();
      final activeMeds = [
        Tratamiento(
          id: '1',
          nombreMedicamento: 'Omeprazol 20mg',
          presentacion: 'Cápsulas',
          duracion: '14 días',
          horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
          intervaloDosis: const Duration(hours: 24),
          prescriptionAlarmId: 1,
          fechaInicioTratamiento: now.subtract(const Duration(days: 2)),
          fechaFinTratamiento: now.add(const Duration(days: 12)),
        ),
      ];

      final tips = geminiService.getFallbackTips(
        treatments: activeMeds,
        pendingCount: 0,
        takenCount: 1,
        adherenceRate: 100.0,
        language: 'en',
      );

      expect(tips, isNotEmpty);
      expect(tips.any((t) => t['title'] == 'Take on empty stomach'), isTrue);
      expect(tips.any((t) => t['title'] == 'Great consistency!'), isTrue);
      expect(tips.any((t) => t['title'] == 'Hydration key'), isTrue);
    });

    test('Generates tips in Portuguese when language is pt', () {
      final now = DateTime.now();
      final activeMeds = [
        Tratamiento(
          id: '1',
          nombreMedicamento: 'Omeprazol 20mg',
          presentacion: 'Cápsulas',
          duracion: '14 días',
          horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
          intervaloDosis: const Duration(hours: 24),
          prescriptionAlarmId: 1,
          fechaInicioTratamiento: now.subtract(const Duration(days: 2)),
          fechaFinTratamiento: now.add(const Duration(days: 12)),
        ),
      ];

      final tips = geminiService.getFallbackTips(
        treatments: activeMeds,
        pendingCount: 0,
        takenCount: 1,
        adherenceRate: 100.0,
        language: 'pt',
      );

      expect(tips, isNotEmpty);
      expect(tips.any((t) => t['title'] == 'Tome em jejum'), isTrue);
      expect(tips.any((t) => t['title'] == 'Excelente constância!'), isTrue);
      expect(tips.any((t) => t['title'] == 'Hidratação chave'), isTrue);
    });
  });
}
