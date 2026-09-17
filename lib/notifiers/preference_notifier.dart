import 'package:flutter/material.dart';
import 'package:meditime/services/preference_service.dart';

class PreferenceNotifier extends ChangeNotifier {
  final PreferenceService _preferenceService;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  DoseReminderMode _reminderMode = DoseReminderMode.automatic;
  DoseReminderMode get reminderMode => _reminderMode;

  bool _notificationModeActive = false;
  bool get notificationModeActive => _notificationModeActive;

  int _snoozeDuration = 10;
  int get snoozeDuration => _snoozeDuration;

  String _calendarFormat = 'weekly';
  String get calendarFormat => _calendarFormat;

  String _interfaceStyle = 'classic';
  String get interfaceStyle => _interfaceStyle;

  String _themeMode = 'system';
  String get themeMode => _themeMode;

  String _languageCode = 'system';
  String get languageCode => _languageCode;

  Locale? get locale {
    if (_languageCode == 'system') return null;
    return Locale(_languageCode);
  }

  bool _highContrast = false;
  bool get highContrast => _highContrast;

  bool _largeText = false;
  bool get largeText => _largeText;

  bool _largeButtons = false;
  bool get largeButtons => _largeButtons;

  bool _simplifiedInterface = false;
  bool get simplifiedInterface => _simplifiedInterface;

  bool _showCardBorder = false;
  bool get showCardBorder => _showCardBorder;

  bool _hideMedicineNameOnLockScreen = false;
  bool get hideMedicineNameOnLockScreen => _hideMedicineNameOnLockScreen;

  bool _isAnimalMode = false;
  bool get isAnimalMode => _isAnimalMode;

  String _animalModeType = 'individual';
  String get animalModeType => _animalModeType;

  ThemeMode get themeModeEnum {
    switch (_themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  PreferenceNotifier(this._preferenceService) {
    loadPreferences();
  }

  Future<void> loadPreferences() async {
    _isLoading = true;
    notifyListeners();

    _reminderMode = await _preferenceService.getReminderMode();
    _notificationModeActive = _reminderMode == DoseReminderMode.active;
    _snoozeDuration = await _preferenceService.getSnoozeDuration();
    _calendarFormat = await _preferenceService.getCalendarFormat();
    _interfaceStyle = await _preferenceService.getInterfaceStyle();
    _themeMode = await _preferenceService.getThemeMode();
    _languageCode = await _preferenceService.getLanguageCode();

    _highContrast = await _preferenceService.getHighContrast();
    _largeText = await _preferenceService.getLargeText();
    _largeButtons = await _preferenceService.getLargeButtons();
    _simplifiedInterface = await _preferenceService.getSimplifiedInterface();
    _showCardBorder = await _preferenceService.getShowCardBorder();
    _hideMedicineNameOnLockScreen = await _preferenceService.getHideMedicineNameOnLockScreen();
    _isAnimalMode = await _preferenceService.getAnimalModeActive();
    _animalModeType = await _preferenceService.getAnimalModeType();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setReminderMode(DoseReminderMode mode) async {
    if (_reminderMode == mode) return;
    _reminderMode = mode;
    _notificationModeActive = mode == DoseReminderMode.active;
    notifyListeners();
    await _preferenceService.saveReminderMode(mode);
  }

  Future<void> setNotificationModeActive(bool value) async {
    final newMode = value ? DoseReminderMode.active : DoseReminderMode.automatic;
    await setReminderMode(newMode);
  }

  Future<void> setSnoozeDuration(int duration) async {
    if (_snoozeDuration == duration) return;
    _snoozeDuration = duration;
    notifyListeners();
    await _preferenceService.saveSnoozeDuration(duration);
  }

  Future<void> setCalendarFormat(String format) async {
    if (_calendarFormat == format) return;
    _calendarFormat = format;
    notifyListeners();
    await _preferenceService.saveCalendarFormat(format);
  }

  Future<void> setInterfaceStyle(String style) async {
    if (_interfaceStyle == style) return;
    _interfaceStyle = style;
    notifyListeners();
    await _preferenceService.saveInterfaceStyle(style);
  }

  Future<void> setThemeMode(String themeStr) async {
    if (_themeMode == themeStr) return;
    _themeMode = themeStr;
    notifyListeners();
    await _preferenceService.saveThemeMode(themeStr);
  }

  Future<void> setLanguageCode(String code) async {
    if (_languageCode == code) return;
    _languageCode = code;
    notifyListeners();
    await _preferenceService.saveLanguageCode(code);
  }

  Future<void> setHighContrast(bool value) async {
    if (_highContrast == value) return;
    _highContrast = value;
    notifyListeners();
    await _preferenceService.saveHighContrast(value);
  }

  Future<void> setLargeText(bool value) async {
    if (_largeText == value) return;
    _largeText = value;
    notifyListeners();
    await _preferenceService.saveLargeText(value);
  }

  Future<void> setLargeButtons(bool value) async {
    if (_largeButtons == value) return;
    _largeButtons = value;
    notifyListeners();
    await _preferenceService.saveLargeButtons(value);
  }

  Future<void> setSimplifiedInterface(bool value) async {
    if (_simplifiedInterface == value) return;
    _simplifiedInterface = value;
    notifyListeners();
    await _preferenceService.saveSimplifiedInterface(value);
  }

  Future<void> setShowCardBorder(bool value) async {
    if (_showCardBorder == value) return;
    _showCardBorder = value;
    notifyListeners();
    await _preferenceService.saveShowCardBorder(value);
  }

  Future<void> setHideMedicineNameOnLockScreen(bool value) async {
    if (_hideMedicineNameOnLockScreen == value) return;
    _hideMedicineNameOnLockScreen = value;
    notifyListeners();
    await _preferenceService.saveHideMedicineNameOnLockScreen(value);
  }

  Future<void> applyOnboardingSettings({
    required DoseReminderMode reminderMode,
    required String interfaceStyle,
    required bool simplifiedInterface,
    required bool largeText,
    required bool highContrast,
  }) async {
    _reminderMode = reminderMode;
    _notificationModeActive = reminderMode == DoseReminderMode.active;
    _interfaceStyle = interfaceStyle;
    _simplifiedInterface = simplifiedInterface;
    _largeText = largeText;
    _highContrast = highContrast;
    notifyListeners();

    await _preferenceService.saveReminderMode(reminderMode);
    await _preferenceService.saveInterfaceStyle(interfaceStyle);
    await _preferenceService.saveSimplifiedInterface(simplifiedInterface);
    await _preferenceService.saveLargeText(largeText);
    await _preferenceService.saveHighContrast(highContrast);
  }

  Future<void> setAnimalMode(bool value) async {
    if (_isAnimalMode == value) return;
    _isAnimalMode = value;
    if (value) {
      // Exclusividad mutua: desactiva modo cuidador en persistencia
      await _preferenceService.saveCaregiverModeActive(false);
    }
    notifyListeners();
    await _preferenceService.saveAnimalModeActive(value);
  }

  Future<void> setAnimalModeType(String type) async {
    if (_animalModeType == type) return;
    _animalModeType = type;
    notifyListeners();
    await _preferenceService.saveAnimalModeType(type);
  }
}
