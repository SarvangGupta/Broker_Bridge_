import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/app/router/app_router.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_negotiation_model.dart';
import 'package:rmbroker_mobile/features/work/presentation/controllers/requirements_controller.dart';
import 'package:rmbroker_mobile/features/work/presentation/screens/requirement_detail_screen.dart';
import 'package:rmbroker_mobile/features/work/presentation/work_screen.dart';

class MockWorkRepository extends WorkRepository {
  final List<RequirementItem> mockRequirements;
  MockWorkRepository({required this.mockRequirements});

  @override
  Future<WorkDataResult<List<RequirementItem>>> getRequirements({
    String? searchQuery,
    RequirementStatus? statusFilter,
  }) async {
    return WorkSuccess(mockRequirements);
  }

  @override
  Future<WorkDataResult<RequirementNegotiationData>> getRequirementNegotiationDetails(
    String requirementId,
  ) async {
    return WorkSuccess(
      RequirementNegotiationData(
        requirementId: requirementId,
        requestId: requirementId,
        currentVersionNumber: 1,
        currentStatus: 'Open',
        offeredPrice: 28500,
        proposedQuantity: 50,
        unitSymbol: 'MT',
        deliveryTerms: 'Ex-Warehouse Jaipur Depot',
        rounds: [],
      ),
    );
  }
}

void main() {
  final req = RequirementItem(
    id: '60000000-0000-0000-0000-000000000000',
    ref: '#REQ-600000',
    buyerCompanyId: 'buyer-02',
    buyerCompanyName: 'RBTEST Golden Harvest Flour Mills',
    isBuyerVerified: true,
    buyerTrustScore: 90,
    commodityId: 'comm-wheat',
    commodityName: 'Sharbati Wheat',
    gradeId: 'grade-a',
    gradeName: 'Premium Sharbati',
    requestedQuantity: 50.0,
    allocatedQuantity: 0.0,
    contractedQuantity: 0.0,
    deliveredQuantity: 0.0,
    acceptedQuantity: 0.0,
    disputedQuantity: 0.0,
    remainingQuantity: 50.0,
    unitId: 'unit-mt',
    unitName: 'Metric Tonne',
    unitSymbol: 'MT',
    targetPrice: 28500.0,
    deliveryTerms: 'Ex-Warehouse Jaipur Depot',
    targetDate: DateTime.now().add(const Duration(days: 10)),
    targetDateFormatted: '27 Oct 2026',
    isUrgent: false,
    hoursUntilTarget: 240,
    isExpired: false,
    status: RequirementStatus.open,
    createdAt: DateTime.now(),
  );

  testWidgets('End-to-End Requirement Detail Navigation & Work Desk responsiveness', (tester) async {
    final mockRepo = MockWorkRepository(mockRequirements: [req]);
    final router = AppRouter.router;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    router.go('/work');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    debugPrint('Check 1: WorkScreen is displayed with card');
    expect(find.byType(WorkScreen), findsOneWidget);
    expect(find.text('#REQ-600000'), findsOneWidget);

    debugPrint('Check 2: Tap #REQ-600000 card');
    await tester.tap(find.text('#REQ-600000'));
    await tester.pumpAndSettle();

    debugPrint('Check 3: Dedicated RequirementDetailScreen is opened');
    expect(find.byType(RequirementDetailScreen), findsOneWidget);
    expect(find.text('Sharbati Wheat'), findsOneWidget);
    expect(find.text('Grade: Premium Sharbati'), findsOneWidget);
    expect(find.text('Quantity Breakdown'), findsOneWidget);

    debugPrint('Check 4: Tap Back button to return to Work Desk');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(RequirementDetailScreen), findsNothing);
    expect(find.byType(WorkScreen), findsOneWidget);

    debugPrint('Check 5: Navigate to Deals tab via bottom nav');
    await tester.tap(find.text('Deals'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Deals'), findsWidgets);

    debugPrint('Check 6: Navigate to Directory tab via bottom nav');
    await tester.tap(find.text('Directory'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Directory'), findsWidgets);

    debugPrint('Check 7: Return to Work Desk tab via bottom nav');
    await tester.tap(find.text('Work Desk'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(WorkScreen), findsOneWidget);

    debugPrint('Check 8: Verify Work Desk is fully responsive and can reopen RequirementDetailScreen');
    await tester.tap(find.text('#REQ-600000'));
    await tester.pumpAndSettle();
    expect(find.byType(RequirementDetailScreen), findsOneWidget);

    debugPrint('Check 9: Back navigation returns cleanly to Work Desk again');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(RequirementDetailScreen), findsNothing);
    expect(find.byType(WorkScreen), findsOneWidget);
  });
}
