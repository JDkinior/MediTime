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

  CaregiverNotifier(this._preferenceService, this._firestoreService) {
    _loadPreferences();
  }

  bool get isCaregiverModeActive => _isCaregiverModeActive;
  CaregiverModeType get modeType => _modeType;
  String? get activeProfileId => _activeProfileId;
  List<CaregiverProfile> get managedProfiles => _managedProfiles;
  bool get isLoading => _isLoading;
  bool get isGeneralMode => _activeProfileId == 'general';

  CaregiverProfile? get activeProfile {
    if (_activeProfileId == null || _activeProfileId == 'general') return null;
    try {
      return _managedProfiles.firstWhere((p) => p.id == _activeProfileId);
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadPreferences() async {
    _isCaregiverModeActive = await _preferenceService.getCaregiverModeActive();
    final typeStr = await _preferenceService.getCaregiverModeType();
    _modeType = typeStr == 'clinico' ? CaregiverModeType.clinico : CaregiverModeType.familiar;
    _activeProfileId = await _preferenceService.getCaregiverActiveProfile();
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
    if (!isActive) {
      _activeProfileId = null;
      await _preferenceService.saveCaregiverActiveProfile(null);
    }
    notifyListeners();
  }

  Future<void> setModeType(CaregiverModeType type) async {
    _modeType = type;
    await _preferenceService.saveCaregiverModeType(
      type == CaregiverModeType.clinico ? 'clinico' : 'familiar'
    );
    notifyListeners();
  }

  Future<void> setActiveProfileId(String? profileId) async {
    _activeProfileId = profileId;
    await _preferenceService.saveCaregiverActiveProfile(profileId);
    notifyListeners();
  }
}
