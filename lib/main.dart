// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'auth_wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

// Importa tus nuevos servicios
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/storage_service.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/notifiers/treatment_form_notifier.dart';
import 'package:meditime/notifiers/calendar_notifier.dart';
import 'package:meditime/services/treatment_service.dart';
import 'package:meditime/services/lazy_treatment_service.dart';

// Importa repositorios y casos de uso
import 'package:meditime/repositories/treatment_repository.dart';
import 'package:meditime/repositories/firestore_treatment_repository.dart';
import 'package:meditime/repositories/user_repository.dart';
import 'package:meditime/repositories/firestore_user_repository.dart';
import 'package:meditime/use_cases/sign_out_use_case.dart';
import 'package:meditime/use_cases/load_user_profile_use_case.dart';

/// Punto de entrada principal de la aplicación.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService.initializeCore();
  await NotificationService.requestAllNecessaryPermissions();
  await AndroidAlarmManager.initialize();
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

        // Notifier providers
        ChangeNotifierProvider<ProfileNotifier>(
          create: (_) => ProfileNotifier(),
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
      ],
      child: MaterialApp(
        title: 'MediTime',
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
      ),
    );
  }
}
