import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmseller_mobile/features/notifications/data/notifications_repository.dart';
import 'package:rmseller_mobile/features/notifications/domain/notification_model.dart';
import 'package:rmseller_mobile/features/notifications/presentation/seller_notifications_screen.dart';

class _FakeNotificationsRepository extends NotificationsRepository {
  final List<SellerNotification> items;
  final List<String> markedRead = [];

  _FakeNotificationsRepository(this.items);

  @override
  Future<List<SellerNotification>> getNotifications() async =>
      List.of(items);

  @override
  Future<void> markAsRead(String notificationId) async {
    markedRead.add(notificationId);
    final i = items.indexWhere((n) => n.id == notificationId);
    final n = items[i];
    items[i] = SellerNotification(
      id: n.id,
      userId: n.userId,
      eventType: n.eventType,
      title: n.title,
      message: n.message,
      actionUrl: n.actionUrl,
      actionLabel: n.actionLabel,
      isRead: true,
      createdAt: n.createdAt,
    );
  }
}

void main() {
  group('NOTIFICATIONS-UI-SIMPLIFY-01: SellerNotificationsScreen', () {
    late _FakeNotificationsRepository repo;
    late List<String> visited;

    SellerNotification notif(
      String id,
      String type,
      String title,
      Duration age, {
      bool read = false,
      String url = '/home',
    }) => SellerNotification(
      id: id,
      userId: 'u1',
      eventType: type,
      title: title,
      message: '$title summary',
      actionUrl: url,
      actionLabel: 'View Terms',
      isRead: read,
      createdAt: DateTime.now().subtract(age),
    );

    setUp(() {
      final now = DateTime.now();
      final sinceMidnight = now.difference(
        DateTime(now.year, now.month, now.day),
      );
      repo = _FakeNotificationsRepository([
        notif(
          'n1',
          'COMMISSION_PROPOSAL',
          'Commission Offer Received',
          Duration.zero,
          url: '/communication/broker/b1',
        ),
        notif('n2', 'BROKER_MESSAGE', 'New Broker Message', Duration.zero),
        notif(
          'n3',
          'DEAL_BOOKED',
          'Deal Booked',
          sinceMidnight + const Duration(hours: 2),
          read: true,
          url: '/deals/d1',
        ),
        notif(
          'n4',
          'INVOICE_GENERATED',
          'Invoice Generated',
          const Duration(days: 4),
          read: true,
        ),
      ]);
      visited = [];
    });

    Widget buildApp() {
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(
            path: '/notifications',
            builder: (context, state) =>
                SellerNotificationsScreen(repository: repo),
          ),
          GoRoute(
            path: '/communication/broker/:id',
            builder: (context, state) {
              visited.add(state.uri.path);
              return const Scaffold(body: Text('CHAT'));
            },
          ),
          GoRoute(
            path: '/deals/:id',
            builder: (context, state) {
              visited.add(state.uri.path);
              return const Scaffold(body: Text('DEAL'));
            },
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const Scaffold(body: Text('HOME')),
          ),
        ],
      );
      return MaterialApp.router(routerConfig: router);
    }

    testWidgets('Compact cards grouped by Today / Yesterday / This Week', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);

      expect(find.text('Commission Offer Received'), findsOneWidget);
      expect(find.text('Commission Offer Received summary'), findsOneWidget);

      // No inline action labels/buttons
      expect(find.text('View Terms'), findsNothing);

      // Unread dot only on unread notifications
      expect(find.byKey(const Key('notification_unread_n1')), findsOneWidget);
      expect(find.byKey(const Key('notification_unread_n2')), findsOneWidget);
      expect(find.byKey(const Key('notification_unread_n3')), findsNothing);
    });

    testWidgets('Filters keep their behavior and show counts', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Counts: All 4, Unread 2, Commission 1, Messages 1
      Finder countIn(String filter, String count) => find.descendant(
        of: find.byKey(Key('notification_filter_$filter')),
        matching: find.text(count),
      );
      expect(countIn('ALL', '4'), findsOneWidget);
      expect(countIn('Unread', '2'), findsOneWidget);
      expect(countIn('Commission', '1'), findsOneWidget);
      expect(countIn('Messages', '1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('notification_filter_Unread')));
      await tester.pumpAndSettle();
      expect(find.text('Deal Booked'), findsNothing);
      expect(find.text('New Broker Message'), findsOneWidget);

      await tester.tap(find.byKey(const Key('notification_filter_Commission')));
      await tester.pumpAndSettle();
      expect(find.text('Commission Offer Received'), findsOneWidget);
      expect(find.text('New Broker Message'), findsNothing);
    });

    testWidgets('Tapping a card marks it read and opens its destination', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('notification_card_n1')));
      await tester.pumpAndSettle();

      expect(repo.markedRead, ['n1']);
      expect(find.text('CHAT'), findsOneWidget);
      expect(visited, ['/communication/broker/b1']);

      // Back: unread dot is gone after reload
      final router = GoRouter.of(tester.element(find.text('CHAT')));
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notification_unread_n1')), findsNothing);

      await tester.tap(find.byKey(const Key('notification_card_n3')));
      await tester.pumpAndSettle();
      expect(find.text('DEAL'), findsOneWidget);
    });

    testWidgets('No overflow on a 320dp screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Any RenderFlex overflow is reported by the framework and fails here.
      expect(find.text('Commission Offer Received'), findsOneWidget);
    });
  });
}
