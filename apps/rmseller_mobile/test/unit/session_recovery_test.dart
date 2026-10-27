import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmseller_mobile/features/commodities/data/commodities_repository.dart';
import 'package:rmseller_mobile/features/commodities/domain/commodity_model.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';

import '../support/fake_postgrest.dart';

const _sellerId = '7c000000-0000-4000-8000-000000000001';
const _companyId = '20000000-0000-4000-8000-0000000000a1';

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
        'user_metadata': <String, dynamic>{'role': role},
        'created_at': '2026-10-01T00:00:00Z',
      },
    }),
  );
}

void main() {
  late FakePostgrest fake;
  late SecureStorageService storage;
  late AuthRepository authRepo;
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
          'name': 'Priya Singh',
          'status': true,
          'company_id': _companyId,
        },
      ],
      'companies': [
        {
          'id': _companyId,
          'name': 'Priya Agro Foods',
          'gst': '08AAAAA0000A1Z5',
          'state_id': 'state-rj',
          'district_id': 'dist-bundi',
          'trust_score': 95,
          'is_verified': true,
        },
      ],
      'availabilities': [],
    });

    authRepo = AuthRepository(supabase: fake.client, storage: storage);
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

  group('RB-SELLER-SESSION-RECOVERY-01: Comprehensive Lifecycle Tests', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Expired access token with successful refresh
    // -------------------------------------------------------------------------
    test('1. Expired access token is transparently recovered via refreshSession', () async {
      await _seedSession(fake, _sellerId, isExpired: true);
      expect(fake.client.auth.currentSession!.isExpired, isTrue);

      final state = await authRepo.recoverSession();
      expect(state, SessionRecoveryState.recovered);

      // Verify that after recovery, session is active and not expired
      final current = fake.client.auth.currentSession;
      expect(current, isNotNull);
      expect(current!.isExpired, isFalse);

      // Verify commodities repository can now resolve seller ownership without error
      final list = await commoditiesRepo.getCommodities();
      expect(list, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Invalid or revoked refresh token terminates session cleanly
    // -------------------------------------------------------------------------
    test('2. Invalid or revoked refresh token clears session and returns unrecoverable', () async {
      await _seedSession(fake, _sellerId, isExpired: true, refreshToken: 'revoked-token');

      // Inject 400 Bad Request / Invalid Refresh Token on auth endpoint
      fake.failWith = (req) {
        if (req.table == 'token') {
          return (400, {'error': 'invalid_grant', 'error_description': 'Invalid Refresh Token'});
        }
        return null;
      };

      await storage.saveToken('expired-access-token');
      await storage.saveRefreshToken('revoked-token');
      await storage.saveUserInfo(
        id: _sellerId,
        role: 'seller',
        email: 'priya@gmail.com',
        fullName: 'Priya Singh',
      );

      final state = await authRepo.recoverSession();
      expect(state, SessionRecoveryState.unrecoverable);

      // Storage must be wiped clean
      expect(await storage.getToken(), isNull);
      expect(await storage.getUserId(), isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Offline/network failure does not destroy stored credentials
    // -------------------------------------------------------------------------
    test('3. Network failure during refresh preserves stored credentials', () async {
      await _seedSession(fake, _sellerId, isExpired: true);

      // Inject network connection failure
      fake.failWith = (req) {
        if (req.table == 'token') {
          return (503, {'message': 'Connection refused: Failed host lookup'});
        }
        return null;
      };

      await storage.saveToken('expired-access-token');
      await storage.saveRefreshToken('saved-refresh-token');
      await storage.saveUserInfo(
        id: _sellerId,
        role: 'seller',
        email: 'priya@gmail.com',
        fullName: 'Priya Singh',
      );

      final state = await authRepo.recoverSession();
      expect(state, SessionRecoveryState.networkError);

      // Storage must NOT be cleared during offline network failure
      expect(await storage.getToken(), isNotNull);
      expect(await storage.getUserId(), equals(_sellerId));
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Authorization/RLS failure is not misclassified as session expiry
    // -------------------------------------------------------------------------
    test('4. RLS / permission failure (42501) is treated as permission denied, not session expiry', () async {
      await _seedSession(fake, _sellerId, isExpired: false);

      fake.failWith = (req) {
        if (req.table == 'availabilities' && req.method == 'GET') {
          return (403, {'code': '42501', 'message': 'permission denied for table availabilities'});
        }
        return null;
      };

      try {
        await commoditiesRepo.getCommodities();
        fail('Expected CommodityListException');
      } on CommodityListException catch (e) {
        // Must NOT masquerade as "Your session has expired"
        expect(e.message, isNot(contains('session has expired')));
        expect(e.message, contains(CommodityListException.generic));
      }
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Session persistence after app restart
    // -------------------------------------------------------------------------
    test('5. Session restored from secure storage on app restart even if in-memory session was dropped', () async {
      // Simulate stored refresh token in secure storage from a prior login
      await storage.saveToken('prior-access-token');
      await storage.saveRefreshToken('valid-persisted-refresh');
      await storage.saveUserInfo(
        id: _sellerId,
        role: 'seller',
        email: 'priya@gmail.com',
        fullName: 'Priya Singh',
        companyId: _companyId,
        companyName: 'Priya Agro Foods',
      );

      // In-memory session on client is initially null
      expect(fake.client.auth.currentSession, isNull);

      final user = await authRepo.getSavedUser();
      expect(user, isNotNull);
      expect(user!.id, equals(_sellerId));
      expect(user.role, equals('seller'));
      expect(user.companyName, equals('Priya Agro Foods'));

      // In-memory session must be re-hydrated
      expect(fake.client.auth.currentSession, isNotNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Concurrent API calls during refresh are deduplicated
    // -------------------------------------------------------------------------
    test('6. Concurrent recovery calls share a single in-flight refresh request', () async {
      await _seedSession(fake, _sellerId, isExpired: true);

      int refreshRequestCount = 0;
      fake.authHandler = (req) {
        refreshRequestCount++;
        return {
          'access_token': _jwt(_sellerId, offsetSeconds: 3600),
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'new-single-refresh',
          'user': {
            'id': _sellerId,
            'aud': 'authenticated',
            'app_metadata': {'role': 'seller'},
            'user_metadata': {'role': 'seller'},
            'created_at': '2026-10-01T00:00:00Z',
          },
        };
      };

      // Launch 5 concurrent recoverSession calls simultaneously
      final results = await Future.wait([
        authRepo.recoverSession(),
        authRepo.recoverSession(),
        authRepo.recoverSession(),
        authRepo.recoverSession(),
        authRepo.recoverSession(),
      ]);

      // All 5 must succeed
      for (final r in results) {
        expect(r, SessionRecoveryState.recovered);
      }

      // Exact deduplication: only 1 network request fired
      expect(refreshRequestCount, equals(1));
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Business profile readiness recovers session before check
    // -------------------------------------------------------------------------
    test('7. checkListingReadiness transparently recovers expired session', () async {
      await _seedSession(fake, _sellerId, isExpired: true);

      final readiness = await profileRepo.checkListingReadiness();
      expect(readiness.status, equals(ListingReadinessStatus.complete));
      expect(readiness.firmName, equals('Priya Agro Foods'));
      expect(readiness.companyStateId, equals('state-rj'));
      expect(readiness.companyDistrictId, equals('dist-bundi'));
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Posting form submission recovers session and preserves payload
    // -------------------------------------------------------------------------
    test('8. Commodity creation recovers expired session and inserts record', () async {
      await _seedSession(fake, _sellerId, isExpired: true);

      final dto = CreateCommodityDto(
        commodityId: '10000000-0000-4000-8000-000000000001',
        commodityName: 'Mustard Seeds',
        gradeId: '30000000-0000-4000-8000-000000000001',
        gradeName: 'FAQ Grade 1',
        totalQuantity: 30.0,
        unitSymbol: 'MT',
        unitId: '20000000-0000-4000-8000-000000000001',
        askingPrice: 54000.0,
        lotNumber: 'LOT-RECOVER-01',
        stateName: 'Rajasthan',
        districtName: 'Bundi',
        stateId: 'state-rj',
        districtId: 'dist-bundi',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 7)),
      );

      final created = await commoditiesRepo.createCommodity(dto);
      expect(created.id, isNotNull);
      expect(created.lotNumber, equals('LOT-RECOVER-01'));
      expect(created.companyId, equals(_companyId));

      // Re-read directly from database table
      expect(fake.tables['availabilities']!.length, equals(1));
      expect(fake.tables['availabilities']!.first['lot_number'], equals('LOT-RECOVER-01'));
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Duplicate submission lock prevents duplicate lots
    // -------------------------------------------------------------------------
    test('9. Submission lock prevents simultaneous duplicate posts during retry', () async {
      await _seedSession(fake, _sellerId, isExpired: false);

      final dto = CreateCommodityDto(
        commodityId: '10000000-0000-4000-8000-000000000001',
        commodityName: 'Mustard Seeds',
        gradeId: '30000000-0000-4000-8000-000000000001',
        gradeName: 'FAQ Grade 1',
        totalQuantity: 20.0,
        unitSymbol: 'MT',
        unitId: '20000000-0000-4000-8000-000000000001',
        askingPrice: 50000.0,
        lotNumber: 'LOT-CONCUR-01',
        stateName: 'Rajasthan',
        districtName: 'Bundi',
        stateId: 'state-rj',
        districtId: 'dist-bundi',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 7)),
      );

      final firstPost = commoditiesRepo.createCommodity(dto);
      expect(
        () => commoditiesRepo.createCommodity(dto),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('submission is already in progress'),
        )),
      );

      final created = await firstPost;
      expect(created.lotNumber, equals('LOT-CONCUR-01'));
      expect(fake.tables['availabilities']!.length, equals(1));
    });

    // -------------------------------------------------------------------------
    // Scenario 10: Individual and company-linked seller flows supported
    // -------------------------------------------------------------------------
    test('10. Individual seller without company recovers session and posts lot under trusted user ID', () async {
      const individualId = '7c000000-0000-4000-8000-000000000009';
      fake.tables['users']!.add({
        'id': individualId,
        'role': 'seller',
        'name': 'Ramesh Kumar (Farmer)',
        'status': true,
        'company_id': null, // Individual seller
      });

      await _seedSession(fake, individualId, isExpired: true);

      final readiness = await profileRepo.checkListingReadiness();
      expect(readiness.status, equals(ListingReadinessStatus.complete));
      expect(readiness.firmName, equals('Ramesh Kumar (Farmer)'));

      final dto = CreateCommodityDto(
        commodityId: '10000000-0000-4000-8000-000000000001',
        commodityName: 'Wheat Sharbati',
        gradeId: '30000000-0000-4000-8000-000000000001',
        gradeName: 'FAQ Grade 1',
        totalQuantity: 15.0,
        unitSymbol: 'MT',
        unitId: '20000000-0000-4000-8000-000000000001',
        askingPrice: 28000.0,
        lotNumber: 'INDIV-LOT-RECOVER',
        stateName: 'Rajasthan',
        districtName: 'Bundi',
        stateId: 'state-rj',
        districtId: 'dist-bundi',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 7)),
      );

      final created = await commoditiesRepo.createCommodity(dto);
      expect(created.sellerUserId, equals(individualId));
      expect(created.companyId, isNull);

      final row = fake.tables['availabilities']!.last;
      expect(row['seller_user_id'], equals(individualId));
      expect(row['company_id'], isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 11: No demo company or demo user introduced
    // -------------------------------------------------------------------------
    test('11. Authentic database values are always preferred over hardcoded demo data', () async {
      await _seedSession(fake, _sellerId, isExpired: false);

      final profile = await profileRepo.checkListingReadiness();
      expect(profile.firmName, equals('Priya Agro Foods'));
      expect(profile.firmName, isNot(equals('Bikaner Agro Traders')));
      expect(profile.firmName, isNot(equals('Bikaner Agro Processing Ltd')));
    });
  });
}
