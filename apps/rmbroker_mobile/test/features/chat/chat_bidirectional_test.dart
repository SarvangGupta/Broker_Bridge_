import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmbroker_mobile/features/chat/data/chat_contacts.dart';
import 'package:rmbroker_mobile/features/chat/domain/chat_models.dart';
import 'package:rmbroker_mobile/features/chat/presentation/chat_controller.dart';
import 'package:rmbroker_mobile/features/chat/presentation/chat_inbox_screen.dart';
import 'package:rmbroker_mobile/features/chat/presentation/chat_screen.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:rmbroker_mobile/features/work/domain/offer_model.dart';
import 'package:rmbroker_mobile/features/work/presentation/controllers/requirements_controller.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/offer_detail_sheet.dart';

import '../../support/fake_chat_gateway.dart';

// RM-CHAT-BIDIRECTIONAL-E2E-01: two signed-in sessions per conversation over
// one shared fake server (0043 + proposed 0066 contract). No Supabase project.

const broker = 'e2e-broker-01', broker2 = 'e2e-broker-02';
const buyer = 'e2e-buyer-01', buyer2 = 'e2e-buyer-02';
const seller = 'e2e-seller-01', seller2 = 'e2e-seller-02';

FakeChatServer server() => FakeChatServer(
      roles: {
        broker: 'broker',
        broker2: 'broker',
        buyer: 'buyer',
        buyer2: 'buyer',
        seller: 'seller',
        seller2: 'seller',
      },
      names: {broker: 'E2E Broker', buyer: 'E2E Buyer', seller: 'E2E Seller', seller2: 'Seller Two'},
      // Broker 1 has buyer 1 on an assigned requirement and seller 1 on a managed lot.
      relations: {'$broker:$buyer', '$broker:$seller'},
    );

Future<void> settle() => Future<void>.delayed(Duration.zero);

/// Opens [who]'s side of the conversation the way the app does: from the
/// inbox row (recipient) or by person (initiator).
Future<ChatController> open(FakeChatServer s, String who,
    {String? conversationId, String? brokerId, String? counterpartId, int pageSize = 50}) async {
  final c = ChatController(
    gateway: FakeChatGateway(s, who),
    conversationId: conversationId,
    brokerId: brokerId,
    counterpartId: counterpartId,
    pageSize: pageSize,
  );
  await c.init();
  return c;
}

List<String?> ids(ChatController c) => c.messages.map((m) => m.id).toList();
List<String> bodies(ChatController c) => c.messages.map((m) => m.body).toList();

/// Runs the 7-step two-way exchange and checks both sides end identical.
Future<void> exchange(FakeChatServer s, ChatController initiator, String recipientId) async {
  initiator.send('1 initiator opens');
  await settle();
  final convId = initiator.conversationId!;
  expect(s.notifications.last.user, recipientId);

  // Recipient finds it in the inbox, opens it, and replies.
  final inbox = await FakeChatGateway(s, recipientId).inbox();
  final row = inbox.singleWhere((r) => r.id == convId);
  expect(row.unreadCount, 1);
  final recipient = await open(s, recipientId, conversationId: row.id);
  expect(bodies(recipient), ['1 initiator opens']);
  recipient.send('2 recipient replies');
  await settle();
  expect(bodies(initiator), ['1 initiator opens', '2 recipient replies'], reason: 'live update to initiator');

  initiator.send('3 initiator again');
  await settle();
  recipient.send('4 recipient again');
  await settle();

  expect(bodies(initiator), ['1 initiator opens', '2 recipient replies', '3 initiator again', '4 recipient again']);
  expect(ids(initiator), ids(recipient), reason: 'same message ids, same order, both sides');
  expect(initiator.messages.every((m) => m.delivery == ChatDelivery.sent), isTrue);
  expect(s.conversations.length, 1, reason: 'one conversation, no duplicates');

  // Close and reopen both sides (new controllers): history is server-backed.
  final reopenedInitiator = await open(s, initiator.me!, conversationId: convId);
  final reopenedRecipient = await open(s, recipientId, conversationId: convId);
  expect(ids(reopenedInitiator), ids(initiator));
  expect(ids(reopenedRecipient), ids(initiator));
  for (final c in [initiator, recipient, reopenedInitiator, reopenedRecipient]) {
    c.dispose();
  }
}

void main() {
  group('scenarios', () {
    test('A broker -> buyer: both send, receive and reply; same history', () async {
      final s = server();
      final b = await open(s, broker, counterpartId: buyer);
      expect(b.isNewConversation, isTrue);
      await exchange(s, b, buyer);
      expect(s.inbox(broker).single.counterpartRole, 'buyer');
    });

    test('B broker -> seller: both send, receive and reply; same history', () async {
      final s = server();
      final b = await open(s, broker, counterpartId: seller);
      await exchange(s, b, seller);
      expect(s.inbox(broker).single.counterpartRole, 'seller');
      expect(s.inbox(seller).single.counterpartRole, 'broker');
    });

    test('C buyer -> broker: broker sees it in the inbox and the chat continues', () async {
      final s = server();
      final b = await open(s, buyer2, brokerId: broker2);
      await exchange(s, b, broker2);
    });

    test('D seller -> broker: broker sees it in the inbox and the chat continues', () async {
      final s = server();
      final c = await open(s, seller2, brokerId: broker);
      await exchange(s, c, broker);
    });

    test('broker reopening by person finds the conversation the client started', () async {
      final s = server();
      final sellerSide = await open(s, seller, brokerId: broker);
      sellerSide.send('hello broker');
      await settle();
      final brokerSide = await open(s, broker, counterpartId: seller);
      expect(brokerSide.conversationId, sellerSide.conversationId);
      expect(bodies(brokerSide), ['hello broker']);
      sellerSide.dispose();
      brokerSide.dispose();
    });
  });

  group('authorization and privacy', () {
    test('broker cannot start a chat with an unrelated buyer or seller', () async {
      final s = server();
      for (final target in [buyer2, seller2]) {
        final c = await open(s, broker, counterpartId: target);
        c.send('cold message');
        await settle();
        expect(c.messages.single.delivery, ChatDelivery.failed);
        c.dispose();
      }
      expect(s.conversations, isEmpty);
      expect(s.messages, isEmpty);
    });

    test('buyer and seller can never message each other', () async {
      final s = server();
      final b = await open(s, buyer, brokerId: seller);
      b.send('direct to seller?');
      await settle();
      expect(b.messages.single.delivery, ChatDelivery.failed);
      expect(() => s.send(seller, body: 'x', clientId: 'k', counterpartId: buyer), throwsStateError);
      expect(s.conversations, isEmpty);
      b.dispose();
    });

    test('a third party cannot open or post into a conversation', () async {
      final s = server();
      final conv = s.send(buyer, body: 'private', clientId: 'k', brokerId: broker).conversationId;
      final intruder = await open(s, seller, conversationId: conv);
      expect(intruder.error, isNotNull);
      expect(intruder.messages, isEmpty);
      expect(() => s.send(broker2, body: 'x', clientId: 'k2', conversationId: conv), throwsStateError);
      expect(s.inbox(seller), isEmpty);
      intruder.dispose();
    });

    test('the sender is always the signed-in user', () async {
      final s = server();
      final c = await open(s, buyer, brokerId: broker);
      c.send('mine');
      await settle();
      expect(s.messages.single.senderId, buyer);
      c.dispose();
    });
  });

  group('ordering, history and delivery', () {
    test('identical server timestamps keep a stable (time, id) order and page without gaps', () async {
      final s = server()..freezeClock = true;
      final conv = s.send(buyer, body: 'm0', clientId: 'k0', brokerId: broker).conversationId;
      for (var i = 1; i < 7; i++) {
        s.send(i.isEven ? buyer : broker, body: 'm$i', clientId: 'k$i', conversationId: conv);
      }
      final c = await open(s, broker, conversationId: conv, pageSize: 2);
      expect(bodies(c), ['m5', 'm6']);
      while (c.hasMore) {
        await c.loadOlder();
      }
      expect(bodies(c), ['m0', 'm1', 'm2', 'm3', 'm4', 'm5', 'm6']);
      final other = await open(s, buyer, conversationId: conv);
      expect(ids(other), ids(c));
      c.dispose();
      other.dispose();
    });

    test('an incoming message is appended once (realtime + refresh do not duplicate)', () async {
      final s = server();
      final conv = s.send(buyer, body: 'hi', clientId: 'k', brokerId: broker).conversationId;
      final c = await open(s, broker, conversationId: conv);
      s.send(buyer, body: 'second', clientId: 'k2', conversationId: conv);
      await c.refresh();
      expect(bodies(c), ['hi', 'second']);
      c.dispose();
    });

    test('failed send shows retry; retry delivers exactly one message', () async {
      final s = server();
      final gw = FakeChatGateway(s, broker)..failSends = true;
      final c = ChatController(gateway: gw, counterpartId: buyer);
      await c.init();
      c.send('rate update');
      await settle();
      expect(c.messages.single.delivery, ChatDelivery.failed);
      gw.failSends = false;
      c.retry(c.messages.single);
      await settle();
      c.retry(c.messages.single); // no-op once sent
      await settle();
      expect(s.messages.length, 1);
      expect(c.messages.single.delivery, ChatDelivery.sent);
      c.dispose();
    });

    test('timestamps render in local time from the server value', () {
      final m = ChatMessage.fromMap({
        'id': 'x',
        'conversation_id': 'c',
        'sender_id': broker,
        'body': 'b',
        'client_message_id': 'k',
        'created_at': '2026-11-02T04:30:00+00:00',
      });
      expect(m.createdAt.isUtc, isTrue);
      expect(m.createdAt, DateTime.utc(2026, 11, 2, 4, 30));
      expect(m.createdAt.toLocal().toUtc(), m.createdAt);
    });
  });

  group('context conversations (0067)', () {
    const req = 'req-1', lot = 'lot-1';
    FakeChatServer ctxServer() => FakeChatServer(
          roles: {broker: 'broker', broker2: 'broker', buyer: 'buyer', buyer2: 'buyer', seller: 'seller', seller2: 'seller'},
          requirements: {req: (broker: broker, clients: {buyer})},
          offers: {lot: (broker: broker, clients: {seller})},
        );

    test('Flow A: broker chats the seller on the offer and the buyer on the requirement, separately', () async {
      final s = ctxServer();
      final toSeller = await open(s, broker, counterpartId: seller);
      final sellerCtl = ChatController(gateway: FakeChatGateway(s, broker), counterpartId: seller, availabilityId: lot);
      await sellerCtl.init();
      sellerCtl.send('About your lot');
      await settle();
      final sellerSide = ChatController(gateway: FakeChatGateway(s, seller), brokerId: broker, availabilityId: lot);
      await sellerSide.init();
      expect(sellerSide.conversationId, sellerCtl.conversationId, reason: 'seller reopening the offer finds the same chat');
      sellerSide.send('Lot is ready');
      await settle();

      final buyerCtl = ChatController(gateway: FakeChatGateway(s, broker), counterpartId: buyer, requirementId: req);
      await buyerCtl.init();
      buyerCtl.send('Matched a lot for you');
      await settle();
      final buyerSide = ChatController(gateway: FakeChatGateway(s, buyer), brokerId: broker, requirementId: req);
      await buyerSide.init();
      buyerSide.send('Great, send terms');
      await settle();

      expect(sellerCtl.conversationId, isNot(buyerCtl.conversationId));
      expect(bodies(sellerCtl), ['About your lot', 'Lot is ready']);
      expect(bodies(buyerCtl), ['Matched a lot for you', 'Great, send terms']);
      expect(ids(buyerCtl), ids(buyerSide));
      final labels = s.inbox(broker).map((r) => r.contextLabel).toSet();
      expect(labels, {'Offer · $lot', 'Requirement · $req'});
      expect(s.inbox(buyer).single.counterpartRole, 'broker');
      expect(s.inbox(seller).single.counterpartRole, 'broker');
      for (final c in [toSeller, sellerCtl, sellerSide, buyerCtl, buyerSide]) {
        c.dispose();
      }
    });

    test('Flow B/C: buyer and seller start from their own requirement / offer; no duplicates on reopen', () async {
      final s = ctxServer();
      final b = ChatController(gateway: FakeChatGateway(s, buyer), brokerId: broker, requirementId: req);
      await b.init();
      b.send('Question on my requirement');
      await settle();
      final again = ChatController(gateway: FakeChatGateway(s, buyer), brokerId: broker, requirementId: req);
      await again.init();
      expect(again.conversationId, b.conversationId);
      final c = ChatController(gateway: FakeChatGateway(s, seller), brokerId: broker, availabilityId: lot);
      await c.init();
      c.send('Question on my lot');
      await settle();
      expect(s.conversations.length, 2);
      final general = ChatController(gateway: FakeChatGateway(s, buyer), brokerId: broker);
      await general.init();
      expect(general.conversationId, isNull, reason: 'the general thread is separate from context chats');
      for (final x in [b, again, c, general]) {
        x.dispose();
      }
    });

    test('Flow D: only the context\'s assigned broker and own client can chat in it', () async {
      final s = ctxServer();
      Future<ChatDelivery> attempt(String me,
          {String? brokerId, String? counterpartId, String? requirementId, String? availabilityId}) async {
        final c = ChatController(
            gateway: FakeChatGateway(s, me),
            brokerId: brokerId,
            counterpartId: counterpartId,
            requirementId: requirementId,
            availabilityId: availabilityId);
        await c.init();
        c.send('x');
        await settle();
        final d = c.messages.single.delivery;
        c.dispose();
        return d;
      }

      expect(await attempt(broker2, counterpartId: seller, availabilityId: lot), ChatDelivery.failed);
      expect(await attempt(seller2, brokerId: broker, availabilityId: lot), ChatDelivery.failed);
      expect(await attempt(buyer2, brokerId: broker, requirementId: req), ChatDelivery.failed);
      expect(await attempt(buyer, brokerId: seller, requirementId: req), ChatDelivery.failed);
      expect(await attempt(seller, brokerId: buyer, availabilityId: lot), ChatDelivery.failed);
      expect(await attempt(buyer, brokerId: broker, availabilityId: lot), ChatDelivery.failed);
      expect(s.conversations, isEmpty);
    });
  });

  group('broker UI', () {
    testWidgets('inbox tags each conversation as Buyer or Seller', (tester) async {
      final s = server();
      final cBuyer = s.send(buyer, body: 'from buyer', clientId: 'a', brokerId: broker).conversationId;
      final cSeller = s.send(seller, body: 'from seller', clientId: 'b', brokerId: broker).conversationId;
      await tester.pumpWidget(MaterialApp(home: ChatInboxScreen(gateway: FakeChatGateway(s, broker))));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(Key('chat-inbox-subtitle-$cBuyer'))).data, startsWith('Buyer'));
      expect(tester.widget<Text>(find.byKey(Key('chat-inbox-subtitle-$cSeller'))).data, startsWith('Seller'));
    });

    testWidgets('broker starts a chat from the conversation screen and the buyer sees it', (tester) async {
      final s = server();
      await tester.pumpWidget(MaterialApp(
        home: ChatScreen(gateway: FakeChatGateway(s, broker), counterpartId: buyer, fallbackName: 'E2E Buyer'),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-empty')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('chat-input')), 'Your requirement is matched');
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      expect(find.text('Your requirement is matched'), findsOneWidget);
      expect(s.inbox(buyer).single.lastMessagePreview, 'Your requirement is matched');
      expect(find.text('E2E Buyer'), findsOneWidget);
    });

    testWidgets('Chat with Seller is an explicit action on own lots only and opens the seller chat', (tester) async {
      final pushed = <String>[];
      Future<void> pumpSheet(OfferItem offer) async {
        final router = GoRouter(routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(body: OfferDetailSheet(offer: offer)),
          ),
          GoRoute(
            path: '/chats/user/:id',
            builder: (_, st) {
              pushed.add(st.pathParameters['id']!);
              return const Text('chat opened');
            },
          ),
        ]);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            workRepositoryProvider.overrideWithValue(_Work()),
            chatContactsRepositoryProvider.overrideWithValue(_Contacts()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ));
        await tester.pumpAndSettle();
      }

      await pumpSheet(_offer(brokerId: broker2));
      expect(find.byKey(const ValueKey('chat_with_seller_button')), findsNothing);

      await pumpSheet(_offer(brokerId: broker));
      // No phone action opens chat: the only chat entry is the labelled button.
      expect(find.byIcon(Icons.phone), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('chat_with_seller_button')));
      await tester.tap(find.byKey(const ValueKey('chat_with_seller_button')));
      await tester.pumpAndSettle();
      expect(pushed, [seller]);
      expect(find.text('chat opened'), findsOneWidget);
    });
  });
}

class _Work extends WorkRepository {
  @override
  String? activeBrokerId() => broker;
}

class _Contacts extends ChatContactsRepository {
  @override
  Future<List<ChatContact>> forContext({String? requirementId, String? availabilityId}) async =>
      availabilityId == 'lot-1' ? [const ChatContact(userId: seller, name: 'E2E Seller', role: 'seller')] : [];
}

OfferItem _offer({required String brokerId}) => OfferItem.fromJson({
      'id': 'lot-1',
      'lot_number': 'LOT-1',
      'seller_company_name': 'E2E Seller Traders',
      'commodity_id': 'e2e-commodity',
      'commodity_name': 'E2E Commodity',
      'grade_name': 'FAQ',
      'unit_symbol': 'MT',
      'total_quantity': 80,
      'available_quantity': 80,
      'asking_price': 5850,
      'available_from': DateTime.now().toIso8601String(),
      'valid_until': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
      'status': 'Open',
      'broker_id': brokerId,
      'created_at': '2026-11-02T09:00:00.000',
    });
