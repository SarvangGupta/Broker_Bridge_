import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/network/api_client.dart';
import 'package:rmbroker_mobile/features/deals/data/deal_repository.dart';
import 'package:rmbroker_mobile/features/deals/domain/allocation_model.dart';
import 'package:rmbroker_mobile/features/deals/domain/deal_model.dart';

import '../../support/fake_postgrest.dart';
import '../directory/directory_repository_test.dart' show MockSecureStorageService;

// Plain test(): testWidgets stubs HttpClient, which would hide the loopback fake.
// Every write goes to an in-memory fake; nothing reaches a real database.

const broker = 'b0000000-0000-4000-8000-000000000001';
const otherBroker = 'b0000000-0000-4000-8000-000000000002';
const reqId = 'a0000000-0000-4000-8000-000000000001';
const lotId = 'c0000000-0000-4000-8000-000000000001';
const allocId = 'd0000000-0000-4000-8000-000000000001';
const dealId = 'e0000000-0000-4000-8000-000000000001';
const versionId = 'f0000000-0000-4000-8000-000000000001';
const buyerCo = '10000000-0000-4000-8000-000000000001';
const sellerCo = '20000000-0000-4000-8000-000000000001';
const maize = '30000000-0000-4000-8000-000000000001';
const wheat = '30000000-0000-4000-8000-000000000002';

ApiClient _offlineApi() {
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) => h.reject(DioException(requestOptions: o, type: DioExceptionType.connectionError)),
      ),
    );
  return ApiClient(storage: MockSecureStorageService(), customDio: dio);
}

/// Repository signed in as [broker], over the fake PostgREST.
class _Repo extends DealRepository {
  _Repo(FakePostgrest fake)
    : super(apiClient: _offlineApi(), supabase: fake.client, storage: MockSecureStorageService());

  @override
  String? activeBrokerId() => broker;
}

Map<String, dynamic> requirementRow({
  String? brokerId = broker,
  String status = 'Open',
  double quantity = 35,
  double fulfilled = 0,
  String unit = 'MT',
  String commodity = maize,
}) => {
  'id': reqId,
  'broker_id': brokerId,
  'company_id': buyerCo,
  'status': status,
  'quantity': quantity,
  'fulfilled_quantity': fulfilled,
  'unit_id': 'unit-$unit',
  'commodity_id': commodity,
  'target_date': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
  'master_units': {'id': 'unit-$unit', 'name': unit, 'symbol': unit},
};

Map<String, dynamic> lotRow({
  String brokerId = broker,
  String status = 'Open',
  double available = 40,
  String unit = 'MT',
  String commodity = maize,
}) => {
  'id': lotId,
  'broker_id': brokerId,
  'company_id': sellerCo,
  'status': status,
  'commodity_id': commodity,
  'available_quantity': available,
  'reserved_quantity': 0,
  'version': 1,
  'valid_until': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
  'master_units': {'symbol': unit},
};

CreateAllocationDto allocationDto({double qty = 35, String unit = 'MT'}) => CreateAllocationDto(
  requirementId: reqId,
  availabilityId: lotId,
  proposedQuantity: qty,
  unitSymbol: unit,
  remainingRequirementQuantity: 1000,
  availableOfferQuantity: 1000,
  agreedPrice: 28000,
);

Map<String, dynamic> dealRow({String status = 'Draft', String brokerId = broker}) => {
  'id': dealId,
  'requirement_id': reqId,
  'quotation_id': 'q-1',
  'buyer_id': buyerCo,
  'seller_id': sellerCo,
  'broker_id': brokerId,
  'agreed_price': 28000,
  'agreed_quantity': 35,
  'status': status,
  'created_at': '2026-10-25T09:00:00.000',
  'closed_at': null,
};

Map<String, dynamic> versionRow({int number = 1, String status = 'Draft', Map<String, dynamic>? snapshot}) => {
  'id': versionId,
  'request_id': dealId,
  'version_number': number,
  'status': status,
  'actor_id': broker,
  'snapshot_payload': snapshot ?? {'agreedPrice': 28000, 'agreedQuantity': 35},
  'created_at': '2026-10-25T09:00:00.000',
};

void main() {
  late FakePostgrest fake;
  tearDown(() => fake.close());

  group('Allocation: requirement ↔ seller lot reservation', () {
    test('reserves lot stock, raises fulfilled quantity, then confirms (web order)', () async {
      fake = await FakePostgrest.start({
        'requirements': [requirementRow()],
        'availabilities': [lotRow()],
        'requirement_allocations': [],
      });

      final result = await _Repo(fake).proposeAllocation(allocationDto());

      expect(result, isA<DealSuccess<AllocationItem>>());
      final alloc = (result as DealSuccess<AllocationItem>).data;
      expect(alloc.status, AllocationStatus.confirmed);
      expect(fake.tables['availabilities']!.single['available_quantity'], 5);
      expect(fake.tables['availabilities']!.single['reserved_quantity'], 35);
      expect(fake.tables['availabilities']!.single['version'], 2);
      expect(fake.tables['requirements']!.single['fulfilled_quantity'], 35);

      final allocWrites = fake.writesTo('requirement_allocations');
      expect((allocWrites.first.body as Map)['status'], 'PROPOSED');
      expect(allocWrites.last.filter('status'), 'eq.PROPOSED');
      expect((allocWrites.last.body as Map)['status'], 'CONFIRMED');
      expect((allocWrites.last.body as Map)['confirmed_at'], isNotNull);
      // Optimistic lock on the lot version.
      expect(fake.writesTo('availabilities').single.filter('version'), 'eq.1');
    });

    test('converts the requirement unit to the lot unit (70 kg against an MT lot)', () async {
      fake = await FakePostgrest.start({
        'requirements': [requirementRow(quantity: 70, unit: 'kg')],
        'availabilities': [lotRow(available: 40)],
        'requirement_allocations': [],
      });

      final result = await _Repo(fake).proposeAllocation(allocationDto(qty: 70, unit: 'kg'));

      expect(result, isA<DealSuccess<AllocationItem>>());
      expect(fake.tables['availabilities']!.single['available_quantity'], closeTo(39.93, 1e-9));
      expect(fake.tables['requirements']!.single['fulfilled_quantity'], 70);
    });

    final guards = <String, (Map<String, dynamic>, Map<String, dynamic>, double, String)>{
      'requirement assigned to another broker': (requirementRow(brokerId: otherBroker), lotRow(), 35, 'not assigned'),
      'unassigned requirement': (requirementRow(brokerId: null), lotRow(), 35, 'not assigned'),
      'cancelled requirement': (requirementRow(status: 'Cancelled'), lotRow(), 35, 'cannot take new allocations'),
      'fully allocated requirement': (requirementRow(status: 'Allocated'), lotRow(), 35, 'cannot take new allocations'),
      'quantity above the remaining requirement': (
        requirementRow(fulfilled: 20),
        lotRow(),
        35,
        'exceeds the remaining',
      ),
      'different product': (requirementRow(), lotRow(commodity: wheat), 35, 'different product'),
      'lot managed by another broker': (requirementRow(), lotRow(brokerId: otherBroker), 35, 'another broker desk'),
      'expired or inactive lot': (requirementRow(), lotRow(status: 'Expired'), 35, 'no longer active'),
      'quantity above the lot balance': (
        requirementRow(quantity: 100),
        lotRow(available: 40),
        50,
        'seller lot balance',
      ),
    };
    for (final entry in guards.entries) {
      test('rejects ${entry.key} without writing anything', () async {
        final (req, lot, qty, message) = entry.value;
        fake = await FakePostgrest.start({
          'requirements': [req],
          'availabilities': [lot],
          'requirement_allocations': [],
        });

        final result = await _Repo(fake).proposeAllocation(allocationDto(qty: qty));

        expect(result, isA<DealError<AllocationItem>>());
        expect((result as DealError).message, contains(message));
        expect(fake.writes(), isEmpty);
      });
    }

    test('a concurrent lot change cancels the allocation and leaves quantities untouched', () async {
      fake = await FakePostgrest.start({
        'requirements': [requirementRow()],
        'availabilities': [lotRow()],
        'requirement_allocations': [],
      });
      // Another desk bumps the lot version before every compare-and-set.
      fake.beforePatch = (r) {
        if (r.table == 'availabilities') {
          final lot = fake.tables['availabilities']!.single;
          lot['version'] = (lot['version'] as int) + 1;
        }
      };

      final result = await _Repo(fake).proposeAllocation(allocationDto());

      expect(result, isA<DealError<AllocationItem>>());
      expect(fake.tables['availabilities']!.single['available_quantity'], 40);
      expect(fake.tables['requirements']!.single['fulfilled_quantity'], 0);
      expect(fake.tables['requirement_allocations']!.single['status'], 'CANCELLED');
    });

    test('a requirement over-allocation race restores the lot and cancels the allocation', () async {
      fake = await FakePostgrest.start({
        'requirements': [requirementRow()],
        'availabilities': [lotRow()],
        'requirement_allocations': [],
      });
      // Another allocation consumes the requirement between read and write.
      fake.beforePatch = (r) {
        if (r.table == 'requirements') fake.tables['requirements']!.single['fulfilled_quantity'] = 30;
      };

      final result = await _Repo(fake).proposeAllocation(allocationDto());

      expect(result, isA<DealError<AllocationItem>>());
      expect(fake.tables['availabilities']!.single['available_quantity'], 40);
      expect(fake.tables['availabilities']!.single['reserved_quantity'], 0);
      expect(fake.tables['requirement_allocations']!.single['status'], 'CANCELLED');
    });

    test('a retry reuses the reserved, uncommitted allocation instead of duplicating it', () async {
      // Balances as seen by the retry (the guard reads them before looking for reuse).
      fake = await FakePostgrest.start({
        'requirements': [requirementRow(quantity: 70, fulfilled: 35)],
        'availabilities': [lotRow(available: 40)],
        'requirement_allocations': [
          {
            'id': allocId,
            'allocation_reference': 'ALC-1',
            'requirement_id': reqId,
            'availability_id': lotId,
            'broker_id': broker,
            'allocated_quantity': 35,
            'status': 'CONFIRMED',
            'confirmed_at': '2026-10-25T09:00:00Z',
            'deal_id': null,
          },
        ],
      });

      final result = await _Repo(fake).proposeAllocation(allocationDto());

      expect((result as DealSuccess<AllocationItem>).data.id, allocId);
      expect(fake.writes(), isEmpty);
    });
  });

  group('Deal creation from an allocation', () {
    Map<String, dynamic> allocationRow({String status = 'CONFIRMED', String? deal}) => {
      'id': allocId,
      'status': status,
      'deal_id': deal,
      'broker_id': broker,
      'allocation_reference': 'ALC-1',
      'requirement_id': reqId,
      'availability_id': lotId,
      'allocated_quantity': 35,
      'allocated_price': 28000,
      'requirements': {
        'id': reqId,
        'company_id': buyerCo,
        'status': 'Open',
        'delivery_location_id': 'wh-unload',
        'master_commodities': {'name': 'Maize DDGS'},
        'master_units': {'symbol': 'MT'},
        'companies': {'name': 'Rohan Feeds'},
      },
      'availabilities': {
        'id': lotId,
        'company_id': sellerCo,
        'status': 'Open',
        'loading_location_id': 'wh-load',
        'loading_location_snapshot': 'Kota Godown, Road - 324005, Kota, Rajasthan',
        'companies': {'name': 'Seller Co'},
      },
    };

    CreateDealDto dealDto() => CreateDealDto(
      allocationId: allocId,
      agreedPrice: 28000,
      agreedQuantity: 35,
      priceBasis: 'FOR_DESTINATION',
      deliveryLocation: 'FOR Mill Delivery, Kota Mandi',
      deliveryDate: DateTime(2026, 11, 8),
    );

    test('links buyer and seller companies (no seller_id column), quotation, version and allocation', () async {
      fake = await FakePostgrest.start({
        'requirement_allocations': [allocationRow()],
        'quotations': [],
        'deals': [],
        'deal_versions': [],
      });

      final result = await _Repo(fake).createDealFromAllocation(dealDto());

      final deal = (result as DealSuccess<DealItem>).data;
      expect(deal.requirementId, reqId);
      expect(deal.buyerCompanyName, 'Rohan Feeds');
      final select = fake.requests.first.query['select']!;
      expect(select, isNot(contains('seller_id')));
      expect(select, contains('availabilities(*')); // seller company comes from the lot row

      final dealInsert = fake.writesTo('deals').single.body as Map;
      expect(dealInsert['buyer_id'], buyerCo);
      expect(dealInsert['seller_id'], sellerCo);
      expect(dealInsert['broker_id'], broker);
      expect(dealInsert['status'], 'Draft');

      final snapshot = (fake.writesTo('deal_versions').single.body as Map)['snapshot_payload'] as Map;
      expect(snapshot['requirementId'], reqId);
      expect(snapshot['allocationId'], allocId);
      expect(snapshot['buyerConfirmed'], isFalse);
      expect(snapshot['deliveryLocation'], 'FOR Mill Delivery, Kota Mandi');
      expect(snapshot['unloadingLocationId'], 'wh-unload');
      expect(snapshot['loadingLocationId'], 'wh-load');
      expect(snapshot['loadingLocationSnapshot'], contains('Kota Godown'));

      final commit = fake.writesTo('requirement_allocations').single;
      expect((commit.body as Map)['status'], 'COMMITTED_TO_DEAL');
      expect((commit.body as Map)['deal_id'], deal.id);
    });

    test('reuses the existing quotation for the same requirement and lot', () async {
      fake = await FakePostgrest.start({
        'requirement_allocations': [allocationRow()],
        'quotations': [
          {
            'id': 'q-existing',
            'requirement_id': reqId,
            'seller_availability_id': lotId,
            'broker_id': broker,
            'created_at': '2026-10-24',
          },
        ],
        'deals': [],
        'deal_versions': [],
      });

      await _Repo(fake).createDealFromAllocation(dealDto());

      expect(fake.writesTo('quotations'), isEmpty);
      expect((fake.writesTo('deals').single.body as Map)['quotation_id'], 'q-existing');
    });

    test('an allocation already committed to a deal returns that deal and writes nothing', () async {
      fake = await FakePostgrest.start({
        'requirement_allocations': [allocationRow(status: 'COMMITTED_TO_DEAL', deal: dealId)],
        'deals': [dealRow()],
        'deal_versions': [versionRow()],
      });

      final result = await _Repo(fake).createDealFromAllocation(dealDto());

      expect((result as DealSuccess<DealItem>).data.id, dealId);
      expect(fake.writes(), isEmpty);
    });

    test('refuses an allocation that is not confirmed', () async {
      fake = await FakePostgrest.start({
        'requirement_allocations': [allocationRow(status: 'PROPOSED')],
      });

      final result = await _Repo(fake).createDealFromAllocation(dealDto());

      expect((result as DealError).message, contains('must be confirmed'));
      expect(fake.writes(), isEmpty);
    });
  });

  group('Party confirmations and finalization', () {
    PartyConfirmationDto confirm(String party, {int version = 1}) =>
        PartyConfirmationDto(dealId: dealId, versionNumber: version, party: party);

    test('buyer then seller confirmation moves the deal to Ready to Finalize, never editing versions', () async {
      fake = await FakePostgrest.start({
        'deals': [dealRow()],
        'deal_versions': [versionRow()],
      });
      final repo = _Repo(fake);

      final buyer = await repo.recordPartyConfirmation(confirm('BUYER'));
      expect((buyer as DealSuccess<DealConfirmationState>).data.buyerConfirmed, isTrue);
      expect(fake.tables['deals']!.single['status'], 'Awaiting Seller Confirmation');

      final seller = await repo.recordPartyConfirmation(confirm('SELLER'));
      expect((seller as DealSuccess<DealConfirmationState>).data.canFinalize, isTrue);
      expect(fake.tables['deals']!.single['status'], 'Ready to Finalize');

      expect(fake.writesTo('deal_versions'), isEmpty);
      // Compare-and-set on the status read before the write.
      expect(fake.writesTo('deals').first.filter('status'), 'eq.Draft');
    });

    test('a repeated confirmation for the same party writes nothing', () async {
      fake = await FakePostgrest.start({
        'deals': [dealRow(status: 'Awaiting Seller Confirmation')],
        'deal_versions': [versionRow()],
      });

      final result = await _Repo(fake).recordPartyConfirmation(confirm('BUYER'));

      expect((result as DealSuccess<DealConfirmationState>).data.buyerConfirmed, isTrue);
      expect(fake.writes(), isEmpty);
    });

    test('a confirmation against a superseded version is rejected', () async {
      fake = await FakePostgrest.start({
        'deals': [dealRow(status: 'Negotiation')],
        'deal_versions': [versionRow(number: 2, status: 'Negotiation')],
      });

      final result = await _Repo(fake).recordPartyConfirmation(confirm('BUYER', version: 1));

      expect((result as DealError).code, 'STALE_VERSION_DETECTED');
      expect(fake.writes(), isEmpty);
    });

    test('closed deals take no confirmation', () async {
      fake = await FakePostgrest.start({
        'deals': [dealRow(status: 'Finalized')],
        'deal_versions': [versionRow()],
      });

      final result = await _Repo(fake).recordPartyConfirmation(confirm('SELLER'));

      expect(result, isA<DealError<DealConfirmationState>>());
      expect(fake.writes(), isEmpty);
    });

    test('finalize issues one booking locked to the latest version and closes the deal', () async {
      fake = await FakePostgrest.start({
        'deals': [dealRow(status: 'Ready to Finalize')],
        'deal_versions': [versionRow()],
        'bookings': [],
        'quotations': [
          {'id': 'q-1', 'status': 'Accepted'},
        ],
      });

      final result = await _Repo(fake).finalizeDeal(dealId, 1);

      final ref = (result as DealSuccess<String>).data;
      expect(ref, startsWith('BKG-'));
      final booking = fake.writesTo('bookings').single.body as Map;
      expect(booking['locked_version_id'], versionId);
      expect(booking.containsKey('broker_id'), isFalse);
      expect(fake.tables['deals']!.single['status'], 'Finalized');
      expect(fake.tables['deals']!.single['closed_at'], isNotNull);
      expect(fake.tables['quotations']!.single['status'], 'Broker Finalized');
    });

    test('finalize is blocked until both parties confirmed', () async {
      fake = await FakePostgrest.start({
        'deals': [dealRow(status: 'Awaiting Seller Confirmation')],
        'deal_versions': [versionRow()],
      });

      final result = await _Repo(fake).finalizeDeal(dealId, 1);

      expect((result as DealError).code, 'PRE_FLIGHT_BLOCKED');
      expect(fake.writes(), isEmpty);
    });

    test('a duplicate finalize reuses the existing booking (unique deal_id)', () async {
      fake = await FakePostgrest.start({
        'deals': [dealRow(status: 'Ready to Finalize')],
        'deal_versions': [versionRow()],
        'bookings': [
          {'id': 'bk-1', 'deal_id': dealId, 'booking_reference': 'BKG-2026-000111'},
        ],
      });
      fake.failWith = (r) => r.method == 'POST' && r.table == 'bookings'
          ? (
              409,
              {'code': '23505', 'message': 'duplicate key value violates unique constraint "bookings_deal_id_unique"'},
            )
          : null;

      final result = await _Repo(fake).finalizeDeal(dealId, 1);

      expect((result as DealSuccess<String>).data, 'BKG-2026-000111');
      expect(fake.tables['bookings'], hasLength(1));
      expect(fake.tables['deals']!.single['status'], 'Finalized');
    });

    test('finalizing an already finalized deal returns its booking without writes', () async {
      fake = await FakePostgrest.start({
        'deals': [dealRow(status: 'Finalized')],
        'deal_versions': [versionRow()],
        'bookings': [
          {'id': 'bk-1', 'deal_id': dealId, 'booking_reference': 'BKG-2026-000111'},
        ],
      });

      final result = await _Repo(fake).finalizeDeal(dealId, 1);

      expect((result as DealSuccess<String>).data, 'BKG-2026-000111');
      expect(fake.writes(), isEmpty);
    });
  });

  group('Cancellation, terms and reads', () {
    test('cancel closes the deal, releases its allocation and restores both balances', () async {
      fake = await FakePostgrest.start({
        'deals': [dealRow(status: 'Negotiation')],
        'requirements': [requirementRow(fulfilled: 35)],
        'availabilities': [
          {...lotRow(available: 5), 'reserved_quantity': 35},
        ],
        'requirement_allocations': [
          {
            'id': allocId,
            'requirement_id': reqId,
            'availability_id': lotId,
            'allocated_quantity': 35,
            'status': 'COMMITTED_TO_DEAL',
            'confirmed_at': '2026-10-25T09:00:00Z',
            'deal_id': dealId,
            'master_units': {'symbol': 'MT'},
            'availabilities': {
              'master_units': {'symbol': 'MT'},
            },
          },
        ],
      });

      final result = await _Repo(fake).cancelDeal(dealId, 'Buyer withdrew');

      expect((result as DealSuccess<bool>).data, isTrue);
      expect(fake.tables['deals']!.single['status'], 'Cancelled');
      expect(fake.tables['deals']!.single['closed_at'], isNotNull);
      expect(fake.tables['requirement_allocations']!.single['status'], 'RELEASED');
      expect(fake.tables['availabilities']!.single['available_quantity'], 40);
      expect(fake.tables['availabilities']!.single['reserved_quantity'], 0);
      expect(fake.tables['requirements']!.single['fulfilled_quantity'], 0);
    });

    test('a finalized deal cannot be cancelled', () async {
      fake = await FakePostgrest.start({
        'deals': [dealRow(status: 'Finalized')],
      });

      final result = await _Repo(fake).cancelDeal(dealId, 'Buyer withdrew');

      expect(result, isA<DealError<bool>>());
      expect(fake.writes(), isEmpty);
    });

    test('terms amendment inserts a new version (reason in the snapshot) and resets the deal to Negotiation', () async {
      fake = await FakePostgrest.start({
        'deals': [dealRow(status: 'Awaiting Seller Confirmation')],
        'deal_versions': [
          versionRow(
            snapshot: {'agreedPrice': 28000.0, 'agreedQuantity': 35.0, 'requirementId': reqId, 'allocationId': allocId},
          ),
        ],
      });

      final result = await _Repo(fake).updateDealTerms(
        UpdateDealTermsDto(
          dealId: dealId,
          expectedVersion: 1,
          agreedPrice: 27500,
          agreedQuantity: 35,
          priceBasis: 'FOR_DESTINATION',
          deliveryLocation: 'Kota',
          deliveryDate: DateTime(2026, 11, 8),
          reason: 'Buyer counter',
        ),
      );

      expect(result, isA<DealSuccess<DealDetailItem>>());
      final insert = fake.writesTo('deal_versions').single;
      expect(insert.method, 'POST');
      final body = insert.body as Map;
      expect(body.containsKey('change_reason'), isFalse);
      expect(body['version_number'], 2);
      expect((body['snapshot_payload'] as Map)['changeReason'], 'Buyer counter');
      expect((body['snapshot_payload'] as Map)['requirementId'], reqId);
      expect(fake.tables['deals']!.single['status'], 'Negotiation');
      // Confirmations of v1 no longer count.
      final detail = (result as DealSuccess<DealDetailItem>).data;
      expect(detail.confirmations.buyerConfirmed, isFalse);
    });

    test('allocation list and version history only select existing columns', () async {
      fake = await FakePostgrest.start({'requirement_allocations': [], 'deal_versions': []});
      final repo = _Repo(fake);

      await repo.getAllocationsForRequirement(reqId);
      await repo.getDealVersionHistory(dealId);

      final allocSelect = fake.requests[0].query['select']!;
      expect(allocSelect, isNot(contains('seller_id')));
      expect(allocSelect, contains('company_id'));
      expect(fake.requests[1].query['select'], isNot(contains('change_reason')));
    });

    test('deal detail reads confirmations from the deal status and reports a missing deal', () async {
      fake = await FakePostgrest.start({
        'deals': [dealRow(status: 'Awaiting Buyer Confirmation')],
        'deal_versions': [
          versionRow(snapshot: {'paymentTerms': '50% advance', 'deliveryLocation': 'Kota'}),
        ],
      });
      final repo = _Repo(fake);

      final detail = (await repo.getDealDetail(dealId) as DealSuccess<DealDetailItem>).data;
      expect(detail.confirmations.sellerConfirmed, isTrue);
      expect(detail.confirmations.buyerConfirmed, isFalse);
      expect(detail.paymentTerms, '50% advance');

      final missing = await repo.getDealDetail('e0000000-0000-4000-8000-0000000000ff');
      expect((missing as DealError).code, 'NOT_FOUND');

      // The former demo fallback answered any id containing "0042" with a fake deal.
      final demo = await repo.getDealDetail('deal-bkg-0042');
      expect(demo, isNot(isA<DealSuccess<DealDetailItem>>()));
    });
  });
}
