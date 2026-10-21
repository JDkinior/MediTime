import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/widgets/pill_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PillIcon Widget Tests', () {
    testWidgets('renders CustomPaint with default size and specified color', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: PillIcon(color: Colors.blue))),
        ),
      );

      final sizedBoxFinder = find.byType(SizedBox);
      expect(sizedBoxFinder, findsWidgets);

      final customPaintFinder = find.byType(CustomPaint);
      expect(customPaintFinder, findsWidgets);

      final pillIconFinder = find.byType(PillIcon);
      expect(pillIconFinder, findsOneWidget);

      final pillIcon = tester.widget<PillIcon>(pillIconFinder);
      expect(pillIcon.size, 14.0);
      expect(pillIcon.color, Colors.blue);
    });

    testWidgets('renders with custom size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: PillIcon(size: 24, color: Colors.red)),
          ),
        ),
      );

      final pillIconFinder = find.byType(PillIcon);
      expect(pillIconFinder, findsOneWidget);

      final pillIcon = tester.widget<PillIcon>(pillIconFinder);
      expect(pillIcon.size, 24.0);
      expect(pillIcon.color, Colors.red);

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(of: pillIconFinder, matching: find.byType(SizedBox)),
      );
      expect(sizedBox.width, 24.0);
      expect(sizedBox.height, 24.0);
    });
  });

  group('TabletIcon & SachetIcon Widget Tests', () {
    testWidgets('renders TabletIcon properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: TabletIcon(color: Colors.green))),
        ),
      );

      expect(find.byType(TabletIcon), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders SachetIcon properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: SachetIcon(color: Colors.purple))),
        ),
      );

      expect(find.byType(SachetIcon), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('MedicationPresentationIcon Widget Tests', () {
    testWidgets('renders SachetIcon for Sobres and Sachets', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MedicationPresentationIcon(
                presentation: 'Sobres',
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SachetIcon), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MedicationPresentationIcon(
                presentation: '1 Sachets',
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SachetIcon), findsOneWidget);
    });

    testWidgets('renders science icon for Suspensiones', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MedicationPresentationIcon(
                presentation: 'Suspensiones',
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.science_outlined), findsOneWidget);
    });

    testWidgets('renders medication liquid icon for Jarabes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MedicationPresentationIcon(
                presentation: 'Jarabes',
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.medication_liquid_rounded), findsOneWidget);
    });

    testWidgets('renders water drop icon for Gotas', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MedicationPresentationIcon(
                presentation: 'Gotas',
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
    });

    testWidgets('renders TabletIcon for Comprimidos and Grageas', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MedicationPresentationIcon(
                presentation: 'Comprimidos',
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(TabletIcon), findsOneWidget);
    });

    testWidgets('renders PillIcon for Cápsulas and unknown fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MedicationPresentationIcon(
                presentation: 'Cápsulas',
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(PillIcon), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MedicationPresentationIcon(
                presentation: 'Otro',
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(PillIcon), findsOneWidget);
    });
  });
}
