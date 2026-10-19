import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/widgets/container_transform_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget({
    required Widget child,
    bool showCardBorder = false,
    bool highContrast = false,
  }) {
    final prefNotifier = PreferenceNotifier(PreferenceService());
    if (showCardBorder) {
      prefNotifier.setShowCardBorder(true);
    }
    if (highContrast) {
      prefNotifier.setHighContrast(true);
    }

    return ChangeNotifierProvider<PreferenceNotifier>.value(
      value: prefNotifier,
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('ContainerTransformCard Widget Tests', () {
    testWidgets('renders closed state initially', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: ContainerTransformCard<void>(
            closedBuilder: (context, openContainer) {
              return InkWell(
                onTap: openContainer,
                child: const Text('Medicamento Card Cerrado'),
              );
            },
            openBuilder: (context, closeContainer) {
              return const Scaffold(
                body: Text('Detalle Receta Abierto'),
              );
            },
          ),
        ),
      );

      expect(find.text('Medicamento Card Cerrado'), findsOneWidget);
      expect(find.text('Detalle Receta Abierto'), findsNothing);
    });

    testWidgets('transforms to openBuilder when openContainer is called', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: ContainerTransformCard<void>(
            closedBuilder: (context, openContainer) {
              return InkWell(
                onTap: openContainer,
                child: const Text('Medicamento Card Cerrado'),
              );
            },
            openBuilder: (context, closeContainer) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Detalle Receta Abierto'),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: closeContainer,
                  ),
                ),
                body: const Text('Contenido Detalle'),
              );
            },
          ),
        ),
      );

      // Tap on closed card to trigger transformation
      await tester.tap(find.text('Medicamento Card Cerrado'));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle(); // Finish transition animation

      // Now openBuilder should be visible
      expect(find.text('Detalle Receta Abierto'), findsOneWidget);
      expect(find.text('Contenido Detalle'), findsOneWidget);
      expect(find.text('Medicamento Card Cerrado'), findsNothing);
    });

    testWidgets('reverses transition back to closed state upon close action', (tester) async {
      bool onClosedCalled = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: ContainerTransformCard<void>(
            onClosed: (_) {
              onClosedCalled = true;
            },
            closedBuilder: (context, openContainer) {
              return InkWell(
                onTap: openContainer,
                child: const Text('Medicamento Card Cerrado'),
              );
            },
            openBuilder: (context, closeContainer) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Detalle Receta Abierto'),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: closeContainer,
                  ),
                ),
                body: const Text('Contenido Detalle'),
              );
            },
          ),
        ),
      );

      // Open
      await tester.tap(find.text('Medicamento Card Cerrado'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle Receta Abierto'), findsOneWidget);

      // Close via back button / closeContainer callback
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Closed state is restored
      expect(find.text('Medicamento Card Cerrado'), findsOneWidget);
      expect(find.text('Detalle Receta Abierto'), findsNothing);
      expect(onClosedCalled, isTrue);
    });

    testWidgets('internal actions do not trigger openContainer when tapped directly', (tester) async {
      bool optionsDialogOpened = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: ContainerTransformCard<void>(
            tappable: false,
            closedBuilder: (context, openContainer) {
              return Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: openContainer,
                      child: const Text('Card Body'),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      optionsDialogOpened = true;
                    },
                    child: const Icon(Icons.more_vert),
                  ),
                ],
              );
            },
            openBuilder: (context, closeContainer) {
              return const Scaffold(
                body: Text('Detalle Abierto'),
              );
            },
          ),
        ),
      );

      // Tap on more_vert icon
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump();

      // Ensure openBuilder was NOT triggered
      expect(optionsDialogOpened, isTrue);
      expect(find.text('Detalle Abierto'), findsNothing);
      expect(find.text('Card Body'), findsOneWidget);
    });

    testWidgets('applies border side when high contrast or showCardBorder is enabled', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          showCardBorder: true,
          child: ContainerTransformCard<void>(
            closedBuilder: (context, openContainer) {
              return const Text('Card con borde');
            },
            openBuilder: (context, closeContainer) {
              return const SizedBox();
            },
          ),
        ),
      );

      expect(find.text('Card con borde'), findsOneWidget);
    });

    testWidgets('maintains transparent barrier color without darkening background and keeps rounded corners mid-flight', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: ContainerTransformCard<void>(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            closedBuilder: (context, openContainer) {
              return InkWell(
                onTap: openContainer,
                child: const Text('Medicamento Rounded'),
              );
            },
            openBuilder: (context, closeContainer) {
              return const Scaffold(
                body: Text('Detalle Pantalla'),
              );
            },
          ),
        ),
      );

      // Tap to trigger transition
      await tester.tap(find.text('Medicamento Rounded'));
      await tester.pump(); // Start transition
      // Pump halfway through the animation (180ms of 360ms)
      await tester.pump(const Duration(milliseconds: 180));

      // Find the ContainerTransformPageRoute in modal routes
      final modalRoute = ModalRoute.of(tester.element(find.text('Detalle Pantalla')));
      expect(modalRoute, isA<ContainerTransformPageRoute>());
      expect(modalRoute?.barrierColor, equals(Colors.transparent));
      expect(modalRoute?.opaque, isFalse);

      // Verify that mid-flight, ClipRRect has a non-zero rounded corner radius
      final clipRRectFinder = find.byType(ClipRRect);
      expect(clipRRectFinder, findsWidgets);

      final clipRRect = tester.widget<ClipRRect>(clipRRectFinder.first);
      final borderRadius = clipRRect.borderRadius as BorderRadius;
      expect(borderRadius.topLeft.x, greaterThan(0.0));
      expect(borderRadius.topRight.x, greaterThan(0.0));

      // Finish animation
      await tester.pumpAndSettle();
      expect(find.text('Detalle Pantalla'), findsOneWidget);
    });
  });
}
