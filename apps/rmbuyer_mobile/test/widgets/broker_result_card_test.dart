import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/core/services/contact_launcher_service.dart';
import 'package:rmbuyer_mobile/features/search/domain/broker_model.dart';
import 'package:rmbuyer_mobile/features/search/presentation/widgets/broker_result_card.dart';
import 'package:url_launcher/url_launcher.dart';

/// Records launched URIs; never touches the platform.
class _Launches {
  final List<Uri> uris = [];
  bool result = true;
  Completer<void>? gate;

  ContactLauncherService service() => ContactLauncherService(
    launchUrlFn: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
      uris.add(uri);
      if (gate != null) await gate!.future;
      return result;
    },
  );
}

const _full = BrokerModel(
  id: 'b-1',
  name: 'Rajesh Verma',
  companyName: 'Jaipur Grain Broker Desk',
  location: 'Jaipur Mandi, Rajasthan',
  mobile: '+91 98290 12345',
  trustScore: 98,
  isVerified: true,
  commoditiesHandled: ['Soybean', 'Chana', 'Wheat'],
);

Widget _router(
  BrokerModel broker, {
  ContactLauncherService? launcher,
  List<String>? pushes,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: ListView(
            children: [
              BrokerResultCard(broker: broker, contactLauncher: launcher),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/brokers/:id',
        builder: (_, state) {
          pushes?.add(state.pathParameters['id']!);
          return Text('profile ${state.pathParameters['id']}');
        },
      ),
      GoRoute(
        path: '/chats/broker/:brokerId',
        builder: (_, state) {
          pushes?.add('chat:${state.pathParameters['brokerId']}');
          return Text('chat ${(state.extra as BrokerModel?)?.name}');
        },
      ),
    ],
  );
  return MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router);
}

void main() {
  testWidgets(
    'complete data: identity, verified badge, real attributes, three actions',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_router(_full));
      expect(find.text('R'), findsOneWidget);
      expect(find.text('Rajesh Verma'), findsOneWidget);
      expect(find.text('Verified Broker'), findsOneWidget);
      expect(find.text('Unverified Broker'), findsNothing);
      expect(find.text('Trust Score: 98%'), findsOneWidget);
      expect(find.text('Jaipur Grain Broker Desk'), findsOneWidget);
      expect(find.text('Jaipur Mandi, Rajasthan'), findsOneWidget);
      expect(find.text('Soybean, Chana, Wheat'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      // No invented metrics.
      for (final fake in [
        'Deals Completed',
        'Active Buyers',
        'Response Rate',
        'Years Exp.',
      ]) {
        expect(find.textContaining(fake), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'partial live row: placeholders, default commodities and trust hidden; unverified neutral',
    (tester) async {
      final broker = BrokerModel.fromMap({
        'id': 'b-2',
        'name': 'Placeholder Desk',
      });
      await tester.pumpWidget(_router(broker));
      expect(find.text('Mandi Trading Floor'), findsNothing);
      expect(find.text('Licensed Mandi Broker Desk'), findsNothing);
      expect(find.textContaining('Soybean'), findsNothing);
      expect(find.text('Verified Broker'), findsNothing);
      expect(find.text('Unverified Broker'), findsOneWidget);
      expect(find.textContaining('Trust'), findsNothing);
    },
  );

  testWidgets('long name and firm do not overflow at 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final broker = BrokerModel(
      id: 'b-3',
      name: 'Shri Venkateshwara Agricultural Commodity Brokerage Services ' * 2,
      companyName:
          'An Extremely Long Registered Trading Firm Name Private Limited',
      mobile: '9829012345',
      isVerified: true,
    );
    await tester.pumpWidget(_router(broker));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Call launches tel: with the stored number and does not open the profile',
    (tester) async {
      final l = _Launches();
      final pushes = <String>[];
      await tester.pumpWidget(
        _router(_full, launcher: l.service(), pushes: pushes),
      );
      await tester.tap(find.byKey(const Key('card-call')));
      await tester.pumpAndSettle();
      expect(l.uris.single.toString(), 'tel:+919829012345');
      expect(pushes, isEmpty);
    },
  );

  testWidgets(
    'WhatsApp opens wa.me with country code and an unsent prefilled message',
    (tester) async {
      final l = _Launches();
      await tester.pumpWidget(
        _router(
          const BrokerModel(id: 'b-4', name: 'Asha', mobile: '98290 12345'),
          launcher: l.service(),
        ),
      );
      await tester.tap(find.byKey(const Key('card-whatsapp')));
      await tester.pumpAndSettle();
      final uri = l.uris.single;
      expect(uri.host, 'wa.me');
      expect(uri.path, '/919829012345');
      expect(uri.queryParameters['text'], contains('Hello Asha'));
    },
  );

  testWidgets(
    'missing / unauthorized number: Call and WhatsApp disabled, explain, never launch',
    (tester) async {
      final l = _Launches();
      await tester.pumpWidget(
        _router(
          const BrokerModel(id: 'b-5', name: 'No Phone'),
          launcher: l.service(),
        ),
      );
      await tester.tap(find.byKey(const Key('card-call')));
      await tester.pump();
      expect(find.text(brokerContactPendingMessage), findsOneWidget);
      await tester.tap(find.byKey(const Key('card-whatsapp')));
      await tester.pump();
      expect(l.uris, isEmpty);
    },
  );

  testWidgets('invalid number reports failure instead of claiming success', (
    tester,
  ) async {
    final l = _Launches();
    await tester.pumpWidget(
      _router(
        const BrokerModel(id: 'b-6', name: 'Bad', mobile: '---'),
        launcher: l.service(),
      ),
    );
    await tester.tap(find.byKey(const Key('card-whatsapp')));
    await tester.pumpAndSettle();
    expect(l.uris, isEmpty);
    expect(find.text('Could not open WhatsApp.'), findsOneWidget);
  });

  testWidgets('Chat opens this broker\'s chat route once, not the profile', (
    tester,
  ) async {
    final pushes = <String>[];
    await tester.pumpWidget(
      _router(_full, launcher: _Launches().service(), pushes: pushes),
    );
    await tester.tap(find.byKey(const Key('card-chat')));
    await tester.tap(find.byKey(const Key('card-chat')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(pushes, ['chat:b-1']);
    expect(find.text('chat Rajesh Verma'), findsOneWidget);
  });

  testWidgets('repeated Call taps launch once while pending', (tester) async {
    final l = _Launches()..gate = Completer<void>();
    await tester.pumpWidget(_router(_full, launcher: l.service()));
    await tester.tap(find.byKey(const Key('card-call')));
    await tester.tap(find.byKey(const Key('card-call')));
    await tester.pump();
    expect(l.uris, hasLength(1));
    l.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('card tap opens the broker profile', (tester) async {
    await tester.pumpWidget(_router(_full));
    await tester.tap(find.text('Rajesh Verma'));
    await tester.pumpAndSettle();
    expect(find.text('profile b-1'), findsOneWidget);
  });
}
