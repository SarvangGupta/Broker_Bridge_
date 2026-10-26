import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/app/router/app_router.dart';
import 'package:rmbroker_mobile/features/deals/data/deal_repository.dart';
import 'package:rmbroker_mobile/features/deals/domain/allocation_model.dart';
import 'package:rmbroker_mobile/features/deals/domain/deal_model.dart';
import 'package:rmbroker_mobile/features/deals/presentation/controllers/deals_controller.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:rmbroker_mobile/features/work/domain/offer_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_negotiation_model.dart';
import 'package:rmbroker_mobile/features/work/presentation/controllers/requirements_controller.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/negotiate_requirement_sheet.dart';

// RB-REQUIREMENT-DETAILS-UI-REDESIGN-01. Fakes only.

const varun = 'b354958e-779a-41f2-b7a3-5899eca32e32';
const reqId = '43728b98-5f80-4010-bf18-51cd06439c06';

const sections = ['quantity', 'price', 'activity', 'seller', 'buyer', 'documents', 'audit'];

RequirementItem req({double fulfilled = 0, String? buyer}) => RequirementItem.fromJson({
      'id': reqId,
      'requirement_ref': '#REQ-43728B',
      'company_id': 'rohan-co',
      'buyer_company_name': buyer ?? 'Rohan Gupta Pvt. Ltd.',
      'buyer_company_verified': true,
      'buyer_trust_score': 100,
      'commodity_id': 'dorb',
      'commodity_name': 'De-oiled Rice Bran (DORB)',
      'grade_id': 'g',
      'grade_name': 'FAQ (Fair Average Quality)',
      'unit_id': 'mt',
      'unit_symbol': 'MT',
      'broker_id': varun,
      'quantity': 100,
      'fulfilled_quantity': fulfilled,
      'target_price': 21000,
      'delivery_terms_id': 'FOR Mill Delivery, Kota Mandi',
      'target_date': DateTime.now().add(const Duration(days: 13)).toIso8601String(),
      'status': 'Proposed to Buyer',
      'created_at': '2026-10-25T01:22:00.000',
    });

class FakeWork extends WorkRepository {
  RequirementItem item;
  final List<NegotiationRoundItem> rounds;
  int detailCalls = 0;
  int negotiationCalls = 0;
  FakeWork(this.item, {this.rounds = const []});

  @override
  String? activeBrokerId() => varun;

  @override
  Future<WorkDataResult<List<RequirementItem>>> getRequirements() async => WorkSuccess([item]);

  @override
  Future<WorkDataResult<List<OfferItem>>> getOffers() async => const WorkSuccess([]);

  @override
  Future<WorkDataResult<RequirementItem>> getRequirementById(String requirementId) async {
    detailCalls++;
    return WorkSuccess(item);
  }

  @override
  Future<WorkDataResult<RequirementNegotiationData>> getRequirementNegotiationDetails(String requirementId) async {
    negotiationCalls++;
    return WorkSuccess(RequirementNegotiationData(
      requirementId: requirementId,
      currentVersionNumber: rounds.length,
      currentStatus: 'Proposed to Buyer',
      offeredPrice: 21050,
      proposedQuantity: 100,
      rounds: rounds,
    ));
  }
}

class FakeDeals extends DealRepository {
  @override
  Future<DealDataResult<List<DealItem>>> getDeals({DealStatus? statusFilter, String? search}) async =>
      const DealSuccess([]);

  @override
  Future<DealDataResult<List<AllocationItem>>> getAllocationsForRequirement(String requirementId) async =>
      const DealSuccess([]);
}

NegotiationRoundItem round(int v, DateTime at, double rate) => NegotiationRoundItem(
      id: 'r$v',
      versionNumber: v,
      status: 'Proposed to Buyer',
      actorRole: 'broker',
      actorName: 'Broker Desk Proposal',
      rate: rate,
      quantity: 100,
      createdAt: at,
    );

void main() {
  Future<FakeWork> pump(WidgetTester tester, FakeWork work, {Size size = const Size(1080, 2340), double dpr = 2.75}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    final router = AppRouter.router;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        workRepositoryProvider.overrideWithValue(work),
        dealRepositoryProvider.overrideWithValue(FakeDeals()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    router.go('/requirements/$reqId');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    // The shared router's first use builds the splash route, whose delay timer
    // must elapse before the test ends.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    return work;
  }

  Finder header(String s) => find.byKey(ValueKey('req_section_$s'));
  Finder body(String s) => find.byKey(ValueKey('req_section_body_$s'));

  Future<void> toggle(WidgetTester tester, String s) async {
    await tester.ensureVisible(header(s));
    await tester.tap(header(s));
    await tester.pumpAndSettle();
  }

  testWidgets('loads the requirement; header and summary; all seven sections collapsed with summaries', (tester) async {
    await pump(tester, FakeWork(req()));
    expect(find.text('Requirement Details'), findsOneWidget);
    expect(find.text('#REQ-43728B'), findsOneWidget);
    expect(find.text('Created 25 Oct 2026, 01:22 AM'), findsOneWidget);
    expect(find.text('De-oiled Rice Bran (DORB)'), findsOneWidget);
    expect(find.text('Grade: FAQ (Fair Average Quality)'), findsOneWidget);
    expect(find.text('100% Trust'), findsOneWidget);

    for (final (s, title) in [
      ('quantity', 'Quantity Breakdown'),
      ('price', 'Price & Delivery'),
      ('activity', 'Activity History'),
      ('seller', 'Seller Allocation & Deals'),
      ('buyer', 'Buyer Details'),
      ('documents', 'Documents'),
      ('audit', 'Audit Details'),
    ]) {
      expect(find.descendant(of: header(s), matching: find.text(title)), findsOneWidget, reason: s);
      expect(body(s), findsNothing, reason: '$s collapsed on entry');
    }
    expect(find.text('Requested: 100 MT  |  Fulfilled: 0%'), findsOneWidget);
    expect(find.text('No seller allocated yet'), findsOneWidget);
    expect(find.text('Not available yet'), findsOneWidget, reason: 'no document source; no fake count');
    expect(find.text('Created: 25 Oct 2026'), findsOneWidget);
  });

  testWidgets('each section toggles independently, with no extra loads', (tester) async {
    final work = await pump(tester, FakeWork(req()));
    final detailCalls = work.detailCalls;
    final negotiationCalls = work.negotiationCalls;
    for (final s in sections) {
      await toggle(tester, s);
      expect(body(s), findsOneWidget, reason: '$s opens');
      for (final other in sections.where((o) => o != s && sections.indexOf(o) > sections.indexOf(s))) {
        expect(body(other), findsNothing, reason: '$other untouched by $s');
      }
    }
    await toggle(tester, 'quantity');
    expect(body('quantity'), findsNothing);
    expect(body('price'), findsOneWidget, reason: 'others stay open');
    expect(work.detailCalls, detailCalls);
    expect(work.negotiationCalls, negotiationCalls);
  });

  testWidgets('quantity and price sections show the existing values', (tester) async {
    await pump(tester, FakeWork(req(fulfilled: 25)));
    await toggle(tester, 'quantity');
    expect(find.text('25% Fulfilled'), findsOneWidget);
    expect(find.text('100 MT'), findsWidgets);
    expect(find.descendant(of: body('quantity'), matching: find.text('75 MT')), findsOneWidget, reason: 'remaining');

    await toggle(tester, 'price');
    expect(find.descendant(of: body('price'), matching: find.text('₹21,000 / MT')), findsOneWidget);
    expect(find.text('FOR Mill Delivery, Kota Mandi'), findsOneWidget);
  });

  testWidgets('Activity History lists only recorded events, newest first', (tester) async {
    final work = FakeWork(req(), rounds: [
      round(1, DateTime(2026, 10, 25, 1, 25), 21050),
      round(2, DateTime(2026, 10, 26, 9, 10), 21025),
    ]);
    await pump(tester, work);
    expect(find.text('Latest: Proposal v2 sent to buyer (26 Oct 2026)'), findsOneWidget);
    await toggle(tester, 'activity');
    expect(find.byKey(const ValueKey('activity_event_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('activity_event_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('activity_event_3')), findsNothing, reason: 'no invented future steps');
    expect(find.text('Requirement Created'), findsOneWidget);
    expect(find.textContaining('Will be updated'), findsNothing);
  });

  testWidgets('Seller section: empty state with Allocate Seller; buyer and audit keep existing data', (tester) async {
    await pump(tester, FakeWork(req()));
    await toggle(tester, 'seller');
    expect(find.text('No seller lot has been allocated to this requirement yet.'), findsOneWidget);
    expect(find.byKey(const ValueKey('allocate_seller_button')), findsOneWidget);

    await toggle(tester, 'buyer');
    expect(find.descendant(of: body('buyer'), matching: find.text('Verified')), findsOneWidget);
    await toggle(tester, 'audit');
    expect(find.descendant(of: body('audit'), matching: find.text('Your broker desk')), findsOneWidget);
    expect(find.textContaining(varun), findsNothing, reason: 'raw broker id not shown');
  });

  testWidgets('bottom actions stay available outside the scroll and keep their workflows', (tester) async {
    // The existing proposal sheet is laid out for the 800dp surface its own tests use.
    await pump(tester, FakeWork(req()), size: const Size(800, 1600), dpr: 1.0);
    final bar = find.byKey(const ValueKey('req_action_proposal'));
    expect(bar, findsOneWidget);
    expect(find.text('View / Amend Proposal'), findsOneWidget);
    expect(find.byKey(const ValueKey('req_action_cancel')), findsOneWidget);
    expect(find.byKey(const ValueKey('req_action_matches')), findsOneWidget);

    // Last section remains reachable above the bar.
    await tester.ensureVisible(header('audit'));
    await tester.pumpAndSettle();
    final auditBottom = tester.getBottomLeft(header('audit')).dy;
    final barTop = tester.getTopLeft(find.byKey(const ValueKey('req_action_cancel'))).dy;
    expect(auditBottom, lessThanOrEqualTo(barTop), reason: 'content not hidden behind actions');

    await tester.tap(find.byKey(const ValueKey('req_action_cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Cancel Requirement Mandate'), findsOneWidget);
    await tester.tap(find.text('Keep Active'));
    await tester.pumpAndSettle();

    await tester.tap(bar);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NegotiateRequirementSheet), findsOneWidget);
  });

  testWidgets('small 320dp screen with long names: no overflow, all sections opened', (tester) async {
    await pump(
      tester,
      FakeWork(req(buyer: 'RBTEST Very Long Integrated Agro Commodities Processing & Trading Private Limited')),
      size: const Size(640, 1136),
      dpr: 2.0,
    );
    expect(tester.takeException(), isNull);
    for (final s in sections) {
      await toggle(tester, s);
    }
    expect(tester.takeException(), isNull);
  });
}
