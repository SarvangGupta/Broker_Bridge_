import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/features/brokers/domain/seller_broker_model.dart';
import 'package:rmseller_mobile/features/brokers/presentation/broker_profile_screen.dart';
import 'package:rmseller_mobile/features/chat/domain/chat_models.dart';
import 'package:rmseller_mobile/features/chat/presentation/chat_controller.dart';
import 'package:rmseller_mobile/features/chat/presentation/chat_inbox_screen.dart';
import 'package:rmseller_mobile/features/chat/presentation/chat_screen.dart';

import '../support/fake_chat_gateway.dart';

// RM-CHAT-BIDIRECTIONAL-E2E-01, seller side. Fake server only; no Supabase.

const broker = 'e2e-broker-01', seller = 'e2e-seller-01', buyer = 'e2e-buyer-01', seller2 = 'e2e-seller-02';

FakeChatServer server() => FakeChatServer(
      roles: {broker: 'broker', seller: 'seller', seller2: 'seller', buyer: 'buyer'},
      names: {broker: 'E2E Broker', seller: 'E2E Seller', buyer: 'E2E Buyer'},
      relations: {'$broker:$seller'},
    );

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('D seller starts a chat; broker replies; both keep the same history', () async {
    final s = server();
    final mine = ChatController(gateway: FakeChatGateway(s, seller), brokerId: broker);
    await mine.init();
    expect(mine.isNewConversation, isTrue);
    mine.send('Lot ready for dispatch');
    await settle();
    final conv = mine.conversationId!;
    expect(s.notifications.last.user, broker);

    final theirs = ChatController(gateway: FakeChatGateway(s, broker), conversationId: conv);
    await theirs.init();
    theirs.send('Buyer wants 40 MT');
    await settle();
    mine.send('Confirmed');
    await settle();

    expect(mine.messages.map((m) => m.body), ['Lot ready for dispatch', 'Buyer wants 40 MT', 'Confirmed']);
    expect(mine.messages.map((m) => m.id), theirs.messages.map((m) => m.id));

    // Reopen: history comes back from the server in the same order.
    final reopened = ChatController(gateway: FakeChatGateway(s, seller), brokerId: broker);
    await reopened.init();
    expect(reopened.conversationId, conv);
    expect(reopened.messages.map((m) => m.id), mine.messages.map((m) => m.id));
    for (final c in [mine, theirs, reopened]) {
      c.dispose();
    }
  });

  test('B broker-initiated chat reaches the seller inbox and the seller replies', () async {
    final s = server();
    final b = ChatController(gateway: FakeChatGateway(s, broker), counterpartId: seller);
    await b.init();
    b.send('Can you hold the lot?');
    await settle();
    final row = (await FakeChatGateway(s, seller).inbox()).single;
    expect(row.counterpartRole, 'broker');
    expect(row.unreadCount, 1);

    final mine = ChatController(gateway: FakeChatGateway(s, seller), conversationId: row.id);
    await mine.init();
    mine.send('Yes, until Friday');
    await settle();
    expect(b.messages.map((m) => m.body), ['Can you hold the lot?', 'Yes, until Friday']);
    b.dispose();
    mine.dispose();
  });

  test('seller cannot reach a buyer or another seller', () async {
    final s = server();
    for (final target in [buyer, seller2]) {
      final c = ChatController(gateway: FakeChatGateway(s, seller), brokerId: target);
      await c.init();
      c.send('direct?');
      await settle();
      expect(c.messages.single.delivery, ChatDelivery.failed);
      c.dispose();
    }
    expect(s.conversations, isEmpty);
  });

  test('Flow C: seller starts a chat from its offer with the assigned broker; reopening finds it', () async {
    final s = FakeChatServer(
      roles: {broker: 'broker', seller: 'seller', seller2: 'seller', buyer: 'buyer'},
      offers: {'lot-1': (broker: broker, clients: {seller})},
    );
    final mine = ChatController(gateway: FakeChatGateway(s, seller), brokerId: broker, availabilityId: 'lot-1');
    await mine.init();
    mine.send('Is my lot matched?');
    await settle();
    final theirs = ChatController(gateway: FakeChatGateway(s, broker), conversationId: mine.conversationId);
    await theirs.init();
    expect(theirs.summary!.contextLabel, 'Offer · lot-1');
    theirs.send('Yes, a buyer is interested');
    await settle();
    final reopened = ChatController(gateway: FakeChatGateway(s, seller), brokerId: broker, availabilityId: 'lot-1');
    await reopened.init();
    expect(reopened.conversationId, mine.conversationId);
    expect(reopened.messages.map((m) => m.body), ['Is my lot matched?', 'Yes, a buyer is interested']);

    // Another seller cannot use this offer's chat.
    final other = ChatController(gateway: FakeChatGateway(s, seller2), brokerId: broker, availabilityId: 'lot-1');
    await other.init();
    other.send('x');
    await settle();
    expect(other.messages.single.delivery, ChatDelivery.failed);
    for (final c in [mine, theirs, reopened, other]) {
      c.dispose();
    }
  });

  testWidgets('seller inbox shows the broker conversation and opens it', (tester) async {
    final s = server();
    final conv = s.send(broker, body: 'Price update', clientId: 'k', counterpartId: seller).conversationId;
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => ChatInboxScreen(gateway: FakeChatGateway(s, seller))),
      GoRoute(
        path: '/chats/:id',
        builder: (_, st) => ChatScreen(gateway: FakeChatGateway(s, seller), conversationId: st.pathParameters['id']),
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('E2E Broker'), findsOneWidget);
    await tester.tap(find.byKey(Key('chat-row-$conv')));
    await tester.pumpAndSettle();
    expect(find.text('Price update'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('chat-input')), 'Noted');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(s.messages.last.senderId, seller);
    expect(s.messages.last.conversationId, conv);
  });

  testWidgets('Chat with Broker opens in-app chat; the phone action does not', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const b = SellerBrokerModel(
      id: broker,
      name: 'E2E Broker',
      companyName: 'E2E Desk',
      location: 'Kota',
      trustScore: 90,
      isVerified: true,
      mobile: '9000000001',
    );
    final pushed = <String>[];
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => BrokerProfileScreen(brokerId: b.id, initialBroker: b)),
      GoRoute(
        path: '/chats/broker/:id',
        builder: (_, st) {
          pushed.add(st.uri.path);
          return const Text('chat opened');
        },
      ),
      GoRoute(path: '/communication/broker/:id', builder: (_, st) {
        pushed.add(st.uri.path);
        return const Text('desk opened');
      }),
    ]);
    await tester.pumpWidget(MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Call Desk'), findsOneWidget);
    expect(find.text('Chat with Broker'), findsOneWidget);
    // The phone action launches the dialler only; it never routes to chat.
    await tester.tap(find.text('Call Desk'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(pushed, isEmpty);

    await tester.ensureVisible(find.byKey(const ValueKey('chat_with_broker_button')));
    await tester.tap(find.byKey(const ValueKey('chat_with_broker_button')));
    await tester.pumpAndSettle();
    expect(pushed, ['/chats/broker/$broker']);
    expect(find.text('chat opened'), findsOneWidget);
  });
}
