import 'package:flutter/foundation.dart';
import '../../work/domain/unit_utils.dart';

/// Status of a brokerage commission invoice.
/// Strictly compatible with backend financial records and statutory accounting standards.
enum InvoiceStatus {
  draft('draft', 'Draft', 'Draft saved, not yet officially issued to counterparty'),
  issued('issued', 'Issued', 'Formally issued to counterparty, payment receivable'),
  partiallyPaid('partially_paid', 'Partially Paid', 'Partial payment received and reconciled'),
  paid('paid', 'Paid', 'Fully paid and reconciled'),
  overdue('overdue', 'Overdue', 'Past payment due date without full settlement'),
  disputed('disputed', 'Disputed', 'Invoice questioned or disputed by counterparty'),
  cancelledOrCredited('cancelled', 'Cancelled / Credited', 'Voided or adjusted via credit note');

  final String code;
  final String displayLabel;
  final String description;

  const InvoiceStatus(this.code, this.displayLabel, this.description);

  bool get isReceivable =>
      this == InvoiceStatus.issued ||
      this == InvoiceStatus.partiallyPaid ||
      this == InvoiceStatus.overdue;

  bool get canAcceptPayment =>
      this == InvoiceStatus.issued ||
      this == InvoiceStatus.partiallyPaid ||
      this == InvoiceStatus.overdue;

  bool get isFinal =>
      this == InvoiceStatus.paid || this == InvoiceStatus.cancelledOrCredited;

  static InvoiceStatus fromString(String? val) {
    if (val == null) return InvoiceStatus.draft;
    final clean = val.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    switch (clean) {
      case 'draft':
        return InvoiceStatus.draft;
      case 'issued':
      case 'open':
      case 'sent':
        return InvoiceStatus.issued;
      case 'partially_paid':
      case 'part_paid':
      case 'partiallypaid':
        return InvoiceStatus.partiallyPaid;
      case 'paid':
      case 'settled':
      case 'closed':
        return InvoiceStatus.paid;
      case 'overdue':
        return InvoiceStatus.overdue;
      case 'disputed':
      case 'dispute':
        return InvoiceStatus.disputed;
      case 'cancelled':
      case 'credited':
      case 'void':
      case 'cancelled_or_credited':
        return InvoiceStatus.cancelledOrCredited;
      default:
        return InvoiceStatus.draft;
    }
  }
}

/// A line item on a brokerage commission invoice.
@immutable
class InvoiceLineItem {
  final String id;
  final String description;
  final double quantity;
  final String unit;
  final double unitRate;
  final double amount;

  const InvoiceLineItem({
    required this.id,
    required this.description,
    required this.quantity,
    this.unit = 'MT',
    required this.unitRate,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'quantity': quantity,
        'unit': unit,
        'unitRate': unitRate,
        'amount': amount,
      };

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItem(
      id: json['id'] as String? ?? 'item-${DateTime.now().millisecondsSinceEpoch}',
      description: json['description'] as String? ?? 'Brokerage Commission',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? 'MT',
      unitRate: (json['unitRate'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Immutable audit entry for commission invoices.
@immutable
class InvoiceAuditEntry {
  final String id;
  final String action;
  final String description;
  final String actor;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const InvoiceAuditEntry({
    required this.id,
    required this.action,
    required this.description,
    required this.actor,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'description': description,
        'actor': actor,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };

  factory InvoiceAuditEntry.fromJson(Map<String, dynamic> json) {
    return InvoiceAuditEntry(
      id: json['id'] as String? ?? 'audit-${DateTime.now().millisecondsSinceEpoch}',
      action: json['action'] as String? ?? 'update',
      description: json['description'] as String? ?? '',
      actor: json['actor'] as String? ?? 'Broker Desk',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Domain model representing a verified, deal-linked commission invoice.
@immutable
class CommissionInvoice {
  final String id;
  final String invoiceNumber;
  final String dealId;
  final String dealReference;
  final String bookingReference;
  final String? commissionRecordId;
  final String billedToParty; // e.g. "Buyer Enterprise", "Seller Enterprise", or "Dual"
  final String buyerCompanyName;
  final String sellerCompanyName;
  final String commodityName;
  final String gradeName;
  final double eligibleDeliveredQuantity;
  final double agreedRatePerMT;
  final String calculationBasis;
  final List<InvoiceLineItem> lineItems;
  final double subtotalAmount;
  final double taxAmount; // Strictly 0.0 unless approved statutory GST rate exists
  final double totalAmount;
  final double paidAmount;
  final double creditedAmount;
  final double outstandingAmount;
  final double disputedAmount;
  final InvoiceStatus status;
  final DateTime issueDate;
  final DateTime dueDate;
  final DateTime? paidAt;
  final String currency;
  final String? notes;
  final List<String> paymentReferences; // UTRs
  final List<InvoiceAuditEntry> auditTrail;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommissionInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.dealId,
    required this.dealReference,
    required this.bookingReference,
    this.commissionRecordId,
    required this.billedToParty,
    required this.buyerCompanyName,
    required this.sellerCompanyName,
    required this.commodityName,
    required this.gradeName,
    required this.eligibleDeliveredQuantity,
    required this.agreedRatePerMT,
    this.calculationBasis = '₹/MT',
    required this.lineItems,
    required this.subtotalAmount,
    this.taxAmount = 0.0,
    required this.totalAmount,
    this.paidAmount = 0.0,
    this.creditedAmount = 0.0,
    required this.outstandingAmount,
    this.disputedAmount = 0.0,
    required this.status,
    required this.issueDate,
    required this.dueDate,
    this.paidAt,
    this.currency = 'INR',
    this.notes,
    this.paymentReferences = const [],
    this.auditTrail = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOverdue =>
      status.isReceivable && DateTime.now().isAfter(dueDate);

  bool get isFullyPaid => outstandingAmount <= 0.01;

  String get formattedInvoiceNumber => invoiceNumber;

  String get calculationFormula =>
      '${UnitUtils.format(eligibleDeliveredQuantity, 'MT')} × ₹${agreedRatePerMT.toStringAsFixed(0)} $calculationBasis';

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoiceNumber': invoiceNumber,
        'dealId': dealId,
        'dealReference': dealReference,
        'bookingReference': bookingReference,
        'commissionRecordId': commissionRecordId,
        'billedToParty': billedToParty,
        'buyerCompanyName': buyerCompanyName,
        'sellerCompanyName': sellerCompanyName,
        'commodityName': commodityName,
        'gradeName': gradeName,
        'eligibleDeliveredQuantity': eligibleDeliveredQuantity,
        'agreedRatePerMT': agreedRatePerMT,
        'calculationBasis': calculationBasis,
        'lineItems': lineItems.map((e) => e.toJson()).toList(),
        'subtotalAmount': subtotalAmount,
        'taxAmount': taxAmount,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'creditedAmount': creditedAmount,
        'outstandingAmount': outstandingAmount,
        'disputedAmount': disputedAmount,
        'status': status.code,
        'issueDate': issueDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'paidAt': paidAt?.toIso8601String(),
        'currency': currency,
        'notes': notes,
        'paymentReferences': paymentReferences,
        'auditTrail': auditTrail.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CommissionInvoice.fromJson(Map<String, dynamic> json) {
    final eligibleQty = (json['eligibleDeliveredQuantity'] as num?)?.toDouble() ?? 0.0;
    final rate = (json['agreedRatePerMT'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (json['subtotalAmount'] as num?)?.toDouble() ?? (eligibleQty * rate);
    final tax = (json['taxAmount'] as num?)?.toDouble() ?? 0.0;
    final total = (json['totalAmount'] as num?)?.toDouble() ?? (subtotal + tax);
    final paid = (json['paidAmount'] as num?)?.toDouble() ?? 0.0;
    final credited = (json['creditedAmount'] as num?)?.toDouble() ?? 0.0;
    final outstanding = (json['outstandingAmount'] as num?)?.toDouble() ?? (total - paid - credited).clamp(0.0, double.infinity);

    final rawLineItems = json['lineItems'] as List<dynamic>?;
    final items = rawLineItems != null
        ? rawLineItems
            .map((e) => InvoiceLineItem.fromJson(e as Map<String, dynamic>))
            .toList()
        : [
            InvoiceLineItem(
              id: 'item-1',
              description: 'Brokerage commission on ${(json['commodityName'] ?? 'Commodity')} (${(json['gradeName'] ?? '')})',
              quantity: eligibleQty,
              unitRate: rate,
              amount: subtotal,
            ),
          ];

    final rawAudit = json['auditTrail'] as List<dynamic>?;
    final audit = rawAudit != null
        ? rawAudit
            .map((e) => InvoiceAuditEntry.fromJson(e as Map<String, dynamic>))
            .toList()
        : <InvoiceAuditEntry>[];

    final rawPayments = json['paymentReferences'] as List<dynamic>?;
    final payments = rawPayments != null
        ? rawPayments.map((e) => e.toString()).toList()
        : <String>[];

    return CommissionInvoice(
      id: json['id'] as String? ?? 'inv-${DateTime.now().millisecondsSinceEpoch}',
      invoiceNumber: json['invoiceNumber'] as String? ?? 'INV-2026-0000',
      dealId: json['dealId'] as String? ?? '',
      dealReference: json['dealReference'] as String? ?? '',
      bookingReference: json['bookingReference'] as String? ?? '',
      commissionRecordId: json['commissionRecordId'] as String?,
      billedToParty: json['billedToParty'] as String? ?? 'Buyer Enterprise',
      buyerCompanyName: json['buyerCompanyName'] as String? ?? 'Buyer Enterprise',
      sellerCompanyName: json['sellerCompanyName'] as String? ?? 'Seller Enterprise',
      commodityName: json['commodityName'] as String? ?? 'Commodity',
      gradeName: json['gradeName'] as String? ?? 'Standard Grade',
      eligibleDeliveredQuantity: eligibleQty,
      agreedRatePerMT: rate,
      calculationBasis: json['calculationBasis'] as String? ?? '₹/MT',
      lineItems: items,
      subtotalAmount: subtotal,
      taxAmount: tax,
      totalAmount: total,
      paidAmount: paid,
      creditedAmount: credited,
      outstandingAmount: outstanding,
      disputedAmount: (json['disputedAmount'] as num?)?.toDouble() ?? 0.0,
      status: InvoiceStatus.fromString(json['status'] as String?),
      issueDate: json['issueDate'] != null
          ? DateTime.tryParse(json['issueDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String) ??
              DateTime.now().add(const Duration(days: 15))
          : DateTime.now().add(const Duration(days: 15)),
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'] as String)
          : null,
      currency: json['currency'] as String? ?? 'INR',
      notes: json['notes'] as String?,
      paymentReferences: payments,
      auditTrail: audit,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  CommissionInvoice copyWith({
    String? billedToParty,
    double? paidAmount,
    double? creditedAmount,
    double? outstandingAmount,
    double? disputedAmount,
    InvoiceStatus? status,
    DateTime? dueDate,
    DateTime? paidAt,
    String? notes,
    List<String>? paymentReferences,
    List<InvoiceAuditEntry>? auditTrail,
    DateTime? updatedAt,
  }) {
    return CommissionInvoice(
      id: id,
      invoiceNumber: invoiceNumber,
      dealId: dealId,
      dealReference: dealReference,
      bookingReference: bookingReference,
      commissionRecordId: commissionRecordId,
      billedToParty: billedToParty ?? this.billedToParty,
      buyerCompanyName: buyerCompanyName,
      sellerCompanyName: sellerCompanyName,
      commodityName: commodityName,
      gradeName: gradeName,
      eligibleDeliveredQuantity: eligibleDeliveredQuantity,
      agreedRatePerMT: agreedRatePerMT,
      calculationBasis: calculationBasis,
      lineItems: lineItems,
      subtotalAmount: subtotalAmount,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      creditedAmount: creditedAmount ?? this.creditedAmount,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      disputedAmount: disputedAmount ?? this.disputedAmount,
      status: status ?? this.status,
      issueDate: issueDate,
      dueDate: dueDate ?? this.dueDate,
      paidAt: paidAt ?? this.paidAt,
      currency: currency,
      notes: notes ?? this.notes,
      paymentReferences: paymentReferences ?? this.paymentReferences,
      auditTrail: auditTrail ?? this.auditTrail,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// DTO for creating an invoice from an eligible commission record.
class CreateInvoiceDto {
  final String dealId;
  final String dealReference;
  final String bookingReference;
  final String? commissionRecordId;
  final String billedToParty;
  final String buyerCompanyName;
  final String sellerCompanyName;
  final String commodityName;
  final String gradeName;
  final double eligibleDeliveredQuantity;
  final double agreedRatePerMT;
  final String calculationBasis;
  final DateTime dueDate;
  final String? notes;

  const CreateInvoiceDto({
    required this.dealId,
    required this.dealReference,
    required this.bookingReference,
    this.commissionRecordId,
    required this.billedToParty,
    required this.buyerCompanyName,
    required this.sellerCompanyName,
    required this.commodityName,
    required this.gradeName,
    required this.eligibleDeliveredQuantity,
    required this.agreedRatePerMT,
    this.calculationBasis = '₹/MT',
    required this.dueDate,
    this.notes,
  });

  double get calculatedSubtotal => eligibleDeliveredQuantity * agreedRatePerMT;

  CreateInvoiceDto copyWith({
    String? dealId,
    String? dealReference,
    String? bookingReference,
    String? commissionRecordId,
    String? billedToParty,
    String? buyerCompanyName,
    String? sellerCompanyName,
    String? commodityName,
    String? gradeName,
    double? eligibleDeliveredQuantity,
    double? agreedRatePerMT,
    String? calculationBasis,
    DateTime? dueDate,
    String? notes,
  }) {
    return CreateInvoiceDto(
      dealId: dealId ?? this.dealId,
      dealReference: dealReference ?? this.dealReference,
      bookingReference: bookingReference ?? this.bookingReference,
      commissionRecordId: commissionRecordId ?? this.commissionRecordId,
      billedToParty: billedToParty ?? this.billedToParty,
      buyerCompanyName: buyerCompanyName ?? this.buyerCompanyName,
      sellerCompanyName: sellerCompanyName ?? this.sellerCompanyName,
      commodityName: commodityName ?? this.commodityName,
      gradeName: gradeName ?? this.gradeName,
      eligibleDeliveredQuantity:
          eligibleDeliveredQuantity ?? this.eligibleDeliveredQuantity,
      agreedRatePerMT: agreedRatePerMT ?? this.agreedRatePerMT,
      calculationBasis: calculationBasis ?? this.calculationBasis,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
    );
  }

  String? validate() {
    if (dealId.trim().isEmpty) return 'Deal identifier is required';
    if (dealReference.trim().isEmpty) return 'Deal reference is required';
    if (eligibleDeliveredQuantity <= 0) {
      return 'Cannot create invoice: eligible delivered quantity must be greater than zero';
    }
    if (agreedRatePerMT <= 0) {
      return 'Agreed commission rate must be greater than zero';
    }
    if (dueDate.isBefore(DateTime.now().subtract(const Duration(hours: 1)))) {
      return 'Invoice due date cannot be in the past';
    }
    return null;
  }
}

/// DTO for applying a credit note or adjustment to an issued invoice.
class ApplyCreditNoteDto {
  final String invoiceId;
  final double creditAmount;
  final String reason;
  final String authorizedBy;

  const ApplyCreditNoteDto({
    required this.invoiceId,
    required this.creditAmount,
    required this.reason,
    required this.authorizedBy,
  });

  String? validate(CommissionInvoice invoice) {
    if (creditAmount <= 0) {
      return 'Credit amount must be greater than zero';
    }
    if (creditAmount > invoice.outstandingAmount) {
      return 'Credit amount (₹${creditAmount.toStringAsFixed(2)}) exceeds invoice outstanding balance (₹${invoice.outstandingAmount.toStringAsFixed(2)})';
    }
    if (reason.trim().length < 5) {
      return 'A detailed business reason is required for applying credit adjustments';
    }
    return null;
  }
}
