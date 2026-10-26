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

class MockNotificationRepo extends NotificationRepository {
  final List<BrokerNotification> items;
  MockNotificationRepo(this.items);

  @override
  Future<List<BrokerNotification>> fetchNotifications({
    NotificationCategory? category,
    bool? unreadOnly,
  }) async => items;

  @override
  Future<bool> markAsRead(String notificationId) async => true;
}

class MockDealRepo extends DealRepository {
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
      }),
    );
  }
}

void main() {
  testWidgets('Test tapping Recent Confirmation card in NotificationCenterScreen', (tester) async {
    final notif = BrokerNotification(
      id: 'conf-1',
      userId: 'broker-1',
      eventType: 'FINAL_CONFIRMATION_REQUIRED',
      category: NotificationCategory.dealsAndConfirmations,
      title: 'Deal Awaiting Final Confirmation',
      message: 'Deal DL-2026-0891 (50 MT Mustard Seed) requires review.',
      contextReason: 'Buyer Sharma Agro Mills Ltd confirmed terms.',
      actionLabel: 'Review Deal',
      actionUrl: '/deals/deal-bkg-0042',
      deliveryStatus: 'Sent',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      payload: {'dealId': 'deal-bkg-0042'},
    );

    final mockNotifRepo = MockNotificationRepo([notif]);
    final mockDealRepo = MockDealRepo();

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
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(notif.resolvedRoute, '/deals/deal-bkg-0042');
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Deal Awaiting Final Confirmation'), findsOneWidget);

    // Tap the confirmation card
    await tester.tap(find.text('Deal Awaiting Final Confirmation'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // Verify DealDetailScreen opened without crash
    expect(find.byType(DealDetailScreen), findsOneWidget);
  });
}
