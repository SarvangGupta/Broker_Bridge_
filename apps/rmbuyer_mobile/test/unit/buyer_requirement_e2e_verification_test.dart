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
  test('E2E Requirement Creation, Backend Persistence & List Verification', () async {
    final client = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
    );

    final storage = TestSecureStorageService();
    final authRepo = AuthRepository(supabase: client, storage: storage);

    // 1. Sign in as verified live test buyer (Rohan)
    final authRes = await authRepo.signInWithPassword(
      email: 'rohan@gmail.com',
      password: 'rohan123',
    );
    expect(authRes, isA<AuthSuccess>());
    final success = authRes as AuthSuccess;
    expect(success.user.role, 'buyer');
    expect(success.user.companyId, '53b23dbe-df8e-4dbd-8ad8-322550ab8cdf');

    final reqRepo = RequirementsRepository(
      client: client,
      storage: storage,
    );

    // 2. Verify invalid fields are rejected
    final invalidQtyDto = CreateRequirementDto(
      commodityId: 'a732266b-b30d-4688-8519-8b3e9784685e',
      commodityName: 'Soyabean',
      gradeId: '1f13a047-687d-4f61-bc25-5f93f134ae10',
      gradeName: 'Moisture',
      quantity: -10,
      unitId: 'bfefee25-68a1-4771-8910-6d4b04db39cc',
      unitSymbol: 'kg',
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
      commodityId: 'a732266b-b30d-4688-8519-8b3e9784685e',
      commodityName: 'Soyabean',
      gradeId: '1f13a047-687d-4f61-bc25-5f93f134ae10',
      gradeName: 'Moisture',
      quantity: testQuantity,
      unitId: 'bfefee25-68a1-4771-8910-6d4b04db39cc',
      unitSymbol: 'kg',
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
    expect(fromList.commodityName, 'Soyabean');
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

    // 9. Tenant Isolation: Second buyer (Rahul) cannot access Rohan requirement
    final rahulClient = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
    );
    final rahulStorage = TestSecureStorageService();
    final rahulAuthRepo = AuthRepository(supabase: rahulClient, storage: rahulStorage);

    final rahulLogin = await rahulAuthRepo.signInWithPassword(
      email: 'rahul@gmail.com',
      password: 'rahul123',
    );
    expect(rahulLogin, isA<AuthSuccess>());
    final rahulSuccess = rahulLogin as AuthSuccess;
    expect(rahulSuccess.user.companyId, '567f1ce4-c89e-40b1-934d-00ad826903ef');

    final rahulReqRepo = RequirementsRepository(
      client: rahulClient,
      storage: rahulStorage,
    );

    final rahulList = await rahulReqRepo.getRequirements();
    expect(rahulList.any((r) => r.id == created.id), isFalse);
  });
}
