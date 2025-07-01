// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream para escuchar cambios en el estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Obtener el usuario actual
  User? get currentUser => _auth.currentUser;

  // Iniciar sesión con correo y contraseña
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Registrar un nuevo usuario
  Future<void> createUserWithEmailAndPassword(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _googleSignIn.disconnect(); // <-- AÑADE ESTA LÍNEA
    await _auth.signOut();
  }

  // Iniciar sesión con Google
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