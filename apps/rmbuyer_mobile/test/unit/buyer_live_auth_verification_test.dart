import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rmbuyer_mobile/core/config/app_config.dart';
import 'package:rmbuyer_mobile/core/security/secure_storage_service.dart';
import 'package:rmbuyer_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmbuyer_mobile/features/authentication/domain/auth_result.dart';

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

void main() {
  test('Live Authentication Validation for Rohan Gupta (Buyer)', () async {
    final client = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
    );

    final storage = TestSecureStorageService();
    final authRepo = AuthRepository(
      supabase: client,
      storage: storage,
    );

    final result = await authRepo.signInWithPassword(
      email: 'rohan@gmail.com',
      password: 'rohan123',
    );

    if (result is AuthFailure) {
      fail('Login failed: ${result.message} (${result.code})');
    }

    expect(result, isA<AuthSuccess>());
    final success = result as AuthSuccess;
    expect(success.user.email, 'rohan@gmail.com');
    expect(success.user.role, 'buyer');
    expect(success.user.fullName, 'Rohan Gupta');
    expect(success.user.companyId, '53b23dbe-df8e-4dbd-8ad8-322550ab8cdf');

    // ignore: avoid_print
    print('>>> LIVE LOGIN VALIDATED SUCCESSFULLY FOR: ${success.user.fullName} (${success.user.email})');
    // ignore: avoid_print
    print('>>> Role: ${success.user.role}');
    // ignore: avoid_print
    print('>>> Company ID: ${success.user.companyId}');
  });

  test('Live Authentication Validation for Rahul (Buyer)', () async {
    final client = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
    );

    final storage = TestSecureStorageService();
    final authRepo = AuthRepository(
      supabase: client,
      storage: storage,
    );

    final result = await authRepo.signInWithPassword(
      email: 'rahul@gmail.com',
      password: 'rahul123',
    );

    if (result is AuthFailure) {
      fail('Login failed: ${result.message} (${result.code})');
    }

    expect(result, isA<AuthSuccess>());
    final success = result as AuthSuccess;
    expect(success.user.email, 'rahul@gmail.com');
    expect(success.user.role, 'buyer');
    expect(success.user.fullName, 'Rahul');

    // ignore: avoid_print
    print('>>> LIVE LOGIN VALIDATED SUCCESSFULLY FOR: ${success.user.fullName} (${success.user.email})');
  });
}
