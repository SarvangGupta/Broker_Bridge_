import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/home/presentation/home_screen.dart';
import 'package:rmbuyer_mobile/features/search/data/search_repository.dart';
import 'package:rmbuyer_mobile/features/search/domain/broker_model.dart';
import 'package:rmbuyer_mobile/features/search/domain/search_model.dart';

class MockHomeScreenSearchRepo extends SearchRepository {
  List<SearchItem>? searchReturnItems;

  MockHomeScreenSearchRepo({this.searchReturnItems})
      : super(client: null);

  @override
  Future<List<BrokerModel>> searchBrokers({
    required String query,
    String? commodityFilter,
  }) async {
    return SearchRepository.fallbackBrokers;
  }

  @override
  Future<List<SearchItem>> search({
    required String query,
    SearchCategory category = SearchCategory.all,
  }) async {
    if (query.trim().isEmpty) return [];
    return searchReturnItems ?? [];
  }
}

void main() {
  group('RB-BUYER-02: HomeScreen Search & Broker Discovery Widget Tests', () {
    testWidgets('Scenario 1: Authenticated buyer opens home screen with branding, search, and CTA',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(searchRepository: MockHomeScreenSearchRepo()),
        ),
      );

      // Verify Header Identity
      expect(find.text('RMBuyer'), findsOneWidget);
      expect(find.text('Buyer Procurement Workstation'), findsOneWidget);

      // Verify Search Field with exact prompt requirement
      expect(find.text('Search commodity or broker'), findsOneWidget);

      // Verify Primary CTA
      expect(find.text('Post Your Requirement'), findsOneWidget);

      // Verify Mandi Catalogs
      expect(find.text('Browse Commodity Mandi Catalogs'), findsOneWidget);
      expect(find.text('Yellow Soybean'), findsOneWidget);
      expect(find.text('Desi Chana (Gram)'), findsOneWidget);
      expect(find.text('Wheat (Sharbati)'), findsOneWidget);
      expect(find.text('Mustard Seeds'), findsOneWidget);

      // Verify Authorized Mandi Broker Desks Spotlight
      expect(find.text('Authorized Mandi Broker Desks'), findsOneWidget);
    });

    testWidgets('Live debounced search updates UI with results and clear button resets to home',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MockHomeScreenSearchRepo(
        searchReturnItems: [
          const SearchItem(
            id: 'c-1',
            title: 'Yellow Soybean Grade A',
            subtitle: 'Master Commodity • Indore Mandi',
            category: SearchCategory.commodities,
          ),
          SearchItem(
            id: 'b-1',
            title: 'Varun (Jaipur Desk)',
            subtitle: 'Jaipur Grain Broker Desk • Jaipur Mandi',
            category: SearchCategory.brokers,
            broker: SearchRepository.fallbackBrokers.first,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(searchRepository: repo),
        ),
      );

      // Enter query in primary search field
      await tester.enterText(
        find.widgetWithText(TextField, 'Search commodity or broker'),
        'soybean',
      );
      await tester.pump();

      // Advance clock past the 300ms debounce
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Verify search results header and items
      expect(find.text('Search Results (2)'), findsOneWidget);
      expect(find.text('Yellow Soybean Grade A'), findsOneWidget);
      expect(find.text('Varun (Jaipur Desk)'), findsOneWidget);

      // Tap clear search button ('X')
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      // Verified: Resets back to default home layout
      expect(find.text('Browse Commodity Mandi Catalogs'), findsOneWidget);
      expect(find.text('Search Results (2)'), findsNothing);
    });

    testWidgets('Scenario 6: No matching broker found displays correct empty state',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MockHomeScreenSearchRepo(searchReturnItems: []);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(searchRepository: repo),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Search commodity or broker'),
        'unmatched-query-999',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Verify exact specified empty state string
      expect(find.text('No matching broker found.'), findsOneWidget);
      expect(find.text('Post Your Requirement'), findsOneWidget);
    });
  });
}
