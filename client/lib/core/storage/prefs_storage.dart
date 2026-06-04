import 'package:shared_preferences/shared_preferences.dart';

class PrefsStorage {
  static const String _darkModeKey = 'dark_mode';
  static const String _biometricLockKey = 'biometric_lock';
  final SharedPreferences _prefs;

  PrefsStorage(this._prefs);

  bool get isDarkMode => _prefs.getBool(_darkModeKey) ?? true;
  Future<void> setDarkMode(bool value) => _prefs.setBool(_darkModeKey, value);
  bool get isBiometricEnabled => _prefs.getBool(_biometricLockKey) ?? false;
  Future<void> setBiometricEnabled(bool value) => _prefs.setBool(_biometricLockKey, value);
  Future<void> clearAll() => _prefs.clear();
}
