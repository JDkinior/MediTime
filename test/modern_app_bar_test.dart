import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/widgets/modern_app_bar.dart';
import 'package:meditime/widgets/modern_content_fade.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'interface_style': 'modern'});
  });

  Widget buildTestWidget({
    required Widget child,
  }) {
    final prefNotifier = PreferenceNotifier(PreferenceService());
    prefNotifier.setInterfaceStyle('modern');

    return ChangeNotifierProvider<PreferenceNotifier>.value(
      value: prefNotifier,
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('ModernAppBar Widget Tests', () {
    testWidgets('renders flat solid background when not scrolled', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Scaffold(
            appBar: ModernAppBar(
              child: AppBar(title: const Text('Test Title')),
            ),
            body: const Center(child: Text('Content')),
          ),
        ),
      );

      // Verify Stack clipBehavior is Clip.hardEdge in resting position
      final stackFinder = find.byWidgetPredicate((w) => w is Stack && w.clipBehavior == Clip.hardEdge);
      expect(stackFinder, findsWidgets);

      // Verify no gradient opacity container is visible at rest
      final opacityFinder = find.byWidgetPredicate(
        (w) => w is Opacity && w.opacity > 0.0 && w.child is Container && (w.child as Container).decoration is BoxDecoration,
      );
      expect(opacityFinder, findsNothing);
    });

    testWidgets('respects showFade: false and renders solid background always', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Scaffold(
            appBar: ModernAppBar(
              showFade: false,
              child: AppBar(title: const Text('No Fade')),
            ),
            body: ListView.builder(
              itemCount: 50,
              itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
            ),
          ),
        ),
      );

      // Scroll the list
      await tester.drag(find.text('Item 0'), const Offset(0, -200));
      await tester.pumpAndSettle();

      // Verify it stays solid with Clip.hardEdge and no gradient
      final stackFinder = find.byWidgetPredicate((w) => w is Stack && w.clipBehavior == Clip.hardEdge);
      expect(stackFinder, findsWidgets);

      final opacityFinder = find.byWidgetPredicate(
        (w) => w is Opacity && w.opacity > 0.0 && w.child is Container && (w.child as Container).decoration is BoxDecoration,
      );
      expect(opacityFinder, findsNothing);
    });

    testWidgets('fadeEnabledNotifier disables fade reactively', (tester) async {
      final notifier = ValueNotifier<bool>(true);

      await tester.pumpWidget(
        buildTestWidget(
          child: Scaffold(
            appBar: ModernAppBar(
              fadeEnabledNotifier: notifier,
              child: AppBar(title: const Text('Notifier Test')),
            ),
            body: const Center(child: Text('Content')),
          ),
        ),
      );

      // Initially at rest: solid
      expect(find.text('Notifier Test'), findsOneWidget);

      // Toggle notifier to false
      notifier.value = false;
      await tester.pumpAndSettle();

      final stackFinder = find.byWidgetPredicate((w) => w is Stack && w.clipBehavior == Clip.hardEdge);
      expect(stackFinder, findsWidgets);
    });
  });

  group('ModernContentFade Widget Tests', () {
    testWidgets('ModernContentFade uses Clip.hardEdge and does not show gradient at rest', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Scaffold(
            body: ModernContentFade(
              child: ListView(
                children: const [Text('Top Item')],
              ),
            ),
          ),
        ),
      );

      final stackFinder = find.descendant(
        of: find.byType(ModernContentFade),
        matching: find.byWidgetPredicate((w) => w is Stack && w.clipBehavior == Clip.hardEdge),
      );
      expect(stackFinder, findsOneWidget);

      // At rest (0 scroll), no fade overlay Positioned exists
      expect(find.byType(Positioned), findsNothing);
    });
  });
}
