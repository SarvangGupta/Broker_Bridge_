/// Domain model representing sales metrics, commission totals, and settlement summaries across reporting periods.
class SalesReportSummary {
  final String period; // 'Weekly', 'Monthly', 'Quarterly', 'Yearly', 'Custom'
  final DateTime startDate;
  final DateTime endDate;
  final double totalSoldVolumeMT;
  final int completedDealsCount;
  final int activeDealsCount;
  final int cancelledDealsCount;
  final double grossSalesValue;
  final double settledAmount;
  final double pendingAmount;

  // Commission Metrics
  final double totalAgreedCommission;
  final double totalCommissionPaid;
  final double totalCommissionOutstanding;

  const SalesReportSummary({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalSoldVolumeMT,
    required this.completedDealsCount,
    required this.activeDealsCount,
    required this.cancelledDealsCount,
    required this.grossSalesValue,
    required this.settledAmount,
    required this.pendingAmount,
    required this.totalAgreedCommission,
    required this.totalCommissionPaid,
    required this.totalCommissionOutstanding,
  });

  int get totalDealsCount =>
      completedDealsCount + activeDealsCount + cancelledDealsCount;

  double get settlementPercentage =>
      grossSalesValue > 0 ? (settledAmount / grossSalesValue) * 100 : 0.0;
}

/// Item representing a discrete commercial deal transaction for the historical sales list.
/// STRICT COUNTERPARTY SHIELD INVARIANT:
/// Buyer identity and direct contact information are strictly omitted.
class SalesTransactionItem {
  final String dealId;
  final String bookingReference;
  final String commodityName;
  final String gradeName;
  final double quantityMT;
  final double ratePerMT;
  final double grossAmount;
  final String? invoiceNo;
  final String? invoiceId;
  final String? invoiceStatus; // 'Paid', 'Pending'
  final String brokerDeskName;
  final String
  status; // 'Settled', 'In Transit', 'Dispatch Pending', 'Cancelled'
  final DateTime date;
  final double? commissionRate;
  final String commissionBasis;
  final double commissionAmount;
  final double commissionPaid;
  final double commissionOutstanding;

  const SalesTransactionItem({
    required this.dealId,
    required this.bookingReference,
    required this.commodityName,
    required this.gradeName,
    required this.quantityMT,
    required this.ratePerMT,
    required this.grossAmount,
    this.invoiceNo,
    this.invoiceId,
    this.invoiceStatus,
    required this.brokerDeskName,
    required this.status,
    required this.date,
    this.commissionRate,
    this.commissionBasis = '₹/MT',
    this.commissionAmount = 0.0,
    this.commissionPaid = 0.0,
    this.commissionOutstanding = 0.0,
  });

  bool get isCompleted =>
      status.toLowerCase() == 'completed' ||
      status.toLowerCase() == 'delivered' ||
      status.toLowerCase() == 'settled';

  bool get isCancelled =>
      status.toLowerCase() == 'cancelled' || status.toLowerCase() == 'rejected';

  bool get isActive => !isCompleted && !isCancelled;
}
