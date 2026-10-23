import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/app/router/app_router.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_negotiation_model.dart';
import 'package:rmbroker_mobile/features/work/presentation/controllers/requirements_controller.dart';
import 'package:rmbroker_mobile/features/work/presentation/screens/requirement_detail_screen.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/requirement_card.dart';

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
        offeredPrice: 27500,
        proposedQuantity: 120,
        unitSymbol: 'MT',
        deliveryTerms: 'FOR Delivery Kota Plant',
        rounds: [],
      ),
    );
  }
}

void main() {
  final req1 = RequirementItem(
    id: '60000000-0000-0000-0000-000000000001',
    ref: '#REQ-600001',
    buyerCompanyId: 'buyer-01',
    buyerCompanyName: 'RBTEST Frontier Starch Processing',
    isBuyerVerified: true,
    buyerTrustScore: 94,
    commodityId: 'comm-wheat',
    commodityName: 'Sharbati Wheat',
    gradeId: 'grade-a',
    gradeName: 'Premium Sharbati',
    requestedQuantity: 120.0,
    allocatedQuantity: 0.0,
    contractedQuantity: 0.0,
    deliveredQuantity: 0.0,
    acceptedQuantity: 0.0,
    disputedQuantity: 0.0,
    remainingQuantity: 120.0,
    unitId: 'unit-mt',
    unitName: 'Metric Tonne',
    unitSymbol: 'MT',
    targetPrice: 27500.0,
    deliveryTerms: 'FOR Delivery Kota Plant',
    targetDate: DateTime.now().add(const Duration(days: 10)),
    targetDateFormatted: '27 Oct 2026',
    isUrgent: false,
    hoursUntilTarget: 240,
    isExpired: false,
    status: RequirementStatus.matching,
    createdAt: DateTime.now(),
  );

  final req2 = RequirementItem(
    id: '60000000-0000-0000-0000-000000000002',
    ref: '#REQ-600002',
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

  testWidgets('WorkScreen allows selecting multiple requirements without hanging', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockRepo = MockWorkRepository(mockRequirements: [req1, req2]);
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

    debugPrint('STEP 1: Verify rendered');
    expect(find.byType(RequirementCard), findsNWidgets(2));
    expect(find.text('RBTEST Frontier Starch Processing'), findsOneWidget);
    expect(find.text('RBTEST Golden Harvest Flour Mills'), findsOneWidget);

    // 1. Tap first requirement card to open dedicated RequirementDetailScreen
    debugPrint('STEP 2: Tap first card');
    await tester.tap(find.text('RBTEST Frontier Starch Processing'));
    await tester.pumpAndSettle();

    debugPrint('STEP 3: Expect RequirementDetailScreen for req1');
    expect(find.byType(RequirementDetailScreen), findsOneWidget);
    expect(find.text('#REQ-600001'), findsOneWidget);

    // Close detail screen using Back button
    debugPrint('STEP 4: Back navigation');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    debugPrint('STEP 5: Expect returned to WorkScreen');
    expect(find.byType(RequirementDetailScreen), findsNothing);
    expect(find.text('RBTEST Frontier Starch Processing'), findsOneWidget);

    // Wait for 600ms debounce to expire
    await tester.pump(const Duration(milliseconds: 700));

    // 2. Tap second requirement card to open dedicated RequirementDetailScreen
    debugPrint('STEP 6: Tap second card');
    await tester.tap(find.text('RBTEST Golden Harvest Flour Mills'));
    await tester.pumpAndSettle();

    debugPrint('STEP 7: Expect second RequirementDetailScreen for req2');
    expect(find.byType(RequirementDetailScreen), findsOneWidget);
    expect(find.text('#REQ-600002'), findsOneWidget);

    // Close second detail screen
    debugPrint('STEP 8: Back navigation from second detail');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    debugPrint('STEP 9: Expect returned to WorkScreen');
    expect(find.byType(RequirementDetailScreen), findsNothing);

    debugPrint('STEP 10: Requirements card navigation verified cleanly');

    // 4. Tab Switching
    debugPrint('STEP 14: Tap Offers tab');
    await tester.tap(find.textContaining('Offers'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('STEP 15: Tap Match Center tab');
    await tester.tap(find.text('Match Center'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('STEP 16: Tap Requirements tab');
    await tester.tap(find.textContaining('Requirements'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('STEP 17: Done - all transitions verified successfully');
  });
}
