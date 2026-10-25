import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'secure_storage_service.dart';

/// Outcome of [SessionGuard.ensureValidSession].
enum SessionCheck {
  /// A non-expired session is active (refreshed if it had to be).
  valid,

  /// No session, or the refresh token was rejected: the user must sign in.
  signedOut,

  /// The token is expired and could not be refreshed because the auth server
  /// was unreachable or slow. The session is kept; retry later.
  offline,
}

/// Makes sure the Supabase session is usable before an authenticated request.
///
/// `Supabase.initialize` restores a persisted session immediately, expired or
/// not, and refreshes it in the background without awaiting. On reopen or
/// resume, requests could run in that window with an expired session and fail
/// as if the backend were missing. Callers await this first instead.
class SessionGuard {
  SessionGuard._();

  /// Refresh when the token expires within this margin.
  static const Duration _expiryMargin = Duration(seconds: 30);
  @visibleForTesting
  static Duration refreshTimeout = const Duration(seconds: 15);

  /// One refresh shared by concurrent startup requests.
  static Future<SessionCheck>? _inFlight;

  static Future<SessionCheck> ensureValidSession(
    SupabaseClient? client, {
    SecureStorageService? storage,
  }) async {
    if (client == null) return SessionCheck.signedOut;
    final session = client.auth.currentSession;
    if (session == null) return SessionCheck.signedOut;

    if (!_expiresSoon(session)) {
      await _syncToken(storage, session.accessToken);
      return SessionCheck.valid;
    }
    return _inFlight ??= _refresh(client, storage).whenComplete(() => _inFlight = null);
  }

  static bool _expiresSoon(Session session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return session.isExpired;
    final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    return DateTime.now().add(_expiryMargin).isAfter(expiry);
  }

  static Future<SessionCheck> _refresh(SupabaseClient client, SecureStorageService? storage) async {
    try {
      final res = await client.auth.refreshSession().timeout(refreshTimeout);
      final fresh = res.session ?? client.auth.currentSession;
      if (fresh == null || fresh.isExpired) return SessionCheck.signedOut;
      await _syncToken(storage, fresh.accessToken);
      return SessionCheck.valid;
    } on AuthRetryableFetchException {
      debugPrint('Session refresh deferred: auth server unreachable');
      return SessionCheck.offline;
    } on TimeoutException {
      debugPrint('Session refresh deferred: timed out');
      return SessionCheck.offline;
    } on AuthException catch (e) {
      // Invalid/revoked refresh token or missing session: re-authentication.
      debugPrint('Session refresh rejected (${e.statusCode ?? e.code ?? 'auth'})');
      return SessionCheck.signedOut;
    } catch (e) {
      debugPrint('Session refresh deferred: ${e.runtimeType}');
      return SessionCheck.offline;
    }
  }

  /// Keeps the REST bearer copy in step with the Supabase session.
  static Future<void> _syncToken(SecureStorageService? storage, String accessToken) async {
    if (storage == null) return;
    try {
      if (await storage.getToken() != accessToken) await storage.saveToken(accessToken);
    } catch (_) {
      debugPrint('Session token sync failed');
    }
  }
}
