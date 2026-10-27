// RB-SELLER-INDIVIDUAL-LISTINGS-02: Comprehensive test suite for approved
// individual seller ownership, trusted database identity, cross-seller isolation,
// and company-seller coexistence.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/data/commodities_repository.dart';
import 'package:rmseller_mobile/features/commodities/domain/commodity_model.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';

import '../support/fake_postgrest.dart';

const _companySeller = '7c000000-0000-4000-8000-000000000001';
const _individualSeller1 = '7c000000-0000-4000-8000-000000000002';
const _individualSeller2 = '7c000000-0000-4000-8000-000000000003';
const _unprovisionedUser = '7c000000-0000-4000-8000-000000000004';
const _buyerUser = '7c000000-0000-4000-8000-000000000005';

const _companyA = '20000000-0000-4000-8000-0000000000a1';
const _companyB = '20000000-0000-4000-8000-0000000000b1';

const _activeBroker = 'b0000000-0000-4000-8000-00000000000a';
const _inactiveBroker = 'b0000000-0000-4000-8000-00000000000b';

String _jwt(String sub, {String role = 'seller'}) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1));
  return '${b64({'alg': 'none', 'typ': 'JWT'})}.'
      '${b64({'sub': sub, 'role': 'authenticated', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

Future<void> _signIn(FakePostgrest fake, String sub, {String role = 'seller'}) =>
    fake.client.auth.setInitialSession(
      jsonEncode({
        'access_token': _jwt(sub, role: role),
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'refresh-$sub',
        'user': {
          'id': sub,
          'aud': 'authenticated',
          'app_metadata': {'role': role},
          'user_metadata': <String, dynamic>{'role': role},
          'created_at': '2026-10-01T00:00:00Z',
        },
      }),
    );

CreateCommodityDto _dto({
  String lot = 'LOT-INDIV-001',
  String? brokerId,
  double price = 25000,
}) =>
    CreateCommodityDto(
      commodityId: '10000000-0000-4000-8000-000000000001',
      commodityName: 'Chana Desi',
      gradeId: '30000000-0000-4000-8000-000000000001',
      gradeName: 'FAQ Grade 1',
      lotNumber: lot,
      totalQuantity: 20,
      unitId: '22000000-0000-0000-0000-000000000001',
      unitSymbol: 'MT',
      askingPrice: price,
      stateId: '40000000-0000-0000-0000-000000000001',
      stateName: 'Rajasthan',
      districtId: '50000000-0000-0000-0000-000000000001',
      districtName: 'Bikaner',
      availableFrom: DateTime(2026, 10, 27),
      validUntil: DateTime(2026, 11, 10),
      brokerId: brokerId,
      loadingRemarks: 'Farm gate pickup',
      visibility: brokerId != null ? 'restricted' : 'global',
    );

void main() {
  late FakePostgrest fake;
  late SecureStorageService storage;
  late CommoditiesRepository commoditiesRepo;
  late SellerProfileRepository profileRepo;

  setUp(() async {
    storage = SecureStorageService()..enableMemoryFallbackForTesting();
    fake = await FakePostgrest.start({
      'users': [
        {
          'id': _companySeller,
          'name': 'Company Seller Lead',
          'role': 'seller',
          'status': true,
          'company_id': _companyA,
        },
        {
          'id': _individualSeller1,
          'name': 'Ramesh Kumar (Kisan)',
          'role': 'seller',
          'status': true,
          'company_id': null,
        },
        {
          'id': _individualSeller2,
          'name': 'Suresh Patel (Farmer)',
          'role': 'seller',
          'status': true,
          'company_id': null,
        },
        {
          'id': _buyerUser,
          'name': 'Buyer Account',
          'role': 'buyer',
          'status': true,
          'company_id': null,
        },
        {
          'id': _activeBroker,
          'name': 'Broker Ram',
          'role': 'broker',
          'status': true,
        },
        {
          'id': _inactiveBroker,
          'name': 'Broker Inactive',
          'role': 'broker',
          'status': false,
        },
      ],
      'companies': [
        {
          'id': _companyA,
          'name': 'Agro Corp India',
          'state_id': 'S-1',
          'district_id': 'D-1',
        },
        {
          'id': _companyB,
          'name': 'Bharat Pulses Ltd',
          'state_id': 'S-2',
          'district_id': 'D-2',
        },
      ],
      'availabilities': [
        {
          'id': 'a0000000-0000-4000-8000-000000000001',
          'lot_number': 'LOT-CORP-A1',
          'company_id': _companyA,
          'seller_user_id': null,
          'asking_price': 30000,
          'price': 30000,
          'broker_id': _activeBroker,
          'status': 'Open',
          'created_at': '2026-10-25T10:00:00.000',
        },
        {
          'id': 'a0000000-0000-4000-8000-000000000002',
          'lot_number': 'LOT-INDIV-S2',
          'company_id': null,
          'seller_user_id': _individualSeller2,
          'asking_price': 28000,
          'price': 28000,
          'broker_id': _activeBroker,
          'status': 'Open',
          'created_at': '2026-10-26T10:00:00.000',
        },
      ],
    });

    fake.numericColumns.addAll([
      'price',
      'asking_price',
      'total_quantity',
      'available_quantity',
      'reserved_quantity',
      'sold_quantity',
    ]);

    profileRepo = SellerProfileRepository(
      supabase: fake.client,
      storage: storage,
    );
    commoditiesRepo = CommoditiesRepository(
      client: fake.client,
      storage: storage,
    );
    CommoditiesRepository.clearSessionCache();
  });

  tearDown(() => fake.close());

  group('Trusted Identity & Profile Readiness', () {
    test('company seller readiness is complete with firm name and location', () async {
      await _signIn(fake, _companySeller);
      final r = await profileRepo.checkListingReadiness();
      expect(r.status, ListingReadinessStatus.complete);
      expect(r.firmName, 'Agro Corp India');
      expect(r.companyStateId, 'S-1');
      expect(r.companyDistrictId, 'D-1');
    });

    test('individual seller readiness is complete with individual name without firm', () async {
      await _signIn(fake, _individualSeller1);
      final r = await profileRepo.checkListingReadiness();
      expect(r.status, ListingReadinessStatus.complete);
      expect(r.firmName, 'Ramesh Kumar (Kisan)');
    });

    test('unprovisioned user without public.users row is incomplete when unprovisioned', () async {
      await _signIn(fake, _unprovisionedUser);
      fake.failWith = (r) {
        if (r.table == 'provision_individual_seller') {
          return (500, {'message': 'RPC error'});
        }
        return null;
      };
      final r = await profileRepo.checkListingReadiness();
      expect(r.status, ListingReadinessStatus.incomplete);
      expect(r.missing.single, contains('not yet provisioned'));
    });

    test('self-asserted seller metadata without trusted seller role is rejected', () async {
      await _signIn(fake, _buyerUser, role: 'buyer');
      final r = await profileRepo.checkListingReadiness();
      expect(r.status, ListingReadinessStatus.incomplete);
      expect(r.missing.single, contains('does not have active seller permissions'));
    });
  });

  group('Ownership Model & Mutual Exclusivity Invariant', () {
    test('toSupabaseInsert rejects payload with neither ownership identifier', () {
      expect(
        () => _dto().toSupabaseInsert(),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'm', contains('either a companyId or a sellerUserId'))),
      );
    });

    test('toSupabaseInsert rejects payload with both companyId and sellerUserId', () {
      expect(
        () => _dto().toSupabaseInsert(
          companyId: _companyA,
          sellerUserId: _individualSeller1,
        ),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'm', contains('cannot have both companyId and sellerUserId'))),
      );
    });

    test('individual seller creates lot with seller_user_id and null company_id', () async {
      await _signIn(fake, _individualSeller1);
      final created = await commoditiesRepo.createCommodity(_dto(lot: 'INDIV-OWN-1'));
      expect(created.sellerUserId, _individualSeller1);
      expect(created.companyId, isNull);
      expect(created.isIndividualOwned, isTrue);
      expect(created.isCompanyOwned, isFalse);

      final row = fake.tables['availabilities']!.firstWhere((r) => r['id'] == created.id);
      expect(row['seller_user_id'], _individualSeller1);
      expect(row['company_id'], isNull);
    });

    test('company seller creates lot with company_id and null seller_user_id', () async {
      await _signIn(fake, _companySeller);
      final created = await commoditiesRepo.createCommodity(_dto(lot: 'CORP-OWN-1'));
      expect(created.companyId, _companyA);
      expect(created.sellerUserId, isNull);
      expect(created.isCompanyOwned, isTrue);
      expect(created.isIndividualOwned, isFalse);

      final row = fake.tables['availabilities']!.firstWhere((r) => r['id'] == created.id);
      expect(row['company_id'], _companyA);
      expect(row['seller_user_id'], isNull);
    });
  });

  group('Isolation: Cross-Seller & Cross-Company Access Prevention', () {
    test('individual seller 1 only reads own lots, never other seller or company lots', () async {
      await _signIn(fake, _individualSeller1);
      await commoditiesRepo.createCommodity(_dto(lot: 'MINE-1'));
      CommoditiesRepository.clearSessionCache();

      final lots = await commoditiesRepo.getCommodities();
      expect(lots.length, 1);
      expect(lots.first.lotNumber, 'MINE-1');
      expect(lots.any((l) => l.lotNumber == 'LOT-CORP-A1'), isFalse);
      expect(lots.any((l) => l.lotNumber == 'LOT-INDIV-S2'), isFalse);
    });

    test('individual seller 1 cannot update price of individual seller 2 lot', () async {
      await _signIn(fake, _individualSeller1);
      await expectLater(
        commoditiesRepo.updateCommodityPrice('a0000000-0000-4000-8000-000000000002', 99999),
        throwsA(isA<PriceUpdateException>().having((e) => e.message, 'm', contains('not found for your account'))),
      );
      // Verify price did not change in database
      final row = fake.tables['availabilities']!.firstWhere((r) => r['id'] == 'a0000000-0000-4000-8000-000000000002');
      expect(row['asking_price'], 28000);
    });

    test('individual seller 1 cannot update price of company A lot', () async {
      await _signIn(fake, _individualSeller1);
      await expectLater(
        commoditiesRepo.updateCommodityPrice('a0000000-0000-4000-8000-000000000001', 99999),
        throwsA(isA<PriceUpdateException>().having((e) => e.message, 'm', contains('not found for your account'))),
      );
    });

    test('company seller cannot update price of individual seller lot', () async {
      await _signIn(fake, _companySeller);
      await expectLater(
        commoditiesRepo.updateCommodityPrice('a0000000-0000-4000-8000-000000000002', 99999),
        throwsA(isA<PriceUpdateException>().having((e) => e.message, 'm', contains('not found for your account'))),
      );
    });
  });

  group('Lifecycle Operations: Price, Fulfilled, Withdraw, Broker', () {
    test('individual seller updates price with server confirmation', () async {
      await _signIn(fake, _individualSeller1);
      final created = await commoditiesRepo.createCommodity(_dto(lot: 'INDIV-P1', price: 20000));

      final confirmed = await commoditiesRepo.updateCommodityPrice(created.id, 21500);
      expect(confirmed, 21500);

      final row = fake.tables['availabilities']!.firstWhere((r) => r['id'] == created.id);
      expect(row['asking_price'], 21500);
    });

    test('individual seller marks lot Fulfilled and Cancelled (Withdraw)', () async {
      await _signIn(fake, _individualSeller1);
      final created = await commoditiesRepo.createCommodity(_dto(lot: 'INDIV-F1'));

      final fulfilled = await commoditiesRepo.updateCommodityStatus(created.id, 'Fulfilled');
      expect(fulfilled, 'Fulfilled');

      final cancelled = await commoditiesRepo.updateCommodityStatus(created.id, 'Cancelled');
      expect(cancelled, 'Cancelled');
    });

    test('individual seller assigns and changes eligible active broker', () async {
      await _signIn(fake, _individualSeller1);
      final created = await commoditiesRepo.createCommodity(_dto(lot: 'INDIV-BRK'));

      final assigned = await commoditiesRepo.updateCommodityBroker(
        created.id,
        brokerId: _activeBroker,
        brokerName: 'Broker Ram',
      );
      expect(assigned, _activeBroker);

      final unassigned = await commoditiesRepo.updateCommodityBroker(
        created.id,
        brokerId: null,
        brokerName: null,
      );
      expect(unassigned, isNull);
    });

    test('unregistered broker UUID is rejected before update', () async {
      await _signIn(fake, _individualSeller1);
      final created = await commoditiesRepo.createCommodity(_dto(lot: 'INDIV-BRK2'));

      await expectLater(
        commoditiesRepo.updateCommodityBroker(
          created.id,
          brokerId: 'invalid-broker-uuid',
          brokerName: 'Fake',
        ),
        throwsA(isA<BrokerUpdateException>().having((e) => e.message, 'm', contains('not registered'))),
      );
    });
  });

  group('Error Boundaries, Duplicate Prevention, and Resiliency', () {
    test('duplicate lot number submission (23505) returns clear friendly error', () async {
      await _signIn(fake, _individualSeller1);
      await commoditiesRepo.createCommodity(_dto(lot: 'DUP-001'));

      fake.failWith = (r) => r.method == 'POST'
          ? (409, {'code': '23505', 'message': 'unique violation'})
          : null;

      await expectLater(
        commoditiesRepo.createCommodity(_dto(lot: 'DUP-001')),
        throwsA(isA<ListingSubmitException>().having((e) => e.code, 'code', '23505')),
      );
    });

    test('network retry does not duplicate state in session cache on failure', () async {
      await _signIn(fake, _individualSeller1);
      fake.failWith = (r) => r.method == 'POST'
          ? (503, {'code': '08006', 'message': 'connection failure'})
          : null;

      await expectLater(
        commoditiesRepo.createCommodity(_dto(lot: 'FAIL-001')),
        throwsA(isA<ListingSubmitException>()),
      );

      // Cache does not contain failed lot
      fake.failWith = null;
      final commodities = await commoditiesRepo.getCommodities();
      expect(commodities.any((c) => c.lotNumber == 'FAIL-001'), isFalse);
    });

    test('empty list is distinct from 500 server error', () async {
      await _signIn(fake, _individualSeller1);
      expect(await commoditiesRepo.getCommodities(), isEmpty);

      fake.failWith = (r) => r.table == 'availabilities'
          ? (500, {'code': 'XX000', 'message': 'database crash'})
          : null;

      await expectLater(
        commoditiesRepo.getCommodities(),
        throwsA(isA<CommodityListException>()),
      );
    });
  });
}
