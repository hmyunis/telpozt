import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/auth_state.dart';
import '../../core/storage/secure_storage.dart';
import '../models/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

class UserNotifier extends StateNotifier<User?> {
  final Ref _ref;
  UserNotifier(this._ref) : super(null);

  void setUser(User user) => state = user;

  void clearSession() {
    state = null;
    _ref.read(authNotifierProvider.notifier).setUnauthenticated();
  }

  Future<void> updateTimezone(String ianaTimezone) async {
    if (state == null) return;
    final client = _ref.read(apiClientProvider);
    await client.patch('/user/me', data: {'timezone': ianaTimezone});
    state = state!.copyWith(timezone: ianaTimezone);
  }
}

final userNotifierProvider =
    StateNotifierProvider<UserNotifier, User?>((ref) => UserNotifier(ref));

final userTimezoneProvider = Provider<String>(
    (ref) => ref.watch(userNotifierProvider)?.timezone ?? 'UTC');

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final SecureStorage _secureStorage;
  final AuthRepository _repository;

  AuthNotifier(this._ref, this._secureStorage, this._repository)
      : super(AuthState.checking()) {
    checkToken();
  }

  Future<void> checkToken() async {
    final token = await _secureStorage.getToken();
    if (token == null) {
      state = AuthState.unauthenticated();
      return;
    }
    try {
      final response = await _ref.read(apiClientProvider).get('/user/me');
      _ref.read(userNotifierProvider.notifier).setUser(
          User.fromJson(response.data['data'] as Map<String, dynamic>));
      state = AuthState.authenticated();
    } catch (_) {
      await _secureStorage.deleteToken();
      state = AuthState.unauthenticated();
    }
  }

  Future<void> login(String username, String password) async {
    state = AuthState.loading();
    try {
      final res = await _repository.login(username, password);
      await _secureStorage.saveToken(res['token'] as String);
      _ref.read(userNotifierProvider.notifier).setUser(res['user'] as User);
      state = AuthState.authenticated();
    } catch (e) {
      state = AuthState.unauthenticated(error: e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    await _secureStorage.deleteToken();
    _ref.read(userNotifierProvider.notifier).clearSession();
    state = AuthState.unauthenticated();
  }

  void setUnauthenticated() => state = AuthState.unauthenticated();
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref,
    ref.watch(secureStorageProvider),
    ref.read(authRepositoryProvider),
  );
});
