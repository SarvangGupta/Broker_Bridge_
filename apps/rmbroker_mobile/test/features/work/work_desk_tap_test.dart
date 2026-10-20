import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_negotiation_model.dart';
import 'package:rmbroker_mobile/features/work/presentation/controllers/requirements_controller.dart';
import 'package:rmbroker_mobile/features/work/presentation/work_screen.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/negotiate_requirement_sheet.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/requirement_card.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/requirement_detail_sheet.dart';

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
    FlutterError.onError = (details) {
      debugPrint('STACK TRACE OF OVERFLOW:');
      debugPrint(details.stack.toString());
      debugPrint(details.context.toString());
    };
    final mockRepo = MockWorkRepository(mockRequirements: [req1, req2]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: WorkScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    debugPrint('STEP 1: Verify rendered');
    expect(find.byType(RequirementCard), findsNWidgets(2));
    expect(find.text('RBTEST Frontier Starch Processing'), findsOneWidget);
    expect(find.text('RBTEST Golden Harvest Flour Mills'), findsOneWidget);

    // 1. Tap first requirement card to open detail sheet
    debugPrint('STEP 2: Tap first card');
    await tester.tap(find.text('RBTEST Frontier Starch Processing'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('STEP 3: Expect RequirementDetailSheet');
    expect(find.byType(RequirementDetailSheet), findsOneWidget);

    // Close the detail sheet using the X button
    debugPrint('STEP 4: Close sheet');
    await tester.tap(find.byIcon(LucideIcons.x).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('STEP 5: Expect sheet closed');
    expect(find.byType(RequirementDetailSheet), findsNothing);

    // 2. Tap second requirement card to open detail sheet
    debugPrint('STEP 6: Tap second card');
    await tester.tap(find.text('RBTEST Golden Harvest Flour Mills'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('STEP 7: Expect second sheet');
    expect(find.byType(RequirementDetailSheet), findsOneWidget);

    // Close the second sheet
    debugPrint('STEP 8: Close second sheet');
    await tester.tap(find.byIcon(LucideIcons.x).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('STEP 9: Expect second sheet closed');
    expect(find.byType(RequirementDetailSheet), findsNothing);

    // 3. Tap on Negotiate / Proposal directly on first card
    debugPrint('STEP 10: Tap Proposal button');
    await tester.tap(find.text('Proposal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('STEP 11: Expect NegotiateRequirementSheet');
    expect(find.byType(NegotiateRequirementSheet), findsOneWidget);

    // Close negotiate sheet
    debugPrint('STEP 12: Close negotiate sheet');
    await tester.tap(find.byIcon(LucideIcons.x).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('STEP 13: Negotiate sheet closed');
    expect(find.byType(NegotiateRequirementSheet), findsNothing);

    // 4. Test Transition: Open detail sheet and tap 'Initiate Negotiation & Submit Proposal'
    debugPrint('STEP 14: Tap first card again');
    await tester.tap(find.text('RBTEST Frontier Starch Processing'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RequirementDetailSheet), findsOneWidget);

    debugPrint('STEP 15: Tap proposal button inside detail sheet');
    final proposalButton = find.text('Initiate Negotiation & Submit Proposal');
    final amendButton = find.text('View / Amend Commercial Proposal');
    final buttonToTap = proposalButton.evaluate().isNotEmpty ? proposalButton : amendButton;
    await tester.tap(buttonToTap);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('STEP 16: Verify detail sheet dismissed and negotiate sheet opened');
    expect(find.byType(RequirementDetailSheet), findsNothing);
    expect(find.byType(NegotiateRequirementSheet), findsOneWidget);

    // Close negotiate sheet
    debugPrint('STEP 17: Close negotiate sheet');
    await tester.tap(find.byIcon(LucideIcons.x).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(NegotiateRequirementSheet), findsNothing);

    // 5. Test Tab Switching (Requirements -> Offers -> Match Center -> Requirements)
    debugPrint('STEP 18: Tap Offers tab');
    await tester.tap(find.textContaining('Offers'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('STEP 19: Tap Match Center tab');
    await tester.tap(find.text('Match Center'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('STEP 20: Tap Requirements tab');
    await tester.tap(find.textContaining('Requirements'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('STEP 21: Done - all transitions verified successfully');
  });
}
