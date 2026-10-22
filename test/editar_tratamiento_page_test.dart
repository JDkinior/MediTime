import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/notifiers/treatment_form_notifier.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/screens/medication/editar_tratamiento_page.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/treatment_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/gemini_service.dart';
import 'package:meditime/repositories/treatment_repository.dart';

class MockFirestoreService extends Fake implements FirestoreService {}

class MockAuthService extends Fake implements AuthService {}

class MockTreatmentRepository extends Fake implements TreatmentRepository {}

class MockGeminiService extends Fake implements GeminiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Tratamiento dummyTratamiento;

  setUp(() {
    SharedPreferences.setMockInitialValues({'interface_style': 'modern'});
    dummyTratamiento = Tratamiento(
      id: 'test_treatment_123',
      nombreMedicamento: 'Ibuprofeno 600mg',
      presentacion: 'Comprimidos',
      duracion: '7',
      cantidadActual: 20,
      cantidadTotalCaja: 30,
      dosisPorToma: 1,
      horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
      intervaloDosis: const Duration(hours: 8),
      prescriptionAlarmId: 101,
      fechaInicioTratamiento: DateTime(2026, 10, 21),
      fechaFinTratamiento: DateTime(2026, 10, 28),
      notas: 'Tomar con abundante agua',
    );
  });

  Widget createWidgetUnderTest(Tratamiento tratamiento) {
    final prefService = PreferenceService();
    final prefNotifier = PreferenceNotifier(prefService);
    final firestoreService = MockFirestoreService();
    final authService = MockAuthService();
    final treatmentService = TreatmentService(firestoreService);
    final formNotifier = TreatmentFormNotifier(treatmentService, authService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferenceNotifier>.value(value: prefNotifier),
        ChangeNotifierProvider<TreatmentFormNotifier>.value(value: formNotifier),
        Provider<AuthService>.value(value: authService),
        Provider<TreatmentRepository>.value(value: MockTreatmentRepository()),
        Provider<GeminiService>.value(value: MockGeminiService()),
      ],
      child: MaterialApp(
        home: EditarTratamientoPage(tratamiento: tratamiento),
      ),
    );
  }

  group('EditarTratamientoPage Widget Tests', () {
    testWidgets('renders medication name, presentation and scheduled doses list',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(dummyTratamiento));
      await tester.pumpAndSettle();

      // Verificar título de AppBar
      expect(find.text('Editar Tratamiento'), findsOneWidget);

      // Verificar que el nombre del medicamento aparece en el TextFormField
      expect(find.text('Ibuprofeno 600mg'), findsOneWidget);

      // Verificar sección de Dosis y Horarios
      expect(find.text('Dosis y Horarios'), findsOneWidget);
      expect(find.text('3 dosis al día'), findsOneWidget);

      // Con intervalo de 8h desde las 08:00 a.m., debe listar 3 dosis:
      // Dosis 1: 08:00 a.m.
      // Dosis 2: 04:00 p.m.
      // Dosis 3: 12:00 a.m.
      expect(find.text('Dosis 1'), findsOneWidget);
      expect(find.text('Dosis 2'), findsOneWidget);
      expect(find.text('Dosis 3'), findsOneWidget);
      expect(find.text('08:00 a.m.'), findsOneWidget);
      expect(find.text('04:00 p.m.'), findsOneWidget);
      expect(find.text('12:00 a.m.'), findsOneWidget);

      // Verificar botón de Guardar en AppBar
      expect(find.text('Guardar'), findsOneWidget);

      // Desplazarse en el ListView principal hasta el botón inferior de Guardar Cambios
      await tester.scrollUntilVisible(
        find.text('Guardar Cambios'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Guardar Cambios'), findsOneWidget);
    });

    testWidgets('changing frequency chips updates the dose list dynamically',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(dummyTratamiento));
      await tester.pumpAndSettle();

      // Cambiar de Cada 8 h a Cada 12 h
      final cada12hChip = find.text('Cada 12 h');
      expect(cada12hChip, findsOneWidget);
      await tester.tap(cada12hChip);
      await tester.pumpAndSettle();

      // Con Cada 12 h, debe haber 2 dosis al día (08:00 a.m. y 08:00 p.m.)
      expect(find.text('2 dosis al día'), findsOneWidget);
      expect(find.text('Dosis 1'), findsOneWidget);
      expect(find.text('Dosis 2'), findsOneWidget);
      expect(find.text('Dosis 3'), findsNothing);
      expect(find.text('08:00 a.m.'), findsOneWidget);
      expect(find.text('08:00 p.m.'), findsOneWidget);
    });

    testWidgets('incrementing and decrementing dosisPorToma updates stepper',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(dummyTratamiento));
      await tester.pumpAndSettle();

      // Dosis inicial: muestra 1 Comprimidos en las tarjetas de dosis
      expect(find.text('1 Comprimidos'), findsWidgets);

      // Tocar botón + del stepper
      final addIcon = find.byIcon(Icons.add);
      expect(addIcon, findsOneWidget);
      await tester.tap(addIcon);
      await tester.pumpAndSettle();

      // Ahora debe mostrar 2 Comprimidos
      expect(find.text('2 Comprimidos'), findsWidgets);

      // Tocar botón - del stepper
      final removeIcon = find.byIcon(Icons.remove);
      expect(removeIcon, findsOneWidget);
      await tester.tap(removeIcon);
      await tester.pumpAndSettle();

      // Vuelve a 1 Comprimidos
      expect(find.text('1 Comprimidos'), findsWidgets);
    });
  });
}
