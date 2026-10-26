import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/deals/data/deal_repository.dart';
import 'package:rmbroker_mobile/features/deals/domain/deal_model.dart';
import 'package:rmbroker_mobile/features/deals/presentation/controllers/deals_controller.dart';
import 'package:rmbroker_mobile/features/deals/presentation/deals_screen.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_negotiation_model.dart';
import 'package:rmbroker_mobile/features/work/domain/offer_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';
import 'package:rmbroker_mobile/features/work/presentation/controllers/requirements_controller.dart';
import 'package:rmbroker_mobile/features/work/presentation/work_screen.dart';

// Test repository mock providing Varun's exact authorized dataset
class MockVarunDealRepository extends DealRepository {
  final List<DealItem> deals;

  MockVarunDealRepository(this.deals);

  @override
  Future<DealDataResult<List<DealItem>>> getDeals({
    DealStatus? statusFilter,
    String? search,
  }) async {
    return DealSuccess(deals);
  }
}

class MockVarunWorkRepository extends WorkRepository {
  @override
  Future<WorkDataResult<RequirementNegotiationData>> getRequirementNegotiationDetails(String requirementId) async =>
      WorkSuccess(RequirementNegotiationData(
        requirementId: requirementId,
        currentVersionNumber: 1,
        currentStatus: 'Open',
        offeredPrice: 0,
        proposedQuantity: 0,
      ));
  final List<RequirementItem> requirements;
  final List<OfferItem> offers;

  MockVarunWorkRepository({
    this.requirements = const [],
    this.offers = const [],
  });

  @override
  Future<WorkDataResult<List<RequirementItem>>> getRequirements({
    RequirementStatus? statusFilter,
    String? search,
  }) async {
    return WorkSuccess(requirements);
  }

  @override
  Future<WorkDataResult<List<OfferItem>>> getOffers({
    OfferStatus? statusFilter,
    String? search,
  }) async {
    return WorkSuccess(offers);
  }
}

void main() {
  group('Dashboard-to-Detail Drilldown & Data Consistency Tests (RB-DRILL-01)', () {
    // 9 Authoritative deals for broker Varun
    final List<DealItem> varunDeals = [
      DealItem(
        id: '90000000-0000-0000-0000-000000000001',
        ref: 'DL-0001',
        quotationId: 'q-01',
        requirementId: 'r-01',
        commodityName: 'Yellow Maize',
        buyerCompanyId: 'b-01',
        buyerCompanyName: 'AgrInnovate Feeds',
        sellerCompanyId: 's-01',
        sellerCompanyName: 'Kota Agro Warehousing',
        agreedQuantity: 60.0,
        unitSymbol: 'MT',
        agreedPrice: 22500.0,
        totalValuation: 1350000.0,
        priceBasis: 'FOR_DESTINATION',
        deliveryLocation: 'Kota Mandi',
        status: DealStatus.draft,
        latestVersionNumber: 1,
        buyerConfirmed: false,
        sellerConfirmed: false,
        createdAt: DateTime.now(),
      ),
      DealItem(
        id: '90000000-0000-0000-0000-000000000002',
        ref: 'DL-0002',
        quotationId: 'q-02',
        requirementId: 'r-02',
        commodityName: 'Yellow Maize',
        buyerCompanyId: 'b-01',
        buyerCompanyName: 'AgrInnovate Feeds',
        sellerCompanyId: 's-02',
        sellerCompanyName: 'Hadoti Grain Producers',
        agreedQuantity: 40.0,
        unitSymbol: 'MT',
        agreedPrice: 22800.0,
        totalValuation: 912000.0,
        priceBasis: 'FOR_DESTINATION',
        deliveryLocation: 'Kota Mandi',
        status: DealStatus.negotiation,
        latestVersionNumber: 1,
        buyerConfirmed: false,
        sellerConfirmed: false,
        createdAt: DateTime.now(),
      ),
      DealItem(
        id: '90000000-0000-0000-0000-000000000003',
        ref: 'DL-0003',
        quotationId: 'q-03',
        requirementId: 'r-03',
        commodityName: 'Sharbati Wheat',
        buyerCompanyId: 'b-03',
        buyerCompanyName: 'Golden Harvest Flour Mills',
        sellerCompanyId: 's-03',
        sellerCompanyName: 'Shekhawati Wheat Traders',
        agreedQuantity: 50.0,
        unitSymbol: 'MT',
        agreedPrice: 28500.0,
        totalValuation: 1425000.0,
        priceBasis: 'FOR_DESTINATION',
        deliveryLocation: 'Jaipur Warehouse',
        status: DealStatus.awaitingBuyerConfirmation,
        latestVersionNumber: 1,
        buyerConfirmed: false,
        sellerConfirmed: true,
        createdAt: DateTime.now(),
      ),
      DealItem(
        id: '90000000-0000-0000-0000-000000000004',
        ref: 'DL-0004',
        quotationId: 'q-04',
        requirementId: 'r-04',
        commodityName: 'Yellow Maize',
        buyerCompanyId: 'b-02',
        buyerCompanyName: 'North Dairy Feed Corp',
        sellerCompanyId: 's-02',
        sellerCompanyName: 'Hadoti Grain Producers',
        agreedQuantity: 40.0,
        unitSymbol: 'MT',
        agreedPrice: 22400.0,
        totalValuation: 896000.0,
        priceBasis: 'FOR_DESTINATION',
        deliveryLocation: 'Baran Mandi',
        status: DealStatus.awaitingSellerConfirmation,
        latestVersionNumber: 1,
        buyerConfirmed: true,
        sellerConfirmed: false,
        createdAt: DateTime.now(),
      ),
      DealItem(
        id: '90000000-0000-0000-0000-000000000005',
        ref: 'DL-0005',
        quotationId: 'q-05',
        requirementId: 'r-05',
        commodityName: 'Soybean Seed',
        buyerCompanyId: 'b-05',
        buyerCompanyName: 'Malwa Solvent Extractions',
        sellerCompanyId: 's-01',
        sellerCompanyName: 'Kota Agro Warehousing',
        agreedQuantity: 50.0,
        unitSymbol: 'MT',
        agreedPrice: 48000.0,
        totalValuation: 2400000.0,
        priceBasis: 'FOR_DESTINATION',
        deliveryLocation: 'Kota Mandi',
        status: DealStatus.finalized,
        latestVersionNumber: 1,
        buyerConfirmed: true,
        sellerConfirmed: true,
        createdAt: DateTime.now(),
      ),
      DealItem(
        id: '90000000-0000-0000-0000-000000000006',
        ref: 'DL-0006',
        quotationId: 'q-06',
        requirementId: 'r-06',
        commodityName: 'Yellow Maize',
        buyerCompanyId: 'b-04',
        buyerCompanyName: 'Frontier Starch Processing',
        sellerCompanyId: 's-01',
        sellerCompanyName: 'Kota Agro Warehousing',
        agreedQuantity: 60.0,
        unitSymbol: 'MT',
        agreedPrice: 22600.0,
        totalValuation: 1356000.0,
        priceBasis: 'FOR_DESTINATION',
        deliveryLocation: 'Kota Mandi',
        status: DealStatus.inFulfillment, // Dispatch Pending
        latestVersionNumber: 1,
        buyerConfirmed: true,
        sellerConfirmed: true,
        createdAt: DateTime.now(),
      ),
      DealItem(
        id: '90000000-0000-0000-0000-000000000007',
        ref: 'DL-0007',
        quotationId: 'q-07',
        requirementId: 'r-07',
        commodityName: 'Yellow Maize',
        buyerCompanyId: 'b-01',
        buyerCompanyName: 'AgrInnovate Feeds',
        sellerCompanyId: 's-01',
        sellerCompanyName: 'Kota Agro Warehousing',
        agreedQuantity: 50.0,
        unitSymbol: 'MT',
        agreedPrice: 22000.0,
        totalValuation: 1100000.0,
        priceBasis: 'FOR_DESTINATION',
        deliveryLocation: 'Kota Mandi',
        status: DealStatus.completed,
        latestVersionNumber: 1,
        buyerConfirmed: true,
        sellerConfirmed: true,
        createdAt: DateTime.now(),
      ),
      DealItem(
        id: '90000000-0000-0000-0000-000000000008',
        ref: 'DL-0008',
        quotationId: 'q-08',
        requirementId: 'r-08',
        commodityName: 'Yellow Maize',
        buyerCompanyId: 'b-02',
        buyerCompanyName: 'North Dairy Feed Corp',
        sellerCompanyId: 's-02',
        sellerCompanyName: 'Hadoti Grain Producers',
        agreedQuantity: 20.0,
        unitSymbol: 'MT',
        agreedPrice: 21500.0,
        totalValuation: 430000.0,
        priceBasis: 'FOR_DESTINATION',
        deliveryLocation: 'Baran Mandi',
        status: DealStatus.cancelled,
        latestVersionNumber: 1,
        buyerConfirmed: false,
        sellerConfirmed: false,
        createdAt: DateTime.now(),
      ),
      DealItem(
        id: '90000000-0000-0000-0000-000000000009',
        ref: 'DL-0009',
        quotationId: 'q-09',
        requirementId: 'r-09',
        commodityName: 'Yellow Maize',
        buyerCompanyId: 'b-04',
        buyerCompanyName: 'Frontier Starch Processing',
        sellerCompanyId: 's-01',
        sellerCompanyName: 'Kota Agro Warehousing',
        agreedQuantity: 40.0,
        unitSymbol: 'MT',
        agreedPrice: 22700.0,
        totalValuation: 908000.0,
        priceBasis: 'FOR_DESTINATION',
        deliveryLocation: 'Kota Mandi',
        status: DealStatus.disputed,
        latestVersionNumber: 1,
        buyerConfirmed: true,
        sellerConfirmed: true,
        createdAt: DateTime.now(),
      ),
    ];

    // Varun's 6 requirements (4 Open, 1 Fully Allocated, 1 Expired, 0 Partially Allocated)
    final List<RequirementItem> varunRequirements = [
      RequirementItem(
        id: '60000000-0000-0000-0000-000000000101',
        ref: 'REQ-101',
        buyerCompanyId: 'b-01',
        buyerCompanyName: 'AgrInnovate Feeds',
        isBuyerVerified: true,
        buyerTrustScore: 90,
        commodityId: 'comm-1',
        commodityName: 'Yellow Maize',
        gradeId: 'grade-1',
        gradeName: 'FAQ',
        requestedQuantity: 100.0,
        allocatedQuantity: 100.0,
        contractedQuantity: 100.0,
        deliveredQuantity: 0.0,
        acceptedQuantity: 0.0,
        disputedQuantity: 0.0,
        remainingQuantity: 0.0,
        unitId: 'unit-1',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        targetPrice: 22500.0,
        deliveryTerms: 'FOR Kota',
        targetDate: DateTime.now().add(const Duration(days: 5)),
        targetDateFormatted: '25 Oct 2026',
        isUrgent: false,
        hoursUntilTarget: 120,
        isExpired: false,
        status: RequirementStatus.fullyAllocated,
        createdAt: DateTime.now(),
      ),
      RequirementItem(
        id: '60000000-0000-0000-0000-000000000102',
        ref: 'REQ-102',
        buyerCompanyId: 'b-02',
        buyerCompanyName: 'North Dairy Feed Corp',
        isBuyerVerified: true,
        buyerTrustScore: 90,
        commodityId: 'comm-1',
        commodityName: 'Yellow Maize',
        gradeId: 'grade-1',
        gradeName: 'FAQ',
        requestedQuantity: 75.0,
        allocatedQuantity: 0.0,
        contractedQuantity: 0.0,
        deliveredQuantity: 0.0,
        acceptedQuantity: 0.0,
        disputedQuantity: 0.0,
        remainingQuantity: 75.0,
        unitId: 'unit-1',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        targetPrice: 22400.0,
        deliveryTerms: 'FOR Baran',
        targetDate: DateTime.now().add(const Duration(days: 7)),
        targetDateFormatted: '27 Oct 2026',
        isUrgent: false,
        hoursUntilTarget: 168,
        isExpired: false,
        status: RequirementStatus.open,
        createdAt: DateTime.now(),
      ),
      RequirementItem(
        id: '60000000-0000-0000-0000-000000000103',
        ref: 'REQ-103',
        buyerCompanyId: 'b-03',
        buyerCompanyName: 'Golden Harvest Flour Mills',
        isBuyerVerified: true,
        buyerTrustScore: 90,
        commodityId: 'comm-1',
        commodityName: 'Sharbati Wheat',
        gradeId: 'grade-1',
        gradeName: 'FAQ',
        requestedQuantity: 50.0,
        allocatedQuantity: 0.0,
        contractedQuantity: 0.0,
        deliveredQuantity: 0.0,
        acceptedQuantity: 0.0,
        disputedQuantity: 0.0,
        remainingQuantity: 50.0,
        unitId: 'unit-1',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        targetPrice: 28500.0,
        deliveryTerms: 'FOR Jaipur',
        targetDate: DateTime.now().add(const Duration(days: 8)),
        targetDateFormatted: '28 Oct 2026',
        isUrgent: false,
        hoursUntilTarget: 192,
        isExpired: false,
        status: RequirementStatus.open,
        createdAt: DateTime.now(),
      ),
      RequirementItem(
        id: '60000000-0000-0000-0000-000000000104',
        ref: 'REQ-104',
        buyerCompanyId: 'b-04',
        buyerCompanyName: 'Frontier Starch Processing',
        isBuyerVerified: true,
        buyerTrustScore: 90,
        commodityId: 'comm-1',
        commodityName: 'Yellow Maize',
        gradeId: 'grade-1',
        gradeName: 'FAQ',
        requestedQuantity: 120.0,
        allocatedQuantity: 0.0,
        contractedQuantity: 0.0,
        deliveredQuantity: 0.0,
        acceptedQuantity: 0.0,
        disputedQuantity: 0.0,
        remainingQuantity: 120.0,
        unitId: 'unit-1',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        targetPrice: 22600.0,
        deliveryTerms: 'FOR Kota',
        targetDate: DateTime.now().add(const Duration(days: 10)),
        targetDateFormatted: '30 Oct 2026',
        isUrgent: false,
        hoursUntilTarget: 240,
        isExpired: false,
        status: RequirementStatus.open,
        createdAt: DateTime.now(),
      ),
      RequirementItem(
        id: '60000000-0000-0000-0000-000000000105',
        ref: 'REQ-105',
        buyerCompanyId: 'b-05',
        buyerCompanyName: 'Malwa Solvent Extractions',
        isBuyerVerified: true,
        buyerTrustScore: 90,
        commodityId: 'comm-1',
        commodityName: 'Soybean Seed',
        gradeId: 'grade-1',
        gradeName: 'FAQ',
        requestedQuantity: 100.0,
        allocatedQuantity: 0.0,
        contractedQuantity: 0.0,
        deliveredQuantity: 0.0,
        acceptedQuantity: 0.0,
        disputedQuantity: 0.0,
        remainingQuantity: 100.0,
        unitId: 'unit-1',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        targetPrice: 48000.0,
        deliveryTerms: 'FOR Kota',
        targetDate: DateTime.now().add(const Duration(days: 12)),
        targetDateFormatted: '01 Nov 2026',
        isUrgent: false,
        hoursUntilTarget: 288,
        isExpired: false,
        status: RequirementStatus.open,
        createdAt: DateTime.now(),
      ),
      RequirementItem(
        id: '60000000-0000-0000-0000-000000000106',
        ref: 'REQ-106',
        buyerCompanyId: 'b-06',
        buyerCompanyName: 'Mewar Grains Distributing',
        isBuyerVerified: false,
        buyerTrustScore: 60,
        commodityId: 'comm-1',
        commodityName: 'Yellow Maize',
        gradeId: 'grade-1',
        gradeName: 'FAQ',
        requestedQuantity: 60.0,
        allocatedQuantity: 0.0,
        contractedQuantity: 0.0,
        deliveredQuantity: 0.0,
        acceptedQuantity: 0.0,
        disputedQuantity: 0.0,
        remainingQuantity: 60.0,
        unitId: 'unit-1',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        targetPrice: 22000.0,
        deliveryTerms: 'FOR Jaipur',
        targetDate: DateTime.now().subtract(const Duration(days: 1)),
        targetDateFormatted: '18 Oct 2026',
        isUrgent: false,
        hoursUntilTarget: -24,
        isExpired: true,
        status: RequirementStatus.expired,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];

    // Varun's 2 available open seller offers
    final List<OfferItem> varunOffers = [
      OfferItem(
        id: '50000000-0000-0000-0000-000000000202',
        ref: 'OFF-202',
        lotNumber: 'LOT-WHEAT-202',
        sellerCompanyId: 's-03',
        sellerCompanyName: 'Shekhawati Wheat Traders',
        isSellerVerified: true,
        sellerTrustScore: 90,
        commodityId: 'comm-1',
        commodityName: 'Sharbati Wheat',
        gradeId: 'grade-1',
        gradeName: 'FAQ',
        offeredQuantity: 70.0,
        availableQuantity: 70.0,
        reservedQuantity: 0.0,
        soldQuantity: 0.0,
        unitId: 'unit-1',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        askingPrice: 24500.0,
        confidentialMinimumPrice: 24000.0,
        stateId: 'st-01',
        stateName: 'Rajasthan',
        districtId: 'dt-01',
        districtName: 'Jaipur',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 14)),
        validUntilFormatted: '02 Nov 2026',
        isExpired: false,
        loadingStatus: LoadingReadiness.readyToLoad,
        status: OfferStatus.open,
        createdAt: DateTime.now(),
      ),
      OfferItem(
        id: '50000000-0000-0000-0000-000000000203',
        ref: 'OFF-203',
        lotNumber: 'LOT-MUSTARD-203',
        sellerCompanyId: 's-02',
        sellerCompanyName: 'Hadoti Grain Producers',
        isSellerVerified: true,
        sellerTrustScore: 90,
        commodityId: 'comm-1',
        commodityName: 'Mustard Seed',
        gradeId: 'grade-1',
        gradeName: 'FAQ',
        offeredQuantity: 40.0,
        availableQuantity: 40.0,
        reservedQuantity: 0.0,
        soldQuantity: 0.0,
        unitId: 'unit-1',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        askingPrice: 5400.0,
        confidentialMinimumPrice: 5300.0,
        stateId: 'st-01',
        stateName: 'Rajasthan',
        districtId: 'dt-01',
        districtName: 'Baran',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 14)),
        validUntilFormatted: '02 Nov 2026',
        isExpired: false,
        loadingStatus: LoadingReadiness.readyToLoad,
        status: OfferStatus.open,
        createdAt: DateTime.now(),
      ),
    ];

    testWidgets('Active Deals Drilldown: opens DealsScreen with active filter showing exactly 7 deals', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dealRepositoryProvider.overrideWithValue(MockVarunDealRepository(varunDeals)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DealsScreen(initialFilter: 'active'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Active filter chip is selected with count (7)
      expect(find.text('Active (7)'), findsOneWidget);

      // Verify Terminal deals are excluded
      expect(find.text('DL-0007'), findsNothing); // Completed deal
      expect(find.text('DL-0008'), findsNothing); // Cancelled deal

      // Verify Active deals are present
      expect(find.text('DL-0001'), findsOneWidget); // Draft
      expect(find.text('DL-0002'), findsOneWidget); // Negotiation
      expect(find.text('DL-0003'), findsOneWidget); // Awaiting Buyer
      expect(find.text('DL-0004'), findsOneWidget); // Awaiting Seller
      expect(find.text('DL-0005'), findsOneWidget); // Finalized
      expect(find.text('DL-0006'), findsOneWidget); // Dispatch Pending
      expect(find.text('DL-0009'), findsOneWidget); // Disputed
    });

    testWidgets('Awaiting Sign-off Drilldown: filters to 3 confirmation-pending deals', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dealRepositoryProvider.overrideWithValue(MockVarunDealRepository(varunDeals)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DealsScreen(initialFilter: 'signoff'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Awaiting Sign-off (3)'), findsOneWidget);

      // Verify confirmation pending deals appear
      expect(find.text('DL-0001'), findsOneWidget); // Draft
      expect(find.text('DL-0003'), findsOneWidget); // Awaiting Buyer
      expect(find.text('DL-0004'), findsOneWidget); // Awaiting Seller

      // Verify other deals excluded
      expect(find.text('DL-0005'), findsNothing); // Finalized
      expect(find.text('DL-0006'), findsNothing); // In fulfillment
      expect(find.text('DL-0007'), findsNothing); // Completed
    });

    testWidgets('Dispatch Due Drilldown: filters to 2 logistics pending deals', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dealRepositoryProvider.overrideWithValue(MockVarunDealRepository(varunDeals)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DealsScreen(initialFilter: 'dispatch_due'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dispatch Due (2)'), findsOneWidget);
      expect(find.text('DL-0005'), findsOneWidget); // Finalized
      expect(find.text('DL-0006'), findsOneWidget); // Dispatch Pending

      // Other deals excluded
      expect(find.text('DL-0001'), findsNothing);
      expect(find.text('DL-0002'), findsNothing);
    });

    testWidgets('Open Disputes Drilldown: filters to 1 disputed deal with context', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dealRepositoryProvider.overrideWithValue(MockVarunDealRepository(varunDeals)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DealsScreen(initialFilter: 'disputed'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Disputed (1)'), findsOneWidget);
      expect(find.text('DL-0009'), findsOneWidget);
      expect(find.text('DL-0001'), findsNothing);
    });

    testWidgets('Open Requirements Drilldown: opens Tab 0 with Open (4) filter chip', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workRepositoryProvider.overrideWithValue(
              MockVarunWorkRepository(
                requirements: varunRequirements,
                offers: varunOffers,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WorkScreen(
                initialTabIndex: 0,
                initialStatusFilter: 'open',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Open (4) chip is visible
      expect(find.text('Open (4)'), findsOneWidget);

      // Verify the 4 open requirements appear
      expect(find.text('REQ-102'), findsOneWidget);
      expect(find.text('REQ-103'), findsOneWidget);
      expect(find.text('REQ-104'), findsOneWidget);
      expect(find.text('REQ-105'), findsOneWidget);

      // Allocated and Expired excluded
      expect(find.text('REQ-101'), findsNothing);
      expect(find.text('REQ-106'), findsNothing);
    });

    testWidgets('Partially Allocated Drilldown: opens Tab 0 showing legitimate empty state for 0 count', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workRepositoryProvider.overrideWithValue(
              MockVarunWorkRepository(
                requirements: varunRequirements,
                offers: varunOffers,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WorkScreen(
                initialTabIndex: 0,
                initialStatusFilter: 'partially_allocated',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Partly Allocated (0)'), findsOneWidget);

      // Legitimate empty state names the empty filter (RB-WORK-DESK-UI-01)
      expect(find.text('No partly allocated requirements'), findsOneWidget);
      expect(find.text('Clear Filters'), findsOneWidget);

      // No unrelated requirements shown
      expect(find.text('REQ-101'), findsNothing);
      expect(find.text('REQ-102'), findsNothing);
    });

    testWidgets('Available Offers Drilldown: switches to Tab 1 (Seller Offers) with Active Supply (2)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workRepositoryProvider.overrideWithValue(
              MockVarunWorkRepository(
                requirements: varunRequirements,
                offers: varunOffers,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WorkScreen(
                initialTabIndex: 1,
                initialStatusFilter: 'open',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Tab 1 content is visible
      expect(find.text('Active Supply (2)'), findsOneWidget);

      // Verify the 2 seller offer lots appear
      expect(find.text('LOT-WHEAT-202'), findsOneWidget);
      expect(find.text('LOT-MUSTARD-203'), findsOneWidget);

      // Buyer mandates from Tab 0 should NOT be in this tab's list
      expect(find.text('REQ-102'), findsNothing);
    });
  });
}
