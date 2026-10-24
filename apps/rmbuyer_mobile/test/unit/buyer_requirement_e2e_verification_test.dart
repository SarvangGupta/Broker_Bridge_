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
  test('E2E Requirement Creation, Backend Persistence & List Verification', () async {
    final config = LiveTestConfig.require();
    final secondEmail = config.secondBuyerEmail;
    final secondPassword = config.secondBuyerPassword;
    if (secondEmail == null || secondPassword == null) {
      fail('Set RMBUYER_TEST_SECOND_BUYER_EMAIL and RMBUYER_TEST_SECOND_BUYER_PASSWORD (tenant isolation check).');
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
    expect(success.user.companyId, isNotNull);

    final reqRepo = RequirementsRepository(
      client: client,
      storage: storage,
    );
    final master = await LiveMasterData.load(client);

    // 2. Verify invalid fields are rejected
    final invalidQtyDto = CreateRequirementDto(
      commodityId: master.commodityId,
      commodityName: master.commodityName,
      gradeId: master.gradeId,
      gradeName: master.gradeName,
      quantity: -10,
      unitId: master.unitId,
      unitSymbol: master.unitSymbol,
      targetPrice: 4800,
      deliveryLocation: 'Jaipur Mandi Gate 2',
      targetDate: DateTime.now().add(const Duration(days: 7)),
      paymentTerms: 'Payment on Delivery (CAD)',
    );
    expect(() => reqRepo.createRequirement(invalidQtyDto), throwsArgumentError);

    // 3. Verify notifier fires on successful submission
    int notified = 0;
    void listener() => notified++;
    RequirementsRepository.requirementsUpdatedNotifier.addListener(listener);

    final testQuantity = (40.0 + (DateTime.now().second % 50)).toDouble();
    final testLocation = 'Jaipur Depot Gate ${DateTime.now().second}';

    final validDto = CreateRequirementDto(
      commodityId: master.commodityId,
      commodityName: master.commodityName,
      gradeId: master.gradeId,
      gradeName: master.gradeName,
      quantity: testQuantity,
      unitId: master.unitId,
      unitSymbol: master.unitSymbol,
      targetPrice: 5250.0,
      deliveryLocation: testLocation,
      targetDate: DateTime.now().add(const Duration(days: 10)),
      paymentTerms: 'Payment on Delivery (CAD)',
      notes: 'Automated E2E Verification Requirement',
    );

    final created = await reqRepo.createRequirement(validDto);
    expect(created, isNotNull);
    expect(created.id, isNotEmpty);
    // Server-generated UUID verification (not a fake local REQ- string)
    expect(created.id.contains('-'), isTrue);
    expect(created.id.length, 36);
    expect(created.status, 'Open');
    expect(created.quantity, testQuantity);
    expect(notified, greaterThanOrEqualTo(1));

    RequirementsRepository.requirementsUpdatedNotifier.removeListener(listener);

    // 4. Verify requirement appears in listing via fresh backend query
    final list = await reqRepo.getRequirements(statusFilter: 'ALL');
    expect(list.any((r) => r.id == created.id), isTrue);

    final fromList = list.firstWhere((r) => r.id == created.id);
    expect(fromList.commodityName, master.commodityName);
    expect(fromList.quantity, testQuantity);
    expect(fromList.status, 'Open');

    // 5. Verify detail retrieval by ID
    final detail = await reqRepo.getRequirementById(created.id);
    expect(detail, isNotNull);
    expect(detail!.id, created.id);
    expect(detail.status, 'Open');
    expect(detail.canCancel, isTrue);

    // 6. Verify status filtering: matches Open, excluded by Fulfilled
    final openList = await reqRepo.getRequirements(statusFilter: 'Open');
    expect(openList.any((r) => r.id == created.id), isTrue);

    final fulfilledList = await reqRepo.getRequirements(statusFilter: 'Fulfilled');
    expect(fulfilledList.any((r) => r.id == created.id), isFalse);

    // 7. Verify cancellation updates authoritative status and notifies UI
    int cancelNotified = 0;
    void cancelListener() => cancelNotified++;
    RequirementsRepository.requirementsUpdatedNotifier.addListener(cancelListener);

    final cancelResult = await reqRepo.cancelRequirement(
      created.id,
      reason: 'E2E verified test requirement lifecycle complete',
    );
    expect(cancelResult, isTrue);
    expect(cancelNotified, greaterThanOrEqualTo(1));
    RequirementsRepository.requirementsUpdatedNotifier.removeListener(cancelListener);

    // 8. Re-query backend to confirm status is cancelled in database
    final cancelledDetail = await reqRepo.getRequirementById(created.id);
    expect(cancelledDetail, isNotNull);
    expect(cancelledDetail!.status, 'Cancelled');
    expect(cancelledDetail.canCancel, isFalse);

    // 9. Tenant Isolation: a buyer from another company cannot access this requirement
    final secondClient = SupabaseClient(config.supabaseUrl, config.anonKey);
    final secondStorage = TestSecureStorageService();
    final secondAuthRepo = AuthRepository(supabase: secondClient, storage: secondStorage);

    final secondLogin = await secondAuthRepo.signInWithPassword(
      email: secondEmail,
      password: secondPassword,
    );
    expect(secondLogin, isA<AuthSuccess>());
    final secondSuccess = secondLogin as AuthSuccess;
    expect(secondSuccess.user.companyId, isNotNull);
    expect(secondSuccess.user.companyId, isNot(success.user.companyId));

    final secondReqRepo = RequirementsRepository(
      client: secondClient,
      storage: secondStorage,
    );

    final secondList = await secondReqRepo.getRequirements();
    expect(secondList.any((r) => r.id == created.id), isFalse);
  }, skip: LiveTestConfig.skipReason);
}
