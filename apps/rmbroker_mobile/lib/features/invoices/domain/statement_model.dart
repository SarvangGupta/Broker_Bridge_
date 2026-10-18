import 'package:flutter/foundation.dart';

/// Transaction types on a broker commission financial statement.
enum StatementEntryType {
  openingBalance('opening_balance', 'Opening Balance'),
  commissionEarned('commission_earned', 'Commission Accrued / Earned'),
  commissionInvoiced('commission_invoiced', 'Commission Invoiced'),
  paymentReceived('payment_received', 'Payment Received'),
  creditAdjustment('credit_adjustment', 'Credit Note / Adjustment'),
  disputeWithheld('dispute_withheld', 'Disputed Escrow Withheld'),
  closingBalance('closing_balance', 'Closing Outstanding Balance');

  final String code;
  final String displayLabel;

  const StatementEntryType(this.code, this.displayLabel);
}

/// An immutable ledger transaction row on a commission statement.
@immutable
class StatementLedgerItem {
  final String id;
  final DateTime date;
  final StatementEntryType type;
  final String reference; // Invoice number, payment UTR, or adjustment ref
  final String? dealReference;
  final String counterparty;
  final String description;
  final double debit; // Increases receivable (e.g. Invoiced)
  final double credit; // Decreases receivable (e.g. Payment received, Credit note)
  final double runningBalance;

  const StatementLedgerItem({
    required this.id,
    required this.date,
    required this.type,
    required this.reference,
    this.dealReference,
    required this.counterparty,
    required this.description,
    this.debit = 0.0,
    this.credit = 0.0,
    required this.runningBalance,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'type': type.code,
        'reference': reference,
        'dealReference': dealReference,
        'counterparty': counterparty,
        'description': description,
        'debit': debit,
        'credit': credit,
        'runningBalance': runningBalance,
      };

  factory StatementLedgerItem.fromJson(Map<String, dynamic> json) {
    return StatementLedgerItem(
      id: json['id'] as String? ?? 'item-${DateTime.now().millisecondsSinceEpoch}',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      type: StatementEntryType.values.firstWhere(
        (t) => t.code == json['type'],
        orElse: () => StatementEntryType.commissionInvoiced,
      ),
      reference: json['reference'] as String? ?? '',
      dealReference: json['dealReference'] as String?,
      counterparty: json['counterparty'] as String? ?? 'Counterparty',
      description: json['description'] as String? ?? '',
      debit: (json['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
      runningBalance: (json['runningBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Authoritative financial statement for a broker desk across a specified date range.
@immutable
class CommissionStatement {
  final String statementNumber;
  final String brokerDeskName;
  final String mandiHub;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime generatedAt;
  final String currency;
  final double openingBalance;
  final double totalCommissionEarned;
  final double totalCommissionInvoiced;
  final double totalPaymentsReceived;
  final double totalCreditsAndAdjustments;
  final double totalDisputedAmount;
  final double closingOutstandingBalance;
  final List<StatementLedgerItem> items;
  final String fiduciaryDisclosure;

  const CommissionStatement({
    required this.statementNumber,
    this.brokerDeskName = 'Authorized Intermediary Broker Desk',
    this.mandiHub = 'Jaipur Mandi Commodity Exchange',
    required this.startDate,
    required this.endDate,
    required this.generatedAt,
    this.currency = 'INR',
    this.openingBalance = 0.0,
    required this.totalCommissionEarned,
    required this.totalCommissionInvoiced,
    required this.totalPaymentsReceived,
    required this.totalCreditsAndAdjustments,
    required this.totalDisputedAmount,
    required this.closingOutstandingBalance,
    required this.items,
    this.fiduciaryDisclosure =
        'Brokerage commission statement only. Excludes gross buyer-to-seller raw-material trade turnover. '
        'Payment references reflect manually recorded UTR receipts awaiting independent bank reconciliation.',
  });

  /// Mathematical reconciliation check ensuring statement balances tally exactly:
  /// Closing Balance == Opening Balance + Invoiced - Received - Adjustments
  bool get isMathematicallyReconciled {
    final expectedClosing =
        openingBalance + totalCommissionInvoiced - totalPaymentsReceived - totalCreditsAndAdjustments;
    return (closingOutstandingBalance - expectedClosing).abs() < 0.01;
  }

  Map<String, dynamic> toJson() => {
        'statementNumber': statementNumber,
        'brokerDeskName': brokerDeskName,
        'mandiHub': mandiHub,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'generatedAt': generatedAt.toIso8601String(),
        'currency': currency,
        'openingBalance': openingBalance,
        'totalCommissionEarned': totalCommissionEarned,
        'totalCommissionInvoiced': totalCommissionInvoiced,
        'totalPaymentsReceived': totalPaymentsReceived,
        'totalCreditsAndAdjustments': totalCreditsAndAdjustments,
        'totalDisputedAmount': totalDisputedAmount,
        'closingOutstandingBalance': closingOutstandingBalance,
        'items': items.map((e) => e.toJson()).toList(),
        'fiduciaryDisclosure': fiduciaryDisclosure,
      };

  factory CommissionStatement.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>?;
    final parsedItems = rawItems != null
        ? rawItems
            .map((e) => StatementLedgerItem.fromJson(e as Map<String, dynamic>))
            .toList()
        : <StatementLedgerItem>[];

    return CommissionStatement(
      statementNumber: json['statementNumber'] as String? ?? 'STM-2026-0001',
      brokerDeskName: json['brokerDeskName'] as String? ?? 'Authorized Broker Desk',
      mandiHub: json['mandiHub'] as String? ?? 'Jaipur Mandi Commodity Exchange',
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      generatedAt: json['generatedAt'] != null
          ? DateTime.tryParse(json['generatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      currency: json['currency'] as String? ?? 'INR',
      openingBalance: (json['openingBalance'] as num?)?.toDouble() ?? 0.0,
      totalCommissionEarned: (json['totalCommissionEarned'] as num?)?.toDouble() ?? 0.0,
      totalCommissionInvoiced: (json['totalCommissionInvoiced'] as num?)?.toDouble() ?? 0.0,
      totalPaymentsReceived: (json['totalPaymentsReceived'] as num?)?.toDouble() ?? 0.0,
      totalCreditsAndAdjustments: (json['totalCreditsAndAdjustments'] as num?)?.toDouble() ?? 0.0,
      totalDisputedAmount: (json['totalDisputedAmount'] as num?)?.toDouble() ?? 0.0,
      closingOutstandingBalance: (json['closingOutstandingBalance'] as num?)?.toDouble() ?? 0.0,
      items: parsedItems,
      fiduciaryDisclosure: json['fiduciaryDisclosure'] as String? ?? '',
    );
  }
}
