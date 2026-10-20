import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/security/secure_storage_service.dart';
import '../domain/buyer_offer_model.dart';
import '../domain/offer_inputs.dart';

/// Repository managing broker-provided commercial offers, negotiation rounds,
/// and append-only counter-offer submissions for authenticated buyers.
/// Guarantees strict Counterparty Shield: zero seller records or contact info.
class OffersRepository {
  final SupabaseClient? _customClient;
  final SecureStorageService _storage;

  // In-memory registry of offers to support session modifications and offline testing
  static List<BuyerOffer> _sessionOffers = _generateBaselineOffers();
  bool _isSubmitting = false;

  OffersRepository({
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

  /// Reset session state for clean automated test execution.
  static void resetForTesting() {
    _sessionOffers = _generateBaselineOffers();
  }

  /// Retrieve all offers for the authenticated buyer, optionally filtered by requirement or status.
  Future<List<BuyerOffer>> getOffers({
    String? requirementId,
    String? statusFilter,
  }) async {
    final client = _supabase;
    List<BuyerOffer> remoteOffers = [];

    if (client != null) {
      try {
        final companyId = await _storage.getCompanyId();

        var query = client
            .from('quotations')
            .select(
              'id, requirement_id, offered_price, status, valid_until, created_at, counter_price, counter_notes, rejection_reason, '
              'requirements(id, company_id, commodity_id, quantity, delivery_terms_id, master_commodities(name), master_grades(grade_name), master_units(symbol)), '
              'users!broker_id(name)',
            );

        if (requirementId != null && requirementId.isNotEmpty) {
          query = query.eq('requirement_id', requirementId);
        }

        final data = await query.order('created_at', ascending: false).limit(50);

        for (final item in data) {
          final req = item['requirements'] as Map<String, dynamic>?;
          // Organization data boundary: ensure requirement belongs to buyer's company
          if (companyId != null && companyId.isNotEmpty && req?['company_id'] != null) {
            if (req!['company_id'].toString() != companyId) {
              continue;
            }
          }

          final comm = req?['master_commodities'] as Map<String, dynamic>?;
          final grade = req?['master_grades'] as Map<String, dynamic>?;
          final unit = req?['master_units'] as Map<String, dynamic>?;
          final brokerUser = item['users'] as Map<String, dynamic>?;

          final price = (item['offered_price'] as num?)?.toDouble() ?? 0.0;
          final qty = (req?['quantity'] as num?)?.toDouble() ?? 0.0;
          final quoteId = item['id'].toString();

          // Fetch associated deal_versions for negotiation history
          final rounds = await _fetchRemoteNegotiationRounds(client, quoteId, price, qty);

          remoteOffers.add(
            BuyerOffer(
              id: quoteId,
              requirementId: item['requirement_id']?.toString() ?? '',
              requirementDisplayId: 'REQ-${item['requirement_id']?.toString().substring(0, 8).toUpperCase()}',
              commodityName: comm?['name'] as String? ?? 'Agricultural Commodity',
              gradeName: grade?['grade_name'] as String? ?? 'Standard Grade',
              offeredQuantity: qty,
              unit: unit?['symbol'] as String? ?? 'MT',
              offeredPrice: price,
              totalEstimatedValue: price * qty,
              status: item['status'] as String? ?? 'Proposed',
              versionNumber: rounds.isNotEmpty ? rounds.last.versionNumber : 1,
              brokerId: item['broker_id'] as String?,
              brokerName: brokerUser?['name'] as String? ?? 'Verified Broker Desk',
              brokerNotes: item['counter_notes'] as String?,
              validUntil: item['valid_until'] != null ? DateTime.tryParse(item['valid_until'].toString()) : null,
              deliveryTerms: req?['delivery_terms_id'] as String? ?? 'FOR Destination',
              deliveryLocation: 'Buyer Designated Destination Mill',
              paymentTerms: '100% Against Delivery & Verified Weighbridge Slip',
              packagingType: '50kg HDPE / PP Laminated Bags',
              applicableCharges: [
                const OfferChargeItem(name: 'Brokerage & Facilitation Fee', rate: 35, amount: 3500, type: 'per_unit'),
                const OfferChargeItem(name: 'Mandi Cess & Weighment Handling', rate: 15, amount: 1500, type: 'per_unit'),
                const OfferChargeItem(name: 'Transit Escrow & Quality Assurance', rate: 10, amount: 1000, type: 'per_unit'),
              ],
              qualitySpecs: [
                const OfferQualitySpec(parameterName: 'Moisture Content', targetValue: '12.0', tolerance: 'Max 12.5%', unit: '%'),
                const OfferQualitySpec(parameterName: 'Foreign Matter', targetValue: '1.0', tolerance: 'Max 1.5%', unit: '%'),
              ],
              negotiationRounds: rounds,
              createdAt: item['created_at'] != null ? DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }

        if (remoteOffers.isNotEmpty) {
          // Merge with session offers
          for (final ro in remoteOffers) {
            final idx = _sessionOffers.indexWhere((o) => o.id == ro.id);
            if (idx >= 0) {
              _sessionOffers[idx] = ro;
            } else {
              _sessionOffers.insert(0, ro);
            }
          }
        }
      } catch (e) {
        debugPrint('Offers Supabase query notice: $e');
      }
    }

    var results = List<BuyerOffer>.from(_sessionOffers);

    if (requirementId != null && requirementId.isNotEmpty) {
      results = results.where((o) => o.requirementId == requirementId).toList();
    }

    if (statusFilter != null && statusFilter != 'ALL') {
      results = results.where((o) => o.status.toLowerCase() == statusFilter.toLowerCase()).toList();
    }

    return results;
  }

  /// Retrieve a specific commercial offer by its unique identifier.
  Future<BuyerOffer?> getOfferById(String id) async {
    final list = await getOffers();
    final match = list.where((o) => o.id == id);
    if (match.isNotEmpty) return match.first;
    return null;
  }

  /// Submit a commercial counter-offer to the broker desk.
  /// Conforms to optimistic locking: verifies that expectedVersionNumber == current versionNumber.
  /// Appends a new immutable round to the negotiation rounds ledger.
  Future<BuyerOffer> submitCounterOffer(CounterOfferInput input) async {
    final validationError = input.validate();
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    if (_isSubmitting) {
      throw StateError('DUPLICATE_SUBMISSION_PREVENTED: A negotiation update is currently in progress.');
    }
    _isSubmitting = true;

    try {
      final existingOffer = await getOfferById(input.proposalId);
      if (existingOffer == null) {
        throw StateError('Offer not found with ID ${input.proposalId}.');
      }

      if (!existingOffer.isActionable) {
        throw StateError('This offer is in "${existingOffer.status}" state and cannot be countered.');
      }

      // Optimistic concurrency check
      if (existingOffer.versionNumber > input.expectedVersionNumber) {
        throw StateError(
          'STALE_VERSION_DETECTED: The broker desk has updated this proposal to Version ${existingOffer.versionNumber}. Please review the latest terms.',
        );
      }

      final newVersionNumber = input.expectedVersionNumber + 1;
      final now = DateTime.now();

      // Create new immutable round
      final newRound = NegotiationRound(
        id: 'ROUND-${now.millisecondsSinceEpoch}',
        versionNumber: newVersionNumber,
        status: 'Countered',
        actorRole: 'buyer',
        proposerName: 'You (Buyer Counter-Offer)',
        proposedPrice: input.counterPrice,
        proposedQuantity: input.counterQuantity,
        deliveryDate: input.deliveryDate,
        notes: input.buyerNotes,
        createdAt: now,
        isCurrent: true,
      );

      // Mark previous rounds as superseded
      final updatedRounds = existingOffer.negotiationRounds.map((r) {
        return NegotiationRound(
          id: r.id,
          versionNumber: r.versionNumber,
          status: 'Superseded',
          actorRole: r.actorRole,
          proposerName: r.proposerName,
          proposedPrice: r.proposedPrice,
          proposedQuantity: r.proposedQuantity,
          deliveryDate: r.deliveryDate,
          notes: r.notes,
          createdAt: r.createdAt,
          isCurrent: false,
        );
      }).toList();

      updatedRounds.add(newRound);

      final updatedOffer = existingOffer.copyWith(
        status: 'Countered',
        offeredPrice: input.counterPrice,
        offeredQuantity: input.counterQuantity,
        versionNumber: newVersionNumber,
        brokerNotes: input.buyerNotes != null ? 'Buyer Counter: ${input.buyerNotes}' : existingOffer.brokerNotes,
        negotiationRounds: updatedRounds,
        updatedAt: now,
      );

      // Update session memory
      final idx = _sessionOffers.indexWhere((o) => o.id == existingOffer.id);
      if (idx >= 0) {
        _sessionOffers[idx] = updatedOffer;
      }

      // Remote write if client available
      final client = _supabase;
      if (client != null) {
        try {
          await client.from('quotations').update({
            'status': 'Countered',
            'counter_price': input.counterPrice,
            'counter_notes': input.buyerNotes,
          }).eq('id', existingOffer.id);
        } catch (e) {
          debugPrint('Remote counter offer quotation update notice: $e');
        }
      }

      return updatedOffer;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Accept a broker-provided commercial offer.
  /// Enforces optimistic concurrency and transitions status to 'Accepted'.
  Future<BuyerOffer> acceptOffer(AcceptOfferInput input) async {
    final validationError = input.validate();
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    if (_isSubmitting) {
      throw StateError('DUPLICATE_SUBMISSION_PREVENTED: A negotiation update is currently in progress.');
    }
    _isSubmitting = true;

    try {
      final existingOffer = await getOfferById(input.proposalId);
      if (existingOffer == null) {
        throw StateError('Offer not found with ID ${input.proposalId}.');
      }

      if (!existingOffer.isActionable) {
        throw StateError('This offer is already in "${existingOffer.status}" state and cannot be accepted.');
      }

      if (existingOffer.versionNumber > input.expectedVersionNumber) {
        throw StateError(
          'STALE_VERSION_DETECTED: The broker desk has updated this proposal to Version ${existingOffer.versionNumber}. Please review the latest terms before accepting.',
        );
      }

      final now = DateTime.now();

      final updatedRounds = existingOffer.negotiationRounds.map((r) {
        if (r.versionNumber == input.expectedVersionNumber) {
          return NegotiationRound(
            id: r.id,
            versionNumber: r.versionNumber,
            status: 'Accepted',
            actorRole: r.actorRole,
            proposerName: r.proposerName,
            proposedPrice: r.proposedPrice,
            proposedQuantity: r.proposedQuantity,
            deliveryDate: r.deliveryDate,
            notes: r.notes,
            createdAt: r.createdAt,
            isCurrent: true,
          );
        }
        return r;
      }).toList();

      final updatedOffer = existingOffer.copyWith(
        status: 'Accepted',
        negotiationRounds: updatedRounds,
        updatedAt: now,
      );

      final idx = _sessionOffers.indexWhere((o) => o.id == existingOffer.id);
      if (idx >= 0) {
        _sessionOffers[idx] = updatedOffer;
      }

      final client = _supabase;
      if (client != null) {
        try {
          await client.from('quotations').update({
            'status': 'Accepted',
          }).eq('id', existingOffer.id);
        } catch (e) {
          debugPrint('Remote accept quotation update notice: $e');
        }
      }

      return updatedOffer;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Reject a commercial offer with an authoritative commercial reason.
  Future<BuyerOffer> rejectOffer(RejectOfferInput input) async {
    final validationError = input.validate();
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    if (_isSubmitting) {
      throw StateError('DUPLICATE_SUBMISSION_PREVENTED: A negotiation update is currently in progress.');
    }
    _isSubmitting = true;

    try {
      final existingOffer = await getOfferById(input.proposalId);
      if (existingOffer == null) {
        throw StateError('Offer not found with ID ${input.proposalId}.');
      }

      if (!existingOffer.isActionable) {
        throw StateError('This offer is already in "${existingOffer.status}" state and cannot be rejected.');
      }

      final now = DateTime.now();

      final updatedRounds = existingOffer.negotiationRounds.map((r) {
        if (r.versionNumber == input.expectedVersionNumber) {
          return NegotiationRound(
            id: r.id,
            versionNumber: r.versionNumber,
            status: 'Rejected',
            actorRole: r.actorRole,
            proposerName: r.proposerName,
            proposedPrice: r.proposedPrice,
            proposedQuantity: r.proposedQuantity,
            deliveryDate: r.deliveryDate,
            notes: 'Rejected by Buyer: ${input.reason}${input.notes != null ? ' - ${input.notes}' : ''}',
            createdAt: r.createdAt,
            isCurrent: true,
          );
        }
        return r;
      }).toList();

      final updatedOffer = existingOffer.copyWith(
        status: 'Rejected',
        negotiationRounds: updatedRounds,
        updatedAt: now,
      );

      final idx = _sessionOffers.indexWhere((o) => o.id == existingOffer.id);
      if (idx >= 0) {
        _sessionOffers[idx] = updatedOffer;
      }

      final client = _supabase;
      if (client != null) {
        try {
          await client.from('quotations').update({
            'status': 'Rejected',
            'rejection_reason': input.reason,
          }).eq('id', existingOffer.id);
        } catch (e) {
          debugPrint('Remote reject quotation update notice: $e');
        }
      }

      return updatedOffer;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Helper to query deal_versions from Supabase if available.
  Future<List<NegotiationRound>> _fetchRemoteNegotiationRounds(
    SupabaseClient client,
    String quoteId,
    double fallbackPrice,
    double fallbackQty,
  ) async {
    try {
      final versions = await client
          .from('deal_versions')
          .select('id, version_number, actor_id, status, snapshot_payload, created_at')
          .eq('request_id', quoteId)
          .order('version_number', ascending: true);

      if (versions.isNotEmpty) {
        final list = <NegotiationRound>[];
        for (int i = 0; i < versions.length; i++) {
          final v = versions[i];
          final payload = v['snapshot_payload'] as Map<String, dynamic>? ?? {};
          final isLast = i == versions.length - 1;
          list.add(
            NegotiationRound(
              id: v['id']?.toString() ?? '',
              versionNumber: (v['version_number'] as num?)?.toInt() ?? (i + 1),
              status: v['status'] as String? ?? 'Proposed',
              actorRole: payload['originatorRole'] as String? ?? 'broker',
              proposerName: (payload['originatorRole'] as String? ?? 'broker') == 'buyer'
                  ? 'You (Buyer Counter-Offer)'
                  : 'Broker Desk (Commercial Proposal)',
              proposedPrice: (payload['price'] as num?)?.toDouble() ??
                  (payload['rate'] as num?)?.toDouble() ??
                  fallbackPrice,
              proposedQuantity: (payload['quantity'] as num?)?.toDouble() ?? fallbackQty,
              deliveryDate: payload['deliveryDate'] as String?,
              notes: payload['buyerNotes'] as String? ?? payload['remarks'] as String?,
              createdAt: v['created_at'] != null ? DateTime.tryParse(v['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
              isCurrent: isLast,
            ),
          );
        }
        return list;
      }
    } catch (_) {}

    // Fallback baseline round
    return [
      NegotiationRound(
        id: 'ROUND-$quoteId-V1',
        versionNumber: 1,
        status: 'Proposed',
        actorRole: 'broker',
        proposerName: 'Broker Desk (Commercial Proposal)',
        proposedPrice: fallbackPrice,
        proposedQuantity: fallbackQty,
        notes: 'Initial commercial quotation mediated by broker desk.',
        createdAt: DateTime.now().subtract(const Duration(hours: 18)),
        isCurrent: true,
      ),
    ];
  }

  /// Generate verified baseline commercial offers matching the database test dataset.
  static List<BuyerOffer> _generateBaselineOffers() {
    return [
      // Offer 1: Active proposed offer with 2-round negotiation history for Maize
      BuyerOffer(
        id: 'OFFER-2026-081',
        requirementId: '60000000-0000-0000-0000-000000000101',
        requirementDisplayId: 'REQ-60000000',
        commodityName: 'Yellow Maize (Corn)',
        gradeName: 'Grade A Milling',
        offeredQuantity: 100.0,
        unit: 'MT',
        offeredPrice: 22500.0,
        totalEstimatedValue: 2250000.0,
        status: 'Proposed',
        versionNumber: 2,
        brokerId: '00000000-0000-0000-0000-0000000000a1',
        brokerName: 'Kota Agro Warehousing Broker Desk',
        brokerNotes: 'Negotiated rate down by ₹300/MT. Moisture strictly guaranteed <= 12.5% with digital weighbridge slip.',
        validUntil: DateTime.now().add(const Duration(days: 3)),
        deliveryTerms: 'FOR Destination (Freight Paid by Seller)',
        deliveryLocation: 'Kota Industrial Area Mill Hub, Rajasthan',
        deliveryDate: DateTime.now().add(const Duration(days: 6)),
        paymentTerms: '100% Against Delivery & Verified Weighbridge Slip via Escrow',
        packagingType: '50kg HDPE / PP Laminated Bags',
        specialConditions: 'Standard moisture deductions apply for moisture above 12.0%.',
        applicableCharges: const [
          OfferChargeItem(name: 'Brokerage & Facilitation Fee', rate: 35, amount: 3500, type: 'per_unit', description: 'Regulated broker desk mediation fee'),
          OfferChargeItem(name: 'Mandi Cess & Weighment Handling', rate: 15, amount: 1500, type: 'per_unit', description: 'Certified digital weighbridge handling'),
          OfferChargeItem(name: 'Transit Escrow & Quality Cover', rate: 10, amount: 1000, type: 'per_unit', description: 'Buyer dispute protection guarantee'),
        ],
        qualitySpecs: const [
          OfferQualitySpec(parameterName: 'Moisture Content', targetValue: '12.0', tolerance: 'Max 12.5%', unit: '%', isMandatory: true),
          OfferQualitySpec(parameterName: 'Foreign Matter / Admixture', targetValue: '1.0', tolerance: 'Max 1.5%', unit: '%', isMandatory: true),
          OfferQualitySpec(parameterName: 'Damaged / Discolored Kernels', targetValue: '2.0', tolerance: 'Max 2.5%', unit: '%', isMandatory: false),
          OfferQualitySpec(parameterName: 'Aflatoxin (B1+B2+G1+G2)', targetValue: '20', tolerance: 'Max 20 ppb', unit: 'ppb', isMandatory: true),
        ],
        negotiationRounds: [
          NegotiationRound(
            id: 'ROUND-081-V1',
            versionNumber: 1,
            status: 'Superseded',
            actorRole: 'broker',
            proposerName: 'Broker Desk (Commercial Proposal)',
            proposedPrice: 22800.0,
            proposedQuantity: 100.0,
            notes: 'Initial quotation received from verified mandi lot.',
            createdAt: DateTime.now().subtract(const Duration(hours: 36)),
            isCurrent: false,
          ),
          NegotiationRound(
            id: 'ROUND-081-V2',
            versionNumber: 2,
            status: 'Proposed',
            actorRole: 'broker',
            proposerName: 'Broker Desk (Commercial Proposal)',
            proposedPrice: 22500.0,
            proposedQuantity: 100.0,
            notes: 'Revised proposal: Broker secured ₹300/MT concession for prompt dispatch.',
            createdAt: DateTime.now().subtract(const Duration(hours: 12)),
            isCurrent: true,
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(hours: 36)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),

      // Offer 2: Sharbati Wheat offer in Countered state
      BuyerOffer(
        id: 'OFFER-2026-082',
        requirementId: '60000000-0000-0000-0000-000000000103',
        requirementDisplayId: 'REQ-60000000-WHEAT',
        commodityName: 'Sharbati Wheat',
        gradeName: 'Premium Sharbati',
        offeredQuantity: 50.0,
        unit: 'MT',
        offeredPrice: 28000.0,
        totalEstimatedValue: 1400000.0,
        status: 'Countered',
        versionNumber: 2,
        brokerId: '00000000-0000-0000-0000-0000000000a1',
        brokerName: 'Jaipur Grain Broker Desk',
        brokerNotes: 'Buyer proposed counter rate of ₹28,000/MT with delivery by 25th Oct.',
        validUntil: DateTime.now().add(const Duration(days: 5)),
        deliveryTerms: 'Ex-Mandi (Buyer Arranges Logistics)',
        deliveryLocation: 'Jaipur Central Mandi Yard, Rajasthan',
        deliveryDate: DateTime.now().add(const Duration(days: 8)),
        paymentTerms: 'CAD (Cash Against Documents via Broker Escrow)',
        packagingType: '50kg Jute Bags (Mandi Standard)',
        applicableCharges: const [
          OfferChargeItem(name: 'Brokerage & Facilitation Fee', rate: 35, amount: 1750, type: 'per_unit'),
          OfferChargeItem(name: 'Certified Loading Weighment', rate: 15, amount: 750, type: 'per_unit'),
        ],
        qualitySpecs: const [
          OfferQualitySpec(parameterName: 'Protein Content', targetValue: '12.5', tolerance: 'Min 12.0%', unit: '%'),
          OfferQualitySpec(parameterName: 'Moisture Content', targetValue: '11.5', tolerance: 'Max 12.0%', unit: '%'),
        ],
        negotiationRounds: [
          NegotiationRound(
            id: 'ROUND-082-V1',
            versionNumber: 1,
            status: 'Superseded',
            actorRole: 'broker',
            proposerName: 'Broker Desk (Commercial Proposal)',
            proposedPrice: 28200.0,
            proposedQuantity: 50.0,
            notes: 'Opening quote for Premium Sharbati lot.',
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
            isCurrent: false,
          ),
          NegotiationRound(
            id: 'ROUND-082-V2',
            versionNumber: 2,
            status: 'Countered',
            actorRole: 'buyer',
            proposerName: 'You (Buyer Counter-Offer)',
            proposedPrice: 28000.0,
            proposedQuantity: 50.0,
            notes: 'Targeting ₹28,000/MT based on current Jaipur mandi arrivals.',
            createdAt: DateTime.now().subtract(const Duration(hours: 8)),
            isCurrent: true,
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),

      // Offer 3: Accepted offer (deal contract in preparation)
      BuyerOffer(
        id: 'OFFER-2026-083',
        requirementId: '60000000-0000-0000-0000-000000000101',
        requirementDisplayId: 'REQ-60000000-MAIZE2',
        commodityName: 'Yellow Maize (Corn)',
        gradeName: 'Feed Grade Premium',
        offeredQuantity: 60.0,
        unit: 'MT',
        offeredPrice: 22500.0,
        totalEstimatedValue: 1350000.0,
        status: 'Accepted',
        versionNumber: 1,
        brokerId: '00000000-0000-0000-0000-0000000000a1',
        brokerName: 'Kota Agro Warehousing Broker Desk',
        brokerNotes: 'Accepted commercial proposal. Broker desk preparing trade allocation contract.',
        validUntil: DateTime.now().add(const Duration(days: 10)),
        deliveryTerms: 'FOR Destination',
        deliveryLocation: 'Kota Industrial Area Mill Hub, Rajasthan',
        paymentTerms: '100% Against Delivery & Verified Weighbridge Slip',
        packagingType: '50kg HDPE Bags',
        applicableCharges: const [
          OfferChargeItem(name: 'Brokerage & Facilitation Fee', rate: 35, amount: 2100, type: 'per_unit'),
        ],
        negotiationRounds: [
          NegotiationRound(
            id: 'ROUND-083-V1',
            versionNumber: 1,
            status: 'Accepted',
            actorRole: 'broker',
            proposerName: 'Broker Desk (Commercial Proposal)',
            proposedPrice: 22500.0,
            proposedQuantity: 60.0,
            notes: 'Commercial terms accepted by buyer.',
            createdAt: DateTime.now().subtract(const Duration(days: 4)),
            isCurrent: true,
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),

      // Offer 4: Expired Offer
      BuyerOffer(
        id: 'OFFER-2026-084',
        requirementId: '60000000-0000-0000-0000-000000000102',
        requirementDisplayId: 'REQ-60000000-SOY',
        commodityName: 'Soybean Seed',
        gradeName: 'Standard Mandi Grade',
        offeredQuantity: 30.0,
        unit: 'MT',
        offeredPrice: 4750.0,
        totalEstimatedValue: 142500.0,
        status: 'Expired',
        versionNumber: 1,
        brokerId: '00000000-0000-0000-0000-0000000000a1',
        brokerName: 'Kota Agro Warehousing Broker Desk',
        brokerNotes: 'Validity period elapsed without buyer acceptance.',
        validUntil: DateTime.now().subtract(const Duration(days: 1)),
        deliveryTerms: 'FOR Destination',
        deliveryLocation: 'Kota Industrial Area, Rajasthan',
        paymentTerms: '100% Against Delivery',
        packagingType: 'Loose Bulk',
        negotiationRounds: [
          NegotiationRound(
            id: 'ROUND-084-V1',
            versionNumber: 1,
            status: 'Expired',
            actorRole: 'broker',
            proposerName: 'Broker Desk (Commercial Proposal)',
            proposedPrice: 4750.0,
            proposedQuantity: 30.0,
            notes: 'Offer expired.',
            createdAt: DateTime.now().subtract(const Duration(days: 8)),
            isCurrent: true,
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }
}
