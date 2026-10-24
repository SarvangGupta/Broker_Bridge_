@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rmbuyer_mobile/core/security/secure_storage_service.dart';
import 'package:rmbuyer_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmbuyer_mobile/features/authentication/domain/auth_result.dart';

import '../support/live_test_config.dart';

class TestSecureStorageService extends SecureStorageService {
  final Map<String, String> _data = {};

  @override
  Future<void> saveToken(String token) async => _data['token'] = token;

  @override
  Future<String?> getToken() async => _data['token'];

  @override
  Future<void> saveRefreshToken(String token) async => _data['refresh_token'] = token;

  @override
  Future<String?> getRefreshToken() async => _data['refresh_token'];

  @override
  Future<void> saveUserInfo({
    required String id,
    required String role,
    required String email,
    required String fullName,
    String? companyId,
    String? companyName,
  }) async {
    _data['id'] = id;
    _data['role'] = role;
    _data['email'] = email;
    _data['fullName'] = fullName;
    if (companyId != null) _data['companyId'] = companyId;
    if (companyName != null) _data['companyName'] = companyName;
  }

  @override
  Future<String?> getUserId() async => _data['id'];

  @override
  Future<String?> getUserRole() async => _data['role'];

  @override
  Future<String?> getUserEmail() async => _data['email'];

  @override
  Future<String?> getUserName() async => _data['fullName'];

  @override
  Future<String?> getCompanyId() async => _data['companyId'];

  @override
  Future<String?> getCompanyName() async => _data['companyName'];

  @override
  Future<void> clearAll() async => _data.clear();
}

Future<AuthSuccess> _signIn(LiveTestConfig config, String email, String password) async {
  final client = SupabaseClient(config.supabaseUrl, config.anonKey);
  final authRepo = AuthRepository(supabase: client, storage: TestSecureStorageService());

  final result = await authRepo.signInWithPassword(email: email, password: password);
  if (result is AuthFailure) {
    fail('Login failed: ${result.message} (${result.code})');
  }
  expect(result, isA<AuthSuccess>());
  return result as AuthSuccess;
}

void main() {
  test('Live authentication: primary test buyer signs in with buyer role', () async {
    final config = LiveTestConfig.require();

    final success = await _signIn(config, config.buyerEmail, config.buyerPassword);

    expect(success.user.email, config.buyerEmail);
    expect(success.user.role, 'buyer');
    expect(success.user.fullName, isNotEmpty);
    expect(success.user.companyId, isNotNull);
  }, skip: LiveTestConfig.skipReason);

  test('Live authentication: second test buyer signs in with buyer role', () async {
    final config = LiveTestConfig.require();
    final email = config.secondBuyerEmail;
    final password = config.secondBuyerPassword;
    if (email == null || password == null) {
      fail('Set RMBUYER_TEST_SECOND_BUYER_EMAIL and RMBUYER_TEST_SECOND_BUYER_PASSWORD.');
    }

    final success = await _signIn(config, email, password);

    expect(success.user.email, email);
    expect(success.user.role, 'buyer');
    expect(success.user.fullName, isNotEmpty);
  }, skip: LiveTestConfig.skipReason);
}
