enum AuthStatus { checking, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  AuthState({required this.status, this.errorMessage});

  bool get isChecking => status == AuthStatus.checking;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;

  factory AuthState.checking() => AuthState(status: AuthStatus.checking);
  factory AuthState.authenticated() => AuthState(status: AuthStatus.authenticated);
  factory AuthState.unauthenticated({String? error}) => AuthState(status: AuthStatus.unauthenticated, errorMessage: error);
  factory AuthState.loading() => AuthState(status: AuthStatus.loading);
}
