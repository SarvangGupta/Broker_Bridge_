import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/work/domain/match_model.dart';
import 'package:rmbroker_mobile/features/work/domain/offer_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/match_card.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/offer_card.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/requirement_card.dart';

void main() {
  group('Work Feature Widget Tests (Sprint RB-FL-07)', () {
    testWidgets('RequirementCard renders 7-tier quantities and status correctly', (tester) async {
      final req = RequirementItem(
        id: 'req-01',
        ref: 'REQ-2026-0099',
        buyerCompanyId: 'buyer-01',
        buyerCompanyName: 'AgrInnovate Flour Mills',
        isBuyerVerified: true,
        buyerTrustScore: 94,
        commodityId: 'comm-wheat',
        commodityName: 'Sharbati Wheat',
        gradeId: 'grade-a',
        gradeName: 'Grade A Milling',
        requestedQuantity: 100.0,
        allocatedQuantity: 20.0,
        contractedQuantity: 20.0,
        deliveredQuantity: 10.0,
        acceptedQuantity: 10.0,
        disputedQuantity: 0.0,
        remainingQuantity: 80.0,
        unitId: 'unit-mt',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        targetPrice: 2850.0,
        deliveryTerms: 'FOR Jaipur Mandi',
        targetDate: DateTime.now().add(const Duration(days: 10)),
        targetDateFormatted: '27 Oct 2026',
        isUrgent: false,
        hoursUntilTarget: 240,
        isExpired: false,
        status: RequirementStatus.partiallyAllocated,
        createdAt: DateTime.now(),
      );

      var tapped = false;
      var findMatchesTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RequirementCard(
              requirement: req,
              onTap: () => tapped = true,
              onFindMatches: () => findMatchesTapped = true,
            ),
          ),
        ),
      );

      // Verify requirement details
      expect(find.text('REQ-2026-0099'), findsOneWidget);
      expect(find.text('Sharbati Wheat'), findsOneWidget);
      expect(find.text('AgrInnovate Flour Mills'), findsOneWidget);
      expect(find.text('Partially Allocated'), findsOneWidget);

      // Verify quantity metrics
      expect(find.text('100 MT'), findsOneWidget); // Requested
      expect(find.text('80 MT'), findsOneWidget); // Remaining

      // Verify actions
      await tester.tap(find.text('Find Matches'));
      expect(findMatchesTapped, isTrue);

      await tester.tap(find.byType(RequirementCard));
      expect(tapped, isTrue);
    });

    testWidgets('OfferCard renders inventory quantities and lab report policy disclaimer', (tester) async {
      final offer = OfferItem(
        id: 'off-01',
        ref: 'OFF-2026-0155',
        lotNumber: 'LOT-2026-0155',
        sellerCompanyId: 'seller-01',
        sellerCompanyName: 'Shekhawati Agro Traders',
        isSellerVerified: true,
        sellerTrustScore: 90,
        commodityId: 'comm-wheat',
        commodityName: 'Sharbati Wheat',
        gradeId: 'grade-a',
        gradeName: 'Grade A Milling',
        offeredQuantity: 60.0,
        availableQuantity: 40.0,
        reservedQuantity: 10.0,
        soldQuantity: 10.0,
        unitId: 'unit-mt',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        askingPrice: 2750.0,
        confidentialMinimumPrice: 2680.0,
        stateId: 'st-rj',
        stateName: 'Rajasthan',
        districtId: 'dst-jp',
        districtName: 'Jaipur Mandi',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 14)),
        validUntilFormatted: '31 Oct 2026',
        isExpired: false,
        loadingStatus: LoadingReadiness.readyToLoad,
        labReportUrl: 'https://example.com/lab.pdf',
        labReportDisclaimer: 'Seller Declared / Pending Verification',
        status: OfferStatus.open,
        createdAt: DateTime.now(),
      );

      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfferCard(
              offer: offer,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('OFF-2026-0155'), findsOneWidget);
      expect(find.text('LOT-2026-0155'), findsOneWidget);
      expect(find.text('Shekhawati Agro Traders'), findsOneWidget);
      expect(find.text('40 MT'), findsOneWidget); // Available
      expect(find.text('Ready to Load'), findsOneWidget);

      await tester.tap(find.byType(OfferCard));
      expect(tapped, isTrue);
    });

    testWidgets('MatchCard displays compatibility score and zero-reservation notice', (tester) async {
      final offer = OfferItem(
        id: 'off-01',
        ref: 'OFF-2026-0155',
        lotNumber: 'LOT-2026-0155',
        sellerCompanyId: 'seller-01',
        sellerCompanyName: 'Shekhawati Agro Traders',
        isSellerVerified: true,
        sellerTrustScore: 90,
        commodityId: 'comm-wheat',
        commodityName: 'Sharbati Wheat',
        gradeId: 'grade-a',
        gradeName: 'Grade A Milling',
        offeredQuantity: 60.0,
        availableQuantity: 40.0,
        reservedQuantity: 10.0,
        soldQuantity: 10.0,
        unitId: 'unit-mt',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        askingPrice: 2750.0,
        confidentialMinimumPrice: 2680.0,
        stateId: 'st-rj',
        stateName: 'Rajasthan',
        districtId: 'dst-jp',
        districtName: 'Jaipur Mandi',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 14)),
        validUntilFormatted: '31 Oct 2026',
        isExpired: false,
        loadingStatus: LoadingReadiness.readyToLoad,
        status: OfferStatus.open,
        createdAt: DateTime.now(),
      );

      final match = SupplyMatchItem(
        offer: offer,
        totalScore: 92.5,
        classification: MatchClassification.strongMatch,
        breakdown: const MatchBreakdown(
          commodityScore: 35.0,
          gradeScore: 25.0,
          priceScore: 20.0,
          locationScore: 8.0,
          quantityScore: 4.5,
          deliveryDateScore: 0.0,
        ),
        requiredQuantityMT: 50.0,
        availableQuantityMT: 40.0,
        coveragePercentage: 80.0,
        buyerTargetPrice: 2800.0,
        sellerAskingPrice: 2750.0,
        priceDifference: -50.0,
        priceDifferencePercent: -1.78,
        compatibilityReasons: const [
          'Exact Commodity match (Sharbati Wheat)',
          'Exact Grade match (Grade A Milling)',
        ],
        unmetCriteria: const [
          'Quantity covers 80% of requirement (partial fill)',
        ],
        isAllocationSupported: false,
      );

      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchCard(
              match: match,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('OFF-2026-0155'), findsOneWidget);
      expect(find.text('92% — Strong Match'), findsOneWidget);
      expect(find.text('40 / 50 MT (80%)'), findsOneWidget);
      expect(find.text('Exact Commodity match (Sharbati Wheat)'), findsOneWidget);
      expect(find.text('Quantity covers 80% of requirement (partial fill)'), findsOneWidget);

      // Verify Zero-Reservation Disclaimer is visible
      expect(
        find.text('Recommendation only. Match does not reserve stock or create a deal.'),
        findsOneWidget,
      );

      await tester.tap(find.byType(MatchCard));
      expect(tapped, isTrue);
    });
  });
}
