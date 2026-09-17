import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';

void main() {
  group('Modo Animales - Unit Tests', () {
    test('CaregiverProfile serializes and deserializes animal fields correctly', () {
      final petProfile = CaregiverProfile(
        id: 'pet_123',
        name: 'Rocky',
        relationship: 'Canino',
        colorHex: '#10B981',
        isExternalUser: false,
        isAnimal: true,
        species: 'Perro',
        breed: 'Golden Retriever',
        weight: '28.5 kg',
        microchip: 'CHIP-987654321',
        notes: 'Alérgico a la penicilina',
      );

      final map = petProfile.toMap();
      expect(map['isAnimal'], true);
      expect(map['species'], 'Perro');
      expect(map['breed'], 'Golden Retriever');
      expect(map['weight'], '28.5 kg');
      expect(map['microchip'], 'CHIP-987654321');

      final reconstructed = CaregiverProfile.fromMap('pet_123', map);
      expect(reconstructed.id, 'pet_123');
      expect(reconstructed.name, 'Rocky');
      expect(reconstructed.isAnimal, true);
      expect(reconstructed.species, 'Perro');
      expect(reconstructed.breed, 'Golden Retriever');
      expect(reconstructed.weight, '28.5 kg');
      expect(reconstructed.microchip, 'CHIP-987654321');
      expect(reconstructed.notes, 'Alérgico a la penicilina');
    });

    test('AppTheme switches to green in animal mode and reverts to blue when deactivated', () {
      // Normal mode (light)
      AppTheme.updateThemeColors(false, highContrast: false, isAnimalMode: false);
      expect(AppTheme.primaryColor, const Color(0xFF004AC6));

      // Animal mode (light) - should be green
      AppTheme.updateThemeColors(false, highContrast: false, isAnimalMode: true);
      expect(AppTheme.primaryColor, const Color(0xFF15803D));

      // Animal mode (dark) - should also be green
      AppTheme.updateThemeColors(true, highContrast: false, isAnimalMode: true);
      expect(AppTheme.primaryColor, const Color(0xFF15803D));

      // Back to normal mode (light)
      AppTheme.updateThemeColors(false, highContrast: false, isAnimalMode: false);
      expect(AppTheme.primaryColor, const Color(0xFF004AC6));
    });

    testWidgets('AppLocalizations contains animal mode translations', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Scaffold(
                body: Text(l10n.optionsAnimals),
              );
            },
          ),
        ),
      );

      expect(find.text('Modo Animales (Veterinaria)'), findsOneWidget);
    });
  });
}
