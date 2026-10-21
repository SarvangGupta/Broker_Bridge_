import 'package:flutter/foundation.dart';
import '../../domain/seller_user.dart';

enum AuthStatus {
  initial,
  unauthenticated,
  authenticated,
  accessDenied,
}

/// Shared Notifier managing authentication state and route guarding for RMSeller.
class AuthNotifier extends ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  SellerUser? _user;
  String? _deniedEmail;
  String? _deniedRole;
  String? _deniedMessage;

  AuthStatus get status => _status;
  SellerUser? get user => _user;
  String? get deniedEmail => _deniedEmail;
  String? get deniedRole => _deniedRole;
  String? get deniedMessage => _deniedMessage;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  void setAuthenticated(SellerUser user) {
    _user = user;
    _status = AuthStatus.authenticated;
    _deniedEmail = null;
    _deniedRole = null;
    _deniedMessage = null;
    notifyListeners();
  }

  void setUnauthenticated() {
    _user = null;
    _status = AuthStatus.unauthenticated;
    _deniedEmail = null;
    _deniedRole = null;
    _deniedMessage = null;
    notifyListeners();
  }

  void setAccessDenied({
    required String email,
    required String role,
    String? message,
  }) {
    _user = null;
    _status = AuthStatus.accessDenied;
    _deniedEmail = email;
    _deniedRole = role;
    _deniedMessage = message;
    notifyListeners();
  }

  void setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
