import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/secure_storage_service.dart';
import '../domain/buyer_profile.dart';

/// Loads and saves the signed-in buyer's own profile through Supabase.
///
/// Reads `users` (own row) and `companies` (own company). Writes only `name`
/// and `mobile` on the buyer's own `users` row, which `users_update_policy`
/// permits; the company record is never written from the Buyer app.
class BuyerProfileRepository {
  final SupabaseClient? _customClient;
  final SecureStorageService _storage;

  BuyerProfileRepository({
    SupabaseClient? client,
    SecureStorageService? storage,
  }) : _customClient = client,
       _storage = storage ?? SecureStorageService();

  SupabaseClient? get _supabase {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient _requireClient() {
    final client = _supabase;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw StateError('Not signed in.');
    }
    return client;
  }

  /// Throws when the profile cannot be loaded; never returns placeholder data.
  Future<BuyerProfile> getProfile() async {
    final client = _requireClient();
    final userId = client.auth.currentUser!.id;
    final user = await client
        .from('users')
        .select('id, name, email, mobile, role, company_id')
        .eq('id', userId)
        .single();

    Map<String, dynamic>? company;
    final companyId = user['company_id']?.toString();
    if (companyId != null && companyId.isNotEmpty) {
      company = await client
          .from('companies')
          .select('id, name, gst, is_verified')
          .eq('id', companyId)
          .maybeSingle();
    }
    return profileFromRows(
      user,
      company,
      authEmail: client.auth.currentUser?.email,
    );
  }

  /// Saves only the fields in [changes] (`name`, `mobile`) and returns the
  /// profile with the values the server stored. Throws when the server does
  /// not confirm the write (including a write that matched no row).
  Future<BuyerProfile> updateProfile(
    BuyerProfile current,
    Map<String, Object?> changes,
  ) async {
    final allowed = editableChanges(changes);
    if (allowed.isEmpty) return current;

    final client = _requireClient();
    final saved = await client
        .from('users')
        .update(allowed)
        .eq('id', current.id)
        .select('name, mobile')
        .single();

    final updated = current.copyWith(
      name: saved['name']?.toString(),
      mobile: saved['mobile']?.toString(),
      clearMobile: saved['mobile'] == null,
    );
    try {
      await _storage.saveUserName(updated.name);
    } catch (e) {
      debugPrint('Profile name cache update notice: $e');
    }
    return updated;
  }

  /// Columns the Buyer app may write; everything else (email, role, status,
  /// company_id, any company column) is dropped before the request is built.
  static const Set<String> editableColumns = {'name', 'mobile'};

  @visibleForTesting
  static Map<String, Object?> editableChanges(Map<String, Object?> changes) => {
    for (final e in changes.entries)
      if (editableColumns.contains(e.key)) e.key: e.value,
  };

  @visibleForTesting
  static BuyerProfile profileFromRows(
    Map<String, dynamic> user,
    Map<String, dynamic>? company, {
    String? authEmail,
  }) {
    String? text(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return BuyerProfile(
      id: user['id'].toString(),
      name: text(user['name']) ?? '',
      mobile: text(user['mobile']),
      email: text(user['email']) ?? text(authEmail),
      role: (text(user['role']) ?? '').toLowerCase(),
      companyId: text(user['company_id']),
      companyName: text(company?['name']),
      companyGst: text(company?['gst']),
      companyVerified: company?['is_verified'] as bool?,
    );
  }
}
