// lib/models/usuario.dart
class Usuario {
  final String uid;
  final String? email;
  final String? name;
  final String? phone;
  final String? dob; // Fecha de nacimiento (Date of Birth)
  final String? bloodType;
  final String? allergies;
  final String? medications;
  final String? medicalHistory;
  final String? profileImageUrl;

  Usuario({
    required this.uid,
    this.email,
    this.name,
    this.phone,
    this.dob,
    this.bloodType,
    this.allergies,
    this.medications,
    this.medicalHistory,
    this.profileImageUrl,
  });

  /// Factory constructor para crear un Usuario desde un Map (como los de Firestore).
  factory Usuario.fromMap(String uid, Map<String, dynamic>? data) {
    if (data == null) {
      return Usuario(uid: uid); // Retorna un usuario básico si no hay datos
    }
    return Usuario(
      uid: uid,
      email: data['email'],
      name: data['name'],
      phone: data['phone'],
      dob: data['dob'],
      bloodType: data['bloodType'],
      allergies: data['allergies'],
      medications: data['medications'],
      medicalHistory: data['medicalHistory'],
      profileImageUrl: data['profileImage'],
    );
  }
}