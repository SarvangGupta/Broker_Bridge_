import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/secure_storage_service.dart';
import '../../../core/security/session_guard.dart';
import '../domain/auth_result.dart';
import '../domain/broker_user.dart';

/// Authentication repository interfacing with Supabase Auth and Secure Storage.
class AuthRepository {
  final SupabaseClient? _customClient;
  final SecureStorageService _storage;

  AuthRepository({SupabaseClient? supabase, SecureStorageService? storage})
    : _customClient = supabase,
      _storage = storage ?? SecureStorageService();

  SupabaseClient? get _supabase {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser => _supabase?.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  /// Authenticate broker credentials and authoritatively verify broker desk role.
  Future<AuthResult> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _supabase;
    if (client == null) {
      return const AuthFailure(
        message: 'Authentication client not initialized',
        code: 'CLIENT_NOT_INITIALIZED',
      );
    }

    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final session = response.session;
      final user = response.user;

      if (session == null || user == null) {
        return const AuthFailure(
          message: 'Unable to establish authentication session',
          code: 'NO_SESSION',
        );
      }

      // Authoritative Role Resolution:
      // 1. Initial check from JWT metadata
      String? role = user.userMetadata?['role'] as String?;
      String fullName =
          (user.userMetadata?['full_name'] as String?) ??
          (user.userMetadata?['fullName'] as String?) ??
          'Commodity Broker';
      String? companyId;

      // 2. Authoritative check from public.users table if accessible
      try {
        final profile = await client
            .from('users')
            .select('id, role, full_name, company_id')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null) {
          if (profile['role'] != null) {
            role = profile['role'] as String;
          }
          if (profile['full_name'] != null) {
            fullName = profile['full_name'] as String;
          }
          if (profile['company_id'] != null) {
            companyId = profile['company_id'] as String?;
          }
        }
      } catch (_) {
        // Fallback to metadata if DB lookup is restricted or times out
      }

      final normalizedRole = (role ?? '').toLowerCase().trim();
      final isAuthorized =
          normalizedRole == 'broker' || normalizedRole == 'admin';

      if (!isAuthorized) {
        // User authenticated but lacks broker/admin privileges (e.g. buyer, seller)
        await client.auth.signOut();
        await _storage.clearAll();

        return AuthAccessDenied(
          email: user.email ?? email,
          role: role ?? 'unassigned',
          message:
              'Broker Desk Access Restricted: Your account role ($role) does not have commodity broker desk permissions. Access is restricted to licensed brokers and desk administrators.',
        );
      }

      // Persist credentials securely
      await _storage.saveToken(session.accessToken);
      if (session.refreshToken != null) {
        await _storage.saveRefreshToken(session.refreshToken!);
      }
      await _storage.saveUserInfo(
        id: user.id,
        role: normalizedRole,
        email: user.email ?? email,
        fullName: fullName,
      );

      final brokerUser = BrokerUser(
        id: user.id,
        email: user.email ?? email,
        fullName: fullName,
        role: normalizedRole,
        companyId: companyId,
      );

      return AuthSuccess(brokerUser);
    } on AuthException catch (e) {
      String sanitizedMessage = e.message;
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        sanitizedMessage = 'Invalid email or password. Please verify your credentials and try again.';
      } else if (e.message.toLowerCase().contains('email not confirmed')) {
        sanitizedMessage =
            'Email address is not yet confirmed. Please check your inbox.';
      }
      return AuthFailure(message: sanitizedMessage, code: e.statusCode);
    } catch (e) {
      return const AuthFailure(
        message: 'Unable to connect to the authentication server. Please check your internet connection.',
        code: 'NETWORK_ERROR',
      );
    }
  }

  /// Check whether an active, valid broker session exists on app launch.
  Future<SessionStatus> checkSession() async {
    final client = _supabase;
    if (client != null) {
      // The restored session may be expired while supabase_flutter refreshes
      // it in the background; refresh it here instead of signing out.
      final check = await SessionGuard.ensureValidSession(client, storage: _storage);
      if (check == SessionCheck.signedOut) {
        final hadSession = client.auth.currentSession != null ||
            (await _storage.getToken())?.isNotEmpty == true;
        await signOut();
        return hadSession ? SessionStatus.expired : SessionStatus.unauthenticated;
      }
      final session = client.auth.currentSession;
      if (session != null) {

        // Check role authorization
        final storedRole = await _storage.getUserRole();
        final metaRole = session.user.userMetadata?['role'] as String?;
        final role = (storedRole ?? metaRole ?? '').toLowerCase().trim();

        if (role == 'broker' || role == 'admin') {
          await _storage.saveToken(session.accessToken);
          return SessionStatus.authenticated;
        } else {
          return SessionStatus.accessDenied;
        }
      }
    }

    // Secondary check from secure storage
    final token = await _storage.getToken();
    final role = (await _storage.getUserRole() ?? '').toLowerCase().trim();

    if (token != null && token.isNotEmpty) {
      if (role == 'broker' || role == 'admin') {
        return SessionStatus.authenticated;
      } else {
        return SessionStatus.accessDenied;
      }
    }

    return SessionStatus.unauthenticated;
  }

  /// Retrieve the current logged-in broker details from secure storage.
  Future<BrokerUser?> getCurrentBroker() async {
    final id = await _storage.getUserId();
    final role = await _storage.getUserRole();
    final email = await _storage.getUserEmail();
    final name = await _storage.getUserName();

    if (id == null || role == null) return null;

    return BrokerUser(
      id: id,
      email: email ?? '',
      fullName: name ?? 'Commodity Broker',
      role: role,
    );
  }

  /// Securely terminate the session and wipe cached tokens and identifiers.
  Future<void> signOut() async {
    try {
      await _supabase?.auth.signOut();
    } catch (_) {
      // Continue cleanup even if network fails
    } finally {
      await _storage.clearAll();
    }
  }
}
