import 'package:shared_preferences/shared_preferences.dart';

class PrefsStorage {
  static const String _darkModeKey = 'dark_mode';
  static const String _biometricLockKey = 'biometric_lock';
  static const String _backendBaseUrlKey = 'backend_base_url';
  final SharedPreferences _prefs;

  PrefsStorage(this._prefs);

  static const String defaultBackendBaseUrl = 'http://127.0.0.1:5000/api/v1';

  bool get isDarkMode => _prefs.getBool(_darkModeKey) ?? true;
  Future<void> setDarkMode(bool value) => _prefs.setBool(_darkModeKey, value);
  bool get isBiometricEnabled => _prefs.getBool(_biometricLockKey) ?? false;
  Future<void> setBiometricEnabled(bool value) =>
      _prefs.setBool(_biometricLockKey, value);
  String get backendBaseUrl =>
      _prefs.getString(_backendBaseUrlKey) ?? defaultBackendBaseUrl;
  Future<void> setBackendBaseUrl(String value) =>
      _prefs.setString(_backendBaseUrlKey, value);
  Future<void> clearAll() => _prefs.clear();
}
