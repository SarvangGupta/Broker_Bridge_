/// Domain entity for in-app procurement notifications.
class BuyerNotification {
  final String id;
  final String title;
  final String message;
  final String eventType;
  final bool isRead;
  final DateTime createdAt;

  const BuyerNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.eventType,
    required this.isRead,
    required this.createdAt,
  });

  factory BuyerNotification.fromMap(Map<String, dynamic> map) {
    return BuyerNotification(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Procurement Alert',
      message: map['message'] as String? ?? '',
      eventType: map['event_type'] as String? ?? 'SYSTEM',
      isRead: map['is_read'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
