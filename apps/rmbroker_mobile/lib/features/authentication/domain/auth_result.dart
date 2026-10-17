import 'broker_user.dart';

/// Sealed class representing the result of an authentication operation.
sealed class AuthResult {
  const AuthResult();
}

/// Authentication and broker role verification succeeded.
class AuthSuccess extends AuthResult {
  final BrokerUser user;
  const AuthSuccess(this.user);
}

/// User credentials are valid, but the user does not possess broker/admin privileges.
class AuthAccessDenied extends AuthResult {
  final String email;
  final String role;
  final String message;

  const AuthAccessDenied({
    required this.email,
    required this.role,
    required this.message,
  });
}

/// Authentication failed (invalid credentials, network failure, etc.).
class AuthFailure extends AuthResult {
  final String message;
  final String? code;

  const AuthFailure({required this.message, this.code});
}

/// Status of the current session on startup or verification.
enum SessionStatus { authenticated, accessDenied, unauthenticated, expired }
