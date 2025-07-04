// lib/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meditime/enums/view_state.dart';
import 'package:meditime/screens/shared/loading_screen.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/notification_service.dart';
// Importa el notifier
import 'package:meditime/notifiers/profile_notifier.dart';

// Importar pantallas
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
          // En lugar de una pantalla completa, usamos el widget de estado
          return const Scaffold(body: EstadoVista(state: ViewState.loading, child: SizedBox.shrink()));
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          final firestoreService = context.read<FirestoreService>();
          final profileNotifier = context.read<ProfileNotifier>();
          
        if (profileNotifier.userName == null) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: firestoreService.getUserProfile(user.uid).then((doc) => doc.data() as Map<String, dynamic>?),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen();
              }
              
              if (profileSnapshot.hasError) {
                return const Scaffold(body: Center(child: Text('Error al cargar el perfil.')));
              }

              final profileData = profileSnapshot.data;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  profileNotifier.updateProfile(
                    newName: profileData?['name'] as String?,
                    newImageUrl: profileData?['profileImage'] as String?,
                  );
                  NotificationService.reactivateAlarmsForUser(user.uid);
                }
              });
              return const HomePage();
            },
          );
        } else {
            return const HomePage();
          }
        }
        return const LoginPage();
      },
    );
  }
}