// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:provider/provider.dart'; // Importa Provider
import 'auth_wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

// Importa tus nuevos servicios
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/storage_service.dart';


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
    // Envuelve MaterialApp con MultiProvider
    return MultiProvider(
      providers: [
        // Proveedor para el servicio de autenticación
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        // Proveedor para el servicio de Firestore
        Provider<FirestoreService>(
          create: (_) => FirestoreService(),
        ),
        // Proveedor para el servicio de Storage
        Provider<StorageService>(
          create: (_) => StorageService(),
        ),
      ],
      child: MaterialApp(
        title: 'MediTime',
        theme: ThemeData(
          scaffoldBackgroundColor: const Color.fromARGB(255, 241, 241, 241),
          appBarTheme: const AppBarTheme(
            color: Color.fromARGB(255, 241, 241, 241),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}