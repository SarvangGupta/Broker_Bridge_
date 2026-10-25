import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rmbroker_mobile/features/deals/data/deal_repository.dart';
import 'package:rmbroker_mobile/features/deals/domain/deal_model.dart';
import 'package:rmbroker_mobile/features/deals/presentation/controllers/deals_controller.dart';
import 'package:rmbroker_mobile/features/deals/presentation/screens/deal_detail_screen.dart';
import 'package:rmbroker_mobile/features/deals/presentation/widgets/finalize_deal_dialog.dart';
import 'package:rmbroker_mobile/features/deals/presentation/widgets/negotiate_terms_sheet.dart';
import 'package:rmbroker_mobile/features/deals/presentation/widgets/record_party_confirmation_dialog.dart';
import 'package:rmbroker_mobile/features/deals/presentation/widgets/version_history_sheet.dart';

class FakeDealNegotiationRepository extends DealRepository {
  final bool canFinalizeInitially;
  bool updateTermsCalled = false;
  bool recordConfirmationCalled = false;
  bool finalizeCalled = false;

  FakeDealNegotiationRepository({this.canFinalizeInitially = false});

  @override
  Future<DealDataResult<DealDetailItem>> getDealDetail(String dealId) async {
    return DealSuccess(
      DealDetailItem(
        deal: DealItem(
          id: dealId,
          ref: 'DL-IND-8492',
          quotationId: 'quote-001',
          requirementId: 'req-001',
          commodityName: 'Soybean Special Yellow',
          gradeName: 'Grade FAQ A',
          buyerCompanyId: 'buyer-01',
          buyerCompanyName: 'Mahalaxmi Agro Processors',
          sellerCompanyId: 'seller-01',
          sellerCompanyName: 'Kisan Mandi Traders',
          agreedQuantity: 100,
          unitSymbol: 'MT',
          agreedPrice: 52000,
          totalValuation: 5200000,
          priceBasis: 'FOR_DESTINATION',
          deliveryLocation: 'Indore Mandi Processing Hub',
          deliveryDate: '2026-10-25',
          status: canFinalizeInitially ? DealStatus.readyToFinalize : DealStatus.negotiation,
          latestVersionNumber: 2,
          buyerConfirmed: canFinalizeInitially,
          sellerConfirmed: canFinalizeInitially,
          createdAt: DateTime(2026, 10, 15),
        ),
        confirmations: DealConfirmationState(
          latestVersionNumber: 2,
          buyerConfirmed: canFinalizeInitially,
          buyerConfirmedAt: canFinalizeInitially ? DateTime(2026, 10, 16) : null,
          sellerConfirmed: canFinalizeInitially,
          sellerConfirmedAt: canFinalizeInitially ? DateTime(2026, 10, 16) : null,
          canFinalize: canFinalizeInitially,
        ),
        deliveryTerms: 'Ex-Warehouse / FOR',
        paymentTerms: '100% Advance against Invoice',
        packagingType: '50kg HDPE Bags',
        brokerCommissionRate: 50,
        notes: 'Priority festive lot',
      ),
    );
  }

  @override
  Future<DealDataResult<List<DealVersionItem>>> getDealVersionHistory(String dealId) async {
    return DealSuccess([
      DealVersionItem(
        id: 'ver-2',
        versionNumber: 2,
        status: 'Negotiation',
        actorId: 'broker-01',
        actorName: 'Nilesh Sharma',
        actorRole: 'broker',
        createdAt: DateTime(2026, 10, 16, 11, 30),
        snapshot: const {'rate': 52000, 'quantity': 100},
        diffs: const [
          MaterialDiffItem(
            field: 'rate',
            label: 'Rate / Price',
            oldValue: 51000.0,
            newValue: 52000.0,
            type: MaterialDiffType.increased,
          ),
        ],
        changeReason: 'Seller counter-offered higher rate due to diesel hike',
      ),
      DealVersionItem(
        id: 'ver-1',
        versionNumber: 1,
        status: 'Superseded',
        actorId: 'broker-01',
        actorName: 'Nilesh Sharma',
        actorRole: 'broker',
        createdAt: DateTime(2026, 10, 15, 9, 0),
        snapshot: const {'rate': 51000, 'quantity': 100},
        diffs: const [],
        changeReason: 'Initial agreement from confirmed allocation',
      ),
    ]);
  }

  @override
  Future<DealDataResult<DealDetailItem>> updateDealTerms(UpdateDealTermsDto dto) async {
    updateTermsCalled = true;
    return getDealDetail(dto.dealId);
  }

  @override
  Future<DealDataResult<DealConfirmationState>> recordPartyConfirmation(
    PartyConfirmationDto dto,
  ) async {
    recordConfirmationCalled = true;
    return const DealSuccess(
      DealConfirmationState(
        latestVersionNumber: 2,
        buyerConfirmed: true,
        sellerConfirmed: false,
        canFinalize: false,
      ),
    );
  }

  @override
  Future<DealDataResult<String>> finalizeDeal(String dealId, int expectedVersion) async {
    finalizeCalled = true;
    return const DealSuccess('BKG-2026-8492');
  }
}

void main() {
  Widget buildTestableWidget(Widget child, DealRepository repository) {
    return ProviderScope(
      overrides: [
        dealRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Deal Negotiation & Confirmation Widget Tests (Sprint RB-FL-09)', () {
    testWidgets('NegotiateTermsSheet renders inputs and computes live visual diffs',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = FakeDealNegotiationRepository();
      final detail = (await repo.getDealDetail('deal-001') as DealSuccess<DealDetailItem>).data;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: NegotiateTermsSheet(dealId: 'deal-001', currentDetail: detail),
          ),
          repo,
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header and Rule Notice
      expect(find.text('Negotiate Deal Terms'), findsOneWidget);
      expect(find.textContaining('CRITICAL RULE'), findsOneWidget);
      expect(find.text('Propose Version 3 Terms'), findsOneWidget);

      // Verify initial input values
      expect(find.widgetWithText(TextFormField, '52000'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '100'), findsOneWidget);

      // Modify rate to 54000 to trigger live visual diff
      final priceField = find.widgetWithText(TextFormField, '52000');
      await tester.enterText(priceField, '54000');
      await tester.pumpAndSettle();

      // Check that Live Visual Diff is displayed
      expect(find.textContaining('Live Visual Diff'), findsOneWidget);
      expect(find.text('54000.0'), findsOneWidget);

      // Fill amendment reason
      final reasonField = find.byType(TextFormField).last;
      await tester.enterText(reasonField, 'Buyer accepted revised transport surcharge');
      await tester.pumpAndSettle();

      // Tap submit button
      await tester.tap(find.text('Propose Version 3 Terms'));
      await tester.pumpAndSettle();

      expect(repo.updateTermsCalled, isTrue);
    });

    testWidgets('VersionHistorySheet renders chronological versions and diff chips',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = FakeDealNegotiationRepository();

      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: VersionHistorySheet(dealId: 'deal-001', dealRef: 'DL-IND-8492'),
          ),
          repo,
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Terms Version History'), findsOneWidget);
      expect(find.textContaining('DL-IND-8492'), findsOneWidget);

      // Verify Version 2 & Version 1 cards
      expect(find.text('Version 2'), findsOneWidget);
      expect(find.text('Version 1'), findsOneWidget);

      // Verify change reasons
      expect(find.textContaining('Seller counter-offered higher rate'), findsOneWidget);

      // Verify diff chips
      expect(find.textContaining('Rate / Price: 51000.0 → 52000.0'), findsOneWidget);
    });

    testWidgets('RecordPartyConfirmationDialog allows selecting party and recording acceptance',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = FakeDealNegotiationRepository();
      final detail = (await repo.getDealDetail('deal-001') as DealSuccess<DealDetailItem>).data;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: RecordPartyConfirmationDialog(dealId: 'deal-001', detail: detail),
          ),
          repo,
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & party selectors
      expect(find.text('Record Confirmation'), findsOneWidget);
      expect(find.text('Targeting Version 2 Terms'), findsOneWidget);
      expect(find.text('Buyer'), findsOneWidget);
      expect(find.text('Seller'), findsOneWidget);

      // Enter verification notes
      final notesField = find.byType(TextFormField);
      await tester.enterText(notesField, 'Buyer confirmed via signed mandate');
      await tester.pumpAndSettle();

      // Tap submit
      final submitButton = find.widgetWithText(ElevatedButton, 'Record BUYER Acceptance');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(repo.recordConfirmationCalled, isTrue);
    });

    testWidgets('FinalizeDealDialog displays pre-flight checklist and enforces confirmation lock',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Case A: Missing confirmations -> Finalize is blocked
      final unconfirmedRepo = FakeDealNegotiationRepository(canFinalizeInitially: false);
      final unconfirmedDetail =
          (await unconfirmedRepo.getDealDetail('deal-001') as DealSuccess<DealDetailItem>).data;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: FinalizeDealDialog(dealId: 'deal-001', detail: unconfirmedDetail),
          ),
          unconfirmedRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Finalize Contract Gate'), findsOneWidget);
      expect(find.text('GATE BLOCKED: Both Buyer and Seller must confirm terms before finalization can proceed.'),
          findsOneWidget);

      // Case B: Both confirmed -> Checkbox enables locking
      final confirmedRepo = FakeDealNegotiationRepository(canFinalizeInitially: true);
      final confirmedDetail =
          (await confirmedRepo.getDealDetail('deal-001') as DealSuccess<DealDetailItem>).data;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: FinalizeDealDialog(dealId: 'deal-001', detail: confirmedDetail),
          ),
          confirmedRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CheckboxListTile), findsOneWidget);

      // Check the understanding checkbox
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      // Tap Finalize
      final finalizeBtn = find.widgetWithText(ElevatedButton, 'Lock & Finalize Contract');
      await tester.tap(finalizeBtn);
      await tester.pumpAndSettle();

      expect(confirmedRepo.finalizeCalled, isTrue);
      expect(find.text('OFFICIAL BOOKING REFERENCE'), findsOneWidget);
      expect(find.text('BKG-2026-8492'), findsOneWidget);
    });

    testWidgets('DealDetailScreen renders version indicator, confirmation cards, and workflow buttons',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = FakeDealNegotiationRepository(canFinalizeInitially: false);

      await tester.pumpWidget(
        buildTestableWidget(
          const DealDetailScreen(dealId: 'deal-001'),
          repo,
        ),
      );
      await tester.pumpAndSettle();

      // Header metrics
      expect(find.text('DL-IND-8492'), findsWidgets);
      expect(find.text('Version 2'), findsOneWidget);
      expect(find.text('Soybean Special Yellow'), findsOneWidget);

      // One confirmation chip per party (top card only)
      expect(find.text('Party Confirmation Verification'), findsNothing);
      expect(find.text('Pending'), findsNWidgets(2));
      expect(find.text('Record Counterparty Acceptance'), findsOneWidget);

      // Operational buttons; cancel lives in the overflow menu
      expect(find.text('Negotiate Terms (Propose v3)'), findsOneWidget);
      expect(find.text('Inspect Terms History & Diffs'), findsOneWidget);
      expect(find.byKey(const ValueKey('deal_more_menu')), findsOneWidget);

      // App bar has Version History button
      expect(find.byIcon(LucideIcons.history), findsWidgets);
    });
  });
}
