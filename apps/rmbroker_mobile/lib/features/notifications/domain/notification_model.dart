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
    );
  }

  /// Whether this notification can be clicked to navigate to an existing app screen or record.
  bool get isActionable {
    if (actionUrl != null && actionUrl!.trim().isNotEmpty && actionUrl != '/seller') {
      return true;
    }
    if (payload != null) {
      if (payload!['dealId'] != null ||
          payload!['deal_id'] != null ||
          payload!['invoiceId'] != null ||
          payload!['invoice_id'] != null ||
          payload!['requirementId'] != null ||
          payload!['requirement_id'] != null ||
          payload!['availabilityId'] != null ||
          payload!['offer_id'] != null ||
          payload!['disputeId'] != null) {
        return true;
      }
    }
    return false;
  }

  /// Returns the target Flutter route path if resolved.
  String? get resolvedRoute {
    // 1. Direct recognized action URL
    if (actionUrl != null && actionUrl!.trim().isNotEmpty && actionUrl != '/seller') {
      final url = actionUrl!.trim();
      if (url.startsWith('/')) return url;
      return '/$url';
    }

    // 2. Resolve from payload
    if (payload != null) {
      final dealId = payload!['dealId'] ?? payload!['deal_id'];
      if (dealId != null) return '/deals/$dealId';

      final invoiceId = payload!['invoiceId'] ?? payload!['invoice_id'];
      if (invoiceId != null) return '/invoices/$invoiceId';

      final requirementId = payload!['requirementId'] ?? payload!['requirement_id'];
      if (requirementId != null) return '/work';

      final offerId = payload!['availabilityId'] ?? payload!['offer_id'];
      if (offerId != null) return '/work';

      final disputeId = payload!['disputeId'];
      if (disputeId != null) return '/disputes';
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
