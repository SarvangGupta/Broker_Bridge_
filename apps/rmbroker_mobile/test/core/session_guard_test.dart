import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/core/security/session_guard.dart';
import 'package:rmbroker_mobile/features/directory/data/directory_repository.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unsigned JWT; gotrue only decodes `exp` locally.
String _jwt(DateTime exp, {String sub = 'broker-1'}) {
  String b64(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${b64({'alg': 'none', 'typ': 'JWT'})}.'
      '${b64({'sub': sub, 'role': 'authenticated', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

Map<String, dynamic> _sessionJson(String accessToken, {String refresh = 'refresh-1'}) => {
      'access_token': accessToken,
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': refresh,
      'user': {
        'id': 'broker-1',
        'aud': 'authenticated',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-10-01T00:00:00Z',
      },
    };

/// Loopback GoTrue token endpoint with a scripted response.
class _FakeAuth {
  late final HttpServer server;
  late final SupabaseClient client;
  int refreshCalls = 0;
  Future<(int, Map<String, dynamic>)> Function() respond =
      () async => (200, _sessionJson(_jwt(DateTime.now().add(const Duration(hours: 1))), refresh: 'refresh-2'));

  static Future<_FakeAuth> start() async {
    final f = _FakeAuth();
    f.server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    f.server.listen((req) async {
      await utf8.decoder.bind(req).join();
      if (req.uri.path.endsWith('/token')) f.refreshCalls++;
      final (status, body) = await f.respond();
      req.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await req.response.close();
    });
    f.client = SupabaseClient(
      'http://127.0.0.1:${f.server.port}',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    return f;
  }

  Future<void> restore(DateTime exp) =>
      client.auth.setInitialSession(jsonEncode(_sessionJson(_jwt(exp))));

  Future<void> close() async {
    await client.dispose();
    await server.close(force: true);
  }
}

void main() {
  late _FakeAuth auth;
  late SecureStorageService storage;
  final past = DateTime.now().subtract(const Duration(hours: 2));

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'rmbroker_access_token': 'stale-token'});
    storage = SecureStorageService();
    auth = await _FakeAuth.start();
    SessionGuard.refreshTimeout = const Duration(seconds: 15);
  });

  tearDown(() => auth.close());

  test('no session: signedOut without any network call', () async {
    expect(await SessionGuard.ensureValidSession(auth.client, storage: storage), SessionCheck.signedOut);
    expect(auth.refreshCalls, 0);
  });

  test('valid session: no refresh, REST bearer synced from session', () async {
    await auth.restore(DateTime.now().add(const Duration(hours: 1)));
    expect(await SessionGuard.ensureValidSession(auth.client, storage: storage), SessionCheck.valid);
    expect(auth.refreshCalls, 0);
    expect(await storage.getToken(), auth.client.auth.currentSession!.accessToken);
  });

  test('expired restored session (reopen/resume): refreshed, then valid', () async {
    await auth.restore(past);
    expect(await SessionGuard.ensureValidSession(auth.client, storage: storage), SessionCheck.valid);
    expect(auth.refreshCalls, 1);
    final s = auth.client.auth.currentSession!;
    expect(s.isExpired, isFalse);
    expect(s.refreshToken, 'refresh-2');
    expect(await storage.getToken(), s.accessToken);
  });

  test('concurrent startup requests share one refresh', () async {
    await auth.restore(past);
    final results = await Future.wait([
      for (var i = 0; i < 4; i++) SessionGuard.ensureValidSession(auth.client, storage: storage),
    ]);
    expect(results, everyElement(SessionCheck.valid));
    expect(auth.refreshCalls, 1);
  });

  test('rejected refresh token: signedOut (re-authentication)', () async {
    await auth.restore(past);
    auth.respond = () async =>
        (400, {'code': 400, 'error_code': 'refresh_token_not_found', 'msg': 'Invalid Refresh Token'});
    expect(await SessionGuard.ensureValidSession(auth.client, storage: storage), SessionCheck.signedOut);
  });

  test('slow auth server: times out as offline, then a retry succeeds', () async {
    await auth.restore(past);
    SessionGuard.refreshTimeout = const Duration(milliseconds: 300);
    final gate = Completer<void>();
    auth.respond = () async {
      await gate.future;
      return (200, _sessionJson(_jwt(DateTime.now().add(const Duration(hours: 1)))));
    };
    expect(await SessionGuard.ensureValidSession(auth.client, storage: storage), SessionCheck.offline);
    gate.complete();
    SessionGuard.refreshTimeout = const Duration(seconds: 15);
    // The late response from the first attempt may already have landed.
    expect(await SessionGuard.ensureValidSession(auth.client, storage: storage), SessionCheck.valid);
  });

  test('unreachable auth server: offline, session kept', () async {
    await auth.restore(past);
    await auth.server.close(force: true);
    expect(await SessionGuard.ensureValidSession(auth.client, storage: storage), SessionCheck.offline);
    expect(auth.client.auth.currentSession, isNotNull);
  });

  group('repositories report the real failure, never a contract notice', () {
    test('requirements: rejected refresh -> WorkUnauthorized', () async {
      await auth.restore(past);
      auth.respond = () async => (400, {'code': 400, 'msg': 'Invalid Refresh Token'});
      final repo = WorkRepository(supabase: auth.client, storage: storage);
      expect(await repo.getRequirements(), isA<WorkUnauthorized>());
    });

    test('requirements: unreachable auth -> retryable WorkError', () async {
      await auth.restore(past);
      await auth.server.close(force: true);
      final repo = WorkRepository(supabase: auth.client, storage: storage);
      final res = await repo.getRequirements();
      expect(res, isA<WorkError>());
      expect((res as WorkError).code, 'OFFLINE');
    });

    test('directory: rejected refresh -> DirectoryUnauthorized', () async {
      await auth.restore(past);
      auth.respond = () async => (400, {'code': 400, 'msg': 'Invalid Refresh Token'});
      final repo = DirectoryRepository(supabase: auth.client, storage: storage);
      expect(await repo.getContacts(limit: 30), isA<DirectoryUnauthorized>());
    });

    test('directory: unreachable auth -> DirectoryError', () async {
      await auth.restore(past);
      await auth.server.close(force: true);
      final repo = DirectoryRepository(supabase: auth.client, storage: storage);
      expect(await repo.getContacts(limit: 30), isA<DirectoryError>());
    });
  });
}
