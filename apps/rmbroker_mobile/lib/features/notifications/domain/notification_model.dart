import 'package:intl/intl.dart';

import 'notification_category.dart';

/// Representation of a business notification or trading desk audit event in RMBroker.
class BrokerNotification {
  final String id;
  final String userId;
  final String? companyId;
  final String channel;
  final String eventType;
  final NotificationCategory category;
  final String title;
  final String message;
  final String contextReason;
  final String? actionLabel;
  final String? actionUrl;
  final String? idempotencyKey;
  final String deliveryStatus;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final Map<String, dynamic>? payload;

  /// Read from the related record; never stored on the notification itself.
  final String? counterpartyName;
  final String? resolvedCommodity;
  final String? resolvedQuantity;
  final String? resolvedLocation;

  const BrokerNotification({
    required this.id,
    required this.userId,
    this.companyId,
    this.channel = 'IN_APP',
    required this.eventType,
    required this.category,
    required this.title,
    required this.message,
    required this.contextReason,
    this.actionLabel,
    this.actionUrl,
    this.idempotencyKey,
    this.deliveryStatus = 'Sent',
    this.isRead = false,
    this.readAt,
    required this.createdAt,
    this.payload,
    this.counterpartyName,
    this.resolvedCommodity,
    this.resolvedQuantity,
    this.resolvedLocation,
  });

  /// Factory constructor to parse from backend Supabase or REST API JSON.
  factory BrokerNotification.fromJson(Map<String, dynamic> json) {
    final eventTypeStr = json['event_type']?.toString() ?? json['eventType']?.toString() ?? 'SYSTEM';
    final category = NotificationCategory.fromEventType(eventTypeStr);

    final readAtRaw = json['read_at'] ?? json['readAt'];
    final createdAtRaw = json['created_at'] ?? json['createdAt'];

    final bool isReadVal = json['is_read'] == true ||
        json['isRead'] == true ||
        readAtRaw != null;

    final dynamic rawPayload = json['payload'];
    Map<String, dynamic>? parsedPayload;
    if (rawPayload is Map<String, dynamic>) {
      parsedPayload = rawPayload;
    }

    return BrokerNotification(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      companyId: json['company_id']?.toString() ?? json['companyId']?.toString(),
      channel: json['channel']?.toString() ?? 'IN_APP',
      eventType: eventTypeStr,
      category: category,
      title: json['title']?.toString() ?? 'Business Event',
      message: json['message']?.toString() ?? '',
      contextReason: json['context_reason']?.toString() ??
          json['contextReason']?.toString() ??
          json['message']?.toString() ??
          '',
      actionLabel: json['action_label']?.toString() ?? json['actionLabel']?.toString(),
      actionUrl: json['action_url']?.toString() ?? json['actionUrl']?.toString(),
      idempotencyKey: json['idempotency_key']?.toString() ?? json['idempotencyKey']?.toString(),
      deliveryStatus: json['delivery_status']?.toString() ?? json['deliveryStatus']?.toString() ?? 'Sent',
      isRead: isReadVal,
      readAt: readAtRaw != null ? DateTime.tryParse(readAtRaw.toString()) : null,
      createdAt: createdAtRaw != null
          ? (DateTime.tryParse(createdAtRaw.toString()) ?? DateTime.now())
          : DateTime.now(),
      payload: parsedPayload,
    );
  }

  /// Converts notification back to JSON format.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'company_id': companyId,
      'channel': channel,
      'event_type': eventType,
      'title': title,
      'message': message,
      'context_reason': contextReason,
      'action_label': actionLabel,
      'action_url': actionUrl,
      'idempotency_key': idempotencyKey,
      'delivery_status': deliveryStatus,
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'payload': payload,
    };
  }

  BrokerNotification copyWith({
    String? id,
    String? userId,
    String? companyId,
    String? channel,
    String? eventType,
    NotificationCategory? category,
    String? title,
    String? message,
    String? contextReason,
    String? actionLabel,
    String? actionUrl,
    String? idempotencyKey,
    String? deliveryStatus,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
    Map<String, dynamic>? payload,
    String? counterpartyName,
    String? resolvedCommodity,
    String? resolvedQuantity,
    String? resolvedLocation,
  }) {
    return BrokerNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      channel: channel ?? this.channel,
      eventType: eventType ?? this.eventType,
      category: category ?? this.category,
      title: title ?? this.title,
      message: message ?? this.message,
      contextReason: contextReason ?? this.contextReason,
      actionLabel: actionLabel ?? this.actionLabel,
      actionUrl: actionUrl ?? this.actionUrl,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      payload: payload ?? this.payload,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      resolvedCommodity: resolvedCommodity ?? this.resolvedCommodity,
      resolvedQuantity: resolvedQuantity ?? this.resolvedQuantity,
      resolvedLocation: resolvedLocation ?? this.resolvedLocation,
    );
  }

  /// Commodity named by the payload or the related record.
  String? get commodityLabel {
    for (final key in const ['commodity', 'commodityName', 'commodity_name']) {
      final v = payload?[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    if (resolvedCommodity != null) return resolvedCommodity;
    // Older rows name the commodity only in the title ("New Requirement: Maize").
    final type = eventType.toUpperCase();
    final colon = title.indexOf(': ');
    if ((type.contains('REQUIREMENT') || type.contains('OFFER')) && colon > 0) {
      return title.substring(colon + 2).trim();
    }
    return null;
  }

  /// Whether this notification can be clicked to navigate to an existing app screen or record.
  bool get isActionable {
    if (actionUrl != null && actionUrl!.trim().isNotEmpty && actionUrl != '/seller') {
      return true;
    }
    if (payload != null) {
      if (payload!['conversationId'] != null ||
          payload!['dealId'] != null ||
          payload!['deal_id'] != null ||
          payload!['invoiceId'] != null ||
          payload!['invoice_id'] != null ||
          payload!['requirementId'] != null ||
          payload!['requirement_id'] != null ||
          payload!['availabilityId'] != null ||
          payload!['availability_id'] != null ||
          payload!['offerId'] != null ||
          payload!['offer_id'] != null ||
          payload!['disputeId'] != null ||
          payload!['dispute_id'] != null ||
          payload!['warehouseId'] != null ||
          payload!['warehouse_id'] != null ||
          payload!['taskId'] != null ||
          payload!['task_id'] != null) {
        return true;
      }
    }
    return false;
  }

  static final RegExp _safeId = RegExp(r'^[A-Za-z0-9_\-\.]{1,64}$');

  /// First non-empty, path-safe payload value among [keys].
  String? _payloadId(List<String> keys) {
    for (final key in keys) {
      final value = payload?[key]?.toString().trim();
      if (value != null && value.isNotEmpty && _safeId.hasMatch(value)) return value;
    }
    return null;
  }

  /// Record id from a `/<segment>/<id>` path in [actionUrl].
  String? _urlId(String singular) {
    final url = actionUrl?.trim();
    if (url == null || url.isEmpty) return null;
    final match = RegExp('/${singular}s?/([a-zA-Z0-9_\\-\\.]+)', caseSensitive: false).firstMatch(url);
    final id = match?.group(1);
    if (id == null || id.isEmpty) return null;
    final lower = id.toLowerCase();
    if (lower == singular || lower == '${singular}s') return null;
    return id;
  }

  /// Chat conversation referenced by a CHAT_MESSAGE notification.
  String? get conversationId => _payloadId(const ['conversationId']) ?? _urlId('chat');

  /// Deal referenced by this notification (payload first, then URL).
  String? get dealId => _payloadId(const ['dealId', 'deal_id']) ?? _urlId('deal');

  /// Buyer requirement referenced by this notification (payload first, then URL).
  String? get requirementId =>
      _payloadId(const ['requirementId', 'requirement_id']) ?? _urlId('requirement');

  /// Seller offer (availability lot) referenced by this notification.
  String? get offerId =>
      _payloadId(const ['availabilityId', 'availability_id', 'offerId', 'offer_id']);

  /// Warehouse or unloading location referenced by this notification.
  String? get warehouseId =>
      _payloadId(const ['warehouseId', 'warehouse_id']);

  /// Whether this event concerns a counterparty warehouse or unloading location.
  bool get isWarehouseEvent =>
      eventType.toUpperCase().contains('WAREHOUSE') ||
      warehouseId != null;

  /// Display name of the referenced warehouse.
  String? get warehouseName =>
      payload?['warehouseName']?.toString().trim() ??
      payload?['warehouse_name']?.toString().trim();

  /// Street address or location summary of the referenced warehouse.
  String? get warehouseAddress =>
      payload?['address']?.toString().trim() ??
      payload?['addressLine']?.toString().trim();

  /// Warehouse operational change type (CREATED, UPDATED, LOCATION_UPDATED, DEACTIVATED).
  String? get warehouseChangeType =>
      payload?['changeType']?.toString().trim() ??
      payload?['change_type']?.toString().trim();

  /// Authoritative Google Maps URL referencing warehouse GPS coordinates.
  /// Strictly requires real, valid coordinates; never fabricates a link.
  String? get googleMapsUrl {
    final direct = payload?['googleMapsUrl']?.toString().trim() ??
        payload?['google_maps_url']?.toString().trim();
    if (direct != null && direct.startsWith('https://www.google.com/maps')) {
      return direct;
    }
    final lat = payload?['latitude'];
    final lng = payload?['longitude'];
    if (lat is num && lng is num) {
      final latD = lat.toDouble();
      final lngD = lng.toDouble();
      if (!latD.isNaN &&
          !lngD.isNaN &&
          latD >= -90.0 &&
          latD <= 90.0 &&
          lngD >= -180.0 &&
          lngD <= 180.0 &&
          !(latD.abs() < 0.000001 && lngD.abs() < 0.000001)) {
        final query = Uri.encodeComponent('$latD,$lngD');
        return 'https://www.google.com/maps/search/?api=1&query=$query';
      }
    }
    return null;
  }

  /// Short human reference for the record, matching the refs shown on cards
  /// (`#REQ-XXXXXX`, `DL-XXXXXX`, or the payload's own reference).
  String? get recordReference {
    String short(String id) => (id.length >= 6 ? id.substring(0, 6) : id).toUpperCase();
    final dealRef = payload?['dealReference']?.toString() ?? payload?['bookingReference']?.toString();
    if (dealRef != null && dealRef.isNotEmpty) return dealRef;
    final deal = dealId;
    if (deal != null) return 'DL-${short(deal)}';
    final req = requirementId;
    if (req != null) return '#REQ-${short(req)}';
    final offer = offerId;
    if (offer != null) return payload?['lotNumber']?.toString() ?? 'Offer ${short(offer)}';
    return null;
  }

  /// One line of commercial context from the payload, e.g.
  /// `#REQ-107DF7 · 35 MT · ₹28,000/MT · FOR Mill Delivery, Kota Mandi`.
  String? get detailLine {
    final d = detailFields;
    final parts = [d.reference, d.quantity, d.price, d.location].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// The parts of [detailLine], each null when the record does not carry it.
  ({String? reference, String? quantity, String? price, String? location}) get detailFields {
    final qty = payload?['quantity'];
    final unit = payload?['unit']?.toString() ?? payload?['unitSymbol']?.toString();
    String? quantity;
    if (qty is num) {
      final q = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
      quantity = unit != null && unit.isNotEmpty ? '$q $unit' : q;
    }
    final rawPrice = payload?['targetPrice'] ?? payload?['price'] ?? payload?['agreedPrice'];
    String? price;
    if (rawPrice is num && rawPrice > 0) {
      final formatted = NumberFormat.decimalPattern('en_IN').format(rawPrice);
      price = unit != null && unit.isNotEmpty ? '₹$formatted/$unit' : '₹$formatted';
    }
    final location = payload?['deliveryLocation']?.toString().trim();
    return (
      reference: recordReference,
      quantity: quantity,
      price: price,
      location: location != null && location.isNotEmpty ? location : null,
    );
  }

  /// Returns the target Flutter route path if resolved.
  ///
  /// Record ids win over the generic `action_url` (the requirement RPC writes
  /// `/work?tab=0`, and web writers use `/buyer/...` or `/broker/...` URLs), so a
  /// tap always opens the referenced record in its own section.
  String? get resolvedRoute {
    // Buyer chat message (0043): the chat screen re-checks participation via RLS.
    final conversation = conversationId;
    if (conversation != null) return '/chats/$conversation';
    final deal = dealId;
    if (deal != null) return '/deals/$deal';
    final requirement = requirementId;
    if (requirement != null) return '/requirements/$requirement';
    final offer = offerId;
    if (offer != null) return '/work?tab=1&offerId=$offer';
    final warehouse = warehouseId;
    if (warehouse != null) {
      if (actionUrl != null && actionUrl!.trim().isNotEmpty) return actionUrl!.trim();
      return '/directory';
    }

    // 1. Direct recognized action URL - translate web URLs to mobile routes
    if (actionUrl != null && actionUrl!.trim().isNotEmpty && actionUrl != '/seller') {
      final url = actionUrl!.trim();

      if (url.contains('requirement')) {
        return '/work';
      }

      if (url.contains('deal')) {
        // Fallback to 36-char UUID regex in URL (ids in /deals/<id> were handled above)
        final uuidMatch = RegExp(r'[0-9a-fA-F-]{36}').firstMatch(url);
        if (uuidMatch != null) {
          return '/deals/${uuidMatch.group(0)}';
        }
        return '/deals';
      }

      if (url.contains('invoice')) {
        final match = RegExp(r'/invoices?/([a-zA-Z0-9_\-\.]+)', caseSensitive: false).firstMatch(url);
        if (match != null) {
          final id = match.group(1);
          if (id != null && id.isNotEmpty && id.toLowerCase() != 'invoice' && id.toLowerCase() != 'invoices') {
            return '/invoices/$id';
          }
        }
        final payloadInvoiceId = payload?['invoiceId'] ?? payload?['invoice_id'];
        if (payloadInvoiceId != null && payloadInvoiceId.toString().trim().isNotEmpty) {
          return '/invoices/${payloadInvoiceId.toString().trim()}';
        }
        return '/invoices';
      }

      if (url.contains('task')) {
        final match = RegExp(r'/tasks?/([a-zA-Z0-9_\-\.]+)', caseSensitive: false).firstMatch(url);
        if (match != null) {
          final id = match.group(1);
          if (id != null && id.isNotEmpty && id.toLowerCase() != 'task' && id.toLowerCase() != 'tasks') {
            return '/tasks/$id';
          }
        }
        final payloadTaskId = payload?['taskId'] ?? payload?['task_id'];
        if (payloadTaskId != null && payloadTaskId.toString().trim().isNotEmpty) {
          return '/tasks/${payloadTaskId.toString().trim()}';
        }
        return '/tasks';
      }

      if (url.startsWith('/')) return url;
      return '/$url';
    }

    // 2. Resolve from payload
    if (payload != null) {
      final invoiceId = payload!['invoiceId'] ?? payload!['invoice_id'];
      if (invoiceId != null && invoiceId.toString().trim().isNotEmpty) {
        return '/invoices/${invoiceId.toString().trim()}';
      }

      final disputeId = payload!['disputeId'] ?? payload!['dispute_id'];
      if (disputeId != null) return '/disputes';

      final taskId = payload!['taskId'] ?? payload!['task_id'];
      if (taskId != null && taskId.toString().trim().isNotEmpty) {
        return '/tasks/${taskId.toString().trim()}';
      }
    }

    // 3. Fallback by category
    switch (category) {
      case NotificationCategory.dealsAndConfirmations:
        return '/deals';
      case NotificationCategory.requirementsAndOffers:
        return '/work';
      case NotificationCategory.commissionAndInvoices:
        return '/invoices';
      case NotificationCategory.dispatchAndDelivery:
        return '/orders';
      case NotificationCategory.disputesAndExceptions:
        return '/disputes';
      case NotificationCategory.system:
      case NotificationCategory.all:
        return null;
    }
  }

  /// Formatted relative or calendar time.
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('dd MMM yyyy, hh:mm a').format(createdAt);
    }
  }

  /// Checks if this is an urgent or exception event requiring immediate attention.
  bool get isUrgent {
    const urgentTypes = {
      'FINAL_CONFIRMATION_REQUIRED',
      'DISPUTE_RAISED',
      'RECONCILIATION_EXCEPTION',
      'DOCUMENT_ISSUE',
      'AVAILABILITY_EXPIRING',
      'DELIVERY_UPDATE',
      'DISPATCH_REMINDER',
    };
    return urgentTypes.contains(eventType.toUpperCase());
  }
}
