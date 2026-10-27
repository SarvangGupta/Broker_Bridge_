import 'dart:async';

import 'package:rmbroker_mobile/features/chat/data/chat_gateway.dart';
import 'package:rmbroker_mobile/features/chat/domain/chat_models.dart';

/// Shared in-memory "server" mirroring the 0043 contract: one conversation per
/// (buyer, broker), idempotent sends per (conversation, sender, clientId),
/// participant-only reads, buyer-only conversation creation.
class FakeChatServer {
  final Map<String, String> roles; // userId -> buyer | broker | seller
  final Map<String, String> names;
  final conversations = <String, ({String buyer, String broker})>{};
  final messages = <ChatMessage>[];
  final readAt = <String, DateTime>{}; // '$conv:$user'
  final notifications = <({String user, String key, String conv})>[];
  final _listeners = <String, List<void Function(ChatMessage)>>{};
  int _seq = 0;
  DateTime clock = DateTime.utc(2026, 10, 26, 9);

  FakeChatServer({required this.roles, this.names = const {}});

  DateTime _tick() => clock = clock.add(const Duration(seconds: 1));

  bool participant(String conv, String user) {
    final c = conversations[conv];
    return c != null && (c.buyer == user || c.broker == user);
  }

  ChatMessage send(
    String me, {
    required String body,
    required String clientId,
    String? brokerId,
    String? conversationId,
  }) {
    final text = body.trim();
    if (text.isEmpty || text.length > kChatMaxLength) {
      throw ArgumentError('invalid body');
    }
    if ((brokerId == null) == (conversationId == null)) {
      throw ArgumentError('invalid request');
    }
    String conv;
    if (brokerId != null) {
      if (roles[me] != 'buyer' || roles[brokerId] != 'broker') {
        throw StateError('42501 not authorized');
      }
      conv =
          conversations.entries
              .where((e) => e.value.buyer == me && e.value.broker == brokerId)
              .map((e) => e.key)
              .firstOrNull ??
          'c${++_seq}';
      conversations[conv] ??= (buyer: me, broker: brokerId);
    } else {
      if (!participant(conversationId!, me)) {
        throw StateError('42501 conversation not found');
      }
      conv = conversationId;
    }
    final existing = messages
        .where(
          (m) =>
              m.conversationId == conv &&
              m.senderId == me &&
              m.clientMessageId == clientId,
        )
        .firstOrNull;
    if (existing != null) return existing;
    final m = ChatMessage(
      id: 'm${++_seq}',
      conversationId: conv,
      senderId: me,
      body: text,
      clientMessageId: clientId,
      createdAt: _tick(),
    );
    messages.add(m);
    readAt['$conv:$me'] = m.createdAt;
    final c = conversations[conv]!;
    final recipient = c.buyer == me ? c.broker : c.buyer;
    notifications.add((user: recipient, key: 'chat-msg-${m.id}', conv: conv));
    for (final l in [...?_listeners[conv]]) {
      l(m);
    }
    return m;
  }

  List<ChatConversationSummary> inbox(String me, {String? only}) {
    final rows = <ChatConversationSummary>[];
    for (final e in conversations.entries) {
      final c = e.value;
      if (c.buyer != me && c.broker != me) continue;
      if (only != null && e.key != only) continue;
      final other = c.buyer == me ? c.broker : c.buyer;
      final msgs = messages.where((m) => m.conversationId == e.key).toList();
      final mine = readAt['${e.key}:$me'];
      rows.add(
        ChatConversationSummary(
          id: e.key,
          buyerId: c.buyer,
          brokerId: c.broker,
          counterpartId: other,
          counterpartName: names[other] ?? other,
          lastMessageAt: msgs.isEmpty ? null : msgs.last.createdAt,
          lastMessagePreview: msgs.isEmpty ? null : msgs.last.body,
          lastSenderId: msgs.isEmpty ? null : msgs.last.senderId,
          unreadCount: msgs
              .where(
                (m) =>
                    m.senderId != me &&
                    (mine == null || m.createdAt.isAfter(mine)),
              )
              .length,
          counterpartLastReadAt: readAt['${e.key}:$other'],
        ),
      );
    }
    rows.sort(
      (a, b) => (b.lastMessageAt ?? DateTime(0)).compareTo(
        a.lastMessageAt ?? DateTime(0),
      ),
    );
    return rows;
  }
}

/// One signed-in user's view of [FakeChatServer].
class FakeChatGateway implements ChatGateway {
  final FakeChatServer server;
  final String me;
  bool failSends = false;
  bool failLoads = false;
  int sendCalls = 0;
  Completer<void>? sendGate;
  void Function(ChatConnection)? lastStatus;
  int activeSubscriptions = 0;

  FakeChatGateway(this.server, this.me);

  @override
  String? get currentUserId => me;

  @override
  Future<String?> findConversationWithBroker(String brokerId) async {
    if (failLoads) throw Exception('offline');
    return server.conversations.entries
        .where((e) => e.value.buyer == me && e.value.broker == brokerId)
        .map((e) => e.key)
        .firstOrNull;
  }

  @override
  Future<List<ChatConversationSummary>> inbox({String? conversationId}) async {
    if (failLoads) throw Exception('offline');
    return server.inbox(me, only: conversationId);
  }

  @override
  Future<List<ChatMessage>> fetchMessages(
    String conversationId, {
    DateTime? before,
    int limit = 50,
  }) async {
    if (failLoads) throw Exception('offline');
    if (!server.participant(conversationId, me)) return []; // RLS: no rows
    final rows =
        server.messages
            .where(
              (m) =>
                  m.conversationId == conversationId &&
                  (before == null || m.createdAt.isBefore(before)),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows.take(limit).toList();
  }

  @override
  Future<ChatMessage> send({
    required String body,
    required String clientMessageId,
    String? brokerId,
    String? conversationId,
  }) async {
    sendCalls++;
    if (sendGate != null) await sendGate!.future;
    if (failSends) throw Exception('network down');
    return server.send(
      me,
      body: body,
      clientId: clientMessageId,
      brokerId: conversationId == null ? brokerId : null,
      conversationId: conversationId,
    );
  }

  @override
  Future<void> markRead(String conversationId) async {
    if (server.participant(conversationId, me)) {
      server.readAt['$conversationId:$me'] = server._tick();
    }
  }

  @override
  ChatSubscription subscribe(
    String conversationId, {
    required void Function(ChatMessage message) onMessage,
    required void Function() onConversationChanged,
    required void Function(ChatConnection status) onStatus,
  }) {
    void listener(ChatMessage m) {
      if (server.participant(conversationId, me)) onMessage(m);
    }

    server._listeners.putIfAbsent(conversationId, () => []).add(listener);
    activeSubscriptions++;
    lastStatus = onStatus;
    onStatus(ChatConnection.live);
    return _Sub(() {
      server._listeners[conversationId]?.remove(listener);
      activeSubscriptions--;
    });
  }
}

class _Sub implements ChatSubscription {
  final void Function() _onCancel;
  _Sub(this._onCancel);

  @override
  Future<void> cancel() async => _onCancel();
}
