import 'package:flutter/material.dart';
import 'package:meditime/services/preference_service.dart';

class PreferenceNotifier extends ChangeNotifier {
  final PreferenceService _preferenceService;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

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

  bool _highContrast = false;
  bool get highContrast => _highContrast;

  bool _largeText = false;
  bool get largeText => _largeText;

  bool _largeButtons = false;
  bool get largeButtons => _largeButtons;

  bool _simplifiedInterface = false;
  bool get simplifiedInterface => _simplifiedInterface;

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

    _notificationModeActive = await _preferenceService.getNotificationMode();
    _snoozeDuration = await _preferenceService.getSnoozeDuration();
    _calendarFormat = await _preferenceService.getCalendarFormat();
    _interfaceStyle = await _preferenceService.getInterfaceStyle();
    _themeMode = await _preferenceService.getThemeMode();

    _highContrast = await _preferenceService.getHighContrast();
    _largeText = await _preferenceService.getLargeText();
    _largeButtons = await _preferenceService.getLargeButtons();
    _simplifiedInterface = await _preferenceService.getSimplifiedInterface();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setNotificationModeActive(bool value) async {
    if (_notificationModeActive == value) return;
    _notificationModeActive = value;
    notifyListeners();
    await _preferenceService.saveNotificationMode(value);
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
}
