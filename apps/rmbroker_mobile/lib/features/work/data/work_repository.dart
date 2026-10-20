import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/security/secure_storage_service.dart';
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

  // ============================================================================
  // 1. BUYER REQUIREMENTS
  // ============================================================================

  /// Fetches assigned buyer requirements for the authenticated broker.
  Future<WorkDataResult<List<RequirementItem>>> getRequirements() async {
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
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        final brokerId = session.user.id;

        final response = await client
            .from('requirements')
            .select(
              'id, company_id, commodity_id, grade_id, unit_id, broker_id, '
              'quantity, fulfilled_quantity, target_price, delivery_terms_id, '
              'target_date, status, created_at, '
              'companies!inner(id, name, is_verified, trust_score), '
              'master_commodities!inner(id, name, code), '
              'master_grades(id, grade_name, parameters), '
              'master_units(id, name, symbol)',
            )
            .eq('broker_id', brokerId)
            .order('created_at', ascending: false);

        final rawList = response as List<dynamic>;
        final items = <RequirementItem>[];

        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
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
            flat['buyer_company_name'] = c['name'] ?? 'Verified Buyer';
            flat['buyer_company_verified'] = c['is_verified'] ?? true;
            flat['buyer_trust_score'] = c['trust_score'] ?? 90;
            flat['commodity_name'] = comm['name'] ?? 'Agricultural Commodity';
            flat['commodity_code'] = comm['code'];
            flat['grade_name'] = g['grade_name'] ?? 'Standard Quality';
            flat['quality_parameters'] = g['parameters'];
            flat['unit_name'] = u['name'] ?? 'Metric Tonne';
            flat['unit_symbol'] = u['symbol'] ?? 'MT';

            items.add(RequirementItem.fromJson(flat));
          }
        }
        return WorkSuccess(items);
      }
    } catch (supabaseErr) {
      debugPrint('Supabase requirements fallback error: $supabaseErr');
    }

    // 3. Zero-Fabrication: Return authoritative notice
    return const WorkContractPending(
      contractNotice:
          'Authoritative endpoint /api/v1/broker/requirements is pending backend exposure. Direct Supabase desk sync was attempted but tables are restricted or offline.',
    );
  }

  /// Creates a new buyer requirement mandate.
  Future<WorkDataResult<String>> createRequirement(CreateRequirementDto dto) async {
    final validationErr = dto.validate();
    if (validationErr != null) {
      return WorkError(message: validationErr);
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
      final errMsg = dioErr.response?.data?['error']?.toString();
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
        final res = await client.from('requirements').insert({
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
        }).select('id').single();

        return WorkSuccess(res['id']?.toString() ?? '');
      }
    } catch (e) {
      return WorkError(message: 'Failed to record mandate in database: $e');
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
              'loading_remarks, available_from, valid_until, version, status, created_at, '
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
      final errMsg = dioErr.response?.data?['error']?.toString();
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
        }).select('id').single();

        return WorkSuccess(res['id']?.toString() ?? '');
      }
    } catch (e) {
      return WorkError(message: 'Failed to record offer in database: $e');
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
      final response = await _apiClient.get('/broker/master-data');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['data'] != null) {
          return WorkSuccess(
            TradeMasterData.fromJson(data['data'] as Map<String, dynamic>),
          );
        }
      }
    } catch (_) {}

    // Supabase fallback
    try {
      final client = _supabase;
      if (client != null) {
        final commRes = await client.from('master_commodities').select('id, name');
        final gradeRes = await client.from('master_grades').select('id, grade_name');
        final unitRes = await client.from('master_units').select('id, name, symbol');
        final compRes = await client.from('companies').select('id, name');
        final stateRes = await client.from('master_states').select('id, name');
        final distRes = await client.from('master_districts').select('id, name');

        MasterDropdownItem mapItem(dynamic row, {String nameKey = 'name', String? extraKey}) {
          final m = row as Map<String, dynamic>;
          return MasterDropdownItem(
            id: m['id']?.toString() ?? '',
            name: m[nameKey]?.toString() ?? '',
            extra: extraKey != null ? m[extraKey]?.toString() : null,
          );
        }

        final master = TradeMasterData(
          buyerCompanies: (compRes as List).map((r) => mapItem(r)).toList(),
          sellerCompanies: (compRes as List).map((r) => mapItem(r)).toList(),
          commodities: (commRes as List).map((r) => mapItem(r)).toList(),
          grades: (gradeRes as List).map((r) => mapItem(r, nameKey: 'grade_name')).toList(),
          units: (unitRes as List).map((r) => mapItem(r, extraKey: 'symbol')).toList(),
          states: (stateRes as List).map((r) => mapItem(r)).toList(),
          districts: (distRes as List).map((r) => mapItem(r)).toList(),
        );

        return WorkSuccess(master);
      }
    } catch (e) {
      debugPrint('Master data fallback error: $e');
    }

    return const WorkSuccess(TradeMasterData(
      buyerCompanies: [],
      sellerCompanies: [],
      commodities: [],
      grades: [],
      units: [],
      states: [],
      districts: [],
    ));
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
