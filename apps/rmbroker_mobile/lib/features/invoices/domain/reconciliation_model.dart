import 'package:flutter/foundation.dart';
import 'invoice_model.dart';

/// Status of financial reconciliation on an invoice or deal record.
enum ReconciliationStatus {
  fullyReconciled('fully_reconciled', 'Fully Reconciled (Paid)', 'Payments and credits match invoice total'),
  partiallyReconciled('partially_reconciled', 'Partially Reconciled', 'Partial payments recorded, outstanding remains'),
  unreconciled('unreconciled', 'Unreconciled (Unpaid)', 'No payments recorded against issued invoice'),
  overpaid('overpaid', 'Overpaid / Credit Balance', 'Recorded payments exceed invoice total'),
  disputedException('disputed_exception', 'Dispute Withheld', 'Dispute active on underlying delivery quantities');

  final String code;
  final String displayLabel;
  final String description;

  const ReconciliationStatus(this.code, this.displayLabel, this.description);
}

/// Severity classification for reconciliation exceptions.
enum InconsistencySeverity {
  info('info', 'Informational'),
  warning('warning', 'Review Required'),
  critical('critical', 'Critical Exception');

  final String code;
  final String displayLabel;

  const InconsistencySeverity(this.code, this.displayLabel);
}

/// An inconsistency or discrepancy detected during automated financial reconciliation.
@immutable
class ReconciliationInconsistency {
  final String id;
  final String? invoiceId;
  final String invoiceNumber;
  final String dealReference;
  final String counterparty;
  final String ruleViolation;
  final InconsistencySeverity severity;
  final String description;
  final double invoiceAmount;
  final double recordedPayments;
  final double variance;
  final String suggestedResolution;
  final DateTime detectedAt;

  const ReconciliationInconsistency({
    required this.id,
    this.invoiceId,
    required this.invoiceNumber,
    required this.dealReference,
    required this.counterparty,
    required this.ruleViolation,
    required this.severity,
    required this.description,
    required this.invoiceAmount,
    required this.recordedPayments,
    required this.variance,
    required this.suggestedResolution,
    required this.detectedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoiceId': invoiceId,
        'invoiceNumber': invoiceNumber,
        'dealReference': dealReference,
        'counterparty': counterparty,
        'ruleViolation': ruleViolation,
        'severity': severity.code,
        'description': description,
        'invoiceAmount': invoiceAmount,
        'recordedPayments': recordedPayments,
        'variance': variance,
        'suggestedResolution': suggestedResolution,
        'detectedAt': detectedAt.toIso8601String(),
      };

  factory ReconciliationInconsistency.fromJson(Map<String, dynamic> json) {
    return ReconciliationInconsistency(
      id: json['id'] as String? ?? 'inc-${DateTime.now().millisecondsSinceEpoch}',
      invoiceId: json['invoiceId'] as String?,
      invoiceNumber: json['invoiceNumber'] as String? ?? 'N/A',
      dealReference: json['dealReference'] as String? ?? 'N/A',
      counterparty: json['counterparty'] as String? ?? 'Counterparty',
      ruleViolation: json['ruleViolation'] as String? ?? 'General Variance',
      severity: InconsistencySeverity.values.firstWhere(
        (s) => s.code == json['severity'],
        orElse: () => InconsistencySeverity.warning,
      ),
      description: json['description'] as String? ?? '',
      invoiceAmount: (json['invoiceAmount'] as num?)?.toDouble() ?? 0.0,
      recordedPayments: (json['recordedPayments'] as num?)?.toDouble() ?? 0.0,
      variance: (json['variance'] as num?)?.toDouble() ?? 0.0,
      suggestedResolution: json['suggestedResolution'] as String? ?? 'Audit payment history',
      detectedAt: json['detectedAt'] != null
          ? DateTime.tryParse(json['detectedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Single item in the reconciliation overview.
@immutable
class ReconciliationItem {
  final CommissionInvoice invoice;
  final ReconciliationStatus status;
  final double variance;
  final bool hasException;

  const ReconciliationItem({
    required this.invoice,
    required this.status,
    required this.variance,
    this.hasException = false,
  });
}

/// Overall financial reconciliation report across invoices, payments, and credits.
@immutable
class FinancialReconciliationSummary {
  final int totalInvoicesCount;
  final int fullyPaidCount;
  final int partiallyPaidCount;
  final int unpaidCount;
  final int overpaidCount;
  final int disputedCount;
  final double totalInvoicedAmount;
  final double totalReconciledPaidAmount;
  final double totalCreditedAmount;
  final double totalOutstandingBalance;
  final double totalOverpaidVariance;
  final List<ReconciliationItem> items;
  final List<ReconciliationInconsistency> inconsistencies;

  const FinancialReconciliationSummary({
    required this.totalInvoicesCount,
    required this.fullyPaidCount,
    required this.partiallyPaidCount,
    required this.unpaidCount,
    required this.overpaidCount,
    required this.disputedCount,
    required this.totalInvoicedAmount,
    required this.totalReconciledPaidAmount,
    required this.totalCreditedAmount,
    required this.totalOutstandingBalance,
    required this.totalOverpaidVariance,
    required this.items,
    required this.inconsistencies,
  });

  /// Factory computing reconciliation summary from invoices.
  factory FinancialReconciliationSummary.fromInvoices(List<CommissionInvoice> invoices) {
    int fullyPaid = 0;
    int partiallyPaid = 0;
    int unpaid = 0;
    int overpaid = 0;
    int disputed = 0;

    double totalInvoiced = 0.0;
    double totalPaid = 0.0;
    double totalCredited = 0.0;
    double totalOutstanding = 0.0;
    double totalOverpaid = 0.0;

    final items = <ReconciliationItem>[];
    final inconsistencies = <ReconciliationInconsistency>[];

    for (final inv in invoices) {
      totalInvoiced += inv.totalAmount;
      totalPaid += inv.paidAmount;
      totalCredited += inv.creditedAmount;
      totalOutstanding += inv.outstandingAmount;

      final netDue = inv.totalAmount - inv.creditedAmount;
      final variance = inv.paidAmount - netDue;

      ReconciliationStatus status;
      bool hasException = false;

      if (inv.status == InvoiceStatus.disputed || inv.disputedAmount > 0) {
        status = ReconciliationStatus.disputedException;
        disputed++;
        hasException = true;
        inconsistencies.add(ReconciliationInconsistency(
          id: 'exc-disp-${inv.id}',
          invoiceId: inv.id,
          invoiceNumber: inv.invoiceNumber,
          dealReference: inv.dealReference,
          counterparty: inv.buyerCompanyName,
          ruleViolation: 'Active Delivery Dispute',
          severity: InconsistencySeverity.warning,
          description: 'Invoice is held under dispute for ₹${inv.disputedAmount.toStringAsFixed(2)}.',
          invoiceAmount: inv.totalAmount,
          recordedPayments: inv.paidAmount,
          variance: inv.disputedAmount,
          suggestedResolution: 'Hold settlement until formal delivery arbitration sign-off.',
          detectedAt: DateTime.now(),
        ));
      } else if (variance > 0.01) {
        // Overpaid! Recorded payments exceed invoice due amount
        status = ReconciliationStatus.overpaid;
        overpaid++;
        totalOverpaid += variance;
        hasException = true;
        inconsistencies.add(ReconciliationInconsistency(
          id: 'exc-over-${inv.id}',
          invoiceId: inv.id,
          invoiceNumber: inv.invoiceNumber,
          dealReference: inv.dealReference,
          counterparty: inv.buyerCompanyName,
          ruleViolation: 'Overpayment Detected',
          severity: InconsistencySeverity.critical,
          description: 'Recorded payments (₹${inv.paidAmount.toStringAsFixed(2)}) exceed invoice total (₹${netDue.toStringAsFixed(2)}) by ₹${variance.toStringAsFixed(2)}.',
          invoiceAmount: inv.totalAmount,
          recordedPayments: inv.paidAmount,
          variance: variance,
          suggestedResolution: 'Review UTR records or allocate credit to counterparty ledger.',
          detectedAt: DateTime.now(),
        ));
      } else if (inv.paidAmount >= netDue - 0.01 && netDue > 0) {
        status = ReconciliationStatus.fullyReconciled;
        fullyPaid++;
      } else if (inv.paidAmount > 0) {
        status = ReconciliationStatus.partiallyReconciled;
        partiallyPaid++;
      } else {
        status = ReconciliationStatus.unreconciled;
        unpaid++;
      }

      items.add(ReconciliationItem(
        invoice: inv,
        status: status,
        variance: variance,
        hasException: hasException,
      ));
    }

    return FinancialReconciliationSummary(
      totalInvoicesCount: invoices.length,
      fullyPaidCount: fullyPaid,
      partiallyPaidCount: partiallyPaid,
      unpaidCount: unpaid,
      overpaidCount: overpaid,
      disputedCount: disputed,
      totalInvoicedAmount: totalInvoiced,
      totalReconciledPaidAmount: totalPaid,
      totalCreditedAmount: totalCredited,
      totalOutstandingBalance: totalOutstanding,
      totalOverpaidVariance: totalOverpaid,
      items: items,
      inconsistencies: inconsistencies,
    );
  }
}
