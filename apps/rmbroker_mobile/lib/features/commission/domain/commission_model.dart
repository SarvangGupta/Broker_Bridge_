import 'package:flutter/foundation.dart';
import '../../work/domain/unit_utils.dart';

/// Brokerage commission lifecycle statuses.
/// Strictly aligned with backend settlement & financial models.
enum CommissionStatus {
  notEligible('not_eligible', 'Not Eligible', 'Draft or unfulfilled deal'),
  accruing('accruing', 'Accruing', 'Fulfillment in progress'),
  eligible('eligible', 'Eligible', 'Delivered & accepted, un-invoiced'),
  invoiced('invoiced', 'Invoiced', 'Commission invoice issued'),
  partiallyPaid('partially_paid', 'Partially Paid', 'Partially received'),
  paid('paid', 'Paid', 'Commission fully settled'),
  disputed('disputed', 'Disputed', 'Commission withheld or under dispute'),
  adjusted('adjusted', 'Adjusted', 'Commission adjusted with audit log');

  final String code;
  final String displayLabel;
  final String description;

  const CommissionStatus(this.code, this.displayLabel, this.description);

  bool get isReceivable =>
      this == CommissionStatus.eligible ||
      this == CommissionStatus.invoiced ||
      this == CommissionStatus.partiallyPaid;

  bool get canLogPayment =>
      this == CommissionStatus.invoiced ||
      this == CommissionStatus.partiallyPaid ||
      this == CommissionStatus.eligible;

  static CommissionStatus fromString(String? val) {
    if (val == null) return CommissionStatus.notEligible;
    final clean = val.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    switch (clean) {
      case 'not_eligible':
      case 'noteligible':
      case 'draft':
        return CommissionStatus.notEligible;
      case 'accruing':
      case 'pending':
      case 'in_progress':
        return CommissionStatus.accruing;
      case 'eligible':
      case 'delivered':
      case 'completed':
        return CommissionStatus.eligible;
      case 'invoiced':
      case 'billed':
        return CommissionStatus.invoiced;
      case 'partially_paid':
      case 'part_paid':
      case 'partiallypaid':
        return CommissionStatus.partiallyPaid;
      case 'paid':
      case 'settled':
      case 'closed':
        return CommissionStatus.paid;
      case 'disputed':
      case 'dispute':
        return CommissionStatus.disputed;
      case 'adjusted':
      case 'cancelled':
      case 'adjusted_or_cancelled':
        return CommissionStatus.adjusted;
      default:
        return CommissionStatus.notEligible;
    }
  }
}

/// Strict multi-tier quantity breakdown.
/// Ensures contracted, dispatched, delivered, accepted, rejected, and disputed quantities remain distinct.
@immutable
class CommissionQuantityBreakdown {
  final double contractedQuantity;
  final double dispatchedQuantity;
  final double deliveredQuantity;
  final double acceptedQuantity;
  final double rejectedQuantity;
  final double disputedQuantity;
  final String unitSymbol;

  const CommissionQuantityBreakdown({
    required this.contractedQuantity,
    this.dispatchedQuantity = 0.0,
    this.deliveredQuantity = 0.0,
    this.acceptedQuantity = 0.0,
    this.rejectedQuantity = 0.0,
    this.disputedQuantity = 0.0,
    this.unitSymbol = 'MT',
  });

  /// Authoritative eligible delivered quantity.
  /// Business Rule: Rejected and disputed quantities are NEVER commission-eligible.
  /// If acceptedQuantity is recorded explicitly (> 0), it acts as authoritative accepted quantity;
  /// otherwise eligible delivered quantity is max(0, delivered - rejected - disputed).
  double get eligibleDeliveredQuantity {
    if (acceptedQuantity > 0) {
      return acceptedQuantity;
    }
    final eligible = deliveredQuantity - rejectedQuantity - disputedQuantity;
    return eligible > 0 ? eligible : 0.0;
  }

  /// Explicit unit conversion factor to Metric Tonnes (MT).
  /// 1 MT = 10 Quintals = 1,000 Kg.
  double get conversionFactorToMT {
    final clean = unitSymbol.trim().toUpperCase();
    if (clean == 'MT' || clean == 'METRIC TONNE' || clean == 'TONNE') {
      return 1.0;
    }
    if (clean == 'QTL' || clean == 'QUINTAL' || clean == 'QUINTALS') {
      return 0.1;
    }
    if (clean == 'KG' || clean == 'KILOGRAM' || clean == 'KGS') {
      return 0.001;
    }
    return 1.0;
  }

  /// Eligible delivered quantity normalized to Metric Tonnes (MT).
  double get eligibleDeliveredQuantityMT =>
      double.parse((eligibleDeliveredQuantity * conversionFactorToMT).toStringAsFixed(3));

  /// Contracted quantity normalized to Metric Tonnes (MT).
  double get contractedQuantityMT =>
      double.parse((contractedQuantity * conversionFactorToMT).toStringAsFixed(3));

  /// Disputed quantity normalized to Metric Tonnes (MT).
  double get disputedQuantityMT =>
      double.parse((disputedQuantity * conversionFactorToMT).toStringAsFixed(3));

  factory CommissionQuantityBreakdown.fromJson(Map<String, dynamic> json) {
    return CommissionQuantityBreakdown(
      contractedQuantity: (json['contractedQuantity'] as num?)?.toDouble() ??
          (json['agreedQuantity'] as num?)?.toDouble() ??
          (json['quantity'] as num?)?.toDouble() ??
          0.0,
      dispatchedQuantity: (json['dispatchedQuantity'] as num?)?.toDouble() ?? 0.0,
      deliveredQuantity: (json['deliveredQuantity'] as num?)?.toDouble() ?? 0.0,
      acceptedQuantity: (json['acceptedQuantity'] as num?)?.toDouble() ?? 0.0,
      rejectedQuantity: (json['rejectedQuantity'] as num?)?.toDouble() ?? 0.0,
      disputedQuantity: (json['disputedQuantity'] as num?)?.toDouble() ?? 0.0,
      unitSymbol: json['unitSymbol']?.toString() ?? json['unit_symbol']?.toString() ?? 'MT',
    );
  }

  Map<String, dynamic> toJson() => {
        'contractedQuantity': contractedQuantity,
        'dispatchedQuantity': dispatchedQuantity,
        'deliveredQuantity': deliveredQuantity,
        'acceptedQuantity': acceptedQuantity,
        'rejectedQuantity': rejectedQuantity,
        'disputedQuantity': disputedQuantity,
        'eligibleDeliveredQuantity': eligibleDeliveredQuantity,
        'unitSymbol': unitSymbol,
        'eligibleDeliveredQuantityMT': eligibleDeliveredQuantityMT,
      };
}

/// Audit record for commission rate or calculation adjustments.
@immutable
class CommissionAdjustment {
  final String id;
  final String dealId;
  final double previousCommission;
  final double adjustedCommission;
  final String reason;
  final String adjustedBy;
  final DateTime createdAt;

  const CommissionAdjustment({
    required this.id,
    required this.dealId,
    required this.previousCommission,
    required this.adjustedCommission,
    required this.reason,
    required this.adjustedBy,
    required this.createdAt,
  });

  factory CommissionAdjustment.fromJson(Map<String, dynamic> json) {
    return CommissionAdjustment(
      id: json['id']?.toString() ?? '',
      dealId: json['dealId']?.toString() ?? '',
      previousCommission: (json['previousCommission'] as num?)?.toDouble() ?? 0.0,
      adjustedCommission: (json['adjustedCommission'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason']?.toString() ?? 'Commission Adjustment',
      adjustedBy: json['adjustedBy']?.toString() ?? 'Broker Desk',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dealId': dealId,
        'previousCommission': previousCommission,
        'adjustedCommission': adjustedCommission,
        'reason': reason,
        'adjustedBy': adjustedBy,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Payment record for brokerage commission settlement.
@immutable
class CommissionPaymentItem {
  final String id;
  final String dealId;
  final String? bookingReference;
  final double amount;
  final String referenceNumber;
  final String direction;
  final String status;
  final DateTime paymentDate;
  final String recordedBy;
  final String? notes;

  const CommissionPaymentItem({
    required this.id,
    required this.dealId,
    this.bookingReference,
    required this.amount,
    required this.referenceNumber,
    this.direction = 'Buyer to Broker',
    this.status = 'Confirmed',
    required this.paymentDate,
    this.recordedBy = 'Manually recorded by Broker Desk',
    this.notes,
  });

  factory CommissionPaymentItem.fromJson(Map<String, dynamic> json) {
    return CommissionPaymentItem(
      id: json['id']?.toString() ?? '',
      dealId: json['dealId']?.toString() ?? '',
      bookingReference: json['bookingReference']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      referenceNumber: json['referenceNumber']?.toString() ?? 'N/A',
      direction: json['direction']?.toString() ?? 'Buyer to Broker',
      status: json['status']?.toString() ?? 'Confirmed',
      paymentDate: json['paymentDate'] != null
          ? DateTime.tryParse(json['paymentDate'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      recordedBy: json['recordedBy']?.toString() ?? 'Manually recorded by Broker Desk',
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dealId': dealId,
        'bookingReference': bookingReference,
        'amount': amount,
        'referenceNumber': referenceNumber,
        'direction': direction,
        'status': status,
        'paymentDate': paymentDate.toIso8601String(),
        'recordedBy': recordedBy,
        'notes': notes,
      };
}

/// Detailed brokerage commission record for a deal.
/// STRICT FIDUCIARY SEPARATION:
/// Gross Raw Material Value is stored strictly as trade turnover context and is
/// NEVER summed or aggregated into brokerage income.
@immutable
class CommissionRecord {
  final String dealId;
  final String dealReference;
  final String? bookingReference;
  final String commodityName;
  final String? gradeName;
  final String buyerCompanyName;
  final String sellerCompanyName;
  final double agreedRatePerMT;
  final String commissionBasis;
  final CommissionQuantityBreakdown quantities;
  final double grossRawMaterialValue;
  final double calculatedCommission;
  final double eligibleCommission;
  final double invoicedAmount;
  final double paidAmount;
  final double outstandingAmount;
  final double disputedAmount;
  final CommissionStatus status;
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final List<CommissionPaymentItem> payments;
  final List<CommissionAdjustment> adjustments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommissionRecord({
    required this.dealId,
    required this.dealReference,
    this.bookingReference,
    required this.commodityName,
    this.gradeName,
    required this.buyerCompanyName,
    required this.sellerCompanyName,
    required this.agreedRatePerMT,
    this.commissionBasis = '₹/MT',
    required this.quantities,
    required this.grossRawMaterialValue,
    required this.calculatedCommission,
    required this.eligibleCommission,
    required this.invoicedAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.disputedAmount,
    required this.status,
    this.invoiceNumber,
    this.invoiceDate,
    this.payments = const [],
    this.adjustments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Formatted calculation formula: e.g. "40.00 MT × ₹50.00/MT = ₹2,000.00"
  String get calculationFormula {
    final qtyStr = UnitUtils.format(quantities.eligibleDeliveredQuantityMT, 'MT');
    final rateStr = '₹${agreedRatePerMT.toStringAsFixed(2)}/MT';
    final commStr = '₹${eligibleCommission.toStringAsFixed(2)}';
    return '$qtyStr × $rateStr = $commStr';
  }

  factory CommissionRecord.fromJson(Map<String, dynamic> json) {
    final qBreakdown = json['quantities'] is Map<String, dynamic>
        ? CommissionQuantityBreakdown.fromJson(json['quantities'] as Map<String, dynamic>)
        : CommissionQuantityBreakdown.fromJson(json);

    final rate = (json['agreedRatePerMT'] as num?)?.toDouble() ??
        (json['brokerCommissionRate'] as num?)?.toDouble() ??
        (json['rate'] as num?)?.toDouble() ??
        50.0;

    final grossVal = (json['grossRawMaterialValue'] as num?)?.toDouble() ??
        (json['totalValuation'] as num?)?.toDouble() ??
        0.0;

    // Commission = eligible delivered MT * agreed rate per MT
    final eligibleComm = (json['eligibleCommission'] as num?)?.toDouble() ??
        double.parse((qBreakdown.eligibleDeliveredQuantityMT * rate).toStringAsFixed(2));

    final calcComm = (json['calculatedCommission'] as num?)?.toDouble() ??
        double.parse((qBreakdown.contractedQuantityMT * rate).toStringAsFixed(2));

    final invoiced = (json['invoicedAmount'] as num?)?.toDouble() ?? 0.0;
    final paid = (json['paidAmount'] as num?)?.toDouble() ?? 0.0;

    final outstanding = (json['outstandingAmount'] as num?)?.toDouble() ??
        (invoiced > 0
            ? (invoiced - paid > 0 ? invoiced - paid : 0.0)
            : (eligibleComm - paid > 0 ? eligibleComm - paid : 0.0));

    final disputed = (json['disputedAmount'] as num?)?.toDouble() ??
        double.parse((qBreakdown.disputedQuantityMT * rate).toStringAsFixed(2));

    final paymentsList = (json['payments'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(CommissionPaymentItem.fromJson)
            .toList() ??
        [];

    final adjList = (json['adjustments'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(CommissionAdjustment.fromJson)
            .toList() ??
        [];

    final created = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now();

    final updated = json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
        : created;

    return CommissionRecord(
      dealId: json['dealId']?.toString() ?? json['id']?.toString() ?? '',
      dealReference: json['dealReference']?.toString() ??
          json['ref']?.toString() ??
          'DL-${json['id']?.toString().substring(0, 6).toUpperCase() ?? '0000'}',
      bookingReference: json['bookingReference']?.toString(),
      commodityName: json['commodityName']?.toString() ?? 'Agricultural Commodity',
      gradeName: json['gradeName']?.toString(),
      buyerCompanyName: json['buyerCompanyName']?.toString() ?? 'Buyer Mandate',
      sellerCompanyName: json['sellerCompanyName']?.toString() ?? 'Seller Lot',
      agreedRatePerMT: rate,
      commissionBasis: json['commissionBasis']?.toString() ?? '₹/MT',
      quantities: qBreakdown,
      grossRawMaterialValue: grossVal,
      calculatedCommission: calcComm,
      eligibleCommission: eligibleComm,
      invoicedAmount: invoiced,
      paidAmount: paid,
      outstandingAmount: outstanding,
      disputedAmount: disputed,
      status: CommissionStatus.fromString(json['status']?.toString()),
      invoiceNumber: json['invoiceNumber']?.toString(),
      invoiceDate: json['invoiceDate'] != null
          ? DateTime.tryParse(json['invoiceDate'].toString())
          : null,
      payments: paymentsList,
      adjustments: adjList,
      createdAt: created,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toJson() => {
        'dealId': dealId,
        'dealReference': dealReference,
        'bookingReference': bookingReference,
        'commodityName': commodityName,
        'gradeName': gradeName,
        'buyerCompanyName': buyerCompanyName,
        'sellerCompanyName': sellerCompanyName,
        'agreedRatePerMT': agreedRatePerMT,
        'commissionBasis': commissionBasis,
        'quantities': quantities.toJson(),
        'grossRawMaterialValue': grossRawMaterialValue,
        'calculatedCommission': calculatedCommission,
        'eligibleCommission': eligibleCommission,
        'invoicedAmount': invoicedAmount,
        'paidAmount': paidAmount,
        'outstandingAmount': outstandingAmount,
        'disputedAmount': disputedAmount,
        'status': status.code,
        'invoiceNumber': invoiceNumber,
        'invoiceDate': invoiceDate?.toIso8601String(),
        'payments': payments.map((p) => p.toJson()).toList(),
        'adjustments': adjustments.map((a) => a.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

/// Comprehensive commission summary metrics for broker dashboard.
@immutable
class CommissionSummary {
  final double totalEligibleCommission;
  final double totalInvoicedCommission;
  final double totalReceivedCommission;
  final double totalOutstandingCommission;
  final double totalDisputedCommission;
  final int totalDealsCount;
  final double totalEligibleQuantityMT;
  final double totalGrossDealValuation;
  final String period;

  const CommissionSummary({
    required this.totalEligibleCommission,
    required this.totalInvoicedCommission,
    required this.totalReceivedCommission,
    required this.totalOutstandingCommission,
    required this.totalDisputedCommission,
    required this.totalDealsCount,
    required this.totalEligibleQuantityMT,
    required this.totalGrossDealValuation,
    this.period = 'All Time',
  });

  factory CommissionSummary.fromRecords(List<CommissionRecord> records, {String period = 'All Time'}) {
    double eligible = 0.0;
    double invoiced = 0.0;
    double received = 0.0;
    double outstanding = 0.0;
    double disputed = 0.0;
    double eligibleMT = 0.0;
    double grossValuation = 0.0;

    for (final r in records) {
      eligible += r.eligibleCommission;
      invoiced += r.invoicedAmount;
      received += r.paidAmount;
      outstanding += r.outstandingAmount;
      disputed += r.disputedAmount;
      eligibleMT += r.quantities.eligibleDeliveredQuantityMT;
      grossValuation += r.grossRawMaterialValue;
    }

    return CommissionSummary(
      totalEligibleCommission: double.parse(eligible.toStringAsFixed(2)),
      totalInvoicedCommission: double.parse(invoiced.toStringAsFixed(2)),
      totalReceivedCommission: double.parse(received.toStringAsFixed(2)),
      totalOutstandingCommission: double.parse(outstanding.toStringAsFixed(2)),
      totalDisputedCommission: double.parse(disputed.toStringAsFixed(2)),
      totalDealsCount: records.length,
      totalEligibleQuantityMT: double.parse(eligibleMT.toStringAsFixed(2)),
      totalGrossDealValuation: double.parse(grossValuation.toStringAsFixed(2)),
      period: period,
    );
  }

  factory CommissionSummary.zero({String period = 'All Time'}) {
    return CommissionSummary(
      totalEligibleCommission: 0.0,
      totalInvoicedCommission: 0.0,
      totalReceivedCommission: 0.0,
      totalOutstandingCommission: 0.0,
      totalDisputedCommission: 0.0,
      totalDealsCount: 0,
      totalEligibleQuantityMT: 0.0,
      totalGrossDealValuation: 0.0,
      period: period,
    );
  }
}

/// DTO for logging a new commission payment transaction.
class LogPaymentDto {
  final String dealId;
  final String? bookingReference;
  final double amount;
  final String referenceNumber;
  final DateTime paymentDate;
  final String direction;
  final String? notes;

  const LogPaymentDto({
    required this.dealId,
    this.bookingReference,
    required this.amount,
    required this.referenceNumber,
    required this.paymentDate,
    this.direction = 'Buyer to Broker',
    this.notes,
  });

  String? validate() {
    if (dealId.trim().isEmpty) return 'Deal ID is required';
    if (amount <= 0) return 'Payment amount must be greater than zero';
    if (referenceNumber.trim().isEmpty) return 'Reference / UTR number is required';
    if (referenceNumber.trim().length < 4) {
      return 'Please enter a valid reference / UTR number (at least 4 characters)';
    }
    return null;
  }
}
