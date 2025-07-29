// lib/notifiers/profile_notifier.dart
import 'package:flutter/material.dart';

/// Un `ChangeNotifier` para gestionar el estado global del perfil del usuario.
///
/// Permite que widgets como el `CustomDrawer` o el header del perfil se actualicen
/// automáticamente cuando el nombre o la imagen del usuario cambian, sin necesidad
/// de pasar los datos a través de múltiples widgets.
class ProfileNotifier extends ChangeNotifier {
  String? _userName;
  String? _profileImageUrl;

  String? get userName => _userName;
  String? get profileImageUrl => _profileImageUrl;

  /// Actualiza los datos del perfil y notifica a los widgets que están escuchando.
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

  /// Limpia los datos del perfil, típicamente al cerrar sesión.
    void clearProfile() {
    _userName = null;
    _profileImageUrl = null;
    notifyListeners();
  }
}