import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/app/router/app_router.dart';
import 'package:rmbroker_mobile/features/deals/presentation/controllers/deals_controller.dart';
import 'package:rmbroker_mobile/features/notifications/domain/alert_kind.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_category.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_model.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:rmbroker_mobile/features/work/domain/offer_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_negotiation_model.dart';
import 'package:rmbroker_mobile/features/work/presentation/controllers/requirements_controller.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/offer_detail_sheet.dart';

import 'requirement_allocate_seller_test.dart' show FakeDeals;

// RMBROKER-SELLER-REQUIREMENT-CHAT-E2E-01, client half of steps 2-5.
// Isolated fixtures only; no Supabase project is contacted.

const broker = 'e2e00000-0000-4000-8000-0000000b0001'; // E2E-BROKER-01
const sellerCo = 'e2e00000-0000-4000-8000-0000000c0001'; // E2E-SELLER-01
const commodity = 'e2e00000-0000-4000-8000-0000000d0001'; // E2E-COMMODITY-01
const offerId = 'e2e00000-0000-4000-8000-0000000e0001';
const otherOfferId = 'e2e00000-0000-4000-8000-0000000e0002';
const reqId = 'e2e00000-0000-4000-8000-0000000f0001';

RequirementItem e2eRequirement() => RequirementItem.fromJson({
      'id': reqId,
      'company_id': 'e2e-buyer-co',
      'buyer_company_name': 'E2E-BUYER-01',
      'commodity_id': commodity,
      'commodity_name': 'E2E-COMMODITY-01',
      'grade_id': 'e2e-grade',
      'grade_name': 'FAQ',
      'unit_id': 'unit-mt',
      'unit_symbol': 'MT',
      'broker_id': broker,
      'quantity': 50,
      'fulfilled_quantity': 0,
      'target_price': 6000,
      'target_date': DateTime.now().add(const Duration(days: 14)).toIso8601String(),
      'status': 'Open',
      'created_at': '2026-11-02T09:00:00.000',
    });

OfferItem e2eOffer(String id, {String commodityId = commodity, String name = 'E2E-COMMODITY-01'}) =>
    OfferItem.fromJson({
      'id': id,
      'lot_number': 'LOT-$id'.substring(0, 12),
      'company_id': sellerCo,
      'seller_company_name': 'E2E-SELLER-01',
      'seller_company_verified': true,
      'commodity_id': commodityId,
      'commodity_name': name,
      'grade_id': 'e2e-grade',
      'grade_name': 'FAQ',
      'unit_id': 'unit-mt',
      'unit_symbol': 'MT',
      'total_quantity': 80,
      'available_quantity': 80,
      'asking_price': 5850,
      'district_name': 'Kota',
      'available_from': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'valid_until': DateTime.now().add(const Duration(days: 20)).toIso8601String(),
      'status': 'Open',
      'broker_id': broker,
      'created_at': '2026-11-02T09:30:00.000',
    });

class E2EWork extends WorkRepository {
  final List<OfferItem> offers;
  E2EWork(this.offers);

  @override
  String? activeBrokerId() => broker;

  @override
  Future<WorkDataResult<List<RequirementItem>>> getRequirements() async => WorkSuccess([e2eRequirement()]);

  @override
  Future<WorkDataResult<List<OfferItem>>> getOffers() async => WorkSuccess(offers);

  @override
  Future<WorkDataResult<RequirementItem>> getRequirementById(String requirementId) async =>
      WorkSuccess(e2eRequirement());

  @override
  Future<WorkDataResult<RequirementNegotiationData>> getRequirementNegotiationDetails(String requirementId) async =>
      WorkSuccess(RequirementNegotiationData(
        requirementId: requirementId,
        currentVersionNumber: 1,
        currentStatus: 'Open',
        offeredPrice: 0,
        proposedQuantity: 0,
      ));
}

/// Row shaped exactly as proposed migration 0065's trigger writes it.
Map<String, dynamic> listingNotificationRow() => {
      'id': 'e2e-notification-1',
      'user_id': broker,
      'company_id': 'e2e-broker-firm',
      'channel': 'IN_APP',
      'event_type': 'AVAILABILITY_CREATED',
      'title': 'New commodity listing',
      'message': 'E2E-SELLER-01 listed E2E-COMMODITY-01 — LOT-1: 80 MT at ₹5850/MT. Open the listing to view the details.',
      'action_label': 'Open Listing',
      'action_url': '/work?tab=1&offerId=$offerId',
      'delivery_status': 'Sent',
      'is_read': false,
      'created_at': '2026-11-02T09:30:01Z',
      'payload': {
        'availabilityId': offerId,
        'lotNumber': 'LOT-1',
        'commodity': 'E2E-COMMODITY-01',
        'sellerName': 'E2E-SELLER-01',
        'quantity': 80,
        'unit': 'MT',
        'price': 5850,
        'status': 'Open',
        'changeType': 'AVAILABILITY_CREATED',
      },
    };

void main() {
  Future<void> pump(WidgetTester tester, String location, {required E2EWork work, FakeDeals? deals}) async {
    tester.view.physicalSize = const Size(2000, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final router = AppRouter.router..go(location);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        workRepositoryProvider.overrideWithValue(work),
        dealRepositoryProvider.overrideWithValue(deals ?? FakeDeals()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  test('step 2: seller-listing notification targets the selected broker and the offer, without secrets', () {
    final row = listingNotificationRow();
    final n = BrokerNotification.fromJson(row);
    expect(n.category, NotificationCategory.requirementsAndOffers);
    expect(AlertKind.of(n), AlertKind.offer);
    expect(n.offerId, offerId);
    expect(row['user_id'], broker);
    final text = row.toString().toLowerCase();
    expect(text, isNot(contains('confidential')));
    expect(text, isNot(contains('minimum')));
    expect(text, isNot(contains('buyer')));
  });

  testWidgets('step 3: tapping the notification route opens exactly that offer', (tester) async {
    await pump(
      tester,
      BrokerNotification.fromJson(listingNotificationRow()).resolvedRoute!,
      work: E2EWork([e2eOffer(otherOfferId), e2eOffer(offerId)]),
    );

    final sheet = tester.widget<OfferDetailSheet>(find.byType(OfferDetailSheet));
    expect(sheet.offer.id, offerId);
  });

  testWidgets('step 3: a removed offer shows a safe unavailable message', (tester) async {
    await pump(tester, '/work?tab=1&offerId=$offerId', work: E2EWork([e2eOffer(otherOfferId)]));

    expect(find.byType(OfferDetailSheet), findsNothing);
    expect(find.text('This seller offer is no longer available or not visible to your desk.'), findsOneWidget);
  });

  testWidgets('steps 4-5: same-commodity requirement allocates the new seller offer once', (tester) async {
    final deals = FakeDeals();
    await pump(tester, '/requirements/$reqId',
        work: E2EWork([
          e2eOffer(offerId),
          e2eOffer(otherOfferId, commodityId: 'e2e-other-commodity', name: 'Other'),
        ]),
        deals: deals);
    await tester.ensureVisible(find.byKey(const ValueKey('req_section_seller')));
    await tester.tap(find.byKey(const ValueKey('req_section_seller')));
    await tester.pumpAndSettle();

    // Step 4: no seller allocated yet.
    expect(find.text('No seller lot has been allocated to this requirement yet.'), findsOneWidget);

    // Step 5: the new offer is listed by canonical commodity; the other commodity is not.
    await tester.ensureVisible(find.byKey(const ValueKey('allocate_seller_button')));
    await tester.tap(find.byKey(const ValueKey('allocate_seller_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('seller_lot_$otherOfferId')), findsNothing);
    final tile = tester.widget<ListTile>(find.byKey(const ValueKey('seller_lot_$offerId')));
    expect(tile.enabled, isTrue);

    await tester.tap(find.byKey(const ValueKey('seller_lot_$offerId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review Allocation Summary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Authoritatively Commit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close Desk'));
    await tester.pumpAndSettle();

    expect(deals.proposeCalls, 1);
    expect(deals.allocations.single.requirementId, reqId);
    expect(deals.allocations.single.availabilityId, offerId);
    expect(find.byKey(const ValueKey('linked_alloc_alloc-1')), findsOneWidget);

    // Reopen the picker: the allocated offer cannot be allocated again.
    await tester.ensureVisible(find.byKey(const ValueKey('allocate_another_seller_button')));
    await tester.tap(find.byKey(const ValueKey('allocate_another_seller_button')));
    await tester.pumpAndSettle();
    expect(tester.widget<ListTile>(find.byKey(const ValueKey('seller_lot_$offerId'))).enabled, isFalse);
    expect(find.textContaining('Already allocated to this requirement'), findsOneWidget);
  });
}
