import 'dart:convert';
import 'dart:io';

import 'network_guard.dart';

/// Opt-in configuration for tests that talk to a real Supabase backend.
///
/// Live tests run only when `RMBUYER_LIVE_TESTS=1` and every value comes from
/// the environment. There is no fallback to `AppConfig` (production defaults),
/// and a production URL or key is rejected so the test fails closed.
///
/// Required: RMBUYER_TEST_SUPABASE_URL, RMBUYER_TEST_SUPABASE_ANON_KEY,
///           RMBUYER_TEST_BUYER_EMAIL, RMBUYER_TEST_BUYER_PASSWORD
/// Optional: RMBUYER_TEST_SECOND_BUYER_EMAIL, RMBUYER_TEST_SECOND_BUYER_PASSWORD,
///           RMBUYER_TEST_BROKER_ID
class LiveTestConfig {
  static const String enableVar = 'RMBUYER_LIVE_TESTS';

  final String supabaseUrl;
  final String anonKey;
  final String buyerEmail;
  final String buyerPassword;
  final String? secondBuyerEmail;
  final String? secondBuyerPassword;
  final String? brokerId;

  const LiveTestConfig._({
    required this.supabaseUrl,
    required this.anonKey,
    required this.buyerEmail,
    required this.buyerPassword,
    this.secondBuyerEmail,
    this.secondBuyerPassword,
    this.brokerId,
  });

  static bool isEnabled([Map<String, String>? env]) =>
      (env ?? Platform.environment)[enableVar] == '1';

  /// Skip reason for live tests when they are not explicitly enabled; null when enabled.
  static String? get skipReason => isEnabled()
      ? null
      : 'Live backend test: set $enableVar=1 and RMBUYER_TEST_* variables for an isolated, '
          'non-production Supabase project to run it.';

  /// Validated configuration. Throws [StateError] when enabled but incomplete,
  /// or when it points at the production project.
  static LiveTestConfig require([Map<String, String>? env]) {
    final e = env ?? Platform.environment;
    if (!isEnabled(e)) {
      throw StateError('Live tests are disabled ($enableVar is not 1).');
    }

    String need(String name) {
      final value = e[name]?.trim() ?? '';
      if (value.isEmpty) throw StateError('Missing required live-test variable $name.');
      return value;
    }

    String? optional(String name) {
      final value = e[name]?.trim() ?? '';
      return value.isEmpty ? null : value;
    }

    final url = need('RMBUYER_TEST_SUPABASE_URL');
    final key = need('RMBUYER_TEST_SUPABASE_ANON_KEY');
    assertNonProduction(url, key);

    return LiveTestConfig._(
      supabaseUrl: url,
      anonKey: key,
      buyerEmail: need('RMBUYER_TEST_BUYER_EMAIL'),
      buyerPassword: need('RMBUYER_TEST_BUYER_PASSWORD'),
      secondBuyerEmail: optional('RMBUYER_TEST_SECOND_BUYER_EMAIL'),
      secondBuyerPassword: optional('RMBUYER_TEST_SECOND_BUYER_PASSWORD'),
      brokerId: optional('RMBUYER_TEST_BROKER_ID'),
    );
  }

  /// Hosts the network guard may allow: only a valid, non-production live backend.
  static Set<String> allowedHosts([Map<String, String>? env]) {
    try {
      final config = require(env);
      return {Uri.parse(config.supabaseUrl).host};
    } catch (_) {
      return const {};
    }
  }

  /// Rejects the production project (by URL host or by the key's `ref` claim)
  /// and any service-role key.
  static void assertNonProduction(String url, String anonKey) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      throw StateError('RMBUYER_TEST_SUPABASE_URL is not a valid URL.');
    }
    if (isProductionSupabaseHost(uri.host)) {
      throw StateError('Refusing to run live tests against the production Supabase project.');
    }

    final claims = _jwtClaims(anonKey);
    if (claims['ref'] == productionSupabaseProjectRef) {
      throw StateError('Refusing to run live tests with a production Supabase key.');
    }
    if (claims['role'] == 'service_role') {
      throw StateError('Refusing to run live tests with a service-role key.');
    }
  }

  static Map<String, dynamic> _jwtClaims(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return const {};
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }
}
