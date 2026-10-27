// RB-SELLER-POST-REGRESSION-01: post → change price → change broker, through the
// real CommoditiesRepository online code path (Supabase client, PostgREST HTTP,
// RETURNING confirmations) against a loopback PostgREST. No live database.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/commodities/data/commodities_repository.dart';
import 'package:rmseller_mobile/features/commodities/domain/commodity_model.dart';

import '../support/fake_postgrest.dart';

const _seller = '7c000000-0000-4000-8000-000000000001';
const _companyC = '20000000-0000-4000-8000-0000000000c1';
const _companyD = '20000000-0000-4000-8000-0000000000d1';
const _brokerA = 'b0000000-0000-4000-8000-00000000000a';
const _brokerB = 'b0000000-0000-4000-8000-00000000000b';
const _foreignLot = 'f0000000-0000-4000-8000-0000000000f1';

/// Unsigned JWT; gotrue only decodes `exp` locally.
String _jwt(String sub) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1));
  return '${b64({'alg': 'none', 'typ': 'JWT'})}.'
      '${b64({'sub': sub, 'role': 'authenticated', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

Future<void> _signIn(FakePostgrest fake, String sub) =>
    fake.client.auth.setInitialSession(
      jsonEncode({
        'access_token': _jwt(sub),
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'refresh-1',
        'user': {
          'id': sub,
          'aud': 'authenticated',
          'app_metadata': {'role': 'seller'},
          'user_metadata': <String, dynamic>{},
          'created_at': '2026-10-01T00:00:00Z',
        },
      }),
    );

CreateCommodityDto _dto({String lot = 'LOT-E2E-1', String? brokerId}) =>
    CreateCommodityDto(
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
      brokerId: brokerId,
      loadingRemarks: 'Same as registered warehouse · Gate 2',
      visibility: brokerId != null ? 'restricted' : 'global',
    );

void main() {
  late FakePostgrest fake;
  late SecureStorageService storage;
  late CommoditiesRepository repo;

  Map<String, dynamic> row(String id) =>
      fake.tables['availabilities']!.firstWhere((r) => r['id'] == id);

  setUp(() async {
    storage = SecureStorageService()..enableMemoryFallbackForTesting();
    // A stale/wrong cached company: the repository must not use it online.
    await storage.saveUserInfo(
      id: _seller,
      role: 'seller',
      email: 'seller@test',
      fullName: 'Test Seller',
      companyId: '20000000-0000-0000-0000-000000000101',
    );
    fake = await FakePostgrest.start({
      'users': [
        {'id': _seller, 'company_id': _companyC},
      ],
      'availabilities': [
        {
          'id': _foreignLot,
          'company_id': _companyD,
          'asking_price': 900,
          'price': 900,
          'broker_id': _brokerA,
          'status': 'Open',
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
    await _signIn(fake, _seller);
    repo = CommoditiesRepository(client: fake.client, storage: storage);
    CommoditiesRepository.clearSessionCache();
  });

  tearDown(() => fake.close());

  group('E2E: post → price → broker (server-confirmed)', () {
    test('full lifecycle converges on the persisted values', () async {
      // Step 1 — post
      final created = await repo.createCommodity(_dto(brokerId: _brokerA));
      expect(CreateCommodityDto.isValidUuid(created.id), isTrue);
      final post = fake.writesTo('availabilities').single;
      final body = post.body as Map<String, dynamic>;
      expect(body['company_id'], _companyC, reason: 'own company from users row');
      expect(body['visibility'], 'restricted');
      expect(body['broker_id'], _brokerA);
      expect(body['loading_remarks'], 'Same as registered warehouse · Gate 2');

      // Simulate the broker embed PostgREST would resolve via the FK.
      row(created.id)['broker'] = {'name': 'Broker A Desk', 'mobile': '+910000000001'};

      // Server read path (session cache cleared → rows come from the server).
      CommoditiesRepository.clearSessionCache();
      final listed = await repo.getCommodities();
      expect(listed.map((c) => c.id), [created.id], reason: 'own company only');
      final fromServer = listed.single;
      expect(fromServer.askingPrice, 22500);
      expect(fromServer.brokerId, _brokerA);
      expect(fromServer.brokerName, 'Broker A Desk');
      expect(fromServer.loadingRemarks, 'Same as registered warehouse · Gate 2');
      expect(fake.requests.last.filter('company_id'), 'eq.$_companyC');

      // Step 2 — change price
      final saved = await repo.updateCommodityPrice(created.id, 23750);
      expect(saved, 23750);
      final pricePatch = fake.writesTo('availabilities').last;
      expect(pricePatch.filter('id'), 'eq.${created.id}');
      expect(pricePatch.filter('company_id'), 'eq.$_companyC');
      expect(row(created.id)['asking_price'], 23750);
      expect((await repo.getCommodityById(created.id))?.askingPrice, 23750);

      // Second update wins.
      expect(await repo.updateCommodityPrice(created.id, 24000), 24000);
      expect((await repo.getCommodityById(created.id))?.askingPrice, 24000);

      // Step 3 — change broker
      final newBroker = await repo.updateCommodityBroker(
        created.id,
        brokerId: _brokerB,
        brokerName: 'Broker B Desk',
      );
      expect(newBroker, _brokerB);
      expect(row(created.id)['broker_id'], _brokerB);
      row(created.id)['broker'] = {'name': 'Broker B Desk', 'mobile': null};
      final afterBroker = await repo.getCommodityById(created.id);
      expect(afterBroker?.brokerId, _brokerB);
      expect(afterBroker?.brokerName, 'Broker B Desk');

      // Step 4 — integrity
      expect(row(created.id)['company_id'], _companyC);
      expect(row(_foreignLot)['asking_price'], 900);
      expect(row(_foreignLot)['broker_id'], _brokerA);
      expect(fake.writesTo('availabilities').where((r) => r.method == 'POST'), hasLength(1));
    });

    test('a failed price update keeps the confirmed price and does not notify', () async {
      final created = await repo.createCommodity(_dto());
      final notified = CommoditiesRepository.commoditiesUpdatedNotifier.value;
      fake.failWith = (r) => r.method == 'PATCH'
          ? (500, {'code': 'XX000', 'message': 'boom'})
          : null;

      await expectLater(
        repo.updateCommodityPrice(created.id, 30000),
        throwsA(isA<PriceUpdateException>()),
      );
      expect(CommoditiesRepository.commoditiesUpdatedNotifier.value, notified);
      expect(row(created.id)['asking_price'], 22500);
      expect((await repo.getCommodityById(created.id))?.askingPrice, 22500);
    });

    test('a failed broker change keeps the confirmed broker and does not notify', () async {
      final created = await repo.createCommodity(_dto(brokerId: _brokerA));
      final notified = CommoditiesRepository.commoditiesUpdatedNotifier.value;
      fake.failWith = (r) => r.method == 'PATCH'
          ? (500, {'code': 'XX000', 'message': 'boom'})
          : null;

      await expectLater(
        repo.updateCommodityBroker(created.id, brokerId: _brokerB, brokerName: 'B'),
        throwsA(isA<BrokerUpdateException>()),
      );
      expect(CommoditiesRepository.commoditiesUpdatedNotifier.value, notified);
      expect(row(created.id)['broker_id'], _brokerA);
      expect((await repo.getCommodityById(created.id))?.brokerId, _brokerA);
    });

    test('another company\'s lot: zero-row update is an error, not success', () async {
      await expectLater(
        repo.updateCommodityPrice(_foreignLot, 1),
        throwsA(isA<PriceUpdateException>()),
      );
      await expectLater(
        repo.updateCommodityBroker(_foreignLot, brokerId: _brokerB, brokerName: 'B'),
        throwsA(isA<BrokerUpdateException>()),
      );
      expect(row(_foreignLot)['asking_price'], 900);
      expect(row(_foreignLot)['broker_id'], _brokerA);
    });

    test('an unregistered broker id is rejected, never cleared to null', () async {
      final created = await repo.createCommodity(_dto(brokerId: _brokerA));
      final patchesBefore = fake.writesTo('availabilities').length;
      await expectLater(
        repo.updateCommodityBroker(created.id, brokerId: 'BRK-DEMO-01', brokerName: 'Demo'),
        throwsA(isA<BrokerUpdateException>()),
      );
      expect(fake.writesTo('availabilities').length, patchesBefore);
      expect(row(created.id)['broker_id'], _brokerA);
    });

    test('broker FK violation (23503) gets a clear message', () async {
      final created = await repo.createCommodity(_dto());
      fake.failWith = (r) => r.method == 'PATCH'
          ? (409, {'code': '23503', 'message': 'fk'})
          : null;
      await expectLater(
        repo.updateCommodityBroker(created.id, brokerId: _brokerB, brokerName: 'B'),
        throwsA(
          isA<BrokerUpdateException>().having((e) => e.message, 'message', contains('not registered')),
        ),
      );
    });
  });

  group('Posting failures and identity', () {
    test('RLS rejection: friendly error, nothing cached as listed', () async {
      fake.failWith = (r) => r.method == 'POST'
          ? (403, {'code': '42501', 'message': 'new row violates row-level security policy'})
          : null;
      await expectLater(
        repo.createCommodity(_dto()),
        throwsA(
          isA<ListingSubmitException>().having((e) => e.code, 'code', '42501'),
        ),
      );
      fake.failWith = null;
      expect(await repo.getCommodities(), isEmpty);
    });

    // RB-SELLER-INDIVIDUAL-LISTINGS-02: seller without a company posts and manages
    // their own individual lot (seller_user_id), never sees foreign company lots.
    test('seller without a company: posts individual lot, lists own, never sees others', () async {
      fake.tables['users']!.first['company_id'] = null;
      fake.tables['users']!.first['role'] = 'seller';
      expect(await repo.getCommodities(), isEmpty);
      expect(await repo.getPostingHistory(), isEmpty);

      final posted = await repo.createCommodity(_dto(lot: 'INDIV-LOT-1'));
      expect(posted.sellerUserId, _seller);
      expect(posted.companyId, isNull);
      expect(posted.isIndividualOwned, isTrue);
      expect(posted.isCompanyOwned, isFalse);

      CommoditiesRepository.clearSessionCache();
      final mine = await repo.getCommodities();
      expect(mine.map((c) => c.lotNumber), contains('INDIV-LOT-1'));
      // Never sees foreign company lot
      expect(mine.map((c) => c.id), isNot(contains(_foreignLot)));
    });

    test('seller with no users row at all (unprovisioned): lists empty', () async {
      fake.tables['users']!.clear();
      expect(await repo.getCommodities(), isEmpty);
      await expectLater(
        repo.updateCommodityPrice(_foreignLot, 1),
        throwsA(isA<PriceUpdateException>()),
      );
      expect(row(_foreignLot)['asking_price'], 900);
    });

    test('company lookup failure is an error, not an empty list', () async {
      fake.failWith = (r) => r.table == 'users'
          ? (500, {'code': 'XX000', 'message': 'down'})
          : null;
      await expectLater(repo.getCommodities(), throwsA(isA<CommodityListException>()));
    });

    test('duplicate concurrent submission sends one insert', () async {
      final first = repo.createCommodity(_dto());
      await expectLater(repo.createCommodity(_dto()), throwsA(isA<StateError>()));
      await first;
      expect(fake.writesTo('availabilities').where((r) => r.method == 'POST'), hasLength(1));
    });
  });

  group('No demo data online', () {
    test('empty server result is an empty list, not sample lots', () async {
      fake.tables['availabilities']!.clear();
      expect(await repo.getCommodities(), isEmpty);
    });

    test('a failed read is an error, not sample lots', () async {
      fake.failWith = (r) => r.method == 'GET' && r.table == 'availabilities'
          ? (500, {'code': 'XX000', 'message': 'down'})
          : null;
      await expectLater(repo.getCommodities(), throwsA(isA<CommodityListException>()));
    });

    test('a posted lot replaces the empty state', () async {
      fake.tables['availabilities']!.clear();
      expect(await repo.getCommodities(), isEmpty);
      final created = await repo.createCommodity(_dto());
      CommoditiesRepository.clearSessionCache();
      expect((await repo.getCommodities()).map((c) => c.id), [created.id]);
    });
  });
}
