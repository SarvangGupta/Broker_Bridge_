import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/secure_storage_service.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/commodity_model.dart';
import '../domain/master_commodity_data.dart';

/// Repository managing Seller commodity listings, lot-level inventory,
/// and authoritative database synchronization with the `availabilities` table.
/// A price change the server did not confirm; [message] is user-facing.
class PriceUpdateException implements Exception {
  final String message;
  const PriceUpdateException(this.message);

  @override
  String toString() => message;
}

/// A listing the server did not save; [message] is safe to show the seller.
class ListingSubmitException implements Exception {
  static const String generic =
      'Unable to publish your commodity right now. Please try again or '
      'contact support if the problem continues.';

  final String message;
  final String? code;
  const ListingSubmitException(this.message, {this.code});

  @override
  String toString() => message;
}

/// The seller's lots could not be read; [message] is safe to show.
class CommodityListException implements Exception {
  static const String generic =
      'Could not load your commodity lots. Check your connection and try again.';

  final String message;
  const CommodityListException(this.message);

  @override
  String toString() => message;
}

/// A status change (Fulfil / Withdraw) the server did not confirm.
class StatusUpdateException implements Exception {
  static const String generic =
      'Could not update the lot status. Check your connection and try again.';

  final String message;
  const StatusUpdateException(this.message);

  @override
  String toString() => message;
}

/// A broker change the server did not confirm; [message] is user-facing.
class BrokerUpdateException implements Exception {
  final String message;
  const BrokerUpdateException(this.message);

  @override
  String toString() => message;
}

/// Ownership representation for Seller listing isolation: either an enterprise
/// company or an authorized individual seller identity.
enum SellerOwnershipType { company, individual }

class SellerOwnership {
  final SellerOwnershipType type;
  final String? companyId;
  final String? userId;

  const SellerOwnership._({required this.type, this.companyId, this.userId});

  factory SellerOwnership.company(String companyId) =>
      SellerOwnership._(type: SellerOwnershipType.company, companyId: companyId);

  factory SellerOwnership.individual(String userId) =>
      SellerOwnership._(type: SellerOwnershipType.individual, userId: userId);

  bool get isCompany => type == SellerOwnershipType.company;
  bool get isIndividual => type == SellerOwnershipType.individual;

  /// Cache key for partitioning session-stored lots
  String get cacheKey => isCompany ? companyId! : 'individual_$userId';
}

/// Error type only, for logs that must not carry row values or tokens.
String _errorCode(Object e) =>
    e is PostgrestException ? 'code=${e.code}' : e.runtimeType.toString();

class CommoditiesRepository {
  final SupabaseClient? _customClient;
  final SecureStorageService _storage;

  // In-memory registry of newly posted commodities during session, partitioned by company
  static final Map<String, List<SellerCommodity>> _sessionCommoditiesByCompany =
      {};
  bool _isSubmissionLocked = false;

  /// Global notifier signaled whenever a commodity lot is created, updated, or cancelled
  static final ValueNotifier<int> commoditiesUpdatedNotifier =
      ValueNotifier<int>(0);

  /// Helper to clear session cache on logout
  static void clearSessionCache() {
    _sessionCommoditiesByCompany.clear();
  }

  CommoditiesRepository({SupabaseClient? client, SecureStorageService? storage})
    : _customClient = client,
      _storage = storage ?? SecureStorageService();

  SupabaseClient? get _supabase {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ============================================================================
  // 1. MASTER REFERENCE DATA
  // ============================================================================

  /// Active (tradable) products from the shared Product Master, A→Z, each with its
  /// authoritative category name. Throws when the catalogue cannot be loaded: there is
  /// no offline list, so callers must show an error with retry.
  Future<List<MasterCommodity>> getMasterCommodities() async {
    final client = _supabase;
    if (client == null) {
      throw StateError('Product catalogue service is not available.');
    }
    final data = await client
        .from('master_commodities')
        .select('id, name, code, status, category_id')
        .eq('status', true)
        // postgrest-dart's order() defaults to descending.
        .order('name', ascending: true);
    final categoryNames = await _loadCategoryNames(client);

    return (data as List)
        .whereType<Map<String, dynamic>>()
        .where((row) => row['status'] != false && (row['id']?.toString() ?? '').isNotEmpty)
        .map(
          (row) => MasterCommodity.fromMap(
            row,
            categoryName: categoryNames[row['category_id']?.toString()],
          ),
        )
        .toList();
  }

  /// Category id → name. A failure yields an empty map so products still load and the
  /// form shows "Category unavailable" rather than a guessed label.
  Future<Map<String, String>> _loadCategoryNames(SupabaseClient client) async {
    try {
      final rows = await client.from('master_categories').select('id, name');
      return {
        for (final r in (rows as List).whereType<Map<String, dynamic>>())
          r['id'].toString(): r['name']?.toString() ?? '',
      };
    } catch (e) {
      debugPrint('Category names unavailable: $e');
      return const {};
    }
  }

  /// Grades linked to [commodityId] only. Returns an empty list when the product has
  /// no grade yet (never a synthetic one); throws when the request fails.
  Future<List<MasterGrade>> getMasterGrades(String commodityId) async {
    final client = _supabase;
    if (client == null) {
      throw StateError('Product catalogue service is not available.');
    }
    if (commodityId.isEmpty) return const [];
    final data = await client
        .from('master_grades')
        .select('id, commodity_id, grade_name, parameters')
        .eq('commodity_id', commodityId)
        .order('grade_name', ascending: true);

    return (data as List)
        .whereType<Map<String, dynamic>>()
        .map(MasterGrade.fromMap)
        .where((g) => g.commodityId == commodityId)
        .toList();
  }

  Future<List<MasterUnit>> getMasterUnits() async {
    final client = _supabase;
    if (client != null) {
      try {
        final data = await client
            .from('master_units')
            .select('id, name, symbol');
        if (data.isNotEmpty) {
          return (data as List)
              .map((row) => MasterUnit.fromMap(row as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('Master units fetch notice: $e');
      }
    }
    return MasterCommodityData.verifiedUnits;
  }

  Future<List<MasterState>> getMasterStates() async {
    final client = _supabase;
    if (client != null) {
      try {
        final data = await client
            .from('master_states')
            .select('id, name, code')
            .order('name');
        if (data.isNotEmpty) {
          return (data as List)
              .map((row) => MasterState.fromMap(row as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('Master states fetch notice: $e');
      }
    }
    return MasterCommodityData.verifiedStates;
  }

  Future<List<MasterDistrict>> getMasterDistricts(String stateId) async {
    final client = _supabase;
    if (client != null && stateId.isNotEmpty) {
      try {
        final data = await client
            .from('master_districts')
            .select('id, state_id, name')
            .eq('state_id', stateId)
            .order('name');

        if (data.isNotEmpty) {
          return (data as List)
              .map((row) => MasterDistrict.fromMap(row as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('Master districts fetch notice: $e');
      }
    }

    final fallbacks = MasterCommodityData.verifiedDistricts
        .where((d) => d.stateId == stateId)
        .toList();

    return fallbacks;
  }

  Future<List<MasterMandi>> getMasterMandis(String districtId) async {
    final client = _supabase;
    if (client != null && districtId.isNotEmpty) {
      try {
        final data = await client
            .from('master_mandis')
            .select('id, district_id, state_id, name, yard_type')
            .eq('district_id', districtId)
            .order('name');

        if (data.isNotEmpty) {
          return (data as List)
              .map((row) => MasterMandi.fromMap(row as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('Master mandis fetch notice: $e');
      }
    }

    final fallbacks = MasterCommodityData.verifiedMandis
        .where((m) => m.districtId == districtId)
        .toList();

    return fallbacks;
  }

  List<String> getLoadingStatusOptions() =>
      MasterCommodityData.verifiedLoadingStatuses;
  List<String> getPaymentTermsOptions() =>
      MasterCommodityData.verifiedPaymentTerms;

  // ============================================================================
  // 2. COMMODITY CREATION & PERSISTENCE
  // ============================================================================

  /// Submit a verified Seller commodity listing / lot with authoritative validation
  /// and concurrency duplicate prevention.
  Future<SellerCommodity> createCommodity(CreateCommodityDto dto) async {
    // 1. Business Validation
    if (dto.commodityId.trim().isEmpty) {
      throw ArgumentError('Commodity selection is required');
    }
    if (dto.totalQuantity <= 0) {
      throw ArgumentError('Total quantity must be greater than zero');
    }
    if (dto.askingPrice <= 0) {
      throw ArgumentError('Asking price must be a positive number');
    }
    if (dto.lotNumber.trim().isEmpty) {
      throw ArgumentError('Lot/Batch number is required');
    }

    // 2. Concurrency Lock: Prevent duplicate submissions
    if (_isSubmissionLocked) {
      throw StateError(
        'A commodity submission is already in progress. Please wait.',
      );
    }
    _isSubmissionLocked = true;

    try {
      final client = _supabase;
      String? companyId;
      try {
        companyId = await _storage.getCompanyId().timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => null,
        );
      } catch (_) {}

      // Check session user or fallback to verified seller company ID
      if (companyId == null || companyId.isEmpty) {
        final sessionUser = client?.auth.currentUser;
        if (sessionUser != null && client != null) {
          try {
            final userRow = await client
                .from('users')
                .select('company_id')
                .eq('id', sessionUser.id)
                .maybeSingle();
            companyId = userRow?['company_id']?.toString();
          } catch (_) {}
        }
      }

      companyId ??= '20000000-0000-0000-0000-000000000101';

      String listingId =
          'AVL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      String cacheKey = companyId;
      SellerOwnership? ownership;

      if (client != null) {
        ownership = await _resolveSellerOwnership(
          client,
          (m) => ListingSubmitException(m),
          ListingSubmitException.generic,
        );
        cacheKey = ownership.cacheKey;

        final insertPayload = ownership.isCompany
            ? dto.toSupabaseInsert(companyId: ownership.companyId)
            : dto.toSupabaseInsert(sellerUserId: ownership.userId);

        try {
          final res = await client
              .from('availabilities')
              .insert(insertPayload)
              .select('id, created_at, status')
              .single();
          listingId = res['id'].toString();
        } on PostgrestException catch (e) {
          // Log the code only; the message can echo row values.
          debugPrint('Availability insert rejected: code=${e.code}');
          throw ListingSubmitException(
            switch (e.code) {
              '42501' =>
                'Your account is not yet allowed to publish listings. '
                    'Please contact support.',
              '23505' =>
                'Lot ${dto.lotNumber.trim()} is already listed. '
                    'Check My Commodities instead of posting it again.',
              _ => ListingSubmitException.generic,
            },
            code: e.code,
          );
        } catch (e) {
          debugPrint('Availability insert failed: ${_errorCode(e)}');
          throw const ListingSubmitException(ListingSubmitException.generic);
        }
      }

      final createdCommodity = SellerCommodity(
        id: listingId,
        lotNumber: dto.lotNumber,
        commodityName: dto.commodityName,
        gradeName: dto.gradeName,
        totalQuantity: dto.totalQuantity,
        availableQuantity: dto.totalQuantity,
        reservedQuantity: 0.0,
        soldQuantity: 0.0,
        unit: dto.unitSymbol,
        askingPrice: dto.askingPrice,
        confidentialMinimumPrice: dto.confidentialMinimumPrice,
        stateName: dto.stateName,
        districtName: dto.districtName,
        loadingStatus: dto.loadingStatus,
        status: 'Open',
        availableFrom: dto.availableFrom,
        validUntil: dto.validUntil,
        brokerId: dto.brokerId,
        brokerName:
            dto.brokerName ??
            (dto.brokerId != null ? 'Assigned Mandi Broker Desk' : null),
        brokerPhone: dto.brokerPhone,
        brokerLocation: dto.brokerLocation,
        commodityId: dto.commodityId,
        gradeId: dto.gradeId,
        unitId: dto.unitId,
        stateId: dto.stateId,
        districtId: dto.districtId,
        paymentTerms: dto.paymentTerms,
        officeLocation: dto.officeLocation,
        warehouseName: dto.warehouseName,
        mandiName: dto.mandiName,
        loadingRemarks: dto.loadingRemarks,
        labReportNumber: dto.labReportNumber,
        labName: dto.labName,
        labReportFileUrl: dto.labReportFileUrl,
        labReportFileName: dto.labReportFileName,
        companyId: client != null && ownership?.isCompany == true
            ? ownership!.companyId
            : (client != null ? null : companyId),
        sellerUserId: client != null && ownership?.isIndividual == true
            ? ownership!.userId
            : null,
        version: 1,
        createdAt: DateTime.now(),
      );

      // Register into session cache, partitioned by company or individual seller
      _sessionCommoditiesByCompany
          .putIfAbsent(cacheKey, () => [])
          .insert(0, createdCommodity);

      // Notify active listeners
      commoditiesUpdatedNotifier.value++;

      return createdCommodity;
    } finally {
      _isSubmissionLocked = false;
    }
  }

  // ============================================================================
  // 3. COMMODITY LISTING & QUERYING
  // ============================================================================

  /// Fetch Seller commodity listings with optional status filter.
  /// Scoped to authenticated Seller's company or individual seller identity.
  Future<List<SellerCommodity>> getCommodities({String? statusFilter}) async {
    final client = _supabase;
    final List<SellerCommodity> results = [];

    final String cacheKey;
    SellerOwnership? ownership;
    if (client != null) {
      ownership = await _resolveSellerOwnershipOrNull(
        client,
        (m) => CommodityListException(m),
        CommodityListException.generic,
      );
      if (ownership == null) {
        return const [];
      }
      cacheKey = ownership.cacheKey;
    } else {
      cacheKey = await _offlineCompanyId();
    }

    // Prepend newly posted commodities from this session for this company/seller only
    final sessionItems = _sessionCommoditiesByCompany[cacheKey] ?? [];
    results.addAll(sessionItems);

    if (client != null && ownership != null) {
      try {
        var query = client
            .from('availabilities')
            .select(
              'id, company_id, seller_user_id, commodity_id, grade_id, quantity, unit_id, price, state_id, district_id, status, lot_number, total_quantity, available_quantity, reserved_quantity, sold_quantity, asking_price, confidential_minimum_price, available_from, valid_until, loading_status, loading_remarks, broker_id, version, created_at, master_commodities(name), master_grades(grade_name), master_units(symbol), master_states(name), master_districts(name), broker:users!availabilities_broker_id_fkey(name, mobile)',
            );

        if (ownership.isCompany) {
          query = query.eq('company_id', ownership.companyId!);
        } else {
          query = query
              .isFilter('company_id', null)
              .eq('seller_user_id', ownership.userId!);
        }

        if (statusFilter != null && statusFilter != 'ALL') {
          query = query.eq('status', statusFilter);
        }

        final data = await query
            .order('created_at', ascending: false)
            .limit(50);

        for (final item in data) {
          final id = item['id'].toString();
          if (results.any((r) => r.id == id)) continue;

          final comm = item['master_commodities'] as Map<String, dynamic>?;
          final grade = item['master_grades'] as Map<String, dynamic>?;
          final unit = item['master_units'] as Map<String, dynamic>?;
          final state = item['master_states'] as Map<String, dynamic>?;
          final dist = item['master_districts'] as Map<String, dynamic>?;

          results.add(
            SellerCommodity(
              id: id,
              lotNumber:
                  item['lot_number'] as String? ??
                  'LOT-${id.substring(0, 5).toUpperCase()}',
              commodityName:
                  comm?['name'] as String? ?? 'Agricultural Commodity',
              gradeName:
                  grade?['grade_name'] as String? ?? 'Standard Grade FAQ',
              totalQuantity:
                  (item['total_quantity'] as num?)?.toDouble() ??
                  (item['quantity'] as num?)?.toDouble() ??
                  0.0,
              availableQuantity:
                  (item['available_quantity'] as num?)?.toDouble() ??
                  (item['quantity'] as num?)?.toDouble() ??
                  0.0,
              reservedQuantity:
                  (item['reserved_quantity'] as num?)?.toDouble() ?? 0.0,
              soldQuantity: (item['sold_quantity'] as num?)?.toDouble() ?? 0.0,
              unit: unit?['symbol'] as String? ?? 'MT',
              askingPrice:
                  (item['asking_price'] as num?)?.toDouble() ??
                  (item['price'] as num?)?.toDouble() ??
                  0.0,
              confidentialMinimumPrice:
                  (item['confidential_minimum_price'] as num?)?.toDouble(),
              stateName: state?['name'] as String? ?? 'Rajasthan',
              districtName: dist?['name'] as String? ?? 'Bikaner',
              loadingStatus:
                  item['loading_status'] as String? ?? 'Ready to Load',
              status: item['status'] as String? ?? 'Open',
              availableFrom: item['available_from'] != null
                  ? DateTime.tryParse(item['available_from'].toString()) ??
                        DateTime.now()
                  : DateTime.now(),
              validUntil: item['valid_until'] != null
                  ? DateTime.tryParse(item['valid_until'].toString()) ??
                        DateTime.now().add(const Duration(days: 7))
                  : DateTime.now().add(const Duration(days: 7)),
              brokerId: item['broker_id'] as String?,
              // Real broker from the broker_id FK, not a placeholder label.
              brokerName: item['broker_id'] == null
                  ? null
                  : (item['broker'] as Map<String, dynamic>?)?['name']
                            as String? ??
                        'Assigned broker',
              brokerPhone:
                  (item['broker'] as Map<String, dynamic>?)?['mobile']
                      as String?,
              loadingRemarks: item['loading_remarks'] as String?,
              commodityId: item['commodity_id'] as String?,
              gradeId: item['grade_id'] as String?,
              unitId: item['unit_id'] as String?,
              stateId: item['state_id'] as String?,
              districtId: item['district_id'] as String?,
              companyId: item['company_id'] as String?,
              sellerUserId: item['seller_user_id'] as String?,
              version: (item['version'] as num?)?.toInt() ?? 1,
              createdAt: item['created_at'] != null
                  ? DateTime.tryParse(item['created_at'].toString()) ??
                        DateTime.now()
                  : DateTime.now(),
            ),
          );
        }
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST301' ||
            (e.message.toLowerCase().contains('jwt') &&
                e.message.toLowerCase().contains('expired'))) {
          final recovery = await AuthRepository(
            supabase: client,
            storage: _storage,
          ).recoverSession(force: true);
          if (recovery == SessionRecoveryState.recovered) {
            return getCommodities(statusFilter: statusFilter);
          }
          throw const CommodityListException(
            'Your session has expired. Please sign in again.',
          );
        }
        debugPrint('Availabilities fetch failed: ${_errorCode(e)}');
        throw const CommodityListException(CommodityListException.generic);
      } catch (e) {
        // A failed read is an error, never an empty list or sample data.
        debugPrint('Availabilities fetch failed: ${_errorCode(e)}');
        throw const CommodityListException(CommodityListException.generic);
      }
      // Real (possibly empty) server data; sample lots are offline-only.
      return results;
    }

    if (results.isEmpty) {
      var fallbacks = _baselineCommodities;
      if (statusFilter != null && statusFilter != 'ALL') {
        fallbacks = fallbacks
            .where((c) => c.status.toLowerCase() == statusFilter.toLowerCase())
            .toList();
      }
      return fallbacks;
    }

    return results;
  }

  /// True when a backend is configured (false in offline/test mode).
  bool get isOnline => _supabase != null;

  /// The seller's real listings, for "previously posted" suggestions. Empty in
  /// offline/test mode, so the sample lots are never shown as history. Throws
  /// [CommodityListException] when the server read fails (not "no history").
  Future<List<SellerCommodity>> getPostingHistory() async {
    if (_supabase == null) return const [];
    return getCommodities();
  }

  Future<SellerCommodity?> getCommodityById(String id) async {
    final list = await getCommodities();
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Changes the lot status (e.g. Fulfilled, Cancelled). Returns the status
  /// the server confirms it stored; throws [StatusUpdateException] when
  /// nothing was saved, so callers never show an unconfirmed state.
  Future<String> updateCommodityStatus(
    String commodityId,
    String newStatus,
  ) async {
    final client = _supabase;
    final String companyId;
    String confirmed = newStatus;

    if (client != null) {
      if (!CreateCommodityDto.isValidUuid(commodityId)) {
        throw const StatusUpdateException(
          'This lot is not saved on the server, so its status cannot be changed.',
        );
      }
      final ownership = await _resolveSellerOwnership(
        client,
        (m) => StatusUpdateException(m),
        StatusUpdateException.generic,
      );
      List<dynamic> rows;
      try {
        var query = client
            .from('availabilities')
            .update({'status': newStatus})
            .eq('id', commodityId);

        if (ownership.isCompany) {
          query = query.eq('company_id', ownership.companyId!);
        } else {
          query = query
              .isFilter('company_id', null)
              .eq('seller_user_id', ownership.userId!);
        }

        rows = await query.select('id, status');
      } on PostgrestException catch (e) {
        debugPrint('Status update rejected: code=${e.code}');
        throw StatusUpdateException(
          e.code == '42501'
              ? 'Your account is not allowed to change this lot.'
              : StatusUpdateException.generic,
        );
      } catch (e) {
        debugPrint('Status update failed: ${_errorCode(e)}');
        throw const StatusUpdateException(StatusUpdateException.generic);
      }
      if (rows.isEmpty) {
        throw const StatusUpdateException(
          'The status was not changed: this lot was not found for your account.',
        );
      }
      confirmed =
          (rows.first as Map<String, dynamic>)['status']?.toString() ?? '';
      if (confirmed != newStatus) {
        throw const StatusUpdateException(StatusUpdateException.generic);
      }
      // Mirror the confirmed value into the session cache.
      final sessionList = _sessionCommoditiesByCompany[ownership.cacheKey];
      final idx = sessionList?.indexWhere((c) => c.id == commodityId) ?? -1;
      if (idx != -1) {
        sessionList![idx] = sessionList[idx].copyWith(status: confirmed);
      }
    } else {
      companyId = await _offlineCompanyId();
      // Offline/test mode: only lots held in this session's cache can change.
      final known = _sessionCommoditiesByCompany[companyId]?.any(
        (c) => c.id == commodityId,
      );
      if (known != true) {
        throw const StatusUpdateException(
          'This lot is not saved, so its status cannot be changed.',
        );
      }
      final sessionList = _sessionCommoditiesByCompany[companyId];
      final idx = sessionList?.indexWhere((c) => c.id == commodityId) ?? -1;
      if (idx != -1) {
        sessionList![idx] = sessionList[idx].copyWith(status: confirmed);
      }
    }

    commoditiesUpdatedNotifier.value++;
    return confirmed;
  }

  /// Update asking price for an active lot with seller company scoping
  /// Returns the asking price the server confirms it stored. Throws
  /// [PriceUpdateException] when nothing was saved, so callers never report a
  /// price that is not persisted.
  Future<double> updateCommodityPrice(String commodityId, double newPrice) async {
    if (newPrice <= 0 || !newPrice.isFinite) {
      throw const PriceUpdateException('Asking price must be positive.');
    }
    final client = _supabase;
    final String companyId;

    double confirmed = newPrice;
    if (client != null) {
      if (!CreateCommodityDto.isValidUuid(commodityId)) {
        // e.g. the offline sample lots: they do not exist on the server.
        throw const PriceUpdateException(
          'This lot is not saved on the server, so its price cannot be updated.',
        );
      }
      final ownership = await _resolveSellerOwnership(
        client,
        (m) => PriceUpdateException(m),
        'Could not update the price. Check your connection and try again.',
      );
      List<dynamic> rows;
      try {
        var query = client
            .from('availabilities')
            .update({
              'price': newPrice.toString(),
              'asking_price': newPrice.toString(),
            })
            .eq('id', commodityId);

        if (ownership.isCompany) {
          query = query.eq('company_id', ownership.companyId!);
        } else {
          query = query
              .isFilter('company_id', null)
              .eq('seller_user_id', ownership.userId!);
        }

        rows = await query.select('id, asking_price, price');
      } on PostgrestException catch (e) {
        debugPrint('Price update rejected: code=${e.code}');
        throw PriceUpdateException(
          e.code == '42501'
              ? 'Your account is not allowed to change this lot.'
              : 'Could not update the price. Check your connection and try again.',
        );
      } catch (e) {
        debugPrint('Supabase price update error: $e');
        throw const PriceUpdateException(
          'Could not update the price. Check your connection and try again.',
        );
      }
      if (rows.isEmpty) {
        throw const PriceUpdateException(
          'The price was not updated: this lot was not found for your account.',
        );
      }
      final row = rows.first as Map<String, dynamic>;
      confirmed =
          double.tryParse('${row['asking_price'] ?? row['price']}') ?? newPrice;

      // Mirror the confirmed value into the session cache.
      final sessionList = _sessionCommoditiesByCompany[ownership.cacheKey];
      final idx = sessionList?.indexWhere((c) => c.id == commodityId) ?? -1;
      if (idx != -1) {
        sessionList![idx] = sessionList[idx].copyWith(askingPrice: confirmed);
      }
    } else {
      companyId = await _offlineCompanyId();
      // Offline/test mode: only lots held in this session's cache can change.
      final known = _sessionCommoditiesByCompany[companyId]?.any(
        (c) => c.id == commodityId,
      );
      if (known != true) {
        throw const PriceUpdateException(
          'This lot is not saved, so its price cannot be updated.',
        );
      }
      final sessionList = _sessionCommoditiesByCompany[companyId];
      final idx = sessionList?.indexWhere((c) => c.id == commodityId) ?? -1;
      if (idx != -1) {
        sessionList![idx] = sessionList[idx].copyWith(askingPrice: confirmed);
      }
    }

    commoditiesUpdatedNotifier.value++;
    return confirmed;
  }

  /// Offline/test mode only: the stored company id, else the demo company.
  Future<String> _offlineCompanyId() async {
    String? id;
    try {
      id = await _storage.getCompanyId().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => null,
      );
    } catch (_) {}
    return (id == null || id.isEmpty)
        ? '20000000-0000-0000-0000-000000000101'
        : id;
  }

  Future<SellerOwnership> _resolveSellerOwnership(
    SupabaseClient client,
    Exception Function(String message) error, [
    String generic = CommodityListException.generic,
  ]) async {
    final ownership = await _resolveSellerOwnershipOrNull(client, error, generic);
    if (ownership == null) {
      throw error(
        'Your account is not provisioned as a seller. Please contact support.',
      );
    }
    return ownership;
  }

  Future<SellerOwnership?> _resolveSellerOwnershipOrNull(
    SupabaseClient client,
    Exception Function(String message) error, [
    String generic = CommodityListException.generic,
  ]) async {
    var session = client.auth.currentSession;
    if (session == null || session.isExpired) {
      final recovery = await AuthRepository(
        supabase: client,
        storage: _storage,
      ).recoverSession();

      if (recovery == SessionRecoveryState.networkError) {
        throw error(
          'Network connection issue. Please check your internet and tap Retry.',
        );
      }
      if (recovery == SessionRecoveryState.unrecoverable) {
        throw error('Your session has expired. Please sign in again.');
      }
      session = client.auth.currentSession;
    }
    if (session == null || session.isExpired) {
      throw error('Your session has expired. Please sign in again.');
    }
    Map<String, dynamic>? row;
    try {
      row = await client
          .from('users')
          .select('id, role, status, company_id')
          .eq('id', session.user.id)
          .maybeSingle();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST301' ||
          (e.message.toLowerCase().contains('jwt') &&
              e.message.toLowerCase().contains('expired'))) {
        final retryRecovery = await AuthRepository(
          supabase: client,
          storage: _storage,
        ).recoverSession(force: true);
        if (retryRecovery == SessionRecoveryState.recovered) {
          final freshSession = client.auth.currentSession;
          if (freshSession != null) {
            try {
              row = await client
                  .from('users')
                  .select('id, role, status, company_id')
                  .eq('id', freshSession.user.id)
                  .maybeSingle();
            } catch (_) {
              throw error(generic);
            }
          }
        } else {
          throw error('Your session has expired. Please sign in again.');
        }
      } else {
        debugPrint('Seller identity lookup failed: ${_errorCode(e)}');
        throw error(generic);
      }
    } catch (e) {
      debugPrint('Seller identity lookup failed: ${_errorCode(e)}');
      throw error(generic);
    }
    if (row == null) {
      // Attempt idempotent self-provisioning before reporting unprovisioned
      try {
        await client.rpc(
          'provision_individual_seller',
          params: {'target_auth_user_id': session.user.id},
        );
        row = await client
            .from('users')
            .select('id, role, status, company_id')
            .eq('id', session.user.id)
            .maybeSingle();
      } catch (e) {
        debugPrint('Auto-provisioning attempt in repository: $e');
      }
    }
    if (row == null) {
      return null;
    }
    final role = row['role']?.toString().toLowerCase().trim() ??
        session.user.appMetadata['role']?.toString().toLowerCase().trim();
    final isInactive = row['status'] == false || row['status'] == 'false';
    if (role != null && role != 'seller') {
      throw error(
        'Your account does not have active seller permissions.',
      );
    }
    if (isInactive) {
      throw error(
        'Your account has been deactivated. Please contact support.',
      );
    }
    final compId = row['company_id']?.toString().trim();
    if (compId != null && compId.isNotEmpty) {
      return SellerOwnership.company(compId);
    } else {
      return SellerOwnership.individual(session.user.id);
    }
  }


  /// Update assigned broker for an active lot with seller company scoping and validation (UX-04)
  /// Returns the broker id the server confirms it stored. Throws
  /// [BrokerUpdateException] when nothing was saved, so callers never show a
  /// broker change that is not persisted.
  Future<String?> updateCommodityBroker(
    String commodityId, {
    required String? brokerId,
    required String? brokerName,
    String? brokerPhone,
    String? brokerLocation,
  }) async {
    // An unregistered broker id is an error, never silently cleared to null.
    if (brokerId != null && !CreateCommodityDto.isValidUuid(brokerId)) {
      throw const BrokerUpdateException(
        'This broker is not registered on the platform, so they cannot be assigned.',
      );
    }
    final client = _supabase;
    final String companyId;
    String? confirmed = brokerId;

    if (client != null) {
      if (!CreateCommodityDto.isValidUuid(commodityId)) {
        throw const BrokerUpdateException(
          'This lot is not saved on the server, so its broker cannot be changed.',
        );
      }
      const generic =
          'Could not change the broker. Check your connection and try again.';
      final ownership = await _resolveSellerOwnership(
        client,
        (m) => BrokerUpdateException(m),
        generic,
      );
      List<dynamic> rows;
      try {
        var query = client
            .from('availabilities')
            .update({'broker_id': brokerId})
            .eq('id', commodityId);

        if (ownership.isCompany) {
          query = query.eq('company_id', ownership.companyId!);
        } else {
          query = query
              .isFilter('company_id', null)
              .eq('seller_user_id', ownership.userId!);
        }

        rows = await query.select('id, broker_id');
      } on PostgrestException catch (e) {
        debugPrint('Broker update rejected: code=${e.code}');
        throw BrokerUpdateException(
          (e.code == '23503' || e.code == '42501')
              ? 'This broker is not registered on the platform, so they cannot be assigned.'
              : generic,
        );
      } catch (e) {
        debugPrint('Broker update failed: ${_errorCode(e)}');
        throw const BrokerUpdateException(generic);
      }
      if (rows.isEmpty) {
        throw const BrokerUpdateException(
          'The broker was not changed: this lot was not found for your account.',
        );
      }
      confirmed = (rows.first as Map<String, dynamic>)['broker_id']?.toString();

      // Mirror the confirmed assignment into the session cache.
      final sessionList = _sessionCommoditiesByCompany[ownership.cacheKey];
      final idx = sessionList?.indexWhere((c) => c.id == commodityId) ?? -1;
      if (idx != -1) {
        sessionList![idx] = sessionList[idx].copyWith(
          brokerId: confirmed,
          brokerName: brokerName,
          brokerPhone: brokerPhone,
          brokerLocation: brokerLocation,
        );
      }
    } else {
      companyId = await _offlineCompanyId();
      // Offline/test mode: only lots held in this session's cache can change.
      final known = _sessionCommoditiesByCompany[companyId]?.any(
        (c) => c.id == commodityId,
      );
      if (known != true) {
        throw const BrokerUpdateException(
          'This lot is not saved, so its broker cannot be changed.',
        );
      }
      final sessionList = _sessionCommoditiesByCompany[companyId];
      final idx = sessionList?.indexWhere((c) => c.id == commodityId) ?? -1;
      if (idx != -1) {
        sessionList![idx] = sessionList[idx].copyWith(
          brokerId: confirmed,
          brokerName: brokerName,
          brokerPhone: brokerPhone,
          brokerLocation: brokerLocation,
        );
      }
    }

    commoditiesUpdatedNotifier.value++;
    return confirmed;
  }

  static final List<SellerCommodity> _baselineCommodities = [
    SellerCommodity(
      id: 'AVL-2026-001',
      lotNumber: 'LOT-CHANA-01',
      commodityName: 'Desi Chana (Gram)',
      gradeName: 'Bold Size FAQ (Count 60-65)',
      totalQuantity: 100.0,
      availableQuantity: 75.0,
      reservedQuantity: 25.0,
      soldQuantity: 0.0,
      unit: 'MT',
      askingPrice: 5850.0,
      confidentialMinimumPrice: 5750.0,
      stateName: 'Rajasthan',
      districtName: 'Bikaner Mandi Hub',
      loadingStatus: 'Ready to Load',
      status: 'Active',
      availableFrom: DateTime.now().subtract(const Duration(days: 2)),
      validUntil: DateTime.now().add(const Duration(days: 8)),
      brokerName: 'Bikaner Mandi Broker Desk',
      brokerId: 'b354958e-779a-41f2-b7a3-5899eca32e32',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    SellerCommodity(
      id: 'AVL-2026-002',
      lotNumber: 'LOT-SOY-04',
      commodityName: 'Yellow Soybean',
      gradeName: 'Grade A FAQ (Moisture < 10%)',
      totalQuantity: 60.0,
      availableQuantity: 60.0,
      reservedQuantity: 0.0,
      soldQuantity: 0.0,
      unit: 'MT',
      askingPrice: 4950.0,
      confidentialMinimumPrice: 4850.0,
      stateName: 'Madhya Pradesh',
      districtName: 'Indore Mandi Complex',
      loadingStatus: 'Scheduled',
      status: 'Open',
      availableFrom: DateTime.now(),
      validUntil: DateTime.now().add(const Duration(days: 5)),
      brokerName: 'Indore Mandi Associates',
      brokerId: 'b354958e-779a-41f2-b7a3-5899eca32e33',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    SellerCommodity(
      id: 'AVL-2026-003',
      lotNumber: 'LOT-MUST-02',
      commodityName: 'Mustard Seeds',
      gradeName: 'High Oil Content (42% Oil)',
      totalQuantity: 40.0,
      availableQuantity: 0.0,
      reservedQuantity: 0.0,
      soldQuantity: 40.0,
      unit: 'MT',
      askingPrice: 5600.0,
      stateName: 'Rajasthan',
      districtName: 'Kota Agro Mandi',
      loadingStatus: 'Ready to Load',
      status: 'Fulfilled',
      availableFrom: DateTime.now().subtract(const Duration(days: 14)),
      validUntil: DateTime.now().subtract(const Duration(days: 2)),
      brokerName: 'Kota Agro Brokerage',
      brokerId: 'b354958e-779a-41f2-b7a3-5899eca32e34',
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
    ),
  ];
}
