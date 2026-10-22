import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meditime/widgets/drawer_widget.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/notifiers/subscription_notifier.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/services/firestore_service.dart';

class MockFirestoreService extends Fake implements FirestoreService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildDrawerApp({required bool isDark, bool isAnimal = false, bool isCaregiver = false}) {
    AppTheme.updateThemeColors(
      isDark,
      isAnimalMode: isAnimal,
      isCaregiverMode: isCaregiver,
    );

    final prefService = PreferenceService();
    final prefNotifier = PreferenceNotifier(prefService);
    final profileNotifier = ProfileNotifier();
    final caregiverNotifier = CaregiverNotifier(prefService, MockFirestoreService());
    final subscriptionNotifier = SubscriptionNotifier();

    final themeData = isDark ? AppTheme.getDarkTheme() : AppTheme.getLightTheme();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferenceNotifier>.value(value: prefNotifier),
        ChangeNotifierProvider<ProfileNotifier>.value(value: profileNotifier),
        ChangeNotifierProvider<CaregiverNotifier>.value(value: caregiverNotifier),
        ChangeNotifierProvider<SubscriptionNotifier>.value(value: subscriptionNotifier),
      ],
      child: MaterialApp(
        theme: themeData,
        home: Scaffold(
          body: const SizedBox(),
          drawer: CustomDrawer(
            onLogout: () {},
          ),
        ),
      ),
    );
  }

  group('Drawer Theme Consistency Tests', () {
    test('AppTheme drawerTheme backgroundColor matches AppTheme.backgroundColor', () {
      AppTheme.updateThemeColors(false);
      final lightTheme = AppTheme.getLightTheme();
      expect(lightTheme.drawerTheme.backgroundColor, AppTheme.backgroundColor);

      AppTheme.updateThemeColors(true);
      final darkTheme = AppTheme.getDarkTheme();
      expect(darkTheme.drawerTheme.backgroundColor, AppTheme.backgroundColor);
    });

    testWidgets('CustomDrawer background matches AppTheme.backgroundColor in Dark Mode', (tester) async {
      await tester.pumpWidget(buildDrawerApp(isDark: true));

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      final drawer = tester.widget<Drawer>(find.byType(Drawer));
      expect(drawer.backgroundColor, AppTheme.backgroundColor);
      expect(drawer.backgroundColor, const Color(0xFF111318));
    });

    testWidgets('CustomDrawer background matches AppTheme.backgroundColor in Light Mode', (tester) async {
      await tester.pumpWidget(buildDrawerApp(isDark: false));

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      final drawer = tester.widget<Drawer>(find.byType(Drawer));
      expect(drawer.backgroundColor, AppTheme.backgroundColor);
      expect(drawer.backgroundColor, const Color(0xFFF8F9FF));
    });
  });
}
