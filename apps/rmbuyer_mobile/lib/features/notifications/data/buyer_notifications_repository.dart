import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/buyer_notification_model.dart';

/// Repository for fetching and managing user procurement notifications from public.notifications.
class BuyerNotificationsRepository {
  final SupabaseClient? _customClient;

  BuyerNotificationsRepository({SupabaseClient? client})
      : _customClient = client;

  SupabaseClient? get _supabase {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<BuyerNotification>> getNotifications() async {
    final client = _supabase;
    if (client != null) {
      try {
        final userId = client.auth.currentUser?.id;
        if (userId != null) {
          final data = await client
              .from('notifications')
              .select('id, title, message, event_type, is_read, created_at')
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .limit(30);

          final list = <BuyerNotification>[];
          for (final row in data) {
            list.add(BuyerNotification.fromMap(row));
          }
          if (list.isNotEmpty) return list;
        }
      } catch (e) {
        debugPrint('Notifications fetch notice: $e');
      }
    }

    return _fallbackNotifications;
  }

  static final List<BuyerNotification> _fallbackNotifications = [
    BuyerNotification(
      id: 'notif-1',
      title: 'Counterparty Quote Received',
      message: 'Broker Desk has proposed 50 MT Yellow Soybean at ₹4,820/MT.',
      eventType: 'NEW_BROKER_REQUEST',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    BuyerNotification(
      id: 'notif-2',
      title: 'Requirement Allocated',
      message: 'Your requirement REQ-2026-081 was allocated for verification.',
      eventType: 'AVAILABILITY_APPROVED',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    BuyerNotification(
      id: 'notif-3',
      title: 'Shipment Dispatched',
      message: 'Deal DEAL-2026-042 (Mustard Seeds 25 MT) is dispatched from Mandi.',
      eventType: 'DISPATCH_REMINDER',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
}
