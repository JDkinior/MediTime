import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:provider/provider.dart';

// Importa el notifier
import 'package:meditime/notifiers/profile_notifier.dart';

// Importar pantallas
import 'package:meditime/screens/shared/loading_screen.dart';
import 'package:meditime/screens/auth/login_page.dart';
import 'package:meditime/screens/home/home_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          final firestoreService = context.read<FirestoreService>();

          return FutureBuilder<Map<String, dynamic>?>(
            future: firestoreService.getUserProfile(user.uid).then((doc) => doc.data() as Map<String, dynamic>?),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen();
              }
              
              if (profileSnapshot.hasError) {
                return const Scaffold(body: Center(child: Text('Error al cargar el perfil.')));
              }

              // Una vez que tenemos los datos del perfil...
              final profileData = profileSnapshot.data;

              // ----- INICIO DE LA CORRECCIÓN -----
              // Usamos addPostFrameCallback para actualizar el estado DESPUÉS del build.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) { // Verificamos que el contexto aún sea válido
                  context.read<ProfileNotifier>().updateProfile(
                    newName: profileData?['name'] as String?,
                    newImageUrl: profileData?['profileImage'] as String?,
                  );
                }
              });
              // ----- FIN DE LA CORRECCIÓN -----

              // Ya no pasamos los datos directamente a HomePage.
              return const HomePage();
            },
          );
        }

        return const LoginPage();
      },
    );
  }
}