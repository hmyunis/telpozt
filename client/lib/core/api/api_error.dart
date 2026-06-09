class ApiError implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  ApiError({required this.code, required this.message, this.statusCode});

  factory ApiError.fromMap(Map<String, dynamic> map, {int? statusCode}) {
    final errorPayload = map['error'] as Map<String, dynamic>?;
    return ApiError(
        code: errorPayload?['code'] ?? 'UNKNOWN_ERROR',
        message:
            errorPayload?['message'] ?? 'An unexpected network error occurred.',
        statusCode: statusCode);
  }

  factory ApiError.networkError(Uri? uri) {
    final host = uri?.host ?? 'the backend';
    final isLoopbackHost =
        host == '127.0.0.1' || host == 'localhost' || host == '::1';
    if (isLoopbackHost) {
      return ApiError(
        code: 'NETWORK_ERROR',
        message:
            'This phone is trying to call $host, which points back to the phone itself. Open Connection Setup and use the backend computer\'s Wi-Fi IP instead.',
      );
    }
    return ApiError(
      code: 'NETWORK_ERROR',
      message:
          'Connection to $host failed. Confirm the phone and backend computer are on the same Wi-Fi, the backend is running, and the saved backend URL is correct.',
    );
  }
  @override
  String toString() =>
      'ApiError(code: $code, message: $message, statusCode: $statusCode)';
}
