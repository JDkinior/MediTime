import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/screens/shared/accesibilidad_page.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createTestWidget({
  required PreferenceNotifier notifier,
  Locale locale = const Locale('es'),
}) {
  return ChangeNotifierProvider<PreferenceNotifier>.value(
    value: notifier,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AccesibilidadPage(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Renders Senior preset button and accessibility options in AccesibilidadPage', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final notifier = PreferenceNotifier(PreferenceService());
    await tester.pumpWidget(createTestWidget(notifier: notifier));
    await tester.pumpAndSettle();

    // Verify Page Header
    expect(find.text('Accesibilidad'), findsOneWidget);

    // Verify Senior Preset Button
    expect(find.text('Activar todas las ayudas (Modo Adulto Mayor)'), findsOneWidget);

    // Verify all 5 clean switch options are present
    expect(find.text('Alto Contraste'), findsOneWidget);
    expect(find.text('Texto Grande'), findsOneWidget);
    expect(find.text('Botones Grandes'), findsOneWidget);
    expect(find.text('Borde en tarjetas'), findsOneWidget);
    expect(find.text('Interfaz Simplificada'), findsOneWidget);
  });

  testWidgets('Toggling switches updates preferenceNotifier state live', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final notifier = PreferenceNotifier(PreferenceService());
    await tester.pumpWidget(createTestWidget(notifier: notifier));
    await tester.pumpAndSettle();

    expect(notifier.highContrast, false);
    expect(notifier.largeText, false);
    expect(notifier.largeButtons, false);
    expect(notifier.showCardBorder, false);
    expect(notifier.simplifiedInterface, false);

    // Toggle Alto Contraste
    await tester.tap(find.widgetWithText(SwitchListTile, 'Alto Contraste'));
    await tester.pumpAndSettle();
    expect(notifier.highContrast, true);

    // Toggle Texto Grande
    await tester.tap(find.widgetWithText(SwitchListTile, 'Texto Grande'));
    await tester.pumpAndSettle();
    expect(notifier.largeText, true);

    // Toggle Botones Grandes
    await tester.tap(find.widgetWithText(SwitchListTile, 'Botones Grandes'));
    await tester.pumpAndSettle();
    expect(notifier.largeButtons, true);

    // Toggle Borde en tarjetas
    await tester.tap(find.widgetWithText(SwitchListTile, 'Borde en tarjetas'));
    await tester.pumpAndSettle();
    expect(notifier.showCardBorder, true);

    // Toggle Interfaz Simplificada
    await tester.tap(find.widgetWithText(SwitchListTile, 'Interfaz Simplificada'));
    await tester.pumpAndSettle();
    expect(notifier.simplifiedInterface, true);
  });

  testWidgets('Senior preset button activates and restores all accessibility aids', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final notifier = PreferenceNotifier(PreferenceService());
    await tester.pumpWidget(createTestWidget(notifier: notifier));
    await tester.pumpAndSettle();

    expect(find.text('Activar todas las ayudas (Modo Adulto Mayor)'), findsOneWidget);
    await tester.tap(find.text('Activar todas las ayudas (Modo Adulto Mayor)'));
    await tester.pumpAndSettle();

    expect(notifier.highContrast, true);
    expect(notifier.largeText, true);
    expect(notifier.largeButtons, true);
    expect(notifier.showCardBorder, true);
    expect(notifier.simplifiedInterface, true);
    expect(find.text('Restaurar vista estándar'), findsOneWidget);

    await tester.tap(find.text('Restaurar vista estándar'));
    await tester.pumpAndSettle();

    expect(notifier.highContrast, false);
    expect(notifier.largeText, false);
    expect(notifier.largeButtons, false);
    expect(notifier.showCardBorder, false);
    expect(notifier.simplifiedInterface, false);
    expect(find.text('Activar todas las ayudas (Modo Adulto Mayor)'), findsOneWidget);
  });
}
