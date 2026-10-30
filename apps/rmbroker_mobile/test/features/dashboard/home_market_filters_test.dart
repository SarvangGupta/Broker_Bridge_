import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/dashboard/domain/market_filter_criteria.dart';
import 'package:rmbroker_mobile/features/dashboard/presentation/controllers/home_market_filter_controller.dart';
import 'package:rmbroker_mobile/features/dashboard/presentation/widgets/home_market_section.dart';
import 'package:rmbroker_mobile/features/dashboard/presentation/widgets/market_filter_sheet.dart';
import 'package:rmbroker_mobile/features/work/domain/offer_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';
import 'package:rmbroker_mobile/features/work/domain/trade_master_data.dart';
import 'package:rmbroker_mobile/features/work/presentation/controllers/master_data_controller.dart';
import 'package:rmbroker_mobile/features/work/presentation/controllers/offers_controller.dart';
import 'package:rmbroker_mobile/features/work/presentation/controllers/requirements_controller.dart';

void main() {
  group('MICRO-SPRINT: RMBROKER-HOME-FILTERS-01 Unit Tests', () {
    final now = DateTime.now();

    final testRequirements = [
      RequirementItem(
        id: 'req-1',
        ref: 'REQ-101',
        buyerCompanyId: 'comp-1',
        buyerCompanyName: 'AgrInnovate Feeds',
        isBuyerVerified: true,
        buyerTrustScore: 90,
        commodityId: 'comm-wheat',
        commodityName: 'Sharbati Wheat',
        gradeId: 'grade-1',
        gradeName: 'Grade A',
        requestedQuantity: 100,
        allocatedQuantity: 0,
        unitId: 'unit-mt',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        targetPrice: 25000,
        deliveryTerms: 'FOR Kota Mandi',
        targetDate: now.add(const Duration(days: 5)),
        targetDateFormatted: '05 Nov 2026',
        isUrgent: false,
        hoursUntilTarget: 120,
        isExpired: false,
        status: RequirementStatus.open,
        createdAt: now.subtract(const Duration(hours: 2)), // Today
      ),
      RequirementItem(
        id: 'req-2',
        ref: 'REQ-102',
        buyerCompanyId: 'comp-2',
        buyerCompanyName: 'North Dairy Feed',
        isBuyerVerified: true,
        buyerTrustScore: 85,
        commodityId: 'comm-maize',
        commodityName: 'Yellow Maize',
        gradeId: 'grade-2',
        gradeName: 'Feed Grade',
        requestedQuantity: 300,
        allocatedQuantity: 0,
        unitId: 'unit-mt',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        targetPrice: 19500,
        deliveryTerms: 'FOR Jaipur',
        targetDate: now.add(const Duration(days: 3)),
        targetDateFormatted: '03 Nov 2026',
        isUrgent: true,
        hoursUntilTarget: 72,
        isExpired: false,
        status: RequirementStatus.open,
        createdAt: now.subtract(const Duration(days: 3)), // Last 7 days
      ),
      RequirementItem(
        id: 'req-3',
        ref: 'REQ-103',
        buyerCompanyId: 'comp-3',
        buyerCompanyName: 'Golden Harvest',
        isBuyerVerified: false,
        buyerTrustScore: 80,
        commodityId: 'comm-soybean',
        commodityName: 'Soybean Meal',
        gradeId: 'grade-3',
        gradeName: 'Standard',
        requestedQuantity: 50,
        allocatedQuantity: 0,
        unitId: 'unit-mt',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        targetPrice: 38000,
        deliveryTerms: 'Ex-Mill Indore',
        targetDate: now.add(const Duration(days: 8)),
        targetDateFormatted: '08 Nov 2026',
        isUrgent: false,
        hoursUntilTarget: 190,
        isExpired: false,
        status: RequirementStatus.open,
        createdAt: now.subtract(const Duration(days: 15)), // Last 30 days
      ),
    ];

    final testOffers = [
      OfferItem(
        id: 'off-1',
        ref: 'OFF-201',
        lotNumber: 'LOT-501',
        sellerCompanyId: 'comp-s1',
        sellerCompanyName: 'Kota Agro Warehouse',
        isSellerVerified: true,
        sellerTrustScore: 92,
        commodityId: 'comm-wheat',
        commodityName: 'Sharbati Wheat',
        gradeId: 'grade-1',
        gradeName: 'Grade A',
        offeredQuantity: 150,
        availableQuantity: 150,
        reservedQuantity: 0,
        soldQuantity: 0,
        unitId: 'unit-mt',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        askingPrice: 24500,
        stateId: 'state-rj',
        stateName: 'Rajasthan',
        districtId: 'dist-kota',
        districtName: 'Kota',
        availableFrom: now,
        validUntil: now.add(const Duration(days: 10)),
        validUntilFormatted: '10 Nov 2026',
        isExpired: false,
        loadingStatus: LoadingReadiness.readyNow,
        status: OfferStatus.open,
        version: 1,
        labReportDisclaimer: '',
        createdAt: now.subtract(const Duration(hours: 3)), // Today
      ),
      OfferItem(
        id: 'off-2',
        ref: 'OFF-202',
        lotNumber: 'LOT-502',
        sellerCompanyId: 'comp-s2',
        sellerCompanyName: 'Hadoti Grain Traders',
        isSellerVerified: true,
        sellerTrustScore: 88,
        commodityId: 'comm-maize',
        commodityName: 'Yellow Maize',
        gradeId: 'grade-2',
        gradeName: 'Feed Grade',
        offeredQuantity: 400,
        availableQuantity: 400,
        reservedQuantity: 0,
        soldQuantity: 0,
        unitId: 'unit-mt',
        unitName: 'Metric Tonne',
        unitSymbol: 'MT',
        askingPrice: 19000,
        stateId: 'state-rj',
        stateName: 'Rajasthan',
        districtId: 'dist-baran',
        districtName: 'Baran',
        availableFrom: now,
        validUntil: now.add(const Duration(days: 12)),
        validUntilFormatted: '12 Nov 2026',
        isExpired: false,
        loadingStatus: LoadingReadiness.readyNow,
        status: OfferStatus.open,
        version: 1,
        labReportDisclaimer: '',
        createdAt: now.subtract(const Duration(days: 5)), // Last 7 days
      ),
    ];

    test('1. Filter by Raw Material (Commodity)', () {
      const criteria = MarketFilterCriteria(commodityId: 'comm-wheat');
      final filtered = criteria.applyToRequirements(testRequirements);
      expect(filtered.length, 1);
      expect(filtered.first.id, 'req-1');

      final filteredOffers = criteria.applyToOffers(testOffers);
      expect(filteredOffers.length, 1);
      expect(filteredOffers.first.id, 'off-1');
    });

    test('2. Filter by Date Presets (Today, Last 7 Days, Last 30 Days)', () {
      // Today
      const todayFilter = MarketFilterCriteria(datePreset: DateFilterPreset.today);
      expect(todayFilter.applyToRequirements(testRequirements).length, 1);
      expect(todayFilter.applyToRequirements(testRequirements).first.id, 'req-1');

      // Last 7 Days
      const last7DaysFilter = MarketFilterCriteria(datePreset: DateFilterPreset.last7Days);
      expect(last7DaysFilter.applyToRequirements(testRequirements).length, 2);

      // Last 30 Days
      const last30DaysFilter = MarketFilterCriteria(datePreset: DateFilterPreset.last30Days);
      expect(last30DaysFilter.applyToRequirements(testRequirements).length, 3);
    });

    test('3. Filter by Custom Date Range', () {
      final criteria = MarketFilterCriteria(
        datePreset: DateFilterPreset.custom,
        customStartDate: now.subtract(const Duration(days: 4)),
        customEndDate: now.subtract(const Duration(days: 2)),
      );
      final filtered = criteria.applyToRequirements(testRequirements);
      expect(filtered.length, 1);
      expect(filtered.first.id, 'req-2'); // req-2 was 3 days ago
    });

    test('4. Filter by Minimum and Maximum Price', () {
      // Min price only (>= 20000)
      const minPriceFilter = MarketFilterCriteria(minPrice: 20000);
      final minFiltered = minPriceFilter.applyToRequirements(testRequirements);
      expect(minFiltered.length, 2); // 25000 and 38000

      // Price range (20000 to 30000)
      const rangeFilter = MarketFilterCriteria(minPrice: 20000, maxPrice: 30000);
      final rangeFiltered = rangeFilter.applyToRequirements(testRequirements);
      expect(rangeFiltered.length, 1);
      expect(rangeFiltered.first.id, 'req-1'); // 25000
    });

    test('5. Filter by Minimum and Maximum Quantity', () {
      // Min quantity 100, max quantity 350
      const qtyFilter = MarketFilterCriteria(minQuantity: 100, maxQuantity: 350);
      final filtered = qtyFilter.applyToRequirements(testRequirements);
      expect(filtered.length, 2); // 100 and 300
    });

    test('6. Combine Multiple Filters (Commodity + Price + Quantity)', () {
      const combined = MarketFilterCriteria(
        commodityId: 'comm-maize',
        minPrice: 18000,
        maxPrice: 22000,
        minQuantity: 200,
      );
      final filtered = combined.applyToRequirements(testRequirements);
      expect(filtered.length, 1);
      expect(filtered.first.id, 'req-2');
    });

    test('7. Sort by Price (Low to High & High to Low)', () {
      const sortLow = MarketFilterCriteria(sortBy: MarketSortOption.priceLowToHigh);
      final lowToHigh = sortLow.applyToRequirements(testRequirements);
      expect(lowToHigh.first.targetPrice, 19500);
      expect(lowToHigh.last.targetPrice, 38000);

      const sortHigh = MarketFilterCriteria(sortBy: MarketSortOption.priceHighToLow);
      final highToLow = sortHigh.applyToRequirements(testRequirements);
      expect(highToLow.first.targetPrice, 38000);
      expect(highToLow.last.targetPrice, 19500);
    });

    test('8. Sort by Quantity (Low to High & High to Low)', () {
      const sortQtyLow = MarketFilterCriteria(sortBy: MarketSortOption.quantityLowToHigh);
      final qtyLowToHigh = sortQtyLow.applyToRequirements(testRequirements);
      expect(qtyLowToHigh.first.requestedQuantity, 50);
      expect(qtyLowToHigh.last.requestedQuantity, 300);

      const sortQtyHigh = MarketFilterCriteria(sortBy: MarketSortOption.quantityHighToLow);
      final qtyHighToLow = sortQtyHigh.applyToRequirements(testRequirements);
      expect(qtyHighToLow.first.requestedQuantity, 300);
      expect(qtyHighToLow.last.requestedQuantity, 50);
    });

    test('9. Active Filter Count Calculation', () {
      const empty = MarketFilterCriteria.empty();
      expect(empty.activeFilterCount, 0);
      expect(empty.hasActiveFilters, isFalse);

      const oneFilter = MarketFilterCriteria(commodityId: 'comm-wheat');
      expect(oneFilter.activeFilterCount, 1);
      expect(oneFilter.hasActiveFilters, isTrue);

      const threeFilters = MarketFilterCriteria(
        commodityId: 'comm-wheat',
        datePreset: DateFilterPreset.last7Days,
        minPrice: 20000,
      );
      expect(threeFilters.activeFilterCount, 3);
    });

    test('10. Independent Tab State Preservation in Controller', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(homeMarketFilterProvider.notifier);

      // Set filter on Requirements
      notifier.setRequirementsFilter(
        const MarketFilterCriteria(commodityId: 'comm-wheat'),
      );
      expect(container.read(homeMarketFilterProvider).requirementsFilter.commodityId, 'comm-wheat');
      expect(container.read(homeMarketFilterProvider).offersFilter.commodityId, isNull);

      // Switch to Offers Tab
      notifier.setTab(true);
      expect(container.read(homeMarketFilterProvider).isOffersTab, isTrue);
      expect(container.read(homeMarketFilterProvider).currentFilter.commodityId, isNull);

      // Set filter on Offers
      notifier.setOffersFilter(
        const MarketFilterCriteria(minPrice: 15000),
      );
      expect(container.read(homeMarketFilterProvider).offersFilter.minPrice, 15000);
      // Requirements filter MUST remain intact
      expect(container.read(homeMarketFilterProvider).requirementsFilter.commodityId, 'comm-wheat');

      // Switch back to Requirements Tab
      notifier.setTab(false);
      expect(container.read(homeMarketFilterProvider).isOffersTab, isFalse);
      expect(container.read(homeMarketFilterProvider).currentFilter.commodityId, 'comm-wheat');
      expect(container.read(homeMarketFilterProvider).currentFilter.minPrice, isNull);
    });
  });

  group('MICRO-SPRINT: RMBROKER-HOME-FILTERS-01 Widget & UI Tests', () {
    late TradeMasterData mockMaster;

    setUp(() {
      mockMaster = const TradeMasterData(
        buyerCompanies: [],
        sellerCompanies: [],
        commodities: [
          MasterDropdownItem(id: 'comm-wheat', name: 'Sharbati Wheat', categoryName: 'Grains'),
          MasterDropdownItem(id: 'comm-maize', name: 'Yellow Maize', categoryName: 'Grains'),
          MasterDropdownItem(id: 'comm-soybean', name: 'Soybean Meal', categoryName: 'Oilseeds'),
        ],
        grades: [],
        units: [],
        states: [],
        districts: [],
      );
    });

    testWidgets('11. HomeMarketSection renders Filter button with active count badge', (tester) async {
      final container = ProviderContainer(
        overrides: [
          masterDataProvider.overrideWith((ref) => mockMaster),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: HomeMarketSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Filter button must be visible near the tabs
      expect(find.byKey(const Key('home_market_filter_button')), findsOneWidget);
      // Initially no active badge
      expect(find.byKey(const Key('home_market_filter_badge_count')), findsNothing);

      // Apply a filter
      container.read(homeMarketFilterProvider.notifier).setRequirementsFilter(
        const MarketFilterCriteria(commodityId: 'comm-wheat', commodityName: 'Sharbati Wheat'),
      );
      await tester.pumpAndSettle();

      // Badge must appear with count '1'
      expect(find.byKey(const Key('home_market_filter_badge_count')), findsOneWidget);
      expect(find.text('1'), findsWidgets);

      // Active chips bar must render
      expect(find.text('Raw Material: Sharbati Wheat'), findsOneWidget);
      expect(find.byKey(const Key('home_market_clear_all_chips')), findsOneWidget);
    });

    testWidgets('12. Tapping Filter button opens MarketFilterSheet', (tester) async {
      final container = ProviderContainer(
        overrides: [
          masterDataProvider.overrideWith((ref) => mockMaster),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: HomeMarketSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_market_filter_button')));
      await tester.pumpAndSettle();

      // Bottom sheet is displayed
      expect(find.text('Filter & Sort'), findsOneWidget);
      expect(find.text('Buyer Requirements'), findsWidgets);
      expect(find.text('Raw Material (Commodity)'), findsOneWidget);
      expect(find.text('Date Range'), findsOneWidget);
      expect(find.text('Target Price (₹/MT)'), findsOneWidget);
      expect(find.text('Required Quantity (MT)'), findsOneWidget);
      expect(find.text('Sort By'), findsOneWidget);
      expect(find.byKey(const Key('filter_reset_all_button')), findsOneWidget);
      expect(find.byKey(const Key('filter_apply_button')), findsOneWidget);
    });

    testWidgets('13. Empty search result displays helpful message and Clear Filters button', (tester) async {
      final container = ProviderContainer(
        overrides: [
          masterDataProvider.overrideWith((ref) => mockMaster),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: HomeMarketSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set impossible filter
      container.read(homeMarketFilterProvider.notifier).setRequirementsFilter(
        const MarketFilterCriteria(minPrice: 9999999),
      );
      await tester.pumpAndSettle();

      // Empty state message
      expect(find.text('No buyer requirements match your active filters.'), findsOneWidget);
      expect(find.byKey(const Key('home_market_clear_filters_button')), findsOneWidget);

      // Tap Clear Filters button
      await tester.tap(find.byKey(const Key('home_market_clear_filters_button')));
      await tester.pumpAndSettle();

      // Filter should be cleared
      expect(container.read(homeMarketFilterProvider).requirementsFilter.hasActiveFilters, isFalse);
    });

    testWidgets('14. Tab switching preserves independent filter criteria', (tester) async {
      final container = ProviderContainer(
        overrides: [
          masterDataProvider.overrideWith((ref) => mockMaster),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: HomeMarketSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Apply filter on Buyer Requirements
      container.read(homeMarketFilterProvider.notifier).setRequirementsFilter(
        const MarketFilterCriteria(commodityId: 'comm-wheat', commodityName: 'Sharbati Wheat'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Raw Material: Sharbati Wheat'), findsOneWidget);
      expect(find.byKey(const Key('home_market_filter_badge_count')), findsOneWidget);

      // Switch to Seller Offers tab
      await tester.tap(find.byKey(const ValueKey('home_tab_offers')));
      await tester.pumpAndSettle();

      // Seller offers tab should have NO filters applied
      expect(find.text('Raw Material: Sharbati Wheat'), findsNothing);
      expect(find.byKey(const Key('home_market_filter_badge_count')), findsNothing);

      // Switch back to Buyer Requirements tab
      await tester.tap(find.byKey(const ValueKey('home_tab_requirements')));
      await tester.pumpAndSettle();

      // Filter MUST still be there!
      expect(find.text('Raw Material: Sharbati Wheat'), findsOneWidget);
      expect(find.byKey(const Key('home_market_filter_badge_count')), findsOneWidget);
    });
  });
}

