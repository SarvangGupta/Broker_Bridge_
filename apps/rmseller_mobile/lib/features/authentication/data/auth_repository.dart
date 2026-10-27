import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router/app_router.dart';
import '../../../core/security/secure_storage_service.dart';
import '../domain/auth_result.dart';
import '../domain/seller_user.dart';

/// Status outcomes of an automatic or explicit session recovery attempt.
enum SessionRecoveryState {
  /// Session is valid and active (not expired).
  valid,

  /// Session was expired or unhydrated and was successfully refreshed.
  recovered,

  /// Refresh token is missing, invalid, or revoked; session terminated.
  unrecoverable,

  /// Recovery could not be completed due to network or connection failure.
  networkError,
}

/// Authentication repository interfacing with Supabase Auth and Secure Storage.
/// Strictly enforces Seller Portal role validation (role must be 'seller' or 'admin').
class AuthRepository {
  final SupabaseClient? _customClient;
  final SecureStorageService _storage;
  bool _isSigningIn = false;

  /// Global in-flight recovery future to deduplicate concurrent refresh requests
  /// and prevent Supabase refresh token rotation collision.
  static Future<SessionRecoveryState>? _inFlightRecovery;

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

  /// Whether the client holds an active, unexpired authenticated session.
  bool get hasValidSession {
    final session = _supabase?.auth.currentSession;
    return session != null && !session.isExpired;
  }

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
        .select('id, name, gst, trust_score, is_verified')
        .eq('id', companyId)
        .maybeSingle();
  }

  /// Hook for performing sign out on the underlying client.
  @visibleForTesting
  Future<void> performSignOut(SupabaseClient client) async {
    await client.auth.signOut();
  }

  /// Hook for refreshing an existing Supabase session.
  @visibleForTesting
  Future<AuthResponse> performSessionRefresh(
    SupabaseClient client, [
    String? refreshToken,
  ]) async {
    if (refreshToken != null && refreshToken.isNotEmpty) {
      return await client.auth.refreshSession(refreshToken);
    }
    return await client.auth.refreshSession();
  }

  /// Hook for establishing a Supabase session from a persisted refresh token.
  @visibleForTesting
  Future<AuthResponse> performSetSession(
    SupabaseClient client,
    String refreshToken,
  ) async {
    return await client.auth.setSession(refreshToken);
  }

  /// Authenticate credentials and authoritatively verify seller permissions.
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
      // Deterministic offline test mode / fallback
      _isSigningIn = false;
      final cleanEmail = email.trim().toLowerCase();
      if (cleanEmail == 'buyer@demo.com' || cleanEmail.contains('buyer')) {
        await _storage.clearAll();
        return const AuthAccessDenied(
          email: 'buyer@demo.com',
          role: 'buyer',
          message: 'Seller Portal Access Restricted: Your account role (buyer) does not have commodity seller permissions. Access is strictly restricted to authorized commodity sellers and supply aggregators.',
        );
      }
      if (cleanEmail == 'broker@demo.com' || cleanEmail.contains('broker')) {
        await _storage.clearAll();
        return const AuthAccessDenied(
          email: 'broker@demo.com',
          role: 'broker',
          message: 'Seller Portal Access Restricted: Your account role (broker) does not have commodity seller permissions. Please use the RMBroker desk workstation.',
        );
      }

      // Default authorized seller in test mode
      const defaultUser = SellerUser(
        id: '20000000-0000-0000-0000-000000000001',
        email: 'seller@demo.com',
        fullName: 'Bikaner Agro Traders & Millers',
        role: 'seller',
        companyId: '20000000-0000-0000-0000-000000000101',
        companyName: 'Bikaner Agro Processing Ltd',
        companyGst: '08AAAAA0000A1Z5',
        trustScore: 98,
        isVerified: true,
      );
      await _storage.saveToken('mock_seller_access_token');
      await _storage.saveUserInfo(
        id: defaultUser.id,
        role: defaultUser.role,
        email: defaultUser.email,
        fullName: defaultUser.fullName,
        companyId: defaultUser.companyId,
        companyName: defaultUser.companyName,
        companyGst: defaultUser.companyGst,
      );
      return const AuthSuccess(defaultUser);
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

      String fullName =
          (user.userMetadata?['full_name'] as String?) ??
          (user.userMetadata?['fullName'] as String?) ??
          (user.userMetadata?['name'] as String?) ??
          'Commodity Seller Lead';
      String? companyId;
      String? companyName;
      String? companyGst;
      int trustScore = 100;
      bool isVerified = false;

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
                trustScore = (comp['trust_score'] as num?)?.toInt() ?? 100;
                isVerified = comp['is_verified'] == true;
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('DB profile lookup notice: $e');
      }

      // Priority 3: Fallback to userMetadata for role and enterprise credentials
      if (serverRole == null || serverRole.isEmpty) {
        serverRole = user.userMetadata?['role'] as String?;
      }
      // A company comes only from the server users row. No hard-coded demo
      // company, and not user_metadata (self-editable, so never ownership).
      // An unlinked seller keeps companyId == null and can still use the
      // desk (RB-SELLER-INDIVIDUAL-ACCESS-FIX-01). Display name only:
      companyName ??= user.userMetadata?['company_name'] as String?;

      // Role check: Strictly assert seller or admin permissions
      final resolvedRole = (serverRole ?? '').toLowerCase().trim();
      final isAuthorized =
          resolvedRole == 'seller' ||
          resolvedRole == 'admin' ||
          resolvedRole == 'seller_admin';

      if (!isAuthorized) {
        try {
          await performSignOut(client);
        } catch (_) {}
        await _storage.clearAll();

        return AuthAccessDenied(
          email: user.email ?? email,
          role: resolvedRole.isEmpty ? 'unauthorized' : resolvedRole,
          message:
              'Seller Portal Access Restricted: Your account role (${resolvedRole.isEmpty ? 'unassigned' : resolvedRole}) does not have commodity seller permissions. Access is strictly restricted to authorized commodity sellers.',
        );
      }

      // Persist verified seller credentials securely
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
        companyGst: companyGst,
      );

      // Hydrate persistent default warehouse from authoritative auth metadata
      final wh = (user.userMetadata?['default_warehouse'] as Map<String, dynamic>?) ??
          (user.userMetadata?['warehouse'] as Map<String, dynamic>?);
      if (wh != null &&
          wh['address_line'] != null &&
          wh['address_line'].toString().trim().isNotEmpty) {
        final addr = wh['address_line'].toString();
        final name = (wh['name'] ?? '').toString();
        final locality = (wh['locality'] ?? '').toString();
        final stateId = (wh['state_id'] ?? '').toString();
        final stateName = (wh['state_name'] ?? '').toString();
        final districtId = (wh['district_id'] ?? '').toString();
        final districtName = (wh['district_name'] ?? '').toString();
        final pinCode = (wh['pin_code'] ?? '').toString();

        await _storage.savePreference('business_location_address_${user.id}', addr);
        await _storage.savePreference('business_location_name_${user.id}', name);
        await _storage.savePreference('business_location_locality_${user.id}', locality);
        await _storage.savePreference('business_location_state_id_${user.id}', stateId);
        await _storage.savePreference('business_location_state_${user.id}', stateName);
        await _storage.savePreference('business_location_district_id_${user.id}', districtId);
        await _storage.savePreference('business_location_district_${user.id}', districtName);
        await _storage.savePreference('business_location_pincode_${user.id}', pinCode);

        await _storage.savePreference('business_location_address', addr);
        await _storage.savePreference('business_location_name', name);
        await _storage.savePreference('business_location_locality', locality);
        await _storage.savePreference('business_location_state_id', stateId);
        await _storage.savePreference('business_location_state', stateName);
        await _storage.savePreference('business_location_district_id', districtId);
        await _storage.savePreference('business_location_district', districtName);
        await _storage.savePreference('business_location_pincode', pinCode);
      }
      final sellerUser = SellerUser(
        id: user.id,
        email: user.email ?? email,
        fullName: fullName,
        role: resolvedRole,
        companyId: companyId,
        companyName: companyName,
        companyGst: companyGst,
        trustScore: trustScore,
        isVerified: isVerified,
      );

      return AuthSuccess(sellerUser);
    } on AuthException catch (e) {
      return AuthFailure(message: e.message, code: 'AUTH_ERROR');
    } catch (e) {
      return AuthFailure(message: e.toString(), code: 'UNEXPECTED_ERROR');
    } finally {
      _isSigningIn = false;
    }
  }

  /// Sign out the current seller and clean up local secure storage.
  Future<void> signOut() async {
    final client = _supabase;
    if (client != null) {
      try {
        await performSignOut(client);
      } catch (_) {}
    }
    await _storage.clearAll();
    try {
      AppRouter.authNotifier.setUnauthenticated();
    } catch (_) {}
  }

  /// Safely recovers or refreshes an expired session using Supabase refresh token.
  /// Deduplicates concurrent recovery calls across the app via a single in-flight future
  /// to eliminate Gotrue refresh token rotation collisions.
  Future<SessionRecoveryState> recoverSession({bool force = false}) async {
    final client = _supabase;
    if (client == null) {
      final token = await _storage.getToken();
      return token != null
          ? SessionRecoveryState.valid
          : SessionRecoveryState.unrecoverable;
    }

    final current = client.auth.currentSession;
    if (!force && current != null && !current.isExpired) {
      return SessionRecoveryState.valid;
    }

    if (_inFlightRecovery != null) {
      return await _inFlightRecovery!;
    }

    final future = _performRecovery(client);
    _inFlightRecovery = future;
    try {
      return await future;
    } finally {
      _inFlightRecovery = null;
    }
  }

  Future<SessionRecoveryState> _performRecovery(SupabaseClient client) async {
    try {
      final current = client.auth.currentSession;
      AuthResponse? response;

      if (current != null && current.refreshToken != null) {
        response = await performSessionRefresh(client, current.refreshToken);
      } else {
        final storedRefreshToken = await _storage.getRefreshToken();
        if (storedRefreshToken != null && storedRefreshToken.isNotEmpty) {
          response = await performSetSession(client, storedRefreshToken);
        }
      }

      final session = response?.session ?? client.auth.currentSession;
      if (session != null && !session.isExpired) {
        await _storage.saveToken(session.accessToken);
        if (session.refreshToken != null) {
          await _storage.saveRefreshToken(session.refreshToken!);
        }
        return SessionRecoveryState.recovered;
      }

      await _handleUnrecoverableSession(client);
      return SessionRecoveryState.unrecoverable;
    } on AuthException catch (e) {
      debugPrint('Auth recovery notice: ${e.message}');
      final msg = e.message.toLowerCase();
      if (msg.contains('network') ||
          msg.contains('socket') ||
          msg.contains('failed host lookup') ||
          msg.contains('connection refused') ||
          msg.contains('timeout')) {
        return SessionRecoveryState.networkError;
      }
      await _handleUnrecoverableSession(client);
      return SessionRecoveryState.unrecoverable;
    } on SocketException catch (_) {
      return SessionRecoveryState.networkError;
    } on HttpException catch (_) {
      return SessionRecoveryState.networkError;
    } on TimeoutException catch (_) {
      return SessionRecoveryState.networkError;
    } catch (e) {
      debugPrint('Unexpected auth recovery error: $e');
      final str = e.toString().toLowerCase();
      if (str.contains('network') ||
          str.contains('socket') ||
          str.contains('connection') ||
          str.contains('timeout')) {
        return SessionRecoveryState.networkError;
      }
      await _handleUnrecoverableSession(client);
      return SessionRecoveryState.unrecoverable;
    }
  }

  Future<void> _handleUnrecoverableSession(SupabaseClient client) async {
    try {
      await performSignOut(client);
    } catch (_) {}
    await _storage.clearAll();
    try {
      AppRouter.authNotifier.setUnauthenticated();
    } catch (_) {}
  }

  /// Check whether a valid saved session exists, recovering an expired session if possible.
  Future<SellerUser?> getSavedUser() async {
    final token = await _storage.getToken();
    final userId = await _storage.getUserId();
    final role = await _storage.getUserRole();
    final email = await _storage.getUserEmail();
    final fullName = await _storage.getUserFullName();
    final companyId = await _storage.getCompanyId();
    final companyName = await _storage.getCompanyName();
    final companyGst = await _storage.getCompanyGst();

    if (token == null || userId == null || role == null || email == null) {
      return null;
    }

    final client = _supabase;
    if (client != null) {
      var session = client.auth.currentSession;
      if (session == null || session.isExpired || session.user.id != userId) {
        final recovery = await recoverSession();
        if (recovery == SessionRecoveryState.unrecoverable) {
          return null;
        }
        // If recovery == SessionRecoveryState.networkError, device is offline
        // Preserve saved credentials so offline experience continues cleanly
        session = client.auth.currentSession;
        if (session != null && session.user.id != userId) {
          await _storage.clearAll();
          return null;
        }
      }
    }

    final cleanRole = role.toLowerCase().trim();
    if (cleanRole != 'seller' &&
        cleanRole != 'admin' &&
        cleanRole != 'seller_admin') {
      await _storage.clearAll();
      return null;
    }

    return SellerUser(
      id: userId,
      email: email,
      fullName: fullName ?? 'Commodity Seller',
      role: cleanRole,
      companyId: companyId,
      companyName: companyName,
      companyGst: companyGst,
    );
  }
}
