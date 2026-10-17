import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/security/secure_storage_service.dart';
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
          return DealSuccess(items);
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
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        final brokerId = session.user.id;

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
            final bookingList = item['bookings'] as List<dynamic>? ?? [];
            final bookingRef = bookingList.isNotEmpty
                ? (bookingList.first as Map<String, dynamic>)['booking_reference']?.toString()
                : null;

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

        return DealSuccess(items);
      }
    } catch (supabaseErr) {
      debugPrint('Supabase deals fallback error: $supabaseErr');
    }

    // 3. Fallback notice
    return const DealContractPending(
      contractNotice:
          'Authoritative endpoint /api/v1/broker/deals is pending backend exposure. Direct Supabase desk sync was attempted but tables are restricted or offline.',
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
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        final response = await client
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

        if (response != null) {
          final req = response['requirements'] as Map<String, dynamic>? ?? {};
          final comm = req['master_commodities'] as Map<String, dynamic>? ?? {};
          final gr = req['master_grades'] as Map<String, dynamic>? ?? {};
          final buyer = response['buyer'] as Map<String, dynamic>? ?? {};
          final seller = response['seller'] as Map<String, dynamic>? ?? {};
          final bookingList = response['bookings'] as List<dynamic>? ?? [];
          final bookingRef = bookingList.isNotEmpty
              ? (bookingList.first as Map<String, dynamic>)['booking_reference']?.toString()
              : null;

          final flat = Map<String, dynamic>.from(response);
          flat['commodity_name'] = comm['name'] ?? 'Agricultural Commodity';
          flat['grade_name'] = gr['grade_name'];
          flat['buyer_company_id'] = response['buyer_id'];
          flat['buyer_company_name'] = buyer['name'] ?? 'Buyer Enterprise';
          flat['seller_company_id'] = response['seller_id'];
          flat['seller_company_name'] = seller['name'] ?? 'Seller Enterprise';
          flat['booking_reference'] = bookingRef;

          // Check versions for confirmation state
          final versionsRes = await client
              .from('deal_versions')
              .select('version_number, status')
              .eq('request_id', dealId)
              .order('version_number', ascending: false)
              .limit(1);

          final versionList = versionsRes as List<dynamic>? ?? [];
          bool buyerConfirmed = false;
          bool sellerConfirmed = false;
          int latestVer = 1;

          if (versionList.isNotEmpty) {
            final latest = versionList.first as Map<String, dynamic>;
            latestVer = (latest['version_number'] as num?)?.toInt() ?? 1;
            final vStatus = (latest['status']?.toString() ?? '').toLowerCase();
            if (vStatus.contains('buyer confirmed')) buyerConfirmed = true;
            if (vStatus.contains('seller confirmed')) sellerConfirmed = true;
          }

          flat['latestVersionNumber'] = latestVer;
          flat['buyerConfirmed'] = buyerConfirmed;
          flat['sellerConfirmed'] = sellerConfirmed;

          return DealSuccess(DealDetailItem.fromJson(flat));
        }
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
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        final response = await client
            .from('requirement_allocations')
            .select(
              'id, allocation_reference, requirement_id, availability_id, broker_id, deal_id, '
              'allocated_quantity, unit_id, price_basis, allocated_price, status, notes, '
              'release_reason, version, allocated_at, confirmed_at, released_at, '
              'master_units(id, name, symbol), '
              'availabilities!inner(id, lot_number, seller_id, companies!seller_id(id, name, is_verified))',
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
            flat['seller_company_id'] = seller['id'] ?? avail['seller_id'];
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
      final msg = dioErr.response?.data?['error']?.toString() ?? dioErr.message;
      debugPrint('REST propose allocation error: $msg');
    } catch (e) {
      debugPrint('REST propose allocation error: $e');
    }

    // 2. Direct Supabase PostgREST insertion fallback
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        final brokerId = session.user.id;
        final timestampStr = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
        final refCode = 'ALC-$timestampStr';

        // Resolve unit_id from requirement
        final reqRes = await client
            .from('requirements')
            .select('unit_id, master_units(id, name, symbol)')
            .eq('id', dto.requirementId)
            .maybeSingle();

        final unitId = reqRes?['unit_id']?.toString() ?? '';
        final unitObj = reqRes?['master_units'] as Map<String, dynamic>? ?? {};

        final insertRes = await client
            .from('requirement_allocations')
            .insert({
              'allocation_reference': refCode,
              'requirement_id': dto.requirementId,
              'availability_id': dto.availabilityId,
              'broker_id': brokerId,
              'allocated_quantity': dto.proposedQuantity,
              'unit_id': unitId,
              'price_basis': dto.priceBasis,
              'allocated_price': dto.agreedPrice,
              'status': 'CONFIRMED', // Immediately confirmed when broker commits
              'notes': dto.notes,
              'version': 1,
            })
            .select()
            .single();

        final flat = Map<String, dynamic>.from(insertRes);
        flat['unit_name'] = unitObj['name'] ?? 'Metric Tonne';
        flat['unit_symbol'] = unitObj['symbol'] ?? dto.unitSymbol;
        flat['seller_company_name'] = 'Allocated Seller Lot';

        return DealSuccess(AllocationItem.fromJson(flat));
      }
    } catch (supabaseErr) {
      debugPrint('Supabase propose allocation error: $supabaseErr');
      return DealError(message: 'Failed to record allocation: $supabaseErr');
    }

    return const DealContractPending(
      contractNotice: 'Allocation proposal service is currently unavailable.',
    );
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
      final msg = dioErr.response?.data?['error']?.toString() ?? dioErr.message;
      debugPrint('REST create deal error: $msg');
    } catch (e) {
      debugPrint('REST create deal error: $e');
    }

    // 2. Direct Supabase PostgREST transaction fallback
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        final brokerId = session.user.id;

        // Fetch allocation
        final allocRes = await client
            .from('requirement_allocations')
            .select(
              'id, requirement_id, availability_id, allocated_quantity, allocated_price, '
              'requirements(id, company_id, commodity_id, master_commodities(name)), '
              'availabilities(id, seller_id, companies!seller_id(name))',
            )
            .eq('id', dto.allocationId)
            .maybeSingle();

        if (allocRes == null) {
          return const DealError(message: 'Allocation record not found for deal creation');
        }

        final req = allocRes['requirements'] as Map<String, dynamic>? ?? {};
        final avail = allocRes['availabilities'] as Map<String, dynamic>? ?? {};
        final buyerId = req['company_id']?.toString() ?? '';
        final sellerId = avail['seller_id']?.toString() ?? '';
        final comm = req['master_commodities'] as Map<String, dynamic>? ?? {};
        final sellerCo = avail['companies'] as Map<String, dynamic>? ?? {};

        // Create baseline quotation placeholder
        final quoteRes = await client
            .from('quotations')
            .insert({
              'requirement_id': allocRes['requirement_id'],
              'broker_id': brokerId,
              'seller_availability_id': allocRes['availability_id'],
              'offered_price': dto.agreedPrice,
              'status': 'Accepted',
              'valid_until': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            })
            .select()
            .single();

        final quotationId = quoteRes['id'];

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
            'agreedPrice': dto.agreedPrice,
            'agreedQuantity': dto.agreedQuantity,
            'deliveryLocation': dto.deliveryLocation,
            'deliveryDate': dto.deliveryDate.toIso8601String(),
            'deliveryTerms': dto.deliveryTerms,
            'paymentTerms': dto.paymentTerms,
            'packagingType': dto.packagingType,
            'brokerCommissionRate': dto.brokerCommissionRate,
          },
        });

        // Update allocation to COMMITTED_TO_DEAL with dealId
        await client
            .from('requirement_allocations')
            .update({
              'status': 'COMMITTED_TO_DEAL',
              'deal_id': dealId,
            })
            .eq('id', dto.allocationId);

        final flat = Map<String, dynamic>.from(dealRes);
        flat['commodity_name'] = comm['name'] ?? 'Agricultural Commodity';
        flat['buyer_company_id'] = buyerId;
        flat['buyer_company_name'] = 'Authorized Buyer Mandate';
        flat['seller_company_id'] = sellerId;
        flat['seller_company_name'] = sellerCo['name'] ?? 'Authorized Seller Lot';
        flat['unit_symbol'] = 'MT';
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
      if (client != null) {
        await client.from('deals').update({'status': 'Cancelled'}).eq('id', dealId);

        // Release linked allocations back to inventory
        await client
            .from('requirement_allocations')
            .update({
              'status': 'RELEASED',
              'release_reason': 'Deal cancelled: $reason',
              'released_at': DateTime.now().toIso8601String(),
            })
            .eq('deal_id', dealId);

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
            .select('id, request_id, version_number, status, actor_id, created_at, snapshot_payload, change_reason')
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
      final msg = dioErr.response?.data?['error']?.toString() ?? dioErr.message;
      debugPrint('REST update deal terms error: $msg');
    } catch (e) {
      debugPrint('REST update deal terms error: $e');
    }

    // 2. Direct Supabase PostgREST versioning fallback
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        final brokerId = session.user.id;

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
        String? previousVerId;

        if (rawList.isNotEmpty) {
          final top = rawList.first as Map<String, dynamic>;
          currentVer = (top['version_number'] as num?)?.toInt() ?? 1;
          oldSnapshot = top['snapshot_payload'] as Map<String, dynamic>?;
          previousVerId = top['id']?.toString();
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

        // Invalidate prior version
        if (previousVerId != null) {
          await client.from('deal_versions').update({
            'status': 'Superseded',
          }).eq('id', previousVerId);
        }

        // Reset confirmations to false for the new version
        newSnapshot['buyerConfirmed'] = false;
        newSnapshot['sellerConfirmed'] = false;

        // Insert new version
        await client.from('deal_versions').insert({
          'request_id': dto.dealId,
          'version_number': nextVersionNumber,
          'status': 'Negotiation',
          'actor_id': brokerId,
          'snapshot_payload': newSnapshot,
          'change_reason': dto.reason ?? 'Broker proposed terms revision to v$nextVersionNumber',
        });

        // Update deals record
        await client.from('deals').update({
          'agreed_price': dto.agreedPrice,
          'agreed_quantity': dto.agreedQuantity,
          'status': 'Negotiation',
        }).eq('id', dto.dealId);

        // Record audit event in negotiation_events if table exists
        try {
          await client.from('negotiation_events').insert({
            'deal_id': dto.dealId,
            'actor_id': brokerId,
            'event_type': 'TERMS_AMENDED',
            'version_number': nextVersionNumber,
            'notes': dto.reason ?? 'Terms amended to v$nextVersionNumber',
          });
        } catch (_) {}

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
      final msg = dioErr.response?.data?['error']?.toString() ?? dioErr.message;
      debugPrint('REST party confirmation error: $msg');
    } catch (e) {
      debugPrint('REST party confirmation error: $e');
    }

    // 2. Direct Supabase PostgREST confirmation fallback
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        final brokerId = session.user.id;

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

        final snapshot = Map<String, dynamic>.from(
          top['snapshot_payload'] as Map<String, dynamic>? ?? {},
        );
        final nowIso = DateTime.now().toIso8601String();

        if (dto.party == 'BUYER') {
          snapshot['buyerConfirmed'] = true;
          snapshot['buyerConfirmedAt'] = nowIso;
          if (dto.verificationNotes != null) {
            snapshot['buyerVerificationNotes'] = dto.verificationNotes;
          }
        } else {
          snapshot['sellerConfirmed'] = true;
          snapshot['sellerConfirmedAt'] = nowIso;
          if (dto.verificationNotes != null) {
            snapshot['sellerVerificationNotes'] = dto.verificationNotes;
          }
        }

        final buyerConf = snapshot['buyerConfirmed'] == true;
        final sellerConf = snapshot['sellerConfirmed'] == true;
        final canFinalize = buyerConf && sellerConf;

        String nextStatus = 'Negotiation';
        if (canFinalize) {
          nextStatus = 'Ready to Finalize';
        } else if (buyerConf) {
          nextStatus = 'Awaiting Seller Confirmation';
        } else if (sellerConf) {
          nextStatus = 'Awaiting Buyer Confirmation';
        }

        // Update deal_versions
        await client.from('deal_versions').update({
          'snapshot_payload': snapshot,
          'status': nextStatus,
        }).eq('id', top['id']);

        // Update deals record status
        await client.from('deals').update({
          'status': nextStatus,
        }).eq('id', dto.dealId);

        // Record audit event in negotiation_events if table exists
        try {
          await client.from('negotiation_events').insert({
            'deal_id': dto.dealId,
            'actor_id': brokerId,
            'event_type': '${dto.party}_CONFIRMED',
            'version_number': currentVer,
            'notes': dto.verificationNotes ?? 'Formal ${dto.party} acceptance recorded by broker',
          });
        } catch (_) {}

        return DealSuccess(
          DealConfirmationState(
            latestVersionNumber: currentVer,
            buyerConfirmed: buyerConf,
            buyerConfirmedAt: snapshot['buyerConfirmedAt'] != null
                ? DateTime.tryParse(snapshot['buyerConfirmedAt'].toString())
                : null,
            sellerConfirmed: sellerConf,
            sellerConfirmedAt: snapshot['sellerConfirmedAt'] != null
                ? DateTime.tryParse(snapshot['sellerConfirmedAt'].toString())
                : null,
            canFinalize: canFinalize,
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
      final msg = dioErr.response?.data?['error']?.toString() ?? dioErr.message;
      debugPrint('REST finalize deal error: $msg');
    } catch (e) {
      debugPrint('REST finalize deal error: $e');
    }

    // 2. Direct Supabase PostgREST finalization fallback
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        final brokerId = session.user.id;

        // Check deal status
        final dealRes = await client
            .from('deals')
            .select('id, status, agreed_price, agreed_quantity, quotation_id')
            .eq('id', dealId)
            .maybeSingle();

        if (dealRes == null) {
          return const DealError(message: 'Deal record not found');
        }

        final currentStatus = dealRes['status']?.toString();
        if (currentStatus == 'Finalized' || currentStatus == 'Completed') {
          return const DealError(message: 'Deal is already finalized and cannot be re-finalized');
        }
        if (currentStatus == 'Cancelled' || currentStatus == 'Disputed') {
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

        final snapshot = top['snapshot_payload'] as Map<String, dynamic>? ?? {};
        final buyerConf = snapshot['buyerConfirmed'] == true;
        final sellerConf = snapshot['sellerConfirmed'] == true;

        // CRITICAL INVARIANT: PRE-FLIGHT GATE REQUIRES BOTH PARTIES CONFIRMED
        if (!buyerConf || !sellerConf) {
          return DealError(
            message:
                'PRE_FLIGHT_BLOCKED: Finalization requires verified confirmation from BOTH Buyer and Seller on Version $currentVer. (Buyer: ${buyerConf ? "Confirmed" : "Pending"}, Seller: ${sellerConf ? "Confirmed" : "Pending"})',
            code: 'PRE_FLIGHT_BLOCKED',
          );
        }

        // Generate enterprise booking reference BKG-YYYY-XXXX
        final randomCode = DateTime.now().millisecondsSinceEpoch.toString().substring(9);
        final bookingRef = 'BKG-${DateTime.now().year}-$randomCode';

        // Insert booking record
        await client.from('bookings').insert({
          'deal_id': dealId,
          'booking_reference': bookingRef,
          'status': 'Confirmed',
          'broker_id': brokerId,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Freeze latest deal_version status to 'Broker Finalized'
        await client.from('deal_versions').update({
          'status': 'Broker Finalized',
        }).eq('id', top['id']);

        // Update deals record to Finalized
        await client.from('deals').update({
          'status': 'Finalized',
          'closed_at': DateTime.now().toIso8601String(),
        }).eq('id', dealId);

        // Record audit event in negotiation_events if table exists
        try {
          await client.from('negotiation_events').insert({
            'deal_id': dealId,
            'actor_id': brokerId,
            'event_type': 'DEAL_FINALIZED',
            'version_number': currentVer,
            'notes': 'Authoritative contract finalization locked with booking reference $bookingRef',
          });
        } catch (_) {}

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
}
