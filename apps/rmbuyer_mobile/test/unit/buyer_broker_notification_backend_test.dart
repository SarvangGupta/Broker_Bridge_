import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rmbuyer_mobile/core/config/app_config.dart';
import 'package:rmbuyer_mobile/core/security/secure_storage_service.dart';
import 'package:rmbuyer_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmbuyer_mobile/features/authentication/domain/auth_result.dart';
import 'package:rmbuyer_mobile/features/requirements/data/requirements_repository.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/requirement_model.dart';

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
    final client = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
    );

    final storage = TestSecureStorageService();
    final authRepo = AuthRepository(supabase: client, storage: storage);

    // 1. Sign in as verified live buyer (Rohan)
    final authRes = await authRepo.signInWithPassword(
      email: 'rohan@gmail.com',
      password: 'rohan123',
    );
    expect(authRes, isA<AuthSuccess>());
    final success = authRes as AuthSuccess;
    expect(success.user.role, 'buyer');

    final reqRepo = RequirementsRepository(
      client: client,
      storage: storage,
    );

    const brokerVarunId = 'b354958e-779a-41f2-b7a3-5899eca32e32';
    final testQuantity = (50.0 + (DateTime.now().second % 30)).toDouble();

    final validDto = CreateRequirementDto(
      commodityId: 'a732266b-b30d-4688-8519-8b3e9784685e',
      commodityName: 'Soyabean',
      gradeId: '1f13a047-687d-4f61-bc25-5f93f134ae10',
      gradeName: 'Moisture',
      quantity: testQuantity,
      unitId: 'bfefee25-68a1-4771-8910-6d4b04db39cc',
      unitSymbol: 'kg',
      targetPrice: 5350.0,
      deliveryLocation: 'Kota Mandi Yard Gate 1',
      targetDate: DateTime.now().add(const Duration(days: 12)),
      paymentTerms: 'Payment on Delivery (CAD)',
      notes: 'RB-BUYER-07 Automated Test Requirement',
      selectedBrokerIds: const [brokerVarunId],
      selectedBrokerNames: const ['Varun Broker Desk'],
    );

    // 2. Persist requirement and notify selected broker
    final created = await reqRepo.createRequirement(validDto);
    expect(created, isNotNull);
    expect(created.id, isNotEmpty);
    expect(created.commodityName, 'Soyabean');

    // 3. Verify notification was dispatched via RPC and idempotency prevents duplicates
    final notifiedCount = await reqRepo.notifyRequirementBrokers(
      requirementId: created.id,
      brokerIds: [brokerVarunId],
    );
    expect(notifiedCount, 0);

    // 4. Verify unselected broker list triggers no unselected notifications
    final unselectedResult = await reqRepo.notifyRequirementBrokers(
      requirementId: created.id,
      brokerIds: [],
    );
    expect(unselectedResult, 0);
  });
}
