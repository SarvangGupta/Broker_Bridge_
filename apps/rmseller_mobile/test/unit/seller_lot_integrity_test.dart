// RB-SELLER-POST-INTEGRITY-02: Mark Fulfilled / Withdraw confirmation and
// retry/duplicate behaviour, through the real CommoditiesRepository online path
// against a loopback PostgREST. No live database.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/data/commodities_repository.dart';
import 'package:rmseller_mobile/features/commodities/domain/commodity_model.dart';
import 'package:rmseller_mobile/features/commodities/presentation/post_commodity_screen.dart';

import '../support/fake_postgrest.dart';

const _seller = '7c000000-0000-4000-8000-000000000001';
const _companyC = '20000000-0000-4000-8000-0000000000c1';
const _companyD = '20000000-0000-4000-8000-0000000000d1';
const _foreignLot = 'f0000000-0000-4000-8000-0000000000f1';

String _jwt(String sub) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1));
  return '${b64({'alg': 'none', 'typ': 'JWT'})}.'
      '${b64({'sub': sub, 'role': 'authenticated', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

CreateCommodityDto _dto(String lot) => CreateCommodityDto(
  commodityId: '10000000-0000-4000-8000-000000000001',
  commodityName: 'Wheat Bran',
  gradeId: '30000000-0000-4000-8000-000000000001',
  gradeName: 'FAQ',
  lotNumber: lot,
  totalQuantity: 25,
  unitId: '22000000-0000-0000-0000-000000000001',
  unitSymbol: 'MT',
  askingPrice: 22500,
  stateId: '40000000-0000-0000-0000-000000000001',
  stateName: 'Rajasthan',
  districtId: '50000000-0000-0000-0000-000000000001',
  districtName: 'Bikaner',
  availableFrom: DateTime(2026, 10, 27),
  validUntil: DateTime(2026, 11, 3),
);

void main() {
  late FakePostgrest fake;
  late CommoditiesRepository repo;

  List<Map<String, dynamic>> lots() => fake.tables['availabilities']!;
  Map<String, dynamic> row(String id) => lots().firstWhere((r) => r['id'] == id);
  int notified() => CommoditiesRepository.commoditiesUpdatedNotifier.value;

  setUp(() async {
    final storage = SecureStorageService()..enableMemoryFallbackForTesting();
    fake = await FakePostgrest.start({
      'users': [
        {'id': _seller, 'company_id': _companyC},
      ],
      'availabilities': [
        {
          'id': _foreignLot,
          'company_id': _companyD,
          'lot_number': 'LOT-SHARED-1',
          'status': 'Open',
          'asking_price': 900,
          'created_at': '2026-10-20T10:00:00.000',
        },
      ],
    });
    // Live `availabilities` numeric columns (verified read-only, 2026-10-27).
    fake.numericColumns.addAll([
      'price',
      'asking_price',
      'total_quantity',
      'available_quantity',
      'reserved_quantity',
      'sold_quantity',
      'confidential_minimum_price',
    ]);
    await fake.client.auth.setInitialSession(
      jsonEncode({
        'access_token': _jwt(_seller),
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'r',
        'user': {
          'id': _seller,
          'aud': 'authenticated',
          'app_metadata': {'role': 'seller'},
          'user_metadata': <String, dynamic>{},
          'created_at': '2026-10-01T00:00:00Z',
        },
      }),
    );
    repo = CommoditiesRepository(client: fake.client, storage: storage);
    CommoditiesRepository.clearSessionCache();
  });

  tearDown(() => fake.close());

  group('Mark Fulfilled / Withdraw (server-confirmed)', () {
    for (final status in ['Fulfilled', 'Cancelled']) {
      test('$status: confirmed by the server, then visible on re-read', () async {
        final lot = await repo.createCommodity(_dto('LOT-S-$status'));
        final before = notified();

        expect(await repo.updateCommodityStatus(lot.id, status), status);
        final patch = fake.writesTo('availabilities').last;
        expect(patch.method, 'PATCH');
        expect(patch.filter('id'), 'eq.${lot.id}');
        expect(patch.filter('company_id'), 'eq.$_companyC');
        expect(row(lot.id)['status'], status);
        expect(notified(), before + 1);

        CommoditiesRepository.clearSessionCache();
        expect((await repo.getCommodityById(lot.id))?.status, status);
      });
    }

    test('request failure: error, status unchanged, no notify', () async {
      final lot = await repo.createCommodity(_dto('LOT-S-FAIL'));
      final before = notified();
      fake.failWith = (r) => r.method == 'PATCH' ? (500, {'code': 'XX000', 'message': 'x'}) : null;

      await expectLater(
        repo.updateCommodityStatus(lot.id, 'Fulfilled'),
        throwsA(isA<StatusUpdateException>()),
      );
      expect(row(lot.id)['status'], 'Open');
      expect(notified(), before);
      expect((await repo.getCommodityById(lot.id))?.status, 'Open');
    });

    test('authorization error (42501) gets a clear message', () async {
      final lot = await repo.createCommodity(_dto('LOT-S-RLS'));
      fake.failWith = (r) => r.method == 'PATCH' ? (403, {'code': '42501', 'message': 'rls'}) : null;
      await expectLater(
        repo.updateCommodityStatus(lot.id, 'Cancelled'),
        throwsA(isA<StatusUpdateException>().having((e) => e.message, 'm', contains('not allowed'))),
      );
    });

    test('zero-row update (another company\'s lot) is an error', () async {
      await expectLater(
        repo.updateCommodityStatus(_foreignLot, 'Cancelled'),
        throwsA(isA<StatusUpdateException>().having((e) => e.message, 'm', contains('not found'))),
      );
      expect(row(_foreignLot)['status'], 'Open');
    });

    test('invalid lot id is rejected before any request', () async {
      final before = fake.requests.length;
      await expectLater(
        repo.updateCommodityStatus('AVL-2026-001', 'Fulfilled'),
        throwsA(isA<StatusUpdateException>()),
      );
      expect(fake.requests.length, before);
    });

    test('server stores a different status (no-op): treated as failure', () async {
      final lot = await repo.createCommodity(_dto('LOT-S-NOOP'));
      final before = notified();
      // Simulate a server-side rule that leaves the status unchanged.
      fake.beforePatch = (r) => (r.body as Map<String, dynamic>)['status'] = 'Open';
      await expectLater(
        repo.updateCommodityStatus(lot.id, 'Fulfilled'),
        throwsA(isA<StatusUpdateException>()),
      );
      expect(notified(), before);
    });
  });

  group('Retry after a lost response (OPEN-01)', () {
    test('today (no constraint): a retry after a lost response duplicates the lot', () async {
      fake.dropResponseAfterCommit = (r) => r.method == 'POST';
      await expectLater(
        repo.createCommodity(_dto('LOT-RETRY-1')),
        throwsA(isA<ListingSubmitException>()),
      );
      fake.dropResponseAfterCommit = null;
      await repo.createCommodity(_dto('LOT-RETRY-1'));
      // Documents the current gap the proposed 0045 constraint closes.
      expect(lots().where((r) => r['lot_number'] == 'LOT-RETRY-1'), hasLength(2));
    });

    test('with proposed unique (company_id, lot_number): retry is refused clearly, one row', () async {
      fake.uniqueConstraints['availabilities'] = [
        ['company_id', 'lot_number'],
      ];
      fake.dropResponseAfterCommit = (r) => r.method == 'POST';
      await expectLater(
        repo.createCommodity(_dto('LOT-RETRY-2')),
        throwsA(isA<ListingSubmitException>()),
      );
      fake.dropResponseAfterCommit = null;
      await expectLater(
        repo.createCommodity(_dto('LOT-RETRY-2')),
        throwsA(
          isA<ListingSubmitException>()
              .having((e) => e.code, 'code', '23505')
              .having((e) => e.message, 'm', contains('already listed')),
        ),
      );
      expect(lots().where((r) => r['lot_number'] == 'LOT-RETRY-2'), hasLength(1));
    });

    test('constraint scope is per company: same lot number elsewhere is allowed', () async {
      fake.uniqueConstraints['availabilities'] = [
        ['company_id', 'lot_number'],
      ];
      // Company D already uses LOT-SHARED-1.
      final lot = await repo.createCommodity(_dto('LOT-SHARED-1'));
      expect(row(lot.id)['company_id'], _companyC);
    });
  });

  group('Listing date rule', () {
    test('valid, same-day and reversed windows', () {
      final from = DateTime(2026, 11, 10, 18, 30);
      expect(PostCommodityScreen.validUntilError(from, DateTime(2026, 11, 20)), isNull);
      // Same calendar day, earlier clock time: still valid.
      expect(PostCommodityScreen.validUntilError(from, DateTime(2026, 11, 10, 9)), isNull);
      expect(
        PostCommodityScreen.validUntilError(from, DateTime(2026, 11, 9, 23, 59)),
        'Valid Until must be on or after Available From',
      );
    });
  });
}
