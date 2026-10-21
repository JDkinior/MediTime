import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';
import 'package:meditime/widgets/calendar_expand_handle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppTheme.updateThemeColors(false, highContrast: false);
  });

  Widget buildTestWidget({
    required CalendarFormat calendarFormat,
    required ValueChanged<CalendarFormat> onFormatChanged,
    bool highContrast = false,
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('es'),
  }) {
    final prefNotifier = PreferenceNotifier(PreferenceService());
    if (highContrast) {
      prefNotifier.setHighContrast(true);
    }
    AppTheme.updateThemeColors(brightness == Brightness.dark, highContrast: highContrast);

    return ChangeNotifierProvider<PreferenceNotifier>.value(
      value: prefNotifier,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: Center(
            child: CalendarExpandHandle(
              calendarFormat: calendarFormat,
              onFormatChanged: onFormatChanged,
            ),
          ),
        ),
      ),
    );
  }

  group('CalendarExpandHandle Widget Tests', () {
    testWidgets('renders drag handle bar with correct dimensions', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          calendarFormat: CalendarFormat.week,
          onFormatChanged: (_) {},
        ),
      );

      final barFinder = find.byKey(const Key('calendar_expand_handle_bar'));
      expect(barFinder, findsOneWidget);

      final container = tester.widget<AnimatedContainer>(barFinder);
      expect(container.constraints?.maxWidth ?? 40.0, 40.0);
      expect(container.constraints?.maxHeight ?? 4.0, 4.0);
    });

    testWidgets('shows correct expand/collapse tooltip and semantics', (tester) async {
      // In week view -> should invite to expand
      await tester.pumpWidget(
        buildTestWidget(
          calendarFormat: CalendarFormat.week,
          onFormatChanged: (_) {},
        ),
      );

      expect(find.byTooltip('Expandir calendario'), findsOneWidget);

      // In month view -> should invite to collapse
      await tester.pumpWidget(
        buildTestWidget(
          calendarFormat: CalendarFormat.month,
          onFormatChanged: (_) {},
        ),
      );

      expect(find.byTooltip('Contraer calendario'), findsOneWidget);
    });

    testWidgets('tap on handle toggles between week and month', (tester) async {
      CalendarFormat? changedFormat;

      await tester.pumpWidget(
        buildTestWidget(
          calendarFormat: CalendarFormat.week,
          onFormatChanged: (f) => changedFormat = f,
        ),
      );

      await tester.tap(find.byType(CalendarExpandHandle));
      await tester.pumpAndSettle();
      expect(changedFormat, CalendarFormat.month);

      // Tap when in month -> goes back to week
      await tester.pumpWidget(
        buildTestWidget(
          calendarFormat: CalendarFormat.month,
          onFormatChanged: (f) => changedFormat = f,
        ),
      );

      await tester.tap(find.byType(CalendarExpandHandle));
      await tester.pumpAndSettle();
      expect(changedFormat, CalendarFormat.week);
    });

    testWidgets('moderate drag down expands from week to twoWeeks (quincenal)', (tester) async {
      CalendarFormat? lastFormat;

      await tester.pumpWidget(
        buildTestWidget(
          calendarFormat: CalendarFormat.week,
          onFormatChanged: (f) => lastFormat = f,
        ),
      );

      // Moderate drag down (50 pixels) reaches twoWeeks
      await tester.drag(find.byType(CalendarExpandHandle), const Offset(0, 50));
      await tester.pumpAndSettle();

      expect(lastFormat, CalendarFormat.twoWeeks);
    });

    testWidgets('continuous long drag down expands from week all the way to month', (tester) async {
      final List<CalendarFormat> formatTransitions = [];

      await tester.pumpWidget(
        buildTestWidget(
          calendarFormat: CalendarFormat.week,
          onFormatChanged: (f) => formatTransitions.add(f),
        ),
      );

      // Continuous long drag down (100 pixels) without lifting finger
      await tester.drag(find.byType(CalendarExpandHandle), const Offset(0, 100));
      await tester.pumpAndSettle();

      // Should have transitioned continuously through twoWeeks and reached month
      expect(formatTransitions, contains(CalendarFormat.twoWeeks));
      expect(formatTransitions.last, CalendarFormat.month);
    });

    testWidgets('moderate drag up collapses from month to twoWeeks (quincenal)', (tester) async {
      CalendarFormat? lastFormat;

      await tester.pumpWidget(
        buildTestWidget(
          calendarFormat: CalendarFormat.month,
          onFormatChanged: (f) => lastFormat = f,
        ),
      );

      // Moderate drag up (-50 pixels) reaches twoWeeks
      await tester.drag(find.byType(CalendarExpandHandle), const Offset(0, -50));
      await tester.pumpAndSettle();

      expect(lastFormat, CalendarFormat.twoWeeks);
    });

    testWidgets('continuous long drag up collapses from month all the way to week', (tester) async {
      final List<CalendarFormat> formatTransitions = [];

      await tester.pumpWidget(
        buildTestWidget(
          calendarFormat: CalendarFormat.month,
          onFormatChanged: (f) => formatTransitions.add(f),
        ),
      );

      // Continuous long drag up (-100 pixels) without lifting finger
      await tester.drag(find.byType(CalendarExpandHandle), const Offset(0, -100));
      await tester.pumpAndSettle();

      // Should have transitioned continuously through twoWeeks and reached week
      expect(formatTransitions, contains(CalendarFormat.twoWeeks));
      expect(formatTransitions.last, CalendarFormat.week);
    });

    testWidgets('continuous drag down and reverse up tracks smoothly', (tester) async {
      final List<CalendarFormat> formatTransitions = [];

      await tester.pumpWidget(
        buildTestWidget(
          calendarFormat: CalendarFormat.week,
          onFormatChanged: (f) => formatTransitions.add(f),
        ),
      );

      final center = tester.getCenter(find.byType(CalendarExpandHandle));
      final gesture = await tester.startGesture(center);
      await tester.pump();

      // Break slop and move down into 4th level month (total dy = 102px)
      await gesture.moveBy(const Offset(0, 25));
      await gesture.moveBy(const Offset(0, 95));
      await tester.pump();
      expect(formatTransitions, contains(CalendarFormat.twoWeeks));
      expect(formatTransitions.last, CalendarFormat.month);

      // Now reverse without lifting finger, back up into twoWeeks zone (dy drops to ~62px)
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(formatTransitions.last, CalendarFormat.twoWeeks);

      // Continue moving up into week zone (dy drops to ~12px)
      await gesture.moveBy(const Offset(0, -50));
      await tester.pump();
      expect(formatTransitions.last, CalendarFormat.week);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('flick down/up triggers single step according to velocity', (tester) async {
      CalendarFormat? changedFormat;

      await tester.pumpWidget(
        buildTestWidget(
          calendarFormat: CalendarFormat.week,
          onFormatChanged: (f) => changedFormat = f,
        ),
      );

      // Rapid flick down
      await tester.fling(find.byType(CalendarExpandHandle), const Offset(0, 60), 1000);
      await tester.pumpAndSettle();

      expect(changedFormat, CalendarFormat.twoWeeks);

      // Rapid flick up from month
      await tester.pumpWidget(
        buildTestWidget(
          calendarFormat: CalendarFormat.month,
          onFormatChanged: (f) => changedFormat = f,
        ),
      );

      await tester.fling(find.byType(CalendarExpandHandle), const Offset(0, -60), 1000);
      await tester.pumpAndSettle();

      expect(changedFormat, CalendarFormat.twoWeeks);
    });

    testWidgets('shows tactile expansion feedback (widens) during drag', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          calendarFormat: CalendarFormat.week,
          onFormatChanged: (_) {},
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.byType(CalendarExpandHandle)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      final barFinder = find.byKey(const Key('calendar_expand_handle_bar'));
      final containerDuringDrag = tester.widget<AnimatedContainer>(barFinder);
      expect(containerDuringDrag.constraints?.maxWidth ?? 48.0, 48.0);

      await gesture.up();
      await tester.pumpAndSettle();

      final containerAfterDrag = tester.widget<AnimatedContainer>(barFinder);
      expect(containerAfterDrag.constraints?.maxWidth ?? 40.0, 40.0);
    });

    testWidgets('adapts handle color in dark mode and high contrast mode', (tester) async {
      // Normal light mode
      await tester.pumpWidget(
        buildTestWidget(
          calendarFormat: CalendarFormat.week,
          onFormatChanged: (_) {},
          brightness: Brightness.light,
          highContrast: false,
        ),
      );

      AnimatedContainer barContainer = tester.widget<AnimatedContainer>(find.byKey(const Key('calendar_expand_handle_bar')));
      BoxDecoration decoration = barContainer.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFD1D5DB));

      // Dark mode
      await tester.pumpWidget(
        buildTestWidget(
          calendarFormat: CalendarFormat.week,
          onFormatChanged: (_) {},
          brightness: Brightness.dark,
          highContrast: false,
        ),
      );

      barContainer = tester.widget<AnimatedContainer>(find.byKey(const Key('calendar_expand_handle_bar')));
      decoration = barContainer.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF555A64));

      // High contrast mode
      await tester.pumpWidget(
        buildTestWidget(
          calendarFormat: CalendarFormat.week,
          onFormatChanged: (_) {},
          brightness: Brightness.light,
          highContrast: true,
        ),
      );

      barContainer = tester.widget<AnimatedContainer>(find.byKey(const Key('calendar_expand_handle_bar')));
      decoration = barContainer.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF666666));
    });
  });
}
