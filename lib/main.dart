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
// --- INICIO DEL CAMBIO ---
// Importa el nuevo servicio de preferencias
import 'package:meditime/services/preference_service.dart';
// --- FIN DEL CAMBIO ---
import 'package:meditime/notifiers/profile_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.initializeCore();
  await NotificationService.requestAllNecessaryPermissions();
  await AndroidAlarmManager.initialize();
  await initializeDateFormatting('es_ES', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Proveedores para los servicios
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<StorageService>(create: (_) => StorageService()),
        // --- INICIO DEL CAMBIO ---
        // Añade el proveedor para tu nuevo servicio de preferencias
        Provider<PreferenceService>(create: (_) => PreferenceService()),
        // --- FIN DEL CAMBIO ---

        ChangeNotifierProvider<ProfileNotifier>(
          create: (_) => ProfileNotifier(),
        ),
      ],
      child: MaterialApp(
        title: 'MediTime',
        // --- INICIO DE LA MODIFICACIÓN: Tema global completo ---
        theme: ThemeData(
          // 1. Definimos el esquema de color
          colorScheme: ColorScheme.fromSeed(
            // Usamos nuestro color primario como "semilla"
            seedColor: kSecondaryColor, 
            // Opcional: podemos definir un color de fondo ligeramente diferente si queremos
            background: const Color.fromARGB(255, 241, 241, 241),
          ),
          
          useMaterial3: true,
          
          // 3. Mantenemos las personalizaciones que ya tenías
          scaffoldBackgroundColor: const Color.fromARGB(255, 241, 241, 241),
          appBarTheme: const AppBarTheme(
            color: Color.fromARGB(255, 241, 241, 241),
          ),
        ),
        // --- FIN DE LA MODIFICACIÓN ---
        home: const AuthWrapper(),
      ),
    );
  }
}