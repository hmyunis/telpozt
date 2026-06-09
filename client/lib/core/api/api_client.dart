import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';
import '../storage/prefs_storage.dart';
import 'api_interceptor.dart';

final secureStorageProvider =
    Provider<SecureStorage>((ref) => throw UnimplementedError());
final prefsStorageProvider =
    Provider<PrefsStorage>((ref) => throw UnimplementedError());

String normalizeBackendBaseUrl(String rawValue) {
  var normalized = rawValue.trim();
  if (normalized.isEmpty) {
    return PrefsStorage.defaultBackendBaseUrl;
  }
  if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
    normalized = 'http://$normalized';
  }
  normalized = normalized.replaceAll(RegExp(r'/+$'), '');
  if (!normalized.endsWith('/api/v1')) {
    if (normalized.endsWith('/api')) {
      normalized = '$normalized/v1';
    } else {
      normalized = '$normalized/api/v1';
    }
  }
  return normalized;
}

final apiClientProvider = Provider<Dio>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final prefs = ref.watch(prefsStorageProvider);
  final dio = Dio(BaseOptions(
      baseUrl: normalizeBackendBaseUrl(prefs.backendBaseUrl),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'}));
  dio.interceptors.add(ApiInterceptor(ref, secureStorage));
  return dio;
});
