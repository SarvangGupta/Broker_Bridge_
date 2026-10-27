import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/core/services/contact_launcher_service.dart';
import 'package:rmbuyer_mobile/features/search/data/search_repository.dart';
import 'package:rmbuyer_mobile/features/search/domain/broker_model.dart';
import 'package:rmbuyer_mobile/features/search/presentation/broker_profile_screen.dart';
import 'package:rmbuyer_mobile/features/search/presentation/widgets/broker_result_card.dart';
import 'package:url_launcher/url_launcher.dart';

class _FakeRepo extends SearchRepository {
  BrokerModel? broker;
  bool fail = false;
  Completer<void>? gate;
  int calls = 0;
  _FakeRepo() : super(client: null);

  @override
  Future<BrokerModel?> getBrokerById(String id) async {
    calls++;
    if (gate != null) await gate!.future;
    if (fail) throw Exception('offline');
    return broker;
  }
}

const _verified = BrokerModel(
  id: 'b354958e-779a-41f2-b7a3-5899eca32e32',
  name: 'Rajesh Verma',
  companyName: 'Jaipur Grain Broker Desk',
  companyGst: '08AAACJ1234A1Z1',
  location: 'Jaipur Mandi, Rajasthan',
  mobile: '+919829012345',
  trustScore: 98,
  isVerified: true,
  commoditiesHandled: ['Yellow Soybean', 'Desi Chana', 'Wheat (Sharbati)'],
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());
}

Future<void> _pump(
  WidgetTester tester, {
  BrokerModel? initial,
  SearchRepository? repo,
  ContactLauncherService? launcher,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: BrokerProfileScreen(
        brokerId: initial?.id ?? 'b-x',
        initialBroker: initial,
        searchRepository: repo ?? _FakeRepo(),
        contactLauncher: launcher,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'verified broker: identity, about, commodities, location; no invented metrics',
    (tester) async {
      _size(tester, const Size(400, 1400));
      await _pump(tester, initial: _verified);

      expect(find.text('Broker Profile'), findsOneWidget);
      expect(
        find.text('Rajesh Verma'),
        findsNWidgets(2),
      ); // heading + contact person
      expect(
        find.text('Jaipur Grain Broker Desk'),
        findsNWidgets(2),
      ); // header + business name
      expect(
        find.text('Verified Broker'),
        findsNWidgets(2),
      ); // badge + status row
      expect(find.text('Trust Score: 98%'), findsOneWidget);
      expect(find.text('08AAACJ1234A1Z1'), findsOneWidget);
      expect(find.text('Deals In (Commodities)'), findsOneWidget);
      expect(find.text('Yellow Soybean'), findsOneWidget);
      expect(find.text('Wheat (Sharbati)'), findsOneWidget);
      expect(find.text('Jaipur Mandi, Rajasthan'), findsOneWidget);

      expect(
        find.byKey(const Key('broker-metrics-unavailable')),
        findsOneWidget,
      );
      for (final fake in [
        'Years Experience',
        'Deals Completed',
        'Average Rating',
        'Active Clients',
        'reviews)',
        'View on Map',
        'Address',
        'Share',
      ]) {
        expect(find.textContaining(fake), findsNothing);
      }
      expect(find.text('Post Requirement with this Broker'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'contact actions are icon-only with semantics and launch real destinations',
    (tester) async {
      _size(tester, const Size(400, 1400));
      final uris = <Uri>[];
      final launcher = ContactLauncherService(
        launchUrlFn:
            (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
              uris.add(uri);
              return true;
            },
      );
      await _pump(tester, initial: _verified, launcher: launcher);

      expect(find.text('Call'), findsNothing);
      expect(find.text('WhatsApp'), findsNothing);
      expect(find.text('Chat'), findsNothing);
      expect(find.bySemanticsLabel('Call broker'), findsOneWidget);
      expect(find.bySemanticsLabel('WhatsApp broker'), findsOneWidget);
      expect(find.bySemanticsLabel('Chat with broker'), findsOneWidget);

      await tester.tap(find.byKey(const Key('broker-call')));
      await tester.pumpAndSettle();
      expect(uris.last.toString(), 'tel:+919829012345');

      await tester.tap(find.byKey(const Key('broker-whatsapp')));
      await tester.pumpAndSettle();
      expect(uris.last.host, 'wa.me');
      expect(uris.last.path, '/919829012345');
      expect(uris, hasLength(2));
    },
  );

  testWidgets('no number: Call/WhatsApp disabled, explain, never launch', (
    tester,
  ) async {
    final uris = <Uri>[];
    final launcher = ContactLauncherService(
      launchUrlFn: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        uris.add(uri);
        return true;
      },
    );
    await _pump(
      tester,
      initial: const BrokerModel(id: 'b-no-phone', name: 'Desk Without Mobile'),
      launcher: launcher,
    );
    expect(find.bySemanticsLabel('Call broker unavailable'), findsOneWidget);
    await tester.tap(find.byKey(const Key('broker-call')));
    await tester.pump();
    expect(find.text(brokerContactPendingMessage), findsOneWidget);
    await tester.tap(find.byKey(const Key('broker-whatsapp')));
    await tester.pump();
    expect(uris, isEmpty);
  });

  testWidgets(
    'live row at 320px: no placeholders, unverified, empty commodities, no overflow',
    (tester) async {
      _size(tester, const Size(320, 700));
      final broker = BrokerModel.fromMap({
        'id': 'live-1',
        'name': 'A Very Long Broker Desk Name That Should Wrap Cleanly Across Lines',
        'mobile': '+919800000000',
      });
      await _pump(tester, initial: broker);

      expect(find.text('Business Name'), findsNothing);
      expect(find.text('Mandi Trading Floor'), findsNothing);
      expect(find.text('Licensed Mandi Broker Desk'), findsNothing);
      expect(find.textContaining('Soybean'), findsNothing);
      expect(find.text('Location'), findsNothing);
      expect(find.text('Unverified Broker'), findsOneWidget);
      expect(find.text('Not verified'), findsOneWidget);
      expect(find.text('Verified Broker'), findsNothing);
      expect(find.byKey(const Key('broker-no-commodities')), findsOneWidget);
      expect(find.text('Post Requirement with this Broker'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Post Requirement passes only the broker and blank terms, once', (
    tester,
  ) async {
    final pushed = <Map<String, dynamic>?>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const BrokerProfileScreen(
            brokerId: 'x',
            initialBroker: _verified,
          ),
        ),
        GoRoute(
          path: '/requirements/new',
          builder: (_, state) {
            pushed.add(state.extra as Map<String, dynamic>?);
            return Text('form ${state.uri.query}');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();

    final cta = find.byKey(const Key('broker-post-requirement'));
    await tester.tap(cta);
    await tester.tap(cta, warnIfMissed: false);
    await tester.pumpAndSettle();

    // No commodity or other query params prefilled.
    expect(find.text('form '), findsOneWidget);
    expect(pushed, hasLength(1));
    expect(pushed.single, {
      'brokerId': _verified.id,
      'brokerName': 'Rajesh Verma',
      'blankCommercialTerms': true,
    });
  });

  testWidgets('Chat icon opens the chat route for this exact broker, once', (
    tester,
  ) async {
    final pushed = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const BrokerProfileScreen(
            brokerId: 'x',
            initialBroker: _verified,
          ),
        ),
        GoRoute(
          path: '/chats/broker/:brokerId',
          builder: (_, state) {
            pushed.add(state.pathParameters['brokerId']!);
            return const Text('chat');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('broker-chat')));
    await tester.tap(find.byKey(const Key('broker-chat')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(pushed, [_verified.id]);

    // Back returns to the profile.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Broker Profile'), findsOneWidget);
  });

  testWidgets(
    'loading, missing record, network error with retry, and refresh',
    (tester) async {
      final repo = _FakeRepo()..gate = Completer<void>();
      await _pump(tester, repo: repo, settle: false);
      await tester.pump();
      expect(find.text('Loading authorized broker profile...'), findsOneWidget);

      repo.gate!.complete();
      repo.gate = null;
      await tester.pumpAndSettle();
      expect(
        find.text('Broker profile not found or no longer authorized.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('broker-post-requirement')), findsNothing);

      repo.fail = true;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Unable to load broker profile. Please check your connection.',
        ),
        findsOneWidget,
      );

      repo
        ..fail = false
        ..broker = _verified;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(find.text('Jaipur Grain Broker Desk'), findsNWidgets(2));

      final before = repo.calls;
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(repo.calls, before + 1);
    },
  );
}
