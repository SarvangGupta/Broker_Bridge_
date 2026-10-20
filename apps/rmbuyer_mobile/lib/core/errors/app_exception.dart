/// Base exception class for all RMBuyer domain and operational failures.
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException({
    required this.message,
    this.code,
    this.details,
  });

  @override
  String toString() => 'AppException(code: $code, message: $message)';
}

class NetworkException extends AppException {
  const NetworkException({
    super.message = 'Network connection failure. Please check your internet connection.',
    super.code = 'NETWORK_ERROR',
    super.details,
  });
}

class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code = 'AUTH_ERROR',
    super.details,
  });
}

class AccessDeniedException extends AppException {
  const AccessDeniedException({
    super.message = 'Access denied. Account lacks buyer procurement permissions.',
    super.code = 'ACCESS_DENIED',
    super.details,
  });
}

class ServerException extends AppException {
  const ServerException({
    super.message = 'The server encountered an error processing your request.',
    super.code = 'SERVER_ERROR',
    super.details,
  });
}

class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.details,
  });
}
