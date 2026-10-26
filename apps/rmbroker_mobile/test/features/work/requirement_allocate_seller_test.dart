import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/app/router/app_router.dart';
import 'package:rmbroker_mobile/features/deals/data/deal_repository.dart';
import 'package:rmbroker_mobile/features/deals/domain/allocation_model.dart';
import 'package:rmbroker_mobile/features/deals/domain/deal_model.dart';
import 'package:rmbroker_mobile/features/deals/presentation/controllers/deals_controller.dart';
import 'package:rmbroker_mobile/features/deals/presentation/screens/deal_detail_screen.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_negotiation_model.dart';
import 'package:rmbroker_mobile/features/work/domain/offer_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';
import 'package:rmbroker_mobile/features/work/presentation/controllers/requirements_controller.dart';
import 'package:rmbroker_mobile/features/work/presentation/screens/requirement_detail_screen.dart';

// RB-REQ-SELLER-ALLOCATION-FIX-01. Fakes only; no production data.

const varun = 'b354958e-779a-41f2-b7a3-5899eca32e32';
const otherBroker = 'b0000000-0000-4000-8000-000000000009';
const reqId = '107df7a3-8693-42b2-9893-6a4610abad14';
const dealId = '90000000-0000-4000-8000-0000000000aa';

RequirementItem requirement() => RequirementItem.fromJson({
      'id': reqId,
      'company_id': 'rohan-co',
      'buyer_company_name': 'Rohan Feeds',
      'commodity_id': 'maize-ddgs',
      'commodity_name': 'Maize DDGS',
      'grade_id': 'grade-good',
      'grade_name': 'Good',
      'unit_id': 'unit-mt',
      'unit_symbol': 'MT',
      'broker_id': varun,
      'quantity': 35,
      'fulfilled_quantity': 0,
      'target_price': 28000,
      'delivery_terms_id': 'FOR Kota Mandi',
      'target_date': DateTime.now().add(const Duration(days: 14)).toIso8601String(),
      'status': 'Proposed to Buyer',
      'created_at': '2026-10-25T02:31:08.690',
    });

OfferItem lot(String id, {String broker = varun, bool verified = true, String commodityId = 'maize-ddgs'}) =>
    OfferItem.fromJson({
      'id': id,
      'lot_number': 'LOT-$id',
      'seller_company_name': 'Seller $id',
      'seller_company_verified': verified,
      'commodity_id': commodityId,
      'commodity_name': commodityId == 'maize-ddgs' ? 'Maize DDGS' : 'Wheat',
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
      'broker_id': broker,
      'created_at': '2026-10-20T00:00:00.000',
    });

class FakeWork extends WorkRepository {
  @override
  Future<WorkDataResult<RequirementNegotiationData>> getRequirementNegotiationDetails(String requirementId) async =>
      WorkSuccess(RequirementNegotiationData(
        requirementId: requirementId,
        currentVersionNumber: 1,
        currentStatus: 'Open',
        offeredPrice: 0,
        proposedQuantity: 0,
      ));
  final List<OfferItem> offers;
  FakeWork(this.offers);

  @override
  String? activeBrokerId() => varun;

  @override
  Future<WorkDataResult<List<RequirementItem>>> getRequirements() async => WorkSuccess([requirement()]);

  @override
  Future<WorkDataResult<List<OfferItem>>> getOffers() async => WorkSuccess(offers);

  @override
  Future<WorkDataResult<RequirementItem>> getRequirementById(String requirementId) async =>
      WorkSuccess(requirement());
}

class FakeDeals extends DealRepository {
  final List<DealItem> deals;
  final List<AllocationItem> allocations = [];
  bool failPropose;
  Completer<void>? holdPropose;
  int proposeCalls = 0;
  int createDealCalls = 0;
  FakeDeals({List<DealItem>? deals, this.failPropose = false}) : deals = deals ?? [];

  @override
  Future<DealDataResult<List<DealItem>>> getDeals({DealStatus? statusFilter, String? search}) async =>
      DealSuccess(List.of(deals));

  @override
  Future<DealDataResult<List<AllocationItem>>> getAllocationsForRequirement(String requirementId) async =>
      DealSuccess(List.of(allocations));

  @override
  Future<DealDataResult<AllocationItem>> proposeAllocation(CreateAllocationDto dto) async {
    proposeCalls++;
    await holdPropose?.future;
    if (failPropose) return const DealError(message: 'Seller lot stock changed. Refresh and retry.');
    final a = AllocationItem.fromJson({
      'id': 'alloc-1',
      'allocation_reference': 'ALC-000001',
      'requirement_id': dto.requirementId,
      'availability_id': dto.availabilityId,
      'allocated_quantity': dto.proposedQuantity,
      'unit_symbol': dto.unitSymbol,
      'seller_company_name': 'Seller lot-mine',
      'status': 'CONFIRMED',
    });
    allocations.add(a);
    return DealSuccess(a);
  }

  @override
  Future<DealDataResult<DealItem>> createDealFromAllocation(CreateDealDto dto) async {
    createDealCalls++;
    return const DealError(message: 'not expected');
  }

  @override
  Future<DealDataResult<DealDetailItem>> getDealDetail(String id) async => DealSuccess(DealDetailItem.fromJson({
        'id': id,
        'requirement_id': reqId,
        'commodity_name': 'Maize DDGS',
        'seller_company_name': 'Seller lot-mine',
        'agreed_price': 27500,
        'agreed_quantity': 35,
        'status': 'Draft',
      }));

  @override
  Future<DealDataResult<List<DealVersionItem>>> getDealVersionHistory(String id) async => const DealSuccess([]);
}

DealItem realDeal() => DealItem.fromJson({
      'id': dealId,
      'requirement_id': reqId,
      'quotation_id': 'q-1',
      'commodity_name': 'Maize DDGS',
      'seller_company_name': 'Seller lot-mine',
      'agreed_price': 27500,
      'agreed_quantity': 35,
      'status': 'Draft',
    });

/// Requirement-level negotiation item as the Deals list builds it.
DealItem negotiationItem() => DealRepository.requirementNegotiationItem({
      'id': reqId,
      'company_id': 'rohan-co',
      'quantity': 35,
      'target_price': 28000,
      'created_at': '2026-10-25T02:31:08.690',
    }, null);

void main() {
  Future<void> pump(WidgetTester tester, {required FakeWork work, required FakeDeals deals}) async {
    tester.view.physicalSize = const Size(2000, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final router = AppRouter.router;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        workRepositoryProvider.overrideWithValue(work),
        dealRepositoryProvider.overrideWithValue(deals),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    router.go('/requirements/$reqId');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    // Seller Allocation & Deals starts collapsed; open it.
    await tester.ensureVisible(find.byKey(const ValueKey('req_section_seller')));
    await tester.tap(find.byKey(const ValueKey('req_section_seller')));
    await tester.pumpAndSettle();
  }

  Future<void> openPickerAndChoose(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('allocate_seller_button')));
    await tester.tap(find.byKey(const ValueKey('allocate_seller_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('seller_lot_lot-mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review Allocation Summary'));
    await tester.pumpAndSettle();
  }

  testWidgets('unallocated requirement shows Allocate Seller; picker lists only eligible verified own lots',
      (tester) async {
    await pump(tester,
        work: FakeWork([
          lot('lot-mine'),
          lot('lot-other-desk', broker: otherBroker),
          lot('lot-unverified', verified: false),
          lot('lot-wheat', commodityId: 'wheat'),
        ]),
        deals: FakeDeals());

    expect(find.text('No seller lot has been allocated to this requirement yet.'), findsOneWidget);
    expect(find.byKey(const ValueKey('allocate_seller_button')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('allocate_seller_button')));
    await tester.tap(find.byKey(const ValueKey('allocate_seller_button')));
    await tester.pumpAndSettle();

    // Still on the requirement page, with the picker over it.
    expect(find.byType(RequirementDetailScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('seller_lot_lot-mine')), findsOneWidget);
    expect(find.byKey(const ValueKey('seller_lot_lot-other-desk')), findsNothing);
    expect(find.byKey(const ValueKey('seller_lot_lot-unverified')), findsNothing);
    expect(find.byKey(const ValueKey('seller_lot_lot-wheat')), findsNothing);
  });

  testWidgets('successful allocation persists, creates no deal and updates the section', (tester) async {
    final deals = FakeDeals();
    await pump(tester, work: FakeWork([lot('lot-mine')]), deals: deals);
    await openPickerAndChoose(tester);

    await tester.tap(find.text('Authoritatively Commit'));
    await tester.pumpAndSettle();
    expect(find.text('Allocation Committed Successfully!'), findsOneWidget);
    expect(deals.proposeCalls, 1);
    expect(deals.createDealCalls, 0);

    await tester.tap(find.text('Close Desk'));
    await tester.pumpAndSettle();
    expect(find.byType(RequirementDetailScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('linked_alloc_alloc-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('allocate_seller_button')), findsNothing);
  });

  testWidgets('failed allocation shows the error and no success', (tester) async {
    final deals = FakeDeals(failPropose: true);
    await pump(tester, work: FakeWork([lot('lot-mine')]), deals: deals);
    await openPickerAndChoose(tester);

    await tester.tap(find.text('Authoritatively Commit'));
    await tester.pumpAndSettle();
    // Shown in the sheet and in the Linked section behind it.
    expect(find.text('Seller lot stock changed. Refresh and retry.'), findsWidgets);
    expect(find.text('Allocation Committed Successfully!'), findsNothing);
    expect(deals.allocations, isEmpty);
  });

  testWidgets('repeated taps while saving submit one allocation', (tester) async {
    final deals = FakeDeals()..holdPropose = Completer<void>();
    await pump(tester, work: FakeWork([lot('lot-mine')]), deals: deals);
    await openPickerAndChoose(tester);

    await tester.tap(find.text('Authoritatively Commit'));
    await tester.pump();
    // Button is disabled (spinner) while the first request is in flight.
    await tester.tap(find.byType(ElevatedButton).last, warnIfMissed: false);
    await tester.pump();
    deals.holdPropose!.complete();
    await tester.pumpAndSettle();
    expect(deals.proposeCalls, 1);
    expect(deals.allocations, hasLength(1));
  });

  testWidgets('requirement negotiation item is not shown as a deal and opens no Deal Contract', (tester) async {
    await pump(tester, work: FakeWork([lot('lot-mine')]), deals: FakeDeals(deals: [negotiationItem()]));
    expect(find.byKey(const ValueKey('linked_deal_$reqId')), findsNothing);
    expect(find.textContaining('Seller not allocated'), findsNothing);
    expect(find.text('No seller lot has been allocated to this requirement yet.'), findsOneWidget);
    expect(find.byKey(const ValueKey('allocate_seller_button')), findsOneWidget);
    expect(find.byType(DealDetailScreen), findsNothing);
  });

  testWidgets('an existing real deal still opens its details', (tester) async {
    await pump(tester, work: FakeWork([lot('lot-mine')]), deals: FakeDeals(deals: [realDeal(), negotiationItem()]));
    expect(find.byKey(const ValueKey('allocate_seller_button')), findsNothing);
    final row = find.byKey(const ValueKey('linked_deal_$dealId'));
    expect(row, findsOneWidget);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(DealDetailScreen), findsOneWidget);
  });
}
