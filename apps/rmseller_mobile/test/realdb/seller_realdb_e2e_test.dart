// RB-SELLER-REALDB-E2E-01: Real Database Commodity Posting & Full Lifecycle Validation.
// Runs against the real Supabase database (imztlkvkxzeaekxvmcfe.supabase.co).
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rmseller_mobile/core/config/app_config.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmseller_mobile/features/authentication/domain/auth_result.dart';
import 'package:rmseller_mobile/features/commodities/data/commodities_repository.dart';
import 'package:rmseller_mobile/features/commodities/domain/commodity_model.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';

// Test Sellers & Broker verified from authoritative database
const _priyaEmail = 'priya@gmail.com';
const _priyaPassword = 'priya123';
const _priyaCompanyId = 'b543d6c6-85a7-4f13-a048-1967c05bb71e'; // Priya123

const _nehaEmail = 'neha@gmail.com';
const _nehaPassword = 'neha123';
const _nehaCompanyId = '4f3d7584-ebc8-4a92-82a5-b5d0b02079e7'; // Neha Gupta pvt. Ltd

const _unprovisionedEmail = 'seller.bikaner@gmail.com';
const _unprovisionedPassword = 'seller123';

const _varunBrokerId = 'b354958e-779a-41f2-b7a3-5899eca32e32'; // Active broker
const _foreignLotId = '50000000-0000-0000-0000-000000000201'; // Commercial test lot (Kota Agro)

// Real Master IDs from public database
const _bajraCommodityId = 'a14c3512-8235-5051-a38a-22f7f4bc70c0';
const _bajraFaqGradeId = 'ac57f5b1-234c-500a-8b39-b5425f691527';
const _unitMtId = '22000000-0000-0000-0000-000000000001';
const _rajasthanStateId = 'a55c1bb2-b570-4e7c-bc1f-84d6042e45e7';
const _bundiDistrictId = 'a784455f-25f7-495d-80d8-d4774e2cb391';

void main() {
  late SupabaseClient client;
  late SecureStorageService storage;
  late AuthRepository authRepo;
  late SellerProfileRepository profileRepo;
  late CommoditiesRepository commoditiesRepo;

  String? createdLotId;
  final String testLotNumber =
      'RBTEST-REALDB-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

  setUpAll(() async {
    client = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
    );
    storage = SecureStorageService()..enableMemoryFallbackForTesting();
    authRepo = AuthRepository(supabase: client, storage: storage);
    profileRepo = SellerProfileRepository(supabase: client, storage: storage);
    commoditiesRepo = CommoditiesRepository(client: client, storage: storage);

    // Clean up any test listings from previous runs before starting
    try {
      await client
          .from('availabilities')
          .delete()
          .like('lot_number', 'RBTEST-REALDB-%');
    } catch (_) {}
  });

  tearDownAll(() async {
    // Phase 10: Clean up test lot from real database after lifecycle tests
    try {
      await client
          .from('availabilities')
          .delete()
          .like('lot_number', 'RBTEST-REALDB-%');
    } catch (_) {}
  });

  group('Phase 1 & 2 — Real Test Environment & First-Time Seller Journey', () {
    test('Environment Target is authoritative Supabase backend', () {
      expect(AppConfig.supabaseUrl, contains('imztlkvkxzeaekxvmcfe'));
      expect(AppConfig.supabaseAnonKey, isNotEmpty);
    });

    test('Priya Singh authenticates and verifies enterprise firm linkage', () async {
      final res = await authRepo.signInWithPassword(
        email: _priyaEmail,
        password: _priyaPassword,
      );
      expect(res, isA<AuthSuccess>());
      final user = (res as AuthSuccess).user;
      expect(user.role, 'seller');
      expect(user.companyId, _priyaCompanyId);

      // Verify server-side readiness check
      final readiness = await profileRepo.checkListingReadiness();
      expect(readiness.status, ListingReadinessStatus.complete);
      expect(readiness.firmName, 'Priya123');
      expect(readiness.companyStateId, _rajasthanStateId);
      expect(readiness.companyDistrictId, _bundiDistrictId);
    });

    test('Unprovisioned account is rejected with clear incomplete notice', () async {
      final unprovRes = await authRepo.signInWithPassword(
        email: _unprovisionedEmail,
        password: _unprovisionedPassword,
      );
      expect(unprovRes, isA<AuthSuccess>());

      final readiness = await profileRepo.checkListingReadiness();
      expect(readiness.status, ListingReadinessStatus.incomplete);
      expect(readiness.missing.single, contains('not yet provisioned'));

      // Re-authenticate as Priya for subsequent tests
      await authRepo.signInWithPassword(
        email: _priyaEmail,
        password: _priyaPassword,
      );

      // Clean up any test listings from previous runs while authenticated
      try {
        await client
            .from('availabilities')
            .delete()
            .like('lot_number', 'RBTEST-REALDB-%');
      } catch (_) {}
    });
  });

  group('Phase 3 — Returning Seller Journey', () {
    test('Priya has real server-backed history (never demo lots)', () async {
      CommoditiesRepository.clearSessionCache();
      final history = await commoditiesRepo.getPostingHistory();
      expect(history.every((h) => !h.lotNumber.contains('DEMO')), isTrue);
      expect(history.every((h) => h.companyId == _priyaCompanyId), isTrue);
    });
  });

  group('Phase 4 — Real Commodity Posting & Persistence Verification', () {
    test('Submit valid commodity lot to real Supabase database', () async {
      final dto = CreateCommodityDto(
        commodityId: _bajraCommodityId,
        commodityName: 'Bajra (Pearl Millet)',
        gradeId: _bajraFaqGradeId,
        gradeName: 'FAQ (Fair Average Quality)',
        lotNumber: testLotNumber,
        totalQuantity: 25.0,
        unitId: _unitMtId,
        unitSymbol: 'MT',
        askingPrice: 21500.0,
        stateId: _rajasthanStateId,
        stateName: 'Rajasthan',
        districtId: _bundiDistrictId,
        districtName: 'Bundi',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 14)),
        brokerId: _varunBrokerId,
        brokerName: 'Varun',
        loadingRemarks: 'Warehouse Gate 1 · Verified E2E',
        visibility: 'restricted',
      );

      final created = await commoditiesRepo.createCommodity(dto);
      expect(created, isNotNull);
      expect(created.id, isNotEmpty);
      expect(created.status, 'Open');
      expect(created.companyId, _priyaCompanyId);
      expect(created.isCompanyOwned, isTrue);
      expect(created.isIndividualOwned, isFalse);

      createdLotId = created.id;

      // Re-read directly from real Supabase PostgREST
      CommoditiesRepository.clearSessionCache();
      final fetched = await commoditiesRepo.getCommodityById(createdLotId!);
      expect(fetched, isNotNull);
      expect(fetched!.lotNumber, testLotNumber);
      expect(fetched.askingPrice, 21500.0);
      expect(fetched.totalQuantity, 25.0);
      expect(fetched.companyId, _priyaCompanyId);
      expect(fetched.brokerId, _varunBrokerId);
      expect(fetched.status, 'Open');

      // Verify returning seller listing history now shows this lot
      final history = await commoditiesRepo.getPostingHistory();
      expect(history.map((h) => h.id), contains(createdLotId));
      expect(history.first.commodityName, 'Bajra (Pearl Millet)');
    });
  });

  group('Phase 5 — Asking Price Update on Real Database', () {
    test('Update asking price and verify persistence on real database', () async {
      expect(createdLotId, isNotNull);

      // Step 1: Update to 22000
      final confirmed1 = await commoditiesRepo.updateCommodityPrice(createdLotId!, 22000.0);
      expect(confirmed1, 22000.0);

      CommoditiesRepository.clearSessionCache();
      var reRead = await commoditiesRepo.getCommodityById(createdLotId!);
      expect(reRead!.askingPrice, 22000.0);

      // Step 2: Update a second time to 22500 (latest value wins)
      final confirmed2 = await commoditiesRepo.updateCommodityPrice(createdLotId!, 22500.0);
      expect(confirmed2, 22500.0);

      CommoditiesRepository.clearSessionCache();
      reRead = await commoditiesRepo.getCommodityById(createdLotId!);
      expect(reRead!.askingPrice, 22500.0);
    });

    test('Invalid prices (zero, negative) are rejected before DB write', () async {
      expect(() => commoditiesRepo.updateCommodityPrice(createdLotId!, 0), throwsA(isA<PriceUpdateException>()));
      expect(() => commoditiesRepo.updateCommodityPrice(createdLotId!, -500), throwsA(isA<PriceUpdateException>()));
    });

    test('Updating price of foreign company lot is rejected', () async {
      await expectLater(
        commoditiesRepo.updateCommodityPrice(_foreignLotId, 99999.0),
        throwsA(isA<PriceUpdateException>().having((e) => e.message, 'm', contains('not found'))),
      );
    });
  });

  group('Phase 6 — Broker Assignment on Real Database', () {
    test('Unassign broker (null) and reassign Varun with real DB persistence', () async {
      expect(createdLotId, isNotNull);

      // Step 1: Unassign broker
      final unassigned = await commoditiesRepo.updateCommodityBroker(
        createdLotId!,
        brokerId: null,
        brokerName: null,
      );
      expect(unassigned, isNull);

      CommoditiesRepository.clearSessionCache();
      var reRead = await commoditiesRepo.getCommodityById(createdLotId!);
      expect(reRead!.brokerId, isNull);

      // Step 2: Re-assign active broker Varun
      final reassigned = await commoditiesRepo.updateCommodityBroker(
        createdLotId!,
        brokerId: _varunBrokerId,
        brokerName: 'Varun',
      );
      expect(reassigned, _varunBrokerId);

      CommoditiesRepository.clearSessionCache();
      reRead = await commoditiesRepo.getCommodityById(createdLotId!);
      expect(reRead!.brokerId, _varunBrokerId);
    });

    test('Unregistered broker UUID is rejected before DB update', () async {
      await expectLater(
        commoditiesRepo.updateCommodityBroker(
          createdLotId!,
          brokerId: 'invalid-broker-format',
          brokerName: 'Fake Broker',
        ),
        throwsA(isA<BrokerUpdateException>().having((e) => e.message, 'm', contains('not registered'))),
      );
    });

    test('Updating broker on foreign company lot is rejected', () async {
      await expectLater(
        commoditiesRepo.updateCommodityBroker(
          _foreignLotId,
          brokerId: _varunBrokerId,
          brokerName: 'Varun',
        ),
        throwsA(isA<BrokerUpdateException>().having((e) => e.message, 'm', contains('not found'))),
      );
    });
  });

  group('Phase 7 — Status & Listing Lifecycle on Real Database', () {
    test('Mark lot Fulfilled and verify server confirmation', () async {
      expect(createdLotId, isNotNull);

      final confirmed = await commoditiesRepo.updateCommodityStatus(createdLotId!, 'Fulfilled');
      expect(confirmed, 'Fulfilled');

      CommoditiesRepository.clearSessionCache();
      final reRead = await commoditiesRepo.getCommodityById(createdLotId!);
      expect(reRead!.status, 'Fulfilled');
    });

    test('Withdraw lot (Cancelled) and verify server confirmation', () async {
      expect(createdLotId, isNotNull);

      final confirmed = await commoditiesRepo.updateCommodityStatus(createdLotId!, 'Cancelled');
      expect(confirmed, 'Cancelled');

      CommoditiesRepository.clearSessionCache();
      final reRead = await commoditiesRepo.getCommodityById(createdLotId!);
      expect(reRead!.status, 'Cancelled');
    });
  });

  group('Phase 8 — Duplicate Protection & Cross-Company Isolation', () {
    test('Duplicate lot number for same company (23505) is rejected by real database', () async {
      final duplicateDto = CreateCommodityDto(
        commodityId: _bajraCommodityId,
        commodityName: 'Bajra (Pearl Millet)',
        gradeId: _bajraFaqGradeId,
        gradeName: 'FAQ (Fair Average Quality)',
        lotNumber: testLotNumber, // Identical lot number
        totalQuantity: 30.0,
        unitId: _unitMtId,
        unitSymbol: 'MT',
        askingPrice: 21000.0,
        stateId: _rajasthanStateId,
        stateName: 'Rajasthan',
        districtId: _bundiDistrictId,
        districtName: 'Bundi',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 14)),
      );

      await expectLater(
        commoditiesRepo.createCommodity(duplicateDto),
        throwsA(
          isA<ListingSubmitException>()
              .having((e) => e.code, 'code', '23505')
              .having((e) => e.message, 'm', contains('already listed')),
        ),
      );
    });

    test('Cross-Company Isolation: Neha Gupta cannot see or update Priyas lot', () async {
      // Sign in as Neha Gupta
      final res = await authRepo.signInWithPassword(
        email: _nehaEmail,
        password: _nehaPassword,
      );
      expect(res, isA<AuthSuccess>());
      expect((res as AuthSuccess).user.companyId, _nehaCompanyId);

      CommoditiesRepository.clearSessionCache();

      // Read check: Neha's company has 0 lots, cannot see Priya's lot
      final nehaLots = await commoditiesRepo.getCommodities();
      expect(nehaLots.any((l) => l.id == createdLotId), isFalse);

      // Update price check: Neha cannot update Priya's lot
      await expectLater(
        commoditiesRepo.updateCommodityPrice(createdLotId!, 99999.0),
        throwsA(isA<PriceUpdateException>().having((e) => e.message, 'm', contains('not found'))),
      );

      // Status update check: Neha cannot change Priya's lot status
      await expectLater(
        commoditiesRepo.updateCommodityStatus(createdLotId!, 'Active'),
        throwsA(isA<StatusUpdateException>().having((e) => e.message, 'm', contains('not found'))),
      );
    });
  });

  group('Phase 9 — Lab Report & Payment Safety Checks', () {
    test('Local file path is never represented as server URL', () {
      final dto = CreateCommodityDto(
        commodityId: _bajraCommodityId,
        commodityName: 'Bajra (Pearl Millet)',
        gradeId: _bajraFaqGradeId,
        gradeName: 'FAQ',
        lotNumber: 'SAFETY-TEST-01',
        totalQuantity: 10,
        unitId: _unitMtId,
        unitSymbol: 'MT',
        askingPrice: 20000,
        stateId: _rajasthanStateId,
        stateName: 'Rajasthan',
        districtId: _bundiDistrictId,
        districtName: 'Bundi',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 7)),
        labReportFileUrl: '/data/user/0/com.brokerbridge/cache/local_test.pdf',
        labReportFileName: 'local_test.pdf',
      );

      final insert = dto.toSupabaseInsert(companyId: _priyaCompanyId);
      // Verify database payload does not contain local phone path as server url
      expect(insert['lab_report_file_url'], isNull);
    });
  });
}
