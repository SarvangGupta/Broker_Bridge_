/// Supported trade units for physical raw material commodities.
enum CommodityUnit {
  metricTonne('MT', 'Metric Tonne', 1.0),
  quintal('Qtl', 'Quintal', 0.1),
  kilogram('Kg', 'Kilogram', 0.001);

  final String symbol;
  final String label;

  /// Conversion multiplier to normalize to 1 Metric Tonne (MT).
  /// 1 MT = 10 Quintals = 1,000 Kilograms.
  final double toMtFactor;

  const CommodityUnit(this.symbol, this.label, this.toMtFactor);

  /// Safe parse from string symbol or label. Defaults to Metric Tonne if unspecified.
  static CommodityUnit fromString(String? val) {
    if (val == null || val.trim().isEmpty) return CommodityUnit.metricTonne;
    final clean = val.trim().toLowerCase();
    for (final u in CommodityUnit.values) {
      if (u.symbol.toLowerCase() == clean || u.label.toLowerCase() == clean) {
        return u;
      }
    }
    if (clean.contains('tonne') || clean.contains('ton') || clean == 'mt') {
      return CommodityUnit.metricTonne;
    }
    if (clean.contains('quintal') || clean.contains('qtl')) {
      return CommodityUnit.quintal;
    }
    if (clean.contains('kilo') || clean.contains('kg')) {
      return CommodityUnit.kilogram;
    }
    return CommodityUnit.metricTonne;
  }
}

/// Strict Quantity and Unit Conversion Utility.
///
/// QUANTITY SAFETY PRINCIPLES:
/// 1. Units are always explicit throughout RMBroker calculations.
/// 2. Verified Mandi Ratio: 1 Metric Tonne (MT) = 10 Quintals = 1,000 Kilograms.
/// 3. Never compare or aggregate quantities without explicit unit normalization.
class UnitUtils {
  const UnitUtils._();

  /// Converts a quantity from one unit to another with high precision.
  /// Throws [ArgumentError] if either quantity is negative or invalid.
  static double convert({
    required double quantity,
    required CommodityUnit from,
    required CommodityUnit to,
  }) {
    if (quantity < 0) {
      throw ArgumentError('Quantity cannot be negative: $quantity');
    }
    if (from == to) return quantity;

    // Convert to normalized MT first
    final inMt = quantity * from.toMtFactor;
    // Then convert to target unit
    return inMt / to.toMtFactor;
  }

  /// Convenience helper to normalize any quantity to Metric Tonnes (MT).
  static double toMT(double quantity, String unitString) {
    final unit = CommodityUnit.fromString(unitString);
    return convert(quantity: quantity, from: unit, to: CommodityUnit.metricTonne);
  }

  /// Convenience helper to normalize any quantity to Quintals.
  static double toQuintals(double quantity, String unitString) {
    final unit = CommodityUnit.fromString(unitString);
    return convert(quantity: quantity, from: unit, to: CommodityUnit.quintal);
  }

  /// Compares two quantities with explicit units.
  /// Returns negative if q1 < q2, zero if q1 == q2, positive if q1 > q2.
  static int compareQuantities({
    required double q1,
    required String unit1,
    required double q2,
    required String unit2,
    double epsilon = 0.0001,
  }) {
    final norm1 = toMT(q1, unit1);
    final norm2 = toMT(q2, unit2);

    final diff = norm1 - norm2;
    if (diff.abs() < epsilon) return 0;
    return diff > 0 ? 1 : -1;
  }

  /// Formats quantity with clean decimal representation and explicit unit.
  /// E.g. `100 MT`, `25.5 Qtl`.
  static String format(
    double quantity,
    String unitString, {
    bool includeUnit = true,
    int maxDecimals = 2,
  }) {
    final unit = CommodityUnit.fromString(unitString);
    final cleanQty = quantity % 1 == 0
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(maxDecimals);

    if (!includeUnit) return cleanQty;
    return '$cleanQty ${unit.symbol}';
  }
}
