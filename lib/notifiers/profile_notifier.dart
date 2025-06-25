import 'package:flutter/material.dart';

/// Gestiona el estado de los datos del perfil del usuario que pueden ser
/// compartidos y modificados a través de la aplicación.
class ProfileNotifier extends ChangeNotifier {
  String? _userName;
  String? _profileImageUrl;

  String? get userName => _userName;
  String? get profileImageUrl => _profileImageUrl;

  /// Actualiza los datos del perfil y notifica a los widgets que escuchan.
  ///
  /// Solo notifica si realmente hay un cambio en los datos para evitar
  /// reconstrucciones innecesarias de la UI.
  void updateProfile({String? newName, String? newImageUrl}) {
    bool hasChanged = false;

    if (newName != null && newName != _userName) {
      _userName = newName;
      hasChanged = true;
    }
    if (newImageUrl != null && newImageUrl != _profileImageUrl) {
      _profileImageUrl = newImageUrl;
      hasChanged = true;
    }

    if (hasChanged) {
      notifyListeners(); // Avisa a los widgets que deben reconstruirse.
    }
  }
}