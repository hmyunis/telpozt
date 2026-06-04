class ApiError implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  ApiError({required this.code, required this.message, this.statusCode});

  factory ApiError.fromMap(Map<String, dynamic> map, {int? statusCode}) {
    final errorPayload = map['error'] as Map<String, dynamic>?;
    return ApiError(code: errorPayload?['code'] ?? 'UNKNOWN_ERROR', message: errorPayload?['message'] ?? 'An unexpected network error occurred.', statusCode: statusCode);
  }

  factory ApiError.networkError() => ApiError(code: 'NETWORK_ERROR', message: 'Connection failed. Check your internet connection.');
  @override
  String toString() => 'ApiError(code: $code, message: $message, statusCode: $statusCode)';
}
