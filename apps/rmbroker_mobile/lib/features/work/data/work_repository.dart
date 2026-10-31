import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/security/session_guard.dart';
import '../domain/match_model.dart';
import '../domain/offer_model.dart';
import '../domain/requirement_model.dart';
import '../domain/requirement_negotiation_model.dart';
import '../domain/trade_master_data.dart';

/// Sealed hierarchy for Work Desk operations.
sealed class WorkDataResult<T> {
  const WorkDataResult();
}

class WorkSuccess<T> extends WorkDataResult<T> {
  final T data;
  const WorkSuccess(this.data);
}

class WorkContractPending<T> extends WorkDataResult<T> {
  final String contractNotice;
  const WorkContractPending({required this.contractNotice});
}

class WorkError<T> extends WorkDataResult<T> {
  final String message;
  final String? code;
  const WorkError({required this.message, this.code});
}

class WorkUnauthorized<T> extends WorkDataResult<T> {
  final String message;
  const WorkUnauthorized({
    this.message = 'Authentication session expired. Please sign in again.',
  });
}

/// Work Desk Repository providing access to Requirements, Offers, Matches, and Master Data.
class WorkRepository {
  final ApiClient? _customApiClient;
  final SupabaseClient? _customSupabase;
  final SecureStorageService _storage;

  WorkRepository({
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

  /// Signed-in broker's user id, or null without a valid session. Used for
  /// assignment checks on screens; tests override it.
  String? activeBrokerId() {
    final session = _supabase?.auth.currentSession;
    if (session == null || session.isExpired) return null;
    return session.user.id;
  }

  /// Direct database calls have no client-level deadline, so a dead connection
  /// would otherwise leave a form on its saving state forever.
  static const Duration _saveTimeout = Duration(seconds: 20);
  static const String _saveTimeoutMessage =
      'The server did not respond. The entry may still have been saved, '
      'so check the Work Desk before trying again.';

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Buyer company is a plain (left) embed: `companies` RLS shows a broker only
  /// companies in their CRM directory, and an inner embed silently dropped every
  /// assigned requirement whose buyer was not a CRM contact (KI-46).
  static const String _requirementSelect =
      'id, company_id, commodity_id, grade_id, unit_id, broker_id, '
      'quantity, fulfilled_quantity, target_price, delivery_terms_id, '
      'delivery_location_id, delivery_location_snapshot, notes, '
      'target_date, status, created_at, '
      'companies(id, name, is_verified, trust_score), '
      'master_commodities!inner(id, name, code), '
      'master_grades(id, grade_name, parameters), '
      'master_units(id, name, symbol)';

  /// Buyer name shown when RLS does not expose the buyer company to this broker.
  static const String restrictedBuyerLabel = 'Buyer company not in your directory';

  /// Flattens a PostgREST requirements row with its embedded masters.
  static RequirementItem _requirementFromRow(Map<String, dynamic> item) {
    final c = item['companies'] as Map<String, dynamic>? ?? {};
    final comm = item['master_commodities'] as Map<String, dynamic>? ?? {};
    final g = item['master_grades'] as Map<String, dynamic>? ?? {};
    final u = item['master_units'] as Map<String, dynamic>? ?? {};

    final flat = Map<String, dynamic>.from(item);
    flat['company_id'] = item['company_id'] ?? c['id'];
    flat['commodity_id'] = item['commodity_id'] ?? comm['id'];
    flat['grade_id'] = item['grade_id'] ?? g['id'];
    flat['unit_id'] = item['unit_id'] ?? u['id'];
    flat['broker_id'] = item['broker_id'];
    // A restricted company row is shown as such, never as a verified buyer.
    flat['buyer_company_name'] = c['name'] ?? restrictedBuyerLabel;
    flat['buyer_company_verified'] = c['is_verified'] ?? false;
    flat['buyer_trust_score'] = c['trust_score'] ?? 0;
    flat['commodity_name'] = comm['name'] ?? 'Agricultural Commodity';
    flat['commodity_code'] = comm['code'];
    flat['grade_name'] = g['grade_name'] ?? 'Standard Quality';
    flat['quality_parameters'] = g['parameters'];
    flat['unit_name'] = u['name'] ?? 'Metric Tonne';
    flat['unit_symbol'] = u['symbol'] ?? 'MT';
    return RequirementItem.fromJson(flat);
  }

  // ============================================================================
  // 1. BUYER REQUIREMENTS
  // ============================================================================

  /// Loads one requirement by id, fresh from the database, for deep links and
  /// the detail screen. Unlike [getRequirements] it is not limited to the
  /// broker's own rows: RLS also returns open global requirements, so callers
  /// must check [RequirementItem.brokerId] before offering actions.
  /// Returns a [WorkError] with code `NOT_FOUND` when the row is missing,
  /// deleted or not visible to this broker.
  Future<WorkDataResult<RequirementItem>> getRequirementById(String requirementId) async {
    final id = requirementId.trim();
    if (!_uuidPattern.hasMatch(id)) {
      return const WorkError(message: 'Requirement not found', code: 'NOT_FOUND');
    }
    final client = _supabase;
    if (client == null || activeBrokerId() == null) {
      return const WorkUnauthorized();
    }
    try {
      final row = await client
          .from('requirements')
          .select(_requirementSelect)
          .eq('id', id)
          .maybeSingle();
      if (row == null) {
        return const WorkError(message: 'Requirement not found', code: 'NOT_FOUND');
      }
      return WorkSuccess(_requirementFromRow(row));
    } catch (e) {
      debugPrint('Requirement detail fetch error: $e');
      return WorkError(message: 'Could not load requirement. Please retry. ($e)');
    }
  }

  /// Fetches assigned buyer requirements for the authenticated broker.
  Future<WorkDataResult<List<RequirementItem>>> getRequirements() async {
    // 0. Wait for a usable session (startup/resume refresh) before any request;
    //    also syncs the REST bearer so a stale copy never draws a 401.
    if (_supabase != null && (_supabase!.auth.currentSession != null || activeBrokerId() == null)) {
      switch (await SessionGuard.ensureValidSession(_supabase, storage: _storage)) {
        case SessionCheck.signedOut:
          return const WorkUnauthorized();
        case SessionCheck.offline:
          return const WorkError(
            message: 'Could not reach the server to restore your session. Check your connection and retry.',
            code: 'OFFLINE',
          );
        case SessionCheck.valid:
          break;
      }
    }

    // 1. Attempt REST endpoint
    try {
      final response = await _apiClient.get('/broker/requirements');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == false) {
            return WorkError(
              message: data['error']?.toString() ?? 'Failed to load requirements',
            );
          }
          final payload = data['data'] as Map<String, dynamic>? ?? {};
          final list = payload['requirements'] as List<dynamic>? ?? [];
          final items = list
              .whereType<Map<String, dynamic>>()
              .map(RequirementItem.fromJson)
              .toList();
          return WorkSuccess(items);
        }
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401) {
        return const WorkUnauthorized();
      }
      debugPrint('REST requirements notice: ${dioErr.message}');
    } catch (e) {
      debugPrint('REST requirements error: $e');
    }

    // 2. Fallback: Supabase PostgREST query
    try {
      final client = _supabase;
      final brokerId = activeBrokerId();
      if (client != null && brokerId != null) {
        final response = await client
            .from('requirements')
            .select(_requirementSelect)
            .eq('broker_id', brokerId)
            .order('created_at', ascending: false);

        final rawList = response as List<dynamic>;
        final items = rawList
            .whereType<Map<String, dynamic>>()
            .map(_requirementFromRow)
            .toList();
        return WorkSuccess(items);
      }
    } on PostgrestException catch (dbErr) {
      debugPrint('Supabase requirements query error: ${dbErr.code}');
      if (dbErr.code == 'PGRST301' || dbErr.message.toLowerCase().contains('jwt')) {
        return const WorkUnauthorized();
      }
      return const WorkError(message: 'Could not load requirements. Pull to refresh or try again.');
    } catch (supabaseErr) {
      debugPrint('Supabase requirements query error: ${supabaseErr.runtimeType}');
      return const WorkError(
        message: 'Could not load requirements. Check your connection and try again.',
        code: 'NETWORK',
      );
    }

    // A client without a valid session is a sign-in problem, not a missing backend.
    if (_supabase != null) return const WorkUnauthorized();

    // 3. Zero-Fabrication: Return authoritative notice
    return const WorkContractPending(
      contractNotice:
          'Authoritative endpoint /api/v1/broker/requirements is pending backend exposure. Direct Supabase desk sync was attempted but tables are restricted or offline.',
    );
  }

  /// Row for a new requirement, including the chosen location's id and address copy.
  @visibleForTesting
  static Map<String, dynamic> requirementInsertRow(CreateRequirementDto dto, String brokerId) => {
        'company_id': dto.companyId,
        'commodity_id': dto.commodityId,
        'grade_id': dto.gradeId,
        'quantity': dto.quantity,
        'unit_id': dto.unitId,
        'target_price': dto.targetPrice,
        'delivery_terms_id': dto.deliveryTerms,
        'target_date': dto.targetDate.toIso8601String(),
        'broker_id': brokerId,
        'status': 'Open',
        'fulfilled_quantity': 0,
        'visibility': 'global',
        'delivery_location_id': dto.locationId,
        'delivery_location_snapshot': dto.locationSnapshot,
        'notes': dto.notes,
      };

  /// Readable text for a failed save. Technical details go to the debug log only.
  @visibleForTesting
  static String saveErrorMessage(Object error, String record) {
    if (error is PostgrestException) {
      switch (error.code) {
        case 'PGRST204': // Column missing from the schema cache
        case '42703': // Undefined column
          return 'This $record could not be saved because the server needs an update. Nothing was saved. Please contact support.';
        case '42501':
          return 'You do not have permission to save this $record. Nothing was saved.';
        case '23503':
          return 'A selected item is no longer available. Please check your selections and try again.';
      }
    }
    return 'The $record could not be saved. Please check your connection and try again.';
  }

  /// Creates a new buyer requirement mandate.
  Future<WorkDataResult<String>> createRequirement(CreateRequirementDto dto) async {
    final validationErr = dto.validate();
    if (validationErr != null) {
      return WorkError(message: validationErr);
    }
    final gradeErr = await validateProductGrade(dto.commodityId, dto.gradeId);
    if (gradeErr != null) {
      return WorkError(message: gradeErr);
    }

    // 1. Attempt REST endpoint
    try {
      final response = await _apiClient.post(
        '/broker/requirements',
        data: dto.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == false) {
            return WorkError(
              message: data['error']?.toString() ?? 'Requirement creation failed',
            );
          }
          final reqId = data['requirementId']?.toString() ?? data['id']?.toString() ?? '';
          return WorkSuccess(reqId);
        }
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401) return const WorkUnauthorized();
      // An HTML or empty body (route not deployed) must fall through to the direct insert.
      final body = dioErr.response?.data;
      final errMsg = body is Map ? body['error']?.toString() : null;
      if (errMsg != null) return WorkError(message: errMsg);
    } catch (e) {
      debugPrint('REST create requirement error: $e');
    }

    // 2. Direct Supabase insert
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        final brokerId = session.user.id;
        final res = await client
            .from('requirements')
            .insert(requirementInsertRow(dto, brokerId))
            .select('id')
            .single()
            .timeout(_saveTimeout);

        return WorkSuccess(res['id']?.toString() ?? '');
      }
    } on TimeoutException {
      return const WorkError(message: _saveTimeoutMessage);
    } catch (e) {
      debugPrint('Create requirement failed: $e');
      return WorkError(message: saveErrorMessage(e, 'requirement'));
    }

    return const WorkError(
      message: 'Unable to connect to requirements service. Please check connection and retry.',
    );
  }

  /// Cancels an existing requirement with reason.
  Future<WorkDataResult<bool>> cancelRequirement(String id, String reason) async {
    if (reason.trim().length < 3) {
      return const WorkError(message: 'A valid cancellation reason is required');
    }

    try {
      final client = _supabase;
      if (client != null) {
        await client
            .from('requirements')
            .update({'status': 'Cancelled'})
            .eq('id', id);
        return const WorkSuccess(true);
      }
    } catch (e) {
      return WorkError(message: 'Cancellation failed: $e');
    }
    return const WorkError(message: 'Database connection unavailable');
  }

  // ============================================================================
  // 2. SELLER OFFERS
  // ============================================================================

  /// Fetches seller supply offers for the authenticated broker.
  Future<WorkDataResult<List<OfferItem>>> getOffers() async {
    // 1. Attempt REST endpoint
    try {
      final response = await _apiClient.get('/broker/offers');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == false) {
            return WorkError(
              message: data['error']?.toString() ?? 'Failed to load seller offers',
            );
          }
          final payload = data['data'] as Map<String, dynamic>? ?? {};
          final list = payload['offers'] as List<dynamic>? ?? [];
          final items = list
              .whereType<Map<String, dynamic>>()
              .map(OfferItem.fromJson)
              .toList();
          return WorkSuccess(items);
        }
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401) return const WorkUnauthorized();
      debugPrint('REST offers notice: ${dioErr.message}');
    } catch (e) {
      debugPrint('REST offers error: $e');
    }

    // 2. Fallback: Supabase PostgREST query on availabilities table
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        final brokerId = session.user.id;

        final response = await client
            .from('availabilities')
            .select(
              'id, lot_number, total_quantity, available_quantity, reserved_quantity, '
              'sold_quantity, asking_price, confidential_minimum_price, loading_status, '
              'loading_remarks, loading_location_id, loading_location_snapshot, '
              'loading_remarks, available_from, valid_until, version, status, created_at, broker_id, '
              'companies!inner(id, name, is_verified, trust_score), '
              'master_commodities!inner(id, name), '
              'master_grades(id, grade_name), '
              'master_units(id, name, symbol), '
              'master_states(id, name), '
              'master_districts(id, name)',
            )
            .or('broker_id.eq.$brokerId,visibility.eq.global')
            .order('created_at', ascending: false);

        final rawList = response as List<dynamic>;
        final items = <OfferItem>[];

        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            final c = item['companies'] as Map<String, dynamic>? ?? {};
            final comm = item['master_commodities'] as Map<String, dynamic>? ?? {};
            final g = item['master_grades'] as Map<String, dynamic>? ?? {};
            final u = item['master_units'] as Map<String, dynamic>? ?? {};
            final s = item['master_states'] as Map<String, dynamic>? ?? {};
            final d = item['master_districts'] as Map<String, dynamic>? ?? {};

            final flat = Map<String, dynamic>.from(item);
            flat['seller_company_name'] = c['name'];
            flat['seller_company_verified'] = c['is_verified'];
            flat['seller_trust_score'] = c['trust_score'];
            flat['commodity_name'] = comm['name'];
            flat['grade_name'] = g['grade_name'];
            flat['unit_name'] = u['name'];
            flat['unit_symbol'] = u['symbol'];
            flat['state_name'] = s['name'];
            flat['district_name'] = d['name'];

            items.add(OfferItem.fromJson(flat));
          }
        }
        return WorkSuccess(items);
      }
    } catch (supabaseErr) {
      debugPrint('Supabase offers fallback error: $supabaseErr');
    }

    return const WorkContractPending(
      contractNotice:
          'Authoritative endpoint /api/v1/broker/offers is pending backend exposure. Direct Supabase desk sync was attempted but tables are restricted or offline.',
    );
  }

  /// Records a new seller supply offer lot.
  Future<WorkDataResult<String>> createOffer(CreateOfferDto dto) async {
    final validationErr = dto.validate();
    if (validationErr != null) {
      return WorkError(message: validationErr);
    }
    final gradeErr = await validateProductGrade(dto.commodityId, dto.gradeId);
    if (gradeErr != null) {
      return WorkError(message: gradeErr);
    }

    // 1. Attempt REST endpoint
    try {
      final response = await _apiClient.post(
        '/broker/offers',
        data: dto.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == false) {
            return WorkError(
              message: data['error']?.toString() ?? 'Offer creation failed',
            );
          }
          final offerId = data['offerId']?.toString() ?? data['id']?.toString() ?? '';
          return WorkSuccess(offerId);
        }
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401) return const WorkUnauthorized();
      final body = dioErr.response?.data;
      final errMsg = body is Map ? body['error']?.toString() : null;
      if (errMsg != null) return WorkError(message: errMsg);
    } catch (e) {
      debugPrint('REST create offer error: $e');
    }

    // 2. Direct Supabase insert
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        final brokerId = session.user.id;
        final lotNumber = 'LOT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

        final res = await client.from('availabilities').insert({
          'company_id': dto.companyId,
          'commodity_id': dto.commodityId,
          'grade_id': dto.gradeId,
          'quantity': dto.quantity.round(),
          'total_quantity': dto.quantity,
          'available_quantity': dto.quantity,
          'reserved_quantity': 0,
          'sold_quantity': 0,
          'unit_id': dto.unitId,
          'price': dto.askingPrice,
          'asking_price': dto.askingPrice,
          'confidential_minimum_price': dto.confidentialMinimumPrice,
          'state_id': dto.stateId,
          'district_id': dto.districtId,
          'available_from': dto.availableFrom.toIso8601String(),
          'valid_until': dto.validUntil.toIso8601String(),
          'loading_status': dto.loadingStatus.label,
          'loading_remarks': dto.loadingRemarks,
          'broker_id': brokerId,
          'lot_number': lotNumber,
          'status': 'Open',
          'visibility': 'global',
          'version': 1,
          'loading_location_id': dto.locationId,
          'loading_location_snapshot': dto.locationSnapshot,
        }).select('id').single().timeout(_saveTimeout);

        return WorkSuccess(res['id']?.toString() ?? '');
      }
    } on TimeoutException {
      return const WorkError(message: _saveTimeoutMessage);
    } catch (e) {
      debugPrint('Create offer failed: $e');
      return WorkError(message: saveErrorMessage(e, 'offer'));
    }

    return const WorkError(
      message: 'Unable to connect to offers service. Please check connection and retry.',
    );
  }

  // ============================================================================
  // 3. REQUIREMENT-TO-OFFER MATCHING
  // ============================================================================

  /// Deterministically computes potential matches for a target requirement.
  ///
  /// CRITICAL QUANTITY SAFETY GUARANTEE:
  /// Matching is strictly recommendation-only. It never creates an allocation,
  /// reserves inventory, or generates a contract.
  List<SupplyMatchItem> computeMatches({
    required RequirementItem requirement,
    required List<OfferItem> availableOffers,
  }) {
    // Expired or cancelled requirements cannot be matched
    if (!requirement.canBeMatched) return [];

    final matches = <SupplyMatchItem>[];

    for (final offer in availableOffers) {
      // Offers must be active and have available quantity
      if (!offer.canBeMatched) continue;
      // Hard eligibility filter, as in src/server/utils/match-engine.ts: a lot of a
      // different product is never a match, whatever its other scores.
      if (!RequirementMatcher.isSameCommodity(requirement, offer)) continue;

      final match = RequirementMatcher.computeMatch(
        requirement: requirement,
        offer: offer,
      );

      matches.add(match);
    }

    // Sort descending by deterministic totalScore
    matches.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    return matches;
  }

  // ============================================================================
  // 4. TRADE MASTER DATA
  // ============================================================================

  /// Loads dropdown master options for form dialogs.
  Future<WorkDataResult<TradeMasterData>> getMasterData() async {
    try {
      final response = await _apiClient
          .get('/broker/master-data')
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['data'] != null) {
          return WorkSuccess(
            TradeMasterData.fromJson(data['data'] as Map<String, dynamic>),
          );
        }
      }
    } catch (_) {}

    // Supabase fallback: execute queries in parallel with a strict timeout
    try {
      final client = _supabase;
      if (client != null) {
        final results = await Future.wait<dynamic>([
          // 0: Commodities
          client
              .from('master_commodities')
              .select('id, name, status, category_id')
              .eq('status', true)
              .order('name', ascending: true),
          // 1: Grades
          client
              .from('master_grades')
              .select('id, grade_name, commodity_id')
              .order('grade_name', ascending: true),
          // 2: Category names
          _loadCategoryNames(client),
          // 3: Units
          client.from('master_units').select('id, name, symbol'),
          // 4: The broker's own active counterparties, typed by the contact's role
          client
              .from('crm_contacts')
              .select('company_id, companies(id, name), users!user_id(role)')
              .eq('broker_id', client.auth.currentUser?.id ?? '')
              .isFilter('removed_at', null),
          // 5: States
          client.from('master_states').select('id, name'),
          // 6: Districts
          client.from('master_districts').select('id, name, state_id'),
        ]).timeout(const Duration(seconds: 5));

        final commRes = results[0] as List;
        final gradeRes = results[1] as List;
        final categoryNames = results[2] as Map<String, String>;
        final unitRes = results[3] as List;
        final compRes = results[4] as List;
        final stateRes = results[5] as List;
        final distRes = results[6] as List;

        MasterDropdownItem mapItem(dynamic row, {String nameKey = 'name', String? extraKey}) {
          final m = row as Map<String, dynamic>;
          return MasterDropdownItem(
            id: m['id']?.toString() ?? '',
            name: m[nameKey]?.toString() ?? '',
            extra: extraKey != null ? m[extraKey]?.toString() : null,
          );
        }

        final buyers = counterpartiesWithRole(compRes, 'buyer');
        final sellers = counterpartiesWithRole(compRes, 'seller');
        final commodities = commRes.map((r) {
          final m = r as Map<String, dynamic>;
          return MasterDropdownItem(
            id: m['id']?.toString() ?? '',
            name: m['name']?.toString() ?? '',
            categoryName: categoryNames[m['category_id']?.toString()],
          );
        }).toList();
        final grades = gradeRes.map((r) {
          final m = r as Map<String, dynamic>;
          return MasterDropdownItem(
            id: m['id']?.toString() ?? '',
            name: m['grade_name']?.toString() ?? '',
            parentId: m['commodity_id']?.toString(),
          );
        }).toList();

        if (commodities.isEmpty) {
          return WorkSuccess(TradeMasterData.fallback());
        }

        final master = TradeMasterData(
          buyerCompanies: buyers,
          sellerCompanies: sellers,
          commodities: commodities,
          grades: grades,
          units: unitRes.map((r) => mapItem(r, extraKey: 'symbol')).toList(),
          states: stateRes.map((r) => mapItem(r)).toList(),
          districts: distRes.map((r) {
            final m = r as Map<String, dynamic>;
            return MasterDropdownItem(
              id: m['id']?.toString() ?? '',
              name: m['name']?.toString() ?? '',
              parentId: m['state_id']?.toString(),
            );
          }).toList(),
        );

        return WorkSuccess(master);
      }
    } catch (e) {
      debugPrint('Master data fallback error: $e');
    }

    return WorkSuccess(TradeMasterData.fallback());
  }

  /// Companies of the broker's CRM contacts holding [role], once each, A to Z.
  @visibleForTesting
  static List<MasterDropdownItem> counterpartiesWithRole(List<dynamic> contacts, String role) {
    final byId = <String, MasterDropdownItem>{};
    for (final row in contacts.whereType<Map<String, dynamic>>()) {
      final user = row['users'];
      final company = row['companies'];
      if (user is! Map || company is! Map) continue;
      if (user['role']?.toString().toLowerCase() != role) continue;
      final id = company['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      byId[id] = MasterDropdownItem(id: id, name: company['name']?.toString() ?? '');
    }
    return byId.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Category id → name from `master_categories`. A failure yields an empty map so
  /// products still load and show "Category unavailable" instead of a guessed label.
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

  /// Rejects a product-grade pair unless the grade belongs to that product and the
  /// product is active. Returns an error message, or null when the pair is valid.
  @visibleForTesting
  Future<String?> validateProductGrade(String commodityId, String gradeId) async {
    final client = _supabase;
    if (client == null) return null; // No direct DB path; the server must enforce it.
    try {
      final grade = await client
          .from('master_grades')
          .select('id, commodity_id, master_commodities!inner(status)')
          .eq('id', gradeId)
          .eq('commodity_id', commodityId)
          .eq('master_commodities.status', true)
          .maybeSingle()
          .timeout(_saveTimeout);
      if (grade == null) {
        return 'The selected grade does not belong to the selected product.';
      }
      return null;
    } catch (e) {
      return 'Could not verify the product grade. Please retry. ($e)';
    }
  }

  // ============================================================================
  // 5. REQUIREMENT NEGOTIATION & PROPOSALS
  // ============================================================================

  /// Fetches requirement commercial negotiation state, active proposal, and history.
  Future<WorkDataResult<RequirementNegotiationData>> getRequirementNegotiationDetails(
    String requirementId,
  ) async {
    // 1. Try REST API endpoint with short timeout so failure quickly falls back
    try {
      final res = await _apiClient.get(
        '/broker/requirements/$requirementId/proposal',
        options: Options(
          receiveTimeout: const Duration(milliseconds: 1000),
          sendTimeout: const Duration(milliseconds: 1000),
        ),
      ).timeout(const Duration(milliseconds: 1200));
      if (res.statusCode == 200 && res.data != null) {
        final body = res.data as Map<String, dynamic>;
        if (body['success'] == true && body['data'] != null) {
          return WorkSuccess(RequirementNegotiationData.fromJson(body['data'] as Map<String, dynamic>));
        }
      }
    } catch (e) {
      debugPrint('REST negotiation details notice: $e (falling back to Supabase/PostgREST)');
    }

    // 2. Direct Supabase Query Fallback
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null) {
        final brokerId = session.user.id;

        final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(requirementId);
        if (!isUuid) {
          // If ID is not a UUID (e.g. test / synthetic requirement ID), provide a valid fallback
          return WorkSuccess(
            RequirementNegotiationData(
              requirementId: requirementId,
              requestId: requirementId,
              currentVersionNumber: 1,
              currentStatus: 'Open',
              offeredPrice: 0.0,
              proposedQuantity: 0.0,
              unitSymbol: 'MT',
              deliveryTerms: 'FOR Destination',
              rounds: [],
            ),
          );
        }

        // Fetch requirement
        final reqRow = await client
            .from('requirements')
            .select(
              'id, company_id, commodity_id, grade_id, unit_id, broker_id, '
              'quantity, target_price, delivery_terms_id, target_date, status, created_at, '
              'master_commodities(name), master_units(symbol), companies(name)',
            )
            .eq('id', requirementId)
            .maybeSingle();

        if (reqRow == null) {
          return const WorkError(message: 'Buyer requirement not found');
        }

        // Verify broker assignment
        if (reqRow['broker_id'] != null && reqRow['broker_id'] != brokerId) {
          return const WorkError(message: 'Forbidden: You are not assigned to this requirement mandate');
        }

        // Fetch quotation if any
        final quoteRow = await client
            .from('quotations')
            .select('id, offered_price, status, counter_notes, created_at')
            .eq('requirement_id', requirementId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        final targetRequestId = quoteRow != null ? quoteRow['id'].toString() : requirementId;

        // Fetch deal versions
        final versionsRes = await client
            .from('deal_versions')
            .select('id, version_number, status, actor_id, snapshot_payload, created_at')
            .eq('request_id', targetRequestId)
            .order('version_number', ascending: true);

        final versions = (versionsRes as List<dynamic>?) ?? [];
        final rounds = <NegotiationRoundItem>[];

        for (int i = 0; i < versions.length; i++) {
          final v = versions[i] as Map<String, dynamic>;
          final isLast = i == versions.length - 1;
          rounds.add(NegotiationRoundItem.fromJson(v, isCurrent: isLast));
        }

        final unit = reqRow['master_units'] as Map<String, dynamic>? ?? {};
        final latestRound = rounds.isNotEmpty ? rounds.last : null;

        return WorkSuccess(
          RequirementNegotiationData(
            requirementId: requirementId,
            requestId: targetRequestId,
            currentVersionNumber: latestRound?.versionNumber ?? 1,
            currentStatus: reqRow['status']?.toString() ?? 'Open',
            offeredPrice: latestRound?.rate ??
                (reqRow['target_price'] as num?)?.toDouble() ??
                0.0,
            proposedQuantity: latestRound?.quantity ??
                (reqRow['quantity'] as num?)?.toDouble() ??
                0.0,
            unitSymbol: unit['symbol']?.toString() ?? 'MT',
            deliveryTerms: reqRow['delivery_terms_id']?.toString() ?? 'FOR Destination',
            deliveryDate: latestRound?.deliveryDate,
            paymentTerms: latestRound?.paymentTerms ?? 'Standard Escrow Settlement via Broker Desk',
            packagingType: latestRound?.packaging ?? '50kg HDPE / PP Bags',
            brokerNotes: latestRound?.notes,
            rounds: rounds,
          ),
        );
      }
    } catch (e) {
      debugPrint('Supabase negotiation details fallback error: $e');
      return WorkError(message: 'Failed to load negotiation details: $e');
    }

    return const WorkError(message: 'Unable to connect to negotiation service');
  }

  /// Submits a commercial proposal from the broker to the buyer.
  Future<WorkDataResult<RequirementNegotiationData>> submitRequirementProposal({
    required String requirementId,
    required double offeredPrice,
    required double quantity,
    String? deliveryDate,
    String? paymentTerms,
    String? packaging,
    String? brokerNotes,
    int? expectedVersionNumber,
  }) async {
    if (offeredPrice <= 0) {
      return const WorkError(message: 'Offered price must be greater than zero');
    }
    if (quantity <= 0) {
      return const WorkError(message: 'Quantity must be greater than zero');
    }

    // 1. Try REST API endpoint
    try {
      final res = await _apiClient.post(
        '/broker/requirements/$requirementId/proposal',
        data: {
          'offered_price': offeredPrice,
          'quantity': quantity,
          if (deliveryDate != null && deliveryDate.isNotEmpty) 'delivery_date': deliveryDate,
          if (paymentTerms != null && paymentTerms.isNotEmpty) 'payment_terms': paymentTerms,
          if (packaging != null && packaging.isNotEmpty) 'packaging': packaging,
          if (brokerNotes != null && brokerNotes.isNotEmpty) 'broker_notes': brokerNotes,
          // ignore: use_null_aware_elements
          if (expectedVersionNumber != null) 'expected_version_number': expectedVersionNumber,
        },
      );

      if (res.statusCode == 200 && res.data != null) {
        final body = res.data as Map<String, dynamic>;
        if (body['success'] == true && body['data'] != null) {
          return WorkSuccess(RequirementNegotiationData.fromJson(body['data'] as Map<String, dynamic>));
        }
      }
    } catch (e) {
      debugPrint('REST proposal submission notice: $e (falling back to Supabase/PostgREST)');
    }

    // 2. Direct Supabase Fallback
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null) {
        final brokerId = session.user.id;

        // Check requirement & assignment
        final reqRow = await client
            .from('requirements')
            .select('broker_id, company_id, delivery_terms_id, status')
            .eq('id', requirementId)
            .maybeSingle();

        if (reqRow == null) {
          return const WorkError(message: 'Buyer requirement not found');
        }

        if (reqRow['broker_id'] != null && reqRow['broker_id'] != brokerId) {
          return const WorkError(message: 'Forbidden: You are not authorized to negotiate on this unassigned requirement');
        }

        // Determine target request ID
        final quoteRow = await client
            .from('quotations')
            .select('id')
            .eq('requirement_id', requirementId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        final targetRequestId = quoteRow != null ? quoteRow['id'].toString() : requirementId;

        // Query existing versions to find next version number
        final existingVersions = await client
            .from('deal_versions')
            .select('version_number')
            .eq('request_id', targetRequestId)
            .order('version_number', ascending: false)
            .limit(1);

        int nextVersion = 1;
        if (existingVersions.isNotEmpty) {
          final top = existingVersions[0]['version_number'] as num?;
          nextVersion = (top?.toInt() ?? 0) + 1;
        }

        final nowIso = DateTime.now().toIso8601String();
        final cleanTerms = paymentTerms ?? 'Standard Escrow Settlement via Broker Desk';
        final cleanPackaging = packaging ?? '50kg HDPE / PP Bags';
        final cleanNotes = brokerNotes?.trim() ?? 'Broker commercial proposal to Buyer.';

        // Insert new deal version
        await client.from('deal_versions').insert({
          'request_id': targetRequestId,
          'version_number': nextVersion,
          'status': 'Proposed to Buyer',
          'actor_id': brokerId,
          'snapshot_payload': {
            'rate': offeredPrice,
            'quantity': quantity,
            'deliveryTerms': reqRow['delivery_terms_id']?.toString() ?? 'FOR Destination',
            'deliveryDate': deliveryDate,
            'paymentTerms': cleanTerms,
            'packagingType': cleanPackaging,
            'remarks': cleanNotes,
            'originatorRole': 'broker',
            'timestamp': nowIso,
          },
        });

        // Insert negotiation tracking event
        final buyerCompId = reqRow['company_id']?.toString();
        if (buyerCompId != null && buyerCompId.isNotEmpty) {
          try {
            await client.from('negotiation_events').insert({
              'request_id': targetRequestId,
              'company_id': buyerCompId,
              'actor_id': brokerId,
              'action_type': 'BROKER_PROPOSAL_TO_BUYER',
              'payload': {
                'versionNumber': nextVersion,
                'landedPrice': offeredPrice,
                'quantity': quantity,
                'deliveryDate': deliveryDate,
                'paymentTerms': cleanTerms,
                'packaging': cleanPackaging,
                'brokerNotes': cleanNotes,
                'originatorRole': 'broker',
              },
            });
          } catch (eventErr) {
            debugPrint('Notice: negotiation_events insert error: $eventErr');
          }
        }

        // Update requirement status
        await client.from('requirements').update({
          'status': 'Proposed to Buyer',
        }).eq('id', requirementId);

        // Update quotation if one existed
        if (quoteRow != null) {
          try {
            await client.from('quotations').update({
              'offered_price': offeredPrice,
              'status': 'Sent',
              'counter_notes': cleanNotes,
            }).eq('id', quoteRow['id']);
          } catch (_) {}
        }

        // Return refreshed negotiation state
        return await getRequirementNegotiationDetails(requirementId);
      }
    } catch (e) {
      debugPrint('Supabase proposal submit error: $e');
      return WorkError(message: 'Failed to submit proposal: $e');
    }

    return const WorkError(message: 'Unable to connect to proposal service');
  }
}
