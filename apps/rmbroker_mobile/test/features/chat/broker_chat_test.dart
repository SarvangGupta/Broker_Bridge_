import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmbroker_mobile/features/chat/presentation/chat_controller.dart';
import 'package:rmbroker_mobile/features/chat/presentation/chat_inbox_screen.dart';
import 'package:rmbroker_mobile/features/chat/presentation/chat_screen.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_model.dart';

import '../../support/fake_chat_gateway.dart';

const buyerA = 'buyer-a', buyerB = 'buyer-b', me = 'broker-1', other = 'broker-2';

FakeChatServer _server() => FakeChatServer(
  roles: {buyerA: 'buyer', buyerB: 'buyer', me: 'broker', other: 'broker'},
  names: {buyerA: 'Asha Feeds', buyerB: 'Bharat Dairy', me: 'Varun'},
);

void main() {
  test('broker sees the buyer message and replies into the same conversation', () async {
    final s = _server();
    final conv = s.send(buyerA, body: 'Need 20 MT maize', clientId: 'k1', brokerId: me).conversationId;
    expect(s.notifications.single.user, me);

    final c = ChatController(gateway: FakeChatGateway(s, me), conversationId: conv);
    await c.init();
    expect(c.summary!.counterpartName, 'Asha Feeds');
    expect(c.messages.single.body, 'Need 20 MT maize');

    c.send('Available at ₹2,180/qtl');
    await Future<void>.delayed(Duration.zero);
    expect(s.messages.map((m) => m.senderId), [buyerA, me]);
    expect(s.messages.last.conversationId, conv);
    expect(s.notifications.last.user, buyerA);
    c.dispose();
  });

  test('broker cannot open or post into another broker\'s or buyer\'s conversation', () async {
    final s = _server();
    final foreign = s.send(buyerB, body: 'private', clientId: 'k', brokerId: other).conversationId;
    final c = ChatController(gateway: FakeChatGateway(s, me), conversationId: foreign);
    await c.init();
    expect(c.error, isNotNull);
    expect(c.messages, isEmpty);
    expect(
      () => s.send(me, body: 'x', clientId: 'k2', conversationId: foreign),
      throwsStateError,
    );
    // Brokers cannot initiate conversations with anyone.
    expect(() => s.send(me, body: 'x', clientId: 'k3', brokerId: other), throwsStateError);
    c.dispose();
  });

  test('chat notifications route to the conversation and are actionable', () {
    const id = '0b5f4a2e-1c3d-4e5f-8a9b-0c1d2e3f4a5b';
    final n = BrokerNotification.fromJson({
      'id': 'n1',
      'user_id': me,
      'event_type': 'CHAT_MESSAGE',
      'title': 'New message from Asha',
      'message': 'Open the conversation to read it.',
      'action_url': '/chats/$id',
      'payload': {'conversationId': id, 'messageId': 'm1'},
      'created_at': '2026-10-26T09:00:00Z',
    });
    expect(n.isActionable, isTrue);
    expect(n.resolvedRoute, '/chats/$id');
  });

  testWidgets('inbox shows only my buyer conversations and opens the thread', (tester) async {
    final s = _server();
    final mine = s.send(buyerA, body: 'hello', clientId: 'a', brokerId: me).conversationId;
    s.send(buyerB, body: 'not for me', clientId: 'b', brokerId: other);

    final opened = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => ChatInboxScreen(gateway: FakeChatGateway(s, me))),
        GoRoute(
          path: '/chats/:id',
          builder: (_, st) {
            opened.add(st.pathParameters['id']!);
            return ChatScreen(gateway: FakeChatGateway(s, me), conversationId: st.pathParameters['id']);
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Asha Feeds'), findsOneWidget);
    expect(find.text('Bharat Dairy'), findsNothing);
    expect(find.textContaining('not for me'), findsNothing);
    expect(find.byKey(Key('chat-unread-$mine')), findsOneWidget);

    await tester.tap(find.byKey(Key('chat-row-$mine')));
    await tester.pumpAndSettle();
    expect(opened, [mine]);
    expect(find.text('hello'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('chat-input')), 'Got it, sending rates');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(s.messages.last.senderId, me);
    expect(find.text('Got it, sending rates'), findsOneWidget);
  });
}
