import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';
import '../storage/prefs_storage.dart';
import 'api_interceptor.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => throw UnimplementedError());
final prefsStorageProvider = Provider<PrefsStorage>((ref) => throw UnimplementedError());

final apiClientProvider = Provider<Dio>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:5000/api/v1', connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 30), headers: {'Content-Type': 'application/json'}));
  dio.interceptors.add(ApiInterceptor(ref, secureStorage));
  return dio;
});
