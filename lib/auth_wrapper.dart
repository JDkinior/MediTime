// lib/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meditime/screens/shared/loading_screen.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/use_cases/load_user_profile_use_case.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/repositories/user_repository.dart';

// Importar pantallas
import 'package:meditime/screens/auth/login_page.dart';
import 'package:meditime/screens/home/home_page.dart';

/// Un widget "guardián" que controla qué pantalla se muestra al usuario.
///
/// Escucha los cambios en el estado de autenticación de Firebase.
/// - Si el usuario no está autenticado, muestra [LoginPage].
/// - Si el usuario está autenticado, realiza una configuración inicial
///   (reactivar alarmas, cargar perfil) y luego muestra [HomePage].
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _initialSetupDone = false;

  bool _isDeprecatedFirebaseStorageUrl(String? url) {
    return url != null && url.contains('firebasestorage.googleapis.com');
  }

  Future<void> _performInitialSetup(User user) async {
    // Evita que se ejecute múltiples veces
    if (_initialSetupDone) return;

    // Check if widget is still mounted before proceeding
    if (!mounted) return;

    final profileNotifier = context.read<ProfileNotifier>();
    final loadUserProfileUseCase = context.read<LoadUserProfileUseCase>();
    final userRepository = context.read<UserRepository>();

  // Guardar el usuario actual para filtros en callbacks offline
  await PreferenceService().saveCurrentUserId(user.uid);

  // 1. Reactivar las alarmas incondicionalmente en cada inicio de sesión.
    // Esto es crucial para restaurar las alarmas si la app fue terminada.
    await NotificationService.reactivateAlarmsForUser(user.uid);
    debugPrint("AuthWrapper: Alarmas reactivadas para el usuario ${user.uid}");

    // Check mounted state after async operation
    if (!mounted) return;

    // 1.5. Manejar notificaciones pendientes cuando la app se abre
    await NotificationService.handlePendingNotificationActions();
    debugPrint("AuthWrapper: Notificaciones pendientes verificadas");
    
    // Check mounted state after async operation
    if (!mounted) return;
    
  // 1.6. Verificar si hay una notificación que activó la app
    await NotificationService.checkAppLaunchedFromNotification();
    debugPrint("🔍 AuthWrapper: Verificación de lanzamiento por notificación completada");

  // Limpiar lista de tratamientos revocados al iniciar sesión (evitar bloqueos antiguos)
  await PreferenceService().clearRevokedTreatments();

    // Check mounted state after async operation
    if (!mounted) return;

    // 2. Cargar el perfil del usuario solo si aún no está en el Notifier.
    if (profileNotifier.userName == null) {
      debugPrint("AuthWrapper: Cargando perfil de usuario...");
      
      final result = await loadUserProfileUseCase.execute(user.uid);
      
      // Check mounted state after async operation
      if (!mounted) return;
      
      if (result.isSuccess) {
        final profileData = result.data;
        
        // If profile exists in Firestore, use it. Otherwise, import from
        // Firebase user (e.g., Google account) when available.
        String? firestoreImage = profileData?['profileImage'] as String?;
        String? firestoreName = profileData?['name'] as String?;

        if (_isDeprecatedFirebaseStorageUrl(firestoreImage)) {
          firestoreImage = null;
        }

        // If Firestore profile has no image but Firebase user has one (Google),
        // save it to Firestore and use it.
        if ((firestoreImage == null || firestoreImage.isEmpty) && (user.photoURL != null && user.photoURL!.isNotEmpty)) {
          try {
            final saveResult = await userRepository.saveUserProfile(user.uid, {'profileImage': user.photoURL});
            if (saveResult.isSuccess) {
              firestoreImage = user.photoURL;
              debugPrint('AuthWrapper: Foto de Google importada y guardada en Firestore.');
            } else {
              debugPrint('AuthWrapper: Error al guardar foto de Google en Firestore: ${saveResult.error}');
            }
          } catch (e) {
            debugPrint('AuthWrapper: Excepción al intentar guardar foto de Google: $e');
          }
        }

        // Also import displayName from Firebase user if Firestore name is missing
        if ((firestoreName == null || firestoreName.isEmpty) && (user.displayName != null && user.displayName!.isNotEmpty)) {
          try {
            final saveResult = await userRepository.saveUserProfile(user.uid, {'name': user.displayName});
            if (saveResult.isSuccess) {
              firestoreName = user.displayName;
              debugPrint('AuthWrapper: Nombre importado desde la cuenta de Google.');
            } else {
              debugPrint('AuthWrapper: Error al guardar nombre en Firestore: ${saveResult.error}');
            }
          } catch (e) {
            debugPrint('AuthWrapper: Excepción al intentar guardar nombre de Google: $e');
          }
        }

        // Update profile notifier with the final values
        profileNotifier.updateProfile(
          newName: firestoreName,
          newImageUrl: firestoreImage,
        );
        debugPrint("AuthWrapper: Perfil de usuario cargado.");
      } else {
        debugPrint("AuthWrapper: Error al cargar el perfil de usuario: ${result.error}");
        
        // Check mounted state before showing SnackBar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? 'Error al cargar los datos del perfil.')),
          );
        }
      }
    }
    
    // Check mounted state before calling setState
    if (!mounted) return;
    
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
              future: _performInitialSetup(user),
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
