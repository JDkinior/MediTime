import 'package:flutter/foundation.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/services/firestore_service.dart';

class CaregiverNotifier extends ChangeNotifier {
  final PreferenceService _preferenceService;
  final FirestoreService _firestoreService;

  bool _isCaregiverModeActive = false;
  CaregiverModeType _modeType = CaregiverModeType.familiar;
  String? _activeProfileId;
  List<CaregiverProfile> _managedProfiles = [];
  bool _isLoading = false;
  bool _notifyPatientDoses = true;
  bool _includeLocationInNotifications = true;

  CaregiverNotifier(this._preferenceService, this._firestoreService) {
    _loadPreferences();
  }

  bool get isCaregiverModeActive => _isCaregiverModeActive;
  CaregiverModeType get modeType => _modeType;
  String? get activeProfileId => _activeProfileId;
  List<CaregiverProfile> get managedProfiles => _managedProfiles;
  bool get isLoading => _isLoading;
  bool get isGeneralMode => _activeProfileId == 'general';
  bool get notifyPatientDoses => _notifyPatientDoses;
  bool get includeLocationInNotifications => _includeLocationInNotifications;

  CaregiverProfile? get activeProfile {
    if (_activeProfileId == null || _activeProfileId == 'general') return null;
    try {
      return _managedProfiles.firstWhere((p) => p.id == _activeProfileId);
    } catch (e) {
      return null;
    }
  }

  /// Retorna el perfil activo validando que pertenezca al modo actual (animal vs humano)
  CaregiverProfile? getEffectiveActiveProfile({required bool isAnimalMode}) {
    if (_activeProfileId == 'general') return null;
    if (_activeProfileId != null) {
      try {
        final p = _managedProfiles.firstWhere((p) => p.id == _activeProfileId);
        if (isAnimalMode && p.isAnimal) return p;
        if (!isAnimalMode && !p.isAnimal) return p;
      } catch (_) {}
    }
    // Si estamos en modo animales y no hay selección específica, auto-seleccionar la primera mascota
    if (isAnimalMode) {
      final animals = _managedProfiles.where((p) => p.isAnimal).toList();
      if (animals.isNotEmpty && _activeProfileId != 'general') {
        return animals.first;
      }
    }
    return null;
  }

  void clearActiveProfile() {
    _activeProfileId = null;
    _preferenceService.saveCaregiverActiveProfile(null);
    notifyListeners();
  }

  void ensureActiveProfileForMode({required bool isAnimalMode, String animalModeType = 'individual'}) {
    final relevantProfiles = isAnimalMode
        ? _managedProfiles.where((p) => p.isAnimal).toList()
        : _managedProfiles.where((p) => !p.isAnimal).toList();

    if (relevantProfiles.isEmpty) {
      _activeProfileId = null;
      _preferenceService.saveCaregiverActiveProfile(null);
      notifyListeners();
      return;
    }

    final current = activeProfile;
    final isCurrentValid = current != null && (isAnimalMode ? current.isAnimal : !current.isAnimal);

    if (!isCurrentValid && _activeProfileId != 'general') {
      _activeProfileId = relevantProfiles.first.id;
      _preferenceService.saveCaregiverActiveProfile(_activeProfileId);
      notifyListeners();
    }
  }

  Future<void> _loadPreferences() async {
    _isCaregiverModeActive = await _preferenceService.getCaregiverModeActive();
    final typeStr = await _preferenceService.getCaregiverModeType();
    _modeType = typeStr == 'clinico'
        ? CaregiverModeType.clinico
        : (typeStr == 'veterinario' ? CaregiverModeType.veterinario : CaregiverModeType.familiar);
    _activeProfileId = await _preferenceService.getCaregiverActiveProfile();
    _notifyPatientDoses = await _preferenceService.getCaregiverNotifyPatientDoses();
    _includeLocationInNotifications = await _preferenceService.getCaregiverIncludeLocation();
    notifyListeners();
  }

  Future<void> loadProfiles(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _managedProfiles = await _firestoreService.getCaregiverProfiles(userId);
      // Validate if the active profile still exists
      if (_activeProfileId != null && activeProfile == null) {
        _activeProfileId = null;
        await _preferenceService.saveCaregiverActiveProfile(null);
      }
    } catch (e) {
      debugPrint("Error loading caregiver profiles: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setCaregiverModeActive(bool isActive) async {
    _isCaregiverModeActive = isActive;
    await _preferenceService.saveCaregiverModeActive(isActive);
    if (isActive) {
      // Exclusividad mutua: desactiva modo animales en persistencia
      await _preferenceService.saveAnimalModeActive(false);
    } else {
      _activeProfileId = null;
      await _preferenceService.saveCaregiverActiveProfile(null);
    }
    notifyListeners();
  }

  Future<void> setModeType(CaregiverModeType type) async {
    _modeType = type;
    String typeStr;
    switch (type) {
      case CaregiverModeType.clinico:
        typeStr = 'clinico';
        break;
      case CaregiverModeType.veterinario:
        typeStr = 'veterinario';
        break;
      case CaregiverModeType.familiar:
        typeStr = 'familiar';
        break;
    }
    await _preferenceService.saveCaregiverModeType(typeStr);
    notifyListeners();
  }

  Future<void> setActiveProfileId(String? profileId) async {
    _activeProfileId = profileId;
    await _preferenceService.saveCaregiverActiveProfile(profileId);
    notifyListeners();
  }

  Future<void> setNotifyPatientDoses(bool val) async {
    _notifyPatientDoses = val;
    await _preferenceService.saveCaregiverNotifyPatientDoses(val);
    notifyListeners();
  }

  Future<void> setIncludeLocationInNotifications(bool val) async {
    _includeLocationInNotifications = val;
    await _preferenceService.saveCaregiverIncludeLocation(val);
    notifyListeners();
  }
}
