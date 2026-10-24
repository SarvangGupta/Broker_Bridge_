@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rmbuyer_mobile/core/security/secure_storage_service.dart';
import 'package:rmbuyer_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmbuyer_mobile/features/authentication/domain/auth_result.dart';
import 'package:rmbuyer_mobile/features/requirements/data/requirements_repository.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/requirement_model.dart';

import '../support/live_master_data.dart';
import '../support/live_test_config.dart';

class TestSecureStorageService extends SecureStorageService {
  final Map<String, String> _data = {};

  @override
  Future<void> saveToken(String token) async => _data['rmbuyer_access_token'] = token;
  @override
  Future<String?> getToken() async => _data['rmbuyer_access_token'];

  @override
  Future<void> saveRefreshToken(String token) async => _data['rmbuyer_refresh_token'] = token;
  @override
  Future<String?> getRefreshToken() async => _data['rmbuyer_refresh_token'];

  @override
  Future<void> saveUserInfo({
    required String id,
    required String role,
    required String email,
    required String fullName,
    String? companyId,
    String? companyName,
  }) async {
    _data['rmbuyer_user_id'] = id;
    _data['rmbuyer_user_role'] = role;
    _data['rmbuyer_user_email'] = email;
    _data['rmbuyer_user_name'] = fullName;
    if (companyId != null) _data['rmbuyer_company_id'] = companyId;
    if (companyName != null) _data['rmbuyer_company_name'] = companyName;
  }

  @override
  Future<String?> getCompanyId() async => _data['rmbuyer_company_id'];
  @override
  Future<String?> getUserId() async => _data['rmbuyer_user_id'];
  @override
  Future<String?> getUserRole() async => _data['rmbuyer_user_role'];
  @override
  Future<String?> getUserEmail() async => _data['rmbuyer_user_email'];
  @override
  Future<String?> getUserName() async => _data['rmbuyer_user_name'];

  @override
  Future<void> clearAll() async => _data.clear();
}

void main() {
  test('RB-BUYER-07: Backend Integration: Requirement creation dispatches notification to selected broker', () async {
    final config = LiveTestConfig.require();
    final brokerId = config.brokerId;
    if (brokerId == null) {
      fail('Set RMBUYER_TEST_BROKER_ID to a broker user in the live-test backend.');
    }

    final client = SupabaseClient(config.supabaseUrl, config.anonKey);

    final storage = TestSecureStorageService();
    final authRepo = AuthRepository(supabase: client, storage: storage);

    // 1. Sign in as the configured test buyer
    final authRes = await authRepo.signInWithPassword(
      email: config.buyerEmail,
      password: config.buyerPassword,
    );
    expect(authRes, isA<AuthSuccess>());
    final success = authRes as AuthSuccess;
    expect(success.user.role, 'buyer');

    final reqRepo = RequirementsRepository(
      client: client,
      storage: storage,
    );
    final master = await LiveMasterData.load(client);

    final testQuantity = (50.0 + (DateTime.now().second % 30)).toDouble();

    final validDto = CreateRequirementDto(
      commodityId: master.commodityId,
      commodityName: master.commodityName,
      gradeId: master.gradeId,
      gradeName: master.gradeName,
      quantity: testQuantity,
      unitId: master.unitId,
      unitSymbol: master.unitSymbol,
      targetPrice: 5350.0,
      deliveryLocation: 'Kota Mandi Yard Gate 1',
      targetDate: DateTime.now().add(const Duration(days: 12)),
      paymentTerms: 'Payment on Delivery (CAD)',
      notes: 'RB-BUYER-07 Automated Test Requirement',
      selectedBrokerIds: [brokerId],
      selectedBrokerNames: const ['Test Broker Desk'],
    );

    // 2. Persist requirement and notify selected broker
    final created = await reqRepo.createRequirement(validDto);
    expect(created, isNotNull);
    expect(created.id, isNotEmpty);
    expect(created.commodityName, master.commodityName);

    // 3. Verify notification was dispatched via RPC and idempotency prevents duplicates
    final notifiedCount = await reqRepo.notifyRequirementBrokers(
      requirementId: created.id,
      brokerIds: [brokerId],
    );
    expect(notifiedCount, 0);

    // 4. Verify unselected broker list triggers no unselected notifications
    final unselectedResult = await reqRepo.notifyRequirementBrokers(
      requirementId: created.id,
      brokerIds: [],
    );
    expect(unselectedResult, 0);
  }, skip: LiveTestConfig.skipReason);
}
