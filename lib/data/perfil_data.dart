import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PerfilData {
  static const String keyName = 'name';
  static const String keyPhone = 'phone';
  static const String keyEmail = 'email';
  static const String keyDob = 'dob';
  static const String keyBloodType = 'bloodType';
  static const String keyAllergies = 'allergies';
  static const String keyMedications = 'medications';
  static const String keyMedicalHistory = 'medicalHistory';
  static const String keyProfileImage = 'profileImage';

  // Guardar datos del perfil en Firestore
  static Future<void> saveProfileDataToFirestore({
    required String name,
    required String phone,
    required String email,
    required String dob,
    required String bloodType,
    required String allergies,
    required String medications,
    required String medicalHistory,
    required String profileImagePath, // La URL de la imagen
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        keyName: name,
        keyPhone: phone,
        keyEmail: email,
        keyDob: dob,
        keyBloodType: bloodType,
        keyAllergies: allergies,
        keyMedications: medications,
        keyMedicalHistory: medicalHistory,
        keyProfileImage: profileImagePath, // Guardar la URL de descarga
      }, SetOptions(merge: true));
    }
  }


  // Cargar datos del perfil desde Firestore
  static Future<Map<String, dynamic>?> loadProfileDataFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        return doc.data();
      }
    }
    return null;
  }

  // Obtener el primer nombre del perfil desde Firestore
  static Future<String?> obtenerPrimerNombre() async {
    final data = await loadProfileDataFromFirestore();
    if (data != null && data[keyName] != null) {
      return data[keyName].toString().split(' ').first;
    }
    return null;
  }
}


// Método para iniciar sesión y cargar datos
Future<void> signInAndLoadProfile(String email, String password) async {
  try {
    // Iniciar sesión con Firebase Authentication
    UserCredential userCredential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);

    if (userCredential.user != null) {
      // Cargar datos del perfil desde Firestore
      await PerfilData.loadProfileDataFromFirestore();
    }
  } catch (e) {
    print('Error al iniciar sesión o cargar perfil: $e');
  }
}
