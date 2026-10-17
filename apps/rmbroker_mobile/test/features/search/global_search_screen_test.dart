import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/features/search/domain/search_result.dart';
import 'package:rmbroker_mobile/features/search/domain/search_state.dart';
import 'package:rmbroker_mobile/features/search/presentation/controllers/search_controller.dart';
import 'package:rmbroker_mobile/features/search/presentation/global_search_screen.dart';
import 'package:rmbroker_mobile/features/search/presentation/widgets/recent_searches_view.dart';
import 'package:rmbroker_mobile/features/search/presentation/widgets/search_filter_tabs.dart';
import 'package:rmbroker_mobile/features/search/presentation/widgets/search_input_bar.dart';
import 'package:rmbroker_mobile/features/search/presentation/widgets/search_results_view.dart';
import 'package:rmbroker_mobile/features/search/presentation/widgets/voice_search_dialog.dart';

class MockSearchController extends BrokerSearchController {
  final SearchState _initial;

  MockSearchController([SearchState? initial])
      : _initial = initial ?? SearchState.initial();

  @override
  SearchState build() => _initial;

  @override
  void onQueryChanged(String newQuery) {
    state = state.copyWith(query: newQuery);
  }

  @override
  void setFilter(SearchEntityType filter) {
    state = state.copyWith(activeFilter: filter);
  }

  @override
  void clearQuery() {
    state = state.copyWith(query: '', results: GlobalSearchResults.empty());
  }

  @override
  Future<void> executeSearch({bool addToRecent = true}) async {}
}

Widget createTestWidget({SearchState? state}) {
  return ProviderScope(
    overrides: [
      searchControllerProvider.overrideWith(() => MockSearchController(state)),
    ],
    child: const MaterialApp(
      home: GlobalSearchScreen(),
    ),
  );
}

void main() {
  group('GlobalSearchScreen UI & Interaction Tests', () {
    testWidgets('renders AppBar, SearchInputBar, and SearchFilterTabs cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(SearchInputBar), findsOneWidget);
      expect(find.byType(SearchFilterTabs), findsOneWidget);
      expect(find.byIcon(LucideIcons.mic), findsOneWidget);
      expect(find.byIcon(LucideIcons.phoneCall), findsOneWidget);
    });

    testWidgets('empty query displays RecentSearchesView with suggested commodities', (
      tester,
    ) async {
      const initialState = SearchState(
        query: '',
        recentSearches: ['Soyabean Kota', 'Mustard Seed Jaipur'],
      );

      await tester.pumpWidget(createTestWidget(state: initialState));
      await tester.pumpAndSettle();

      expect(find.byType(RecentSearchesView), findsOneWidget);
      expect(find.text('Recent Searches'), findsOneWidget);
      expect(find.text('Soyabean Kota'), findsOneWidget);
      expect(find.text('Mustard Seed Jaipur'), findsOneWidget);
      expect(find.text('Explore Commodities & Mandis'), findsOneWidget);
    });

    testWidgets('query < 2 chars displays "Keep typing..." guidance', (
      tester,
    ) async {
      const initialState = SearchState(query: 's');

      await tester.pumpWidget(createTestWidget(state: initialState));
      await tester.pumpAndSettle();

      expect(find.text('Keep typing...'), findsOneWidget);
      expect(find.textContaining('Enter at least 2 characters'), findsOneWidget);
    });

    testWidgets('renders contract pending banner when search endpoint is pending exposure', (
      tester,
    ) async {
      const initialState = SearchState(
        query: 'soyabean',
        hasSearched: true,
        isContractPending: true,
        contractNotice:
            'Global search REST contract (/api/v1/broker/search) is pending backend exposure.',
      );

      await tester.pumpWidget(createTestWidget(state: initialState));
      await tester.pumpAndSettle();

      expect(
        find.text('Global Search Service Contract Pending'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Global search REST contract'),
        findsOneWidget,
      );
      expect(find.text('Retry Search'), findsOneWidget);
      expect(find.text('Go to Directory'), findsOneWidget);
    });

    testWidgets('renders populated search results with Call and WhatsApp buttons', (
      tester,
    ) async {
      final sampleResults = GlobalSearchResults(
        contacts: [
          SearchContactItem(
            id: 'c1',
            userId: 'u1',
            name: 'Ramesh Agarwal',
            companyName: 'Agarwal Solvents',
            role: 'Buyer',
            mobile: '+919829012345',
            formattedMobile: '+91 98290 12345',
            city: 'Jaipur',
            isVerified: true,
          ),
        ],
        materials: [
          SearchMaterialItem(
            id: 'm1',
            name: 'Soyabean Yellow',
            code: 'SOYA-01',
            categoryName: 'Oilseeds',
            grades: ['FAQ', 'Super'],
          ),
        ],
        requirements: [
          SearchRequirementItem(
            id: 'r1',
            commodityName: 'Mustard Seed',
            quantity: 100,
            unitSymbol: 'MT',
            targetPrice: 5200,
            buyerCompanyName: 'Marwar Mills',
            status: 'OPEN',
          ),
        ],
        offers: [],
        deals: [],
        totalCount: 3,
      );

      final initialState = SearchState(
        query: 'soyabean',
        hasSearched: true,
        results: sampleResults,
        counts: SearchCounts.fromResults(sampleResults),
      );

      await tester.pumpWidget(createTestWidget(state: initialState));
      await tester.pumpAndSettle();

      expect(find.byType(SearchResultsView), findsOneWidget);
      expect(find.text('BUYERS & SELLERS'), findsOneWidget);
      expect(find.text('Ramesh Agarwal'), findsOneWidget);
      expect(find.text('Agarwal Solvents'), findsOneWidget);

      // Verify communication action buttons are present
      expect(find.byIcon(LucideIcons.phone), findsOneWidget);
      expect(find.byIcon(LucideIcons.messageCircle), findsOneWidget);

      // Verify material and requirement
      expect(find.text('RAW MATERIALS & COMMODITIES'), findsOneWidget);
      expect(find.text('Soyabean Yellow'), findsOneWidget);
      expect(find.text('BUYER REQUIREMENTS'), findsOneWidget);
      expect(find.text('Mustard Seed'), findsOneWidget);
    });

    testWidgets('tapping microphone icon opens VoiceSearchDialog with manual fallback', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final micButton = find.byIcon(LucideIcons.mic);
      expect(micButton, findsOneWidget);

      await tester.tap(micButton);
      await tester.pumpAndSettle();

      expect(find.byType(VoiceSearchDialog), findsOneWidget);
      expect(find.text('Voice-to-Text Search'), findsOneWidget);
      expect(find.text('Manual Typing'), findsOneWidget);
      expect(find.text('Sample Broker Voice Queries:'), findsOneWidget);
    });

    testWidgets('renders cleanly without overflow on compact 360x640 mobile screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull);
      expect(find.byType(GlobalSearchScreen), findsOneWidget);
    });
  });
}
