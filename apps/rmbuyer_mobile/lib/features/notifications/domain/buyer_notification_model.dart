/// Domain entity for an in-app notification row from `public.notifications`.
class BuyerNotification {
  final String id;
  final String title;
  final String message;
  final String contextReason;
  final String eventType;
  final bool isRead;
  final DateTime? createdAt;
  final String actionUrl;
  final Map<String, dynamic> payload;

  const BuyerNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.eventType,
    required this.isRead,
    this.createdAt,
    this.contextReason = '',
    this.actionUrl = '',
    this.payload = const {},
  });

  /// Maps a row as stored. Missing optional fields stay empty; nothing is invented.
  factory BuyerNotification.fromMap(Map<String, dynamic> map) {
    String text(Object? v) => v?.toString().trim() ?? '';
    final created = map['created_at'];
    final payload = map['payload'];
    return BuyerNotification(
      id: text(map['id']),
      title: text(map['title']),
      message: text(map['message']),
      contextReason: text(map['context_reason']),
      eventType: text(map['event_type']).toUpperCase(),
      // The web Action Center treats either flag as read.
      isRead: map['is_read'] == true || map['read_at'] != null,
      createdAt: created == null ? null : DateTime.tryParse(created.toString()),
      actionUrl: text(map['action_url']),
      payload: payload is Map<String, dynamic> ? payload : const {},
    );
  }

  BuyerNotification asRead() => BuyerNotification(
    id: id,
    title: title,
    message: message,
    contextReason: contextReason,
    eventType: eventType,
    isRead: true,
    createdAt: createdAt,
    actionUrl: actionUrl,
    payload: payload,
  );
}

/// Where a notification points, resolved only from backend-supplied references.
enum NotificationTargetKind {
  /// A Buyer requirement the app can open (after an ownership check).
  requirement,

  /// The Buyer's requirements list.
  requirementsList,

  /// A deal. Buyers have no read access to `deals`, so it cannot be opened yet.
  deal,

  /// A broker proposal (quotation). Buyers have no read access to `quotations`.
  offer,

  /// A Buyer <-> Broker chat conversation (RLS-checked when opened).
  chat,

  /// No usable reference.
  none,
}

class NotificationTarget {
  final NotificationTargetKind kind;
  final String? id;

  const NotificationTarget(this.kind, [this.id]);

  static const none = NotificationTarget(NotificationTargetKind.none);

  bool get canOpen =>
      kind == NotificationTargetKind.requirement ||
      kind == NotificationTargetKind.requirementsList ||
      kind == NotificationTargetKind.chat;

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static String? _validId(Object? v) {
    final s = v?.toString().trim() ?? '';
    return _uuid.hasMatch(s) ? s : null;
  }

  /// Resolves a target from the row's `action_url` and `payload`, accepting only
  /// the exact URL shapes the backend writes for Buyers and well-formed UUIDs.
  /// Message text is never parsed.
  static NotificationTarget resolve(BuyerNotification n) {
    final url = n.actionUrl;
    final payloadRequirement = _validId(n.payload['requirementId']);

    // Chat: `/chats/<conversation id>` or payload.conversationId (0043 RPC).
    final chatMatch = RegExp(r'^/chats/([^/?#]+)$').firstMatch(url);
    final chatId =
        _validId(n.payload['conversationId']) ?? _validId(chatMatch?.group(1));
    if (chatId != null) {
      return NotificationTarget(NotificationTargetKind.chat, chatId);
    }

    // Deals: `/buyer/deals/<id>`, or `/broker/deals/<id>` (the URL the web Broker
    // actions currently write into Buyer deal notifications), or payload.dealId.
    final dealMatch = RegExp(r'^/(buyer|broker)/deals/([^/?#]+)')
        .firstMatch(url);
    final dealId =
        _validId(dealMatch?.group(2)) ?? _validId(n.payload['dealId']);
    if (dealId != null) {
      return NotificationTarget(NotificationTargetKind.deal, dealId);
    }

    // Contract confirmation: `/buyer/confirmations?requestId=<quotation id>`.
    final confirm = Uri.tryParse(url);
    if (confirm != null && confirm.path == '/buyer/confirmations') {
      final id = _validId(confirm.queryParameters['requestId']);
      if (id != null) {
        return NotificationTarget(NotificationTargetKind.offer, id);
      }
    }
    final quotationId = _validId(n.payload['quotationId']);
    if (quotationId != null) {
      return NotificationTarget(NotificationTargetKind.offer, quotationId);
    }

    // Requirements: `/buyer/requirements/<id>`, or the list URL with payload.requirementId.
    final reqMatch = RegExp(r'^/buyer/requirements/([^/?#]+)$').firstMatch(url);
    final reqId = _validId(reqMatch?.group(1));
    if (reqId != null) {
      return NotificationTarget(NotificationTargetKind.requirement, reqId);
    }
    if (url == '/buyer/requirements') {
      return payloadRequirement != null
          ? NotificationTarget(
              NotificationTargetKind.requirement,
              payloadRequirement,
            )
          : const NotificationTarget(NotificationTargetKind.requirementsList);
    }
    if (payloadRequirement != null) {
      return NotificationTarget(
        NotificationTargetKind.requirement,
        payloadRequirement,
      );
    }
    return none;
  }
}
