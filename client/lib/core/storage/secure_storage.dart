import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const String _jwtTokenKey = 'jwt_token';
  final FlutterSecureStorage _storage;

  SecureStorage(this._storage);

  Future<void> saveToken(String token) => _storage.write(key: _jwtTokenKey, value: token);
  Future<String?> getToken() => _storage.read(key: _jwtTokenKey);
  Future<void> deleteToken() => _storage.delete(key: _jwtTokenKey);
}
