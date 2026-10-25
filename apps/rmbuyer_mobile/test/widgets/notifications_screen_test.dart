import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/notifications/presentation/buyer_notifications_screen.dart';

import '../support/fake_notifications_repository.dart';

/// Pumps the screen behind a stub router; returns the locations navigated to.
Future<List<String>> _pump(
  WidgetTester tester,
  FakeNotificationsRepository repo,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  final visited = <String>[];
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => BuyerNotificationsScreen(repository: repo),
      ),
      GoRoute(
        path: '/requirements',
        builder: (_, _) {
          visited.add('/requirements');
          return const Scaffold(body: Text('requirements-list'));
        },
      ),
      GoRoute(
        path: '/requirements/:id',
        builder: (_, state) {
          visited.add('/requirements/${state.pathParameters['id']}');
          return const Scaffold(body: Text('requirement-detail'));
        },
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
  );
  router.push('/notifications');
  await tester.pumpAndSettle();
  return visited;
}

void main() {
  testWidgets(
    'renders repository rows, unread styling and count; no sample rows',
    (tester) async {
      await _pump(tester, FakeNotificationsRepository());

      expect(find.text('Contract Signature Required: Maize'), findsOneWidget);
      expect(find.text('New Deal Draft Created: Maize'), findsOneWidget);
      expect(find.text('Commercial Proposal: Maize'), findsOneWidget);
      expect(
        find.byKey(const Key('notification-unread-n-confirm')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('notification-unread-n-req')), findsNothing);
      expect(find.text('2 unread'), findsOneWidget);
      expect(find.text('Confirmation'), findsOneWidget);
      // The old hardcoded rows never appear.
      expect(find.text('Counterparty Quote Received'), findsNothing);
      expect(find.text('Shipment Dispatched'), findsNothing);
    },
  );

  testWidgets('empty list shows the empty state, never sample data', (
    tester,
  ) async {
    await _pump(tester, FakeNotificationsRepository(rows: []));
    expect(find.text('No Notifications'), findsOneWidget);
    expect(find.byKey(const Key('notifications-mark-all')), findsNothing);
  });

  testWidgets('load failure shows error with retry; retry loads real rows', (
    tester,
  ) async {
    final repo = FakeNotificationsRepository()
      ..loadError = Exception('offline');
    await _pump(tester, repo);
    expect(find.text('Unable to load notifications.'), findsOneWidget);
    expect(find.text('Counterparty Quote Received'), findsNothing);

    repo.loadError = null;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Contract Signature Required: Maize'), findsOneWidget);
  });

  testWidgets('duplicate IDs from the backend are shown once', (tester) async {
    final rows = sampleRows()
      ..add({...sampleRows().first, 'title': 'Duplicate copy'});
    await _pump(tester, FakeNotificationsRepository(rows: rows));
    expect(find.text('Duplicate copy'), findsNothing);
    expect(find.byKey(const Key('notification-n-confirm')), findsOneWidget);
  });

  testWidgets(
    'tapping an owned-requirement notification opens that requirement',
    (tester) async {
      final repo = FakeNotificationsRepository();
      final visited = await _pump(tester, repo);
      await tester.tap(find.text('Commercial Proposal: Maize'));
      await tester.pumpAndSettle();
      expect(visited, ['/requirements/$reqId']);
      expect(repo.marked, isEmpty); // already read: no request sent
    },
  );

  testWidgets(
    'a requirement the Buyer does not own shows the unavailable detail',
    (tester) async {
      final rows = [
        {
          ...sampleRows()[2],
          'payload': {'requirementId': otherReqId},
        },
      ];
      final visited = await _pump(
        tester,
        FakeNotificationsRepository(rows: rows),
      );
      await tester.tap(find.text('Commercial Proposal: Maize'));
      await tester.pumpAndSettle();
      expect(visited, isEmpty);
      expect(find.byKey(const Key('notification-target-note')), findsOneWidget);
      expect(find.textContaining("you don't have access"), findsOneWidget);
    },
  );

  testWidgets(
    'deal notification marks read, then shows detail instead of a deal screen',
    (tester) async {
      final repo = FakeNotificationsRepository();
      final visited = await _pump(tester, repo);
      await tester.tap(find.text('New Deal Draft Created: Maize'));
      await tester.pumpAndSettle();

      expect(repo.marked, ['n-deal']);
      expect(visited, isEmpty);
      expect(find.byKey(const Key('notification-detail')), findsOneWidget);
      expect(
        find.text("This item can't be opened in the app yet."),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('1 unread'), findsOneWidget);
      expect(find.byKey(const Key('notification-unread-n-deal')), findsNothing);
    },
  );

  testWidgets('failed mark-as-read keeps the row unread and says so', (
    tester,
  ) async {
    final repo = FakeNotificationsRepository()..markError = Exception('denied');
    await _pump(tester, repo);
    await tester.tap(find.text('New Deal Draft Created: Maize'));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't update read status. Please try again."),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notification-unread-n-deal')), findsOneWidget);
    expect(find.text('2 unread'), findsOneWidget);
  });

  testWidgets('rapid repeated taps send one mark-as-read request', (
    tester,
  ) async {
    final repo = FakeNotificationsRepository()..markGate = Completer<void>();
    await _pump(tester, repo);
    await tester.tap(find.text('New Deal Draft Created: Maize'));
    await tester.pump();
    await tester.tap(
      find.text('New Deal Draft Created: Maize'),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(repo.marked, ['n-deal']);
    repo.markGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'mark all read updates rows and count after the server confirms',
    (tester) async {
      final repo = FakeNotificationsRepository();
      await _pump(tester, repo);
      await tester.tap(find.byKey(const Key('notifications-mark-all')));
      await tester.pumpAndSettle();
      expect(repo.markAllCalls, 1);
      expect(find.text('0 unread'), findsOneWidget);
      expect(find.byKey(const Key('notifications-mark-all')), findsNothing);
    },
  );

  testWidgets('Unread filter shows only unread rows', (tester) async {
    await _pump(tester, FakeNotificationsRepository());
    await tester.tap(find.byKey(const Key('notifications-filter-unread')));
    await tester.pumpAndSettle();
    expect(find.text('Commercial Proposal: Maize'), findsNothing);
    expect(find.text('Contract Signature Required: Maize'), findsOneWidget);
  });

  testWidgets(
    'missing title falls back to the event label; unknown type shows detail',
    (tester) async {
      final rows = [
        {
          'id': 'n-x',
          'title': '',
          'message': 'Something changed',
          'event_type': 'BRAND_NEW_EVENT',
          'is_read': true,
        },
      ];
      await _pump(tester, FakeNotificationsRepository(rows: rows));
      expect(find.text('Update'), findsWidgets);
      await tester.tap(find.text('Something changed'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notification-detail')), findsOneWidget);
      expect(find.byKey(const Key('notification-target-note')), findsNothing);
    },
  );

  testWidgets('pull to refresh reloads from the repository', (tester) async {
    final repo = FakeNotificationsRepository();
    await _pump(tester, repo);
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(repo.loads, 2);
  });
}
