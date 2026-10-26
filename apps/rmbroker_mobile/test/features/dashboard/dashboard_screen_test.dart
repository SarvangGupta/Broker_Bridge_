import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/router/app_router.dart';
import 'package:rmbroker_mobile/core/widgets/module_placeholder_screen.dart';
import 'package:rmbroker_mobile/features/more/presentation/more_screen.dart';
import 'package:rmbroker_mobile/features/profile/presentation/broker_profile_screen.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/create_offer_sheet.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/create_requirement_sheet.dart';
import 'package:rmbroker_mobile/core/widgets/status_badge.dart';
import 'package:rmbroker_mobile/features/authentication/domain/broker_user.dart';
import 'package:rmbroker_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:rmbroker_mobile/features/dashboard/domain/dashboard_models.dart';
import 'package:rmbroker_mobile/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:rmbroker_mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:rmbroker_mobile/features/dashboard/presentation/widgets/dashboard_kpi_grid.dart';
import 'package:rmbroker_mobile/features/dashboard/presentation/widgets/quick_actions_section.dart';

class MockDashboardRepository extends DashboardRepository {
  final DashboardDataResult resultData;
  final BrokerUser? brokerUser;

  MockDashboardRepository({
    required this.resultData,
    this.brokerUser,
  });

  @override
  Future<BrokerUser?> getAuthenticatedBroker() async => brokerUser;

  @override
  Future<DashboardDataResult> fetchDashboardData() async => resultData;
}

void main() {
  const testBroker = BrokerUser(
    id: 'broker-100',
    email: 'nilesh.sharma@rmbroker.in',
    fullName: 'Nilesh Sharma',
    role: 'broker',
  );

  Widget createTestWidget({
    required DashboardRepository repository,
    Size screenSize = const Size(412, 915),
  }) {
    return ProviderScope(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: screenSize),
          child: const DashboardScreen(),
        ),
      ),
    );
  }

  group('DashboardScreen UI & Layout Tests', () {
    testWidgets('renders header, branding, live badge, and broker profile initials', (
      tester,
    ) async {
      final repo = MockDashboardRepository(
        brokerUser: testBroker,
        resultData: DashboardDataSuccess(
          metrics: BrokerDashboardMetrics.fromJson({
            'kpis': {
              'activeDealsCount': 3,
              'openRequirementsCount': 8,
              'partiallyAllocatedCount': 1,
              'availableOffersCount': 6,
              'awaitingConfirmationCount': 2,
              'dispatchDueCount': 0,
              'deliveriesAwaitingConfirmationCount': 0,
              'commissionThisMonth': '₹15,000',
              'openDisputesCount': 0,
            },
          }),
        ),
      );

      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Branding & Desk title
      expect(find.text('RMBroker'), findsOneWidget);
      expect(find.text('COMMODITY DESK'), findsOneWidget);
      expect(find.byType(StatusBadge), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);

      // Header More (⋮) replaces the initials avatar (RB-MORE-ENTRYPOINTS-01)
      expect(find.byKey(const ValueKey('header_more_button')), findsOneWidget);
      expect(find.text('NS'), findsNothing);

      // Welcome Banner
      expect(find.text('Nilesh Sharma'), findsOneWidget);
      expect(find.text('BROKER'), findsOneWidget);
      expect(find.textContaining('does not own or store physical commodity inventory'), findsOneWidget);
    });

    testWidgets('renders all 8 summary metrics with authoritative values', (
      tester,
    ) async {
      final repo = MockDashboardRepository(
        brokerUser: testBroker,
        resultData: DashboardDataSuccess(
          metrics: BrokerDashboardMetrics.fromJson({
            'kpis': {
              'activeDealsCount': 4,
              'openRequirementsCount': 11,
              'partiallyAllocatedCount': 2,
              'availableOffersCount': 9,
              'awaitingConfirmationCount': 1,
              'dispatchDueCount': 3,
              'commissionThisMonth': '₹20,000',
              'openDisputesCount': 0,
            },
          }),
        ),
      );

      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardKpiGrid), findsOneWidget);
      expect(find.text('Active Deals'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      expect(find.text('Open Requirements'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      expect(find.text('Available Offers'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);

      expect(find.text('Partially Allocated'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      expect(find.text('Awaiting Sign-off'), findsOneWidget);
      expect(find.text('Dispatch Due'), findsOneWidget);
      expect(find.text('Commission Ledger'), findsOneWidget);
      expect(find.text('Open Disputes'), findsOneWidget);
    });

    testWidgets('displays honest unavailable state when backend endpoint is not mounted', (
      tester,
    ) async {
      final repo = MockDashboardRepository(
        brokerUser: testBroker,
        resultData: const DashboardDataUnavailable(
          contractNotice: 'Backend endpoint /api/v1/broker/dashboard is pending exposure.',
        ),
      );

      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Zero fabricated numbers displayed
      expect(find.text('Backend endpoint /api/v1/broker/dashboard is pending exposure.'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
      expect(find.text('Pending API'), findsWidgets);
    });

    testWidgets('displays error card with retry button when DashboardDataError occurs', (
      tester,
    ) async {
      final repo = MockDashboardRepository(
        brokerUser: testBroker,
        resultData: const DashboardDataError(
          message: 'Database permission denied: 42501',
          code: '42501',
        ),
      );

      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Unable to Synchronize Desk Data'), findsOneWidget);
      expect(find.textContaining('Database permission denied: 42501'), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);
      expect(find.byType(QuickActionsSection), findsOneWidget);
    });

    testWidgets('displays 0 for legitimate empty counts with no Pending API badges', (
      tester,
    ) async {
      final repo = MockDashboardRepository(
        brokerUser: testBroker,
        resultData: DashboardDataSuccess(
          metrics: BrokerDashboardMetrics.empty(notice: 'Authoritative empty desk'),
        ),
      );

      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardKpiGrid), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      expect(find.text('Pending API'), findsNothing);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('renders quick actions with implemented and roadmap items', (
      tester,
    ) async {
      final repo = MockDashboardRepository(
        brokerUser: testBroker,
        resultData: DashboardDataMetricsTestResult.empty(),
      );

      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(QuickActionsSection), findsOneWidget);
      expect(find.text('Post Requirement'), findsOneWidget);
      expect(find.text('Add Offer'), findsOneWidget);
      expect(find.text('Manage Deals'), findsOneWidget);
      expect(find.text('Track Dispatch'), findsOneWidget);
      expect(find.text('View Earnings'), findsOneWidget);
      expect(find.text('New Dispute'), findsOneWidget);
      expect(find.text('Roadmap'), findsOneWidget);
    });

    testWidgets('header More and bottom-nav More open the same shared More page', (
      tester,
    ) async {
      // Same 800dp surface as the other dashboard tests use.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = MockDashboardRepository(
        brokerUser: testBroker,
        resultData: DashboardDataMetricsTestResult.empty(),
      );
      final router = AppRouter.router;
      await tester.pumpWidget(ProviderScope(
        overrides: [dashboardRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ));
      router.go('/dashboard');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3)); // splash timer from the shared router's first build
      await tester.pumpAndSettle();

      int selectedTab() => tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;
      void expectMorePage() {
        expect(find.byType(MoreScreen), findsOneWidget);
        for (final k in ['more_profile', 'more_tools', 'more_finance', 'more_settings']) {
          expect(find.byKey(Key(k)), findsOneWidget, reason: k);
        }
        expect(selectedTab(), 4, reason: 'More tab selected');
        expect(find.byType(BottomSheet), findsNothing, reason: 'no profile sheet');
      }

      // 1. Header ⋮
      await tester.tap(find.byKey(const ValueKey('header_more_button')));
      await tester.pumpAndSettle();
      expectMorePage();
      final fromHeader = tester.element(find.byType(MoreScreen));

      // 2. Back to Home, then the bottom-nav More tab: same page in the same branch.
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(selectedTab(), 0);

      // Bottom navigation unchanged: Home | Work Desk | Deals | Directory | More,
      // with the "+" FAB on Home above it.
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations.length, 5);
      expect(find.byKey(const ValueKey('home_add_fab')), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byKey(const ValueKey('home_add_fab'))).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(NavigationBar)).dy),
        reason: 'FAB sits above the bottom navigation',
      );
      final labels = ['Home', 'Work Desk', 'Deals', 'Directory', 'More'];
      for (var i = 1; i < labels.length; i++) {
        expect(
          tester.getCenter(find.descendant(of: find.byType(NavigationBar), matching: find.text(labels[i - 1]))).dx,
          lessThan(tester.getCenter(find.descendant(of: find.byType(NavigationBar), matching: find.text(labels[i]))).dx),
          reason: '${labels[i - 1]} before ${labels[i]}',
        );
      }
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Directory')));
      // The Directory list shows a loading spinner; pump fixed frames.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(selectedTab(), 3, reason: 'Directory tab works');
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Home')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expectMorePage();
      expect(identical(tester.element(find.byType(MoreScreen)), fromHeader), isTrue,
          reason: 'one shared More destination (same branch state)');

      // 3. Profile is reachable through More > Profile.
      await tester.tap(find.byKey(const Key('more_profile')));
      // The profile screen shows a loading spinner; pump fixed frames.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BrokerProfileScreen), findsOneWidget, reason: 'existing profile screen');
    });

    testWidgets('"+" FAB shows exactly Add Requirement and Add Offer; dismissible', (
      tester,
    ) async {
      final repo = MockDashboardRepository(
        brokerUser: testBroker,
        resultData: DashboardDataMetricsTestResult.empty(),
      );

      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(
        find.descendant(of: find.byType(FloatingActionButton), matching: find.byIcon(LucideIcons.plus)),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('home_add_fab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home_add_requirement')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_add_offer')), findsOneWidget);
      expect(find.text('Add Requirement'), findsOneWidget);
      expect(find.text('Add Offer'), findsWidgets); // also a dashboard quick action
      expect(
        find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListTile)),
        findsNWidgets(2),
        reason: 'exactly two actions, no combined option',
      );
      expect(find.textContaining('Both'), findsNothing);
      final tileHeight = tester.getSize(find.byKey(const ValueKey('home_add_offer'))).height;
      expect(tileHeight, greaterThanOrEqualTo(48));

      // Dismiss by tapping outside, then by Back.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.byKey(const ValueKey('home_add_fab')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('Add Requirement / Add Offer close the menu and open the existing forms', (
      tester,
    ) async {
      final repo = MockDashboardRepository(
        brokerUser: testBroker,
        resultData: DashboardDataMetricsTestResult.empty(),
      );
      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      for (final (key, sheet) in [
        ('home_add_requirement', CreateRequirementSheet),
        ('home_add_offer', CreateOfferSheet),
      ]) {
        await tester.tap(find.byKey(const ValueKey('home_add_fab')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(key)));
        // The forms load master data with a spinner; pump fixed frames.
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(ValueKey(key)), findsNothing, reason: 'menu closed first');
        expect(find.byType(sheet), findsOneWidget, reason: key);
        Navigator.of(tester.element(find.byType(sheet))).pop();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
      }
    });

    testWidgets('Broker Desk moved to the header still opens the desk sheet', (
      tester,
    ) async {
      final repo = MockDashboardRepository(
        brokerUser: testBroker,
        resultData: DashboardDataMetricsTestResult.empty(),
      );

      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('header_broker_desk_button')));
      await tester.pumpAndSettle();

      // Verify communication desk sheet
      expect(find.text('Broker Desk'), findsOneWidget);
      expect(find.text('Directory'), findsWidgets);
      expect(find.text('Mandi Support'), findsOneWidget);
      expect(find.textContaining('Direct broker phone and WhatsApp'), findsNothing);
    });

    testWidgets('renders without overflow on compact 360x640 mobile screen', (
      tester,
    ) async {
      final repo = MockDashboardRepository(
        brokerUser: testBroker,
        resultData: DashboardDataMetricsTestResult.empty(),
      );

      await tester.pumpWidget(
        createTestWidget(
          repository: repo,
          screenSize: const Size(360, 640),
        ),
      );
      await tester.pumpAndSettle();

      // Confirm no render overflow exception occurred
      expect(tester.takeException(), isNull);
    });
  });

  group('ModulePlaceholderScreen Tests', () {
    testWidgets('renders title, module code, and return button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ModulePlaceholderScreen(
            title: 'Logistics & Dispatch Tracking',
            moduleCode: 'RB-LOG-01',
            description: 'Vehicle tracking scheduled for future sprint.',
            icon: LucideIcons.truck,
          ),
        ),
      );

      expect(find.text('Logistics & Dispatch Tracking'), findsWidgets);
      expect(find.text('MODULE: RB-LOG-01 • SCHEDULED IN ROADMAP'), findsOneWidget);
      expect(find.text('Vehicle tracking scheduled for future sprint.'), findsOneWidget);
      expect(find.text('Return to Dashboard'), findsOneWidget);
    });
  });
}

class DashboardDataMetricsTestResult extends DashboardDataSuccess {
  DashboardDataMetricsTestResult.empty()
    : super(metrics: BrokerDashboardMetrics.empty());
}
