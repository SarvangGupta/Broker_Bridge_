import 'package:flutter/foundation.dart';
import 'offer_model.dart';
import 'requirement_model.dart';
import 'unit_utils.dart';

/// Classification of matching score strength.
enum MatchClassification {
  strongMatch('Strong Match', 'Strong Match', 80),
  goodMatch('Good Match', 'Good Match', 60),
  partialMatch('Partial', 'Partial Match', 40),
  lowMatch('Low', 'Low Match', 0);

  final String label;
  final String displayLabel;
  final int minScore;

  const MatchClassification(this.label, this.displayLabel, this.minScore);

  static MatchClassification fromScore(double score) {
    if (score >= 80) return MatchClassification.strongMatch;
    if (score >= 60) return MatchClassification.goodMatch;
    if (score >= 40) return MatchClassification.partialMatch;
    return MatchClassification.lowMatch;
  }
}

/// Detailed sub-component score breakdown based on ADR-004 / match-engine.ts.
@immutable
class MatchBreakdown {
  final double commodityScore; // Weight: 35%
  final double gradeScore; // Weight: 25%
  final double priceScore; // Weight: 20%
  final double locationScore; // Weight: 10%
  final double quantityScore; // Weight: 7%
  final double deliveryDateScore; // Weight: 3%

  const MatchBreakdown({
    required this.commodityScore,
    required this.gradeScore,
    required this.priceScore,
    required this.locationScore,
    required this.quantityScore,
    required this.deliveryDateScore,
  });

  factory MatchBreakdown.zero() => const MatchBreakdown(
        commodityScore: 0,
        gradeScore: 0,
        priceScore: 0,
        locationScore: 0,
        quantityScore: 0,
        deliveryDateScore: 0,
      );

  Map<String, dynamic> toJson() => {
        'commodity': commodityScore,
        'grade': gradeScore,
        'price': priceScore,
        'location': locationScore,
        'quantity': quantityScore,
        'deliveryDate': deliveryDateScore,
      };
}

/// Domain model representing a computed recommendation match between a requirement and a seller offer.
///
/// CRITICAL QUANTITY SAFETY PRINCIPLE:
/// A match is NOT a reservation, allocation, contract, or completed deal.
/// Displaying or inspecting a match never alters inventory or reserves quantity.
@immutable
class SupplyMatchItem {
  final OfferItem offer;
  final double totalScore; // 0 - 100
  final MatchClassification classification;
  final MatchBreakdown breakdown;

  // Quantity Coverage
  final double requiredQuantityMT;
  final double availableQuantityMT;
  final double coveragePercentage;

  // Price Difference
  final double buyerTargetPrice;
  final double sellerAskingPrice;
  final double priceDifference; // sellerAskingPrice - buyerTargetPrice
  final double priceDifferencePercent;

  // Explanatory Criteria
  final List<String> compatibilityReasons;
  final List<String> unmetCriteria;

  /// Whether authoritative backend allocation is supported in this transaction.
  final bool isAllocationSupported;

  const SupplyMatchItem({
    required this.offer,
    required this.totalScore,
    required this.classification,
    required this.breakdown,
    required this.requiredQuantityMT,
    required this.availableQuantityMT,
    required this.coveragePercentage,
    required this.buyerTargetPrice,
    required this.sellerAskingPrice,
    required this.priceDifference,
    required this.priceDifferencePercent,
    required this.compatibilityReasons,
    required this.unmetCriteria,
    this.isAllocationSupported = false,
  });
}

/// Deterministic Client/Server Matching Algorithm.
///
/// Implements the exact scoring weights specified in `src/server/utils/match-engine.ts`:
/// - Commodity Match: 35 pts
/// - Grade Match: 25 pts
/// - Price Proximity: 20 pts
/// - Location Index: 10 pts
/// - Quantity Match: 7 pts
/// - Delivery Timing: 3 pts
/// Total: 100 pts
class RequirementMatcher {
  const RequirementMatcher._();

  /// Same product master: by id, or by name when an id is missing.
  static bool isSameCommodity(RequirementItem requirement, OfferItem offer) {
    if (requirement.commodityId.isNotEmpty && offer.commodityId.isNotEmpty) {
      return requirement.commodityId == offer.commodityId;
    }
    return requirement.commodityName.trim().toLowerCase() ==
        offer.commodityName.trim().toLowerCase();
  }

  static SupplyMatchItem computeMatch({
    required RequirementItem requirement,
    required OfferItem offer,
  }) {
    final reasons = <String>[];
    final risks = <String>[];

    // 1. Commodity Match (Weight: 35%)
    double commScore = 0.0;
    if (requirement.commodityId == offer.commodityId ||
        requirement.commodityName.toLowerCase() == offer.commodityName.toLowerCase()) {
      commScore = 35.0;
      reasons.add('Exact Commodity Match: ${requirement.commodityName}');
    } else {
      risks.add('Incompatible Commodity: ${offer.commodityName} vs ${requirement.commodityName}');
    }

    // 2. Grade Match (Weight: 25%)
    double gradeScore = 0.0;
    if (requirement.gradeId == offer.gradeId ||
        requirement.gradeName.toLowerCase() == offer.gradeName.toLowerCase()) {
      gradeScore = 25.0;
      reasons.add('Exact Quality Grade Match: ${requirement.gradeName}');
    } else {
      gradeScore = 10.0; // Partial grade tolerance
      risks.add('Grade Variance: Offer is ${offer.gradeName}, Mandate requested ${requirement.gradeName}');
    }

    // 3. Price Proximity (Weight: 20%)
    double priceScore = 0.0;
    final buyerTarget = requirement.targetPrice;
    final sellerAsking = offer.askingPrice;
    final priceDiff = sellerAsking - buyerTarget;
    final priceDiffPct = buyerTarget > 0 ? (priceDiff / buyerTarget) * 100 : 0.0;

    if (sellerAsking <= buyerTarget) {
      priceScore = 20.0;
      final savings = (buyerTarget - sellerAsking).abs();
      reasons.add(
        savings > 0
            ? 'Favorable Price: Asking ₹${sellerAsking.toInt()}/MT is ₹${savings.toInt()} below target'
            : 'At Buyer Target Price: ₹${sellerAsking.toInt()}/MT',
      );
    } else {
      // Asking price is higher than buyer target
      if (priceDiffPct <= 5.0) {
        priceScore = 14.0;
        reasons.add('Close Price Window: Asking price is within 5% of target');
      } else if (priceDiffPct <= 10.0) {
        priceScore = 8.0;
        risks.add('Price Premium: Seller asking is ${priceDiffPct.toStringAsFixed(1)}% above buyer target');
      } else {
        priceScore = 2.0;
        risks.add('High Price Gap: Seller asking is ${priceDiffPct.toStringAsFixed(1)}% above target');
      }
    }

    // 4. Location Proximity (Weight: 10%)
    double locScore = 0.0;
    if (requirement.deliveryTerms.toLowerCase().contains(offer.districtName.toLowerCase()) ||
        requirement.deliveryTerms.toLowerCase().contains(offer.stateName.toLowerCase())) {
      locScore = 10.0;
      reasons.add('Mandi Proximity: Stock located at ${offer.districtName}, ${offer.stateName}');
    } else if (offer.stateName.isNotEmpty) {
      locScore = 6.0;
      reasons.add('Regional Availability: ${offer.stateName}');
    } else {
      locScore = 3.0;
      risks.add('Transit Distance: Delivery terms may require freight adjustment');
    }

    // 5. Quantity Match (Weight: 7%)
    final reqQtyMT = UnitUtils.toMT(
      requirement.remainingQuantity > 0 ? requirement.remainingQuantity : requirement.requestedQuantity,
      requirement.unitSymbol,
    );
    final availQtyMT = UnitUtils.toMT(offer.availableQuantity, offer.unitSymbol);
    final coveragePct = reqQtyMT > 0 ? ((availQtyMT / reqQtyMT) * 100).clamp(0.0, 100.0) : 0.0;

    double qtyScore = 0.0;
    if (availQtyMT >= reqQtyMT) {
      qtyScore = 7.0;
      reasons.add('Full Quantity Coverage: ${availQtyMT.toInt()} MT covers 100% of mandate');
    } else if (coveragePct >= 50.0) {
      qtyScore = 5.0;
      reasons.add('Partial Lot Coverage: ${coveragePct.round()}% of mandate volume available');
    } else {
      qtyScore = 2.0;
      risks.add('Low Volume Coverage: Only ${coveragePct.round()}% of mandate available');
    }

    // 6. Delivery Date Timing (Weight: 3%)
    double dateScore = 0.0;
    final now = DateTime.now();
    if (offer.validUntil.isAfter(now) && !offer.availableFrom.isAfter(requirement.targetDate)) {
      dateScore = 3.0;
      reasons.add('Timing Compatible: Valid through ${offer.validUntilFormatted}');
    } else {
      dateScore = 1.0;
      risks.add('Offer validity window is tight or requires prompt broker confirmation');
    }

    final total = commScore + gradeScore + priceScore + locScore + qtyScore + dateScore;
    final roundedTotal = double.parse(total.toStringAsFixed(1));

    return SupplyMatchItem(
      offer: offer,
      totalScore: roundedTotal,
      classification: MatchClassification.fromScore(roundedTotal),
      breakdown: MatchBreakdown(
        commodityScore: commScore,
        gradeScore: gradeScore,
        priceScore: priceScore,
        locationScore: locScore,
        quantityScore: qtyScore,
        deliveryDateScore: dateScore,
      ),
      requiredQuantityMT: reqQtyMT,
      availableQuantityMT: availQtyMT,
      coveragePercentage: coveragePct,
      buyerTargetPrice: buyerTarget,
      sellerAskingPrice: sellerAsking,
      priceDifference: priceDiff,
      priceDifferencePercent: priceDiffPct,
      compatibilityReasons: reasons,
      unmetCriteria: risks,
      isAllocationSupported: false, // Strictly recommendation-only on mobile client
    );
  }
}
