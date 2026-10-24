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

import 'package:meditime/notifiers/subscription_notifier.dart';
import 'package:meditime/services/subscription_service.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';

// Importar pantallas
import 'package:meditime/screens/auth/login_page.dart';
import 'package:meditime/screens/home/home_page.dart';
import 'package:meditime/screens/onboarding/onboarding_page.dart';
import 'package:meditime/services/widget_service.dart';

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
  bool _onboardingCompleted = true;
  Future<void>? _setupFuture;
  String? _setupUserId;
  Stream<User?>? _authStateStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authStateStream ??= context.read<AuthService>().authStateChanges;
  }

  bool _isDeprecatedFirebaseStorageUrl(String? url) {
    return url != null && url.contains('firebasestorage.googleapis.com');
  }

  Future<void> _performInitialSetup(User user) async {
    // Evita que se ejecute múltiples veces para el mismo usuario
    if (_initialSetupDone && _setupUserId == user.uid) return;

    // Check if widget is still mounted before proceeding
    if (!mounted) return;

    final profileNotifier = context.read<ProfileNotifier>();
    final loadUserProfileUseCase = context.read<LoadUserProfileUseCase>();
    final userRepository = context.read<UserRepository>();

    // 0. Cargar perfil desde la caché local de forma instantánea (0ms)
    await profileNotifier.loadFromLocalCache(user.uid);

    // Guardar el usuario actual para filtros en callbacks offline
    await PreferenceService().saveCurrentUserId(user.uid);

    // Inicializar escucha reactiva de suscripción
    if (mounted) {
      context.read<SubscriptionNotifier>().listenToUser(
        user.uid,
        context.read<SubscriptionService>(),
      );
    }

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

    // 2. Sincronizar el perfil del usuario desde Firestore
    debugPrint("AuthWrapper: Sincronizando perfil de usuario desde Firestore...");
    
    final result = await loadUserProfileUseCase.execute(user.uid);
    
    // Check mounted state after async operation
    if (!mounted) return;
    
    if (result.isSuccess) {
      final profileData = result.data;
      
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

      // Update profile notifier with the final values and auto-cache to disk
      profileNotifier.updateProfile(
        newName: firestoreName,
        newImageUrl: firestoreImage,
        userId: user.uid,
      );
      debugPrint("AuthWrapper: Perfil de usuario sincronizado y actualizado.");
    } else {
      debugPrint("AuthWrapper: Error al cargar el perfil de usuario: ${result.error}");
    }
    
    // Sincronizar estado inicial con los Widgets nativos de Android
    await WidgetService.updateWidgetData(userId: user.uid);

    // Cargar perfiles de cuidador y auto-asegurar vínculos
    if (mounted) {
      context.read<CaregiverNotifier>().loadProfiles(user.uid);
    }

    // Verificar si la aplicación fue abierta por toque en un Widget (ej. Asistente Midi)
    if (mounted) {
      await WidgetService.handleWidgetLaunch(context);
    }

    // Verificar si ya completó el onboarding inicial y aceptó los términos legales
    final prefService = PreferenceService();
    bool completed = await prefService.hasCompletedOnboarding(user.uid);
    bool termsAccepted = await prefService.hasAcceptedTerms(user.uid);

    if (!completed || !termsAccepted) {
      final data = result.isSuccess ? (result.data ?? {}) : (await loadUserProfileUseCase.execute(user.uid)).data ?? {};
      final bool remoteOnboarding = data['onboardingCompleted'] == true;
      final bool remoteTerms = data['termsAccepted'] == true;

      if (remoteOnboarding && remoteTerms) {
        completed = true;
        termsAccepted = true;
        await prefService.saveOnboardingCompleted(user.uid, true);
        await prefService.saveTermsAccepted(
          user.uid,
          accepted: true,
          version: data['termsAcceptedVersion'] as String? ?? '2.36.0',
        );
      }
    }

    final bool allDone = completed && termsAccepted;

    // Marcamos que la configuración inicial ya se realizó.
    if (mounted) {
      setState(() {
        _onboardingCompleted = allDone;
        _initialSetupDone = true;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final stream = _authStateStream ?? authService.authStateChanges;

    return StreamBuilder<User?>(
      stream: stream,
      initialData: authService.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? authService.currentUser;

        // Solo si la app está recién arrancando, no hay ningún usuario en caché
        // y el stream está esperando su primer evento, mostramos el loader.
        if (snapshot.connectionState == ConnectionState.waiting && user == null) {
          return const LoadingScreen();
        }

        // Si el usuario ha iniciado sesión
        if (user != null) {
          if (_setupUserId != null && _setupUserId != user.uid) {
            _initialSetupDone = false;
            _setupFuture = null;
          }

          // Si la configuración inicial ya se completó (escenario normal al navegar entre pantallas),
          // mostramos la página de inmediato sin volver a llamar a _performInitialSetup ni mostrar LoadingScreen.
          if (_initialSetupDone && _setupUserId == user.uid) {
            if (!_onboardingCompleted) {
              return OnboardingPage(
                user: user,
                onCompleted: () {
                  if (mounted) {
                    setState(() {
                      _onboardingCompleted = true;
                    });
                  }
                },
              );
            }
            return const HomePage();
          }

          // Si es la primera vez que se detecta el usuario en este ciclo de sesión,
          // inicializamos el Future una sola vez evitando ejecuciones duplicadas en rebuilds.
          if (_setupFuture == null || _setupUserId != user.uid) {
            _setupUserId = user.uid;
            _setupFuture = _performInitialSetup(user);
          }

          return FutureBuilder<void>(
            future: _setupFuture,
            builder: (context, setupSnapshot) {
              // Durante la configuración inicial de arranque, mostramos el loader
              if (setupSnapshot.connectionState == ConnectionState.waiting && !_initialSetupDone) {
                return const LoadingScreen();
              }
              // Si hubo un error durante la configuración
              if (setupSnapshot.hasError && !_initialSetupDone) {
                return const Scaffold(
                  body: Center(
                    child: Text('Ocurrió un error al configurar la sesión.'),
                  ),
                );
              }
              // Una vez completada la configuración, comprobar si requiere onboarding
              if (!_onboardingCompleted) {
                return OnboardingPage(
                  user: user,
                  onCompleted: () {
                    if (mounted) {
                      setState(() {
                        _onboardingCompleted = true;
                      });
                    }
                  },
                );
              }
              return const HomePage();
            },
          );
        }

        // Si el usuario no ha iniciado sesión, reiniciamos el estado
        _initialSetupDone = false;
        _setupFuture = null;
        _setupUserId = null;
        _onboardingCompleted = true;
        return const LoginPage();
      },
    );
  }
}
