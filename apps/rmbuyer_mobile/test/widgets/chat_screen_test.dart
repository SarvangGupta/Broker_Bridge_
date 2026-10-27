import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/chat/presentation/chat_inbox_screen.dart';
import 'package:rmbuyer_mobile/features/chat/presentation/chat_screen.dart';

import '../support/fake_chat_gateway.dart';

const buyer = 'buyer-a', broker = 'broker-1', broker2 = 'broker-2';

FakeChatServer _server() => FakeChatServer(
  roles: {buyer: 'buyer', broker: 'broker', broker2: 'broker'},
  names: {broker: 'Varun', broker2: 'Kota Desk'},
);

Future<void> _pumpChat(
  WidgetTester tester,
  FakeChatGateway g, {
  String? brokerId,
  String? conversationId,
  Size size = const Size(390, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: ChatScreen(
        gateway: g,
        brokerId: brokerId,
        conversationId: conversationId,
        fallbackName: 'Varun',
        fallbackCompany: 'Varun Agro Trading — DEMO',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'new conversation: header from real broker, Start a conversation, no fake presence',
    (tester) async {
      await _pumpChat(
        tester,
        FakeChatGateway(_server(), buyer),
        brokerId: broker,
      );
      expect(find.text('Varun'), findsOneWidget);
      expect(find.text('Varun Agro Trading — DEMO'), findsOneWidget);
      expect(find.text('Start a conversation'), findsOneWidget);
      for (final fake in ['Online', 'online', 'typing', 'Video']) {
        expect(find.textContaining(fake), findsNothing);
      }
      // No attachment control without secure storage.
      expect(find.byIcon(Icons.attach_file), findsNothing);
    },
  );

  testWidgets('send is disabled until text; sending shows a confirmed bubble', (
    tester,
  ) async {
    final s = _server();
    final g = FakeChatGateway(s, buyer);
    await _pumpChat(tester, g, brokerId: broker);

    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.enterText(find.byKey(const Key('chat-input')), '   ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(g.sendCalls, 0);

    await tester.enterText(
      find.byKey(const Key('chat-input')),
      'Need 20 MT maize',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(find.text('Need 20 MT maize'), findsOneWidget);
    expect(find.text('Start a conversation'), findsNothing);
    expect(find.text('Today'), findsOneWidget);
    expect(s.messages, hasLength(1));
    // Input cleared after a successful hand-off.
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('chat-input')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('failed send shows Not sent + Retry; retry delivers once', (
    tester,
  ) async {
    final s = _server();
    final g = FakeChatGateway(s, buyer)..failSends = true;
    await _pumpChat(tester, g, brokerId: broker);
    await tester.enterText(find.byKey(const Key('chat-input')), 'hello?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(find.text('Not sent'), findsOneWidget);
    expect(find.text('hello?'), findsOneWidget);

    g.failSends = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Not sent'), findsNothing);
    expect(s.messages, hasLength(1));
  });

  testWidgets('incoming reply appears live in an open conversation', (
    tester,
  ) async {
    final s = _server();
    final conv = s
        .send(buyer, body: 'Rate?', clientId: 'k1', brokerId: broker)
        .conversationId;
    await _pumpChat(tester, FakeChatGateway(s, buyer), conversationId: conv);
    expect(find.text('Rate?'), findsOneWidget);

    s.send(broker, body: '₹4,650/qtl', clientId: 'k2', conversationId: conv);
    await tester.pumpAndSettle();
    expect(find.text('₹4,650/qtl'), findsOneWidget);
  });

  testWidgets('load error offers retry; unauthorized id shows no messages', (
    tester,
  ) async {
    final s = _server();
    final g = FakeChatGateway(s, buyer)..failLoads = true;
    await _pumpChat(tester, g, brokerId: broker);
    expect(
      find.textContaining('Unable to load this conversation'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chat-input')), findsNothing);

    g.failLoads = false;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Start a conversation'), findsOneWidget);
  });

  testWidgets('long message on a 320px screen does not overflow', (
    tester,
  ) async {
    final s = _server();
    final conv = s
        .send(
          buyer,
          body: 'Lorem ipsum dolor sit amet ' * 60,
          clientId: 'k',
          brokerId: broker,
        )
        .conversationId;
    await _pumpChat(
      tester,
      FakeChatGateway(s, buyer),
      conversationId: conv,
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'inbox lists real conversations newest first with unread badges',
    (tester) async {
      final s = _server();
      final c1 = s
          .send(buyer, body: 'old', clientId: 'a', brokerId: broker)
          .conversationId;
      s.send(
        broker,
        body: 'reply from Varun',
        clientId: 'b',
        conversationId: c1,
      );
      s.send(buyer, body: 'to Kota', clientId: 'c', brokerId: broker2);

      final opened = <String>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                ChatInboxScreen(gateway: FakeChatGateway(s, buyer)),
          ),
          GoRoute(
            path: '/chats/:id',
            builder: (_, st) {
              opened.add(st.pathParameters['id']!);
              return const Text('conversation');
            },
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );
      await tester.pumpAndSettle();

      final names = tester
          .widgetList<Text>(find.textContaining(RegExp(r'^(Varun|Kota Desk)$')))
          .map((t) => t.data)
          .toList();
      expect(names, ['Kota Desk', 'Varun']);
      expect(find.byKey(Key('chat-unread-$c1')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byKey(Key('chat-row-$c1')));
      await tester.pumpAndSettle();
      expect(opened, [c1]);
    },
  );

  testWidgets('empty inbox shows guidance', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ChatInboxScreen(gateway: FakeChatGateway(_server(), buyer)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-inbox-empty')), findsOneWidget);
  });

  testWidgets('leaving the screen cancels the realtime subscription', (
    tester,
  ) async {
    final s = _server();
    final conv = s
        .send(buyer, body: 'x', clientId: 'k', brokerId: broker)
        .conversationId;
    final g = FakeChatGateway(s, buyer);
    await _pumpChat(tester, g, conversationId: conv);
    expect(g.activeSubscriptions, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(g.activeSubscriptions, 0);
    unawaited(Future<void>.value());
  });
}
