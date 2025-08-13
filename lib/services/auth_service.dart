// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meditime/core/result.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/use_cases/sign_out_use_case.dart';
import 'package:meditime/services/preference_service.dart';

/// Servicio para gestionar la autenticación de usuarios con Firebase.
///
/// Centraliza todas las operaciones relacionadas con el inicio de sesión,
/// registro, cierre de sesión y autenticación con proveedores externos como Google.
/// 
/// This service now uses the clean architecture pattern with use cases for business logic.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final SignOutUseCase _signOutUseCase;

  AuthService(this._signOutUseCase);

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
      profileNotifier.clearProfile();
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

  /// Inicia el flujo de autenticación usando una cuenta de Google.
  Future<Result<UserCredential>> signInWithGoogle() async {
    try {
      // Inicia el flujo de inicio de sesión de Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return const Result.failure('Inicio de sesión con Google cancelado');
      }

      // Obtiene los detalles de autenticación de la solicitud
      final GoogleSignInAuthentication? googleAuth = await googleUser.authentication;

      // Crea una nueva credencial
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      // Una vez que se inicia sesión, devuelve la credencial del usuario
      final userCredential = await _auth.signInWithCredential(credential);
      return Result.success(userCredential);
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return Result.failure('Error al iniciar sesión con Google: $e');
    }
  }
}