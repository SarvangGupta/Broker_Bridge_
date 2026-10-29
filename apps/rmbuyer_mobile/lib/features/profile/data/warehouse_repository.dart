import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/company_warehouse.dart';

/// Data source contract for company warehouses.
abstract class WarehouseDataSource {
  Future<List<CompanyWarehouse>> listFor(String companyId);
  Future<CompanyWarehouse> upsert(CompanyWarehouse warehouse, String userId);
  Future<void> toggleActive(String warehouseId, bool isActive);
  Future<void> delete(String warehouseId);
}

/// Supabase implementation reading and writing `company_warehouses` (migration 0055).
class SupabaseWarehouseDataSource implements WarehouseDataSource {
  static const Duration timeout = Duration(seconds: 15);
  final SupabaseClient? _customClient;

  SupabaseWarehouseDataSource({SupabaseClient? client})
      : _customClient = client;

  SupabaseClient get _client => _customClient ?? Supabase.instance.client;

  @override
  Future<List<CompanyWarehouse>> listFor(String companyId) async {
    final rows = await _client
        .from('company_warehouses')
        .select()
        .eq('company_id', companyId)
        .order('is_active', ascending: false)
        .order('created_at', ascending: false)
        .timeout(timeout);

    return (rows as List)
        .map((r) => CompanyWarehouse.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<CompanyWarehouse> upsert(
    CompanyWarehouse warehouse,
    String userId,
  ) async {
    final map = warehouse.toMap();
    map['created_by'] = userId;
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();

    if (warehouse.id.isEmpty) {
      // New record
      final inserted = await _client
          .from('company_warehouses')
          .insert(map)
          .select()
          .single()
          .timeout(timeout);
      return CompanyWarehouse.fromRow(Map<String, dynamic>.from(inserted));
    } else {
      // Update existing
      final updated = await _client
          .from('company_warehouses')
          .update(map)
          .eq('id', warehouse.id)
          .eq('company_id', warehouse.companyId)
          .select()
          .single()
          .timeout(timeout);
      return CompanyWarehouse.fromRow(Map<String, dynamic>.from(updated));
    }
  }

  @override
  Future<void> toggleActive(String warehouseId, bool isActive) async {
    await _client
        .from('company_warehouses')
        .update({
          'is_active': isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', warehouseId)
        .timeout(timeout);
  }

  @override
  Future<void> delete(String warehouseId) async {
    await _client
        .from('company_warehouses')
        .delete()
        .eq('id', warehouseId)
        .timeout(timeout);
  }
}

class EmptyWarehouseDataSource implements WarehouseDataSource {
  const EmptyWarehouseDataSource();

  @override
  Future<List<CompanyWarehouse>> listFor(String companyId) async => const [];

  @override
  Future<CompanyWarehouse> upsert(
    CompanyWarehouse warehouse,
    String userId,
  ) async => warehouse;

  @override
  Future<void> toggleActive(String warehouseId, bool isActive) async {}

  @override
  Future<void> delete(String warehouseId) async {}
}

/// Repository for managing operational warehouses and unloading sites.
class WarehouseRepository {
  final WarehouseDataSource _source;
  final SupabaseClient? _client;

  WarehouseRepository({
    WarehouseDataSource? source,
    SupabaseClient? client,
  })  : _source = source ??
            (client != null || _hasSupabase()
                ? SupabaseWarehouseDataSource(client: client)
                : const EmptyWarehouseDataSource()),
        _client = client;

  static bool _hasSupabase() {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  String? get currentUserId {
    try {
      return (_client ?? Supabase.instance.client).auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Future<List<CompanyWarehouse>> getWarehouses(String companyId) =>
      _source.listFor(companyId);

  Future<CompanyWarehouse> saveWarehouse(
    CompanyWarehouse warehouse, {
    String? userId,
  }) async {
    final uid = userId ?? currentUserId;
    if (uid == null || uid.isEmpty) {
      throw StateError('User must be signed in to save warehouse.');
    }
    return _source.upsert(warehouse, uid);
  }

  Future<void> toggleActive(String warehouseId, bool isActive) =>
      _source.toggleActive(warehouseId, isActive);

  Future<void> deleteWarehouse(String warehouseId) =>
      _source.delete(warehouseId);
}
