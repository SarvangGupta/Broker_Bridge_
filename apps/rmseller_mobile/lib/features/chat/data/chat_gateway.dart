import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/chat_models.dart';

/// Handle for a live subscription; call [cancel] when leaving the screen.
abstract class ChatSubscription {
  Future<void> cancel();
}

/// Backend contract for broker-mediated chat: Buyer/Seller <-> Broker
/// (migration 0043, extended by proposed 0066). One conversation per
/// (client user, broker user); buyers and sellers never share one.
/// All writes go through SECURITY DEFINER RPCs that derive the sender from
/// the session; the client never supplies its own identity or role.
abstract class ChatGateway {
  String? get currentUserId;

  /// The caller's conversation with [userId] (either side), if one exists:
  /// the general thread, or the one linked to [requirementId] / [availabilityId].
  Future<String?> findConversationWith(String userId, {String? requirementId, String? availabilityId});

  /// Inbox rows; pass [conversationId] for a single conversation's header.
  Future<List<ChatConversationSummary>> inbox({String? conversationId});

  /// Newest-first page of messages strictly before ([before], [beforeId]) in
  /// (created_at, id) order, so equal timestamps never skip a message.
  Future<List<ChatMessage>> fetchMessages(
    String conversationId, {
    DateTime? before,
    String? beforeId,
    int limit = 50,
  });

  /// Persists a message. With [conversationId] it replies; otherwise the
  /// first message creates the conversation, addressed by [brokerId]
  /// (buyer/seller to a broker, 0043 path) or [counterpartId] (any role to
  /// a specific user, 0066 path). With [requirementId] / [availabilityId] the
  /// conversation is the one linked to that requirement / offer (0067).
  /// Retrying with the same [clientMessageId] returns the original row.
  Future<ChatMessage> send({
    required String body,
    required String clientMessageId,
    String? brokerId,
    String? counterpartId,
    String? conversationId,
    String? requirementId,
    String? availabilityId,
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
  Future<String?> findConversationWith(String userId, {String? requirementId, String? availabilityId}) async {
    final me = currentUserId;
    if (me == null) throw StateError('Not signed in');
    try {
      final id = await _db.rpc(
        'chat_find_conversation',
        params: {
          'p_counterpart_id': userId,
          'p_requirement_id': requirementId,
          'p_availability_id': availabilityId,
        },
      );
      return id?.toString();
    } on PostgrestException catch (e) {
      // Backend without 0067: only general conversations exist, so a context
      // chat falls back to the general thread with this person.
      if (!_isMissingFunction(e)) rethrow;
    }
    // RLS returns only the caller's own conversations.
    final row = await _db
        .from('chat_conversations')
        .select('id')
        .or('and(buyer_id.eq.$me,broker_id.eq.$userId),and(broker_id.eq.$me,buyer_id.eq.$userId)')
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
    String? beforeId,
    int limit = 50,
  }) async {
    var query = _db
        .from('chat_messages')
        .select(
          'id, conversation_id, sender_id, body, client_message_id, created_at',
        )
        .eq('conversation_id', conversationId);
    if (before != null) {
      final ts = before.toUtc().toIso8601String();
      query = beforeId == null
          ? query.lt('created_at', ts)
          : query.or('created_at.lt."$ts",and(created_at.eq."$ts",id.lt.$beforeId)');
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
    String? counterpartId,
    String? conversationId,
    String? requirementId,
    String? availabilityId,
  }) async {
    if (conversationId == null && (requirementId != null || availabilityId != null)) {
      try {
        final row = await _db.rpc(
          'chat_send_in_context',
          params: {
            'p_body': body,
            'p_client_message_id': clientMessageId,
            'p_counterpart_id': counterpartId ?? brokerId,
            'p_requirement_id': requirementId,
            'p_availability_id': availabilityId,
          },
        );
        return ChatMessage.fromMap(Map<String, dynamic>.from(row as Map));
      } on PostgrestException catch (e) {
        // Backend without 0067: send in the general thread (same as before).
        if (!_isMissingFunction(e)) rethrow;
      }
    }
    final row = conversationId == null && counterpartId != null
        ? await _db.rpc(
            'chat_send_message_to',
            params: {
              'p_body': body,
              'p_client_message_id': clientMessageId,
              'p_counterpart_id': counterpartId,
            },
          )
        : await _db.rpc(
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

/// PostgREST "function not found" (an RPC from a migration not applied yet).
bool _isMissingFunction(PostgrestException e) =>
    e.code == 'PGRST202' || e.code == '42883';

class _ChannelSubscription implements ChatSubscription {
  final SupabaseClient _db;
  final RealtimeChannel _channel;
  _ChannelSubscription(this._db, this._channel);

  @override
  Future<void> cancel() => _db.removeChannel(_channel);
}
