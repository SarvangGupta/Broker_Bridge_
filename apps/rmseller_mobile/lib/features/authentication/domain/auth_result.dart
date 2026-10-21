import 'seller_user.dart';

/// Sealed-like result hierarchy for authentication and role verification operations.
abstract class AuthResult {
  const AuthResult();
}

/// Successfully authenticated with a verified seller/admin role.
class AuthSuccess extends AuthResult {
  final SellerUser user;
  const AuthSuccess(this.user);
}

/// Authentication failed due to invalid credentials, network failure, or client error.
class AuthFailure extends AuthResult {
  final String message;
  final String code;
  const AuthFailure({required this.message, required this.code});
}

/// Authentication credentials were valid, but the user is unauthorized for the Seller Portal.
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
