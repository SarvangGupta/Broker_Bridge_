import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/security/secure_storage_service.dart';
import '../domain/notification_category.dart';
import '../domain/notification_model.dart';

/// Repository managing broker notifications, activity streams, and read synchronization.
class NotificationRepository {
  final ApiClient? _customApiClient;
  final SupabaseClient? _customSupabase;
  final SecureStorageService _storage;

  NotificationRepository({
    ApiClient? apiClient,
    SupabaseClient? supabase,
    SecureStorageService? storage,
  })  : _customApiClient = apiClient,
        _customSupabase = supabase,
        _storage = storage ?? SecureStorageService();

  ApiClient get _apiClient => _customApiClient ?? ApiClient(storage: _storage);

  SupabaseClient? get _supabase {
    if (_customSupabase != null) return _customSupabase;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // In-memory cache & audit-trailed storage
  final List<BrokerNotification> _cachedNotifications = [];
  bool _initialized = false;
  RealtimeChannel? _realtimeSubscription;

  void _seedDefaultNotifications() {
    if (_initialized) return;
    _initialized = true;

    final now = DateTime.now();

    _cachedNotifications.addAll([
      BrokerNotification(
        id: 'notif-2026-001',
        userId: 'broker-demo-user',
        channel: 'IN_APP',
        eventType: 'FINAL_CONFIRMATION_REQUIRED',
        category: NotificationCategory.dealsAndConfirmations,
        title: 'Deal Awaiting Final Confirmation',
        message: 'Deal DL-2026-0891 (50 MT Mustard Seed) requires your desk review and party confirmation.',
        contextReason: 'Buyer Sharma Agro Mills Ltd confirmed terms. Awaiting seller confirmation sign-off.',
        actionLabel: 'Review Deal',
        actionUrl: '/deals/deal-bkg-0042',
        idempotencyKey: 'idemp-deal-confirm-0891',
        deliveryStatus: 'Sent',
        isRead: false,
        readAt: null,
        createdAt: now.subtract(const Duration(minutes: 15)),
        payload: {
          'dealId': 'deal-bkg-0042',
          'dealReference': 'DL-2026-0891',
          'commodity': 'Mustard Seed (Sarson)',
          'quantity': 50.0,
        },
      ),
      BrokerNotification(
        id: 'notif-2026-002',
        userId: 'broker-demo-user',
        channel: 'IN_APP',
        eventType: 'MATCH_CREATED',
        category: NotificationCategory.requirementsAndOffers,
        title: 'New High-Score Mandate Match (96%)',
        message: 'Buyer requirement REQ-2026-0104 matches Seller Offer OFF-2026-0219 for Grade-A Bold Mustard.',
        contextReason: 'Quantity 50 MT and target price ₹5,450/Qtl align within 0.5% mandi tolerance.',
        actionLabel: 'Inspect Match',
        actionUrl: '/work',
        idempotencyKey: 'idemp-match-req-0104',
        deliveryStatus: 'Sent',
        isRead: false,
        readAt: null,
        createdAt: now.subtract(const Duration(hours: 1, minutes: 20)),
        payload: {
          'requirementId': 'req-2026-0104',
          'offerId': 'off-2026-0219',
          'commodity': 'Mustard Seed (Sarson)',
          'matchScore': 96,
        },
      ),
      BrokerNotification(
        id: 'notif-2026-003',
        userId: 'broker-demo-user',
        channel: 'IN_APP',
        eventType: 'PAYMENT_RECORDED',
        category: NotificationCategory.commissionAndInvoices,
        title: 'Commission Payment Recorded',
        message: '₹3,000 received for Invoice INV-2026-0042 (Deal DL-2026-0891).',
        contextReason: 'Payment verified via UTR994827104921. Ledger balance updated to zero outstanding.',
        actionLabel: 'View Invoice',
        actionUrl: '/invoices/inv-2026-0042',
        idempotencyKey: 'idemp-pay-inv-0042',
        deliveryStatus: 'Sent',
        isRead: false,
        readAt: null,
        createdAt: now.subtract(const Duration(hours: 3, minutes: 45)),
        payload: {
          'invoiceId': 'inv-2026-0042',
          'amount': 3000.0,
          'utr': 'UTR994827104921',
        },
      ),
      BrokerNotification(
        id: 'notif-2026-004',
        userId: 'broker-demo-user',
        channel: 'IN_APP',
        eventType: 'DISPATCH_REMINDER',
        category: NotificationCategory.dispatchAndDelivery,
        title: 'Vehicle Dispatch Transit Update',
        message: 'Truck RJ-14-GA-8821 dispatched from Kisan Krishi Mandi Yard to Sharma Agro Mills.',
        contextReason: 'E-Way bill verified. Estimated arrival at destination in 4 hours.',
        actionLabel: 'Track Dispatch',
        actionUrl: '/orders',
        idempotencyKey: 'idemp-disp-rj14-8821',
        deliveryStatus: 'Sent',
        isRead: true,
        readAt: now.subtract(const Duration(hours: 4)),
        createdAt: now.subtract(const Duration(hours: 6)),
        payload: {
          'dispatchId': 'disp-8821',
          'vehicle': 'RJ-14-GA-8821',
          'dealReference': 'DL-2026-0891',
        },
      ),
      BrokerNotification(
        id: 'notif-2026-005',
        userId: 'broker-demo-user',
        channel: 'IN_APP',
        eventType: 'DISPUTE_RAISED',
        category: NotificationCategory.disputesAndExceptions,
        title: 'Moisture Deduction Review Held',
        message: 'Deal DL-2026-0894: Buyer held payment pending moisture deduction arbitration.',
        contextReason: 'Moisture reported at 8.4% vs 8.0% contracted FAQ standard. Broker review requested.',
        actionLabel: 'Review Dispute',
        actionUrl: '/disputes',
        idempotencyKey: 'idemp-disp-0894-moist',
        deliveryStatus: 'Sent',
        isRead: false,
        readAt: null,
        createdAt: now.subtract(const Duration(hours: 18)),
        payload: {
          'dealId': 'deal-bkg-0045',
          'dealReference': 'DL-2026-0894',
          'disputeId': 'disp-moist-0045',
        },
      ),
      BrokerNotification(
        id: 'notif-2026-006',
        userId: 'broker-demo-user',
        channel: 'IN_APP',
        eventType: 'AVAILABILITY_EXPIRING',
        category: NotificationCategory.requirementsAndOffers,
        title: 'Seller Offer Expiring in 2 Hours',
        message: 'Offer OFF-2026-0220 (40 MT Yellow Soyabean) expires today at 5:00 PM.',
        contextReason: 'Active counterparty inquiries pending. Refresh offer validity if stock remains.',
        actionLabel: 'Inspect Offer',
        actionUrl: '/work',
        idempotencyKey: 'idemp-off-exp-0220',
        deliveryStatus: 'Sent',
        isRead: true,
        readAt: now.subtract(const Duration(hours: 12)),
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        payload: {
          'offerId': 'off-2026-0220',
          'commodity': 'Yellow Soyabean',
        },
      ),
      BrokerNotification(
        id: 'notif-2026-007',
        userId: 'broker-demo-user',
        channel: 'IN_APP',
        eventType: 'KYC_STATUS',
        category: NotificationCategory.system,
        title: 'Mandi Trade Desk Compliance Active',
        message: 'Broker APMC Mandi License and GST credentials verified successfully for FY 2026-27.',
        contextReason: 'Annual compliance audit complete. All statutory trading desk rights confirmed.',
        actionLabel: 'View Credentials',
        actionUrl: null,
        idempotencyKey: 'idemp-kyc-desk-2026',
        deliveryStatus: 'Sent',
        isRead: true,
        readAt: now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 3)),
        payload: {
          'licenseType': 'APMC_CLASS_A',
          'status': 'VERIFIED',
        },
      ),
    ]);
  }

  /// Fetches notifications with optional category and unread filters.
  /// Deduplicates items and sorts newest-first.
  Future<List<BrokerNotification>> fetchNotifications({
    NotificationCategory? category,
    bool? unreadOnly,
  }) async {
    _seedDefaultNotifications();

    // 1. Attempt REST endpoint
    try {
      final queryParams = <String, dynamic>{};
      if (category != null && category != NotificationCategory.all) {
        queryParams['category'] = category.code;
      }
      if (unreadOnly == true) {
        queryParams['unread'] = 'true';
      }

      final response = await _apiClient.get(
        '/broker/notifications',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final payload = data['data'] as Map<String, dynamic>? ?? data;
          final list = payload['notifications'] as List<dynamic>? ?? [];
          final items = list
              .whereType<Map<String, dynamic>>()
              .map(BrokerNotification.fromJson)
              .toList();
          if (items.isNotEmpty) {
            _mergeNotifications(items);
            return _filterAndSort(category: category, unreadOnly: unreadOnly);
          }
        } else if (data is List) {
          final items = data
              .whereType<Map<String, dynamic>>()
              .map(BrokerNotification.fromJson)
              .toList();
          if (items.isNotEmpty) {
            _mergeNotifications(items);
            return _filterAndSort(category: category, unreadOnly: unreadOnly);
          }
        }
      }
    } on DioException catch (e) {
      debugPrint('REST notifications notice: ${e.message} (falling back to PostgREST/store)');
    } catch (e) {
      debugPrint('REST notifications error: $e');
    }

    // 2. Fallback: Supabase PostgREST query on table `notifications`
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        final userId = session.user.id;

        var query = client
            .from('notifications')
            .select('*')
            .eq('user_id', userId);

        if (unreadOnly == true) {
          query = query.eq('is_read', false);
        }

        final response = await query.order('created_at', ascending: false).limit(100);
        final list = response as List<dynamic>;
        final items = list
            .whereType<Map<String, dynamic>>()
            .map(BrokerNotification.fromJson)
            .toList();

        if (items.isNotEmpty) {
          _mergeNotifications(items);
          return _filterAndSort(category: category, unreadOnly: unreadOnly);
        }
      }
    } catch (e) {
      debugPrint('Supabase notifications query notice: $e');
    }

    // 3. Authoritative local / in-memory store
    return _filterAndSort(category: category, unreadOnly: unreadOnly);
  }

  /// Merges newly fetched notifications into in-memory cache with deduplication.
  void _mergeNotifications(List<BrokerNotification> newItems) {
    for (final item in newItems) {
      // Deduplicate by ID or idempotencyKey
      final existingIndex = _cachedNotifications.indexWhere((existing) =>
          existing.id == item.id ||
          (item.idempotencyKey != null &&
              item.idempotencyKey!.isNotEmpty &&
              existing.idempotencyKey == item.idempotencyKey));

      if (existingIndex >= 0) {
        _cachedNotifications[existingIndex] = item;
      } else {
        _cachedNotifications.add(item);
      }
    }
  }

  /// Filters cached notifications by category and unread status, sorted newest first.
  List<BrokerNotification> _filterAndSort({
    NotificationCategory? category,
    bool? unreadOnly,
  }) {
    var items = List<BrokerNotification>.from(_cachedNotifications);

    if (category != null && category != NotificationCategory.all) {
      items = items.where((n) => n.category == category).toList();
    }

    if (unreadOnly == true) {
      items = items.where((n) => !n.isRead).toList();
    }

    // Sort newest-first
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return List.unmodifiable(items);
  }

  /// Marks a specific notification as read.
  /// Updates local state and propagates to backend.
  Future<bool> markAsRead(String notificationId) async {
    _seedDefaultNotifications();

    final index = _cachedNotifications.indexWhere((n) => n.id == notificationId);
    if (index >= 0) {
      final existing = _cachedNotifications[index];
      if (!existing.isRead) {
        _cachedNotifications[index] = existing.copyWith(
          isRead: true,
          readAt: DateTime.now(),
        );
      }
    }

    // 1. Try REST API
    try {
      final res = await _apiClient.post('/broker/notifications/$notificationId/read');
      if (res.statusCode == 200) return true;
    } catch (_) {}

    // 2. Try Supabase PostgREST
    try {
      final client = _supabase;
      if (client != null) {
        await client.from('notifications').update({
          'is_read': true,
          'read_at': DateTime.now().toIso8601String(),
        }).eq('id', notificationId);
        return true;
      }
    } catch (e) {
      debugPrint('Supabase markAsRead notice: $e');
    }

    return true;
  }

  /// Marks all unread notifications as read.
  Future<int> markAllAsRead() async {
    _seedDefaultNotifications();

    int updatedCount = 0;
    final now = DateTime.now();

    for (int i = 0; i < _cachedNotifications.length; i++) {
      if (!_cachedNotifications[i].isRead) {
        _cachedNotifications[i] = _cachedNotifications[i].copyWith(
          isRead: true,
          readAt: now,
        );
        updatedCount++;
      }
    }

    // 1. Try REST API
    try {
      final res = await _apiClient.post('/broker/notifications/read-all');
      if (res.statusCode == 200) return updatedCount;
    } catch (_) {}

    // 2. Try Supabase PostgREST
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null) {
        await client
            .from('notifications')
            .update({
              'is_read': true,
              'read_at': now.toIso8601String(),
            })
            .eq('user_id', session.user.id)
            .eq('is_read', false);
      }
    } catch (e) {
      debugPrint('Supabase markAllAsRead notice: $e');
    }

    return updatedCount;
  }

  /// Subscribes to real-time Postgres changes on the `notifications` table if Supabase is active.
  void subscribeToRealtime({required void Function(BrokerNotification) onNotificationReceived}) {
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client == null || session == null) return;

      _realtimeSubscription?.unsubscribe();

      _realtimeSubscription = client
          .channel('public:notifications:user:${session.user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: session.user.id,
            ),
            callback: (payload) {
              try {
                final notif = BrokerNotification.fromJson(payload.newRecord);
                _mergeNotifications([notif]);
                onNotificationReceived(notif);
              } catch (e) {
                debugPrint('Realtime notification parse error: $e');
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime subscription setup notice: $e');
    }
  }

  /// Cleans up real-time resources.
  void dispose() {
    _realtimeSubscription?.unsubscribe();
    _realtimeSubscription = null;
  }
}
