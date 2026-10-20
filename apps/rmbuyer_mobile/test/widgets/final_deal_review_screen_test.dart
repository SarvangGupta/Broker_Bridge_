import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/deals/data/buyer_deals_repository.dart';
import 'package:rmbuyer_mobile/features/deals/domain/final_deal_review_model.dart';
import 'package:rmbuyer_mobile/features/deals/presentation/final_deal_review_screen.dart';

void main() {
  Widget buildTestWidget({
    required String dealId,
    BuyerDealsRepository? repo,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: FinalDealReviewScreen(
        dealId: dealId,
        repository: repo,
      ),
    );
  }

  setUp(() {
    BuyerDealsRepository.resetStore();
  });

  group('RB-BUYER-06: FinalDealReviewScreen Widget Tests', () {
    testWidgets('Renders commercial overview, visual diff, charges breakdown, and trade milestones', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget(dealId: 'DEAL-2026-TEST-201'));
      await tester.pumpAndSettle();

      // Verify Header & References
      expect(find.text('Deal Ref: DEAL-2026-TEST-201'), findsOneWidget);
      expect(find.text('Mandate Ref: REQ-2026-062'), findsOneWidget);
      expect(find.textContaining('Deal Snapshot v2'), findsOneWidget);
      expect(find.text('AWAITING BUYER CONFIRMATION'), findsWidgets);

      // Verify Counterparty Shield Banner
      expect(find.textContaining('Counterparty Shield:'), findsOneWidget);

      // Verify Visual Diff Card (comparing current v2 vs previous v1)
      expect(find.text('Changes in Version 2 (vs v1)'), findsOneWidget);
      expect(find.text('Base Commodity Rate'), findsOneWidget);

      // Verify Commercial Terms
      expect(find.textContaining('Agreed Commercial Terms (Yellow Maize / Corn)'), findsOneWidget);
      expect(find.text('250.0 MT'), findsWidgets);

      // Verify Transparent Charges Ledger
      expect(find.text('Transparent Charges Ledger'), findsOneWidget);
      expect(find.text('Brokerage & Facilitation Fee'), findsOneWidget);
      expect(find.text('Mandi Cess & Weighment Handling'), findsOneWidget);
      expect(find.text('Transit Escrow & Quality Assurance Cover'), findsOneWidget);

      // Verify Quality Parameters Table
      expect(find.text('Agreed Quality Parameters'), findsOneWidget);
      expect(find.text('Moisture Content'), findsOneWidget);
      expect(find.text('Foreign Matter / Admixture'), findsOneWidget);

      // Verify Trade Execution Milestones Tracker
      expect(find.text('Trade Execution Lifecycle'), findsOneWidget);
      expect(find.text('Deal Confirmation'), findsOneWidget);
      expect(find.text('Contract Issuance & Trade Slip'), findsOneWidget);
      expect(find.text('Weighbridge & Dispatch Notice'), findsOneWidget);

      // Verify Bottom Action Buttons
      expect(find.text('Request Amendment'), findsOneWidget);
      expect(find.text('Confirm Deal'), findsOneWidget);
    });

    testWidgets('Tapping Confirm Deal opens explicit confirmation bottom sheet and confirms deal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget(dealId: 'DEAL-2026-TEST-202'));
      await tester.pumpAndSettle();

      final confirmBtn = find.text('Confirm Deal');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify Modal Title & Summary
      expect(find.text('Confirm Final Deal Terms'), findsOneWidget);
      expect(find.textContaining('Yellow Maize / Corn'), findsWidgets);
      expect(find.textContaining('By clicking Confirm Deal, you formally approve this commercial snapshot'), findsOneWidget);

      // Verify Checkbox is initially unchecked
      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);

      // Tap Checkbox to agree
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Submit confirmation via modal confirm button
      final modalConfirmBtn = find.byKey(const Key('modal_confirm_deal_btn'));
      expect(modalConfirmBtn, findsOneWidget);
      await tester.tap(modalConfirmBtn);
      await tester.pumpAndSettle();

      // Verify Status updated to Buyer Confirmed and Banner displayed
      expect(find.text('BUYER CONFIRMED'), findsWidgets);
      expect(find.textContaining('Deal Snapshot v2 Officially Confirmed'), findsOneWidget);
    });

    testWidgets('Tapping Request Amendment opens dialog, validates min 5 chars, and submits amendment', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget(dealId: 'DEAL-2026-TEST-203'));
      await tester.pumpAndSettle();

      final amendBtn = find.text('Request Amendment');
      expect(amendBtn, findsOneWidget);
      await tester.tap(amendBtn);
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.text('Request Amendment'), findsWidgets);
      expect(find.text('Submit Request'), findsOneWidget);

      // Test short validation
      await tester.enterText(find.byType(TextField), 'No');
      await tester.tap(find.text('Submit Request'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter at least 5 characters.'), findsOneWidget);

      // Enter valid reason
      await tester.enterText(find.byType(TextField), 'Please shift delivery window by 3 days.');
      await tester.tap(find.text('Submit Request'));
      await tester.pumpAndSettle();

      // Verify status updated to Amendment Required
      expect(find.text('AMENDMENT REQUIRED'), findsWidgets);
      expect(find.textContaining('Amendment Requested. Awaiting revised commercial proposal snapshot'), findsOneWidget);
    });

    testWidgets('Already confirmed deal displays confirmation banner and disables confirmation actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const dealId = 'DEAL-2026-TEST-204';
      final repo = BuyerDealsRepository();
      // Pre-confirm the deal in repo
      await repo.confirmFinalDeal(const ConfirmDealInput(
        dealId: dealId,
        expectedVersion: 2,
        buyerConfirmed: true,
      ));

      await tester.pumpWidget(buildTestWidget(dealId: dealId, repo: repo));
      await tester.pumpAndSettle();

      // Confirm button should not be present
      expect(find.text('Confirm Deal'), findsNothing);
      expect(find.text('Request Amendment'), findsNothing);
      expect(find.textContaining('Deal Snapshot v2 Officially Confirmed'), findsOneWidget);
      expect(find.text('Completed — Confirmed by Buyer'), findsOneWidget);
    });
  });
}
