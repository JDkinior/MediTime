// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/gemini_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/screens/chat/chat_bot_screen.dart';
import 'package:provider/provider.dart';
import 'auth_wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'package:meditime/core/navigator_key.dart';

// Importa tus nuevos servicios
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/storage_service.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/notifiers/treatment_form_notifier.dart';
import 'package:meditime/notifiers/calendar_notifier.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/services/treatment_service.dart';
import 'package:meditime/services/lazy_treatment_service.dart';

// Importa repositorios y casos de uso
import 'package:meditime/repositories/treatment_repository.dart';
import 'package:meditime/repositories/firestore_treatment_repository.dart';
import 'package:meditime/repositories/user_repository.dart';
import 'package:meditime/repositories/firestore_user_repository.dart';
import 'package:meditime/use_cases/sign_out_use_case.dart';
import 'package:meditime/use_cases/load_user_profile_use_case.dart';

import 'package:meditime/services/widget_service.dart';

/// Punto de entrada principal de la aplicación.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService.initializeCore();
  await NotificationService.requestAllNecessaryPermissions();
  await AndroidAlarmManager.initialize();
  await WidgetService.initialize();
  await initializeDateFormatting('es_ES', null);

  // PRUEBA DE CALLBACKS (comentar después de probar)
  // await NotificationService.checkNotificationCallbacks();

  runApp(const MyApp());
}

/// El widget raíz de la aplicación.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repository providers
        Provider<TreatmentRepository>(
          create: (_) => FirestoreTreatmentRepository(),
        ),
        Provider<UserRepository>(create: (_) => FirestoreUserRepository()),

        // Use case providers
        Provider<SignOutUseCase>(
          create:
              (context) => SignOutUseCase(context.read<TreatmentRepository>()),
        ),
        Provider<LoadUserProfileUseCase>(
          create:
              (context) =>
                  LoadUserProfileUseCase(context.read<UserRepository>()),
        ),

        // Service providers
        Provider<AuthService>(
          create: (context) => AuthService(context.read<SignOutUseCase>()),
        ),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<PreferenceService>(create: (_) => PreferenceService()),
        Provider<TreatmentService>(
          create:
              (context) => TreatmentService(context.read<FirestoreService>()),
        ),
        Provider<LazyTreatmentService>(
          create:
              (context) =>
                  LazyTreatmentService(context.read<FirestoreService>()),
        ),
        Provider<GeminiService>(create: (_) => GeminiService()),

        // Notifier providers
        ChangeNotifierProvider<ProfileNotifier>(
          create: (_) => ProfileNotifier(),
        ),
        ChangeNotifierProvider<PreferenceNotifier>(
          create: (context) => PreferenceNotifier(context.read<PreferenceService>()),
        ),
        ChangeNotifierProvider<TreatmentFormNotifier>(
          create:
              (context) => TreatmentFormNotifier(
                context.read<TreatmentService>(),
                context.read<AuthService>(),
              ),
        ),
        ChangeNotifierProvider<CalendarNotifier>(
          create:
              (context) => CalendarNotifier(
                context.read<LazyTreatmentService>(),
                context.read<FirestoreService>(),
              ),
        ),
        ChangeNotifierProvider<CaregiverNotifier>(
          create:
              (context) => CaregiverNotifier(
                context.read<PreferenceService>(),
                context.read<FirestoreService>(),
              )..loadProfiles(context.read<AuthService>().currentUser?.uid ?? ''),
        ),
      ],
      child: Consumer<PreferenceNotifier>(
        builder: (context, preferenceNotifier, child) {
          final themeModeStr = preferenceNotifier.themeMode;
          final isDark = themeModeStr == 'dark' ||
              (themeModeStr == 'system' &&
                  MediaQuery.platformBrightnessOf(context) == Brightness.dark);
          AppTheme.updateThemeColors(isDark, highContrast: preferenceNotifier.highContrast);

          return MaterialApp(
            title: 'MediTime',
            navigatorKey: navigatorKey,
            theme: AppTheme.getLightTheme(largeButtons: preferenceNotifier.largeButtons),
            darkTheme: AppTheme.getDarkTheme(largeButtons: preferenceNotifier.largeButtons),
            themeMode: preferenceNotifier.themeModeEnum,
            builder: (context, widget) {
              final mediaQueryData = MediaQuery.of(context);
              final scale = preferenceNotifier.largeText ? 1.3 : 1.0;
              return MediaQuery(
                data: mediaQueryData.copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: widget!,
              );
            },
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('es', 'ES'),
            ],
            locale: const Locale('es', 'ES'),
            routes: {ChatBotScreen.routeName: (_) => const ChatBotScreen()},
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}
