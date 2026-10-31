import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/saved_location_model.dart';

/// Saved locations could not be read, as opposed to the company having none.
class SavedLocationsUnavailable implements Exception {
  final String message;
  const SavedLocationsUnavailable(this.message);

  @override
  String toString() => message;
}

/// Reads a counterparty's active locations from `company_warehouses`. Read-only:
/// choosing a location for one transaction never alters the saved address.
class SavedLocationsRepository {
  final SupabaseClient? _customClient;

  SavedLocationsRepository({SupabaseClient? client}) : _customClient = client;

  SupabaseClient? get _client {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<SavedLocation>> getSavedLocations(String companyId) async {
    final client = _client;
    if (client == null) {
      throw const SavedLocationsUnavailable('Saved locations are unavailable. Please try again.');
    }
    try {
      final rows = await client
          .from('company_warehouses')
          .select()
          .eq('company_id', companyId)
          .eq('is_active', true)
          .order('created_at', ascending: true)
          .timeout(const Duration(seconds: 15));
      return (rows as List).whereType<Map<String, dynamic>>().map(SavedLocation.fromWarehouseRow).toList();
    } catch (_) {
      throw const SavedLocationsUnavailable('Saved locations could not be loaded. Please try again.');
    }
  }

  /// Saves a new location for the company. RLS allows this only for the broker's
  /// active contacts. Rethrows with a readable message so the form can show it.
  Future<SavedLocation> addLocation({
    required String companyId,
    required String name,
    required String addressLine,
    required String stateId,
    required String districtId,
    String? pinCode,
  }) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw const SavedLocationsUnavailable('Please sign in again to add a location.');
    }
    try {
      final row = await client
          .from('company_warehouses')
          .insert({
            'company_id': companyId,
            'created_by': userId,
            'name': name,
            'address_line': addressLine,
            'state_id': stateId,
            'district_id': districtId,
            'pin_code': pinCode,
          })
          .select()
          .single()
          .timeout(const Duration(seconds: 20));
      return SavedLocation.fromWarehouseRow(row);
    } catch (_) {
      throw const SavedLocationsUnavailable('The location could not be saved. Please try again.');
    }
  }

  /// Updates this exact record. Zero affected rows (RLS or a removed record) is a
  /// failure, so an edit can never report success without persisting.
  Future<SavedLocation> updateLocation({
    required String id,
    required String companyId,
    required String name,
    required String addressLine,
    required String stateId,
    required String districtId,
    required String pinCode,
  }) async {
    final client = _client;
    if (client == null) {
      throw const SavedLocationsUnavailable('Please sign in again to edit this location.');
    }
    try {
      final row = await client
          .from('company_warehouses')
          .update({
            'name': name,
            'address_line': addressLine,
            'state_id': stateId,
            'district_id': districtId,
            'pin_code': pinCode,
          })
          .eq('id', id)
          .eq('company_id', companyId)
          .select()
          .single()
          .timeout(const Duration(seconds: 20));
      return SavedLocation.fromWarehouseRow(row);
    } catch (_) {
      throw const SavedLocationsUnavailable('The location could not be updated. Please try again.');
    }
  }

  /// The saved default when there is one, otherwise the first valid location.
  Future<SavedLocation?> getDefaultLocation(String companyId) async {
    final list = await getSavedLocations(companyId);
    if (list.isEmpty) return null;
    return list.firstWhere((l) => l.isPrimary, orElse: () => list.first);
  }
}

final savedLocationsRepositoryProvider = Provider<SavedLocationsRepository>((ref) {
  return SavedLocationsRepository();
});