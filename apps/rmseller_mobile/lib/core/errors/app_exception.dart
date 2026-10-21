/// Base class for all custom application domain and data exceptions.
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
  String toString() => message;
}

/// Network-level connectivity or transport exceptions (e.g. offline, DNS failure, timeout).
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'Network connection unavailable. Please check your data or Wi-Fi.',
    super.code = 'NETWORK_ERROR',
    super.details,
  });
}

/// Server-side HTTP errors (5xx responses or unexpected payload structures).
class ServerException extends AppException {
  const ServerException({
    required super.message,
    super.code = 'SERVER_ERROR',
    super.details,
  });
}

/// Authentication and session token validation failures (401 responses).
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code = 'AUTH_ERROR',
    super.details,
  });
}

/// Authorization and counterparty boundary violations (403 responses).
class AccessDeniedException extends AppException {
  const AccessDeniedException({
    required super.message,
    super.code = 'ACCESS_DENIED',
    super.details,
  });
}

/// Client-side input and payload validation failures (422 responses).
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.details,
  });
}
