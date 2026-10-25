import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/network/api_client.dart';
import 'package:rmbroker_mobile/features/deals/domain/deal_model.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_category.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_model.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:rmbroker_mobile/features/work/domain/offer_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';
import 'package:rmbroker_mobile/features/work/domain/unit_utils.dart';

import '../../support/fake_postgrest.dart';
import '../directory/directory_repository_test.dart' show MockSecureStorageService;

// Plain test() only: the PostgREST group needs a real loopback HttpClient.

const reqUuid = '107df7a3-8693-42b2-9893-6a4610abad14';

/// The REQUIREMENT_CREATED row written by notify_requirement_brokers (live shape).
Map<String, dynamic> liveRequirementNotification() => {
  'id': '9b02ec34-38e1-4efe-a494-9b55ad7fb485',
  'user_id': 'b354958e-779a-41f2-b7a3-5899eca32e32',
  'event_type': 'REQUIREMENT_CREATED',
  'title': 'New Procurement Requirement: Maize DDGS',
  'message': 'Buyer posted requirement for 35 MT of Maize DDGS.',
  'context_reason': 'Direct mandate notification from verified buyer',
  'action_label': 'Inspect Requirement',
  'action_url': '/work?tab=0',
  'payload': {
    'unit': 'MT',
    'quantity': 35,
    'commodity': 'Maize DDGS',
    'targetPrice': 28000,
    'requirementId': reqUuid,
    'deliveryLocation': 'FOR Mill Delivery, Kota Mandi',
  },
  'is_read': false,
  'created_at': '2026-10-25T08:01:09.117Z',
};

Map<String, dynamic> requirementJson({
  String status = 'Open',
  double quantity = 35,
  double fulfilled = 0,
  String commodityId = 'maize-ddgs',
}) => {
  'id': reqUuid,
  'company_id': 'buyer-co',
  'commodity_id': commodityId,
  'commodity_name': 'Maize DDGS',
  'grade_id': 'grade-good',
  'grade_name': 'Good',
  'unit_id': 'unit-mt',
  'unit_symbol': 'MT',
  'broker_id': 'varun',
  'quantity': quantity,
  'fulfilled_quantity': fulfilled,
  'target_price': 28000,
  'delivery_terms_id': 'FOR Mill Delivery, Kota Mandi',
  'target_date': DateTime.now().add(const Duration(days: 14)).toIso8601String(),
  'status': status,
  'created_at': '2026-10-25T02:31:08.690',
};

Map<String, dynamic> offerJson(String id, {String commodityId = 'maize-ddgs', String name = 'Maize DDGS'}) => {
  'id': id,
  'lot_number': 'LOT-$id',
  'company_id': 'seller-co',
  'seller_company_name': 'Seller Co',
  'commodity_id': commodityId,
  'commodity_name': name,
  'grade_id': 'grade-good',
  'grade_name': 'Good',
  'unit_id': 'unit-mt',
  'unit_symbol': 'MT',
  'total_quantity': 40,
  'available_quantity': 40,
  'asking_price': 27500,
  'state_name': 'Rajasthan',
  'district_name': 'Kota',
  'available_from': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
  'valid_until': DateTime.now().add(const Duration(days: 20)).toIso8601String(),
  'status': 'Open',
  'created_at': '2026-10-20T00:00:00.000',
};

void main() {
  group('Notification payload → record routing', () {
    test('the live REQUIREMENT_CREATED row opens that requirement, not the generic Work list', () {
      final n = BrokerNotification.fromJson(liveRequirementNotification());

      expect(n.category, NotificationCategory.requirementsAndOffers);
      expect(n.requirementId, reqUuid);
      expect(n.resolvedRoute, '/requirements/$reqUuid');
      expect(n.isActionable, isTrue);
    });

    test('formats reference, quantity, price and delivery from the payload', () {
      final n = BrokerNotification.fromJson(liveRequirementNotification());
      expect(n.detailLine, '#REQ-107DF7 · 35 MT · ₹28,000/MT · FOR Mill Delivery, Kota Mandi');
    });

    test('a broker DEAL_VERSION_UPDATE with a Buyer URL still opens the requirement', () {
      final n = BrokerNotification.fromJson({
        'id': 'n2',
        'event_type': 'DEAL_VERSION_UPDATE',
        'title': 'Commercial Proposal: Dal',
        'message': 'Broker submitted landed proposal (v1) for Requirement #f6e202aa.',
        'action_url': '/buyer/requirements',
        'payload': {'url': '/buyer/requirements', 'requirementId': 'f6e202aa-c5a1-49a5-bb74-97d3af532c5a'},
      });
      expect(n.resolvedRoute, '/requirements/f6e202aa-c5a1-49a5-bb74-97d3af532c5a');
    });

    test('deal and offer references open their own sections', () {
      final deal = BrokerNotification.fromJson({
        'id': 'n3',
        'event_type': 'BOOKING_CREATED',
        'title': 'Deal Finalized',
        'action_url': '/broker/deals/90000000-0000-0000-0000-000000000005',
      });
      expect(deal.resolvedRoute, '/deals/90000000-0000-0000-0000-000000000005');

      final offer = BrokerNotification.fromJson({
        'id': 'n4',
        'event_type': 'AVAILABILITY_APPROVED',
        'title': 'Seller lot approved',
        'action_url': '/seller',
        'payload': {'availabilityId': '50000000-0000-0000-0000-000000000202'},
      });
      expect(offer.resolvedRoute, '/work?tab=1&offerId=50000000-0000-0000-0000-000000000202');
    });

    test('a deal id wins over a requirement id on the same event', () {
      final n = BrokerNotification.fromJson({
        'id': 'n5',
        'event_type': 'DEAL_VERSION_UPDATE',
        'title': 'Deal draft',
        'payload': {'dealId': 'deal-1', 'requirementId': reqUuid},
      });
      expect(n.resolvedRoute, '/deals/deal-1');
    });

    test('unsafe ids are ignored and fall back to the section', () {
      final n = BrokerNotification.fromJson({
        'id': 'n6',
        'event_type': 'REQUIREMENT_CREATED',
        'title': 'x',
        'action_url': '/work?tab=0',
        'payload': {'requirementId': '../../etc/passwd'},
      });
      expect(n.requirementId, isNull);
      expect(n.resolvedRoute, '/work?tab=0');
    });
  });

  group('Requirement status shown by remaining quantity', () {
    test('live "Allocated" is a closed, non-matchable state', () {
      final r = RequirementItem.fromJson(requirementJson(status: 'Allocated'));
      expect(r.status, RequirementStatus.fullyAllocated);
      expect(r.canBeMatched, isFalse);
    });

    test('an Open row with partial allocations is Partially Allocated and still matchable', () {
      final r = RequirementItem.fromJson(requirementJson(fulfilled: 10));
      expect(r.status, RequirementStatus.partiallyAllocated);
      expect(r.remainingQuantity, 25);
      expect(r.fulfillmentPercentage, 29);
      expect(r.canBeMatched, isTrue);
    });

    test('an Open row with nothing remaining is Fully Allocated', () {
      final r = RequirementItem.fromJson(requirementJson(fulfilled: 35));
      expect(r.status, RequirementStatus.fullyAllocated);
      expect(r.canBeMatched, isFalse);
    });
  });

  group('Matching', () {
    test('lots of another product are never offered as matches (web hard filter)', () {
      final req = RequirementItem.fromJson(requirementJson());
      final matches = WorkRepository().computeMatches(
        requirement: req,
        availableOffers: [
          OfferItem.fromJson(offerJson('lot-maize')),
          OfferItem.fromJson(offerJson('lot-wheat', commodityId: 'wheat', name: 'Sharbati Wheat')),
        ],
      );
      expect(matches.map((m) => m.offer.id), ['lot-maize']);
    });

    test('a closed requirement yields no matches', () {
      final req = RequirementItem.fromJson(requirementJson(status: 'Cancelled'));
      final matches = WorkRepository().computeMatches(
        requirement: req,
        availableOffers: [OfferItem.fromJson(offerJson('lot-maize'))],
      );
      expect(matches, isEmpty);
    });
  });

  group('Units and confirmations', () {
    test('convertBetween converts known units and refuses unknown ones', () {
      expect(UnitUtils.convertBetween(70, 'kg', 'MT'), closeTo(0.07, 1e-12));
      expect(UnitUtils.convertBetween(2, 'MT', 'Qtl'), 20);
      expect(UnitUtils.convertBetween(5, 'Bags', 'Bags'), 5);
      expect(UnitUtils.convertBetween(5, 'Bags', 'MT'), isNull);
    });

    test('confirmation progress is read from deal status, version status or snapshot', () {
      expect(DealVersionConfirmation.fromRecords(dealStatus: 'Awaiting Seller Confirmation').buyerConfirmed, isTrue);
      expect(DealVersionConfirmation.fromRecords(dealStatus: 'Awaiting Buyer Confirmation').sellerConfirmed, isTrue);
      expect(DealVersionConfirmation.fromRecords(dealStatus: 'Ready to Finalize').isComplete, isTrue);
      expect(DealVersionConfirmation.fromRecords(versionStatus: 'Confirmed').isComplete, isTrue);
      expect(DealVersionConfirmation.fromRecords(versionStatus: 'Seller Confirmed').sellerConfirmed, isTrue);
      expect(DealVersionConfirmation.fromRecords(snapshot: {'buyerConfirmed': true}).buyerConfirmed, isTrue);
      final none = DealVersionConfirmation.fromRecords(dealStatus: 'Negotiation', versionStatus: 'Negotiation');
      expect(none.buyerConfirmed || none.sellerConfirmed, isFalse);
      expect(none.withParty('BUYER').dealStatus, 'Awaiting Seller Confirmation');
      expect(none.withParty('BUYER').withParty('SELLER').dealStatus, 'Ready to Finalize');
    });
  });

  group('WorkRepository.getRequirementById (fake PostgREST)', () {
    late FakePostgrest fake;
    tearDown(() => fake.close());

    WorkRepository repo() {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (o, h) => h.reject(DioException(requestOptions: o, type: DioExceptionType.connectionError)),
          ),
        );
      return _SessionWorkRepository(
        apiClient: ApiClient(storage: MockSecureStorageService(), customDio: dio),
        supabase: fake.client,
      );
    }

    test('loads the row by id without the broker filter, with its masters', () async {
      fake = await FakePostgrest.start({
        'requirements': [
          {
            ...requirementJson(),
            'companies': {'id': 'buyer-co', 'name': 'Rohan Feeds', 'is_verified': true, 'trust_score': 80},
            'master_commodities': {'id': 'maize-ddgs', 'name': 'Maize DDGS', 'code': 'MDDGS'},
            'master_grades': {'id': 'grade-good', 'grade_name': 'Good', 'parameters': null},
            'master_units': {'id': 'unit-mt', 'name': 'Metric Ton', 'symbol': 'MT'},
          },
        ],
      });

      final result = await repo().getRequirementById(reqUuid);

      final r = (result as WorkSuccess<RequirementItem>).data;
      expect(r.buyerCompanyName, 'Rohan Feeds');
      expect(r.brokerId, 'varun');
      final q = fake.requests.single.query;
      expect(q['id'], 'eq.$reqUuid');
      expect(q.containsKey('broker_id'), isFalse);
    });

    test('assigned requirements whose buyer company is RLS-hidden are still listed (KI-46)', () async {
      // Live: Varun sees 15 assigned requirements but only 5 buyer companies (CRM contacts).
      fake = await FakePostgrest.start({
        'requirements': [
          {
            ...requirementJson(),
            'companies': null,
            'master_commodities': {'id': 'maize-ddgs', 'name': 'Maize DDGS', 'code': null},
            'master_grades': {'id': 'grade-good', 'grade_name': 'Good', 'parameters': null},
            'master_units': {'id': 'unit-mt', 'name': 'Metric Ton', 'symbol': 'MT'},
          },
        ],
      });

      final result = await repo().getRequirements();

      final items = (result as WorkSuccess<List<RequirementItem>>).data;
      expect(items.single.id, reqUuid);
      expect(items.single.buyerCompanyName, WorkRepository.restrictedBuyerLabel);
      expect(items.single.isBuyerVerified, isFalse);
      final select = fake.requests.single.query['select']!;
      expect(select, isNot(contains('companies!inner')));
      expect(fake.requests.single.query['broker_id'], 'eq.varun');
    });

    test('a deleted or hidden row is NOT_FOUND; a malformed id never queries', () async {
      fake = await FakePostgrest.start({'requirements': []});

      final missing = await repo().getRequirementById(reqUuid);
      expect((missing as WorkError).code, 'NOT_FOUND');

      final malformed = await repo().getRequirementById('REQ-123');
      expect((malformed as WorkError).code, 'NOT_FOUND');
      expect(fake.requests, hasLength(1));
    });
  });
}

class _SessionWorkRepository extends WorkRepository {
  _SessionWorkRepository({super.apiClient, super.supabase}) : super(storage: MockSecureStorageService());

  @override
  String? activeBrokerId() => 'varun';
}
