import 'dart:math';

/// Max message length; mirrors the `chat_messages_body_len` check in 0043.
const int kChatMaxLength = 2000;

/// Lifecycle of a message on this device. Only [sent] rows exist on the server.
enum ChatDelivery { pending, sent, failed }

/// A chat message. [id] and [createdAt] are server-assigned once [delivery] is
/// [ChatDelivery.sent]; pending/failed rows carry only the local [clientMessageId].
class ChatMessage {
  final String? id;
  final String conversationId;
  final String senderId;
  final String body;
  final String clientMessageId;
  final DateTime createdAt;
  final ChatDelivery delivery;

  const ChatMessage({
    this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.clientMessageId,
    required this.createdAt,
    this.delivery = ChatDelivery.sent,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id']?.toString(),
    conversationId: map['conversation_id']?.toString() ?? '',
    senderId: map['sender_id']?.toString() ?? '',
    body: map['body']?.toString() ?? '',
    clientMessageId: map['client_message_id']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(map['created_at']?.toString() ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
  );

  ChatMessage copyWith({ChatDelivery? delivery}) => ChatMessage(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    body: body,
    clientMessageId: clientMessageId,
    createdAt: createdAt,
    delivery: delivery ?? this.delivery,
  );
}

/// One row of `chat_inbox()`: a conversation seen from the caller's side.
class ChatConversationSummary {
  final String id;
  final String buyerId;
  final String brokerId;
  final String counterpartId;
  final String counterpartName;
  final String? counterpartCompany;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastSenderId;
  final int unreadCount;
  final DateTime? counterpartLastReadAt;

  const ChatConversationSummary({
    required this.id,
    required this.buyerId,
    required this.brokerId,
    required this.counterpartId,
    required this.counterpartName,
    this.counterpartCompany,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastSenderId,
    this.unreadCount = 0,
    this.counterpartLastReadAt,
  });

  factory ChatConversationSummary.fromMap(Map<String, dynamic> map) {
    DateTime? ts(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toUtc();
    String? text(Object? v) {
      final s = v?.toString().trim();
      return s == null || s.isEmpty ? null : s;
    }

    return ChatConversationSummary(
      id: map['conversation_id'].toString(),
      buyerId: map['buyer_id'].toString(),
      brokerId: map['broker_id'].toString(),
      counterpartId: map['counterpart_id'].toString(),
      counterpartName: text(map['counterpart_name']) ?? 'Unknown user',
      counterpartCompany: text(map['counterpart_company']),
      lastMessageAt: ts(map['last_message_at']),
      lastMessagePreview: text(map['last_message_preview']),
      lastSenderId: text(map['last_sender_id']),
      unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0,
      counterpartLastReadAt: ts(map['counterpart_last_read_at']),
    );
  }
}

/// Realtime channel health shown in the chat header.
enum ChatConnection { connecting, live, reconnecting }

final Random _rng = Random.secure();

/// RFC 4122 v4 id used as the idempotency key for a send.
String newClientMessageId() {
  final b = List<int>.generate(16, (_) => _rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int from, int to) => b
      .sublist(from, to)
      .map((x) => x.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
