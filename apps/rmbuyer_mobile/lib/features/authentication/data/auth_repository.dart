import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/secure_storage_service.dart';
import '../domain/auth_result.dart';
import '../domain/buyer_user.dart';

/// Authentication repository interfacing with Supabase Auth and Secure Storage.
/// Strictly enforces Buyer Portal role validation (role must be 'buyer' or 'admin').
class AuthRepository {
  final SupabaseClient? _customClient;
  final SecureStorageService _storage;
  bool _isSigningIn = false;

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

  SecureStorageService get storage => _storage;

  User? get currentUser => _supabase?.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  bool get isSigningIn => _isSigningIn;

  /// Hook for performing the underlying Supabase sign-in call.
  @visibleForTesting
  Future<AuthResponse> performSignIn(
    SupabaseClient client,
    String email,
    String password,
  ) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Hook for performing the authoritative user profile database lookup.
  @visibleForTesting
  Future<Map<String, dynamic>?> performProfileLookup(
    SupabaseClient client,
    String userId,
  ) async {
    return await client
        .from('users')
        .select('id, role, name, company_id')
        .eq('id', userId)
        .maybeSingle();
  }

  /// Hook for performing the enterprise company lookup.
  @visibleForTesting
  Future<Map<String, dynamic>?> performCompanyLookup(
    SupabaseClient client,
    String companyId,
  ) async {
    return await client
        .from('companies')
        .select('id, name, gst')
        .eq('id', companyId)
        .maybeSingle();
  }

  /// Hook for performing sign out on the underlying client.
  @visibleForTesting
  Future<void> performSignOut(SupabaseClient client) async {
    await client.auth.signOut();
  }

  /// Authenticate credentials and authoritatively verify buyer permissions.
  /// Prevents concurrent or repeated submissions while a request is active.
  Future<AuthResult> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (_isSigningIn) {
      return const AuthFailure(
        message: 'Authentication request already in progress. Please wait.',
        code: 'REQUEST_IN_PROGRESS',
      );
    }

    _isSigningIn = true;
    final client = _supabase;
    if (client == null) {
      _isSigningIn = false;
      return const AuthFailure(
        message: 'Authentication client not initialized',
        code: 'CLIENT_NOT_INITIALIZED',
      );
    }

    try {
      final response = await performSignIn(client, email.trim(), password);

      final session = response.session;
      final user = response.user;

      if (session == null || user == null) {
        return const AuthFailure(
          message: 'Unable to establish authentication session',
          code: 'NO_SESSION',
        );
      }

      // Authoritative Server-Side Role Resolution:
      // Priority 1: Supabase JWT app_metadata (server-controlled, immutable by client)
      String? serverRole = user.appMetadata['role'] as String?;

      String fullName = (user.userMetadata?['full_name'] as String?) ??
          (user.userMetadata?['fullName'] as String?) ??
          (user.userMetadata?['name'] as String?) ??
          'Buyer Procurement Lead';
      String? companyId;
      String? companyName;
      String? companyGst;

      // Priority 2: Database lookup in public.users (authoritative source of truth)
      try {
        final profile = await performProfileLookup(client, user.id);

        if (profile != null) {
          if (profile['role'] != null) {
            serverRole = profile['role'] as String;
          }
          if (profile['name'] != null) {
            fullName = profile['name'] as String;
          }
          if (profile['company_id'] != null) {
            companyId = profile['company_id'] as String?;

            // Fetch company details if linked
            try {
              final comp = await performCompanyLookup(client, companyId!);
              if (comp != null) {
                companyName = comp['name'] as String?;
                companyGst = comp['gst'] as String?;
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('DB profile lookup notice: $e');
      }

      // Security Constraint: NEVER trust client-editable userMetadata['role']
      // for privilege granting. If server authority is missing or unauthorized,
      // unverified userMetadata claims cannot grant buyer/admin permissions.
      final resolvedRole = (serverRole ?? '').toLowerCase().trim();
      final isAuthorized = resolvedRole == 'buyer' || resolvedRole == 'admin';

      if (!isAuthorized) {
        // User authenticated with valid credentials, but is not authorized to act as buyer
        // (e.g. seller accounts, broker desk accounts, or unassigned roles)
        try {
          await performSignOut(client);
        } catch (_) {}
        await _storage.clearAll();

        return AuthAccessDenied(
          email: user.email ?? email,
          role: resolvedRole.isEmpty ? 'unauthorized' : resolvedRole,
          message:
              'Buyer Portal Access Restricted: Your account role (${resolvedRole.isEmpty ? 'unassigned' : resolvedRole}) does not have commodity buyer permissions. Access is strictly restricted to authorized commodity procurement buyers.',
        );
      }

      // Persist verified buyer credentials securely in encrypted keystore/keychain
      await _storage.saveToken(session.accessToken);
      if (session.refreshToken != null) {
        await _storage.saveRefreshToken(session.refreshToken!);
      }
      await _storage.saveUserInfo(
        id: user.id,
        role: resolvedRole,
        email: user.email ?? email,
        fullName: fullName,
        companyId: companyId,
        companyName: companyName,
      );

      final buyerUser = BuyerUser(
        id: user.id,
        email: user.email ?? email,
        fullName: fullName,
        role: resolvedRole,
        companyId: companyId,
        companyName: companyName,
        companyGst: companyGst,
      );

      return AuthSuccess(buyerUser);
    } on AuthException catch (e) {
      String sanitized = e.message;
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        sanitized = 'Invalid email or password. Please verify your credentials and try again.';
      } else if (e.message.toLowerCase().contains('email not confirmed')) {
        sanitized = 'Email address is not yet confirmed. Please check your inbox.';
      }
      return AuthFailure(message: sanitized, code: e.statusCode);
    } catch (e) {
      return const AuthFailure(
        message: 'Unable to connect to the authentication server. Please check your internet connection.',
        code: 'NETWORK_ERROR',
      );
    } finally {
      _isSigningIn = false;
    }
  }

  /// Check whether an active, valid buyer session exists on app launch.
  /// Validates both session expiration and server-side role authority.
  Future<SessionStatus> checkSession() async {
    final client = _supabase;
    if (client != null) {
      final session = client.auth.currentSession;
      if (session != null) {
        if (session.isExpired) {
          await signOut();
          return SessionStatus.expired;
        }

        // Authoritative role check: JWT app_metadata takes precedence over local cache
        final appMetaRole = session.user.appMetadata['role'] as String?;
        final storedRole = await _storage.getUserRole();
        final role = (appMetaRole ?? storedRole ?? '').toLowerCase().trim();

        if (role == 'buyer' || role == 'admin') {
          await _storage.saveToken(session.accessToken);
          return SessionStatus.authenticated;
        } else {
          await signOut();
          return SessionStatus.accessDenied;
        }
      }
    }

    // Secondary check from encrypted secure storage (offline / cold launch cache)
    final token = await _storage.getToken();
    final role = (await _storage.getUserRole() ?? '').toLowerCase().trim();

    if (token != null && token.isNotEmpty) {
      if (role == 'buyer' || role == 'admin') {
        return SessionStatus.authenticated;
      } else {
        await _storage.clearAll();
        return SessionStatus.accessDenied;
      }
    }

    return SessionStatus.unauthenticated;
  }

  /// Retrieve the current logged-in buyer details from secure storage.
  Future<BuyerUser?> getCurrentBuyer() async {
    final id = await _storage.getUserId();
    final role = await _storage.getUserRole();
    final email = await _storage.getUserEmail();
    final name = await _storage.getUserName();
    final companyId = await _storage.getCompanyId();
    final companyName = await _storage.getCompanyName();

    if (id == null || role == null) return null;

    return BuyerUser(
      id: id,
      email: email ?? '',
      fullName: name ?? 'Buyer Procurement Lead',
      role: role,
      companyId: companyId,
      companyName: companyName,
    );
  }

  /// Securely terminate the session and wipe cached tokens and identifiers.
  Future<void> signOut() async {
    final client = _supabase;
    if (client != null) {
      try {
        await performSignOut(client);
      } catch (_) {
        // Continue cleanup even if network fails
      }
    }
    await _storage.clearAll();
  }
}
