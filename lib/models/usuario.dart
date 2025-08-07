// lib/models/usuario.dart
import 'package:flutter/foundation.dart';
import 'package:meditime/core/constants.dart';

/// Enhanced user model with validation and better type safety.
@immutable
class Usuario {
  final String uid;
  final String? email;
  final String? name;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? bloodType;
  final String? allergies;
  final String? medications;
  final String? medicalHistory;
  final String? profileImageUrl;

  const Usuario({
    required this.uid,
    this.email,
    this.name,
    this.phone,
    this.dateOfBirth,
    this.bloodType,
    this.allergies,
    this.medications,
    this.medicalHistory,
    this.profileImageUrl,
  });

  /// Gets the user's display name, falling back to default if null
  String get displayName => name ?? AppConstants.defaultUserName;

  /// Gets the user's age based on date of birth
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month || 
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  /// Validates if the user has complete profile information
  bool get hasCompleteProfile {
    return name != null &&
           name!.isNotEmpty &&
           email != null &&
           email!.isNotEmpty;
  }

  /// Validates if the user has medical information
  bool get hasMedicalInfo {
    return bloodType != null ||
           allergies != null ||
           medications != null ||
           medicalHistory != null;
  }

  /// Creates a copy of this user with updated values
  Usuario copyWith({
    String? uid,
    String? email,
    String? name,
    String? phone,
    DateTime? dateOfBirth,
    String? bloodType,
    String? allergies,
    String? medications,
    String? medicalHistory,
    String? profileImageUrl,
  }) {
    return Usuario(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      medications: medications ?? this.medications,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  /// Converts to Map for Firestore storage
  Map<String, dynamic> toFirestoreMap() {
    return {
      AppConstants.emailField: email,
      AppConstants.nameField: name,
      AppConstants.phoneField: phone,
      AppConstants.dobField: dateOfBirth?.toIso8601String(),
      AppConstants.bloodTypeField: bloodType,
      AppConstants.allergiesField: allergies,
      AppConstants.medicationsField: medications,
      AppConstants.medicalHistoryField: medicalHistory,
      AppConstants.profileImageField: profileImageUrl,
    };
  }

  /// Factory constructor para crear un Usuario desde un Map (como los de Firestore).
  factory Usuario.fromMap(String uid, Map<String, dynamic>? data) {
    if (data == null) {
      return Usuario(uid: uid); // Retorna un usuario básico si no hay datos
    }

    // Parse date of birth safely
    DateTime? dateOfBirth;
    final dobString = data[AppConstants.dobField];
    if (dobString is String && dobString.isNotEmpty) {
      try {
        dateOfBirth = DateTime.parse(dobString);
      } catch (e) {
        debugPrint('Error parsing date of birth: $e');
      }
    }

    return Usuario(
      uid: uid,
      email: data[AppConstants.emailField],
      name: data[AppConstants.nameField],
      phone: data[AppConstants.phoneField],
      dateOfBirth: dateOfBirth,
      bloodType: data[AppConstants.bloodTypeField],
      allergies: data[AppConstants.allergiesField],
      medications: data[AppConstants.medicationsField],
      medicalHistory: data[AppConstants.medicalHistoryField],
      profileImageUrl: data[AppConstants.profileImageField],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Usuario &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email &&
          name == other.name &&
          phone == other.phone &&
          dateOfBirth == other.dateOfBirth &&
          bloodType == other.bloodType &&
          allergies == other.allergies &&
          medications == other.medications &&
          medicalHistory == other.medicalHistory &&
          profileImageUrl == other.profileImageUrl;

  @override
  int get hashCode =>
      uid.hashCode ^
      email.hashCode ^
      name.hashCode ^
      phone.hashCode ^
      dateOfBirth.hashCode ^
      bloodType.hashCode ^
      allergies.hashCode ^
      medications.hashCode ^
      medicalHistory.hashCode ^
      profileImageUrl.hashCode;

  @override
  String toString() {
    return 'Usuario{uid: $uid, name: $name, email: $email, hasCompleteProfile: $hasCompleteProfile}';
  }
}