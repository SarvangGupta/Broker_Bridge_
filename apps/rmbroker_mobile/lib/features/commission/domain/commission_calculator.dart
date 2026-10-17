import 'commission_model.dart';

/// Pure mathematical calculation engine for brokerage commission.
///
/// RULES:
/// 1. Commission = eligible delivered quantity (MT) × agreed commission rate per MT.
/// 2. Disputed or rejected quantities are strictly excluded from eligible commission.
/// 3. Rounding: Standard 2 decimal places for currency amounts (₹), 3 decimal places for MT quantities.
/// 4. Unit Conversion: 1 MT = 10 Quintals = 1,000 Kg.
/// 5. Never treat gross raw material deal valuation as brokerage earnings.
class CommissionCalculator {
  const CommissionCalculator._();

  /// Converts any commodity quantity into Metric Tonnes (MT).
  static double normalizeToMT(double quantity, String unitSymbol) {
    if (quantity <= 0) return 0.0;
    final clean = unitSymbol.trim().toUpperCase();
    if (clean == 'MT' || clean == 'METRIC TONNE' || clean == 'TONNE') {
      return double.parse(quantity.toStringAsFixed(3));
    }
    if (clean == 'QTL' || clean == 'QUINTAL' || clean == 'QUINTALS') {
      return double.parse((quantity * 0.1).toStringAsFixed(3));
    }
    if (clean == 'KG' || clean == 'KILOGRAM' || clean == 'KGS') {
      return double.parse((quantity * 0.001).toStringAsFixed(3));
    }
    // Default to MT if unknown standard agricultural unit
    return double.parse(quantity.toStringAsFixed(3));
  }

  /// Calculates eligible delivered quantity from physical fulfillment records.
  /// Deducts rejected and disputed quantities.
  static double calculateEligibleQuantity({
    required double deliveredQuantity,
    double rejectedQuantity = 0.0,
    double disputedQuantity = 0.0,
    double acceptedQuantity = 0.0,
  }) {
    if (acceptedQuantity > 0) {
      return acceptedQuantity;
    }
    final eligible = deliveredQuantity - rejectedQuantity - disputedQuantity;
    return eligible > 0 ? double.parse(eligible.toStringAsFixed(3)) : 0.0;
  }

  /// Calculates commission amount:
  /// `Commission = eligibleDeliveredQuantityMT * agreedRatePerMT`
  static double calculateCommission({
    required double eligibleDeliveredQuantityMT,
    required double agreedRatePerMT,
  }) {
    if (eligibleDeliveredQuantityMT <= 0 || agreedRatePerMT <= 0) {
      return 0.0;
    }
    final raw = eligibleDeliveredQuantityMT * agreedRatePerMT;
    return double.parse(raw.toStringAsFixed(2));
  }

  /// Calculates commission when rate is agreed per quintal:
  /// `1 MT = 10 Quintals`, so `ratePerMT = ratePerQuintal * 10`.
  static double calculateCommissionFromQuintalRate({
    required double eligibleDeliveredQuantityMT,
    required double ratePerQuintal,
  }) {
    final ratePerMT = ratePerQuintal * 10.0;
    return calculateCommission(
      eligibleDeliveredQuantityMT: eligibleDeliveredQuantityMT,
      agreedRatePerMT: ratePerMT,
    );
  }

  /// Calculates outstanding commission balance:
  /// `Outstanding = max(0, totalReceivable - totalPaid)`
  static double calculateOutstanding({
    required double totalReceivable,
    required double totalPaid,
  }) {
    final diff = totalReceivable - totalPaid;
    return diff > 0 ? double.parse(diff.toStringAsFixed(2)) : 0.0;
  }

  /// Evaluates and determines the appropriate commission status according to approved business rules.
  static CommissionStatus determineCommissionStatus({
    required double eligibleDeliveredQuantityMT,
    required double invoicedAmount,
    required double paidAmount,
    required double disputedQuantityMT,
    bool isCancelled = false,
  }) {
    if (isCancelled) {
      return CommissionStatus.adjusted;
    }

    if (disputedQuantityMT > 0 && eligibleDeliveredQuantityMT <= 0) {
      return CommissionStatus.disputed;
    }

    if (paidAmount > 0) {
      final totalTarget = invoicedAmount > 0 ? invoicedAmount : 0.0;
      if (totalTarget > 0 && paidAmount >= totalTarget - 0.01) {
        return CommissionStatus.paid;
      }
      return CommissionStatus.partiallyPaid;
    }

    if (invoicedAmount > 0) {
      return CommissionStatus.invoiced;
    }

    if (eligibleDeliveredQuantityMT > 0) {
      return CommissionStatus.eligible;
    }

    return CommissionStatus.notEligible;
  }

  /// Formats currency with Indian Rupee (₹) symbol and commas.
  static String formatCurrency(double amount) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final parts = absAmount.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    if (integerPart.length <= 3) {
      return '${isNegative ? '-' : ''}₹$integerPart.$decimalPart';
    }

    final lastThree = integerPart.substring(integerPart.length - 3);
    final otherNumbers = integerPart.substring(0, integerPart.length - 3);
    final formattedOther = otherNumbers.replaceAllMapped(
      RegExp(r'\B(?=(\d{2})+(?!\d))'),
      (match) => ',',
    );

    final res = '$formattedOther,$lastThree.$decimalPart';
    return '${isNegative ? '-' : ''}₹$res';
  }
}
