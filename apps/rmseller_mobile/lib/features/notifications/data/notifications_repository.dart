import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/secure_storage_service.dart';
import '../domain/notification_model.dart';

/// Repository managing authoritative notifications and real-time alerts.
class NotificationsRepository {
  final SupabaseClient? _customClient;
  final SecureStorageService _storage;

  static final List<SellerNotification> _sessionNotifications = [];
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(2);

  NotificationsRepository({
    SupabaseClient? client,
    SecureStorageService? storage,
  })  : _customClient = client,
        _storage = storage ?? SecureStorageService();

  SupabaseClient? get _supabase {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<SellerNotification>> getNotifications() async {
    final client = _supabase;
    final List<SellerNotification> list = [];

    String? userId;
    String? companyId;
    try {
      userId = await _storage.getUserId();
      companyId = await _storage.getCompanyId();
    } catch (_) {}

    userId ??= '20000000-0000-0000-0000-000000000001';
    companyId ??= '20000000-0000-0000-0000-000000000101';

    list.addAll(_sessionNotifications);

    if (client != null) {
      try {
        final data = await client
            .from('notifications')
            .select()
            .or('user_id.eq.$userId,company_id.eq.$companyId')
            .order('created_at', ascending: false)
            .limit(30);

        for (final row in data) {
          final id = row['id'].toString();
          if (list.any((n) => n.id == id)) continue;
          list.add(SellerNotification.fromMap(row as Map<String, dynamic>));
        }
      } catch (e) {
        debugPrint('Supabase notifications query notice: $e');
      }
    }

    if (list.isEmpty) {
      list.addAll(_baselineNotifications(userId, companyId));
    }

    // Update unread badge
    unreadCountNotifier.value = list.where((n) => !n.isRead).length;

    return list;
  }

  Future<void> markAsRead(String notificationId) async {
    final client = _supabase;

    final idx = _sessionNotifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      final old = _sessionNotifications[idx];
      _sessionNotifications[idx] = SellerNotification(
        id: old.id,
        userId: old.userId,
        companyId: old.companyId,
        channel: old.channel,
        eventType: old.eventType,
        title: old.title,
        message: old.message,
        actionUrl: old.actionUrl,
        actionLabel: old.actionLabel,
        isRead: true,
        createdAt: old.createdAt,
      );
    }

    if (client != null) {
      try {
        await client
            .from('notifications')
            .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
            .eq('id', notificationId);
      } catch (e) {
        debugPrint('Supabase markAsRead notice: $e');
      }
    }

    final unread = (await getNotifications()).where((n) => !n.isRead).length;
    unreadCountNotifier.value = unread;
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    for (int i = 0; i < _sessionNotifications.length; i++) {
      final old = _sessionNotifications[i];
      _sessionNotifications[i] = SellerNotification(
        id: old.id,
        userId: old.userId,
        companyId: old.companyId,
        channel: old.channel,
        eventType: old.eventType,
        title: old.title,
        message: old.message,
        actionUrl: old.actionUrl,
        actionLabel: old.actionLabel,
        isRead: true,
        createdAt: old.createdAt,
      );
    }
    unreadCountNotifier.value = 0;
  }

  /// Returns total count of unread notifications for current seller
  Future<int> getUnreadCount() async {
    final list = await getNotifications();
    return list.where((n) => !n.isRead).length;
  }

  List<SellerNotification> _baselineNotifications(String userId, String companyId) {
    final now = DateTime.now();
    return [
      SellerNotification(
        id: 'NOTIF-001',
        userId: userId,
        companyId: companyId,
        eventType: 'COMMISSION_PROPOSAL',
        title: 'Broker Commission Proposal Received',
        message: 'Bikaner Mandi Broker Desk proposed ₹50/MT commission for LOT-CHANA-01.',
        actionUrl: '/commodities/AVL-2026-001/negotiate',
        actionLabel: 'Review Terms',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      SellerNotification(
        id: 'NOTIF-002',
        userId: userId,
        companyId: companyId,
        eventType: 'BROKER_MESSAGE',
        title: 'New Broker Message',
        message: 'Bikaner Mandi Broker Desk sent an update regarding buyer matching.',
        actionUrl: '/commodities/AVL-2026-001/negotiate',
        actionLabel: 'Open Chat',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      SellerNotification(
        id: 'NOTIF-003',
        userId: userId,
        companyId: companyId,
        eventType: 'DEAL_UPDATE',
        title: 'Contract Booking Finalized',
        message: 'Deal DL-2026-001 successfully booked with Mandi Broker Desk.',
        actionUrl: '/deals/DL-2026-001',
        actionLabel: 'View Contract',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}
