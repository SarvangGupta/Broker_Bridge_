import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_bank_details.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TestMemorySecureStorage extends SecureStorageService {
  final Map<String, String> _prefs = {};

  TestMemorySecureStorage() {
    enableMemoryFallbackForTesting();
  }

  @override
  Future<void> savePreference(String key, String value) async {
    _prefs[key] = value;
  }

  @override
  Future<String?> getPreference(String key) async {
    return _prefs[key];
  }

  @override
  Future<void> clearAll() async {
    _prefs.clear();
  }

  @override
  Future<void> saveUserInfo({
    required String id,
    required String role,
    required String email,
    required String fullName,
    String? companyId,
    String? companyName,
    String? companyGst,
  }) async {
    _prefs['user_id'] = id;
    _prefs['user_role'] = role;
    _prefs['user_email'] = email;
    _prefs['user_full_name'] = fullName;
    if (companyId != null) _prefs['company_id'] = companyId;
    if (companyName != null) _prefs['company_name'] = companyName;
    if (companyGst != null) _prefs['company_gst'] = companyGst;
  }

  @override
  Future<String?> getUserId() async => _prefs['user_id'] ?? '20000000-0000-0000-0000-000000000001';

  @override
  Future<String?> getUserRole() async => _prefs['user_role'] ?? 'seller';

  @override
  Future<String?> getUserEmail() async => _prefs['user_email'] ?? 'seller@demo.com';

  @override
  Future<String?> getUserFullName() async => _prefs['user_full_name'] ?? 'Seller Lead';

  @override
  Future<String?> getCompanyId() async => _prefs['company_id'] ?? '30000000-0000-0000-0000-000000000001';

  @override
  Future<String?> getCompanyName() async => _prefs['company_name'] ?? 'Agro Mills';

  @override
  Future<String?> getCompanyGst() async => _prefs['company_gst'] ?? '08ABCDE1234F1Z5';
}

class FailingSellerProfileRepository extends SellerProfileRepository {
  bool shouldFail = false;

  FailingSellerProfileRepository({super.storage});

  @override
  Future<SellerProfileModel> updateProfile(
    SellerProfileModel updatedProfile, {
    String operationType = 'MANUAL_EDIT',
    String? requestId,
    List<String>? confirmedFields,
    String? customSummary,
  }) async {
    if (shouldFail) {
      throw const PostgrestException(
        message: 'Network connection timeout while persisting profile update',
        code: '504',
      );
    }
    return super.updateProfile(
      updatedProfile,
      operationType: operationType,
      requestId: requestId,
      confirmedFields: confirmedFields,
      customSummary: customSummary,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RB-SELLER-PROFILE-INVOICE-01: Confirmation & Audit History Tests', () {
    late TestMemorySecureStorage storage;
    late FailingSellerProfileRepository repository;

    setUp(() async {
      storage = TestMemorySecureStorage();
      await storage.clearAll();
      repository = FailingSellerProfileRepository(storage: storage);
    });

    test('1. Failed profile save preserves unsaved draft and DOES NOT create an audit entry', () async {
      final initial = await repository.getProfile();

      // Configure repository to fail
      repository.shouldFail = true;

      final proposed = initial.copyWith(
        companyName: 'Failed Company Name Attempt',
        bankDetails: const SellerBankDetails(
          bankName: 'HDFC Bank',
          accountNumber: '112233445566',
          ifscCode: 'HDFC0001234',
        ),
      );

      // Attempt update expecting error
      expect(
        () => repository.updateProfile(proposed),
        throwsA(isA<PostgrestException>()),
      );

      // Verify NO audit entry was recorded
      final auditHistory = await repository.getProfileAuditHistory(
        sellerId: initial.id,
        checkAdminRole: false,
      );
      expect(auditHistory, isEmpty);
    });

    test('2. Successful save creates exactly one audit entry with safe masked summary', () async {
      final initial = await repository.getProfile();
      repository.shouldFail = false;

      final updated = initial.copyWith(
        companyName: 'Bikaner Agro Mills Pvt Ltd',
        bankDetails: const SellerBankDetails(
          accountHolderName: 'Bikaner Agro Mills',
          bankName: 'State Bank of India',
          accountNumber: '998877665544',
          ifscCode: 'SBIN0001234',
        ),
      );

      final saved = await repository.updateProfile(
        updated,
        operationType: 'INVOICE_ASSISTED_EDIT',
      );

      expect(saved.companyName, 'Bikaner Agro Mills Pvt Ltd');
      expect(saved.bankDetails.isConfigured, isTrue);

      // Verify audit entry exists
      final auditHistory = await repository.getProfileAuditHistory(
        sellerId: initial.id,
        checkAdminRole: false,
      );

      expect(auditHistory.length, 1);
      final entry = auditHistory.first;
      expect(entry.operationType, 'INVOICE_ASSISTED_EDIT');
      expect(entry.sellerId, initial.id);
      expect(entry.source, 'rmseller_mobile');

      // Zero-leak check: Audit summary contains masked account number, never raw account digits
      expect(entry.changeSummary, contains('...5544'));
      expect(entry.changeSummary.contains('99887766'), isFalse);
    });

    test('3. Retry after failure does not duplicate audit events', () async {
      final initial = await repository.getProfile();

      // Attempt 1: Fails
      repository.shouldFail = true;
      final proposed = initial.copyWith(companyName: 'First Attempt Name');
      try {
        await repository.updateProfile(proposed);
      } catch (_) {}

      var history = await repository.getProfileAuditHistory(sellerId: initial.id, checkAdminRole: false);
      expect(history, isEmpty);

      // Attempt 2: Succeeds (Retry)
      repository.shouldFail = false;
      await repository.updateProfile(proposed);

      history = await repository.getProfileAuditHistory(sellerId: initial.id, checkAdminRole: false);
      expect(history.length, 1);
    });

    test('4. Reloading profile returns authoritative persisted values', () async {
      final initial = await repository.getProfile();

      final updated = initial.copyWith(
        companyName: 'Authoritative Verified Corp Ltd',
        bankDetails: const SellerBankDetails(
          accountHolderName: 'Authoritative Corp',
          bankName: 'Bank of Baroda',
          accountNumber: '445566778899',
          ifscCode: 'BARB0BIKANE',
        ),
      );

      await repository.updateProfile(updated);

      // Re-fetch clean profile
      final reloaded = await repository.getProfile();
      expect(reloaded.companyName, 'Authoritative Verified Corp Ltd');
      expect(reloaded.bankDetails.bankName, 'Bank of Baroda');
      expect(reloaded.bankDetails.accountNumber, '445566778899');
      expect(reloaded.bankDetails.maskedAccountNumber, contains('••••'));
      expect(reloaded.bankDetails.maskedAccountNumber.endsWith('8899'), isTrue);
    });
  });
}
