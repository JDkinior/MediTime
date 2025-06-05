// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meditime/notification_service.dart';
import 'auth_wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart'; // <--- AÑADIR
// Importa el archivo donde definirás tu callback (ver paso 3)


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 1. Inicializar el núcleo del servicio de notificaciones (SIN pedir permisos)
  await NotificationService.initializeCore();
  
  // 2. Solicitar permisos (DESDE EL ISOLATE PRINCIPAL)
  // Esto solo se hará una vez si _permissionsHaveBeenRequested es true.
  await NotificationService.requestAllNecessaryPermissions(); 
  
  await AndroidAlarmManager.initialize();
  await initializeDateFormatting('es_ES', null);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediTime',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromARGB(255, 241, 241, 241),
        appBarTheme: const AppBarTheme(
          color: Color.fromARGB(255, 241, 241, 241),
        ),
      ),
      home: const AuthWrapper(), //
    );
  }
}