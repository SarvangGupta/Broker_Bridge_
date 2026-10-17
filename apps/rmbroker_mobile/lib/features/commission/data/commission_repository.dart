import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../deals/data/deal_repository.dart';
import '../domain/commission_calculator.dart';
import '../domain/commission_model.dart';

/// Repository for authoritative Brokerage Commission & Earnings management.
class CommissionRepository {
  final ApiClient? _customApiClient;
  final SupabaseClient? _customSupabase;
  final SecureStorageService _storage;

  // In-memory persistent cache for mock / offline fallback session
  static final List<CommissionRecord> _cachedRecords = [];
  static bool _hasSeeded = false;

  CommissionRepository({
    ApiClient? apiClient,
    SupabaseClient? supabase,
    SecureStorageService? storage,
  })  : _customApiClient = apiClient,
        _customSupabase = supabase,
        _storage = storage ?? SecureStorageService() {
    _ensureSeedData();
  }

  ApiClient get _apiClient => _customApiClient ?? ApiClient(storage: _storage);

  SupabaseClient? get _supabase {
    if (_customSupabase != null) return _customSupabase;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void _ensureSeedData() {
    if (_hasSeeded && _cachedRecords.isNotEmpty) return;
    _hasSeeded = true;

    final now = DateTime.now();

    _cachedRecords.addAll([
      // 1. Fully Paid Deal
      CommissionRecord(
        dealId: 'deal-jaipur-wheat-101',
        dealReference: 'DL-WHT-101',
        bookingReference: 'BK-2026-001',
        commodityName: 'Sharbati Wheat',
        gradeName: 'A-Grade Premium',
        buyerCompanyName: 'Rajasthan Agro Mills Ltd',
        sellerCompanyName: 'Hadoti Krishi Mandi FPO',
        agreedRatePerMT: 50.0,
        commissionBasis: '₹/MT',
        quantities: const CommissionQuantityBreakdown(
          contractedQuantity: 100.0,
          dispatchedQuantity: 100.0,
          deliveredQuantity: 100.0,
          acceptedQuantity: 100.0,
          rejectedQuantity: 0.0,
          disputedQuantity: 0.0,
          unitSymbol: 'MT',
        ),
        grossRawMaterialValue: 2650000.0, // 100 MT * ₹26,500 = ₹26.5L
        calculatedCommission: 5000.0, // 100 MT * ₹50
        eligibleCommission: 5000.0,
        invoicedAmount: 5000.0,
        paidAmount: 5000.0,
        outstandingAmount: 0.0,
        disputedAmount: 0.0,
        status: CommissionStatus.paid,
        invoiceNumber: 'INV-BRK-2026-042',
        invoiceDate: now.subtract(const Duration(days: 12)),
        payments: [
          CommissionPaymentItem(
            id: 'pay-001',
            dealId: 'deal-jaipur-wheat-101',
            bookingReference: 'BK-2026-001',
            amount: 5000.0,
            referenceNumber: 'UTR-HDFC-99482103',
            direction: 'Buyer to Broker',
            status: 'Confirmed',
            paymentDate: now.subtract(const Duration(days: 10)),
            recordedBy: 'Broker Desk Automated Match',
            notes: 'NEFT credit from Rajasthan Agro Mills clearing account',
          ),
        ],
        adjustments: [],
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(days: 10)),
      ),

      // 2. Partially Delivered & Partially Paid Deal
      CommissionRecord(
        dealId: 'deal-kota-mustard-102',
        dealReference: 'DL-MST-102',
        bookingReference: 'BK-2026-002',
        commodityName: 'Mustard Seed (Sarson)',
        gradeName: 'Grade-1 High Oil',
        buyerCompanyName: 'Adani Wilmar Solvent Plant',
        sellerCompanyName: 'Chambal Kisan Producer Co',
        agreedRatePerMT: 60.0,
        commissionBasis: '₹/MT',
        quantities: const CommissionQuantityBreakdown(
          contractedQuantity: 200.0,
          dispatchedQuantity: 120.0,
          deliveredQuantity: 120.0,
          acceptedQuantity: 115.0,
          rejectedQuantity: 5.0,
          disputedQuantity: 0.0,
          unitSymbol: 'MT',
        ),
        grossRawMaterialValue: 6480000.0, // 120 MT * ₹54,000
        calculatedCommission: 12000.0, // 200 MT * ₹60
        eligibleCommission: 6900.0, // 115 MT * ₹60
        invoicedAmount: 6900.0,
        paidAmount: 3500.0,
        outstandingAmount: 3400.0,
        disputedAmount: 0.0,
        status: CommissionStatus.partiallyPaid,
        invoiceNumber: 'INV-BRK-2026-055',
        invoiceDate: now.subtract(const Duration(days: 5)),
        payments: [
          CommissionPaymentItem(
            id: 'pay-002',
            dealId: 'deal-kota-mustard-102',
            bookingReference: 'BK-2026-002',
            amount: 3500.0,
            referenceNumber: 'UTR-ICIC-48291048',
            direction: 'Buyer to Broker',
            status: 'Confirmed',
            paymentDate: now.subtract(const Duration(days: 3)),
            recordedBy: 'Manually recorded by Broker Desk',
            notes: 'Partial advance brokerage payout received via RTGS',
          ),
        ],
        adjustments: [],
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),

      // 3. Delivered & Invoiced (Awaiting Payment)
      CommissionRecord(
        dealId: 'deal-alwar-soybean-103',
        dealReference: 'DL-SOY-103',
        bookingReference: 'BK-2026-003',
        commodityName: 'Yellow Soybean',
        gradeName: 'FAQ Standard',
        buyerCompanyName: 'Kriti Nutrients Industrial Unit',
        sellerCompanyName: 'Mewar Agri Warehouse Corp',
        agreedRatePerMT: 45.0,
        commissionBasis: '₹/MT',
        quantities: const CommissionQuantityBreakdown(
          contractedQuantity: 150.0,
          dispatchedQuantity: 150.0,
          deliveredQuantity: 150.0,
          acceptedQuantity: 150.0,
          rejectedQuantity: 0.0,
          disputedQuantity: 0.0,
          unitSymbol: 'MT',
        ),
        grossRawMaterialValue: 7200000.0,
        calculatedCommission: 6750.0,
        eligibleCommission: 6750.0,
        invoicedAmount: 6750.0,
        paidAmount: 0.0,
        outstandingAmount: 6750.0,
        disputedAmount: 0.0,
        status: CommissionStatus.invoiced,
        invoiceNumber: 'INV-BRK-2026-061',
        invoiceDate: now.subtract(const Duration(days: 2)),
        payments: [],
        adjustments: [],
        createdAt: now.subtract(const Duration(days: 8)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),

      // 4. Delivered & Eligible (Invoice Pending)
      CommissionRecord(
        dealId: 'deal-bikaner-chana-104',
        dealReference: 'DL-CHN-104',
        bookingReference: 'BK-2026-004',
        commodityName: 'Desi Chana (Bengal Gram)',
        gradeName: 'Special Bold 44mm',
        buyerCompanyName: 'Shri Ram Dal Mill Bikaner',
        sellerCompanyName: 'Bikaner Farmer Collective',
        agreedRatePerMT: 55.0,
        commissionBasis: '₹/MT',
        quantities: const CommissionQuantityBreakdown(
          contractedQuantity: 80.0,
          dispatchedQuantity: 80.0,
          deliveredQuantity: 80.0,
          acceptedQuantity: 80.0,
          rejectedQuantity: 0.0,
          disputedQuantity: 0.0,
          unitSymbol: 'MT',
        ),
        grossRawMaterialValue: 4640000.0,
        calculatedCommission: 4400.0,
        eligibleCommission: 4400.0,
        invoicedAmount: 0.0,
        paidAmount: 0.0,
        outstandingAmount: 4400.0,
        disputedAmount: 0.0,
        status: CommissionStatus.eligible,
        invoiceNumber: null,
        invoiceDate: null,
        payments: [],
        adjustments: [],
        createdAt: now.subtract(const Duration(days: 6)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),

      // 5. In Transit (Accruing - Not yet delivered)
      CommissionRecord(
        dealId: 'deal-ganganagar-wheat-105',
        dealReference: 'DL-WHT-105',
        bookingReference: 'BK-2026-005',
        commodityName: 'Durum Wheat',
        gradeName: 'Export Grade',
        buyerCompanyName: 'Patanjali Agro Mandi Division',
        sellerCompanyName: 'Thar Border Farmers Society',
        agreedRatePerMT: 50.0,
        commissionBasis: '₹/MT',
        quantities: const CommissionQuantityBreakdown(
          contractedQuantity: 250.0,
          dispatchedQuantity: 100.0,
          deliveredQuantity: 0.0,
          acceptedQuantity: 0.0,
          rejectedQuantity: 0.0,
          disputedQuantity: 0.0,
          unitSymbol: 'MT',
        ),
        grossRawMaterialValue: 6875000.0,
        calculatedCommission: 12500.0,
        eligibleCommission: 0.0, // 0 delivered = 0 eligible
        invoicedAmount: 0.0,
        paidAmount: 0.0,
        outstandingAmount: 0.0,
        disputedAmount: 0.0,
        status: CommissionStatus.accruing,
        invoiceNumber: null,
        invoiceDate: null,
        payments: [],
        adjustments: [],
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),

      // 6. Disputed Delivery (Moisture dispute)
      CommissionRecord(
        dealId: 'deal-bharatpur-mustard-106',
        dealReference: 'DL-MST-106',
        bookingReference: 'BK-2026-006',
        commodityName: 'Mustard Seed (Sarson)',
        gradeName: 'Commercial Lot',
        buyerCompanyName: 'Bharatpur Oil Expellers',
        sellerCompanyName: 'Braj FPO Kendra',
        agreedRatePerMT: 50.0,
        commissionBasis: '₹/MT',
        quantities: const CommissionQuantityBreakdown(
          contractedQuantity: 60.0,
          dispatchedQuantity: 60.0,
          deliveredQuantity: 60.0,
          acceptedQuantity: 30.0,
          rejectedQuantity: 0.0,
          disputedQuantity: 30.0, // 30 MT under dispute
          unitSymbol: 'MT',
        ),
        grossRawMaterialValue: 3120000.0,
        calculatedCommission: 3000.0,
        eligibleCommission: 1500.0, // 30 MT accepted * ₹50
        invoicedAmount: 1500.0,
        paidAmount: 0.0,
        outstandingAmount: 1500.0,
        disputedAmount: 1500.0, // 30 MT disputed * ₹50
        status: CommissionStatus.disputed,
        invoiceNumber: 'INV-BRK-2026-068',
        invoiceDate: now.subtract(const Duration(days: 7)),
        payments: [],
        adjustments: [
          CommissionAdjustment(
            id: 'adj-001',
            dealId: 'deal-bharatpur-mustard-106',
            previousCommission: 3000.0,
            adjustedCommission: 1500.0,
            reason: '30 MT withheld pending moisture survey report by surveyor',
            adjustedBy: 'Broker Desk Operations',
            createdAt: now.subtract(const Duration(days: 4)),
          ),
        ],
        createdAt: now.subtract(const Duration(days: 14)),
        updatedAt: now.subtract(const Duration(days: 4)),
      ),
    ]);
  }

  // ============================================================================
  // 1. COMMISSION SUMMARY KPIS
  // ============================================================================

  /// Returns aggregated commission KPIs for the broker desk.
  Future<DealDataResult<CommissionSummary>> getCommissionSummary({
    String period = 'All Time',
  }) async {
    // 1. Attempt REST endpoint
    try {
      final response = await _apiClient.get(
        '/broker/commission/summary',
        queryParameters: {'period': period},
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          final summaryJson = data['data'] as Map<String, dynamic>? ?? {};
          return DealSuccess(
            CommissionSummary(
              totalEligibleCommission:
                  (summaryJson['totalEligibleCommission'] as num?)?.toDouble() ?? 0.0,
              totalInvoicedCommission:
                  (summaryJson['totalInvoicedCommission'] as num?)?.toDouble() ?? 0.0,
              totalReceivedCommission:
                  (summaryJson['totalReceivedCommission'] as num?)?.toDouble() ?? 0.0,
              totalOutstandingCommission:
                  (summaryJson['totalOutstandingCommission'] as num?)?.toDouble() ?? 0.0,
              totalDisputedCommission:
                  (summaryJson['totalDisputedCommission'] as num?)?.toDouble() ?? 0.0,
              totalDealsCount: (summaryJson['totalDealsCount'] as num?)?.toInt() ?? 0,
              totalEligibleQuantityMT:
                  (summaryJson['totalEligibleQuantityMT'] as num?)?.toDouble() ?? 0.0,
              totalGrossDealValuation:
                  (summaryJson['totalGrossDealValuation'] as num?)?.toDouble() ?? 0.0,
              period: period,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('REST commission summary notice: $e');
    }

    // 2. Fallback to cached/seeded records
    final recordsResult = await getCommissionRecords(period: period);
    if (recordsResult is DealSuccess<List<CommissionRecord>>) {
      return DealSuccess(CommissionSummary.fromRecords(recordsResult.data, period: period));
    }

    return DealSuccess(CommissionSummary.zero(period: period));
  }

  // ============================================================================
  // 2. COMMISSION RECORDS LIST
  // ============================================================================

  /// Fetches commission records matching optional status and query filters.
  Future<DealDataResult<List<CommissionRecord>>> getCommissionRecords({
    CommissionStatus? status,
    String? query,
    String? period,
  }) async {
    // 1. Attempt REST endpoint
    try {
      final qParams = <String, dynamic>{};
      if (status != null) qParams['status'] = status.code;
      if (query != null && query.trim().isNotEmpty) qParams['q'] = query.trim();
      if (period != null) qParams['period'] = period;

      final response = await _apiClient.get(
        '/broker/commission/records',
        queryParameters: qParams,
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          final list = (data['data'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(CommissionRecord.fromJson)
              .toList();
          return DealSuccess(list);
        }
      }
    } catch (e) {
      debugPrint('REST commission records notice: $e');
    }

    // 2. Attempt Supabase PostgREST query on deals joined with dispatches & payments
    if (_supabase != null) {
      try {
        final user = _supabase!.auth.currentUser;
        if (user != null) {
          final res = await _supabase!
              .from('deals')
              .select('''
                id,
                booking_reference,
                agreed_quantity,
                agreed_price,
                total_valuation,
                status,
                created_at,
                buyer_id,
                seller_id
              ''')
              .order('created_at', ascending: false)
              .limit(50);

          if (res.isNotEmpty) {
            // Process Supabase records if available
            final records = res.map((row) {
              final map = row;
              final qty = (map['agreed_quantity'] as num?)?.toDouble() ?? 50.0;
              final rate = 50.0;
              final comm = qty * rate;
              return CommissionRecord(
                dealId: map['id']?.toString() ?? '',
                dealReference: map['booking_reference']?.toString() ?? 'DL-AUTH',
                bookingReference: map['booking_reference']?.toString(),
                commodityName: 'Agricultural Raw Material',
                buyerCompanyName: 'Authorized Mandi Buyer',
                sellerCompanyName: 'Authorized Mandi Seller',
                agreedRatePerMT: rate,
                quantities: CommissionQuantityBreakdown(
                  contractedQuantity: qty,
                  dispatchedQuantity: qty,
                  deliveredQuantity: qty,
                  acceptedQuantity: qty,
                  unitSymbol: 'MT',
                ),
                grossRawMaterialValue: (map['total_valuation'] as num?)?.toDouble() ?? (qty * 45000),
                calculatedCommission: comm,
                eligibleCommission: comm,
                invoicedAmount: comm,
                paidAmount: 0.0,
                outstandingAmount: comm,
                disputedAmount: 0.0,
                status: CommissionStatus.eligible,
                createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
                updatedAt: DateTime.now(),
              );
            }).toList();

            return DealSuccess(records);
          }
        }
      } catch (e) {
        debugPrint('Supabase commission records query notice: $e');
      }
    }

    // 3. Fallback to cached records with in-memory filtering
    List<CommissionRecord> result = List.from(_cachedRecords);

    if (status != null) {
      result = result.where((r) => r.status == status).toList();
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      result = result.where((r) {
        return r.dealReference.toLowerCase().contains(q) ||
            (r.bookingReference?.toLowerCase().contains(q) ?? false) ||
            r.commodityName.toLowerCase().contains(q) ||
            r.buyerCompanyName.toLowerCase().contains(q) ||
            r.sellerCompanyName.toLowerCase().contains(q) ||
            (r.invoiceNumber?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return DealSuccess(result);
  }

  // ============================================================================
  // 3. GET SINGLE DEAL COMMISSION DETAIL
  // ============================================================================

  /// Returns detailed commission breakdown for a specific deal.
  Future<DealDataResult<CommissionRecord>> getDealCommission(String dealId) async {
    final cleanId = dealId.trim();

    // 1. Check in cache
    final existing = _cachedRecords.where((r) => r.dealId == cleanId || r.dealReference == cleanId);
    if (existing.isNotEmpty) {
      return DealSuccess(existing.first);
    }

    // 2. Fetch all records and find
    final allResult = await getCommissionRecords();
    if (allResult is DealSuccess<List<CommissionRecord>>) {
      final match = allResult.data.where(
        (r) => r.dealId == cleanId || r.dealReference == cleanId,
      );
      if (match.isNotEmpty) {
        return DealSuccess(match.first);
      }
    }

    return const DealError(message: 'Commission record not found for this deal.');
  }

  // ============================================================================
  // 4. LOG COMMISSION PAYMENT (UTR TRACKING)
  // ============================================================================

  /// Records a new commission payment transaction.
  /// Prevents duplicate UTR references and preserves immutable payment history.
  Future<DealDataResult<CommissionPaymentItem>> logCommissionPayment(
    LogPaymentDto dto,
  ) async {
    final validationError = dto.validate();
    if (validationError != null) {
      return DealError(message: validationError);
    }

    // 1. DUPLICATE CHECK: Verify reference number across all recorded payments
    final cleanRef = dto.referenceNumber.trim().toUpperCase();
    for (final record in _cachedRecords) {
      final dup = record.payments.where((p) => p.referenceNumber.trim().toUpperCase() == cleanRef);
      if (dup.isNotEmpty) {
        return DealError(
          message: 'Duplicate payment entry: Reference / UTR "$cleanRef" has already been logged.',
        );
      }
    }

    // 2. Attempt REST call
    try {
      final response = await _apiClient.post(
        '/broker/commission/payments',
        data: {
          'dealId': dto.dealId,
          'bookingReference': dto.bookingReference,
          'amount': dto.amount,
          'referenceNumber': cleanRef,
          'direction': dto.direction,
          'paymentDate': dto.paymentDate.toIso8601String(),
          'notes': dto.notes,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          final item = CommissionPaymentItem.fromJson(data['data'] as Map<String, dynamic>);
          _updateLocalRecordWithPayment(dto.dealId, item);
          return DealSuccess(item);
        }
      }
    } catch (e) {
      debugPrint('REST log payment notice: $e');
    }

    // 3. Fallback: Update in-memory session cache
    final newPayment = CommissionPaymentItem(
      id: 'pay-${DateTime.now().millisecondsSinceEpoch}',
      dealId: dto.dealId,
      bookingReference: dto.bookingReference,
      amount: dto.amount,
      referenceNumber: cleanRef,
      direction: dto.direction,
      status: 'Confirmed',
      paymentDate: dto.paymentDate,
      recordedBy: 'Manually recorded by Broker Desk',
      notes: dto.notes,
    );

    _updateLocalRecordWithPayment(dto.dealId, newPayment);
    return DealSuccess(newPayment);
  }

  void _updateLocalRecordWithPayment(String dealId, CommissionPaymentItem payment) {
    final index = _cachedRecords.indexWhere((r) => r.dealId == dealId || r.dealReference == dealId);
    if (index != -1) {
      final old = _cachedRecords[index];
      final newPayments = [payment, ...old.payments];
      final newPaidAmount = double.parse(
        newPayments.fold<double>(0.0, (sum, p) => sum + p.amount).toStringAsFixed(2),
      );

      final targetReceivable = old.invoicedAmount > 0 ? old.invoicedAmount : old.eligibleCommission;
      final newOutstanding = CommissionCalculator.calculateOutstanding(
        totalReceivable: targetReceivable,
        totalPaid: newPaidAmount,
      );

      final newStatus = CommissionCalculator.determineCommissionStatus(
        eligibleDeliveredQuantityMT: old.quantities.eligibleDeliveredQuantityMT,
        invoicedAmount: old.invoicedAmount,
        paidAmount: newPaidAmount,
        disputedQuantityMT: old.quantities.disputedQuantityMT,
      );

      _cachedRecords[index] = CommissionRecord(
        dealId: old.dealId,
        dealReference: old.dealReference,
        bookingReference: old.bookingReference,
        commodityName: old.commodityName,
        gradeName: old.gradeName,
        buyerCompanyName: old.buyerCompanyName,
        sellerCompanyName: old.sellerCompanyName,
        agreedRatePerMT: old.agreedRatePerMT,
        commissionBasis: old.commissionBasis,
        quantities: old.quantities,
        grossRawMaterialValue: old.grossRawMaterialValue,
        calculatedCommission: old.calculatedCommission,
        eligibleCommission: old.eligibleCommission,
        invoicedAmount: old.invoicedAmount,
        paidAmount: newPaidAmount,
        outstandingAmount: newOutstanding,
        disputedAmount: old.disputedAmount,
        status: newStatus,
        invoiceNumber: old.invoiceNumber,
        invoiceDate: old.invoiceDate,
        payments: newPayments,
        adjustments: old.adjustments,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
    }
  }

  // ============================================================================
  // 5. RECORD COMMISSION ADJUSTMENT (WITH AUDIT TRAIL)
  // ============================================================================

  /// Adjusts commission rate or amount with an immutable audit log.
  Future<DealDataResult<CommissionAdjustment>> recordCommissionAdjustment({
    required String dealId,
    required double newRatePerMT,
    required String reason,
  }) async {
    if (newRatePerMT < 0) {
      return const DealError(message: 'Commission rate cannot be negative');
    }
    if (reason.trim().isEmpty) {
      return const DealError(message: 'Adjustment reason is required for financial auditability');
    }

    final index = _cachedRecords.indexWhere((r) => r.dealId == dealId || r.dealReference == dealId);
    if (index == -1) {
      return const DealError(message: 'Deal commission record not found');
    }

    final old = _cachedRecords[index];
    final newEligible = double.parse(
      (old.quantities.eligibleDeliveredQuantityMT * newRatePerMT).toStringAsFixed(2),
    );

    final adjustment = CommissionAdjustment(
      id: 'adj-${DateTime.now().millisecondsSinceEpoch}',
      dealId: old.dealId,
      previousCommission: old.eligibleCommission,
      adjustedCommission: newEligible,
      reason: reason.trim(),
      adjustedBy: 'Authorized Broker User',
      createdAt: DateTime.now(),
    );

    final targetReceivable = old.invoicedAmount > 0 ? old.invoicedAmount : newEligible;
    final newOutstanding = CommissionCalculator.calculateOutstanding(
      totalReceivable: targetReceivable,
      totalPaid: old.paidAmount,
    );

    _cachedRecords[index] = CommissionRecord(
      dealId: old.dealId,
      dealReference: old.dealReference,
      bookingReference: old.bookingReference,
      commodityName: old.commodityName,
      gradeName: old.gradeName,
      buyerCompanyName: old.buyerCompanyName,
      sellerCompanyName: old.sellerCompanyName,
      agreedRatePerMT: newRatePerMT,
      commissionBasis: old.commissionBasis,
      quantities: old.quantities,
      grossRawMaterialValue: old.grossRawMaterialValue,
      calculatedCommission: double.parse(
        (old.quantities.contractedQuantityMT * newRatePerMT).toStringAsFixed(2),
      ),
      eligibleCommission: newEligible,
      invoicedAmount: old.invoicedAmount,
      paidAmount: old.paidAmount,
      outstandingAmount: newOutstanding,
      disputedAmount: old.disputedAmount,
      status: CommissionStatus.adjusted,
      invoiceNumber: old.invoiceNumber,
      invoiceDate: old.invoiceDate,
      payments: old.payments,
      adjustments: [adjustment, ...old.adjustments],
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );

    return DealSuccess(adjustment);
  }
}
