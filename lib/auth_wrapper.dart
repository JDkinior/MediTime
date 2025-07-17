// lib/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meditime/screens/shared/loading_screen.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/notification_service.dart';
// Importa el notifier
import 'package:meditime/notifiers/profile_notifier.dart';

// Importar pantallas
import 'package:meditime/screens/auth/login_page.dart';
import 'package:meditime/screens/home/home_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _initialSetupDone = false;

  Future<void> _performInitialSetup(User user, BuildContext context) async {
    // Evita que se ejecute múltiples veces
    if (_initialSetupDone) return;

    final profileNotifier = context.read<ProfileNotifier>();
    final firestoreService = context.read<FirestoreService>();

    // 1. Reactivar las alarmas incondicionalmente en cada inicio de sesión.
    // Esto es crucial para restaurar las alarmas si la app fue terminada.
    await NotificationService.reactivateAlarmsForUser(user.uid);
    debugPrint("AuthWrapper: Alarmas reactivadas para el usuario ${user.uid}");

    // 2. Cargar el perfil del usuario solo si aún no está en el Notifier.
    if (profileNotifier.userName == null) {
      debugPrint("AuthWrapper: Cargando perfil de usuario...");
      try {
        final doc = await firestoreService.getUserProfile(user.uid);
        final profileData = doc.data() as Map<String, dynamic>?;

        // Usamos `mounted` para asegurarnos de que el widget todavía está en el árbol.
        if (mounted) {
          profileNotifier.updateProfile(
            newName: profileData?['name'] as String?,
            newImageUrl: profileData?['profileImage'] as String?,
          );
          debugPrint("AuthWrapper: Perfil de usuario cargado.");
        }
      } catch (e) {
        debugPrint("AuthWrapper: Error al cargar el perfil de usuario: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al cargar los datos del perfil.')),
          );
        }
      }
    }
    
    // Marcamos que la configuración inicial ya se realizó.
    setState(() {
      _initialSetupDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Mientras se determina el estado de autenticación, mostramos un loader.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        final user = snapshot.data;

        // Si el usuario ha iniciado sesión
        if (user != null) {
          // Si la configuración inicial (reactivación de alarmas y carga de perfil)
          // aún no se ha completado, mostramos un loader mientras se ejecuta.
          if (!_initialSetupDone) {
            return FutureBuilder(
              future: _performInitialSetup(user, context),
              builder: (context, setupSnapshot) {
                // Durante la configuración, seguimos mostrando el loader.
                if (setupSnapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingScreen();
                }
                // Si hubo un error durante la configuración, lo mostramos.
                if (setupSnapshot.hasError) {
                  return const Scaffold(
                    body: Center(
                      child: Text('Ocurrió un error al configurar la sesión.'),
                    ),
                  );
                }
                // Una vez completada la configuración, vamos a la HomePage.
                return const HomePage();
              },
            );
          }
          // Si la configuración ya se hizo, vamos directamente a la HomePage.
          return const HomePage();
        }

        // Si el usuario no ha iniciado sesión, reiniciamos el estado
        // de `_initialSetupDone` para la próxima vez que alguien inicie sesión.
        _initialSetupDone = false;
        return const LoginPage();
      },
    );
  }
}
