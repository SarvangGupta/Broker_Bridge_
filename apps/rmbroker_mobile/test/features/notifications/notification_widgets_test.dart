import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rmbroker_mobile/features/authentication/domain/broker_user.dart';
import 'package:rmbroker_mobile/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:rmbroker_mobile/features/notifications/data/notification_repository.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_category.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_model.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/widgets/notification_badge.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/widgets/notification_card.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/widgets/notification_detail_dialog.dart';

class MockNotificationRepository extends NotificationRepository {
  final List<BrokerNotification> items;

  MockNotificationRepository({required this.items});

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
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    final idx = items.indexWhere((n) => n.id == notificationId);
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(isRead: true, readAt: DateTime.now());
    }
    return true;
  }

  @override
  Future<int> markAllAsRead() async {
    int count = 0;
    for (int i = 0; i < items.length; i++) {
      if (!items[i].isRead) {
        items[i] = items[i].copyWith(isRead: true, readAt: DateTime.now());
        count++;
      }
    }
    return count;
  }
}

void main() {
  final now = DateTime.now();

  final testNotifications = [
    BrokerNotification(
      id: 'test-1',
      userId: 'broker-1',
      eventType: 'FINAL_CONFIRMATION_REQUIRED',
      category: NotificationCategory.dealsAndConfirmations,
      title: 'Deal Awaiting Confirmation',
      message: 'Deal DL-2026-0891 (50 MT Mustard Seed) requires review.',
      contextReason: 'Buyer Sharma Agro Mills Ltd confirmed terms.',
      actionLabel: 'Review Deal',
      actionUrl: '/deals/deal-bkg-0042',
      idempotencyKey: 'idemp-1',
      isRead: false,
      createdAt: now.subtract(const Duration(minutes: 10)),
      payload: {'dealId': 'deal-bkg-0042'},
    ),
    BrokerNotification(
      id: 'test-2',
      userId: 'broker-1',
      eventType: 'MATCH_CREATED',
      category: NotificationCategory.requirementsAndOffers,
      title: 'High-Score Match (96%)',
      message: 'Requirement REQ-2026-0104 matches Offer OFF-2026-0219.',
      contextReason: 'Mustard Seed Grade-A Bold within price range.',
      actionLabel: 'Inspect Match',
      actionUrl: '/work',
      idempotencyKey: 'idemp-2',
      isRead: false,
      createdAt: now.subtract(const Duration(hours: 1)),
      payload: {'requirementId': 'req-2026-0104'},
    ),
    BrokerNotification(
      id: 'test-3',
      userId: 'broker-1',
      eventType: 'PAYMENT_RECORDED',
      category: NotificationCategory.commissionAndInvoices,
      title: 'Commission Payment Recorded',
      message: '₹3,000 received for Invoice INV-2026-0042.',
      contextReason: 'Settled via UTR994827104921.',
      actionLabel: 'View Invoice',
      actionUrl: '/invoices/inv-2026-0042',
      idempotencyKey: 'idemp-3',
      isRead: true,
      readAt: now.subtract(const Duration(hours: 2)),
      createdAt: now.subtract(const Duration(hours: 3)),
      payload: {'invoiceId': 'inv-2026-0042'},
    ),
  ];

  Widget createTestWidget({
    List<BrokerNotification>? initialItems,
    Widget child = const NotificationCenterScreen(),
  }) {
    final mockRepo = MockNotificationRepository(
      items: initialItems != null
          ? List.from(initialItems)
          : List.from(testNotifications),
    );

    return ProviderScope(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('NotificationCenterScreen UI Tests', () {
    testWidgets('renders AppBar with titles, search bar, filter chips, and notification cards', (
      tester,
    ) async {
      // Cards now carry message, record reference and context: use a tall phone
      // viewport (360 dp wide) so all three fixtures are laid out by the lazy list.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('Stay updated on your business'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search by commodity, deal, party or location...'), findsOneWidget);

      // Filter chips with counts from the data
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      Text count(String key) =>
          tester.widget<Text>(find.byKey(ValueKey('alerts_filter_count_$key')));
      expect(count('all').data, '3');
      expect(count('unread').data, '2');
      expect(count('requirement').data, '1');
      expect(count('offer').data, '0');
      expect(count('deal').data, '1');
      expect(count('task').data, '0');

      // Check cards
      expect(find.text('Deal Awaiting Confirmation'), findsOneWidget);
      expect(find.text('High-Score Match (96%)'), findsOneWidget);
      expect(find.text('Commission Payment Recorded'), findsOneWidget);
    });

    testWidgets('filtering by record kind displays only items of that kind', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final dealsChip = find.byKey(const ValueKey('alerts_filter_deal'));
      await tester.ensureVisible(dealsChip);
      await tester.tap(dealsChip);
      await tester.pumpAndSettle();

      expect(find.text('Deal Awaiting Confirmation'), findsOneWidget);
      expect(find.text('Commission Payment Recorded'), findsNothing);
      expect(find.text('High-Score Match (96%)'), findsNothing);

      final reqChip = find.byKey(const ValueKey('alerts_filter_requirement'));
      await tester.ensureVisible(reqChip);
      await tester.tap(reqChip);
      await tester.pumpAndSettle();
      expect(find.text('High-Score Match (96%)'), findsOneWidget);
      expect(find.text('Deal Awaiting Confirmation'), findsNothing);
    });

    testWidgets('Unread chip displays only unread items', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('alerts_filter_unread')));
      await tester.pumpAndSettle();

      expect(find.text('Deal Awaiting Confirmation'), findsOneWidget);
      expect(find.text('High-Score Match (96%)'), findsOneWidget);
      expect(find.text('Commission Payment Recorded'), findsNothing);
    });

    testWidgets('searching in search bar filters notifications accurately', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Mustard Seed');
      await tester.pumpAndSettle();

      expect(find.text('Deal Awaiting Confirmation'), findsOneWidget);
      expect(find.text('Commission Payment Recorded'), findsNothing);
    });

    testWidgets('empty state displays when no notifications match search query', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'NonExistentCommodityQuery1234');
      await tester.pumpAndSettle();

      expect(find.text('No matching notifications found'), findsOneWidget);
      expect(find.text('Reset All Filters'), findsOneWidget);

      // Reset filters button clears query
      await tester.tap(find.text('Reset All Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Deal Awaiting Confirmation'), findsOneWidget);
    });

    testWidgets('mark all as read updates unread notifications', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find mark all as read icon button
      final markAllBtn = find.byTooltip('Mark All Read');
      expect(markAllBtn, findsOneWidget);

      await tester.tap(markAllBtn);
      await tester.pumpAndSettle();

      expect(find.text('All notifications marked as read'), findsOneWidget);
      // Mark All Read icon button should disappear when unread count is 0
      expect(find.byTooltip('Mark All Read'), findsNothing);
    });

    testWidgets('Mark as read from the card menu marks only that alert read', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('notif_unread_test-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('notif_unread_test-2')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('notif_menu_test-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as read'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('notif_unread_test-1')), findsNothing);
      expect(find.byKey(const ValueKey('notif_unread_test-2')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('alerts_filter_count_unread'))).data, '1');
    });
  });

  group('NotificationCard & Detail Dialog Widget Tests', () {
    testWidgets('NotificationCard displays category icon, action button, and relative time', (
      tester,
    ) async {
      bool actionTriggered = false;
      bool tapTriggered = false;

      final notif = testNotifications.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationCard(
              notification: notif,
              onTap: (_) => tapTriggered = true,
              onAction: (_) => actionTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('Deal Awaiting Confirmation'), findsOneWidget);
      expect(find.text('Confirmation required'), findsOneWidget); // short type label
      expect(find.text('Action required'), findsOneWidget); // urgent status
      expect(find.text('10m ago'), findsOneWidget);
      // One compact action; the long message is not repeated on the card
      expect(find.text('View details'), findsOneWidget);
      expect(find.text('Deal DL-2026-0891 (50 MT Mustard Seed) requires review.'), findsNothing);

      // Tap action button
      await tester.tap(find.byKey(const ValueKey('notif_action_test-1')));
      await tester.pump();
      expect(actionTriggered, isTrue);

      // Tap whole card
      await tester.tap(find.byType(NotificationCard));
      await tester.pump();
      expect(tapTriggered, isTrue);
    });

    testWidgets('NotificationDetailDialog renders full audit details and action', (
      tester,
    ) async {
      bool recordOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                child: const Text('Open Dialog'),
                onPressed: () {
                  NotificationDetailDialog.show(
                    ctx,
                    notification: testNotifications.first,
                    onOpenRecord: () => recordOpened = true,
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Operational Context'), findsOneWidget);
      expect(find.text('Event Type'), findsOneWidget);
      expect(find.text('FINAL_CONFIRMATION_REQUIRED'), findsOneWidget);
      expect(find.text('Deduplication Key'), findsOneWidget);
      expect(find.text('idemp-1'), findsOneWidget);

      // Tap Open Record
      await tester.tap(find.text('Review Deal'));
      await tester.pumpAndSettle();
      expect(recordOpened, isTrue);
    });
  });

  group('NotificationBadge & DashboardHeader Integration Tests', () {
    testWidgets('NotificationBadge shows count when > 0 and hides when <= 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NotificationBadge(
                  count: 5,
                  child: Icon(LucideIcons.bell),
                ),
                NotificationBadge(
                  count: 0,
                  child: Icon(LucideIcons.mail),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('DashboardHeader displays bell icon with unread badge', (
      tester,
    ) async {
      const broker = BrokerUser(
        id: 'b-1',
        email: 'broker@rmbroker.in',
        fullName: 'Test Broker',
        role: 'broker',
      );

      await tester.pumpWidget(
        createTestWidget(
          child: const Scaffold(
            appBar: DashboardHeader(broker: broker),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Desk Notifications'), findsOneWidget);
      // testNotifications has 2 unread items
      expect(find.text('2'), findsOneWidget);
    });
  });
}
