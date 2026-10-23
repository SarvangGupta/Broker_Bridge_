import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/core/widgets/module_placeholder_screen.dart';
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

      // Broker Initials Avatar
      expect(find.text('NS'), findsOneWidget);

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

    testWidgets('tapping profile avatar opens profile bottom sheet with sign out access', (
      tester,
    ) async {
      final repo = MockDashboardRepository(
        brokerUser: testBroker,
        resultData: DashboardDataMetricsTestResult.empty(),
      );

      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Tap avatar initials
      await tester.tap(find.text('NS'));
      await tester.pumpAndSettle();

      // Verify bottom sheet contents
      expect(find.text('nilesh.sharma@rmbroker.in'), findsOneWidget);
      expect(find.text('Jaipur Mandi Commodity Exchange'), findsOneWidget);
      expect(find.text('Sign Out from Desk'), findsOneWidget);
    });

    testWidgets('tapping quick dial FAB opens broker communication desk sheet', (
      tester,
    ) async {
      final repo = MockDashboardRepository(
        brokerUser: testBroker,
        resultData: DashboardDataMetricsTestResult.empty(),
      );

      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Tap phone call FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify communication desk sheet
      expect(find.text('Broker Communication Desk'), findsOneWidget);
      expect(find.text('Open Counterparty Directory'), findsOneWidget);
      expect(find.text('Jaipur Mandi Support Line'), findsOneWidget);
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
