import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/live_test_config.dart';
import '../support/network_guard.dart';

String _fakeJwt(Map<String, dynamic> claims) {
  String part(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part(claims)}.signature';
}

Map<String, String> _liveEnv({
  String url = 'https://isolated-test-project.supabase.co',
  String? key,
}) =>
    {
      LiveTestConfig.enableVar: '1',
      'RMBUYER_TEST_SUPABASE_URL': url,
      'RMBUYER_TEST_SUPABASE_ANON_KEY': key ?? _fakeJwt({'ref': 'isolated-test-project', 'role': 'anon'}),
      'RMBUYER_TEST_BUYER_EMAIL': 'buyer@test.invalid',
      'RMBUYER_TEST_BUYER_PASSWORD': 'not-a-real-password',
    };

void main() {
  group('Test network guard', () {
    test('is installed globally for every test file', () {
      expect(HttpOverrides.current, isA<TestNetworkGuardOverrides>());
    });

    test('refuses the production Supabase host before any connection is made', () async {
      expect(HttpOverrides.current, isA<TestNetworkGuardOverrides>());
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      await expectLater(
        client.getUrl(Uri.parse('https://$productionSupabaseProjectRef.supabase.co/rest/v1/requirements')),
        throwsA(isA<TestNetworkAccessBlocked>()),
      );
    });

    test('refuses non-allowed external hosts', () async {
      expect(HttpOverrides.current, isA<TestNetworkGuardOverrides>());
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      await expectLater(
        client.getUrl(Uri.parse('https://example.org/')),
        throwsA(isA<TestNetworkAccessBlocked>()),
      );
    });

    test('a SupabaseClient built from production AppConfig cannot reach the backend', () async {
      // Guard must be active first, otherwise this test would not be safe to continue.
      expect(HttpOverrides.current, isA<TestNetworkGuardOverrides>());
      expect(isProductionSupabaseHost(Uri.parse(AppConfig.supabaseUrl).host), isTrue);

      final client = SupabaseClient(AppConfig.supabaseUrl, AppConfig.supabaseAnonKey);
      addTearDown(client.dispose);

      await expectLater(
        client.from('master_units').select('id').limit(1),
        throwsA(predicate((e) => e.toString().contains('TestNetworkAccessBlocked'))),
      );
    });

    test('production host stays blocked even if listed as allowed', () {
      final guard = TestNetworkGuardOverrides(
        allowedHosts: {'$productionSupabaseProjectRef.supabase.co'},
      );
      expect(
        () => guard.checkUrl(Uri.parse('https://$productionSupabaseProjectRef.supabase.co/auth/v1/token')),
        throwsA(isA<TestNetworkAccessBlocked>()),
      );
      expect(() => guard.checkUrl(Uri.parse('http://localhost:54321/rest/v1/x')), returnsNormally);
    });
  });

  group('LiveTestConfig', () {
    test('live tests are disabled unless explicitly enabled', () {
      expect(LiveTestConfig.isEnabled(const {}), isFalse);
      expect(() => LiveTestConfig.require(const {}), throwsStateError);
      expect(LiveTestConfig.allowedHosts(const {}), isEmpty);
    });

    test('rejects the production project URL', () {
      final env = _liveEnv(url: AppConfig.supabaseUrl);
      expect(() => LiveTestConfig.require(env), throwsStateError);
      expect(LiveTestConfig.allowedHosts(env), isEmpty);
    });

    test('rejects a production key even with a different URL', () {
      final env = _liveEnv(key: _fakeJwt({'ref': productionSupabaseProjectRef, 'role': 'anon'}));
      expect(() => LiveTestConfig.require(env), throwsStateError);
    });

    test('rejects the compiled production anon key', () {
      expect(() => LiveTestConfig.require(_liveEnv(key: AppConfig.supabaseAnonKey)), throwsStateError);
    });

    test('rejects a service-role key', () {
      final env = _liveEnv(key: _fakeJwt({'ref': 'isolated-test-project', 'role': 'service_role'}));
      expect(() => LiveTestConfig.require(env), throwsStateError);
    });

    test('fails closed when enabled but credentials are missing', () {
      final env = _liveEnv()..remove('RMBUYER_TEST_BUYER_PASSWORD');
      expect(() => LiveTestConfig.require(env), throwsStateError);
    });

    test('accepts an isolated non-production backend and allows only its host', () {
      final env = _liveEnv();
      final config = LiveTestConfig.require(env);
      expect(config.supabaseUrl, 'https://isolated-test-project.supabase.co');
      expect(LiveTestConfig.allowedHosts(env), {'isolated-test-project.supabase.co'});
    });
  });
}
