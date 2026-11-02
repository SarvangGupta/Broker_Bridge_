import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/chat/domain/chat_models.dart';
import 'package:rmbuyer_mobile/features/chat/presentation/chat_controller.dart';

import '../support/fake_chat_gateway.dart';

// RM-CHAT-ALLOCATION-PRIVACY-E2E-02, buyer side (Flow B). Fake server only.

const broker = 'e2e-broker-01', broker2 = 'e2e-broker-02', buyer = 'e2e-buyer-01', buyer2 = 'e2e-buyer-02';
const seller = 'e2e-seller-01';

Future<void> settle() => Future<void>.delayed(Duration.zero);

FakeChatServer server() => FakeChatServer(
      roles: {broker: 'broker', broker2: 'broker', buyer: 'buyer', buyer2: 'buyer', seller: 'seller'},
      requirements: {'req-1': (broker: broker, clients: {buyer})},
      offers: {'lot-1': (broker: broker, clients: {seller})},
    );

void main() {
  test('Flow B: buyer starts from its requirement; broker replies; reopen keeps one history', () async {
    final s = server();
    final mine = ChatController(gateway: FakeChatGateway(s, buyer), brokerId: broker, requirementId: 'req-1');
    await mine.init();
    mine.send('Any seller for my requirement?');
    await settle();

    final theirs = ChatController(gateway: FakeChatGateway(s, broker), conversationId: mine.conversationId);
    await theirs.init();
    expect(theirs.summary!.contextLabel, 'Requirement · req-1');
    theirs.send('Yes, terms coming');
    await settle();
    expect(mine.messages.map((m) => m.body), ['Any seller for my requirement?', 'Yes, terms coming']);

    final reopened = ChatController(gateway: FakeChatGateway(s, buyer), brokerId: broker, requirementId: 'req-1');
    await reopened.init();
    expect(reopened.conversationId, mine.conversationId);
    expect(reopened.messages.map((m) => m.id), mine.messages.map((m) => m.id));
    expect(s.conversations.length, 1);
    for (final c in [mine, theirs, reopened]) {
      c.dispose();
    }
  });

  test('buyer cannot use another buyer\'s requirement, an offer, a seller, or an unassigned broker', () async {
    final s = server();
    Future<ChatDelivery> attempt(String me, String to, {String? requirementId, String? availabilityId}) async {
      final c = ChatController(
          gateway: FakeChatGateway(s, me), brokerId: to, requirementId: requirementId, availabilityId: availabilityId);
      await c.init();
      c.send('x');
      await settle();
      final d = c.messages.single.delivery;
      c.dispose();
      return d;
    }

    expect(await attempt(buyer2, broker, requirementId: 'req-1'), ChatDelivery.failed);
    expect(await attempt(buyer, broker2, requirementId: 'req-1'), ChatDelivery.failed);
    expect(await attempt(buyer, broker, availabilityId: 'lot-1'), ChatDelivery.failed);
    expect(await attempt(buyer, seller), ChatDelivery.failed);
    expect(s.conversations, isEmpty);
  });
}
