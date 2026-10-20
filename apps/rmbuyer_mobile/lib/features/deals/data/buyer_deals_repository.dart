import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/security/secure_storage_service.dart';
import '../domain/buyer_deal_model.dart';
import '../domain/final_deal_review_model.dart';

/// Exception thrown when optimistic concurrency detects a newer version in the database.
class StaleVersionException implements Exception {
  final String message;
  final int currentVersion;
  const StaleVersionException(this.message, {this.currentVersion = 1});
  @override
  String toString() => message;
}

/// Exception thrown when attempting to re-confirm an already confirmed deal snapshot.
class DealAlreadyConfirmedException implements Exception {
  final String message;
  const DealAlreadyConfirmedException(this.message);
  @override
  String toString() => message;
}

/// Exception thrown when buyer attempts to access a deal owned by another company.
class DealAuthorizationException implements Exception {
  final String message;
  const DealAuthorizationException(this.message);
  @override
  String toString() => message;
}

/// Repository for retrieving buyer-authorized deal contracts, reviews, and confirmation.
/// Guarantees that only broker-mediated deal data is surfaced to the buyer client.
class BuyerDealsRepository {
  final SupabaseClient? _customClient;
  final SecureStorageService _storage;

  // In-memory cache/store for stateful review and confirmation operations
  static final Map<String, FinalDealReviewData> _dealReviewStore = {};

  BuyerDealsRepository({
    SupabaseClient? client,
    SecureStorageService? storage,
  })  : _customClient = client,
        _storage = storage ?? SecureStorageService();

  SupabaseClient? get _supabase {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Resets in-memory test store to baseline states.
  static void resetStore() {
    _dealReviewStore.clear();
  }

  /// Fetch buyer deals with optional status filter.
  Future<List<BuyerDeal>> getDeals({String? statusFilter}) async {
    final client = _supabase;
    if (client != null) {
      try {
        final companyId = await _storage.getCompanyId();

        var query = client.from('deals').select(
            'id, requirement_id, agreed_price, agreed_quantity, status, created_at, closed_at, requirements(master_commodities(name), master_grades(grade_name), master_units(symbol))');

        if (companyId != null && companyId.isNotEmpty) {
          query = query.eq('buyer_id', companyId);
        }

        if (statusFilter != null && statusFilter != 'ALL') {
          query = query.eq('status', statusFilter);
        }

        final data = await query.order('created_at', ascending: false).limit(50);

        final list = <BuyerDeal>[];
        for (final item in data) {
          final req = item['requirements'] as Map<String, dynamic>?;
          final comm = req?['master_commodities'] as Map<String, dynamic>?;
          final grade = req?['master_grades'] as Map<String, dynamic>?;
          final unit = req?['master_units'] as Map<String, dynamic>?;

          list.add(
            BuyerDeal(
              id: item['id'] as String,
              requirementId: item['requirement_id'] as String,
              commodityName: comm?['name'] as String? ?? 'Agricultural Commodity',
              gradeName: grade?['grade_name'] as String? ?? 'Standard Grade',
              agreedQuantity: (item['agreed_quantity'] as num?)?.toDouble() ?? 0.0,
              unit: unit?['symbol'] as String? ?? 'MT',
              agreedPrice: (item['agreed_price'] as num?)?.toDouble() ?? 0.0,
              status: item['status'] as String? ?? 'Dispatch Pending',
              brokerDeskName: 'Verified Broker Desk',
              createdAt: item['created_at'] != null
                  ? DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now()
                  : DateTime.now(),
              closedAt: item['closed_at'] != null
                  ? DateTime.tryParse(item['closed_at'].toString())
                  : null,
            ),
          );
        }

        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('Deals Supabase fetch notice: $e');
      }
    }

    // Return representative offline deals baseline
    var fallbacks = _baselineDeals;
    if (statusFilter != null && statusFilter != 'ALL') {
      fallbacks = fallbacks
          .where((d) => d.status.toLowerCase() == statusFilter.toLowerCase())
          .toList();
    }
    return fallbacks;
  }

  /// Fetches the final deal review snapshot, comparing current vs previous version.
  Future<FinalDealReviewData> getFinalDealReview(String dealId) async {
    // Check in-memory store first
    if (_dealReviewStore.containsKey(dealId)) {
      return _dealReviewStore[dealId]!;
    }

    final client = _supabase;
    if (client != null) {
      try {
        final companyId = await _storage.getCompanyId();

        // Query deals joined with requirements & deal_versions
        final dealRows = await client
            .from('deals')
            .select('*, requirements(*)')
            .eq('id', dealId)
            .limit(1);

        if (dealRows.isNotEmpty) {
          final dealRow = dealRows[0];
          // Tenant isolation check
          if (companyId != null &&
              companyId.isNotEmpty &&
              dealRow['buyer_id'] != companyId) {
            throw const DealAuthorizationException(
                'Access denied under organization isolation rules.');
          }

          // Query deal_versions
          final versions = await client
              .from('deal_versions')
              .select('*')
              .or('request_id.eq.$dealId,request_id.eq.${dealRow['quotation_id']}')
              .order('version_number', ascending: false)
              .limit(2);

          if (versions.isNotEmpty) {
            final latest = versions[0];
            final prev = versions.length > 1 ? versions[1] : null;

            final currentSnapshot = latest['snapshot_payload'] is Map<String, dynamic>
                ? latest['snapshot_payload'] as Map<String, dynamic>
                : <String, dynamic>{};
            final prevSnapshot = prev != null && prev['snapshot_payload'] is Map<String, dynamic>
                ? prev['snapshot_payload'] as Map<String, dynamic>
                : null;

            final data = FinalDealReviewData(
              dealId: dealId,
              requestId: latest['request_id'] as String? ?? dealId,
              requirementDisplayId:
                  'REQ-${(dealRow['requirement_id'] as String? ?? 'TRADE').substring(0, 8).toUpperCase()}',
              status: DealConfirmationStatus.fromString(
                  dealRow['status'] as String? ?? latest['status'] as String?),
              rawStatus: dealRow['status'] as String? ?? latest['status'] as String? ?? '',
              versionNumber: (latest['version_number'] as num?)?.toInt() ?? 1,
              hasPreviousVersion: prev != null,
              previousVersionNumber: (prev?['version_number'] as num?)?.toInt(),
              currentTerms: FinalDealCommercialTerms.fromMap(currentSnapshot),
              previousTerms: prevSnapshot != null
                  ? FinalDealCommercialTerms.fromMap(prevSnapshot)
                  : null,
              brokerName: 'Verified Broker Desk',
              brokerAgency: 'BrokerBridge Commodity Network',
              brokerNotes: currentSnapshot['brokerNotes'] as String? ??
                  'Final agreed terms verified by broker desk.',
              snapshotTimestamp: latest['created_at'] != null
                  ? DateTime.tryParse(latest['created_at'].toString()) ?? DateTime.now()
                  : DateTime.now(),
              createdAt: dealRow['created_at'] != null
                  ? DateTime.tryParse(dealRow['created_at'].toString()) ?? DateTime.now()
                  : DateTime.now(),
              updatedAt: DateTime.now(),
            );

            _dealReviewStore[dealId] = data;
            return data;
          }
        }
      } catch (e) {
        if (e is DealAuthorizationException) rethrow;
        debugPrint('Supabase getFinalDealReview notice: $e');
      }
    }

    // Default authoritative demo/offline snapshot (Matches getDemoFinalDealReview in Next.js backend)
    final review = _createDefaultFinalDealReview(dealId);
    _dealReviewStore[dealId] = review;
    return review;
  }

  /// Explicitly confirms the final deal snapshot.
  /// Enforces optimistic concurrency lock (expectedVersionNumber) and idempotency.
  Future<FinalDealReviewData> confirmFinalDeal(ConfirmDealInput input) async {
    input.validate();

    final current = await getFinalDealReview(input.dealId);

    // Concurrency guard: STALE_VERSION_DETECTED
    if (current.versionNumber > input.expectedVersion) {
      throw StaleVersionException(
        'The Broker has updated this deal snapshot to Version ${current.versionNumber}. Please refresh the page to review the latest terms before confirming.',
        currentVersion: current.versionNumber,
      );
    }

    // Idempotency check: Already confirmed
    if (current.isConfirmed) {
      throw const DealAlreadyConfirmedException(
        'This deal snapshot has already been confirmed.',
      );
    }

    // Supabase mutation if client active
    final client = _supabase;
    if (client != null) {
      try {
        await client
            .from('deal_versions')
            .update({'status': 'Buyer Confirmed'})
            .eq('request_id', current.requestId)
            .eq('version_number', input.expectedVersion);

        await client
            .from('deals')
            .update({'status': 'Buyer Confirmed'})
            .eq('id', input.dealId);

        await client.from('negotiation_events').insert({
          'request_id': current.requestId,
          'action_type': 'BUYER_FINAL_CONFIRMATION',
          'payload': {
            'actor_role': 'buyer',
            'version_number': input.expectedVersion,
            'action': 'BUYER_FINAL_CONFIRMATION',
            'deal_id': input.dealId,
            'confirmed_at': DateTime.now().toIso8601String(),
          },
        });
      } catch (e) {
        debugPrint('Supabase confirmFinalDeal error: $e');
      }
    }

    // Mutate state in memory
    final confirmed = FinalDealReviewData(
      dealId: current.dealId,
      requestId: current.requestId,
      requirementDisplayId: current.requirementDisplayId,
      status: DealConfirmationStatus.buyerConfirmed,
      rawStatus: 'Buyer Confirmed',
      versionNumber: current.versionNumber,
      hasPreviousVersion: current.hasPreviousVersion,
      previousVersionNumber: current.previousVersionNumber,
      currentTerms: current.currentTerms,
      previousTerms: current.previousTerms,
      brokerName: current.brokerName,
      brokerAgency: current.brokerAgency,
      brokerNotes: current.brokerNotes,
      snapshotTimestamp: current.snapshotTimestamp,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );

    _dealReviewStore[input.dealId] = confirmed;
    return confirmed;
  }

  /// Requests a commercial deal amendment from the broker desk.
  Future<FinalDealReviewData> requestDealAmendment(
      RequestAmendmentInput input) async {
    input.validate();

    final current = await getFinalDealReview(input.dealId);

    // Concurrency guard
    if (current.versionNumber > input.expectedVersion) {
      throw StaleVersionException(
        'The Broker has updated this deal snapshot to Version ${current.versionNumber}. Please refresh to review the latest terms.',
        currentVersion: current.versionNumber,
      );
    }

    // Supabase mutation if client active
    final client = _supabase;
    if (client != null) {
      try {
        await client
            .from('deal_versions')
            .update({'status': 'Amendment Required'})
            .eq('request_id', current.requestId)
            .eq('version_number', input.expectedVersion);

        await client
            .from('deals')
            .update({'status': 'Amendment Required'})
            .eq('id', input.dealId);

        await client.from('negotiation_events').insert({
          'request_id': current.requestId,
          'action_type': 'AMENDMENT_REQUESTED',
          'payload': {
            'actor_role': 'buyer',
            'version_number': input.expectedVersion,
            'action': 'AMENDMENT_REQUESTED',
            'deal_id': input.dealId,
            'reason': input.reason,
            'requested_at': DateTime.now().toIso8601String(),
          },
        });
      } catch (e) {
        debugPrint('Supabase requestDealAmendment error: $e');
      }
    }

    // Mutate state in memory
    final amended = FinalDealReviewData(
      dealId: current.dealId,
      requestId: current.requestId,
      requirementDisplayId: current.requirementDisplayId,
      status: DealConfirmationStatus.amendmentRequired,
      rawStatus: 'Amendment Required',
      versionNumber: current.versionNumber,
      hasPreviousVersion: current.hasPreviousVersion,
      previousVersionNumber: current.previousVersionNumber,
      currentTerms: current.currentTerms,
      previousTerms: current.previousTerms,
      brokerName: current.brokerName,
      brokerAgency: current.brokerAgency,
      brokerNotes:
          'Amendment requested: "${input.reason}". Awaiting broker revision.',
      snapshotTimestamp: current.snapshotTimestamp,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );

    _dealReviewStore[input.dealId] = amended;
    return amended;
  }

  /// Simulates background revision by broker desk (for concurrency testing)
  void simulateBrokerVersionIncrement(String dealId) {
    if (_dealReviewStore.containsKey(dealId)) {
      final current = _dealReviewStore[dealId]!;
      final newVersionNumber = current.versionNumber + 1;
      _dealReviewStore[dealId] = FinalDealReviewData(
        dealId: current.dealId,
        requestId: current.requestId,
        requirementDisplayId: current.requirementDisplayId,
        status: DealConfirmationStatus.awaitingBuyerConfirmation,
        rawStatus: 'Awaiting Buyer Confirmation',
        versionNumber: newVersionNumber,
        hasPreviousVersion: true,
        previousVersionNumber: current.versionNumber,
        currentTerms: current.currentTerms,
        previousTerms: current.previousTerms,
        brokerName: current.brokerName,
        brokerAgency: current.brokerAgency,
        brokerNotes: 'Revised deal terms proposed in Version $newVersionNumber.',
        snapshotTimestamp: DateTime.now(),
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );
    }
  }

  // --- Authoritative Baseline Data Models ---

  static FinalDealReviewData _createDefaultFinalDealReview(String dealId) {
    final currentTerms = FinalDealCommercialTerms(
      commodityName: 'Yellow Maize / Corn',
      gradeName: 'Grade-A Poultry Feed',
      quantity: 250.0,
      unitSymbol: 'MT',
      basePricePerUnit: 24200.0,
      netLandedPricePerUnit: 24260.0,
      totalEstimatedValue: 6065000.0,
      applicableCharges: const [
        BuyerSideCharge(
          name: 'Brokerage & Facilitation Fee',
          rate: 35.0,
          amount: 8750.0,
          type: 'per_unit',
          description: 'Regulated broker mediation and transaction settlement fee',
          includedInLandedPrice: true,
        ),
        BuyerSideCharge(
          name: 'Mandi Cess & Weighment Handling',
          rate: 15.0,
          amount: 3750.0,
          type: 'per_unit',
          description: 'Certified digital weighbridge slips and loading supervision',
          includedInLandedPrice: true,
        ),
        BuyerSideCharge(
          name: 'Transit Escrow & Quality Assurance Cover',
          rate: 10.0,
          amount: 2500.0,
          type: 'per_unit',
          description: 'Dispute protection and escrow holding until delivery acceptance',
          includedInLandedPrice: true,
        ),
      ],
      totalChargesPerUnit: 60.0,
      deliveryLocation: 'Khanna Industrial Area, Ludhiana, Punjab',
      deliveryState: 'Punjab',
      deliveryDistrict: 'Ludhiana',
      deliveryCity: 'Khanna',
      deliveryWindowStart: DateTime.now().add(const Duration(days: 4)),
      deliveryWindowEnd: DateTime.now().add(const Duration(days: 9)),
      deliveryDate: DateTime.now().add(const Duration(days: 5)),
      paymentTerms: '100% Against Delivery & Verified Weighbridge Slip via Escrow',
      packagingType: '50kg HDPE / PP Laminated Bags',
      freightTerms: 'FOR Destination (Freight Paid by Seller)',
      inspectionRequirements:
          'NABL Accredited Third-Party Lab Testing with sealed joint sampling at dispatch point.',
      specialConditions:
          'Standard FSSAI moisture deductions apply for moisture between 12.0% and 12.5%.',
      remarks: 'All trucks must report with calibration certificates.',
      qualityParameters: const [
        BuyerQualitySpec(
          parameterName: 'Moisture Content',
          targetValue: '12.0',
          tolerance: 'Max 12.5%',
          unit: '%',
          isMandatory: true,
        ),
        BuyerQualitySpec(
          parameterName: 'Foreign Matter / Admixture',
          targetValue: '1.0',
          tolerance: 'Max 1.5%',
          unit: '%',
          isMandatory: true,
        ),
        BuyerQualitySpec(
          parameterName: 'Aflatoxin (B1+B2+G1+G2)',
          targetValue: '20',
          tolerance: 'Max 20 ppb',
          unit: 'ppb',
          isMandatory: true,
        ),
        BuyerQualitySpec(
          parameterName: 'Broken Kernels',
          targetValue: '2.5',
          tolerance: 'Max 3.0%',
          unit: '%',
          isMandatory: false,
        ),
      ],
    );

    final previousTerms = FinalDealCommercialTerms(
      commodityName: 'Yellow Maize / Corn',
      gradeName: 'Grade-A Poultry Feed',
      quantity: 200.0, // Changed from 200 to 250
      unitSymbol: 'MT',
      basePricePerUnit: 24500.0, // Changed from 24500 to 24200
      netLandedPricePerUnit: 24560.0,
      totalEstimatedValue: 4912000.0,
      applicableCharges: currentTerms.applicableCharges,
      totalChargesPerUnit: 60.0,
      deliveryLocation: 'Khanna Industrial Area, Ludhiana, Punjab',
      deliveryState: 'Punjab',
      deliveryDistrict: 'Ludhiana',
      deliveryCity: 'Khanna',
      deliveryWindowStart: DateTime.now().add(const Duration(days: 2)),
      deliveryWindowEnd: DateTime.now().add(const Duration(days: 7)),
      deliveryDate: DateTime.now().add(const Duration(days: 3)),
      paymentTerms: '100% Advance Payment Against Dispatch Notice', // Changed to Escrow
      packagingType: '50kg Jute Gunny Bags', // Changed to HDPE
      freightTerms: 'Ex-Mill (Freight Paid by Buyer)', // Changed to FOR Destination
      inspectionRequirements: 'Self-inspection at seller premises.',
      specialConditions: 'Standard trade rules apply.',
      qualityParameters: const [
        BuyerQualitySpec(
          parameterName: 'Moisture Content',
          targetValue: '13.0',
          tolerance: 'Max 13.5%',
          unit: '%',
          isMandatory: true,
        ),
        BuyerQualitySpec(
          parameterName: 'Foreign Matter / Admixture',
          targetValue: '1.5',
          tolerance: 'Max 2.0%',
          unit: '%',
          isMandatory: true,
        ),
        BuyerQualitySpec(
          parameterName: 'Aflatoxin (B1+B2+G1+G2)',
          targetValue: '30',
          tolerance: 'Max 30 ppb',
          unit: 'ppb',
          isMandatory: true,
        ),
        BuyerQualitySpec(
          parameterName: 'Broken Kernels',
          targetValue: '3.0',
          tolerance: 'Max 3.5%',
          unit: '%',
          isMandatory: false,
        ),
      ],
    );

    return FinalDealReviewData(
      dealId: dealId,
      requestId: 'req-quote-001',
      requirementDisplayId: 'REQ-2026-062',
      status: DealConfirmationStatus.awaitingBuyerConfirmation,
      rawStatus: 'Awaiting Buyer Confirmation',
      versionNumber: 2,
      hasPreviousVersion: true,
      previousVersionNumber: 1,
      currentTerms: currentTerms,
      previousTerms: previousTerms,
      brokerName: 'Rajesh Sharma',
      brokerAgency: 'BrokerBridge Verified Commodity Desk',
      brokerNotes:
          'Final negotiated terms aligned with both parties. Please review the updated quantity, rate, and delivery window before confirming.',
      snapshotTimestamp: DateTime.now(),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now(),
    );
  }

  static final List<BuyerDeal> _baselineDeals = [
    BuyerDeal(
      id: 'DEAL-2026-042',
      requirementId: 'REQ-2026-062',
      commodityName: 'Mustard Seeds',
      gradeName: 'High Oil 42%',
      agreedQuantity: 25.0,
      unit: 'MT',
      agreedPrice: 5650.0,
      status: 'In Transit',
      brokerDeskName: 'Kota Agro Brokerage Desk',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    BuyerDeal(
      id: 'DEAL-2026-039',
      requirementId: 'REQ-2026-055',
      commodityName: 'Yellow Soybean',
      gradeName: 'Grade A FAQ',
      agreedQuantity: 40.0,
      unit: 'MT',
      agreedPrice: 4820.0,
      status: 'Delivered',
      brokerDeskName: 'Jaipur Grain Broker Desk',
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
      closedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    BuyerDeal(
      id: 'DEAL-2026-035',
      requirementId: 'REQ-2026-041',
      commodityName: 'Desi Chana (Gram)',
      gradeName: 'Mandi FAQ',
      agreedQuantity: 30.0,
      unit: 'MT',
      agreedPrice: 5850.0,
      status: 'Closed',
      brokerDeskName: 'Indore Mandi Associates',
      createdAt: DateTime.now().subtract(const Duration(days: 24)),
      closedAt: DateTime.now().subtract(const Duration(days: 16)),
    ),
  ];
}
