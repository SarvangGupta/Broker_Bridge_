import 'dart:async';

import 'package:rmseller_mobile/features/chat/data/chat_gateway.dart';
import 'package:rmseller_mobile/features/chat/domain/chat_models.dart';

/// Shared in-memory "server" mirroring the 0043 + proposed 0066 contract: one
/// conversation per (client, broker) where the client is a buyer or seller,
/// idempotent sends per (conversation, sender, clientId), participant-only
/// reads, buyers/sellers open chats with any active broker, brokers open chats
/// only with related clients ([relations]). Buyers and sellers never share one.
class FakeChatServer {
  final Map<String, String> roles; // userId -> buyer | broker | seller
  final Map<String, String> names;

  /// '$broker:$client' pairs a broker may contact (CRM / requirement / lot).
  final Set<String> relations;

  /// 0067 contexts: requirement id -> (assigned broker, buyers of its company),
  /// offer id -> (assigned broker, owning sellers).
  final Map<String, ({String broker, Set<String> clients})> requirements;
  final Map<String, ({String broker, Set<String> clients})> offers;
  final conversations = <String, ({String buyer, String broker})>{};
  final contextOf = <String, ({String? requirement, String? offer})>{};
  final messages = <ChatMessage>[];
  final readAt = <String, DateTime>{}; // '$conv:$user'
  final notifications = <({String user, String key, String conv})>[];
  final _listeners = <String, List<void Function(ChatMessage)>>{};
  int _seq = 0;
  DateTime clock = DateTime.utc(2026, 10, 26, 9);

  /// When true, sends reuse the current clock (identical server timestamps).
  bool freezeClock = false;

  FakeChatServer({
    required this.roles,
    this.names = const {},
    this.relations = const {},
    this.requirements = const {},
    this.offers = const {},
  });

  DateTime _tick() => freezeClock ? clock : clock = clock.add(const Duration(seconds: 1));

  bool participant(String conv, String user) {
    final c = conversations[conv];
    return c != null && (c.buyer == user || c.broker == user);
  }

  bool _isClient(String? id) => roles[id] == 'buyer' || roles[id] == 'seller';

  String? conversationOf(String a, String b, {String? requirement, String? offer}) => conversations.entries
      .where((e) =>
          ((e.value.buyer == a && e.value.broker == b) || (e.value.buyer == b && e.value.broker == a)) &&
          contextOf[e.key]?.requirement == requirement &&
          contextOf[e.key]?.offer == offer)
      .map((e) => e.key)
      .firstOrNull;

  String _open(String client, String broker, {String? requirement, String? offer}) {
    final existing = conversationOf(client, broker, requirement: requirement, offer: offer);
    if (existing != null) return existing;
    final id = 'c${++_seq}';
    conversations[id] = (buyer: client, broker: broker);
    contextOf[id] = (requirement: requirement, offer: offer);
    return id;
  }

  /// 0067 chat_context_parties: (client, broker) when me + other are the
  /// context's own assigned broker and client, else null.
  ({String client, String broker})? _parties(String me, String other, String? requirement, String? offer) {
    if ((requirement == null) == (offer == null)) return null;
    final ctx = requirement != null ? requirements[requirement] : offers[offer];
    if (ctx == null) return null;
    final broker = roles[me] == 'broker' ? me : other;
    final client = roles[me] == 'broker' ? other : me;
    final clientRole = requirement != null ? 'buyer' : 'seller';
    if (roles[broker] != 'broker' || roles[client] != clientRole) return null;
    if (ctx.broker != broker || !ctx.clients.contains(client)) return null;
    return (client: client, broker: broker);
  }

  ChatMessage send(
    String me, {
    required String body,
    required String clientId,
    String? brokerId,
    String? counterpartId,
    String? conversationId,
    String? requirementId,
    String? availabilityId,
  }) {
    final text = body.trim();
    if (text.isEmpty || text.length > kChatMaxLength) {
      throw ArgumentError('invalid body');
    }
    String conv;
    if (conversationId != null) {
      if (!participant(conversationId, me)) {
        throw StateError('42501 conversation not found');
      }
      final ctx = contextOf[conversationId];
      final c = conversations[conversationId]!;
      if ((ctx?.requirement != null || ctx?.offer != null) &&
          _parties(c.broker, c.buyer, ctx!.requirement, ctx.offer) == null) {
        throw StateError('42501 conversation no longer active');
      }
      conv = conversationId;
    } else if (requirementId != null || availabilityId != null) {
      final to = counterpartId ?? brokerId;
      final p = to == null ? null : _parties(me, to, requirementId, availabilityId);
      if (p == null) throw StateError('42501 contact not available');
      conv = _open(p.client, p.broker, requirement: requirementId, offer: availabilityId);
    } else {
      final to = counterpartId ?? brokerId;
      if (to == null) throw ArgumentError('invalid request');
      if (_isClient(me)) {
        // 0043 path (also used by chat_send_message_to for buyers/sellers).
        if (roles[to] != 'broker') throw StateError('42501 broker not available');
        conv = _open(me, to);
      } else if (roles[me] == 'broker' && counterpartId != null) {
        if (!_isClient(to) || !(relations.contains('$me:$to') || conversationOf(me, to) != null)) {
          throw StateError('42501 contact not available');
        }
        conv = _open(to, me);
      } else {
        throw StateError('42501 not authorized');
      }
    }
    final existing = messages
        .where((m) => m.conversationId == conv && m.senderId == me && m.clientMessageId == clientId)
        .firstOrNull;
    if (existing != null) return existing;
    final m = ChatMessage(
      id: 'm${(++_seq).toString().padLeft(4, '0')}',
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

  /// (createdAt, id) order, as the server sorts.
  static int byTime(ChatMessage a, ChatMessage b) {
    final c = a.createdAt.compareTo(b.createdAt);
    return c != 0 ? c : a.id!.compareTo(b.id!);
  }

  List<ChatConversationSummary> inbox(String me, {String? only}) {
    final rows = <ChatConversationSummary>[];
    for (final e in conversations.entries) {
      final c = e.value;
      if (c.buyer != me && c.broker != me) continue;
      if (only != null && e.key != only) continue;
      final other = c.buyer == me ? c.broker : c.buyer;
      final msgs = messages.where((m) => m.conversationId == e.key).toList()..sort(byTime);
      final mine = readAt['${e.key}:$me'];
      rows.add(
        ChatConversationSummary(
          id: e.key,
          buyerId: c.buyer,
          brokerId: c.broker,
          counterpartId: other,
          counterpartName: names[other] ?? other,
          counterpartRole: roles[other],
          requirementId: contextOf[e.key]?.requirement,
          availabilityId: contextOf[e.key]?.offer,
          contextLabel: contextOf[e.key]?.requirement != null
              ? 'Requirement · ${contextOf[e.key]!.requirement}'
              : contextOf[e.key]?.offer != null
                  ? 'Offer · ${contextOf[e.key]!.offer}'
                  : null,
          lastMessageAt: msgs.isEmpty ? null : msgs.last.createdAt,
          lastMessagePreview: msgs.isEmpty ? null : msgs.last.body,
          lastSenderId: msgs.isEmpty ? null : msgs.last.senderId,
          unreadCount: msgs.where((m) => m.senderId != me && (mine == null || m.createdAt.isAfter(mine))).length,
          counterpartLastReadAt: readAt['${e.key}:$other'],
        ),
      );
    }
    rows.sort((a, b) => (b.lastMessageAt ?? DateTime(0)).compareTo(a.lastMessageAt ?? DateTime(0)));
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
  Future<String?> findConversationWith(String userId, {String? requirementId, String? availabilityId}) async {
    if (failLoads) throw Exception('offline');
    return server.conversationOf(me, userId, requirement: requirementId, offer: availabilityId);
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
    String? beforeId,
    int limit = 50,
  }) async {
    if (failLoads) throw Exception('offline');
    if (!server.participant(conversationId, me)) return []; // RLS: no rows
    bool older(ChatMessage m) {
      if (before == null) return true;
      final c = m.createdAt.compareTo(before);
      return c < 0 || (c == 0 && beforeId != null && m.id!.compareTo(beforeId) < 0);
    }

    final rows = server.messages.where((m) => m.conversationId == conversationId && older(m)).toList()
      ..sort((a, b) => FakeChatServer.byTime(b, a));
    return rows.take(limit).toList();
  }

  @override
  Future<ChatMessage> send({
    required String body,
    required String clientMessageId,
    String? brokerId,
    String? counterpartId,
    String? conversationId,
    String? requirementId,
    String? availabilityId,
  }) async {
    sendCalls++;
    if (sendGate != null) await sendGate!.future;
    if (failSends) throw Exception('network down');
    return server.send(
      me,
      body: body,
      clientId: clientMessageId,
      brokerId: conversationId == null ? brokerId : null,
      counterpartId: conversationId == null ? counterpartId : null,
      conversationId: conversationId,
      requirementId: conversationId == null ? requirementId : null,
      availabilityId: conversationId == null ? availabilityId : null,
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
