import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/notifications/data/notification_repository.dart';
import 'package:rmbroker_mobile/features/notifications/domain/alert_kind.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_category.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_model.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/screens/notification_center_screen.dart';

// RB-ALERTS-UI-01. Fakes only.

class FakeRepo extends NotificationRepository {
  final List<BrokerNotification> items;
  int fetches = 0;
  bool fail = false;
  FakeRepo(this.items);

  @override
  Future<List<BrokerNotification>> fetchNotifications({
    NotificationCategory? category,
    bool? unreadOnly,
  }) async {
    fetches++;
    if (fail) throw Exception('offline');
    return List.of(items)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<bool> markAsRead(String notificationId) async => true;

  @override
  Future<int> markAllAsRead() async => items.length;
}

BrokerNotification alert(
  String id,
  String type,
  DateTime at, {
  bool read = false,
  Map<String, dynamic>? payload,
  String title = 'Alert',
  String message = '',
  String? actionUrl,
}) => BrokerNotification.fromJson({
  'id': id,
  'user_id': 'broker',
  'event_type': type,
  'title': title,
  'message': message,
  'is_read': read,
  'action_url': ?actionUrl,
  'created_at': at.toIso8601String(),
  'payload': ?payload,
});

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 9);
  final yesterday = today.subtract(const Duration(days: 1));
  final older = today.subtract(const Duration(days: 4));

  List<BrokerNotification> sample() => [
    alert(
      'r1',
      'REQUIREMENT_CREATED',
      today,
      title: 'New Requirement',
      message:
          'Buyer posted requirement for 100 MT of De-oiled Rice Bran (DORB).',
      payload: {
        'requirementId': 'req-43728b',
        'quantity': 100,
        'unit': 'MT',
        'targetPrice': 21000,
        'deliveryLocation': 'Kota Mandi',
        'commodity': 'DORB',
      },
    ),
    alert(
      'o1',
      'OFFER_CREATED',
      today.add(const Duration(minutes: 5)),
      title: 'New Offer',
      message: 'Seller posted offer for 60 MT of Soyabean Meal.',
      payload: {'offerId': 'off-7721aa'},
    ),
    alert(
      'd1',
      'NEGOTIATION_RECEIVED',
      yesterday,
      read: true,
      title: 'Seller Reply',
      message: 'Seller has sent a counter offer for your deal.',
      payload: {'dealId': 'deal-9823k'},
    ),
    alert(
      't1',
      'TASK_ASSIGNED',
      older,
      title: 'Task Assigned',
      message: 'You have been assigned to review and allocate sellers.',
      payload: {'taskId': 'task-1'},
    ),
    alert(
      's1',
      'SYSTEM',
      older.subtract(const Duration(hours: 1)),
      read: true,
      title: 'Maintenance',
    ),
  ];

  Future<FakeRepo> pump(
    WidgetTester tester, {
    List<BrokerNotification>? items,
    Size size = const Size(1080, 4200),
    double dpr = 2.75,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    final repo = FakeRepo(items ?? sample());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: NotificationCenterScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  String count(WidgetTester tester, String key) => tester
      .widget<Text>(find.byKey(ValueKey('alerts_filter_count_$key')))
      .data!;

  Future<void> chip(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey('alerts_filter_$key')));
    await tester.tap(find.byKey(ValueKey('alerts_filter_$key')));
    await tester.pumpAndSettle();
  }

  Finder card(String id) => find.byKey(ValueKey('notif_card_$id'));

  test(
    'AlertKind classification follows record references and event types',
    () {
      expect(AlertKind.of(sample()[0]), AlertKind.requirement);
      expect(AlertKind.of(sample()[1]), AlertKind.offer);
      expect(AlertKind.of(sample()[2]), AlertKind.deal);
      expect(AlertKind.of(sample()[3]), AlertKind.task);
      expect(AlertKind.of(sample()[4]), AlertKind.other);
    },
  );

  test(
    'time groups use local calendar days, including midnight boundaries',
    () {
      final ref = DateTime(2026, 10, 26, 0, 5);
      expect(
        AlertGroup.of(DateTime(2026, 10, 26, 0, 0), ref),
        AlertGroup.today,
      );
      expect(
        AlertGroup.of(DateTime(2026, 10, 25, 23, 59), ref),
        AlertGroup.yesterday,
      );
      expect(
        AlertGroup.of(DateTime(2026, 10, 25, 0, 0), ref),
        AlertGroup.yesterday,
      );
      expect(
        AlertGroup.of(DateTime(2026, 10, 24, 23, 59), ref),
        AlertGroup.earlier,
      );
    },
  );

  testWidgets('six chips with counts from the data; each filters correctly', (
    tester,
  ) async {
    await pump(tester);
    expect(count(tester, 'all'), '5');
    expect(count(tester, 'unread'), '3');
    expect(count(tester, 'requirement'), '1');
    expect(count(tester, 'offer'), '1');
    expect(count(tester, 'deal'), '1');
    expect(count(tester, 'task'), '1');

    for (final (key, visible) in [
      ('unread', {'r1', 'o1', 't1'}),
      ('requirement', {'r1'}),
      ('offer', {'o1'}),
      ('deal', {'d1'}),
      ('task', {'t1'}),
      ('all', {'r1', 'o1', 'd1', 't1', 's1'}),
    ]) {
      await chip(tester, key);
      for (final id in ['r1', 'o1', 'd1', 't1', 's1']) {
        expect(
          card(id),
          visible.contains(id) ? findsOneWidget : findsNothing,
          reason: '$key/$id',
        );
      }
    }
  });

  testWidgets('search combines with the selected chip and matches metadata', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Kota');
    await tester.pumpAndSettle();
    expect(card('r1'), findsOneWidget, reason: 'location metadata');
    expect(card('o1'), findsNothing);

    await chip(tester, 'offer');
    expect(card('r1'), findsNothing);
    expect(find.text('No matching notifications found'), findsOneWidget);

    await tester.tap(find.text('Reset All Filters'));
    await tester.pumpAndSettle();
    expect(card('o1'), findsOneWidget);
    expect(count(tester, 'all'), '5');
  });

  testWidgets(
    'grouped Today / Yesterday / Earlier, newest first, collapsible, no duplicates',
    (tester) async {
      await pump(tester);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('alerts_group_count_today')),
            )
            .data,
        '2 new · 2',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('alerts_group_count_yesterday')),
            )
            .data,
        '1',
      );

      // Newest first within Today: o1 (09:05) above r1 (09:00).
      expect(
        tester.getTopLeft(card('o1')).dy,
        lessThan(tester.getTopLeft(card('r1')).dy),
      );

      await tester.tap(find.byKey(const ValueKey('alerts_group_today')));
      await tester.pumpAndSettle();
      expect(card('r1'), findsNothing);
      expect(card('d1'), findsOneWidget, reason: 'other groups unaffected');
      await tester.tap(find.byKey(const ValueKey('alerts_group_today')));
      await tester.pumpAndSettle();
      expect(card('r1'), findsOneWidget);

      for (final id in ['r1', 'o1', 'd1', 't1', 's1']) {
        expect(card(id), findsOneWidget, reason: 'each alert appears once');
      }
    },
  );

  testWidgets(
    'refresh reloads without duplicates; mark-all-read clears unread',
    (tester) async {
      final repo = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('alerts_refresh')));
      await tester.pumpAndSettle();
      expect(repo.fetches, 2);
      expect(card('r1'), findsOneWidget);
      expect(count(tester, 'all'), '5');

      await tester.tap(find.byKey(const ValueKey('alerts_mark_all_read')));
      await tester.pumpAndSettle();
      expect(count(tester, 'unread'), '0');
      expect(find.byKey(const ValueKey('alerts_mark_all_read')), findsNothing);
    },
  );

  testWidgets(
    'card shows record metadata with one action; error state retries',
    (tester) async {
      final repo = await pump(tester);
      final r1 = card('r1');
      // Row 1 type, Row 2 commodity, Row 3 ref/qty/price, Row 4 location + action.
      for (final t in [
        'New requirement',
        'DORB',
        '#REQ-REQ-43',
        '100 MT',
        '₹21,000/MT',
        'Kota Mandi',
        'View details',
      ]) {
        expect(
          find.descendant(of: r1, matching: find.text(t)),
          findsOneWidget,
          reason: t,
        );
      }
      // The long message duplicating commodity/quantity is not shown.
      expect(find.textContaining('Buyer posted requirement'), findsNothing);
      expect(
        find.descendant(of: card('t1'), matching: find.text('Task assigned')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card('t1'), matching: find.text('View details')),
        findsOneWidget,
      );
      // Missing optional fields leave no empty labels: the offer has no
      // quantity, price or location.
      final o1 = card('o1');
      expect(find.descendant(of: o1, matching: find.text('New offer')), findsOneWidget);
      expect(find.descendant(of: o1, matching: find.textContaining('MT')), findsNothing);
      expect(
        find.descendant(of: o1, matching: find.byKey(const ValueKey('notif_status_o1'))),
        findsNothing,
      );

      repo.fail = true;
      await tester.tap(find.byKey(const ValueKey('alerts_refresh')));
      await tester.pumpAndSettle();
      expect(
        card('r1'),
        findsOneWidget,
        reason: 'keeps loaded list on refresh failure',
      );
    },
  );

  testWidgets('initial load failure shows error with retry', (tester) async {
    // The existing error state's AppButton is laid out for >= 800dp in tests.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = FakeRepo(sample())..fail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: NotificationCenterScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry Synchronization'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Retry Synchronization'));
    await tester.pumpAndSettle();
    expect(card('r1'), findsOneWidget);
  });

  testWidgets('small 320dp screen with long text: no overflow', (tester) async {
    await pump(
      tester,
      items: [
        alert(
          'x',
          'REQUIREMENT_CREATED',
          today,
          title: 'New Requirement For A Very Long Commodity Name That Wraps',
          message: 'Buyer posted requirement for 100 MT of an extremely long commodity description to test wrapping.',
          payload: {
            'requirementId': 'req-1',
            'quantity': 100,
            'unit': 'MT',
            'targetPrice': 21000,
            'deliveryLocation':
                'FOR Mill Delivery, Kota Mandi Warehouse Complex Gate 4',
          },
        ),
        ...sample(),
      ],
      size: const Size(640, 1136),
      dpr: 2.0,
    );
    expect(tester.takeException(), isNull);
  });
}
