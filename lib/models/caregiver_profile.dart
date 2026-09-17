import 'package:cloud_firestore/cloud_firestore.dart';

enum CaregiverModeType { familiar, clinico, veterinario }

class CaregiverProfile {
  final String id;
  final String name;
  final String relationship; // Ej: "Mamá", "Hijo", "Paciente Cama 204", o Especie para animales
  final String colorHex; // Color temático identificador de la persona o mascota
  final bool isExternalUser; // true = vinculado por correo; false = perfil local
  final String? email; // Correo si es vinculado
  final String? linkedUid; // UID en Firebase si es vinculado
  final String? roomNumber; // Opcional para modo clínico o Jaula/Box para veterinarias
  final String? category; // Categoría/Piso para humanos, o Raza/Área para animales
  final String? bloodType; // Tipo de sangre o Peso/Info clínica
  final String? allergies;
  final String? notes;

  // Campos específicos para Modo Animales / Veterinaria
  final bool isAnimal;
  final String? species; // Ej: "Canino", "Felino", "Equino", etc.
  final String? breed; // Raza
  final String? weight; // Peso (ej: "12.5 kg")
  final String? microchip; // Chip / Placa

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
    this.isAnimal = false,
    this.species,
    this.breed,
    this.weight,
    this.microchip,
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
      isAnimal: data['isAnimal'] ?? false,
      species: data['species'],
      breed: data['breed'],
      weight: data['weight'],
      microchip: data['microchip'],
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
      'isAnimal': isAnimal,
      'species': species,
      'breed': breed,
      'weight': weight,
      'microchip': microchip,
    };
  }
}
