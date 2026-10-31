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

  // In-memory cache of rows fetched from the backend. There is no sample data:
  // an empty feed shows the empty state instead of fabricated alerts.
  final List<BrokerNotification> _cachedNotifications = [];
  RealtimeChannel? _realtimeSubscription;

  /// Fetches notifications with optional category and unread filters.
  /// Deduplicates items and sorts newest-first.
  Future<List<BrokerNotification>> fetchNotifications({
    NotificationCategory? category,
    bool? unreadOnly,
  }) async {
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

  /// Fills in names and record facts from each notification's related record.
  /// Reads run under the broker's own RLS: anything not visible stays unresolved
  /// and the card falls back to neutral wording. Never fails the feed.
  Future<List<BrokerNotification>> resolveRelated(List<BrokerNotification> items) async {
    final client = _supabase;
    if (client == null || items.isEmpty) return items;

    Future<Map<String, Map<String, dynamic>>> rows(String table, String columns, Set<String> ids) async {
      if (ids.isEmpty) return const {};
      try {
        final res = await client
            .from(table)
            .select(columns)
            .inFilter('id', ids.toList())
            .timeout(const Duration(seconds: 8));
        return {
          for (final row in (res as List).whereType<Map<String, dynamic>>()) row['id'].toString(): row,
        };
      } catch (e) {
        debugPrint('Alert details unavailable from $table: $e');
        return const {};
      }
    }

    final results = await Future.wait([
      rows(
        'requirements',
        'id, quantity, delivery_terms_id, companies(name), master_commodities(name), master_units(symbol)',
        {for (final n in items) ?n.requirementId},
      ),
      rows(
        'availabilities',
        'id, quantity, companies(name), master_commodities(name), master_units(symbol), master_districts(name)',
        {for (final n in items) ?n.offerId},
      ),
      rows('deals', 'id, buyer:companies!buyer_id(name)', {for (final n in items) ?n.dealId}),
      rows('companies', 'id, name', {
        for (final n in items)
          if (n.isWarehouseEvent && n.payload?['companyId'] != null) n.payload!['companyId'].toString(),
      }),
    ]);

    String? nested(Map<String, dynamic>? row, String key, String field) {
      final value = row?[key];
      return value is Map ? value[field]?.toString() : null;
    }

    String? quantityOf(Map<String, dynamic>? row) {
      final qty = row?['quantity'];
      if (qty is! num) return null;
      final text = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
      final unit = nested(row, 'master_units', 'symbol');
      return unit == null ? text : '$text $unit';
    }

    return items.map((n) {
      final requirement = results[0][n.requirementId];
      final offer = results[1][n.offerId];
      final deal = results[2][n.dealId];
      final company = n.isWarehouseEvent ? results[3][n.payload?['companyId']?.toString()] : null;
      final record = requirement ?? offer;
      return n.copyWith(
        counterpartyName: nested(deal, 'buyer', 'name') ??
            nested(record, 'companies', 'name') ??
            company?['name']?.toString(),
        resolvedCommodity: nested(record, 'master_commodities', 'name'),
        resolvedQuantity: quantityOf(record),
        resolvedLocation: requirement?['delivery_terms_id']?.toString() ?? nested(offer, 'master_districts', 'name'),
      );
    }).toList();
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
