import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/widgets/chat/prescription_form_card.dart';

class MockCaregiverNotifier extends ChangeNotifier
    implements CaregiverNotifier {
  @override
  bool get isCaregiverModeActive => false;
  @override
  List<CaregiverProfile> get managedProfiles => [];
  @override
  CaregiverProfile? getEffectiveActiveProfile({required bool isAnimalMode}) =>
      null;
  @override
  CaregiverProfile? get activeProfile => null;
  @override
  String? get activeProfileId => null;
  @override
  bool get isGeneralMode => false;
  @override
  bool get isLoading => false;
  @override
  CaregiverModeType get modeType => CaregiverModeType.familiar;
  @override
  bool get notifyPatientDoses => false;
  @override
  bool get includeLocationInNotifications => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'interface_style': 'modern'});
  });

  Widget buildTestCard({
    required Map<String, dynamic> prescriptionData,
    required void Function(
      String name,
      String pres,
      int interval,
      int dosis,
      int duration,
      String notas, [
      CaregiverProfile? targetProfile,
    ])
    onSaved,
  }) {
    final prefNotifier = PreferenceNotifier(PreferenceService());
    final caregiverNotifier = MockCaregiverNotifier();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferenceNotifier>.value(value: prefNotifier),
        ChangeNotifierProvider<CaregiverNotifier>.value(
          value: caregiverNotifier,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PrescriptionFormCard(
              prescriptionData: prescriptionData,
              onSaved: onSaved,
            ),
          ),
        ),
      ),
    );
  }

  group('PrescriptionFormCard Widget Tests', () {
    testWidgets('populates fields correctly from prescriptionData', (
      tester,
    ) async {
      final data = <String, dynamic>{
        'nombreMedicamento': 'Amoxicilina',
        'dosisPorToma': 1,
        'intervaloDosis': 8,
        'duracion': 7,
        'presentacion': 'tabletas',
        'notas': 'Tomar con alimentos',
        'isSaved': false,
      };

      await tester.pumpWidget(
        buildTestCard(
          prescriptionData: data,
          onSaved: (a, b, c, d, e, f, [g]) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Amoxicilina'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Tomar con alimentos'), findsOneWidget);
      expect(find.text('Confirmar y Guardar'), findsOneWidget);
    });

    testWidgets('normalizes presentation to closest valid standard option', (
      tester,
    ) async {
      final data = <String, dynamic>{
        'nombreMedicamento': 'Ibuprofeno Jarabe',
        'dosisPorToma': 5,
        'intervaloDosis': 8,
        'duracion': 5,
        'presentacion': 'jarabes infantiles',
        'isSaved': false,
      };

      await tester.pumpWidget(
        buildTestCard(
          prescriptionData: data,
          onSaved: (a, b, c, d, e, f, [g]) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jarabes'), findsOneWidget);
    });

    testWidgets('invokes onSaved with updated values on submit', (
      tester,
    ) async {
      String? savedName;
      String? savedPres;
      int? savedInterval;
      int? savedDosis;
      int? savedDuration;

      final data = <String, dynamic>{
        'nombreMedicamento': 'Paracetamol',
        'dosisPorToma': 1,
        'intervaloDosis': 6,
        'duracion': 3,
        'presentacion': 'comprimidos',
        'isSaved': false,
      };

      await tester.pumpWidget(
        buildTestCard(
          prescriptionData: data,
          onSaved: (name, pres, interval, dosis, duration, notas, [profile]) {
            savedName = name;
            savedPres = pres;
            savedInterval = interval;
            savedDosis = dosis;
            savedDuration = duration;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar y Guardar'));
      await tester.pumpAndSettle();

      expect(savedName, 'Paracetamol');
      expect(savedPres, 'Comprimidos');
      expect(savedInterval, 6);
      expect(savedDosis, 1);
      expect(savedDuration, 3);
    });

    testWidgets(
      'shows warning SnackBar when medication name is cleared before saving',
      (tester) async {
        final data = <String, dynamic>{
          'nombreMedicamento': '',
          'dosisPorToma': 1,
          'intervaloDosis': 8,
          'duracion': 7,
          'isSaved': false,
        };

        await tester.pumpWidget(
          buildTestCard(
            prescriptionData: data,
            onSaved: (a, b, c, d, e, f, [g]) {},
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirmar y Guardar'));
        await tester.pump();

        expect(
          find.text('El nombre del medicamento es requerido.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('hides save button when isSaved is true', (tester) async {
      final data = <String, dynamic>{
        'nombreMedicamento': 'Omeprazol',
        'dosisPorToma': 1,
        'intervaloDosis': 24,
        'duracion': 14,
        'isSaved': true,
      };

      await tester.pumpWidget(
        buildTestCard(
          prescriptionData: data,
          onSaved: (a, b, c, d, e, f, [g]) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Confirmar y Guardar'), findsNothing);
    });
  });
}
