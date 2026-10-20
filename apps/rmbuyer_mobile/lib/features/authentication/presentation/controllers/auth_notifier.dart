import 'package:flutter/foundation.dart';
import '../../domain/buyer_user.dart';

/// Lifecycle status for buyer authentication and authorization.
enum AuthStatus {
  /// Session check in progress on app launch (splash phase).
  initial,

  /// Valid authenticated session with verified 'buyer' or 'admin' role.
  authenticated,

  /// No active session or session explicitly terminated / expired.
  unauthenticated,

  /// User successfully authenticated with Supabase Auth, but their server-side
  /// role is unauthorized for RMBuyer (e.g., broker, seller, or unassigned).
  accessDenied,
}

/// Listenable notifier tracking authentication and authoritative role status.
/// Powers GoRouter redirect guards to prevent unauthorized route access.
class AuthNotifier extends ChangeNotifier {
  AuthStatus _status;
  BuyerUser? _currentUser;
  String? _deniedEmail;
  String? _deniedRole;
  String? _deniedMessage;

  AuthNotifier({AuthStatus initialStatus = AuthStatus.initial})
      : _status = initialStatus;

  AuthStatus get status => _status;
  BuyerUser? get currentUser => _currentUser;
  String? get deniedEmail => _deniedEmail;
  String? get deniedRole => _deniedRole;
  String? get deniedMessage => _deniedMessage;

  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isAccessDenied => _status == AuthStatus.accessDenied;
  bool get isUnauthenticated => _status == AuthStatus.unauthenticated;
  bool get isInitial => _status == AuthStatus.initial;

  /// Mark the session as authorized with a valid BuyerUser.
  void setAuthenticated(BuyerUser user) {
    _status = AuthStatus.authenticated;
    _currentUser = user;
    _deniedEmail = null;
    _deniedRole = null;
    _deniedMessage = null;
    notifyListeners();
  }

  /// Mark the session as signed out or expired.
  void setUnauthenticated() {
    _status = AuthStatus.unauthenticated;
    _currentUser = null;
    _deniedEmail = null;
    _deniedRole = null;
    _deniedMessage = null;
    notifyListeners();
  }

  /// Mark the session as authenticated but denied due to an unauthorized role.
  void setAccessDenied({
    required String email,
    required String role,
    String? message,
  }) {
    _status = AuthStatus.accessDenied;
    _currentUser = null;
    _deniedEmail = email;
    _deniedRole = role;
    _deniedMessage = message;
    notifyListeners();
  }

  /// Directly set the status (useful for tests or state synchronization).
  void setStatus(AuthStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  /// Reset notifier to clean initial state.
  void reset() {
    _status = AuthStatus.initial;
    _currentUser = null;
    _deniedEmail = null;
    _deniedRole = null;
    _deniedMessage = null;
    notifyListeners();
  }
}
