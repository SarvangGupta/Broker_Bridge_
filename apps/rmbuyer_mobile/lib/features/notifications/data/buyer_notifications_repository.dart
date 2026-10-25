import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/buyer_notification_model.dart';

/// Reads and updates the signed-in Buyer's own rows in `public.notifications`.
///
/// Access is enforced by RLS (`notifications_select_policy` /
/// `notifications_update_policy`: `user_id = auth.uid()`); the `user_id` filter
/// below only narrows the query. Errors are thrown, never replaced with sample rows.
class BuyerNotificationsRepository {
  final SupabaseClient? _customClient;

  /// Rows fetched per load; the screen says so when this limit is reached.
  static const int pageSize = 50;

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

  (SupabaseClient, String) _session() {
    final client = _supabase;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw StateError('Not signed in.');
    }
    return (client, userId);
  }

  /// Latest [pageSize] notifications for the signed-in user, newest first,
  /// de-duplicated by notification ID.
  Future<List<BuyerNotification>> getNotifications() async {
    final (client, userId) = _session();
    final rows = await client
        .from('notifications')
        .select(
          'id, title, message, context_reason, event_type, is_read, read_at, created_at, action_url, payload',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(pageSize);
    return dedupe([
      for (final row in (rows as List).whereType<Map<String, dynamic>>())
        BuyerNotification.fromMap(row),
    ]);
  }

  /// Marks one notification read. Returns only after the server confirms the
  /// row it updated; throws otherwise (including when no row matched).
  Future<void> markAsRead(String id) async {
    final (client, userId) = _session();
    final row = await client
        .from('notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', userId)
        .select('id, is_read')
        .single();
    if (row['is_read'] != true) {
      throw StateError('Notification was not marked as read.');
    }
  }

  /// Marks every unread notification read; returns the IDs the server updated.
  Future<Set<String>> markAllAsRead() async {
    final (client, userId) = _session();
    final rows = await client
        .from('notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('is_read', false)
        .select('id');
    return {
      for (final r in (rows as List).whereType<Map<String, dynamic>>())
        r['id'].toString(),
    };
  }

  /// Whether [requirementId] belongs to the signed-in Buyer's company. The
  /// requirements read policy also exposes other companies' open global
  /// requirements, so ownership is checked explicitly, not only via RLS.
  Future<bool> isOwnRequirement(String requirementId) async {
    final (client, userId) = _session();
    final me = await client
        .from('users')
        .select('company_id')
        .eq('id', userId)
        .maybeSingle();
    final companyId = me?['company_id']?.toString();
    if (companyId == null || companyId.isEmpty) return false;
    final row = await client
        .from('requirements')
        .select('id')
        .eq('id', requirementId)
        .eq('company_id', companyId)
        .maybeSingle();
    return row != null;
  }

  /// Keeps the first occurrence of each ID; rows without an ID are dropped.
  static List<BuyerNotification> dedupe(List<BuyerNotification> items) {
    final seen = <String>{};
    return [
      for (final n in items)
        if (n.id.isNotEmpty && seen.add(n.id)) n,
    ];
  }
}
