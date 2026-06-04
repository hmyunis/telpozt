import 'package:dio/dio.dart';
import '../../shared/models/user.dart';
import '../api/api_error.dart';

class AuthRepository {
  final Dio _client;
  AuthRepository(this._client);

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _client.post('/auth/login', data: {'username': username, 'password': password});
      final data = response.data['data'] as Map<String, dynamic>;
      return {'token': data['token'] as String, 'user': User.fromJson(data['user'] as Map<String, dynamic>)};
    } on DioException catch (e) {
      if (e.error is ApiError) throw e.error!;
      throw ApiError(code: 'LOGIN_FAILED', message: 'Failed to complete authentication sequence.');
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      await _client.post('/auth/change-password', data: {'current_password': currentPassword, 'new_password': newPassword});
    } on DioException catch (e) {
      if (e.error is ApiError) throw e.error!;
      throw ApiError(code: 'PASSWORD_CHANGE_FAILED', message: 'Could not execute password transition sequence.');
    }
  }
}
