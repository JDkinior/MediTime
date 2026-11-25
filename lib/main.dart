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
import 'package:meditime/services/ai_quota_service.dart';
import 'package:meditime/notifiers/subscription_notifier.dart';

// Importa repositorios y casos de uso
import 'package:meditime/repositories/treatment_repository.dart';
import 'package:meditime/repositories/firestore_treatment_repository.dart';
import 'package:meditime/repositories/user_repository.dart';
import 'package:meditime/repositories/firestore_user_repository.dart';
import 'package:meditime/use_cases/sign_out_use_case.dart';
import 'package:meditime/use_cases/load_user_profile_use_case.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:meditime/services/widget_service.dart';
import 'package:meditime/services/system_settings_service.dart';

/// Punto de entrada principal de la aplicación.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En modo release (producción), silenciar todos los logs para evitar fuga de datos PII/médicos por Logcat
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Enable edge-to-edge: the system navigation bar becomes transparent
  // so the Scaffold background shows through, adapting to any theme.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));

  // Aplicar protección de pantalla (FLAG_SECURE) si el usuario lo tenía habilitado
  try {
    final prefs = PreferenceService();
    final isSecure = await prefs.getSecureScreen();
    if (isSecure) {
      await SystemSettingsService.setSecureScreen(true);
    }
  } catch (_) {}

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Inicializaciones independientes en paralelo para acelerar el arranque (Splash Screen)
  await Future.wait([
    NotificationService.initializeCore(),
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
      AndroidAlarmManager.initialize(),
    WidgetService.initialize(),
    initializeDateFormatting('es_ES', null),
    initializeDateFormatting('en_US', null),
    initializeDateFormatting('pt_BR', null),
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
        Provider<AiQuotaService>(create: (_) => const AiQuotaService()),

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
      child: Selector2<PreferenceNotifier, CaregiverNotifier, _AppThemeConfig>(
        selector: (_, pref, caregiver) => _AppThemeConfig(
          themeModeStr: pref.themeMode,
          themeModeEnum: pref.themeModeEnum,
          highContrast: pref.highContrast,
          isAnimalMode: pref.isAnimalMode,
          largeButtons: pref.largeButtons,
          showCardBorder: pref.showCardBorder,
          interfaceStyle: pref.interfaceStyle,
          largeText: pref.largeText,
          locale: pref.locale,
          isCaregiverModeActive: caregiver.isCaregiverModeActive,
          modeType: caregiver.modeType,
        ),
        builder: (context, config, child) {
          final isDark = config.themeModeStr == 'dark' ||
              (config.themeModeStr == 'system' &&
                  MediaQuery.platformBrightnessOf(context) == Brightness.dark);
          final isAnimal = config.isAnimalMode || config.modeType == CaregiverModeType.veterinario;
          final isCaregiver = config.isCaregiverModeActive && !isAnimal;
          final showCardBorder = config.showCardBorder || config.highContrast;
          final isModern = config.interfaceStyle == 'modern';
          AppTheme.updateThemeColors(
            isDark,
            highContrast: config.highContrast,
            isAnimalMode: isAnimal,
            isCaregiverMode: isCaregiver,
          );

          return MaterialApp(
            title: 'MedDue',
            navigatorKey: navigatorKey,
            theme: AppTheme.getLightTheme(
              largeButtons: config.largeButtons,
              showCardBorder: showCardBorder,
              isModern: isModern,
            ),
            darkTheme: AppTheme.getDarkTheme(
              largeButtons: config.largeButtons,
              showCardBorder: showCardBorder,
              isModern: isModern,
            ),
            themeMode: config.themeModeEnum,
            builder: (context, widget) {
              final mediaQueryData = MediaQuery.of(context);
              final scale = config.largeText ? 1.3 : 1.0;
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
            locale: config.locale,
            routes: {ChatBotScreen.routeName: (_) => const ChatBotScreen()},
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

@immutable
class _AppThemeConfig {
  final String themeModeStr;
  final ThemeMode themeModeEnum;
  final bool highContrast;
  final bool isAnimalMode;
  final bool largeButtons;
  final bool showCardBorder;
  final String interfaceStyle;
  final bool largeText;
  final Locale? locale;
  final bool isCaregiverModeActive;
  final CaregiverModeType modeType;

  const _AppThemeConfig({
    required this.themeModeStr,
    required this.themeModeEnum,
    required this.highContrast,
    required this.isAnimalMode,
    required this.largeButtons,
    required this.showCardBorder,
    required this.interfaceStyle,
    required this.largeText,
    required this.locale,
    required this.isCaregiverModeActive,
    required this.modeType,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AppThemeConfig &&
          themeModeStr == other.themeModeStr &&
          themeModeEnum == other.themeModeEnum &&
          highContrast == other.highContrast &&
          isAnimalMode == other.isAnimalMode &&
          largeButtons == other.largeButtons &&
          showCardBorder == other.showCardBorder &&
          interfaceStyle == other.interfaceStyle &&
          largeText == other.largeText &&
          locale == other.locale &&
          isCaregiverModeActive == other.isCaregiverModeActive &&
          modeType == other.modeType;

  @override
  int get hashCode => Object.hash(
        themeModeStr,
        themeModeEnum,
        highContrast,
        isAnimalMode,
        largeButtons,
        showCardBorder,
        interfaceStyle,
        largeText,
        locale,
        isCaregiverModeActive,
        modeType,
      );
}
