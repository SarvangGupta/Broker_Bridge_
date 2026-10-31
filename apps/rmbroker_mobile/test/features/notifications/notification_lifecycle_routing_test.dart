import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/app/router/app_router.dart';
import 'package:rmbroker_mobile/features/deals/data/deal_repository.dart';
import 'package:rmbroker_mobile/features/deals/domain/allocation_model.dart';
import 'package:rmbroker_mobile/features/deals/domain/deal_model.dart';
import 'package:rmbroker_mobile/features/deals/presentation/controllers/deals_controller.dart';
import 'package:rmbroker_mobile/features/deals/presentation/screens/deal_detail_screen.dart';
import 'package:rmbroker_mobile/features/notifications/data/notification_repository.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_category.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_model.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_negotiation_model.dart';
import 'package:rmbroker_mobile/features/work/domain/offer_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';
import 'package:rmbroker_mobile/features/work/presentation/controllers/matches_controller.dart';
import 'package:rmbroker_mobile/features/work/presentation/controllers/requirements_controller.dart';
import 'package:rmbroker_mobile/features/work/presentation/screens/requirement_detail_screen.dart';
import 'package:rmbroker_mobile/features/work/presentation/work_screen.dart';

// Scenario: Rohan (buyer) posts a Maize DDGS requirement and assigns Varun
// (broker); Varun works it from the notification to a deal. Fakes only — no
// production data is read or written.

const varun = 'b354958e-779a-41f2-b7a3-5899eca32e32';
const otherBroker = 'b0000000-0000-4000-8000-000000000009';
const reqId = '107df7a3-8693-42b2-9893-6a4610abad14';
const dealId = '90000000-0000-4000-8000-0000000000aa';

RequirementItem requirement({String? brokerId = varun, String status = 'Open'}) => RequirementItem.fromJson({
  'id': reqId,
  'company_id': 'rohan-co',
  'buyer_company_name': 'Rohan Feeds',
  'commodity_id': 'maize-ddgs',
  'commodity_name': 'Maize DDGS',
  'grade_id': 'grade-good',
  'grade_name': 'Good',
  'unit_id': 'unit-mt',
  'unit_symbol': 'MT',
  'broker_id': brokerId,
  'quantity': 35,
  'fulfilled_quantity': 0,
  'target_price': 28000,
  'delivery_terms_id': 'FOR Mill Delivery, Kota Mandi',
  'target_date': DateTime.now().add(const Duration(days: 14)).toIso8601String(),
  'status': status,
  'created_at': '2026-10-25T02:31:08.690',
});

OfferItem offer(String id, {String commodityId = 'maize-ddgs', String name = 'Maize DDGS'}) => OfferItem.fromJson({
  'id': id,
  'lot_number': 'LOT-$id',
  'seller_company_name': 'Kota Agro Seller',
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
});

BrokerNotification requirementNotification() => BrokerNotification.fromJson({
  'id': '9b02ec34-38e1-4efe-a494-9b55ad7fb485',
  'user_id': varun,
  'event_type': 'REQUIREMENT_CREATED',
  'title': 'New Procurement Requirement: Maize DDGS',
  'message': 'Buyer posted requirement for 35 MT of Maize DDGS.',
  'context_reason': 'Direct mandate notification from verified buyer',
  'action_label': 'Inspect Requirement',
  'action_url': '/work?tab=0',
  'payload': {
    'unit': 'MT',
    'quantity': 35,
    'targetPrice': 28000,
    'requirementId': reqId,
    'deliveryLocation': 'FOR Mill Delivery, Kota Mandi',
  },
  'is_read': false,
  'created_at': DateTime.now().subtract(const Duration(minutes: 3)).toIso8601String(),
});

class FlowNotificationRepository extends NotificationRepository {
  final List<BrokerNotification> items;
  int markReadCalls = 0;
  FlowNotificationRepository(this.items);

  @override
  Future<List<BrokerNotification>> fetchNotifications({NotificationCategory? category, bool? unreadOnly}) async =>
      items;

  @override
  Future<bool> markAsRead(String notificationId) async {
    markReadCalls++;
    return true;
  }
}

class FlowWorkRepository extends WorkRepository {
  @override
  Future<WorkDataResult<RequirementNegotiationData>> getRequirementNegotiationDetails(String requirementId) async =>
      WorkSuccess(RequirementNegotiationData(
        requirementId: requirementId,
        currentVersionNumber: 1,
        currentStatus: 'Open',
        offeredPrice: 0,
        proposedQuantity: 0,
      ));
  final List<RequirementItem> requirements;
  final List<OfferItem> offers;
  final RequirementItem? detail;
  FlowWorkRepository({required this.requirements, required this.offers, required this.detail});

  @override
  String? activeBrokerId() => varun;

  @override
  Future<WorkDataResult<List<RequirementItem>>> getRequirements() async => WorkSuccess(requirements);

  @override
  Future<WorkDataResult<List<OfferItem>>> getOffers() async => WorkSuccess(offers);

  @override
  Future<WorkDataResult<RequirementItem>> getRequirementById(String requirementId) async =>
      detail != null ? WorkSuccess(detail!) : const WorkError(message: 'Requirement not found', code: 'NOT_FOUND');
}

class FlowDealRepository extends DealRepository {
  final bool failFirstDeal;
  final List<DealItem> deals;
  int proposeCalls = 0;
  int createDealCalls = 0;
  FlowDealRepository({this.failFirstDeal = false, List<DealItem>? deals}) : deals = deals ?? [];

  static DealItem deal({String status = 'Draft'}) => DealItem.fromJson({
    'id': dealId,
    'requirement_id': reqId,
    'quotation_id': 'q-1',
    'commodity_name': 'Maize DDGS',
    'buyer_company_name': 'Rohan Feeds',
    'seller_company_name': 'Kota Agro Seller',
    'agreed_price': 27500,
    'agreed_quantity': 35,
    'status': status,
  });

  @override
  Future<DealDataResult<List<DealItem>>> getDeals({DealStatus? statusFilter, String? search}) async =>
      DealSuccess(List.of(deals));

  @override
  Future<DealDataResult<List<AllocationItem>>> getAllocationsForRequirement(String requirementId) async =>
      const DealSuccess([]);

  @override
  Future<DealDataResult<AllocationItem>> proposeAllocation(CreateAllocationDto dto) async {
    proposeCalls++;
    return DealSuccess(
      AllocationItem.fromJson({
        'id': 'alloc-1',
        'allocation_reference': 'ALC-000001',
        'requirement_id': dto.requirementId,
        'availability_id': dto.availabilityId,
        'allocated_quantity': dto.proposedQuantity,
        'unit_symbol': dto.unitSymbol,
        'status': 'CONFIRMED',
      }),
    );
  }

  @override
  Future<DealDataResult<DealItem>> createDealFromAllocation(CreateDealDto dto) async {
    createDealCalls++;
    if (failFirstDeal && createDealCalls == 1) {
      return const DealError(message: 'Network timeout');
    }
    final created = deal();
    deals.add(created);
    return DealSuccess(created);
  }

  @override
  Future<DealDataResult<DealDetailItem>> getDealDetail(String id) async =>
      DealSuccess(DealDetailItem.fromJson({...deal().toJsonForTest(), 'id': id}));

  @override
  Future<DealDataResult<List<DealVersionItem>>> getDealVersionHistory(String id) async => const DealSuccess([]);
}

extension on DealItem {
  Map<String, dynamic> toJsonForTest() => {
    'id': id,
    'requirement_id': requirementId,
    'commodity_name': commodityName,
    'buyer_company_name': buyerCompanyName,
    'seller_company_name': sellerCompanyName,
    'agreed_price': agreedPrice,
    'agreed_quantity': agreedQuantity,
    'status': status.code,
  };
}

void main() {
  late FlowNotificationRepository notifRepo;

  Future<void> pumpApp(
    WidgetTester tester, {
    required FlowWorkRepository work,
    required FlowDealRepository deals,
  }) async {
    // 800 dp wide like the default test surface (the Ahem test font is far wider
    // than real glyphs), and tall enough for the whole detail screen.
    tester.view.physicalSize = const Size(2000, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    notifRepo = FlowNotificationRepository([requirementNotification()]);
    final router = AppRouter.router;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(notifRepo),
          workRepositoryProvider.overrideWithValue(work),
          dealRepositoryProvider.overrideWithValue(deals),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go('/notifications');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  Future<void> openNotification(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('notif_headline_9b02ec34-38e1-4efe-a494-9b55ad7fb485')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  testWidgets('assigned broker: notification → requirement → Match Center → allocation → deal', (tester) async {
    final deals = FlowDealRepository(failFirstDeal: true);
    await pumpApp(
      tester,
      work: FlowWorkRepository(
        requirements: [requirement()],
        offers: [
          offer('lot-maize'),
          offer('lot-wheat', commodityId: 'wheat', name: 'Sharbati Wheat'),
        ],
        detail: requirement(),
      ),
      deals: deals,
    );

    // 1. Readable notification with sender context and record reference.
    // Compact card: type label + commodity; the full message is in Details.
    expect(find.text('New requirement'), findsOneWidget);
    expect(find.text('Maize DDGS'), findsOneWidget);
    expect(find.text('Buyer posted requirement for 35 MT of Maize DDGS.'), findsNothing);
    // Compact metadata and one action; ids and prices stay on the record screen.
    for (final part in ['35 MT', 'Kota Mandi', 'View in Work Desk']) {
      expect(find.text(part), findsOneWidget, reason: part);
    }

    // 2. Tap opens the referenced requirement (not the generic Work list).
    await openNotification(tester);
    final detail = tester.widget<RequirementDetailScreen>(find.byType(RequirementDetailScreen));
    expect(detail.requirementId, reqId);
    expect(notifRepo.markReadCalls, 1);
    // Summary card + Buyer Details summary.
    expect(find.text('Rohan Feeds'), findsNWidgets(2));
    expect(find.text('Requested: 35 MT  |  Fulfilled: 0%'), findsOneWidget);
    expect(find.text('₹28,000 / MT  |  ${requirement().targetDateFormatted}'), findsOneWidget);
    expect(find.text('Not assigned to your desk'), findsNothing);
    expect(find.text('No seller allocated yet'), findsOneWidget);
    // Expanded sections show the existing terms.
    await tester.tap(find.byKey(const ValueKey('req_section_price')));
    await tester.pumpAndSettle();
    expect(find.text('FOR Mill Delivery, Kota Mandi'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('req_section_quantity')));
    await tester.pumpAndSettle();
    expect(find.text('0% Fulfilled'), findsOneWidget);

    // 3. Find Matching Offers selects this requirement in the Match Center.
    await tester.ensureVisible(find.text('Find Matching Offers'));
    await tester.tap(find.text('Find Matching Offers'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byType(WorkScreen), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(WorkScreen)));
    final matches = container.read(matchesProvider);
    expect(matches.selectedRequirement?.id, reqId);
    expect(matches.allMatches.map((m) => m.offer.id), ['lot-maize']); // wheat lot filtered out

    // 4. Allocate the matching lot; the first deal step fails and is retried.
    await tester.ensureVisible(find.text('Allocate Supply to Mandate'));
    await tester.tap(find.text('Allocate Supply to Mandate'));
    await tester.pumpAndSettle();
    expect(find.text('Max Eligible: 35.0 MT'), findsOneWidget);
    await tester.tap(find.text('Review Allocation Summary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Authoritatively Commit'));
    await tester.pumpAndSettle();

    expect(find.text('Retry Deal Creation'), findsOneWidget);
    expect(find.textContaining('Network timeout'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('retry_deal_creation')));
    await tester.pumpAndSettle();

    expect(find.text('Allocation Committed Successfully!'), findsOneWidget);
    expect(deals.proposeCalls, 1, reason: 'a retry must not allocate the lot twice');
    expect(deals.createDealCalls, 2);

    // 5. The new deal opens in the Deals section.
    await tester.tap(find.text('View Deal'));
    await tester.pumpAndSettle();
    expect(tester.widget<DealDetailScreen>(find.byType(DealDetailScreen)).dealId, dealId);
  });

  testWidgets('requirement assigned to another broker is read-only', (tester) async {
    await pumpApp(
      tester,
      work: FlowWorkRepository(
        requirements: [],
        offers: [],
        detail: requirement(brokerId: otherBroker),
      ),
      deals: FlowDealRepository(),
    );

    await openNotification(tester);

    expect(find.byType(RequirementDetailScreen), findsOneWidget);
    expect(find.text('Not assigned to your desk'), findsOneWidget);
    expect(find.text('Find Matching Offers'), findsNothing);
    expect(find.text('Initiate Negotiation & Submit Proposal'), findsNothing);
  });

  testWidgets('a deleted requirement shows a clear not-found state', (tester) async {
    await pumpApp(
      tester,
      work: FlowWorkRepository(requirements: [], offers: [], detail: null),
      deals: FlowDealRepository(),
    );

    await openNotification(tester);

    expect(find.text('Requirement Not Found'), findsOneWidget);
    expect(find.text('Find Matching Offers'), findsNothing);
  });

  testWidgets('a closed requirement is not actionable but keeps its linked deal', (tester) async {
    final deals = FlowDealRepository(deals: [FlowDealRepository.deal(status: 'Finalized')]);
    await pumpApp(
      tester,
      work: FlowWorkRepository(
        requirements: [],
        offers: [],
        detail: requirement(status: 'Cancelled'),
      ),
      deals: deals,
    );

    await openNotification(tester);

    expect(find.text('Requirement closed (Cancelled)'), findsOneWidget);
    expect(find.text('Find Matching Offers'), findsNothing);
    expect(find.text('Cancel Mandate'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('req_section_seller')));
    await tester.tap(find.byKey(const ValueKey('req_section_seller')));
    await tester.pumpAndSettle();
    final linkedDeal = find.byKey(const ValueKey('linked_deal_$dealId'));
    expect(linkedDeal, findsOneWidget);

    await tester.ensureVisible(linkedDeal);
    await tester.tap(linkedDeal);
    await tester.pumpAndSettle();
    expect(find.byType(DealDetailScreen), findsOneWidget);
  });

  testWidgets('a rapid double tap opens the requirement once and marks read once', (tester) async {
    await pumpApp(
      tester,
      work: FlowWorkRepository(requirements: [requirement()], offers: [], detail: requirement()),
      deals: FlowDealRepository(),
    );

    await tester.tap(find.byKey(const ValueKey('notif_headline_9b02ec34-38e1-4efe-a494-9b55ad7fb485')));
    await tester.tap(find.byKey(const ValueKey('notif_headline_9b02ec34-38e1-4efe-a494-9b55ad7fb485')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.byType(RequirementDetailScreen), findsOneWidget);
    expect(notifRepo.markReadCalls, 1);
    final container = ProviderScope.containerOf(tester.element(find.byType(RequirementDetailScreen)));
    expect(container.read(requirementsProvider).requirements.single.id, reqId);
    expect(container.read(notificationControllerProvider).unreadCount, 0);
  });
}
