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
}
