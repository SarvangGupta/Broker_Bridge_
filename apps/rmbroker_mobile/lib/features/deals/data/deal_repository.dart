import '../../directory/domain/cheque_leaf_data.dart';
import '../domain/deal_share_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../work/domain/offer_model.dart';
import '../../work/domain/requirement_model.dart';
import '../../work/domain/unit_utils.dart';
import '../domain/allocation_model.dart';
import '../domain/deal_model.dart';

/// Sealed hierarchy for Deal & Allocation desk operations.
sealed class DealDataResult<T> {
  const DealDataResult();
}

class DealSuccess<T> extends DealDataResult<T> {
  final T data;
  const DealSuccess(this.data);
}

class DealContractPending<T> extends DealDataResult<T> {
  final String contractNotice;
  const DealContractPending({required this.contractNotice});
}

class DealError<T> extends DealDataResult<T> {
  final String message;
  final String? code;
  const DealError({required this.message, this.code});
}

class DealUnauthorized<T> extends DealDataResult<T> {
  final String message;
  const DealUnauthorized({
    this.message = 'Authentication session expired. Please sign in again.',
  });
}

/// Authoritative Repository for Broker-mediated Allocations and Deals.
class DealRepository {
  final ApiClient? _customApiClient;
  final SupabaseClient? _customSupabase;
  final SecureStorageService _storage;

  DealRepository({
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

  /// Safely extracts the booking reference from PostgREST embedded relation,
  /// handling both 1:1 single object (Map) and 1:N array (List) representations.
  static String? extractBookingReference(dynamic bookingsRaw) {
    if (bookingsRaw == null) return null;
    if (bookingsRaw is Map<String, dynamic>) {
      return bookingsRaw['booking_reference']?.toString();
    }
    if (bookingsRaw is List && bookingsRaw.isNotEmpty) {
      final first = bookingsRaw.first;
      if (first is Map<String, dynamic>) {
        return first['booking_reference']?.toString();
      }
    }
    return null;
  }

  /// Signed-in broker's user id, or null without a valid session.
  @visibleForTesting
  String? activeBrokerId() {
    final session = _supabase?.auth.currentSession;
    if (session == null || session.isExpired) return null;
    return session.user.id;
  }

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  static bool _isUniqueViolation(Object e) => e is PostgrestException && e.code == '23505';

  /// Deal statuses after which no confirmation, amendment or finalization applies.
  static const Set<String> _closedDealStatuses = {
    'finalized',
    'in fulfillment',
    'dispatch pending',
    'in transit',
    'completed',
    'delivered',
    'cancelled',
    'disputed',
  };

  static bool _isClosedDealStatus(String? status) =>
      _closedDealStatuses.contains((status ?? '').trim().toLowerCase());

  /// Moves seller-lot stock between available and reserved with an optimistic
  /// lock on `availabilities.version`. A positive [reserveDelta] reserves stock
  /// and requires `available_quantity >= reserveDelta`; a negative one releases.
  /// Returns false when the lot is missing, short, changed concurrently (after
  /// retries) or not updatable by this broker (RLS returns zero rows).
  Future<bool> _shiftLotReservation(SupabaseClient client, String lotId, double reserveDelta) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final lot = await client
          .from('availabilities')
          .select('id, available_quantity, reserved_quantity, version')
          .eq('id', lotId)
          .maybeSingle();
      if (lot == null) return false;
      final available = _num(lot['available_quantity']);
      final reserved = _num(lot['reserved_quantity']);
      if (reserveDelta > 0 && available + 1e-9 < reserveDelta) return false;
      final version = (lot['version'] as num?)?.toInt() ?? 1;
      final updated = await client
          .from('availabilities')
          .update({
            'available_quantity': available - reserveDelta,
            'reserved_quantity': (reserved + reserveDelta) < 0 ? 0 : reserved + reserveDelta,
            'version': version + 1,
          })
          .eq('id', lotId)
          .eq('version', version)
          .select('id');
      if ((updated as List).isNotEmpty) return true;
    }
    return false;
  }

  /// Adds [delta] to `requirements.fulfilled_quantity` with compare-and-set on the
  /// previous value. A positive delta may not exceed the remaining quantity.
  Future<bool> _shiftRequirementFulfilled(SupabaseClient client, String requirementId, double delta) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final req = await client
          .from('requirements')
          .select('id, quantity, fulfilled_quantity')
          .eq('id', requirementId)
          .maybeSingle();
      if (req == null) return false;
      final quantity = _num(req['quantity']);
      final fulfilled = _num(req['fulfilled_quantity']);
      if (delta > 0 && quantity - fulfilled + 1e-9 < delta) return false;
      final next = fulfilled + delta;
      final updated = await client
          .from('requirements')
          .update({'fulfilled_quantity': next < 0 ? 0 : next})
          .eq('id', requirementId)
          .eq('fulfilled_quantity', req['fulfilled_quantity'] ?? 0)
          .select('id');
      if ((updated as List).isNotEmpty) return true;
    }
    return false;
  }

  // ============================================================================
  // 1. BROKER DEALS LIST & SEARCH
  // ============================================================================

  /// Fetches deals managed by the authenticated broker with optional status filter.
  Future<DealDataResult<List<DealItem>>> getDeals({
    DealStatus? statusFilter,
    String? search,
  }) async {
    // 1. Attempt REST endpoint
    try {
      final queryParams = <String, dynamic>{};
      if (statusFilter != null) queryParams['status'] = statusFilter.code;
      if (search != null && search.trim().isNotEmpty) queryParams['q'] = search.trim();

      final response = await _apiClient.get('/broker/deals', queryParameters: queryParams);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == false) {
            return DealError(message: data['error']?.toString() ?? 'Failed to load deals');
          }
          final payload = data['data'] as Map<String, dynamic>? ?? {};
          final list = payload['deals'] as List<dynamic>? ?? [];
          final items = list.whereType<Map<String, dynamic>>().map(DealItem.fromJson).toList();
          return DealSuccess(await _withRequirementNegotiations(items));
        }
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401) {
        return const DealUnauthorized();
      }
      debugPrint('REST deals notice: ${dioErr.message}');
    } catch (e) {
      debugPrint('REST deals error: $e');
    }

    // 2. Fallback: Supabase PostgREST query on deals
    try {
      final client = _supabase;
      final brokerId = activeBrokerId();
      if (client != null && brokerId != null) {

        var query = client.from('deals').select(
              'id, requirement_id, quotation_id, buyer_id, seller_id, broker_id, '
              'agreed_price, agreed_quantity, status, created_at, closed_at, '
              'requirements(id, commodity_id, grade_id, master_commodities(name), master_grades(grade_name)), '
              'buyer:companies!buyer_id(id, name), '
              'seller:companies!seller_id(id, name), '
              'bookings(booking_reference)',
            );

        query = query.or('broker_id.eq.$brokerId,broker_id.is.null');

        final response = await query.order('created_at', ascending: false);
        final rawList = response as List<dynamic>;
        final items = <DealItem>[];

        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            final req = item['requirements'] as Map<String, dynamic>? ?? {};
            final comm = req['master_commodities'] as Map<String, dynamic>? ?? {};
            final gr = req['master_grades'] as Map<String, dynamic>? ?? {};
            final buyer = item['buyer'] as Map<String, dynamic>? ?? {};
            final seller = item['seller'] as Map<String, dynamic>? ?? {};
            final bookingRef = extractBookingReference(item['bookings']);

            final flat = Map<String, dynamic>.from(item);
            flat['commodity_name'] = comm['name'] ?? 'Agricultural Commodity';
            flat['grade_name'] = gr['grade_name'];
            flat['buyer_company_id'] = item['buyer_id'];
            flat['buyer_company_name'] = buyer['name'] ?? 'Buyer Enterprise';
            flat['seller_company_id'] = item['seller_id'];
            flat['seller_company_name'] = seller['name'] ?? 'Seller Enterprise';
            flat['booking_reference'] = bookingRef;

            items.add(DealItem.fromJson(flat));
          }
        }

        return DealSuccess(await _withRequirementNegotiations(items));
      }
    } catch (supabaseErr) {
      debugPrint('Supabase deals fallback error: $supabaseErr');
      return DealError(message: 'Supabase deals sync failed: $supabaseErr');
    }

    // 3. Fallback notice
    return const DealContractPending(
      contractNotice:
          'Authoritative endpoint /api/v1/broker/deals is pending backend exposure. Direct Supabase desk sync was attempted but tables are restricted or offline.',
    );
  }

  /// Broker proposals recorded on requirements are persisted as a deal version
  /// plus requirement status `Proposed to Buyer`; no `deals` row exists until
  /// an allocation creates one. Appends those as Negotiation items so the tab
  /// shows them. Requirements that already have a deal are skipped. Never
  /// fails the deal list: on error the deals are returned unchanged.
  Future<List<DealItem>> _withRequirementNegotiations(List<DealItem> deals) async {
    final client = _supabase;
    final brokerId = activeBrokerId();
    if (client == null || brokerId == null) return deals;
    try {
      final rows = await fetchRequirementNegotiationRows(brokerId);
      final withDeal = {for (final d in deals) d.requirementId};
      final pending = rows.where((r) => !withDeal.contains(r['id']?.toString())).toList();
      if (pending.isEmpty) return deals;

      final latest = await fetchLatestProposalSnapshots(
        pending.map((r) => r['id'].toString()).toList(),
      );
      final extra = [for (final r in pending) requirementNegotiationItem(r, latest[r['id'].toString()])];
      return [...deals, ...extra]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('Requirement negotiations unavailable: $e');
      return deals;
    }
  }

  /// This broker's requirements awaiting the buyer's response to a proposal.
  @visibleForTesting
  Future<List<Map<String, dynamic>>> fetchRequirementNegotiationRows(String brokerId) async {
    final rows = await _supabase!
        .from('requirements')
        .select(
          'id, company_id, quantity, target_price, target_date, status, created_at, '
          'master_commodities(name), master_grades(grade_name), master_units(symbol), '
          'companies(name)',
        )
        .eq('broker_id', brokerId)
        .eq('status', 'Proposed to Buyer')
        .order('created_at', ascending: false);
    return (rows as List).whereType<Map<String, dynamic>>().toList();
  }

  /// Latest deal version snapshot per request id (requirement id). Best effort.
  @visibleForTesting
  Future<Map<String, Map<String, dynamic>>> fetchLatestProposalSnapshots(List<String> requestIds) async {
    final out = <String, Map<String, dynamic>>{};
    try {
      final rows = await _supabase!
          .from('deal_versions')
          .select('request_id, version_number, snapshot_payload, created_at')
          .inFilter('request_id', requestIds)
          .order('version_number', ascending: false);
      for (final r in (rows as List).whereType<Map<String, dynamic>>()) {
        final id = r['request_id']?.toString();
        if (id == null || out.containsKey(id)) continue;
        out[id] = {
          'version_number': r['version_number'],
          'created_at': r['created_at'],
          ...?(r['snapshot_payload'] as Map<String, dynamic>?),
        };
      }
    } catch (e) {
      debugPrint('Proposal versions unavailable: $e');
    }
    return out;
  }

  @visibleForTesting
  static DealItem requirementNegotiationItem(Map<String, dynamic> r, Map<String, dynamic>? version) {
    final id = r['id'].toString();
    final shortId = id.length >= 6 ? id.substring(0, 6).toUpperCase() : id;
    final qty = (version?['quantity'] as num?)?.toDouble() ?? (r['quantity'] as num?)?.toDouble() ?? 0.0;
    final price = (version?['rate'] as num?)?.toDouble() ?? (r['target_price'] as num?)?.toDouble() ?? 0.0;
    final createdRaw = version?['created_at'] ?? r['created_at'];
    return DealItem(
      id: id,
      ref: 'RQ-$shortId',
      quotationId: '',
      requirementId: id,
      commodityName: (r['master_commodities'] as Map?)?['name']?.toString() ?? 'Agricultural Commodity',
      gradeName: (r['master_grades'] as Map?)?['grade_name']?.toString(),
      buyerCompanyId: r['company_id']?.toString() ?? '',
      buyerCompanyName: (r['companies'] as Map?)?['name']?.toString() ?? 'Buyer Mandate',
      sellerCompanyId: '',
      sellerCompanyName: 'Seller not allocated',
      agreedQuantity: qty,
      unitSymbol: (r['master_units'] as Map?)?['symbol']?.toString() ?? 'MT',
      agreedPrice: price,
      totalValuation: qty * price,
      priceBasis: 'FOR_DESTINATION',
      deliveryDate: version?['deliveryDate']?.toString() ?? r['target_date']?.toString(),
      status: DealStatus.negotiation,
      latestVersionNumber: (version?['version_number'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.tryParse(createdRaw?.toString() ?? '') ?? DateTime.now(),
      isRequirementNegotiation: true,
    );
  }

  // ============================================================================
  // 2. DEAL DETAIL
  // ============================================================================

  /// Fetches comprehensive deal record with versions and party confirmation status.
  Future<DealDataResult<DealDetailItem>> getDealDetail(String dealId) async {
    // 1. Attempt REST endpoint
    try {
      final response = await _apiClient.get('/broker/deals/$dealId');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == false) {
            return DealError(message: data['error']?.toString() ?? 'Deal not found');
          }
          final payload = data['data'] as Map<String, dynamic>? ?? data;
          return DealSuccess(DealDetailItem.fromJson(payload));
        }
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401) {
        return const DealUnauthorized();
      }
      debugPrint('REST deal detail notice: ${dioErr.message}');
    } catch (e) {
      debugPrint('REST deal detail error: $e');
    }

    // 2. Fallback: Supabase PostgREST query on deals and deal_versions
    try {
      final client = _supabase;
      if (client != null && activeBrokerId() != null) {
        final isUuid = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(dealId);

        dynamic response;
        if (isUuid) {
          response = await client
              .from('deals')
              .select(
                'id, requirement_id, quotation_id, buyer_id, seller_id, broker_id, '
                'agreed_price, agreed_quantity, status, created_at, closed_at, '
                'requirements(id, commodity_id, grade_id, master_commodities(name), master_grades(grade_name)), '
                'buyer:companies!buyer_id(id, name), '
                'seller:companies!seller_id(id, name), '
                'bookings(booking_reference)',
              )
              .eq('id', dealId)
              .maybeSingle();
        }

        if (response != null) {
          final req = response['requirements'] as Map<String, dynamic>? ?? {};
          final comm = req['master_commodities'] as Map<String, dynamic>? ?? {};
          final gr = req['master_grades'] as Map<String, dynamic>? ?? {};
          final buyer = response['buyer'] as Map<String, dynamic>? ?? {};
          final seller = response['seller'] as Map<String, dynamic>? ?? {};
          final bookingRef = extractBookingReference(response['bookings']);

          final flat = Map<String, dynamic>.from(response);
          flat['commodity_name'] = comm['name'] ?? 'Agricultural Commodity';
          flat['grade_name'] = gr['grade_name'];
          flat['buyer_company_id'] = response['buyer_id'];
          flat['buyer_company_name'] = buyer['name'] ?? 'Buyer Enterprise';
          flat['seller_company_id'] = response['seller_id'];
          flat['seller_company_name'] = seller['name'] ?? 'Seller Enterprise';
          flat['booking_reference'] = bookingRef;

          // Confirmation state and terms come from the latest version
          if (isUuid) {
            final versionsRes = await client
                .from('deal_versions')
                .select('version_number, status, snapshot_payload')
                .eq('request_id', dealId)
                .order('version_number', ascending: false)
                .limit(1);

            final versionList = versionsRes as List<dynamic>? ?? [];
            var confirmation = const DealVersionConfirmation();
            int latestVer = 1;

            if (versionList.isNotEmpty) {
              final latest = versionList.first as Map<String, dynamic>;
              latestVer = (latest['version_number'] as num?)?.toInt() ?? 1;
              final snapshot = latest['snapshot_payload'] as Map<String, dynamic>? ?? {};
              confirmation = DealVersionConfirmation.fromRecords(
                dealStatus: response['status']?.toString(),
                versionStatus: latest['status']?.toString(),
                snapshot: snapshot,
              );
              for (final key in const ['deliveryLocation', 'loadingLocationSnapshot', 'deliveryDate', 'paymentTerms', 'packagingType', 'priceBasis', 'notes']) {
                if (snapshot[key] != null) flat[key] = snapshot[key];
              }
              final terms = snapshot['deliveryTerms'] ?? snapshot['deliveryLocation'];
              if (terms != null) flat['deliveryTerms'] = terms;
              final unit = snapshot['unitSymbol'];
              if (unit != null) flat['unit_symbol'] = unit;
              final commission = snapshot['brokerCommissionRate'];
              if (commission is num) flat['brokerCommissionRate'] = commission;
            }

            flat['latestVersionNumber'] = latestVer;
            flat['buyerConfirmed'] = confirmation.buyerConfirmed;
            flat['sellerConfirmed'] = confirmation.sellerConfirmed;
          }

          return DealSuccess(DealDetailItem.fromJson(flat));
        }
        // Query succeeded but returned no row: deleted, malformed id, or RLS-hidden.
        return const DealError(
          message: 'Deal not found. It may have been removed or is not managed by your desk.',
          code: 'NOT_FOUND',
        );
      }
    } catch (supabaseErr) {
      debugPrint('Supabase deal detail fallback error: $supabaseErr');
    }

    return const DealContractPending(
      contractNotice: 'Deal detail record could not be loaded from backend.',
    );
  }

  // ============================================================================
  // 3. REQUIREMENT ALLOCATIONS
  // ============================================================================

  /// Fetches all active allocations created for a specific requirement mandate.
  Future<DealDataResult<List<AllocationItem>>> getAllocationsForRequirement(
    String requirementId,
  ) async {
    // 1. Attempt REST endpoint
    try {
      final response = await _apiClient.get(
        '/broker/allocations',
        queryParameters: {'requirementId': requirementId},
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == false) {
            return DealError(
              message: data['error']?.toString() ?? 'Failed to load allocations',
            );
          }
          final payload = data['data'] as Map<String, dynamic>? ?? {};
          final list = payload['allocations'] as List<dynamic>? ?? [];
          final items =
              list.whereType<Map<String, dynamic>>().map(AllocationItem.fromJson).toList();
          return DealSuccess(items);
        }
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401) {
        return const DealUnauthorized();
      }
      debugPrint('REST allocations notice: ${dioErr.message}');
    } catch (e) {
      debugPrint('REST allocations error: $e');
    }

    // 2. Fallback: Supabase PostgREST query on requirement_allocations
    try {
      final client = _supabase;
      if (client != null && activeBrokerId() != null) {
        // The seller company is availabilities.company_id (there is no seller_id column).
        final response = await client
            .from('requirement_allocations')
            .select(
              'id, allocation_reference, requirement_id, availability_id, broker_id, deal_id, '
              'allocated_quantity, unit_id, price_basis, allocated_price, status, notes, '
              'release_reason, version, allocated_at, confirmed_at, released_at, '
              'master_units(id, name, symbol), '
              'availabilities!inner(id, lot_number, company_id, companies(id, name, is_verified))',
            )
            .eq('requirement_id', requirementId)
            .order('allocated_at', ascending: false);

        final rawList = response as List<dynamic>;
        final items = <AllocationItem>[];

        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            final u = item['master_units'] as Map<String, dynamic>? ?? {};
            final avail = item['availabilities'] as Map<String, dynamic>? ?? {};
            final seller = avail['companies'] as Map<String, dynamic>? ?? {};

            final flat = Map<String, dynamic>.from(item);
            flat['lot_number'] = avail['lot_number'];
            flat['seller_company_id'] = seller['id'] ?? avail['company_id'];
            flat['seller_company_name'] = seller['name'] ?? 'Seller Enterprise';
            flat['seller_company_verified'] = seller['is_verified'] ?? false;
            flat['unit_name'] = u['name'] ?? 'Metric Tonne';
            flat['unit_symbol'] = u['symbol'] ?? 'MT';

            items.add(AllocationItem.fromJson(flat));
          }
        }

        return DealSuccess(items);
      }
    } catch (supabaseErr) {
      debugPrint('Supabase allocations fallback error: $supabaseErr');
    }

    return const DealContractPending(
      contractNotice:
          'Authoritative endpoint /api/v1/broker/allocations is pending backend exposure. Direct Supabase query was attempted.',
    );
  }

  // ============================================================================
  // 4. PROPOSE ALLOCATION
  // ============================================================================

  /// Proposes a controlled quantity allocation from a requirement against a seller offer.
  Future<DealDataResult<AllocationItem>> proposeAllocation(CreateAllocationDto dto) async {
    final validationError = dto.validate();
    if (validationError != null) {
      return DealError(message: validationError);
    }

    // 1. Attempt REST endpoint
    try {
      final response = await _apiClient.post(
        '/broker/allocations/propose',
        data: {
          'requirementId': dto.requirementId,
          'availabilityId': dto.availabilityId,
          'allocatedQuantity': dto.proposedQuantity,
          'allocatedPrice': dto.agreedPrice,
          'priceBasis': dto.priceBasis,
          'notes': dto.notes,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == false) {
            return DealError(
              message: data['error']?.toString() ?? 'Allocation proposal was rejected',
            );
          }
          final payload = data['data'] as Map<String, dynamic>? ?? data;
          return DealSuccess(AllocationItem.fromJson(payload));
        }
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401) {
        return const DealUnauthorized();
      }
      final body = dioErr.response?.data;
      final msg = (body is Map ? body['error']?.toString() : null) ?? dioErr.message;
      debugPrint('REST propose allocation error: $msg');
    } catch (e) {
      debugPrint('REST propose allocation error: $e');
    }

    // 2. Direct Supabase PostgREST insertion fallback
    try {
      final client = _supabase;
      final brokerId = activeBrokerId();
      if (client != null && brokerId != null) {
        return await _allocateWithReservation(client, brokerId, dto);
      }
    } catch (supabaseErr) {
      debugPrint('Supabase propose allocation error: $supabaseErr');
      return DealError(message: 'Failed to record allocation: $supabaseErr');
    }

    return const DealContractPending(
      contractNotice: 'Allocation proposal service is currently unavailable.',
    );
  }

  /// Direct-database allocation following the web desk's propose + confirm rules
  /// (broker-allocation-actions.ts), without its single transaction:
  /// 1. re-reads the requirement and seller lot and validates assignment, status,
  ///    product, validity and both balances (lot stock converted to the
  ///    requirement unit);
  /// 2. reuses an uncommitted allocation of the same lot and quantity instead of
  ///    creating a duplicate (retry after a failed deal step);
  /// 3. inserts PROPOSED, reserves lot stock, raises fulfilled_quantity, then
  ///    marks CONFIRMED — each step guarded, earlier steps compensated on failure.
  Future<DealDataResult<AllocationItem>> _allocateWithReservation(
    SupabaseClient client,
    String brokerId,
    CreateAllocationDto dto,
  ) async {
    final req = await client
        .from('requirements')
        .select('id, broker_id, status, quantity, fulfilled_quantity, unit_id, commodity_id, '
            'target_date, master_units(id, name, symbol)')
        .eq('id', dto.requirementId)
        .maybeSingle();
    if (req == null) {
      return const DealError(message: 'Requirement not found or no longer visible to your desk.');
    }
    if (req['broker_id']?.toString() != brokerId) {
      return const DealError(message: 'Forbidden: this requirement is not assigned to your desk.');
    }
    final reqStatus = RequirementStatus.fromString(req['status']?.toString());
    final targetDate = DateTime.tryParse(req['target_date']?.toString() ?? '');
    if (!reqStatus.isEligibleForMatching || (targetDate != null && targetDate.isBefore(DateTime.now()))) {
      return DealError(message: 'Requirement is "${req['status']}" and cannot take new allocations.');
    }
    final reqUnitObj = req['master_units'] as Map<String, dynamic>? ?? {};
    final reqUnit = reqUnitObj['symbol']?.toString() ?? dto.unitSymbol;
    final remaining = _num(req['quantity']) - _num(req['fulfilled_quantity']);
    if (dto.proposedQuantity > remaining + 1e-9) {
      return DealError(
        message: 'Allocation (${dto.proposedQuantity} $reqUnit) exceeds the remaining requirement '
            '(${remaining < 0 ? 0 : remaining} $reqUnit). Refresh and retry.',
      );
    }

    final lot = await client
        .from('availabilities')
        .select('id, broker_id, status, commodity_id, available_quantity, valid_until, '
            'master_units(symbol)')
        .eq('id', dto.availabilityId)
        .maybeSingle();
    if (lot == null) {
      return const DealError(message: 'Seller lot not found or no longer visible to your desk.');
    }
    if (lot['commodity_id']?.toString() != req['commodity_id']?.toString()) {
      return const DealError(message: 'Seller lot is a different product from the requirement.');
    }
    final validUntil = DateTime.tryParse(lot['valid_until']?.toString() ?? '');
    if (!OfferStatus.fromString(lot['status']?.toString()).isEligibleForMatching ||
        (validUntil != null && !validUntil.isAfter(DateTime.now()))) {
      return const DealError(message: 'Seller lot is no longer active or its validity has expired.');
    }
    if (lot['broker_id']?.toString() != brokerId) {
      // RLS lets only the managing broker update the lot, so stock cannot be reserved.
      return const DealError(
        message: 'This seller lot is managed by another broker desk; only that desk can reserve its stock.',
      );
    }
    final lotUnit = (lot['master_units'] as Map<String, dynamic>?)?['symbol']?.toString() ?? reqUnit;
    final lotQty = UnitUtils.convertBetween(dto.proposedQuantity, reqUnit, lotUnit);
    if (lotQty == null) {
      return DealError(message: 'Cannot convert $reqUnit to the lot unit $lotUnit; allocation blocked.');
    }
    if (lotQty > _num(lot['available_quantity']) + 1e-9) {
      return DealError(
        message: 'Allocation exceeds the seller lot balance (${_num(lot['available_quantity'])} $lotUnit). Refresh and retry.',
      );
    }

    Map<String, dynamic> withUnit(Map<String, dynamic> row) => {
          ...row,
          'unit_name': reqUnitObj['name'] ?? 'Metric Tonne',
          'unit_symbol': reqUnit,
          'seller_company_name': 'Allocated Seller Lot',
        };

    // Idempotent retry: a reserved allocation of this lot that never reached a deal.
    // Rows without confirmed_at were inserted as CONFIRMED by the old fallback
    // without reserving stock, so they are never reused.
    final open = await client
        .from('requirement_allocations')
        .select()
        .eq('requirement_id', dto.requirementId)
        .eq('availability_id', dto.availabilityId)
        .eq('broker_id', brokerId)
        .eq('status', 'CONFIRMED')
        .isFilter('deal_id', null)
        .not('confirmed_at', 'is', null);
    for (final row in (open as List).whereType<Map<String, dynamic>>()) {
      if ((_num(row['allocated_quantity']) - dto.proposedQuantity).abs() < 1e-9) {
        return DealSuccess(AllocationItem.fromJson(withUnit(row)));
      }
    }

    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final inserted = await client
        .from('requirement_allocations')
        .insert({
          'allocation_reference': 'ALC-${stamp.substring(stamp.length - 9)}',
          'requirement_id': dto.requirementId,
          'availability_id': dto.availabilityId,
          'broker_id': brokerId,
          'allocated_quantity': dto.proposedQuantity,
          'unit_id': req['unit_id'],
          'price_basis': dto.priceBasis,
          'allocated_price': dto.agreedPrice,
          'status': 'PROPOSED',
          'notes': dto.notes,
          'version': 1,
        })
        .select()
        .single();
    final allocationId = inserted['id'].toString();

    Future<void> abandon() async {
      await client
          .from('requirement_allocations')
          .update({'status': 'CANCELLED', 'release_reason': 'Reservation failed on broker mobile'})
          .eq('id', allocationId);
    }

    if (!await _shiftLotReservation(client, dto.availabilityId, lotQty)) {
      await abandon();
      return const DealError(
        message: 'Seller lot stock changed or is no longer sufficient. Refresh the offers and retry.',
      );
    }
    if (!await _shiftRequirementFulfilled(client, dto.requirementId, dto.proposedQuantity)) {
      await _shiftLotReservation(client, dto.availabilityId, -lotQty);
      await abandon();
      return const DealError(
        message: 'Requirement balance changed or would be over-allocated. Refresh and retry.',
      );
    }

    final confirmed = await client
        .from('requirement_allocations')
        .update({
          'status': 'CONFIRMED',
          'confirmed_at': DateTime.now().toUtc().toIso8601String(),
          'version': 2,
        })
        .eq('id', allocationId)
        .eq('status', 'PROPOSED')
        .select();
    final rows = (confirmed as List).whereType<Map<String, dynamic>>().toList();
    if (rows.isEmpty) {
      await _shiftRequirementFulfilled(client, dto.requirementId, -dto.proposedQuantity);
      await _shiftLotReservation(client, dto.availabilityId, -lotQty);
      await abandon();
      return const DealError(message: 'Allocation could not be confirmed. No quantity was reserved.');
    }
    return DealSuccess(AllocationItem.fromJson(withUnit(rows.first)));
  }

  // ============================================================================
  // 5. CONFIRM ALLOCATION
  // ============================================================================

  /// Authoritatively confirms an allocation.
  Future<DealDataResult<bool>> confirmAllocation(
    String allocationId, {
    int expectedVersion = 1,
  }) async {
    // 1. Attempt REST endpoint
    try {
      final response = await _apiClient.post(
        '/broker/allocations/confirm',
        data: {
          'allocationId': allocationId,
          'expectedVersion': expectedVersion,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          return const DealSuccess(true);
        }
      }
    } catch (_) {}

    // 2. Direct Supabase Fallback
    try {
      final client = _supabase;
      if (client != null) {
        await client
            .from('requirement_allocations')
            .update({
              'status': 'CONFIRMED',
              'confirmed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', allocationId);
        return const DealSuccess(true);
      }
    } catch (e) {
      return DealError(message: 'Failed to confirm allocation: $e');
    }

    return const DealError(message: 'Could not confirm allocation on server.');
  }

  // ============================================================================
  // 6. CREATE DEAL FROM ALLOCATION
  // ============================================================================

  /// Authoritatively converts a confirmed allocation into an initial immutable Version 1 deal record.
  /// Location terms a new deal keeps in its immutable version snapshot, copied from the
  /// requirement and offer so later edits to a saved location never rewrite history.
  /// Rows saved before location columns existed fall back to their stored text.
  @visibleForTesting
  static Map<String, dynamic> createdLocationTerms(Map<String, dynamic> requirement, Map<String, dynamic> offer) {
    final legacyLoading = offer['loading_remarks']?.toString().split(' | Notes:').first;
    return {
      'unloadingLocationId': requirement['delivery_location_id'],
      'loadingLocationId': offer['loading_location_id'],
      'loadingLocationSnapshot': offer['loading_location_snapshot'] ?? legacyLoading,
    };
  }

  Future<DealDataResult<DealItem>> createDealFromAllocation(CreateDealDto dto) async {
    final validationError = dto.validate();
    if (validationError != null) {
      return DealError(message: validationError);
    }

    // 1. Attempt REST endpoint
    try {
      final response = await _apiClient.post(
        '/broker/deals/create-from-allocation',
        data: {
          'allocationId': dto.allocationId,
          'customTerms': {
            'agreedPrice': dto.agreedPrice,
            'agreedQuantity': dto.agreedQuantity,
            'priceBasis': dto.priceBasis,
            'deliveryLocation': dto.deliveryLocation,
            'deliveryDate': dto.deliveryDate.toIso8601String(),
            'deliveryTerms': dto.deliveryTerms,
            'paymentTerms': dto.paymentTerms,
            'packagingType': dto.packagingType,
            'brokerCommissionRate': dto.brokerCommissionRate,
            'commissionBasis': dto.commissionBasis,
            'notes': dto.notes,
          },
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == false) {
            return DealError(
              message: data['error']?.toString() ?? 'Deal creation failed on server',
            );
          }
          final payload = data['data'] as Map<String, dynamic>? ?? data;
          return DealSuccess(DealItem.fromJson(payload));
        }
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401) {
        return const DealUnauthorized();
      }
      final body = dioErr.response?.data;
      final msg = (body is Map ? body['error']?.toString() : null) ?? dioErr.message;
      debugPrint('REST create deal error: $msg');
    } catch (e) {
      debugPrint('REST create deal error: $e');
    }

    // 2. Direct Supabase PostgREST transaction fallback
    try {
      final client = _supabase;
      final brokerId = activeBrokerId();
      if (client != null && brokerId != null) {
        // Fetch allocation. The seller company is availabilities.company_id
        // (there is no seller_id column), and deals.buyer_id/seller_id reference companies.
        final allocRes = await client
            .from('requirement_allocations')
            .select(
              'id, status, deal_id, broker_id, allocation_reference, requirement_id, availability_id, '
              'allocated_quantity, allocated_price, '
              // Whole rows: the location columns are read when present (see createdLocationTerms).
              'requirements(*, master_commodities(name), '
              'master_units(symbol), companies(name)), '
              'availabilities(*, companies(name))',
            )
            .eq('id', dto.allocationId)
            .maybeSingle();

        if (allocRes == null) {
          return const DealError(message: 'Allocation record not found for deal creation');
        }
        if (allocRes['broker_id']?.toString() != brokerId) {
          return const DealError(message: 'Forbidden: this allocation belongs to another broker desk.');
        }

        // Idempotency: a retry or late response must not create a second deal.
        final existingDealId = allocRes['deal_id']?.toString();
        if (existingDealId != null && existingDealId.isNotEmpty) {
          final existing = await getDealDetail(existingDealId);
          if (existing is DealSuccess<DealDetailItem>) return DealSuccess(existing.data.deal);
          return DealError(message: 'This allocation is already committed to deal $existingDealId.');
        }
        if (allocRes['status'] != 'CONFIRMED') {
          return DealError(
            message: 'Allocation is "${allocRes['status']}" and must be confirmed before a deal is created.',
          );
        }

        final req = allocRes['requirements'] as Map<String, dynamic>? ?? {};
        final avail = allocRes['availabilities'] as Map<String, dynamic>? ?? {};
        if (const ['Cancelled', 'Expired', 'Rejected'].contains(req['status'])) {
          return DealError(message: 'Linked buyer requirement is inactive (${req['status']}).');
        }
        if (const ['Cancelled', 'Expired', 'Rejected'].contains(avail['status'])) {
          return DealError(message: 'Linked seller lot is inactive (${avail['status']}).');
        }
        final buyerId = req['company_id']?.toString() ?? '';
        final sellerId = avail['company_id']?.toString() ?? '';
        final comm = req['master_commodities'] as Map<String, dynamic>? ?? {};
        final buyerCo = req['companies'] as Map<String, dynamic>? ?? {};
        final sellerCo = avail['companies'] as Map<String, dynamic>? ?? {};
        final unitSymbol = (req['master_units'] as Map<String, dynamic>?)?['symbol']?.toString() ?? 'MT';

        // Find or create the quotation link (as the web desk does), so a retried
        // deal step never leaves duplicate quotations behind.
        final existingQuote = await client
            .from('quotations')
            .select('id')
            .eq('requirement_id', allocRes['requirement_id'])
            .eq('seller_availability_id', allocRes['availability_id'])
            .eq('broker_id', brokerId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        final quotationId = existingQuote?['id'] ??
            (await client
                .from('quotations')
                .insert({
                  'requirement_id': allocRes['requirement_id'],
                  'broker_id': brokerId,
                  'seller_availability_id': allocRes['availability_id'],
                  'offered_price': dto.agreedPrice,
                  'status': 'Accepted',
                  'valid_until': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
                })
                .select('id')
                .single())['id'];

        // Create deal
        final dealRes = await client
            .from('deals')
            .insert({
              'requirement_id': allocRes['requirement_id'],
              'quotation_id': quotationId,
              'buyer_id': buyerId,
              'seller_id': sellerId,
              'broker_id': brokerId,
              'agreed_price': dto.agreedPrice,
              'agreed_quantity': dto.agreedQuantity,
              'status': 'Draft',
            })
            .select()
            .single();

        final dealId = dealRes['id'];

        // Create initial immutable Version 1 snapshot in deal_versions
        await client.from('deal_versions').insert({
          'request_id': dealId,
          'version_number': 1,
          'actor_id': brokerId,
          'status': 'Draft',
          'snapshot_payload': {
            'dealId': dealId,
            'quotationId': quotationId,
            'allocationId': dto.allocationId,
            'allocationReference': allocRes['allocation_reference'],
            'requirementId': allocRes['requirement_id'],
            'availabilityId': allocRes['availability_id'],
            'commodityName': comm['name'],
            'unitSymbol': unitSymbol,
            'agreedPrice': dto.agreedPrice,
            'agreedQuantity': dto.agreedQuantity,
            'priceBasis': dto.priceBasis,
            'deliveryLocation': dto.deliveryLocation,
            ...createdLocationTerms(req, avail),
            'deliveryDate': dto.deliveryDate.toIso8601String(),
            'deliveryTerms': dto.deliveryTerms,
            'paymentTerms': dto.paymentTerms,
            'packagingType': dto.packagingType,
            'brokerCommissionRate': dto.brokerCommissionRate,
            'buyerCompanyId': buyerId,
            'sellerCompanyId': sellerId,
            'buyerConfirmed': false,
            'sellerConfirmed': false,
            'versionReason': 'Initial deal draft created from confirmed allocation',
            'originatorRole': 'broker',
          },
        });

        // Update allocation to COMMITTED_TO_DEAL with dealId
        await client
            .from('requirement_allocations')
            .update({
              'status': 'COMMITTED_TO_DEAL',
              'deal_id': dealId,
              'version': 3,
            })
            .eq('id', dto.allocationId);

        final flat = Map<String, dynamic>.from(dealRes);
        flat['commodity_name'] = comm['name'] ?? 'Agricultural Commodity';
        flat['buyer_company_id'] = buyerId;
        flat['buyer_company_name'] = buyerCo['name'] ?? 'Buyer Enterprise';
        flat['seller_company_id'] = sellerId;
        flat['seller_company_name'] = sellerCo['name'] ?? 'Seller Enterprise';
        flat['unit_symbol'] = unitSymbol;
        flat['total_valuation'] = dto.agreedQuantity * dto.agreedPrice;
        flat['allocation_id'] = dto.allocationId;

        return DealSuccess(DealItem.fromJson(flat));
      }
    } catch (supabaseErr) {
      debugPrint('Supabase create deal error: $supabaseErr');
      return DealError(message: 'Failed to create deal record: $supabaseErr');
    }

    return const DealContractPending(
      contractNotice: 'Authoritative deal creation service is currently unavailable.',
    );
  }

  // ============================================================================
  // 7. CANCEL DEAL
  // ============================================================================

  /// Authoritatively cancels a deal and restores any linked allocations.
  Future<DealDataResult<bool>> cancelDeal(String dealId, String reason) async {
    if (reason.trim().length < 3) {
      return const DealError(message: 'Audit cancellation reason is required (min 3 chars)');
    }

    // 1. Attempt REST endpoint
    try {
      final response = await _apiClient.post(
        '/broker/deals/$dealId/cancel',
        data: {'reason': reason.trim()},
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          return const DealSuccess(true);
        }
      }
    } catch (_) {}

    // 2. Direct Supabase Fallback
    try {
      final client = _supabase;
      final brokerId = activeBrokerId();
      if (client != null && brokerId != null) {
        final deal = await client
            .from('deals')
            .select('id, status, broker_id')
            .eq('id', dealId)
            .maybeSingle();
        if (deal == null) return const DealError(message: 'Deal record not found');
        if (deal['broker_id']?.toString() != brokerId) {
          return const DealError(message: 'Forbidden: this deal is managed by another broker desk.');
        }
        final status = deal['status']?.toString();
        if (status == 'Cancelled') return const DealError(message: 'This deal has already been cancelled.');
        if (_isClosedDealStatus(status)) {
          return DealError(message: 'Cannot cancel a "$status" deal.');
        }

        final nowIso = DateTime.now().toUtc().toIso8601String();
        // deal_versions rows are not updatable from the app (no UPDATE policy);
        // the deal row carries the terminal state.
        await client.from('deals').update({'status': 'Cancelled', 'closed_at': nowIso}).eq('id', dealId);

        // Release linked allocations and give their reserved quantity back.
        final linked = await client
            .from('requirement_allocations')
            .select('id, requirement_id, availability_id, allocated_quantity, status, confirmed_at, '
                'master_units(symbol), availabilities(master_units(symbol))')
            .eq('deal_id', dealId);
        for (final alloc in (linked as List).whereType<Map<String, dynamic>>()) {
          if (alloc['status'] == 'RELEASED' || alloc['status'] == 'CANCELLED') continue;
          await client
              .from('requirement_allocations')
              .update({
                'status': 'RELEASED',
                'release_reason': 'Deal cancelled: ${reason.trim()}',
                'released_at': nowIso,
              })
              .eq('id', alloc['id']);
          // Only allocations reserved through the guarded path moved quantities.
          if (alloc['confirmed_at'] == null) continue;
          final qty = _num(alloc['allocated_quantity']);
          final reqUnit = (alloc['master_units'] as Map<String, dynamic>?)?['symbol']?.toString() ?? 'MT';
          final lotUnit = ((alloc['availabilities'] as Map<String, dynamic>?)?['master_units']
                  as Map<String, dynamic>?)?['symbol']
              ?.toString() ?? reqUnit;
          final lotQty = UnitUtils.convertBetween(qty, reqUnit, lotUnit);
          if (lotQty != null) {
            await _shiftLotReservation(client, alloc['availability_id'].toString(), -lotQty);
          }
          await _shiftRequirementFulfilled(client, alloc['requirement_id'].toString(), -qty);
        }

        return const DealSuccess(true);
      }
    } catch (e) {
      return DealError(message: 'Failed to cancel deal: $e');
    }

    return const DealError(message: 'Could not cancel deal on server.');
  }

  // ============================================================================
  // 8. DEAL VERSION HISTORY & VISUAL DIFFS (RB-FL-09)
  // ============================================================================

  /// Fetches chronological timeline of immutable versions for a deal with material diffs.
  Future<DealDataResult<List<DealVersionItem>>> getDealVersionHistory(String dealId) async {
    // 1. Attempt REST endpoint
    try {
      final response = await _apiClient.get('/broker/deals/$dealId/versions');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == false) {
            return DealError(message: data['error']?.toString() ?? 'Failed to load version history');
          }
          final payload = data['data'] as Map<String, dynamic>? ?? {};
          final list = payload['versions'] as List<dynamic>? ?? [];
          final items = list.whereType<Map<String, dynamic>>().map(DealVersionItem.fromJson).toList();
          return DealSuccess(items);
        }
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401) {
        return const DealUnauthorized();
      }
      debugPrint('REST version history notice: ${dioErr.message}');
    } catch (e) {
      debugPrint('REST version history error: $e');
    }

    // 2. Direct Supabase PostgREST query on deal_versions
    try {
      final client = _supabase;
      if (client != null) {
        final versionsRes = await client
            .from('deal_versions')
            // deal_versions has no change_reason column; the reason travels in the snapshot.
            .select('id, request_id, version_number, status, actor_id, created_at, snapshot_payload')
            .eq('request_id', dealId)
            .order('version_number', ascending: true);

        final rawList = versionsRes as List<dynamic>;
        final items = <DealVersionItem>[];
        Map<String, dynamic>? previousSnapshot;

        for (final row in rawList) {
          if (row is Map<String, dynamic>) {
            final snapshot = row['snapshot_payload'] as Map<String, dynamic>? ?? {};
            final diffs = DealVersionEngine.getMaterialDiffList(previousSnapshot, snapshot);

            final flat = Map<String, dynamic>.from(row);
            flat['change_reason'] = snapshot['changeReason'] ?? snapshot['versionReason'];
            flat['snapshot'] = snapshot;
            flat['diffs'] = diffs.map((d) => d.toJson()).toList();
            flat['actor_name'] = 'Broker Desk';
            flat['actor_role'] = 'broker';

            items.add(DealVersionItem.fromJson(flat));
            previousSnapshot = snapshot;
          }
        }

        return DealSuccess(items.reversed.toList()); // Return newest first for UI timeline
      }
    } catch (supabaseErr) {
      debugPrint('Supabase version history fallback error: $supabaseErr');
    }

    return const DealContractPending(
      contractNotice: 'Deal version history could not be synchronized with server.',
    );
  }

  // ============================================================================
  // 9. PROPOSE TERMS AMENDMENT (RB-FL-09)
  // ============================================================================

  /// Authoritatively updates deal terms, increments version number, and resets counterparty confirmations.
  Future<DealDataResult<DealDetailItem>> updateDealTerms(UpdateDealTermsDto dto) async {
    final validationError = dto.validate();
    if (validationError != null) {
      return DealError(message: validationError);
    }

    // 1. Attempt REST endpoint
    try {
      final response = await _apiClient.post(
        '/broker/deals/${dto.dealId}/terms',
        data: {
          'expectedVersion': dto.expectedVersion,
          'terms': {
            'agreedPrice': dto.agreedPrice,
            'agreedQuantity': dto.agreedQuantity,
            'priceBasis': dto.priceBasis,
            'deliveryLocation': dto.deliveryLocation,
            'deliveryDate': dto.deliveryDate.toIso8601String(),
            'deliveryTerms': dto.deliveryTerms,
            'paymentTerms': dto.paymentTerms,
            'packagingType': dto.packagingType,
            'brokerCommissionRate': dto.brokerCommissionRate,
            'commissionBasis': dto.commissionBasis,
            'reason': dto.reason,
          },
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == false) {
            return DealError(
              message: data['error']?.toString() ?? 'Deal terms revision failed on server',
            );
          }
          final payload = data['data'] as Map<String, dynamic>? ?? data;
          return DealSuccess(DealDetailItem.fromJson(payload));
        }
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401) {
        return const DealUnauthorized();
      }
      final body = dioErr.response?.data;
      final msg = (body is Map ? body['error']?.toString() : null) ?? dioErr.message;
      debugPrint('REST update deal terms error: $msg');
    } catch (e) {
      debugPrint('REST update deal terms error: $e');
    }

    // 2. Direct Supabase PostgREST versioning fallback
    try {
      final client = _supabase;
      final brokerId = activeBrokerId();
      if (client != null && brokerId != null) {
        final deal = await client
            .from('deals')
            .select('id, status, broker_id')
            .eq('id', dto.dealId)
            .maybeSingle();
        if (deal == null) return const DealError(message: 'Deal record not found');
        if (_isClosedDealStatus(deal['status']?.toString())) {
          return DealError(message: 'Deal is "${deal['status']}"; its terms can no longer be amended.');
        }

        // Fetch latest version
        final latestVersions = await client
            .from('deal_versions')
            .select('id, version_number, status, snapshot_payload')
            .eq('request_id', dto.dealId)
            .order('version_number', ascending: false)
            .limit(1);

        final rawList = latestVersions as List<dynamic>;
        int currentVer = 1;
        Map<String, dynamic>? oldSnapshot;

        if (rawList.isNotEmpty) {
          final top = rawList.first as Map<String, dynamic>;
          currentVer = (top['version_number'] as num?)?.toInt() ?? 1;
          oldSnapshot = top['snapshot_payload'] as Map<String, dynamic>?;
        }

        // Optimistic Concurrency Guard
        if (currentVer != dto.expectedVersion) {
          return DealError(
            message:
                'STALE_VERSION_DETECTED: Terms have already been revised to v$currentVer by another user. Please refresh and review latest terms.',
            code: 'STALE_VERSION_DETECTED',
          );
        }

        final newSnapshot = dto.toSnapshot();
        final isMaterial = DealVersionEngine.detectMaterialChanges(oldSnapshot, newSnapshot);

        if (!isMaterial) {
          return const DealError(
            message: 'No material changes detected between current terms and proposed amendment.',
          );
        }

        final nextVersionNumber = currentVer + 1;

        // Keep record links from the previous version, and reset confirmations.
        for (final key in const [
          'dealId', 'quotationId', 'allocationId', 'allocationReference', 'requirementId',
          'availabilityId', 'commodityName', 'unitSymbol', 'buyerCompanyId', 'sellerCompanyId',
          'unloadingLocationId', 'loadingLocationId', 'loadingLocationSnapshot',
        ]) {
          if (oldSnapshot?[key] != null) newSnapshot.putIfAbsent(key, () => oldSnapshot![key]);
        }
        newSnapshot['buyerConfirmed'] = false;
        newSnapshot['sellerConfirmed'] = false;
        newSnapshot['changeReason'] = dto.reason ?? 'Broker proposed terms revision to v$nextVersionNumber';

        // Insert the new version (a unique version per deal is enforced by the
        // stale check above; prior rows are immutable from the app).
        await client.from('deal_versions').insert({
          'request_id': dto.dealId,
          'version_number': nextVersionNumber,
          'status': 'Negotiation',
          'actor_id': brokerId,
          'snapshot_payload': newSnapshot,
        });

        // Update deals record; Negotiation clears confirmations of the old version.
        await client.from('deals').update({
          'agreed_price': dto.agreedPrice,
          'agreed_quantity': dto.agreedQuantity,
          'status': 'Negotiation',
        }).eq('id', dto.dealId);

        return await getDealDetail(dto.dealId);
      }
    } catch (supabaseErr) {
      debugPrint('Supabase update deal terms error: $supabaseErr');
      return DealError(message: 'Failed to save deal terms version: $supabaseErr');
    }

    return const DealContractPending(
      contractNotice: 'Deal terms amendment service is currently synchronizing.',
    );
  }

  // ============================================================================
  // 10. RECORD PARTY CONFIRMATION (RB-FL-09)
  // ============================================================================

  /// Authoritatively records formal acceptance from either Buyer or Seller against exact version.
  Future<DealDataResult<DealConfirmationState>> recordPartyConfirmation(
    PartyConfirmationDto dto,
  ) async {
    final validationError = dto.validate();
    if (validationError != null) {
      return DealError(message: validationError);
    }

    // 1. Attempt REST endpoint
    try {
      final response = await _apiClient.post(
        '/broker/deals/${dto.dealId}/confirm-party',
        data: {
          'party': dto.party,
          'versionNumber': dto.versionNumber,
          'verificationNotes': dto.verificationNotes,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == false) {
            return DealError(
              message: data['error']?.toString() ?? 'Confirmation recording failed',
            );
          }
          final payload = data['data'] as Map<String, dynamic>? ?? data;
          return DealSuccess(DealConfirmationState.fromJson(payload));
        }
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401) {
        return const DealUnauthorized();
      }
      final body = dioErr.response?.data;
      final msg = (body is Map ? body['error']?.toString() : null) ?? dioErr.message;
      debugPrint('REST party confirmation error: $msg');
    } catch (e) {
      debugPrint('REST party confirmation error: $e');
    }

    // 2. Direct Supabase PostgREST confirmation fallback
    try {
      final client = _supabase;
      final brokerId = activeBrokerId();
      if (client != null && brokerId != null) {
        final deal = await client
            .from('deals')
            .select('id, status, broker_id')
            .eq('id', dto.dealId)
            .maybeSingle();
        if (deal == null) return const DealError(message: 'Deal record not found');
        if (deal['broker_id']?.toString() != brokerId) {
          return const DealError(message: 'Forbidden: this deal is managed by another broker desk.');
        }
        if (_isClosedDealStatus(deal['status']?.toString())) {
          return DealError(message: 'Cannot record confirmation for a "${deal['status']}" deal.');
        }

        // Fetch latest version
        final latestVersions = await client
            .from('deal_versions')
            .select('id, version_number, status, snapshot_payload')
            .eq('request_id', dto.dealId)
            .order('version_number', ascending: false)
            .limit(1);

        final rawList = latestVersions as List<dynamic>;
        if (rawList.isEmpty) {
          return const DealError(message: 'No deal version found to record confirmation');
        }

        final top = rawList.first as Map<String, dynamic>;
        final currentVer = (top['version_number'] as num?)?.toInt() ?? 1;

        if (currentVer != dto.versionNumber) {
          return DealError(
            message:
                'STALE_VERSION_DETECTED: Target version v${dto.versionNumber} is stale. Current active terms are v$currentVer. Please re-confirm latest terms.',
            code: 'STALE_VERSION_DETECTED',
          );
        }

        final current = DealVersionConfirmation.fromRecords(
          dealStatus: deal['status']?.toString(),
          versionStatus: top['status']?.toString(),
          snapshot: top['snapshot_payload'] as Map<String, dynamic>?,
        );
        final next = current.withParty(dto.party);

        // A repeated tap or retry for an already-confirmed party writes nothing.
        if (!current.hasConfirmed(dto.party)) {
          // The version row is immutable from the app, so progress lives on the deal.
          final updated = await client
              .from('deals')
              .update({'status': next.dealStatus})
              .eq('id', dto.dealId)
              .eq('status', deal['status'] ?? '')
              .select('id');
          if ((updated as List).isEmpty) {
            return const DealError(
              message: 'The deal changed while confirming. Refresh and review the latest terms.',
              code: 'STALE_VERSION_DETECTED',
            );
          }
        }

        return DealSuccess(
          DealConfirmationState(
            latestVersionNumber: currentVer,
            buyerConfirmed: next.buyerConfirmed,
            sellerConfirmed: next.sellerConfirmed,
            canFinalize: next.isComplete,
          ),
        );
      }
    } catch (supabaseErr) {
      debugPrint('Supabase party confirmation error: $supabaseErr');
      return DealError(message: 'Failed to record confirmation: $supabaseErr');
    }

    return const DealContractPending(
      contractNotice: 'Party confirmation recording service is currently offline.',
    );
  }

  // ============================================================================
  // 11. AUTHORITATIVE DEAL FINALIZATION (RB-FL-09 PRE-FLIGHT GATE)
  // ============================================================================

  /// Authoritatively finalizes a deal after verifying dual-party confirmation on identical version.
  Future<DealDataResult<String>> finalizeDeal(String dealId, int expectedVersion) async {
    // 1. Attempt REST endpoint
    try {
      final response = await _apiClient.post(
        '/broker/deals/$dealId/finalize',
        data: {'expectedVersion': expectedVersion},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == false) {
            return DealError(
              message: data['error']?.toString() ?? 'Pre-flight finalization gate rejected',
            );
          }
          final bookingRef = data['bookingReference']?.toString() ??
              data['data']?['bookingReference']?.toString() ??
              'BKG-${DateTime.now().year}-1001';
          return DealSuccess(bookingRef);
        }
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401) {
        return const DealUnauthorized();
      }
      final body = dioErr.response?.data;
      final msg = (body is Map ? body['error']?.toString() : null) ?? dioErr.message;
      debugPrint('REST finalize deal error: $msg');
    } catch (e) {
      debugPrint('REST finalize deal error: $e');
    }

    // 2. Direct Supabase PostgREST finalization fallback
    try {
      final client = _supabase;
      final brokerId = activeBrokerId();
      if (client != null && brokerId != null) {

        // Check deal status
        final dealRes = await client
            .from('deals')
            .select('id, status, broker_id, agreed_price, agreed_quantity, quotation_id')
            .eq('id', dealId)
            .maybeSingle();

        if (dealRes == null) {
          return const DealError(message: 'Deal record not found');
        }
        if (dealRes['broker_id']?.toString() != brokerId) {
          return const DealError(message: 'Forbidden: only the managing broker can finalize this deal.');
        }

        Future<String?> existingBookingRef() async {
          final row = await client
              .from('bookings')
              .select('booking_reference')
              .eq('deal_id', dealId)
              .maybeSingle();
          return row?['booking_reference']?.toString();
        }

        final currentStatus = dealRes['status']?.toString();
        if (currentStatus == 'Finalized') {
          // Late response or repeated tap: report the booking that already exists.
          final ref = await existingBookingRef();
          if (ref != null) return DealSuccess(ref);
        }
        if (_isClosedDealStatus(currentStatus)) {
          return DealError(
            message: 'Deal is in $currentStatus state and cannot be finalized.',
          );
        }

        // Fetch latest version
        final latestVersions = await client
            .from('deal_versions')
            .select('id, version_number, status, snapshot_payload')
            .eq('request_id', dealId)
            .order('version_number', ascending: false)
            .limit(1);

        final rawList = latestVersions as List<dynamic>;
        if (rawList.isEmpty) {
          return const DealError(message: 'No deal version found to finalize');
        }

        final top = rawList.first as Map<String, dynamic>;
        final currentVer = (top['version_number'] as num?)?.toInt() ?? 1;

        if (currentVer != expectedVersion) {
          return DealError(
            message:
                'STALE_VERSION_DETECTED: Target version v$expectedVersion is outdated. Active terms are v$currentVer.',
            code: 'STALE_VERSION_DETECTED',
          );
        }

        final confirmation = DealVersionConfirmation.fromRecords(
          dealStatus: currentStatus,
          versionStatus: top['status']?.toString(),
          snapshot: top['snapshot_payload'] as Map<String, dynamic>?,
        );
        final buyerConf = confirmation.buyerConfirmed;
        final sellerConf = confirmation.sellerConfirmed;

        // CRITICAL INVARIANT: PRE-FLIGHT GATE REQUIRES BOTH PARTIES CONFIRMED
        if (!buyerConf || !sellerConf) {
          return DealError(
            message:
                'PRE_FLIGHT_BLOCKED: Finalization requires verified confirmation from BOTH Buyer and Seller on Version $currentVer. (Buyer: ${buyerConf ? "Confirmed" : "Pending"}, Seller: ${sellerConf ? "Confirmed" : "Pending"})',
            code: 'PRE_FLIGHT_BLOCKED',
          );
        }

        // One booking per deal (bookings_deal_id_unique) is the idempotency guard:
        // a duplicate tap or retry hits 23505 and reuses the existing booking.
        String? bookingRef;
        for (var attempt = 0; attempt < 2 && bookingRef == null; attempt++) {
          final stamp = DateTime.now().millisecondsSinceEpoch.toString();
          final candidate = 'BKG-${DateTime.now().year}-${stamp.substring(stamp.length - 6)}';
          try {
            final inserted = await client
                .from('bookings')
                .insert({
                  'deal_id': dealId,
                  'booking_reference': candidate,
                  'locked_version_id': top['id'],
                  'status': 'Confirmed',
                })
                .select('booking_reference')
                .single();
            bookingRef = inserted['booking_reference']?.toString() ?? candidate;
          } catch (e) {
            if (!_isUniqueViolation(e)) rethrow;
            // Either this deal already has a booking, or the reference collided.
            bookingRef = await existingBookingRef();
          }
        }
        if (bookingRef == null) {
          return const DealError(message: 'Could not issue a booking reference. Please retry.');
        }

        // Update deals record to Finalized (version rows are immutable from the app).
        await client.from('deals').update({
          'status': 'Finalized',
          'closed_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', dealId);

        final quotationId = dealRes['quotation_id'];
        if (quotationId != null) {
          await client.from('quotations').update({'status': 'Broker Finalized'}).eq('id', quotationId);
        }

        return DealSuccess(bookingRef);
      }
    } catch (supabaseErr) {
      debugPrint('Supabase finalize deal error: $supabaseErr');
      return DealError(message: 'Failed to finalize deal: $supabaseErr');
    }

    return const DealContractPending(
      contractNotice: 'Deal finalization service is currently synchronizing.',
    );
  }
  /// Fetches registered bank details for a seller company to assist with deal document sharing.
  Future<ChequeLeafData?> getSellerBankDetails(String sellerCompanyId) async {
    try {
      if (_supabase != null) {
        final res = await _supabase!
            .from('companies')
            .select('bank_holder_name, bank_name, bank_account_number, bank_ifsc, bank_branch, bank_cheque_url, bank_verification_status')
            .eq('id', sellerCompanyId)
            .maybeSingle();

        if (res != null && res is Map<String, dynamic>) {
          return ChequeLeafData.fromJson(res);
        }
      }
    } catch (e) {
      debugPrint('Seller bank details fetch notice: $e');
    }
    return null;
  }

  /// Records an audit log entry when deal summary and seller cheque leaf are shared.
  Future<bool> logDealDocumentShare({
    required String dealId,
    required String recipientCompanyId,
    required String documentType,
    required Map<String, dynamic> sharedPayload,
    String? documentRef,
  }) async {
    try {
      final brokerId = await _storage.getUserId();
      if (_supabase != null && brokerId != null) {
        await _supabase!.from('deal_document_shares').insert({
          'deal_id': dealId,
          'broker_id': brokerId,
          'recipient_company_id': recipientCompanyId,
          'document_type': documentType,
          'document_ref': documentRef,
          'shared_payload': sharedPayload,
          'shared_at': DateTime.now().toUtc().toIso8601String(),
        });
        return true;
      }
    } catch (e) {
      debugPrint('Deal document share log notice: $e');
    }
    return false;
  }
}