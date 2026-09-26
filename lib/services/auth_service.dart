// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meditime/core/result.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/use_cases/sign_out_use_case.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/services/firestore_service.dart';

/// Servicio para gestionar la autenticación de usuarios con Firebase.
///
/// Centraliza todas las operaciones relacionadas con el inicio de sesión,
/// registro, cierre de sesión y autenticación con proveedores externos como Google.
/// 
class AuthService {
  static const String defaultServerClientId =
      '426041654351-49ca7oolgevitqmkgg6qjho9opscrh7f.apps.googleusercontent.com';

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final SignOutUseCase _signOutUseCase;

  AuthService(
    this._signOutUseCase, {
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              serverClientId: const String.fromEnvironment(
                'GOOGLE_SERVER_CLIENT_ID',
                defaultValue: defaultServerClientId,
              ),
            );

  /// Un stream que notifica sobre los cambios en el estado de autenticación del usuario.
  ///
  /// Es ideal para usar en un `StreamBuilder` y reaccionar a inicios o cierres de sesión.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Obtiene el objeto `User` de Firebase actualmente autenticado.
  ///
  /// Devuelve `null` si no hay ningún usuario con sesión iniciada.
  User? get currentUser => _auth.currentUser;

  /// Inicia sesión de un usuario existente usando su correo electrónico y contraseña.
  Future<Result<void>> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return const Result.success(null);
    } catch (e) {
      debugPrint('Error signing in with email and password: $e');
      return Result.failure('Error al iniciar sesión: $e');
    }
  }

  /// Registra un nuevo usuario en Firebase con su correo electrónico y contraseña.
  Future<Result<void>> createUserWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return const Result.success(null);
    } catch (e) {
      debugPrint('Error creating user with email and password: $e');
      return Result.failure('Error al crear la cuenta: $e');
    }
  }

  /// Cierra la sesión del usuario actual.
  ///
  /// Además de cerrar la sesión en Firebase, este método se encarga de:
  /// - Cancelar todas las alarmas y notificaciones programadas para el usuario.
  /// - Limpiar los datos del perfil del `ProfileNotifier`.
  /// - Desconectar de Google Sign-In si era el método de autenticación.
  /// 
  /// Uses the SignOutUseCase for business logic and returns a Result for error handling.
  Future<Result<void>> signOut({
    required ProfileNotifier profileNotifier,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;

      if (userId != null) {
        // Use the sign out use case for business logic
        final result = await _signOutUseCase.execute(userId);
        if (result.isFailure) {
          debugPrint('SignOut use case failed: ${result.error}');
          // Continue with sign out even if alarm cancellation fails
        }
      }

      // Disconnect from Google if signed in
      try {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.disconnect();
        }
      } catch (e) {
        debugPrint("Error during Google Sign In disconnect: $e");
        // Continue with sign out even if Google disconnect fails
      }

      // Clear profile and sign out
      profileNotifier.clearProfile(userId: _auth.currentUser?.uid);
      await _auth.signOut();
      // After signing out at Firebase level, ensure we clear any remembered user id in preferences
      try {
        await PreferenceService().clearCurrentUserId();
      } catch (_) {}
      
      return const Result.success(null);
    } catch (e) {
      debugPrint('Error during sign out: $e');
      return Result.failure('Error al cerrar sesión: $e');
    }
  }

  /// Indica si el usuario actual inició sesión mediante Google Sign-In.
  bool get isGoogleUser =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;

  /// Reautentica al usuario actual con su cuenta de Google antes de operaciones críticas.
  Future<Result<void>> reauthenticateWithGoogle() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return const Result.failure('No hay ninguna sesión activa.');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 45),
        onTimeout: () => null,
      );
      if (googleUser == null) {
        return const Result.failure('Reautenticación con Google cancelada.');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await user.reauthenticateWithCredential(credential);
      return const Result.success(null);
    } catch (e) {
      debugPrint('Error al reautenticar con Google: $e');
      return Result.failure('Error de reautenticación con Google: $e');
    }
  }

  /// Elimina permanentemente la cuenta del usuario en Firebase Auth y todos sus datos en Firestore.
  /// Cumple estrictamente con la directiva obligatoria de Google Play Store sobre eliminación de cuenta.
  Future<Result<void>> deleteAccount({
    required ProfileNotifier profileNotifier,
    String? currentPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const Result.failure('No hay ninguna sesión activa.');
      }
      final userId = user.uid;

      // 1. Reautenticar si se suministró contraseña de correo
      if (currentPassword != null && user.email != null) {
        try {
          final cred = EmailAuthProvider.credential(
            email: user.email!,
            password: currentPassword,
          );
          await user.reauthenticateWithCredential(cred);
        } catch (e) {
          debugPrint('Error reautenticando con contraseña en deleteAccount: $e');
          return const Result.failure('Contraseña incorrecta. Por favor, verifica tus credenciales.');
        }
      }

      // 2. Cancelar y revocar alarmas y notificaciones
      try {
        await _signOutUseCase.execute(userId);
      } catch (e) {
        debugPrint('Aviso al cancelar alarmas en deleteAccount: $e');
      }

      // 3. Eliminar todos los datos del usuario en Firestore (medicamentos, subcolecciones, chats, perfil)
      try {
        await FirestoreService().deleteUserData(userId);
      } catch (e) {
        debugPrint('Aviso al eliminar datos en Firestore en deleteAccount: $e');
      }

      // 4. Limpiar preferencias locales
      try {
        await PreferenceService().clearCurrentUserId();
      } catch (_) {}

      // 5. Limpiar el estado de ProfileNotifier
      profileNotifier.clearProfile(userId: userId);

      // 6. Desconectar de Google Sign-In si aplica
      try {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.disconnect();
        }
      } catch (_) {}

      // 7. Eliminar definitivamente el usuario de Firebase Authentication
      await user.delete();

      return const Result.success(null);
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during deleteAccount: ${e.code} - ${e.message}');
      if (e.code == 'requires-recent-login') {
        return const Result.failure('REQUIRES_RECENT_LOGIN');
      }
      return Result.failure('Error al eliminar la cuenta (${e.code}): ${e.message ?? 'Fallo de autenticación'}');
    } catch (e) {
      debugPrint('Error general during deleteAccount: $e');
      return Result.failure('Error al eliminar la cuenta: $e');
    }
  }

  /// Inicia el flujo de autenticación usando una cuenta de Google.
  Future<Result<UserCredential>> signInWithGoogle() async {
    try {
      // Asegura que se muestre el selector de cuenta en cada intento si ya había sesión
      try {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.signOut().timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
        }
      } catch (e, stackTrace) {
        debugPrint('Error signing out before Google sign-in: $e');
        debugPrintStack(stackTrace: stackTrace);
      }

      // Inicia el flujo de inicio de sesión de Google con timeout para evitar que la UI quede congelada
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 45),
        onTimeout: () => null,
      );
      
      if (googleUser == null) {
        return const Result.failure('Inicio de sesión con Google cancelado o sin respuesta.');
      }

      // Obtiene los detalles de autenticación de la solicitud
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        return const Result.failure(
          'No se pudo obtener el token de Google. Verifica Play Services y configuración OAuth/SHA-1 en Firebase.',
        );
      }

      // Crea una nueva credencial
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Una vez que se inicia sesión, devuelve la credencial del usuario
      final userCredential = await _auth.signInWithCredential(credential);
      return Result.success(userCredential);
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('FirebaseAuthException in Google sign-in: ${e.code} - ${e.message}');
      debugPrintStack(stackTrace: stackTrace);
      return Result.failure('FirebaseAuth (${e.code}): ${e.message ?? 'Error de autenticación con Google'}');
    } on PlatformException catch (e, stackTrace) {
      debugPrint('PlatformException in Google sign-in: ${e.code} - ${e.message}');
      debugPrintStack(stackTrace: stackTrace);
      final message = e.message ?? 'Error de plataforma';
      final isDeveloperError = e.code == 'sign_in_failed' &&
          (message.contains('ApiException: 10') ||
              message.contains(': 10') ||
              message.contains('api.j: 10'));
      if (isDeveloperError) {
        return const Result.failure(
          'Google Sign-In rechazado (Error 10 / DEVELOPER_ERROR). Falta registrar la huella SHA-1 o SHA-256 en Firebase Console para com.meditime.app.',
        );
      }
      return Result.failure('Google Sign-In (${e.code}): $message');
    } catch (e, stackTrace) {
      debugPrint('Error signing in with Google: $e');
      debugPrintStack(stackTrace: stackTrace);
      return Result.failure('Error al iniciar sesión con Google: $e');
    }
  }
}