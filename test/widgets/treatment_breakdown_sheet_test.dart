import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/screens/medication/detalle_receta_page.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/widgets/reports/full_treatment_breakdown_sheet.dart';
import 'package:meditime/widgets/reports/treatment_accordion_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Tratamiento createSampleTreatment({
    required String id,
    required String name,
    Map<String, DoseStatus> doseStatus = const {},
  }) {
    return Tratamiento(
      id: id,
      nombreMedicamento: name,
      presentacion: 'Pastilla',
      duracion: '30 días',
      horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
      intervaloDosis: const Duration(hours: 8),
      prescriptionAlarmId: 100,
      fechaInicioTratamiento: DateTime(2026, 1, 1),
      fechaFinTratamiento: DateTime(2026, 1, 30),
      doseStatus: doseStatus,
    );
  }

  Widget buildTestApp(Widget child) {
    final notifier = PreferenceNotifier(PreferenceService());
    return ChangeNotifierProvider<PreferenceNotifier>.value(
      value: notifier,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('TreatmentAccordionCard displays info and expands on tap', (tester) async {
    final t = createSampleTreatment(id: 't1', name: 'Ibuprofeno');
    bool expanded = false;

    await tester.pumpWidget(
      buildTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            return TreatmentAccordionCard(
              tratamiento: t,
              stats: const {
                'programadasPasadas': 10,
                'tomadas': 9,
                'omitidas': 1,
                'notificadas': 0,
                'aplazadas': 0,
              },
              isExpanded: expanded,
              onToggle: () {
                setState(() => expanded = !expanded);
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify name and adherence percentage
    expect(find.text('Ibuprofeno'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);

    // Tap to expand
    await tester.tap(find.text('Ibuprofeno'));
    await tester.pumpAndSettle();

    // Verify detail items inside expanded accordion
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Fin'), findsOneWidget);
    expect(find.text('Ver detalle completo del medicamento'), findsOneWidget);

    // Verify all 4 mini stat chips are rendered side-by-side on the same horizontal row
    expect(find.text('Tomadas: 9'), findsOneWidget);
    expect(find.text('Omitidas: 1'), findsOneWidget);
    expect(find.text('Notificadas: 0'), findsOneWidget);
    expect(find.text('Aplazadas: 0'), findsOneWidget);

    final yTomadas = tester.getTopLeft(find.text('Tomadas: 9')).dy;
    final yOmitidas = tester.getTopLeft(find.text('Omitidas: 1')).dy;
    final yNotificadas = tester.getTopLeft(find.text('Notificadas: 0')).dy;
    final yAplazadas = tester.getTopLeft(find.text('Aplazadas: 0')).dy;

    expect(yTomadas, equals(yOmitidas));
    expect(yTomadas, equals(yNotificadas));
    expect(yTomadas, equals(yAplazadas));
  });

  testWidgets('FullTreatmentBreakdownSheet filters treatments by search and chips', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final t1 = createSampleTreatment(id: 't1', name: 'Amoxicilina');
    final t2 = createSampleTreatment(id: 't2', name: 'Paracetamol');

    final dateRange = {
      'start': DateTime(2026, 1, 1),
      'end': DateTime(2026, 1, 15),
    };

    Map<String, int> mockStats(Tratamiento t, Map<String, DateTime> range) {
      if (t.id == 't1') {
        return {
          'programadasPasadas': 10,
          'tomadas': 9, // 90% -> Alta
          'omitidas': 1,
          'notificadas': 0,
          'aplazadas': 0,
        };
      } else {
        return {
          'programadasPasadas': 10,
          'tomadas': 3, // 30% -> Baja
          'omitidas': 7,
          'notificadas': 0,
          'aplazadas': 0,
        };
      }
    }

    await tester.pumpWidget(
      buildTestApp(
        FullTreatmentBreakdownSheet(
          tratamientos: [t1, t2],
          dateRange: dateRange,
          statsCalculator: mockStats,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both should be visible initially
    expect(find.text('Amoxicilina'), findsOneWidget);
    expect(find.text('Paracetamol'), findsOneWidget);
    expect(find.text('2 tratamientos en este período'), findsOneWidget);

    // Filter by Alta (≥80%)
    await tester.tap(find.text('Alta (≥80%)'));
    await tester.pumpAndSettle();

    expect(find.text('Amoxicilina'), findsOneWidget);
    expect(find.text('Paracetamol'), findsNothing);

    // Filter by Baja (<50%)
    await tester.tap(find.text('Baja (<50%)'));
    await tester.pumpAndSettle();

    expect(find.text('Amoxicilina'), findsNothing);
    expect(find.text('Paracetamol'), findsOneWidget);

    // Reset to Todos
    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    expect(find.text('Amoxicilina'), findsOneWidget);
    expect(find.text('Paracetamol'), findsOneWidget);
  });

  testWidgets('DetalleRecetaPage without horaDosis does not show fake dose or notificada status', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final t = createSampleTreatment(id: 't1', name: 'Cehalexina');

    await tester.pumpWidget(
      buildTestApp(
        DetalleRecetaPage(
          tratamiento: t,
          canEdit: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify treatment details are shown
    expect(find.text('Cehalexina'), findsWidgets);
    expect(find.text('MEDICAMENTO'), findsOneWidget);

    // Verify edit button in AppBar is hidden when canEdit: false
    expect(find.byIcon(Icons.edit_outlined), findsNothing);

    // Verify finished treatment banner is NOT displayed
    expect(find.text('TRATAMIENTO FINALIZADO'), findsNothing);
    expect(find.text('No hay más dosis programadas.'), findsNothing);

    // Verify fake dose banner, Notificada badge, and bottom action bar are NOT displayed
    expect(find.text('HORA DE ESTA TOMA'), findsNothing);
    expect(find.text('Notificada'), findsNothing);
    expect(find.text('Tomar'), findsNothing);
    expect(find.text('Aplazar'), findsNothing);
    expect(find.text('Omitir'), findsNothing);
  });
}
