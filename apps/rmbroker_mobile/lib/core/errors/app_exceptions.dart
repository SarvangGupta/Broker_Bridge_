/// Base class for all structured application exceptions.
sealed class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

/// Network connectivity failure or timeout
class NetworkException extends AppException {
  const NetworkException({
    String message = 'Unable to connect to RMBroker server. Please check your internet connection.',
    String? code,
  }) : super(message, code: code ?? 'NETWORK_ERROR');
}

/// 401 Unauthorized / Token expired
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    String message = 'Your session has expired. Please sign in again.',
    String? code,
  }) : super(message, code: code ?? 'UNAUTHORIZED');
}

/// 403 Forbidden / Insufficient permissions
class ForbiddenException extends AppException {
  const ForbiddenException({
    String message = 'Access denied. Broker role privileges required.',
    String? code,
  }) : super(message, code: code ?? 'FORBIDDEN');
}

/// 404 Resource Not Found
class NotFoundException extends AppException {
  const NotFoundException({
    String message = 'The requested resource was not found.',
    String? code,
  }) : super(message, code: code ?? 'NOT_FOUND');
}

/// 400 Bad Request / Validation Failure
class ValidationException extends AppException {
  const ValidationException({
    required String message,
    String? code,
    dynamic details,
  }) : super(message, code: code ?? 'VALIDATION_ERROR', details: details);
}

/// 500+ Internal Server Error
class ServerException extends AppException {
  const ServerException({
    String message = 'Internal server error occurred. Please try again later.',
    String? code,
  }) : super(message, code: code ?? 'SERVER_ERROR');
}
