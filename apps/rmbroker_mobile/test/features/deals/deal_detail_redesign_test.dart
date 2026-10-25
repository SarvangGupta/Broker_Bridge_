import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmbroker_mobile/features/deals/data/deal_repository.dart';
import 'package:rmbroker_mobile/features/deals/domain/deal_model.dart';
import 'package:rmbroker_mobile/features/deals/presentation/controllers/deals_controller.dart';
import 'package:rmbroker_mobile/features/deals/presentation/screens/deal_detail_screen.dart';

// RB-DEAL-DETAILS-REDESIGN-01. Fakes only.

class _Repo extends DealRepository {
  final DealDetailItem detail;
  int detailCalls = 0;
  _Repo(this.detail);

  @override
  Future<DealDataResult<List<DealItem>>> getDeals({DealStatus? statusFilter, String? search}) async =>
      DealSuccess([detail.deal]);

  @override
  Future<DealDataResult<DealDetailItem>> getDealDetail(String dealId) async {
    detailCalls++;
    return DealSuccess(detail);
  }

  @override
  Future<DealDataResult<List<DealVersionItem>>> getDealVersionHistory(String dealId) async =>
      const DealSuccess([]);
}

DealDetailItem detail({
  String buyer = 'RBTEST AgrInnovate Feeds Pvt Ltd',
  String seller = 'RBTEST Hadoti Grain Producers Co',
  String commodity = 'Yellow Maize (Corn)',
  bool buyerConfirmed = false,
}) =>
    DealDetailItem(
      deal: DealItem(
        id: 'deal-1',
        ref: 'DL-900000',
        quotationId: 'q-1',
        requirementId: 'req-1',
        allocationReference: 'ALC-000042',
        commodityName: commodity,
        gradeName: 'Grade A Milling',
        buyerCompanyId: 'b',
        buyerCompanyName: buyer,
        sellerCompanyId: 's',
        sellerCompanyName: seller,
        agreedQuantity: 40,
        unitSymbol: 'MT',
        agreedPrice: 22700,
        totalValuation: 908000,
        priceBasis: 'FOR_DESTINATION',
        deliveryLocation: 'Kota Mandi',
        status: DealStatus.negotiation,
        latestVersionNumber: 2,
        createdAt: DateTime(2026, 10, 19, 2, 47),
      ),
      confirmations: DealConfirmationState(latestVersionNumber: 2, buyerConfirmed: buyerConfirmed),
      deliveryTerms: 'FOR Destination',
      paymentTerms: '100% Advance',
      packagingType: '50kg HDPE Bags',
      brokerCommissionRate: 50,
    );

void main() {
  Future<_Repo> pump(WidgetTester tester, DealDetailItem d, {Size size = const Size(1080, 2160), double dpr = 2.75}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    final repo = _Repo(d);
    final router = GoRouter(
      initialLocation: '/deals/deal-1',
      routes: [
        GoRoute(path: '/deals/:id', builder: (_, s) => DealDetailScreen(dealId: s.pathParameters['id']!)),
        GoRoute(path: '/requirements/:id', builder: (_, s) => Text('REQ ${s.pathParameters['id']}')),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [dealRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('one top card with both parties; each status shown once; old sections gone', (tester) async {
    await pump(tester, detail(buyerConfirmed: true));
    final card = find.byKey(const ValueKey('deal_parties_card'));
    expect(find.descendant(of: card, matching: find.text('RBTEST AgrInnovate Feeds Pvt Ltd')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('RBTEST Hadoti Grain Producers Co')), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Counterparties'), findsNothing);
    expect(find.text('Party Confirmation Verification'), findsNothing);
    expect(find.textContaining('Per business rules'), findsNothing);
    expect(find.byKey(const ValueKey('record_acceptance_button')), findsOneWidget);
  });

  testWidgets('summary shows commodity, grade, status, version, volume, rate, total', (tester) async {
    await pump(tester, detail());
    final s = find.byKey(const ValueKey('deal_summary_card'));
    for (final t in ['Yellow Maize (Corn)', 'Grade: Grade A Milling', 'Negotiating', 'Version 2', '40 MT',
      '₹22,700 / MT', '₹9,08,000']) {
      expect(find.descendant(of: s, matching: find.text(t)), findsOneWidget, reason: t);
    }
  });

  testWidgets('sections start collapsed and expand independently, with no extra loads', (tester) async {
    final repo = await pump(tester, detail());
    final calls = repo.detailCalls;
    // Collapsed: no section body content.
    expect(find.text('50kg HDPE Bags'), findsNothing);
    expect(find.text('Authoritative Broker Ledger Active'), findsNothing);
    expect(find.text('Authorized Intermediary Record'), findsNothing);

    await tester.tap(find.text('Contract Terms & Logistics'));
    await tester.pumpAndSettle();
    expect(find.text('50kg HDPE Bags'), findsOneWidget);
    expect(find.text('100% Advance'), findsOneWidget);
    expect(find.text('Authoritative Broker Ledger Active'), findsNothing);
    expect(find.text('Authorized Intermediary Record'), findsNothing);

    await tester.ensureVisible(find.text('Brokerage Commission Ledger'));
    await tester.tap(find.text('Brokerage Commission Ledger'));
    await tester.pumpAndSettle();
    expect(find.text('Authoritative Broker Ledger Active'), findsOneWidget);
    expect(find.text('View Commission Breakdown & Payment Ledger'), findsOneWidget);
    expect(find.text('50kg HDPE Bags'), findsOneWidget, reason: 'terms stays open');

    await tester.ensureVisible(find.text('Traceability & Audit Record'));
    await tester.tap(find.text('Traceability & Audit Record'));
    await tester.pumpAndSettle();
    expect(find.text('Authorized Intermediary Record'), findsOneWidget);
    expect(find.text('ALC-000042'), findsOneWidget);

    await tester.ensureVisible(find.text('Contract Terms & Logistics'));
    await tester.tap(find.text('Contract Terms & Logistics'));
    await tester.pumpAndSettle();
    expect(find.text('50kg HDPE Bags'), findsNothing);
    expect(find.text('Authoritative Broker Ledger Active'), findsOneWidget, reason: 'commission stays open');
    expect(repo.detailCalls, calls, reason: 'expanding never refetches');
  });

  testWidgets('negotiation details navigates; bottom actions present and open their sheets', (tester) async {
    // The existing sheets are laid out for >= 800dp in their own tests.
    await pump(tester, detail(), size: const Size(800, 1600), dpr: 1.0);
    expect(find.text('Negotiate Terms (Propose v3)'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('terms_history_button')));
    await tester.tap(find.byKey(const ValueKey('terms_history_button')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('negotiate_terms_button')));
    await tester.tap(find.byKey(const ValueKey('negotiate_terms_button')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Negotiation Details'));
    await tester.tap(find.text('Negotiation Details'));
    await tester.pumpAndSettle();
    expect(find.text('REQ req-1'), findsOneWidget);
  });

  testWidgets('long names on a small 320dp screen do not overflow', (tester) async {
    await pump(
      tester,
      detail(
        buyer: 'RBTEST Very Long Integrated Agro Commodities Processing & Trading Private Limited',
        seller: 'RBTEST Extremely Long Named Grain Producers Cooperative Society of Hadoti Region',
        commodity: 'Yellow Maize (Corn) Premium Export Quality Non-GMO Feed Grade',
      ),
      size: const Size(640, 1136),
      dpr: 2.0,
    );
    expect(tester.takeException(), isNull);
    for (final t in ['Contract Terms & Logistics', 'Brokerage Commission Ledger', 'Traceability & Audit Record']) {
      await tester.ensureVisible(find.text(t));
      await tester.tap(find.text(t));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
