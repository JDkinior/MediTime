import 'package:cloud_firestore/cloud_firestore.dart';

enum CaregiverModeType { familiar, clinico }

class CaregiverProfile {
  final String id;
  final String name;
  final String relationship; // Ej: "Mamá", "Hijo", "Paciente Cama 204"
  final String colorHex; // Color temático identificador de la persona
  final bool isExternalUser; // true = vinculado por correo; false = perfil local
  final String? email; // Correo si es vinculado
  final String? linkedUid; // UID en Firebase si es vinculado
  final String? roomNumber; // Opcional para modo clínico
  final String? category; // Categoría/Piso para filtros
  final String? bloodType;
  final String? allergies;
  final String? notes;

  CaregiverProfile({
    required this.id,
    required this.name,
    required this.relationship,
    required this.colorHex,
    required this.isExternalUser,
    this.email,
    this.linkedUid,
    this.roomNumber,
    this.category,
    this.bloodType,
    this.allergies,
    this.notes,
  });

  factory CaregiverProfile.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('missing data for CaregiverProfile');
    }
    return CaregiverProfile.fromMap(snapshot.id, data);
  }

  factory CaregiverProfile.fromMap(String id, Map<String, dynamic> data) {
    return CaregiverProfile(
      id: id,
      name: data['name'] ?? '',
      relationship: data['relationship'] ?? '',
      colorHex: data['colorHex'] ?? '#4F46E5', // Default soft indigo color
      isExternalUser: data['isExternalUser'] ?? false,
      email: data['email'],
      linkedUid: data['linkedUid'],
      roomNumber: data['roomNumber'],
      category: data['category'],
      bloodType: data['bloodType'],
      allergies: data['allergies'],
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'relationship': relationship,
      'colorHex': colorHex,
      'isExternalUser': isExternalUser,
      'email': email,
      'linkedUid': linkedUid,
      'roomNumber': roomNumber,
      'category': category,
      'bloodType': bloodType,
      'allergies': allergies,
      'notes': notes,
    };
  }
}
