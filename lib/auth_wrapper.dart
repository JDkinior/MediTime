import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:provider/provider.dart';

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
        // Mientras espera la primera data del stream
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        // Si hay un usuario autenticado
        if (snapshot.hasData) {
          final user = snapshot.data!;
          final firestoreService = context.read<FirestoreService>();

          // Usamos un FutureBuilder para cargar los datos del perfil UNA SOLA VEZ.
          return FutureBuilder<Map<String, dynamic>?>(
            // El future solo se llama una vez gracias a que está aquí.
            future: firestoreService.getUserProfile(user.uid).then((doc) => doc.data() as Map<String, dynamic>?),
            builder: (context, profileSnapshot) {
              // Mientras se cargan los datos del perfil
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen();
              }
              
              // Si hubo un error cargando el perfil
              if (profileSnapshot.hasError) {
                return const Scaffold(body: Center(child: Text('Error al cargar el perfil.')));
              }

              // Una vez que tenemos los datos del usuario y el perfil, vamos a HomePage
              final profileData = profileSnapshot.data;
              final nameParts = (profileData?['name'] as String?)?.split(' ');
              final profileImagePath = profileData?['profileImage'] as String?;

              return HomePage(
                nameParts: nameParts,
                profileImagePath: profileImagePath,
              );
            },
          );
        }

        // Si no hay usuario, vamos a la página de login
        return const LoginPage();
      },
    );
  }
}
