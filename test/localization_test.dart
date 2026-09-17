import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('AppLocalizations loads Spanish strings correctly', (WidgetTester tester) async {
    late BuildContext savedContext;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: Builder(
          builder: (context) {
            savedContext = context;
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(
              body: Column(
                children: [
                  Text(l10n.optionsLanguage),
                  Text(l10n.navPrescription),
                  Text(l10n.languageSpanish),
                ],
              ),
            );
          },
        ),
      ),
    );

    final l10n = AppLocalizations.of(savedContext)!;
    expect(l10n.optionsLanguage, 'Idioma');
    expect(l10n.navPrescription, 'Receta');
    expect(find.text('Idioma'), findsOneWidget);
    expect(find.text('Receta'), findsOneWidget);
  });

  testWidgets('AppLocalizations loads English strings correctly', (WidgetTester tester) async {
    late BuildContext savedContext;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            savedContext = context;
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(
              body: Column(
                children: [
                  Text(l10n.optionsLanguage),
                  Text(l10n.navPrescription),
                  Text(l10n.languageEnglish),
                ],
              ),
            );
          },
        ),
      ),
    );

    final l10n = AppLocalizations.of(savedContext)!;
    expect(l10n.optionsLanguage, 'Language');
    expect(l10n.navPrescription, 'Prescriptions');
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Prescriptions'), findsOneWidget);
  });
}
