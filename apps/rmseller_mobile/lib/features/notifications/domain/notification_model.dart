/// Domain entity representing an authoritative notification in `public.notifications`.
class SellerNotification {
  final String id;
  final String userId;
  final String? companyId;
  final String channel;
  final String eventType;
  final String title;
  final String message;
  final String actionUrl;
  final String actionLabel;
  final bool isRead;
  final DateTime createdAt;

  const SellerNotification({
    required this.id,
    required this.userId,
    this.companyId,
    this.channel = 'IN_APP',
    required this.eventType,
    required this.title,
    required this.message,
    this.actionUrl = '/home',
    this.actionLabel = 'View Details',
    this.isRead = false,
    required this.createdAt,
  });

  bool get isCommissionAlert =>
      eventType.contains('COMMISSION') ||
      eventType.contains('PROPOSAL') ||
      eventType.contains('NEGOTIATION');

  bool get isMessageAlert =>
      eventType.contains('MESSAGE') || eventType.contains('CHAT');

  factory SellerNotification.fromMap(Map<String, dynamic> map) {
    return SellerNotification(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      companyId: map['company_id']?.toString(),
      channel: map['channel'] as String? ?? 'IN_APP',
      eventType: map['event_type'] as String? ?? 'GENERAL',
      title: map['title'] as String? ?? 'Mandi Alert',
      message: map['message'] as String? ?? '',
      actionUrl: map['action_url'] as String? ?? '/home',
      actionLabel: map['action_label'] as String? ?? 'View Details',
      isRead: map['is_read'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'company_id': companyId,
      'channel': channel,
      'event_type': eventType,
      'title': title,
      'message': message,
      'action_url': actionUrl,
      'action_label': actionLabel,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
