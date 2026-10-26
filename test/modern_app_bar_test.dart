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
    PreferenceNotifier? prefNotifier,
  }) {
    final notifier = prefNotifier ?? PreferenceNotifier(PreferenceService());
    if (prefNotifier == null) {
      notifier.setInterfaceStyle('modern');
    }

    return ChangeNotifierProvider<PreferenceNotifier>.value(
      value: notifier,
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

    testWidgets('toolbar remains solid and gradient projects below toolbar when scrolling with fadeExtension', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Scaffold(
            appBar: ModernAppBar(
              fadeExtension: 28.0,
              child: AppBar(title: const Text('Title')),
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

      // Verify Stack has Clip.none because currentExtension > 0
      final stackFinder = find.byWidgetPredicate((w) => w is Stack && w.clipBehavior == Clip.none);
      expect(stackFinder, findsOneWidget);

      // Verify the gradient container is present and positioned at top: totalAppBarHeight
      final gradientFinder = find.byWidgetPredicate(
        (w) => w is Positioned && w.height == 28.0 && w.child is IgnorePointer,
      );
      expect(gradientFinder, findsOneWidget);
    });

    testWidgets('ModernAppBar disables fade when global enableScrollFade is false', (tester) async {
      final notifier = PreferenceNotifier(PreferenceService());
      notifier.setInterfaceStyle('modern');
      notifier.setEnableScrollFade(false);

      await tester.pumpWidget(
        buildTestWidget(
          prefNotifier: notifier,
          child: Scaffold(
            appBar: ModernAppBar(
              fadeExtension: 28.0,
              child: AppBar(title: const Text('Global Toggle Test')),
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

      // Verify no gradient is shown because enableScrollFade is false
      final gradientFinder = find.byWidgetPredicate(
        (w) => w is Positioned && w.height == 28.0 && w.child is IgnorePointer,
      );
      expect(gradientFinder, findsNothing);
    });

    testWidgets('encapsulateOnScroll fades out title and materializes button capsules on scroll', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Scaffold(
            appBar: ModernAppBar(
              encapsulateOnScroll: true,
              child: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {},
                ),
                title: const Text('MediTime'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.face),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            body: ListView.builder(
              itemCount: 50,
              itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
            ),
          ),
        ),
      );

      // Initially at rest: title is fully visible
      final titleOpacityAtRest = tester.widget<Opacity>(
        find.ancestor(of: find.text('MediTime'), matching: find.byType(Opacity)),
      );
      expect(titleOpacityAtRest.opacity, 1.0);

      // Scroll the list
      await tester.drag(find.text('Item 0'), const Offset(0, -200));
      await tester.pumpAndSettle();

      // Scrolled: title opacity is 0.0
      final titleOpacityScrolled = tester.widget<Opacity>(
        find.ancestor(of: find.text('MediTime'), matching: find.byType(Opacity)),
      );
      expect(titleOpacityScrolled.opacity, 0.0);

      // Scrolled: encapsulated circular containers exist with shadow
      final capsuleFinder = find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration && ((w.decoration as BoxDecoration).boxShadow?.isNotEmpty ?? false),
      );
      expect(capsuleFinder, findsWidgets);
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

    testWidgets('ModernContentFade returns child directly when enableScrollFade is false', (tester) async {
      final notifier = PreferenceNotifier(PreferenceService());
      notifier.setInterfaceStyle('modern');
      notifier.setEnableScrollFade(false);

      await tester.pumpWidget(
        buildTestWidget(
          prefNotifier: notifier,
          child: Scaffold(
            body: ModernContentFade(
              child: ListView(
                children: const [Text('Item 1')],
              ),
            ),
          ),
        ),
      );

      // Should not contain a Stack created by ModernContentFade
      final stackFinder = find.descendant(
        of: find.byType(ModernContentFade),
        matching: find.byType(Stack),
      );
      expect(stackFinder, findsNothing);
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('ModernContentFade displays top fade when scrolled down', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Scaffold(
            body: ModernContentFade(
              height: 28,
              child: ListView.builder(
                itemCount: 50,
                itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
              ),
            ),
          ),
        ),
      );

      // Scroll down
      await tester.drag(find.text('Item 0'), const Offset(0, -200));
      await tester.pumpAndSettle();

      // Top fade overlay positioned widget should now exist
      final topFadeFinder = find.byWidgetPredicate(
        (w) => w is Positioned && w.top == 0.0 && w.height == 28.0 && w.child is IgnorePointer,
      );
      expect(topFadeFinder, findsOneWidget);
    });

    testWidgets('ModernContentFade with enableBottomFade shows bottom fade when content exists below', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Scaffold(
            body: ModernContentFade(
              height: 24,
              bottomHeight: 24,
              enableTopFade: true,
              enableBottomFade: true,
              child: ListView.builder(
                itemCount: 50,
                itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Bottom fade overlay positioned widget should be active since extentAfter > 0
      final bottomFadeFinder = find.byWidgetPredicate(
        (w) => w is Positioned && w.bottom == 0.0 && w.height == 24.0 && w.child is IgnorePointer,
      );
      expect(bottomFadeFinder, findsOneWidget);
    });
  });
}
