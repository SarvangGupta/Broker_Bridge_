import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/chat/domain/chat_models.dart';
import 'package:rmbuyer_mobile/features/chat/presentation/chat_controller.dart';
import 'package:rmbuyer_mobile/features/notifications/domain/buyer_notification_model.dart';

import '../support/fake_chat_gateway.dart';

const buyerA = 'buyer-a',
    buyerB = 'buyer-b',
    broker = 'broker-1',
    seller = 'seller-1';

FakeChatServer _server() => FakeChatServer(
  roles: {buyerA: 'buyer', buyerB: 'buyer', broker: 'broker', seller: 'seller'},
  names: {buyerA: 'Asha', broker: 'Varun'},
);

Future<ChatController> _open(
  FakeChatGateway g, {
  String? brokerId,
  String? conversationId,
  int pageSize = 50,
}) async {
  final c = ChatController(
    gateway: g,
    brokerId: brokerId,
    conversationId: conversationId,
    pageSize: pageSize,
  );
  await c.init();
  return c;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('conversation identity', () {
    test(
      'no conversation: new state, first send creates it, reopen reuses it',
      () async {
        final s = _server();
        final g = FakeChatGateway(s, buyerA);
        final c = await _open(g, brokerId: broker);
        expect(c.isNewConversation, isTrue);
        expect(s.conversations, isEmpty);

        expect(c.send('Hello, need 20 MT soybean'), isTrue);
        await _settle();
        expect(s.conversations, hasLength(1));
        final convId = c.conversationId!;
        expect(s.conversations[convId], (buyer: buyerA, broker: broker));
        expect(c.messages.single.delivery, ChatDelivery.sent);
        c.dispose();

        final again = await _open(g, brokerId: broker);
        expect(again.conversationId, convId);
        expect(again.isNewConversation, isFalse);
        expect(again.messages.single.body, 'Hello, need 20 MT soybean');
        again.dispose();
      },
    );

    test(
      'concurrent first sends from two screens yield one conversation',
      () async {
        final s = _server();
        final g = FakeChatGateway(s, buyerA)..sendGate = Completer<void>();
        final c1 = await _open(g, brokerId: broker);
        final c2 = await _open(g, brokerId: broker);
        c1.send('one');
        c2.send('two');
        g.sendGate!.complete();
        await _settle();
        expect(s.conversations, hasLength(1));
        expect(c1.conversationId, c2.conversationId);
        expect(s.messages, hasLength(2));
        c1.dispose();
        c2.dispose();
      },
    );
  });

  group('end-to-end exchange (fake server)', () {
    test(
      'buyer message reaches broker live; reply reaches buyer; both persist',
      () async {
        final s = _server();
        final buyerSide = await _open(
          FakeChatGateway(s, buyerA),
          brokerId: broker,
        );
        buyerSide.send('Rate for Jaipur delivery?');
        await _settle();
        final convId = buyerSide.conversationId!;

        final brokerGw = FakeChatGateway(s, broker);
        final brokerSide = await _open(brokerGw, conversationId: convId);
        expect(brokerSide.summary!.counterpartName, 'Asha');
        expect(brokerSide.messages.single.body, 'Rate for Jaipur delivery?');

        brokerSide.send('₹4,650/qtl FOR Jaipur');
        await _settle();
        // Delivered to the open buyer screen via the subscription.
        expect(buyerSide.messages.map((m) => m.body), [
          'Rate for Jaipur delivery?',
          '₹4,650/qtl FOR Jaipur',
        ]);
        expect(buyerSide.messages.last.senderId, broker);

        // "App restart": fresh controllers reload persisted history in order.
        buyerSide.dispose();
        brokerSide.dispose();
        final reopened = await _open(
          FakeChatGateway(s, buyerA),
          conversationId: convId,
        );
        expect(reopened.messages.map((m) => m.senderId), [buyerA, broker]);
        reopened.dispose();
      },
    );

    test(
      'realtime echo of my own send does not duplicate the bubble',
      () async {
        final s = _server();
        final c = await _open(FakeChatGateway(s, buyerA), brokerId: broker);
        c.send('first');
        await _settle();
        c.send('second'); // subscription is live now; server echoes it
        await _settle();
        expect(c.messages.map((m) => m.body), ['first', 'second']);
        c.dispose();
      },
    );
  });

  group('sending', () {
    test(
      'empty, whitespace and over-limit messages are rejected locally',
      () async {
        final g = FakeChatGateway(_server(), buyerA);
        final c = await _open(g, brokerId: broker);
        expect(c.send(''), isFalse);
        expect(c.send('   \n '), isFalse);
        expect(c.send('x' * (kChatMaxLength + 1)), isFalse);
        expect(g.sendCalls, 0);
        expect(c.messages, isEmpty);
        c.dispose();
      },
    );

    test(
      'failed send stays visible as failed; retry reuses key; no duplicates',
      () async {
        final s = _server();
        final g = FakeChatGateway(s, buyerA)..failSends = true;
        final c = await _open(g, brokerId: broker);
        c.send('price?');
        await _settle();
        final failed = c.messages.single;
        expect(failed.delivery, ChatDelivery.failed);
        expect(s.messages, isEmpty);

        g.failSends = false;
        c.retry(failed);
        c.retry(failed); // second tap while pending is ignored
        await _settle();
        expect(c.messages.single.delivery, ChatDelivery.sent);
        expect(c.messages.single.clientMessageId, failed.clientMessageId);
        expect(s.messages, hasLength(1));
        c.dispose();
      },
    );

    test('server dedupes a retried request whose response was lost', () {
      final s = _server();
      final a = s.send(buyerA, body: 'hi', clientId: 'k1', brokerId: broker);
      final b = s.send(buyerA, body: 'hi', clientId: 'k1', brokerId: broker);
      expect(b.id, a.id);
      expect(s.messages, hasLength(1));
      expect(s.notifications, hasLength(1));
    });

    test('pending bubble shows until the server confirms', () async {
      final g = FakeChatGateway(_server(), buyerA)
        ..sendGate = Completer<void>();
      final c = await _open(g, brokerId: broker);
      c.send('hold on');
      expect(c.messages.single.delivery, ChatDelivery.pending);
      g.sendGate!.complete();
      await _settle();
      expect(c.messages.single.delivery, ChatDelivery.sent);
      expect(c.messages.single.id, isNotNull);
      c.dispose();
    });
  });

  group('authorization (server contract)', () {
    late FakeChatServer s;
    late String conv;
    setUp(() {
      s = _server();
      conv = s
          .send(buyerA, body: 'private', clientId: 'k', brokerId: broker)
          .conversationId;
    });

    test('another buyer cannot read the conversation by id', () async {
      final c = await _open(FakeChatGateway(s, buyerB), conversationId: conv);
      expect(c.error, isNotNull);
      expect(c.messages, isEmpty);
      c.dispose();
    });

    test('another buyer cannot post into it by id', () {
      expect(
        () => s.send(buyerB, body: 'x', clientId: 'k2', conversationId: conv),
        throwsStateError,
      );
    });

    test('brokers and sellers cannot start conversations; buyers cannot target sellers', () {
      expect(
        () => s.send(broker, body: 'x', clientId: 'a', brokerId: broker),
        throwsStateError,
      );
      expect(
        () => s.send(seller, body: 'x', clientId: 'b', brokerId: broker),
        throwsStateError,
      );
      expect(
        () => s.send(buyerA, body: 'x', clientId: 'c', brokerId: seller),
        throwsStateError,
      );
    });

    test('notification goes only to the recipient, once per message', () {
      s.send(broker, body: 'reply', clientId: 'r1', conversationId: conv);
      s.send(
        broker,
        body: 'reply',
        clientId: 'r1',
        conversationId: conv,
      ); // retry
      expect(s.notifications.map((n) => n.user), [broker, buyerA]);
      expect(s.notifications.map((n) => n.key).toSet(), hasLength(2));
    });
  });

  group('read state and realtime health', () {
    test('unread counts only incoming messages and clears on open', () async {
      final s = _server();
      final conv = s
          .send(buyerA, body: 'q1', clientId: 'a', brokerId: broker)
          .conversationId;
      s.send(broker, body: 'r1', clientId: 'b', conversationId: conv);
      s.send(broker, body: 'r2', clientId: 'c', conversationId: conv);
      expect(s.inbox(buyerA).single.unreadCount, 2);
      expect(s.inbox(broker).single.unreadCount, 0);

      final c = await _open(FakeChatGateway(s, buyerA), conversationId: conv);
      await _settle();
      expect(s.inbox(buyerA).single.unreadCount, 0);
      c.dispose();
    });

    test('Seen appears only after the counterpart has read', () async {
      final s = _server();
      final buyerSide = await _open(
        FakeChatGateway(s, buyerA),
        brokerId: broker,
      );
      buyerSide.send('hello');
      await _settle();
      await buyerSide.refresh();
      expect(buyerSide.seenMessageId, isNull);

      final brokerSide = await _open(
        FakeChatGateway(s, broker),
        conversationId: buyerSide.conversationId,
      );
      await _settle();
      await buyerSide.refresh();
      expect(buyerSide.seenMessageId, buyerSide.messages.single.id);
      buyerSide.dispose();
      brokerSide.dispose();
    });

    test(
      'reconnect re-syncs messages missed while offline; dispose unsubscribes',
      () async {
        final s = _server();
        final g = FakeChatGateway(s, buyerA);
        final c = await _open(g, brokerId: broker);
        c.send('hi');
        await _settle();
        expect(g.activeSubscriptions, 1);

        g.lastStatus!(ChatConnection.reconnecting);
        expect(c.connection, ChatConnection.reconnecting);
        // Missed while down: written directly, no live event delivered.
        s.messages.add(
          ChatMessage(
            id: 'missed',
            conversationId: c.conversationId!,
            senderId: broker,
            body: 'missed reply',
            clientMessageId: 'z',
            createdAt: s.clock.add(const Duration(seconds: 5)),
          ),
        );
        g.lastStatus!(ChatConnection.live);
        await _settle();
        await _settle();
        expect(c.messages.map((m) => m.body), ['hi', 'missed reply']);

        c.dispose();
        expect(g.activeSubscriptions, 0);
      },
    );

    test('older history pages in without duplicates', () async {
      final s = _server();
      final conv = s
          .send(buyerA, body: 'm0', clientId: 'k0', brokerId: broker)
          .conversationId;
      for (var i = 1; i < 7; i++) {
        s.send(
          i.isEven ? buyerA : broker,
          body: 'm$i',
          clientId: 'k$i',
          conversationId: conv,
        );
      }
      final c = await _open(
        FakeChatGateway(s, buyerA),
        conversationId: conv,
        pageSize: 3,
      );
      expect(c.messages.map((m) => m.body), ['m4', 'm5', 'm6']);
      expect(c.hasMore, isTrue);
      await c.loadOlder();
      await c.loadOlder();
      expect(c.messages.map((m) => m.body), [
        'm0',
        'm1',
        'm2',
        'm3',
        'm4',
        'm5',
        'm6',
      ]);
      c.dispose();
    });
  });

  test('chat notifications resolve to the conversation, nothing else', () {
    const id = '0b5f4a2e-1c3d-4e5f-8a9b-0c1d2e3f4a5b';
    final viaPayload = NotificationTarget.resolve(
      BuyerNotification.fromMap({
        'id': 'n1',
        'title': 'New message from Varun',
        'message': 'Open the conversation to read it.',
        'event_type': 'CHAT_MESSAGE',
        'action_url': '/chats/$id',
        'payload': {'conversationId': id},
      }),
    );
    expect(viaPayload.kind, NotificationTargetKind.chat);
    expect(viaPayload.id, id);
    expect(viaPayload.canOpen, isTrue);

    final bogus = NotificationTarget.resolve(
      BuyerNotification.fromMap({
        'id': 'n2',
        'title': 't',
        'message': 'm',
        'event_type': 'CHAT_MESSAGE',
        'action_url': '/chats/not-a-uuid',
      }),
    );
    expect(bogus.kind, NotificationTargetKind.none);
  });
}
