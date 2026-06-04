import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';
import '../../shared/providers/user_provider.dart';
import 'api_error.dart';

class ApiInterceptor extends Interceptor {
  final Ref _ref;
  final SecureStorage _secureStorage;

  ApiInterceptor(this._ref, this._secureStorage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _secureStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.data is Map<String, dynamic>) {
      try {
        final parsedError = ApiError.fromMap(
          err.response!.data,
          statusCode: err.response?.statusCode,
        );

        if (err.response?.statusCode == 401 &&
            (parsedError.code == 'UNAUTHORIZED' || parsedError.code == 'TOKEN_EXPIRED')) {
          await _secureStorage.deleteToken();
          _ref.read(userNotifierProvider.notifier).clearSession();
        }

        return handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: parsedError,
          ),
        );
      } catch (_) {}
    }

    if (err.response?.statusCode == 401) {
      await _secureStorage.deleteToken();
      _ref.read(userNotifierProvider.notifier).clearSession();
      return handler.reject(DioException(requestOptions: err.requestOptions, error: ApiError(code: 'UNAUTHORIZED', message: 'Session expired. Please log in again.', statusCode: 401)));
    }
    if (err.type == DioExceptionType.connectionTimeout || err.type == DioExceptionType.receiveTimeout || err.type == DioExceptionType.sendTimeout || err.type == DioExceptionType.connectionError) {
      return handler.reject(DioException(requestOptions: err.requestOptions, error: ApiError.networkError()));
    }
    return handler.reject(DioException(requestOptions: err.requestOptions, error: ApiError(code: 'HTTP_${err.response?.statusCode ?? "ERROR"}', message: err.message ?? 'Unknown system transport issue.', statusCode: err.response?.statusCode)));
  }
}
