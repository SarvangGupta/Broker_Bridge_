import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/chat_models.dart';

/// Handle for a live subscription; call [cancel] when leaving the screen.
abstract class ChatSubscription {
  Future<void> cancel();
}

/// Backend contract for Buyer <-> Broker chat (migration 0043).
/// All writes go through SECURITY DEFINER RPCs that derive the sender from
/// the session; the client never supplies its own identity or role.
abstract class ChatGateway {
  String? get currentUserId;

  /// The caller's conversation with [brokerId], if one exists (Buyer side).
  Future<String?> findConversationWithBroker(String brokerId);

  /// Inbox rows; pass [conversationId] for a single conversation's header.
  Future<List<ChatConversationSummary>> inbox({String? conversationId});

  /// Newest-first page of messages strictly older than [before].
  Future<List<ChatMessage>> fetchMessages(
    String conversationId, {
    DateTime? before,
    int limit = 50,
  });

  /// Persists a message. Exactly one of [brokerId] (first message / buyer by
  /// broker) or [conversationId] is used. Retrying with the same
  /// [clientMessageId] returns the original row instead of a duplicate.
  Future<ChatMessage> send({
    required String body,
    required String clientMessageId,
    String? brokerId,
    String? conversationId,
  });

  Future<void> markRead(String conversationId);

  ChatSubscription subscribe(
    String conversationId, {
    required void Function(ChatMessage message) onMessage,
    required void Function() onConversationChanged,
    required void Function(ChatConnection status) onStatus,
  });
}

class SupabaseChatGateway implements ChatGateway {
  final SupabaseClient? _customClient;

  SupabaseChatGateway({SupabaseClient? client}) : _customClient = client;

  SupabaseClient get _db => _customClient ?? Supabase.instance.client;

  @override
  String? get currentUserId {
    try {
      return _db.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> findConversationWithBroker(String brokerId) async {
    final me = currentUserId;
    if (me == null) throw StateError('Not signed in');
    final row = await _db
        .from('chat_conversations')
        .select('id')
        .eq('buyer_id', me)
        .eq('broker_id', brokerId)
        .maybeSingle();
    return row?['id']?.toString();
  }

  @override
  Future<List<ChatConversationSummary>> inbox({String? conversationId}) async {
    final rows = await _db.rpc(
      'chat_inbox',
      params: {'p_conversation_id': conversationId},
    );
    return [
      for (final r in rows as List)
        ChatConversationSummary.fromMap(Map<String, dynamic>.from(r as Map)),
    ];
  }

  @override
  Future<List<ChatMessage>> fetchMessages(
    String conversationId, {
    DateTime? before,
    int limit = 50,
  }) async {
    var query = _db
        .from('chat_messages')
        .select(
          'id, conversation_id, sender_id, body, client_message_id, created_at',
        )
        .eq('conversation_id', conversationId);
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);
    return [for (final r in rows) ChatMessage.fromMap(r)];
  }

  @override
  Future<ChatMessage> send({
    required String body,
    required String clientMessageId,
    String? brokerId,
    String? conversationId,
  }) async {
    final row = await _db.rpc(
      'chat_send_message',
      params: {
        'p_body': body,
        'p_client_message_id': clientMessageId,
        'p_broker_id': conversationId == null ? brokerId : null,
        'p_conversation_id': conversationId,
      },
    );
    return ChatMessage.fromMap(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<void> markRead(String conversationId) async {
    await _db.rpc(
      'chat_mark_read',
      params: {'p_conversation_id': conversationId},
    );
  }

  @override
  ChatSubscription subscribe(
    String conversationId, {
    required void Function(ChatMessage message) onMessage,
    required void Function() onConversationChanged,
    required void Function(ChatConnection status) onStatus,
  }) {
    // Realtime postgres_changes are filtered server-side by the same RLS
    // SELECT policies, so only participants receive these events.
    final channel = _db
        .channel('chat:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) =>
              onMessage(ChatMessage.fromMap(payload.newRecord)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: conversationId,
          ),
          callback: (_) => onConversationChanged(),
        );
    channel.subscribe((status, _) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          onStatus(ChatConnection.live);
        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
          onStatus(ChatConnection.reconnecting);
        case RealtimeSubscribeStatus.closed:
          break;
      }
    });
    return _ChannelSubscription(_db, channel);
  }
}

class _ChannelSubscription implements ChatSubscription {
  final SupabaseClient _db;
  final RealtimeChannel _channel;
  _ChannelSubscription(this._db, this._channel);

  @override
  Future<void> cancel() => _db.removeChannel(_channel);
}
