// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/firestore_service.dart';

/// Servicio para gestionar la autenticación de usuarios con Firebase.
///
/// Centraliza todas las operaciones relacionadas con el inicio de sesión,
/// registro, cierre de sesión y autenticación con proveedores externos como Google.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Un stream que notifica sobre los cambios en el estado de autenticación del usuario.
  ///
  /// Es ideal para usar en un `StreamBuilder` y reaccionar a inicios o cierres de sesión.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Obtiene el objeto `User` de Firebase actualmente autenticado.
  ///
  /// Devuelve `null` si no hay ningún usuario con sesión iniciada.
  User? get currentUser => _auth.currentUser;

  /// Inicia sesión de un usuario existente usando su correo electrónico y contraseña.
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Registra un nuevo usuario en Firebase con su correo electrónico y contraseña.
  Future<void> createUserWithEmailAndPassword(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  /// Cierra la sesión del usuario actual.
  ///
  /// Además de cerrar la sesión en Firebase, este método se encarga de:
  /// - Cancelar todas las alarmas y notificaciones programadas para el usuario.
  /// - Limpiar los datos del perfil del `ProfileNotifier`.
  /// - Desconectar de Google Sign-In si era el método de autenticación.
  Future<void> signOut(BuildContext context) async {
    final profileNotifier = context.read<ProfileNotifier>();
    final firestoreService = context.read<FirestoreService>();
    final userId = _auth.currentUser?.uid;

    if (userId != null) {
      try {
        // CAMBIO: Ahora esperamos una List<Tratamiento>
        final List<Tratamiento> tratamientos =
            await firestoreService.getMedicamentosStream(userId).first;

        // CAMBIO: Iteramos directamente sobre la lista de objetos
        for (var tratamiento in tratamientos) {
          // CAMBIO: Accedemos a la propiedad directamente
          final alarmId = tratamiento.prescriptionAlarmId;
          if (alarmId != 0) { // Usamos el valor del objeto
            await NotificationService.cancelTreatmentAlarms(alarmId);
          }
        }
        await NotificationService.cancelAllFlutterLocalNotifications();

      } catch (e) {
        debugPrint('Error al cancelar las alarmas durante el cierre de sesión: $e');
      }
    }

    // --- INICIO DE LA CORRECCIÓN ---

    try {
      // Desconecta de Google SOLO si el usuario había iniciado sesión con Google
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect();
      }
    } catch (e) {
      debugPrint("Error durante el disconnect de Google Sign In: $e");
      // Este catch es una seguridad extra, aunque el if ya debería prevenir el error.
    }

    // --- FIN DE LA CORRECCIÓN ---

    profileNotifier.clearProfile();
    await _auth.signOut();
  }

  /// Inicia el flujo de autenticación usando una cuenta de Google.
  Future<UserCredential> signInWithGoogle() async {
    // Inicia el flujo de inicio de sesión de Google
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    // Obtiene los detalles de autenticación de la solicitud
    final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

    // Crea una nueva credencial
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );

    // Una vez que se inicia sesión, devuelve la credencial del usuario
    return await _auth.signInWithCredential(credential);
  }

}