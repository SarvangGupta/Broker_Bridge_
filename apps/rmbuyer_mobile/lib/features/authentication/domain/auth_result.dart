import 'buyer_user.dart';

sealed class AuthResult {
  const AuthResult();
}

class AuthSuccess extends AuthResult {
  final BuyerUser user;
  const AuthSuccess(this.user);
}

class AuthFailure extends AuthResult {
  final String message;
  final String? code;
  const AuthFailure({required this.message, this.code});
}

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

enum SessionStatus {
  authenticated,
  unauthenticated,
  accessDenied,
  expired,
}
