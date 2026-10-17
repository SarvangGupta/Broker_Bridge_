import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:rmbroker_mobile/features/work/domain/match_model.dart';
import 'package:rmbroker_mobile/features/work/domain/offer_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';

void main() {
  group('Requirement-to-Offer Matching Engine Tests (Sprint RB-FL-07)', () {
    late RequirementItem activeRequirement;
    late RequirementItem expiredRequirement;
    late RequirementItem cancelledRequirement;
    late List<OfferItem> candidateOffers;
    late WorkRepository repository;

    setUp(() {
      repository = WorkRepository();

      activeRequirement = RequirementItem(
        id: 'req-001',
        ref: 'REQ-2026-001',
        buyerCompanyId: 'buyer-001',
        buyerCompanyName: 'AgrInnovate Flour Mills',
        isBuyerVerified: true,
        buyerTrustScore: 95,
        commodityId: 'comm-wheat',
        commodityName: 'Sharbati Wheat',
        gradeId: 'grade-a',
        gradeName: 'Grade A Milling',
        requestedQuantity: 50.0,
        allocatedQuantity: 0.0,
        remainingQuantity: 50.0,
        unitId: 'unit-mt',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        targetPrice: 2800.0,
        deliveryTerms: 'FOR Jaipur Mandi',
        targetDate: DateTime.now().add(const Duration(days: 7)),
        targetDateFormatted: '24 Oct 2026',
        isUrgent: false,
        hoursUntilTarget: 168,
        isExpired: false,
        status: RequirementStatus.open,
        createdAt: DateTime.now(),
      );

      expiredRequirement = RequirementItem(
        id: 'req-002',
        ref: 'REQ-2026-002',
        buyerCompanyId: 'buyer-001',
        buyerCompanyName: 'AgrInnovate Flour Mills',
        isBuyerVerified: true,
        buyerTrustScore: 95,
        commodityId: 'comm-wheat',
        commodityName: 'Sharbati Wheat',
        gradeId: 'grade-a',
        gradeName: 'Grade A Milling',
        requestedQuantity: 50.0,
        allocatedQuantity: 0.0,
        remainingQuantity: 50.0,
        unitId: 'unit-mt',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        targetPrice: 2800.0,
        deliveryTerms: 'FOR Jaipur Mandi',
        targetDate: DateTime.now().subtract(const Duration(days: 1)),
        targetDateFormatted: '16 Oct 2026',
        isUrgent: false,
        hoursUntilTarget: -24,
        isExpired: true,
        status: RequirementStatus.expired,
        createdAt: DateTime.now(),
      );

      cancelledRequirement = RequirementItem(
        id: 'req-003',
        ref: 'REQ-2026-003',
        buyerCompanyId: 'buyer-001',
        buyerCompanyName: 'AgrInnovate Flour Mills',
        isBuyerVerified: true,
        buyerTrustScore: 95,
        commodityId: 'comm-wheat',
        commodityName: 'Sharbati Wheat',
        gradeId: 'grade-a',
        gradeName: 'Grade A Milling',
        requestedQuantity: 50.0,
        allocatedQuantity: 0.0,
        remainingQuantity: 50.0,
        unitId: 'unit-mt',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        targetPrice: 2800.0,
        deliveryTerms: 'FOR Jaipur Mandi',
        targetDate: DateTime.now().add(const Duration(days: 5)),
        targetDateFormatted: '22 Oct 2026',
        isUrgent: false,
        hoursUntilTarget: 120,
        isExpired: false,
        status: RequirementStatus.cancelled,
        createdAt: DateTime.now(),
      );

      candidateOffers = [
        // Perfect match: same commodity, same grade, asking price <= target
        OfferItem(
          id: 'off-001',
          ref: 'OFF-2026-001',
          lotNumber: 'LOT-2026-001',
          sellerCompanyId: 'seller-001',
          sellerCompanyName: 'Shekhawati Agro Traders',
          isSellerVerified: true,
          sellerTrustScore: 90,
          commodityId: 'comm-wheat',
          commodityName: 'Sharbati Wheat',
          gradeId: 'grade-a',
          gradeName: 'Grade A Milling',
          offeredQuantity: 50.0,
          availableQuantity: 50.0,
          reservedQuantity: 0.0,
          soldQuantity: 0.0,
          unitId: 'unit-mt',
          unitName: 'Metric Tonne',
          unitSymbol: 'MT',
          askingPrice: 2750.0, // <= targetPrice 2800
          confidentialMinimumPrice: 2650.0,
          stateId: 'st-rj',
          stateName: 'Rajasthan',
          districtId: 'dst-jp',
          districtName: 'Jaipur',
          availableFrom: DateTime.now(),
          validUntil: DateTime.now().add(const Duration(days: 10)),
          validUntilFormatted: '27 Oct 2026',
          isExpired: false,
          loadingStatus: LoadingReadiness.readyToLoad,
          status: OfferStatus.open,
          createdAt: DateTime.now(),
        ),
        // Partial match: same commodity, different grade, price higher
        OfferItem(
          id: 'off-002',
          ref: 'OFF-2026-002',
          lotNumber: 'LOT-2026-002',
          sellerCompanyId: 'seller-002',
          sellerCompanyName: 'Apex Cattle Nutrition',
          isSellerVerified: false,
          sellerTrustScore: 75,
          commodityId: 'comm-wheat',
          commodityName: 'Sharbati Wheat',
          gradeId: 'grade-b',
          gradeName: 'Grade B Commercial',
          offeredQuantity: 20.0,
          availableQuantity: 20.0,
          reservedQuantity: 0.0,
          soldQuantity: 0.0,
          unitId: 'unit-mt',
          unitName: 'Metric Tonne',
          unitSymbol: 'MT',
          askingPrice: 2950.0, // > targetPrice 2800
          confidentialMinimumPrice: 2800.0,
          stateId: 'st-rj',
          stateName: 'Rajasthan',
          districtId: 'dst-kt',
          districtName: 'Kota',
          availableFrom: DateTime.now(),
          validUntil: DateTime.now().add(const Duration(days: 5)),
          validUntilFormatted: '22 Oct 2026',
          isExpired: false,
          loadingStatus: LoadingReadiness.notReady,
          status: OfferStatus.open,
          createdAt: DateTime.now(),
        ),
        // Inactive / zero available quantity
        OfferItem(
          id: 'off-004',
          ref: 'OFF-2026-004',
          lotNumber: 'LOT-2026-004',
          sellerCompanyId: 'seller-004',
          sellerCompanyName: 'Sold Out Traders',
          isSellerVerified: true,
          sellerTrustScore: 80,
          commodityId: 'comm-wheat',
          commodityName: 'Sharbati Wheat',
          gradeId: 'grade-a',
          gradeName: 'Grade A Milling',
          offeredQuantity: 100.0,
          availableQuantity: 0.0, // ZERO available
          reservedQuantity: 50.0,
          soldQuantity: 50.0,
          unitId: 'unit-mt',
          unitName: 'Metric Tonne',
          unitSymbol: 'MT',
          askingPrice: 2700.0,
          stateId: 'st-rj',
          stateName: 'Rajasthan',
          districtId: 'dst-jp',
          districtName: 'Jaipur',
          availableFrom: DateTime.now(),
          validUntil: DateTime.now().add(const Duration(days: 10)),
          validUntilFormatted: '27 Oct 2026',
          isExpired: false,
          loadingStatus: LoadingReadiness.notReady,
          status: OfferStatus.unavailable,
          createdAt: DateTime.now(),
        ),
      ];
    });

    test('Expired requirement produces ZERO matches (Lifecycle Safety Enforcement)', () {
      final matches = repository.computeMatches(
        requirement: expiredRequirement,
        availableOffers: candidateOffers,
      );
      expect(matches, isEmpty);
    });

    test('Cancelled requirement produces ZERO matches (Lifecycle Safety Enforcement)', () {
      final matches = repository.computeMatches(
        requirement: cancelledRequirement,
        availableOffers: candidateOffers,
      );
      expect(matches, isEmpty);
    });

    test('Deterministic scoring weights and breakdown', () {
      final match = RequirementMatcher.computeMatch(
        requirement: activeRequirement,
        offer: candidateOffers[0],
      );

      // Commodity weight: 35
      expect(match.breakdown.commodityScore, 35.0);
      // Grade weight: 25
      expect(match.breakdown.gradeScore, 25.0);
      // Price weight: 20 (since asking 2750 <= target 2800)
      expect(match.breakdown.priceScore, 20.0);
      // Location weight: 10 (Jaipur matches)
      expect(match.breakdown.locationScore, 10.0);
      // Quantity weight: 7 (50 MT covers 100% of 50 MT)
      expect(match.breakdown.quantityScore, 7.0);
      // Delivery date timing: 3
      expect(match.breakdown.deliveryDateScore, 3.0);

      expect(match.totalScore, 100.0);
      expect(match.classification, MatchClassification.strongMatch);
      expect(match.coveragePercentage, 100.0);
      expect(match.isAllocationSupported, isFalse);
    });

    test('Partial match yields lower score and highlights unmet criteria', () {
      final match = RequirementMatcher.computeMatch(
        requirement: activeRequirement,
        offer: candidateOffers[1],
      );

      expect(match.totalScore, lessThan(100.0));
      expect(match.breakdown.commodityScore, 35.0);
      // Partial grade variance
      expect(match.breakdown.gradeScore, 10.0);
      // Higher asking price
      expect(match.breakdown.priceScore, lessThan(20.0));
      // Unmet criteria list has warnings
      expect(match.unmetCriteria, isNotEmpty);
    });

    test('CRITICAL QUANTITY SAFETY: Matching does NOT mutate inventory or deal state', () {
      final originalAvailable = candidateOffers[0].availableQuantity;
      final originalReserved = candidateOffers[0].reservedQuantity;
      final originalSold = candidateOffers[0].soldQuantity;
      final originalReqAllocated = activeRequirement.allocatedQuantity;

      // Run match evaluation
      final matches = repository.computeMatches(
        requirement: activeRequirement,
        availableOffers: candidateOffers,
      );

      expect(matches, isNotEmpty);

      // STRICT ZERO-ALLOCATION GUARANTEE: Neither offer nor requirement was altered
      expect(candidateOffers[0].availableQuantity, originalAvailable);
      expect(candidateOffers[0].reservedQuantity, originalReserved);
      expect(candidateOffers[0].soldQuantity, originalSold);
      expect(activeRequirement.allocatedQuantity, originalReqAllocated);
    });
  });
}
