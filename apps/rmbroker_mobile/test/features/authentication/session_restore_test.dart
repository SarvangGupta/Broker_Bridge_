import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/network/auth_interceptor.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/core/security/session_guard.dart';
import 'package:rmbroker_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmbroker_mobile/features/authentication/domain/auth_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unsigned JWT; gotrue only decodes `exp` locally.
String _jwt(DateTime exp) {
  String b64(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${b64({'alg': 'none', 'typ': 'JWT'})}.'
      '${b64({'sub': 'broker-1', 'role': 'authenticated', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

Map<String, dynamic> _sessionJson(String accessToken, {String refresh = 'refresh-1'}) => {
      'access_token': accessToken,
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': refresh,
      'user': {
        'id': 'broker-1',
        'aud': 'authenticated',
        'email': 'broker@bb.com',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-10-01T00:00:00Z',
      },
    };

/// Loopback Supabase: GoTrue token/logout plus the `public.users` profile row.
class _FakeBackend {
  late final HttpServer server;
  late final SupabaseClient client;
  int refreshCalls = 0;
  int logoutCalls = 0;
  int profileCalls = 0;
  String profileRole = 'broker';
  (int, Map<String, dynamic>) Function() refreshResponse =
      () => (200, _sessionJson(_jwt(DateTime.now().add(const Duration(hours: 1))), refresh: 'refresh-2'));

  static Future<_FakeBackend> start() async {
    final f = _FakeBackend();
    f.server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    f.server.listen((req) async {
      await utf8.decoder.bind(req).join();
      final path = req.uri.path;
      var (status, body) = (200, <String, dynamic>{});
      if (path.endsWith('/token')) {
        f.refreshCalls++;
        (status, body) = f.refreshResponse();
      } else if (path.endsWith('/logout')) {
        f.logoutCalls++;
      } else if (path.endsWith('/users')) {
        f.profileCalls++;
        body = {'id': 'broker-1', 'role': f.profileRole, 'full_name': 'Desk Broker'};
      } else if (path.contains('/broker/')) {
        (status, body) = (401, {'error': 'Unauthorized'});
      }
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

  /// Simulates app relaunch: supabase_flutter restores the persisted session.
  Future<void> relaunchWith(DateTime exp) =>
      client.auth.setInitialSession(jsonEncode(_sessionJson(_jwt(exp))));

  Future<void> close() async {
    await client.dispose();
    await server.close(force: true);
  }
}

void main() {
  late _FakeBackend backend;
  late SecureStorageService storage;
  late AuthRepository repo;
  final past = DateTime.now().subtract(const Duration(hours: 2));
  final future = DateTime.now().add(const Duration(hours: 1));

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({
      'rmbroker_access_token': 'old-token',
      'rmbroker_user_id': 'broker-1',
      'rmbroker_user_role': 'broker',
      'rmbroker_user_email': 'broker@bb.com',
      'rmbroker_user_name': 'Desk Broker',
    });
    storage = SecureStorageService();
    backend = await _FakeBackend.start();
    repo = AuthRepository(supabase: backend.client, storage: storage);
    SessionGuard.refreshTimeout = const Duration(seconds: 15);
  });

  tearDown(() => backend.close());

  test('app restart with valid session: authenticated without login', () async {
    await backend.relaunchWith(future);
    expect(await repo.checkSession(), SessionStatus.authenticated);
    expect(backend.refreshCalls, 0);
    expect(backend.profileCalls, 0);
    final broker = await repo.getCurrentBroker();
    expect(broker!.id, 'broker-1');
    expect(broker.role, 'broker');
  });

  test('app restart with expired access token: refreshed and authenticated', () async {
    await backend.relaunchWith(past);
    expect(await repo.checkSession(), SessionStatus.authenticated);
    expect(backend.refreshCalls, 1);
    expect(backend.client.auth.currentSession!.refreshToken, 'refresh-2');
    expect(await storage.getToken(), backend.client.auth.currentSession!.accessToken);
  });

  test('cached identity wiped (Keystore reset / old 401 cleanup): rebuilt from profile', () async {
    FlutterSecureStorage.setMockInitialValues({});
    storage = SecureStorageService();
    repo = AuthRepository(supabase: backend.client, storage: storage);
    await backend.relaunchWith(future);

    expect(await repo.checkSession(), SessionStatus.authenticated);
    expect(backend.profileCalls, 1);
    final broker = await repo.getCurrentBroker();
    expect(broker!.id, 'broker-1');
    expect(broker.role, 'broker');
    expect(broker.fullName, 'Desk Broker');
  });

  test('cached identity from another account is not reused', () async {
    FlutterSecureStorage.setMockInitialValues({
      'rmbroker_user_id': 'someone-else',
      'rmbroker_user_role': 'broker',
    });
    storage = SecureStorageService();
    repo = AuthRepository(supabase: backend.client, storage: storage);
    backend.profileRole = 'buyer';
    await backend.relaunchWith(future);

    expect(await repo.checkSession(), SessionStatus.accessDenied);
    expect(await storage.getUserId(), 'broker-1');
  });

  test('revoked refresh token: signed out and routed to login', () async {
    await backend.relaunchWith(past);
    backend.refreshResponse =
        () => (400, {'code': 400, 'error_code': 'refresh_token_not_found', 'msg': 'Invalid Refresh Token'});

    expect(await repo.checkSession(), SessionStatus.expired);
    expect(backend.client.auth.currentSession, isNull);
    expect(await storage.getUserRole(), isNull);
  });

  test('explicit sign out clears session; next launch shows login', () async {
    await backend.relaunchWith(future);
    expect(await repo.checkSession(), SessionStatus.authenticated);

    await repo.signOut();
    expect(backend.logoutCalls, 1);
    expect(backend.client.auth.currentSession, isNull);
    expect(await storage.getToken(), isNull);
    expect(await storage.getUserRole(), isNull);

    expect(await repo.checkSession(), SessionStatus.unauthenticated);
  });

  test('REST 401 no longer wipes the cached broker identity', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${backend.server.port}'))
      ..interceptors.add(AuthInterceptor(storage: storage));
    await expectLater(dio.get('/api/v1/broker/dashboard'), throwsA(isA<DioException>()));

    expect(await storage.getUserRole(), 'broker');
    expect(await storage.getUserId(), 'broker-1');
  });
}
