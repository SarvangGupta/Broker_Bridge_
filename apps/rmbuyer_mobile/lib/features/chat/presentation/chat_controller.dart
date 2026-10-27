import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/chat_gateway.dart';
import '../domain/chat_models.dart';

/// State for one conversation screen.
///
/// Opened either by [conversationId] (inbox, notification, broker side) or by
/// [brokerId] (buyer tapping Chat on a broker profile). In the broker case an
/// existing conversation is looked up; if none exists the screen shows the
/// "Start a conversation" state and the first send creates it server-side.
///
/// Messages are merged by server id and by (sender, clientMessageId), so a
/// realtime echo, a history refresh and the send response never duplicate.
class ChatController extends ChangeNotifier {
  final ChatGateway gateway;
  final String? brokerId;
  final int pageSize;

  ChatController({
    required this.gateway,
    String? conversationId,
    this.brokerId,
    this.pageSize = 50,
  }) : assert(conversationId != null || brokerId != null),
       _conversationId = conversationId;

  String? _conversationId;
  String? get conversationId => _conversationId;

  final List<ChatMessage> _messages = [];

  /// Oldest first.
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  ChatConversationSummary? summary;
  bool loading = true;
  String? error;
  bool hasMore = false;
  bool loadingOlder = false;
  ChatConnection connection = ChatConnection.connecting;

  ChatSubscription? _sub;
  bool _disposed = false;
  bool _wasDisconnected = false;

  String? get me => gateway.currentUserId;
  bool get isNewConversation =>
      !loading && error == null && _conversationId == null;

  Future<void> init() async {
    loading = true;
    error = null;
    _notify();
    try {
      _conversationId ??= await gateway.findConversationWithBroker(brokerId!);
      if (_conversationId != null) {
        await _loadSummary();
        await _loadLatest();
        _subscribe();
        unawaited(_markRead());
      }
      loading = false;
    } catch (e) {
      loading = false;
      error = 'Unable to load this conversation. Check your connection and try again.';
    }
    _notify();
  }

  Future<void> _loadSummary() async {
    final rows = await gateway.inbox(conversationId: _conversationId);
    if (rows.isEmpty) {
      // RLS returns nothing for non-participants: treat as not found.
      throw StateError('Conversation not found');
    }
    summary = rows.first;
  }

  Future<void> _loadLatest() async {
    final page = await gateway.fetchMessages(_conversationId!, limit: pageSize);
    hasMore = page.length == pageSize;
    page.forEach(_merge);
  }

  Future<void> loadOlder() async {
    if (loadingOlder || !hasMore || _conversationId == null) return;
    final oldest = _messages.where((m) => m.delivery == ChatDelivery.sent);
    if (oldest.isEmpty) return;
    loadingOlder = true;
    _notify();
    try {
      final page = await gateway.fetchMessages(
        _conversationId!,
        before: oldest.first.createdAt,
        limit: pageSize,
      );
      hasMore = page.length == pageSize;
      page.forEach(_merge);
    } catch (_) {
      // Keep what is shown; the user can scroll up again to retry.
    }
    loadingOlder = false;
    _notify();
  }

  /// Re-syncs after reconnecting or returning to the foreground.
  Future<void> refresh() async {
    if (_conversationId == null) return;
    try {
      await _loadLatest();
      await _loadSummary();
      unawaited(_markRead());
    } catch (_) {}
    _notify();
  }

  /// Validates and sends [text]. Returns false when rejected locally.
  bool send(String text) {
    final body = text.trim();
    final self = me;
    if (body.isEmpty || body.length > kChatMaxLength || self == null) {
      return false;
    }
    final pending = ChatMessage(
      conversationId: _conversationId ?? '',
      senderId: self,
      body: body,
      clientMessageId: newClientMessageId(),
      createdAt: DateTime.now().toUtc(),
      delivery: ChatDelivery.pending,
    );
    _messages.add(pending);
    _notify();
    unawaited(_deliver(pending));
    return true;
  }

  /// Retries a failed send with the same idempotency key.
  void retry(ChatMessage failed) {
    if (failed.delivery != ChatDelivery.failed) return;
    final i = _messages.indexWhere(
      (m) => m.clientMessageId == failed.clientMessageId && m.id == null,
    );
    if (i < 0) return;
    _messages[i] = failed.copyWith(delivery: ChatDelivery.pending);
    _notify();
    unawaited(_deliver(_messages[i]));
  }

  Future<void> _deliver(ChatMessage pending) async {
    try {
      final saved = await gateway.send(
        body: pending.body,
        clientMessageId: pending.clientMessageId,
        brokerId: brokerId,
        conversationId: _conversationId,
      );
      if (_disposed) return;
      final created = _conversationId == null;
      _conversationId ??= saved.conversationId;
      _merge(saved);
      if (created) {
        // First message created the conversation: wire up the live view.
        try {
          await _loadSummary();
        } catch (_) {}
        _subscribe();
      }
    } catch (_) {
      if (_disposed) return;
      final i = _messages.indexWhere(
        (m) => m.clientMessageId == pending.clientMessageId && m.id == null,
      );
      if (i >= 0) {
        _messages[i] = pending.copyWith(delivery: ChatDelivery.failed);
      }
    }
    _notify();
  }

  void _merge(ChatMessage m) {
    if (m.id != null && _messages.any((x) => x.id == m.id)) return;
    final local = _messages.indexWhere(
      (x) =>
          x.id == null &&
          x.senderId == m.senderId &&
          x.clientMessageId == m.clientMessageId,
    );
    if (local >= 0) _messages.removeAt(local);
    _messages.add(m);
    _messages.sort(_order);
  }

  /// Server rows by (createdAt, id); unsent rows after them in send order.
  static int _order(ChatMessage a, ChatMessage b) {
    final aSent = a.delivery == ChatDelivery.sent;
    final bSent = b.delivery == ChatDelivery.sent;
    if (aSent != bSent) return aSent ? -1 : 1;
    final c = a.createdAt.compareTo(b.createdAt);
    if (c != 0) return c;
    return (a.id ?? a.clientMessageId).compareTo(b.id ?? b.clientMessageId);
  }

  void _subscribe() {
    if (_sub != null || _conversationId == null) return;
    _sub = gateway.subscribe(
      _conversationId!,
      onMessage: (m) {
        if (_disposed || m.conversationId != _conversationId) return;
        _merge(m);
        if (m.senderId != me) unawaited(_markRead());
        _notify();
      },
      onConversationChanged: () {
        if (_disposed) return;
        unawaited(_loadSummary().then((_) => _notify(), onError: (_) {}));
      },
      onStatus: (status) {
        if (_disposed) return;
        if (status == ChatConnection.live && _wasDisconnected) {
          // Catch up on anything missed while the socket was down.
          unawaited(refresh());
        }
        _wasDisconnected = status == ChatConnection.reconnecting;
        connection = status;
        _notify();
      },
    );
  }

  Future<void> _markRead() async {
    final id = _conversationId;
    if (id == null) return;
    try {
      await gateway.markRead(id);
    } catch (_) {}
  }

  /// Last outgoing confirmed message the counterpart has read, if any.
  String? get seenMessageId {
    final readAt = summary?.counterpartLastReadAt;
    if (readAt == null) return null;
    for (final m in _messages.reversed) {
      if (m.senderId == me && m.delivery == ChatDelivery.sent) {
        return m.createdAt.isAfter(readAt) ? null : m.id;
      }
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
