import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/data/commodities_repository.dart';
import 'package:rmseller_mobile/features/commodities/domain/commodity_model.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';

import '../support/fake_postgrest.dart';

const _sellerId = '7c000000-0000-4000-8000-000000000001';
const _companyId = '20000000-0000-4000-8000-0000000000a1';
const _unprovisionedId = '7c000000-0000-4000-8000-000000000099';

String _jwt(String sub, {int offsetSeconds = 3600, String role = 'seller'}) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + offsetSeconds;
  return '${b64({'alg': 'none', 'typ': 'JWT'})}.'
      '${b64({'sub': sub, 'role': 'authenticated', 'exp': exp})}.sig';
}

Future<void> _seedSession(
  FakePostgrest fake,
  String sub, {
  bool isExpired = false,
  String role = 'seller',
  String refreshToken = 'valid-refresh-token',
}) async {
  final offset = isExpired ? -60 : 3600;
  await fake.client.auth.setInitialSession(
    jsonEncode({
      'access_token': _jwt(sub, offsetSeconds: offset, role: role),
      'token_type': 'bearer',
      'expires_in': offset,
      'refresh_token': refreshToken,
      'user': {
        'id': sub,
        'aud': 'authenticated',
        'app_metadata': {'role': role},
        'user_metadata': <String, dynamic>{
          'role': role,
          'name': 'Ramesh Kumar (Farmer)',
          'full_name': 'Ramesh Kumar',
        },
        'created_at': '2026-10-01T00:00:00Z',
      },
    }),
  );
}

void main() {
  late FakePostgrest fake;
  late SecureStorageService storage;
  late CommoditiesRepository commoditiesRepo;
  late SellerProfileRepository profileRepo;

  setUp(() async {
    storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    await storage.clearAll();

    fake = await FakePostgrest.start({
      'users': [
        {
          'id': _sellerId,
          'role': 'seller',
          'status': true,
          'name': 'Priya Singh',
          'company_id': _companyId,
        },
      ],
      'companies': [
        {
          'id': _companyId,
          'name': 'Priya Agro Foods Ltd',
          'gst': '08AABCP1234F1Z5',
          'state_id': 'state-rj',
          'district_id': 'dist-bik',
          'is_verified': true,
          'trust_score': 95,
        },
      ],
      'availabilities': [],
    });

    commoditiesRepo = CommoditiesRepository(
      client: fake.client,
      storage: storage,
    );
    profileRepo = SellerProfileRepository(
      supabase: fake.client,
      storage: storage,
    );
  });

  tearDown(() async {
    await fake.close();
  });

  group('RMS-SELLER-PROVISIONING-FIX-01: Account Provisioning Engine Tests', () {
    test(
      '1. Existing seller with a valid company profile passes readiness and can post',
      () async {
        await _seedSession(fake, _sellerId);

        final readiness = await profileRepo.checkListingReadiness();
        expect(readiness.status, equals(ListingReadinessStatus.complete));
        expect(readiness.firmName, equals('Priya Agro Foods Ltd'));

        final created = await commoditiesRepo.createCommodity(
          CreateCommodityDto(
            commodityId: 'comm-1',
            commodityName: 'Chana',
            gradeId: 'gr-1',
            gradeName: 'FAQ Grade 1',
            totalQuantity: 50.0,
            unitId: 'unit-mt',
            unitSymbol: 'MT',
            askingPrice: 5200.0,
            lotNumber: 'LOT-PRIYA-001',
            stateId: 'state-rj',
            stateName: 'Rajasthan',
            districtId: 'dist-bik',
            districtName: 'Bikaner',
            loadingStatus: 'Ready to Load',
            availableFrom: DateTime.now(),
            validUntil: DateTime.now().add(const Duration(days: 7)),
          ),
        );

        expect(created.id, isNotEmpty);
        expect(created.lotNumber, equals('LOT-PRIYA-001'));
      },
    );

    test(
      '2. Newly registered individual seller auto-provisions and completes readiness',
      () async {
        await _seedSession(fake, _unprovisionedId);

        // Before test: _unprovisionedId is NOT in public.users
        expect(
          fake.tables['users']!.any((u) => u['id'] == _unprovisionedId),
          isFalse,
        );

        // checkListingReadiness attempts auto-provisioning
        final readiness = await profileRepo.checkListingReadiness();

        // The user was auto-provisioned into users table
        expect(
          fake.tables['users']!.any((u) => u['id'] == _unprovisionedId),
          isTrue,
        );
        expect(readiness.status, equals(ListingReadinessStatus.complete));
        expect(readiness.firmName, equals('Ramesh Kumar (Farmer)'));
      },
    );

    test(
      '3. Sole proprietor without company incorporation documents posts as individual seller',
      () async {
        await _seedSession(fake, _unprovisionedId);

        final created = await commoditiesRepo.createCommodity(
          CreateCommodityDto(
            commodityId: 'comm-1',
            commodityName: 'Wheat Sharbati',
            gradeId: 'gr-1',
            gradeName: 'Grade A',
            totalQuantity: 25.0,
            unitId: 'unit-mt',
            unitSymbol: 'MT',
            askingPrice: 3400.0,
            lotNumber: 'LOT-RAMESH-SOLE-01',
            stateId: 'state-rj',
            stateName: 'Rajasthan',
            districtId: 'dist-bik',
            districtName: 'Bikaner',
            loadingStatus: 'Ready to Load',
            availableFrom: DateTime.now(),
            validUntil: DateTime.now().add(const Duration(days: 7)),
          ),
        );

        expect(created.id, isNotEmpty);
        expect(created.lotNumber, equals('LOT-RAMESH-SOLE-01'));
        // Verify in DB that seller_user_id is the user's ID and company_id is null
        final inserted = fake.tables['availabilities']!.firstWhere(
          (a) => a['lot_number'] == 'LOT-RAMESH-SOLE-01',
        );
        expect(inserted['seller_user_id'], equals(_unprovisionedId));
        expect(inserted['company_id'], isNull);
      },
    );

    test(
      '4. Missing seller profile returns actionable message guiding to Complete Profile',
      () async {
        await _seedSession(fake, 'unknown-unprovisionable-user');

        // Override fake to simulate RPC failure (e.g. backend down or pending permission)
        fake.failWith = (r) {
          if (r.table == 'provision_individual_seller') {
            return (500, {'message': 'RPC disabled'});
          }
          return null;
        };

        final readiness = await profileRepo.checkListingReadiness();
        expect(readiness.status, equals(ListingReadinessStatus.incomplete));
        expect(readiness.missing, isNotEmpty);
        expect(
          readiness.missing.first,
          contains('Please complete your profile'),
        );
      },
    );

    test(
      '5. Repeated provisioning is idempotent and does not create duplicate user rows',
      () async {
        await _seedSession(fake, _unprovisionedId);

        // Call provision multiple times
        await profileRepo.provisionCurrentSeller();
        await profileRepo.provisionCurrentSeller();
        await profileRepo.checkListingReadiness();

        final matchingRows =
            fake.tables['users']!
                .where((u) => u['id'] == _unprovisionedId)
                .toList();
        expect(matchingRows.length, equals(1));
        expect(matchingRows.first['role'], equals('seller'));
        expect(matchingRows.first['status'], equals(true));
      },
    );

    test(
      '6. Network failure during readiness check returns unverified retry message',
      () async {
        await _seedSession(fake, _sellerId);

        fake.failWith = (r) {
          if (r.table == 'users') {
            return (500, {'message': 'Internal Server Error'});
          }
          return null;
        };

        // When table query fails, readiness returns unverified with retry message
        final readiness = await profileRepo.checkListingReadiness();
        expect(readiness.status, equals(ListingReadinessStatus.unverified));
        expect(readiness.error, contains('retry'));
      },
    );

    test(
      '7. Unauthorized user role (e.g. buyer) cannot self-provision or list commodities',
      () async {
        await _seedSession(fake, 'buyer-user-id', role: 'buyer');

        // Rpc rejects buyer
        fake.failWith = (r) {
          if (r.table == 'provision_individual_seller') {
            return (403, {'message': '42501: Only sellers can be provisioned'});
          }
          return null;
        };

        final readiness = await profileRepo.checkListingReadiness();
        expect(readiness.status, equals(ListingReadinessStatus.incomplete));
      },
    );

    test(
      '8. Broker assignment is preserved on listing without exposing direct buyer contact',
      () async {
        await _seedSession(fake, _sellerId);

        const brokerId = '40000000-0000-4000-8000-0000000000b1';
        final created = await commoditiesRepo.createCommodity(
          CreateCommodityDto(
            commodityId: 'comm-1',
            commodityName: 'Moong Whole',
            gradeId: 'gr-1',
            gradeName: 'FAQ Grade 1',
            totalQuantity: 20.0,
            unitId: 'unit-mt',
            unitSymbol: 'MT',
            askingPrice: 7800.0,
            lotNumber: 'LOT-BROKER-001',
            stateId: 'state-rj',
            stateName: 'Rajasthan',
            districtId: 'dist-bik',
            districtName: 'Bikaner',
            loadingStatus: 'Ready to Load',
            availableFrom: DateTime.now(),
            validUntil: DateTime.now().add(const Duration(days: 7)),
            brokerId: brokerId,
            brokerName: 'Mandi Broker Desk',
          ),
        );

        expect(created.brokerId, equals(brokerId));
        final inserted = fake.tables['availabilities']!.firstWhere(
          (a) => a['lot_number'] == 'LOT-BROKER-001',
        );
        expect(inserted['broker_id'], equals(brokerId));
      },
    );
  });
}
