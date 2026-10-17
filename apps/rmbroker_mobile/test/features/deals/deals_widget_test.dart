import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/deals/data/deal_repository.dart';
import 'package:rmbroker_mobile/features/deals/domain/deal_model.dart';
import 'package:rmbroker_mobile/features/deals/presentation/controllers/deals_controller.dart';
import 'package:rmbroker_mobile/features/deals/presentation/deals_screen.dart';
import 'package:rmbroker_mobile/features/deals/presentation/screens/deal_detail_screen.dart';
import 'package:rmbroker_mobile/features/deals/presentation/widgets/create_allocation_sheet.dart';
import 'package:rmbroker_mobile/features/deals/presentation/widgets/deal_card.dart';
import 'package:rmbroker_mobile/features/work/domain/offer_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';

class MockDealRepository extends DealRepository {
  final List<DealItem> mockDeals;
  final DealDetailItem? mockDetail;

  MockDealRepository({this.mockDeals = const [], this.mockDetail});

  @override
  Future<DealDataResult<List<DealItem>>> getDeals({
    DealStatus? statusFilter,
    String? search,
  }) async {
    return DealSuccess(mockDeals);
  }

  @override
  Future<DealDataResult<DealDetailItem>> getDealDetail(String dealId) async {
    if (mockDetail != null) {
      return DealSuccess(mockDetail!);
    }
    return const DealError(message: 'Deal not found');
  }
}

void main() {
  group('Deals & Allocation Widget Tests (RB-FL-08)', () {
    final mockDeal = DealItem(
      id: 'deal-test-01',
      ref: 'DL-2026-0042',
      quotationId: 'quote-01',
      requirementId: 'req-01',
      allocationId: 'alloc-01',
      allocationReference: 'ALC-2026-0099',
      commodityName: 'Sharbati Wheat',
      gradeName: 'Grade A Milling',
      buyerCompanyId: 'buyer-01',
      buyerCompanyName: 'AgrInnovate Flour Mills',
      sellerCompanyId: 'seller-01',
      sellerCompanyName: 'Shekhawati Agro Traders',
      agreedQuantity: 30.0,
      unitSymbol: 'MT',
      agreedPrice: 28500.0,
      totalValuation: 855000.0,
      priceBasis: 'FOR_DESTINATION',
      deliveryLocation: 'Jaipur Mandi Warehouse',
      status: DealStatus.negotiation,
      latestVersionNumber: 1,
      buyerConfirmed: true,
      sellerConfirmed: false,
      createdAt: DateTime.now(),
    );

    testWidgets('DealCard renders reference, metrics, counterparties, and party badges', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DealCard(
              deal: mockDeal,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      // Verify Reference & Status
      expect(find.text('DL-2026-0042'), findsOneWidget);
      expect(find.text('Negotiating'), findsOneWidget);
      expect(find.text('v1'), findsOneWidget);

      // Verify Commodity & Counterparties
      expect(find.text('Sharbati Wheat'), findsOneWidget);
      expect(find.text('AgrInnovate Flour Mills'), findsOneWidget);
      expect(find.text('Shekhawati Agro Traders'), findsOneWidget);

      // Verify Commercial Metrics
      expect(find.text('30 MT'), findsOneWidget);
      expect(find.text('₹28,500 / MT'), findsOneWidget);
      expect(find.text('₹8,55,000'), findsOneWidget);

      // Verify Dual Confirmation Badges
      expect(find.text('Buyer: Confirmed'), findsOneWidget);
      expect(find.text('Seller: Pending'), findsOneWidget);

      // Tap card
      await tester.tap(find.byType(DealCard));
      expect(tapped, isTrue);
    });

    testWidgets('CreateAllocationSheet reviews supply match and validates quantity limits', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final req = RequirementItem(
        id: 'req-01',
        ref: 'REQ-2026-001',
        buyerCompanyId: 'buyer-01',
        buyerCompanyName: 'AgrInnovate Mills',
        isBuyerVerified: true,
        buyerTrustScore: 92,
        commodityId: 'comm-01',
        commodityName: 'Sharbati Wheat',
        gradeId: 'grade-01',
        gradeName: 'Grade A',
        requestedQuantity: 100.0,
        allocatedQuantity: 20.0,
        contractedQuantity: 20.0,
        deliveredQuantity: 0.0,
        acceptedQuantity: 0.0,
        disputedQuantity: 0.0,
        remainingQuantity: 80.0,
        unitId: 'unit-01',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        targetPrice: 28000.0,
        deliveryTerms: 'FOR Destination',
        targetDate: DateTime.now().add(const Duration(days: 7)),
        targetDateFormatted: '24 Oct 2026',
        isUrgent: false,
        hoursUntilTarget: 168,
        isExpired: false,
        status: RequirementStatus.partiallyAllocated,
        createdAt: DateTime.now(),
      );

      final offer = OfferItem(
        id: 'off-01',
        ref: 'OFF-2026-001',
        lotNumber: 'LOT-WHEAT-01',
        sellerCompanyId: 'seller-01',
        sellerCompanyName: 'Kisan Traders',
        isSellerVerified: true,
        sellerTrustScore: 88,
        commodityId: 'comm-01',
        commodityName: 'Sharbati Wheat',
        gradeId: 'grade-01',
        gradeName: 'Grade A',
        offeredQuantity: 50.0,
        availableQuantity: 40.0,
        reservedQuantity: 5.0,
        soldQuantity: 5.0,
        unitId: 'unit-01',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        askingPrice: 28200.0,
        confidentialMinimumPrice: 27500.0,
        stateId: 'st-01',
        stateName: 'Rajasthan',
        districtId: 'dist-01',
        districtName: 'Jaipur',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 14)),
        validUntilFormatted: '31 Oct 2026',
        isExpired: false,
        loadingStatus: LoadingReadiness.readyToLoad,
        status: OfferStatus.partiallyAvailable,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreateAllocationSheet(
                requirement: req,
                offer: offer,
              ),
            ),
          ),
        ),
      );

      // Verify Header & Counterparties
      expect(find.text('Allocate Supply to Mandate'), findsOneWidget);
      expect(find.text('Sharbati Wheat'), findsWidgets);
      expect(find.text('AgrInnovate Mills'), findsOneWidget);
      expect(find.text('Kisan Traders'), findsOneWidget);

      // Verify Max Eligible calculation: min(80, 40) = 40 MT
      expect(find.text('Max Eligible: 40.0 MT'), findsOneWidget);

      // Verify default proposed quantity is 40
      expect(find.widgetWithText(TextFormField, '40'), findsOneWidget);

      // Test validation: enter 999 MT (exceeds balance)
      await tester.enterText(find.widgetWithText(TextFormField, '40'), '999');
      await tester.pump();

      await tester.tap(find.text('Review Allocation Summary'));
      await tester.pump();

      expect(find.textContaining('Exceeds requirement balance'), findsOneWidget);

      // Enter valid quantity: 35 MT
      await tester.enterText(find.widgetWithText(TextFormField, '999'), '35');
      await tester.pump();

      await tester.tap(find.text('Review Allocation Summary'));
      await tester.pump();

      // Verify Confirmation Summary screen appears
      expect(find.text('Allocation Confirmation Summary'), findsOneWidget);
      expect(find.text('Authoritatively Commit'), findsOneWidget);
    });

    testWidgets('DealsScreen displays KPI cards, search, and list', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dealRepositoryProvider.overrideWithValue(
              MockDealRepository(mockDeals: [mockDeal]),
            ),
          ],
          child: const MaterialApp(
            home: DealsScreen(),
          ),
        ),
      );

      // Allow microtask loadDeals() to finish
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify App Bar
      expect(find.text('Deals & Negotiations'), findsOneWidget);

      // Verify KPI Metrics
      expect(find.text('Total Deals'), findsOneWidget);
      expect(find.text('Agreed Volume'), findsWidgets);
      expect(find.text('Contract Value'), findsOneWidget);
      expect(find.text('30 MT'), findsWidgets);

      // Verify Search Box and Filter Chips
      expect(find.text('All (1)'), findsOneWidget);
      expect(find.text('Draft (0)'), findsOneWidget);
      expect(find.text('Negotiating (1)'), findsOneWidget);

      // Verify Deal Card
      expect(find.text('DL-2026-0042'), findsOneWidget);
      expect(find.text('AgrInnovate Flour Mills'), findsOneWidget);
    });

    testWidgets('DealDetailScreen displays contract terms, dual confirmations, and cancel action', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockDetail = DealDetailItem(
        deal: mockDeal,
        confirmations: const DealConfirmationState(
          latestVersionNumber: 1,
          buyerConfirmed: true,
          sellerConfirmed: false,
          canFinalize: false,
        ),
        deliveryTerms: 'FOR Destination Jaipur Mandi',
        paymentTerms: '100% Advance against Lorry Receipt',
        packagingType: '50kg HDPE Bags',
        brokerCommissionRate: 50.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dealRepositoryProvider.overrideWithValue(
              MockDealRepository(mockDetail: mockDetail),
            ),
          ],
          child: const MaterialApp(
            home: DealDetailScreen(dealId: 'deal-test-01'),
          ),
        ),
      );

      // Allow microtask loadDetail() to finish
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Deal App Bar & Commodity
      expect(find.text('DL-2026-0042'), findsWidgets);
      expect(find.text('Sharbati Wheat'), findsOneWidget);

      // Verify Counterparties
      expect(find.text('AgrInnovate Flour Mills'), findsOneWidget);
      expect(find.text('Shekhawati Agro Traders'), findsOneWidget);

      // Verify Dual Confirmation Status
      expect(find.text('Party Confirmation Verification'), findsOneWidget);
      expect(find.text('Buyer Confirmation: Confirmed'), findsOneWidget);
      expect(find.text('Seller Confirmation: Pending'), findsOneWidget);

      // Verify Contract Terms
      expect(find.text('Contract Terms & Logistics'), findsOneWidget);
      expect(find.text('FOR Destination Jaipur Mandi'), findsOneWidget);
      expect(find.text('50kg HDPE Bags'), findsOneWidget);
      expect(find.text('₹50 / ₹/MT'), findsOneWidget);

      // Verify Cancel Button and Dialog
      expect(find.text('Cancel Deal Record'), findsOneWidget);
      await tester.tap(find.text('Cancel Deal Record'));
      await tester.pump();

      expect(find.text('Cancel Deal Contract'), findsOneWidget);
      expect(find.text('Keep Active'), findsOneWidget);
    });
  });
}
