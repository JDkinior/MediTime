import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/screens/shared/idioma_opciones_page.dart';
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
      home: const IdiomaOpcionesPage(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Displays native language names (endonyms) and no country flags in Spanish', (tester) async {
    final notifier = PreferenceNotifier(PreferenceService());
    await tester.pumpWidget(createTestWidget(notifier: notifier, locale: const Locale('es')));
    await tester.pumpAndSettle();

    // Verify endonyms are displayed
    expect(find.text('Español'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Português'), findsOneWidget);

    // Verify language code badges
    expect(find.text('ES'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('PT'), findsOneWidget);

    // Verify flags are NOT present
    expect(find.text('🇪🇸'), findsNothing);
    expect(find.text('🇺🇸'), findsNothing);
    expect(find.text('🇧🇷'), findsNothing);
  });

  testWidgets('Displays endonyms in English locale with English descriptions', (tester) async {
    final notifier = PreferenceNotifier(PreferenceService());
    await tester.pumpWidget(createTestWidget(notifier: notifier, locale: const Locale('en')));
    await tester.pumpAndSettle();

    // Verify endonyms are displayed even when English is active
    expect(find.text('Español'), findsOneWidget);
    expect(find.text('English'), findsNWidgets(2)); // Title and description
    expect(find.text('Português'), findsOneWidget); // Endonym title!

    // Descriptions in English
    expect(find.text('Spanish (default)'), findsOneWidget);
    expect(find.text('Portuguese'), findsOneWidget);

    // Language code badges
    expect(find.text('ES'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('PT'), findsOneWidget);

    // Verify flags are NOT present
    expect(find.text('🇪🇸'), findsNothing);
    expect(find.text('🇺🇸'), findsNothing);
    expect(find.text('🇧🇷'), findsNothing);
  });

  testWidgets('Displays endonyms in Portuguese locale', (tester) async {
    final notifier = PreferenceNotifier(PreferenceService());
    await tester.pumpWidget(createTestWidget(notifier: notifier, locale: const Locale('pt')));
    await tester.pumpAndSettle();

    // Verify endonyms are displayed even when Portuguese is active
    expect(find.text('Español'), findsOneWidget); // Endonym title!
    expect(find.text('English'), findsOneWidget); // Endonym title!
    expect(find.text('Português'), findsNWidgets(2)); // Title and description

    // Descriptions in Portuguese
    expect(find.text('Espanhol (padrão)'), findsOneWidget);
    expect(find.text('Inglês'), findsOneWidget);

    // Language code badges
    expect(find.text('ES'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('PT'), findsOneWidget);

    // Verify flags are NOT present
    expect(find.text('🇪🇸'), findsNothing);
    expect(find.text('🇺🇸'), findsNothing);
    expect(find.text('🇧🇷'), findsNothing);
  });

  testWidgets('Tapping a language card changes the language', (tester) async {
    final notifier = PreferenceNotifier(PreferenceService());
    await tester.pumpWidget(createTestWidget(notifier: notifier, locale: const Locale('es')));
    await tester.pumpAndSettle();

    // Tap on English option
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(notifier.languageCode, 'en');
  });
}
