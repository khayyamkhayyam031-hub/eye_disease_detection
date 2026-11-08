import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App preferences (architecture.md §5.7).
class SettingsRepository extends ChangeNotifier {
  SettingsRepository(this._prefs);

  static Future<SettingsRepository> load() async =>
      SettingsRepository(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const _kOnboarding = 'onboarding_done';
  static const _kDisclaimer = 'disclaimer_accepted';
  static const _kTheme = 'theme_mode';
  static const _kLanguage = 'language';

  bool get onboardingDone => _prefs.getBool(_kOnboarding) ?? false;
  bool get disclaimerAccepted => _prefs.getBool(_kDisclaimer) ?? false;

  ThemeMode get themeMode {
    switch (_prefs.getString(_kTheme)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Locale get locale => Locale(_prefs.getString(_kLanguage) ?? 'en');

  Future<void> setOnboardingDone() async {
    await _prefs.setBool(_kOnboarding, true);
  }

  Future<void> setDisclaimerAccepted(bool v) async {
    await _prefs.setBool(_kDisclaimer, v);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_kTheme, mode.name);
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    await _prefs.setString(_kLanguage, code);
    notifyListeners();
  }
}
