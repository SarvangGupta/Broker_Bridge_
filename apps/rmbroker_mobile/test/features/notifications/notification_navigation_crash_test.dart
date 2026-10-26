import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/app/router/app_router.dart';
import 'package:rmbroker_mobile/features/deals/data/deal_repository.dart';
import 'package:rmbroker_mobile/features/deals/domain/deal_model.dart';
import 'package:rmbroker_mobile/features/deals/presentation/controllers/deals_controller.dart';
import 'package:rmbroker_mobile/features/deals/presentation/screens/deal_detail_screen.dart';
import 'package:rmbroker_mobile/features/notifications/data/notification_repository.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_category.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_model.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:rmbroker_mobile/features/work/presentation/work_screen.dart';

class TestNotificationRepository extends NotificationRepository {
  final List<BrokerNotification> items;
  TestNotificationRepository(this.items);

  @override
  Future<List<BrokerNotification>> fetchNotifications({
    NotificationCategory? category,
    bool? unreadOnly,
  }) async {
    var result = List<BrokerNotification>.from(items);
    if (category != null && category != NotificationCategory.all) {
      result = result.where((n) => n.category == category).toList();
    }
    if (unreadOnly == true) {
      result = result.where((n) => !n.isRead).toList();
    }
    return result;
  }

  @override
  Future<bool> markAsRead(String notificationId) async => true;
}

class TestDealRepository extends DealRepository {
  @override
  Future<DealDataResult<List<DealItem>>> getDeals({DealStatus? statusFilter, String? search}) async {
    return const DealSuccess([]);
  }

  @override
  Future<DealDataResult<DealDetailItem>> getDealDetail(String dealId) async {
    return DealSuccess(
      DealDetailItem.fromJson({
        'id': dealId,
        'booking_reference': 'BKG-2026-0891',
        'commodity_name': 'Mustard Seed (Sarson)',
        'grade_name': 'Grade-A Bold',
        'agreed_price': 5450.0,
        'agreed_quantity': 50.0,
        'status': 'finalized',
        'buyer_company_name': 'Sharma Agro Mills Ltd',
        'seller_company_name': 'Kisan Agro Producers Co.',
        'latestVersionNumber': 2,
        'buyerConfirmed': true,
        'sellerConfirmed': true,
      }),
    );
  }
}

void main() {
  late BrokerNotification endedConfirmationNotif;
  late BrokerNotification activeDealNotif;
  late BrokerNotification shellRouteNotif;

  setUp(() {
    final now = DateTime.now();
    endedConfirmationNotif = BrokerNotification(
      id: 'notif-ended-01',
      userId: 'broker-demo-user',
      eventType: 'FINAL_CONFIRMATION_REQUIRED',
      category: NotificationCategory.dealsAndConfirmations,
      title: 'Deal Awaiting Final Confirmation',
      message: 'Deal DL-2026-0891 (50 MT Mustard Seed) confirmed terms.',
      contextReason: 'Buyer Sharma Agro Mills Ltd confirmed terms. Awaiting seller sign-off.',
      actionLabel: 'Review Deal',
      actionUrl: '/deals/deal-bkg-0042',
      deliveryStatus: 'Sent',
      isRead: false,
      createdAt: now.subtract(const Duration(minutes: 10)),
      payload: {
        'dealId': 'deal-bkg-0042',
        'dealReference': 'DL-2026-0891',
      },
    );

    activeDealNotif = BrokerNotification(
      id: 'notif-active-02',
      userId: 'broker-demo-user',
      eventType: 'COUNTER_OFFER_RECEIVED',
      category: NotificationCategory.dealsAndConfirmations,
      title: 'Counter Offer Received',
      message: 'Seller revised counter terms for active negotiation.',
      contextReason: 'Price updated to ₹5,480/Qtl.',
      actionLabel: 'View Deal',
      actionUrl: '/deals/11111111-2222-3333-4444-555555555555',
      deliveryStatus: 'Sent',
      isRead: false,
      createdAt: now.subtract(const Duration(minutes: 5)),
      payload: {'dealId': '11111111-2222-3333-4444-555555555555'},
    );

    shellRouteNotif = BrokerNotification(
      id: 'notif-work-03',
      userId: 'broker-demo-user',
      eventType: 'MATCH_CREATED',
      category: NotificationCategory.requirementsAndOffers,
      title: 'New High-Score Mandate Match',
      message: 'Buyer requirement matched seller offer.',
      contextReason: 'Quantity and price align with mandi tolerance.',
      actionLabel: 'Inspect Match',
      actionUrl: '/work',
      deliveryStatus: 'Sent',
      isRead: false,
      createdAt: now.subtract(const Duration(hours: 1)),
      // No record id: a generic Work Desk alert (record ids route to the record,
      // covered in notification_lifecycle_routing_test.dart).
    );
  });

  testWidgets('Tap confirmation for ended negotiation opens historical detail without crash', (tester) async {
    final mockNotifRepo = TestNotificationRepository([endedConfirmationNotif]);
    final mockDealRepo = TestDealRepository();
    final router = AppRouter.router;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(mockNotifRepo),
          dealRepositoryProvider.overrideWithValue(mockDealRepo),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    router.go('/notifications');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Deal Awaiting Final Confirmation'), findsOneWidget);

    // Verify NotificationCard has stable ValueKey
    expect(find.byKey(const ValueKey('notif_card_notif-ended-01')), findsOneWidget);

    // Tap confirmation card
    await tester.tap(find.text('Deal Awaiting Final Confirmation'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // Verify DealDetailScreen opened smoothly without navigator assertion
    expect(find.byType(DealDetailScreen), findsOneWidget);
    expect(find.text('BKG-2026-0891'), findsWidgets);

    // Navigate back to notifications
    final backBtn = find.byType(BackButton);
    if (backBtn.evaluate().isNotEmpty) {
      await tester.tap(backBtn);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Alerts'), findsOneWidget);
    }
  });

  testWidgets('Tap confirmation for active negotiation opens deal contract smoothly', (tester) async {
    final mockNotifRepo = TestNotificationRepository([activeDealNotif]);
    final mockDealRepo = TestDealRepository();
    final router = AppRouter.router;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(mockNotifRepo),
          dealRepositoryProvider.overrideWithValue(mockDealRepo),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    router.go('/notifications');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Counter Offer Received'), findsOneWidget);

    // Tap active deal card
    await tester.tap(find.text('Counter Offer Received'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.byType(DealDetailScreen), findsOneWidget);
  });

  testWidgets('Rapid duplicate taps on confirmation card are debounced', (tester) async {
    final mockNotifRepo = TestNotificationRepository([endedConfirmationNotif]);
    final mockDealRepo = TestDealRepository();
    final router = AppRouter.router;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(mockNotifRepo),
          dealRepositoryProvider.overrideWithValue(mockDealRepo),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    router.go('/notifications');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Perform rapid double-tap
    await tester.tap(find.text('Deal Awaiting Final Confirmation'));
    await tester.tap(find.text('Deal Awaiting Final Confirmation'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // Only one DealDetailScreen should be pushed
    expect(find.byType(DealDetailScreen), findsOneWidget);
  });

  testWidgets('Notification navigating to shell route (/work) uses go() without duplicate key crash', (tester) async {
    final mockNotifRepo = TestNotificationRepository([shellRouteNotif]);
    final mockDealRepo = TestDealRepository();
    final router = AppRouter.router;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(mockNotifRepo),
          dealRepositoryProvider.overrideWithValue(mockDealRepo),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    router.go('/notifications');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('New High-Score Mandate Match'), findsOneWidget);

    // Tap shell route card
    await tester.tap(find.text('New High-Score Mandate Match'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));

    // Verifies work screen loaded via shell branch switch without crash
    expect(find.byType(WorkScreen), findsOneWidget);
  });
}
