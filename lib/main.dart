// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';
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
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/services/treatment_service.dart';
import 'package:meditime/services/lazy_treatment_service.dart';
import 'package:meditime/services/subscription_service.dart';
import 'package:meditime/notifiers/subscription_notifier.dart';

// Importa repositorios y casos de uso
import 'package:meditime/repositories/treatment_repository.dart';
import 'package:meditime/repositories/firestore_treatment_repository.dart';
import 'package:meditime/repositories/user_repository.dart';
import 'package:meditime/repositories/firestore_user_repository.dart';
import 'package:meditime/use_cases/sign_out_use_case.dart';
import 'package:meditime/use_cases/load_user_profile_use_case.dart';

import 'package:flutter/services.dart';
import 'package:meditime/services/widget_service.dart';

/// Punto de entrada principal de la aplicación.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable edge-to-edge: the system navigation bar becomes transparent
  // so the Scaffold background shows through, adapting to any theme.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Inicializaciones independientes en paralelo para acelerar el arranque (Splash Screen)
  await Future.wait([
    NotificationService.initializeCore(),
    AndroidAlarmManager.initialize(),
    WidgetService.initialize(),
    initializeDateFormatting('es_ES', null),
    initializeDateFormatting('en_US', null),
  ]);

  // Solicitar permisos en segundo plano sin retrasar el pintado de la interfaz
  NotificationService.requestAllNecessaryPermissions();

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
        Provider<GeminiService>(
          create: (_) => GeminiService(),
        ),
        Provider<SubscriptionService>(create: (_) => SubscriptionService()),

        // Notifier providers
        ChangeNotifierProvider<ProfileNotifier>(
          create: (_) => ProfileNotifier(),
        ),
        ChangeNotifierProvider<SubscriptionNotifier>(
          create: (context) {
            final notifier = SubscriptionNotifier();
            final auth = context.read<AuthService>();
            final subService = context.read<SubscriptionService>();
            notifier.listenToUser(auth.currentUser?.uid, subService);
            return notifier;
          },
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
      child: Consumer2<PreferenceNotifier, CaregiverNotifier>(
        builder: (context, preferenceNotifier, caregiverNotifier, child) {
          final themeModeStr = preferenceNotifier.themeMode;
          final isDark = themeModeStr == 'dark' ||
              (themeModeStr == 'system' &&
                  MediaQuery.platformBrightnessOf(context) == Brightness.dark);
          final isAnimal = preferenceNotifier.isAnimalMode || caregiverNotifier.modeType == CaregiverModeType.veterinario;
          final isCaregiver = caregiverNotifier.isCaregiverModeActive && !isAnimal;
          AppTheme.updateThemeColors(
            isDark,
            highContrast: preferenceNotifier.highContrast,
            isAnimalMode: isAnimal,
            isCaregiverMode: isCaregiver,
          );

          return MaterialApp(
            title: 'MediTime',
            navigatorKey: navigatorKey,
            theme: AppTheme.getLightTheme(
              largeButtons: preferenceNotifier.largeButtons,
              showCardBorder: preferenceNotifier.showCardBorder || preferenceNotifier.highContrast,
            ),
            darkTheme: AppTheme.getDarkTheme(
              largeButtons: preferenceNotifier.largeButtons,
              showCardBorder: preferenceNotifier.showCardBorder || preferenceNotifier.highContrast,
            ),
            themeMode: preferenceNotifier.themeModeEnum,
            builder: (context, widget) {
              final mediaQueryData = MediaQuery.of(context);
              final scale = preferenceNotifier.largeText ? 1.3 : 1.0;
              return MediaQuery(
                data: mediaQueryData.copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                // Annotate the entire app so all screens use our overlay style
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
                    systemNavigationBarColor: AppTheme.backgroundColor,
                    systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                    systemNavigationBarDividerColor: Colors.transparent,
                    systemNavigationBarContrastEnforced: false,
                  ),
                  child: Container(
                    color: AppTheme.backgroundColor,
                    child: widget!,
                  ),
                ),
              );
            },
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: preferenceNotifier.locale,
            routes: {ChatBotScreen.routeName: (_) => const ChatBotScreen()},
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}
