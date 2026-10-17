import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/widgets/app_button.dart';
import 'package:rmbroker_mobile/features/commission/data/commission_repository.dart';
import 'package:rmbroker_mobile/features/commission/domain/commission_model.dart';
import 'package:rmbroker_mobile/features/commission/presentation/controllers/commission_controller.dart';
import 'package:rmbroker_mobile/features/commission/presentation/screens/earnings_dashboard_screen.dart';
import 'package:rmbroker_mobile/features/commission/presentation/widgets/commission_record_card.dart';
import 'package:rmbroker_mobile/features/commission/presentation/widgets/deal_commission_sheet.dart';
import 'package:rmbroker_mobile/features/commission/presentation/widgets/log_commission_payment_dialog.dart';
import 'package:rmbroker_mobile/features/deals/data/deal_repository.dart';

class MockCommissionRepository extends CommissionRepository {
  final List<CommissionRecord> mockRecords;

  MockCommissionRepository({this.mockRecords = const []});

  @override
  Future<DealDataResult<List<CommissionRecord>>> getCommissionRecords({
    CommissionStatus? status,
    String? query,
    String? period,
  }) async {
    var list = mockRecords;
    if (status != null) list = list.where((r) => r.status == status).toList();
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list.where((r) {
        return r.commodityName.toLowerCase().contains(q) ||
            r.dealReference.toLowerCase().contains(q) ||
            r.buyerCompanyName.toLowerCase().contains(q);
      }).toList();
    }
    return DealSuccess(list);
  }

  @override
  Future<DealDataResult<CommissionSummary>> getCommissionSummary({String period = 'All Time'}) async {
    return DealSuccess(CommissionSummary.fromRecords(mockRecords, period: period));
  }

  @override
  Future<DealDataResult<CommissionRecord>> getDealCommission(String dealId) async {
    final match = mockRecords.where((r) => r.dealId == dealId);
    if (match.isNotEmpty) return DealSuccess(match.first);
    return DealSuccess(mockRecords.first);
  }

  @override
  Future<DealDataResult<CommissionPaymentItem>> logCommissionPayment(LogPaymentDto dto) async {
    final item = CommissionPaymentItem(
      id: 'pay-test',
      dealId: dto.dealId,
      amount: dto.amount,
      referenceNumber: dto.referenceNumber,
      paymentDate: dto.paymentDate,
      direction: dto.direction,
      status: 'Confirmed',
      recordedBy: 'Mock Desk',
    );
    return DealSuccess(item);
  }
}

final _testNow = DateTime(2026, 10, 15);

final List<CommissionRecord> _sampleRecords = [
  CommissionRecord(
    dealId: 'deal-001',
    dealReference: 'DL-WHT-101',
    bookingReference: 'BK-2026-001',
    commodityName: 'Sharbati Wheat',
    gradeName: 'A-Grade Premium',
    buyerCompanyName: 'Rajasthan Agro Mills Ltd',
    sellerCompanyName: 'Hadoti Krishi Mandi FPO',
    agreedRatePerMT: 50.0,
    quantities: const CommissionQuantityBreakdown(
      contractedQuantity: 100.0,
      dispatchedQuantity: 100.0,
      deliveredQuantity: 100.0,
      acceptedQuantity: 100.0,
      unitSymbol: 'MT',
    ),
    grossRawMaterialValue: 2650000.0,
    calculatedCommission: 5000.0,
    eligibleCommission: 5000.0,
    invoicedAmount: 5000.0,
    paidAmount: 5000.0,
    outstandingAmount: 0.0,
    disputedAmount: 0.0,
    status: CommissionStatus.paid,
    createdAt: _testNow,
    updatedAt: _testNow,
  ),
  CommissionRecord(
    dealId: 'deal-002',
    dealReference: 'DL-SOY-103',
    bookingReference: 'BK-2026-003',
    commodityName: 'Yellow Soybean',
    gradeName: 'FAQ Standard',
    buyerCompanyName: 'Kriti Nutrients Industrial Unit',
    sellerCompanyName: 'Mewar Agri Warehouse Corp',
    agreedRatePerMT: 45.0,
    quantities: const CommissionQuantityBreakdown(
      contractedQuantity: 150.0,
      dispatchedQuantity: 150.0,
      deliveredQuantity: 150.0,
      acceptedQuantity: 150.0,
      unitSymbol: 'MT',
    ),
    grossRawMaterialValue: 7200000.0,
    calculatedCommission: 6750.0,
    eligibleCommission: 6750.0,
    invoicedAmount: 6750.0,
    paidAmount: 0.0,
    outstandingAmount: 6750.0,
    disputedAmount: 0.0,
    status: CommissionStatus.invoiced,
    createdAt: _testNow,
    updatedAt: _testNow,
  ),
  CommissionRecord(
    dealId: 'deal-003',
    dealReference: 'DL-MST-106',
    bookingReference: 'BK-2026-006',
    commodityName: 'Mustard Seed (Sarson)',
    gradeName: 'Commercial Lot',
    buyerCompanyName: 'Bharatpur Oil Expellers',
    sellerCompanyName: 'Braj FPO Kendra',
    agreedRatePerMT: 50.0,
    quantities: const CommissionQuantityBreakdown(
      contractedQuantity: 60.0,
      dispatchedQuantity: 60.0,
      deliveredQuantity: 60.0,
      acceptedQuantity: 30.0,
      disputedQuantity: 30.0,
      unitSymbol: 'MT',
    ),
    grossRawMaterialValue: 3120000.0,
    calculatedCommission: 3000.0,
    eligibleCommission: 1500.0,
    invoicedAmount: 1500.0,
    paidAmount: 0.0,
    outstandingAmount: 1500.0,
    disputedAmount: 1500.0,
    status: CommissionStatus.disputed,
    createdAt: _testNow,
    updatedAt: _testNow,
  ),
];

Widget _buildTestApp(Widget child, {CommissionRepository? repository}) {
  return ProviderScope(
    overrides: [
      commissionRepositoryProvider.overrideWithValue(
        repository ?? MockCommissionRepository(mockRecords: _sampleRecords),
      ),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  group('Commission & Brokerage UI Widget Tests (Sprint RB-FL-11)', () {
    testWidgets('EarningsDashboardScreen renders summary cards, period chips, and deal list', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(const EarningsDashboardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 1. Verify AppBar and Title
      expect(find.text('Brokerage & Earnings'), findsOneWidget);

      // 2. Verify Hero & Breakdown KPI Cards
      expect(find.text('Authoritative Eligible Commission'), findsOneWidget);
      expect(find.text('Received'), findsAtLeast(1));
      expect(find.text('Outstanding'), findsAtLeast(1));

      // Invoiced and Disputed appear in summary card, filter chip, and deal status badges
      expect(find.text('Invoiced'), findsAtLeast(1));
      expect(find.text('Disputed'), findsAtLeast(1));

      // 3. Verify Period Filters
      expect(find.text('All Time'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Last Month'), findsOneWidget);

      // 4. Verify Deal Records
      expect(find.text('DL-WHT-101'), findsOneWidget);
      expect(find.text('Sharbati Wheat'), findsOneWidget);
    });

    testWidgets('Tapping Fiduciary icon displays fiduciary boundary modal', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(const EarningsDashboardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final infoBtn = find.byTooltip('Fiduciary Principles');
      expect(infoBtn, findsOneWidget);

      await tester.tap(infoBtn);
      await tester.pumpAndSettle();

      expect(find.text('Fiduciary Boundary Rule'), findsOneWidget);
      expect(find.textContaining('must NEVER be treated as brokerage earnings'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();
      expect(find.text('Fiduciary Boundary Rule'), findsNothing);
    });

    testWidgets('Status filter chip filters deals list', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(const EarningsDashboardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Tap "Disputed" filter chip
      final disputedChip = find.widgetWithText(FilterChip, 'Disputed');
      expect(disputedChip, findsOneWidget);

      await tester.ensureVisible(disputedChip);
      await tester.tap(disputedChip);
      await tester.pumpAndSettle();

      // Only disputed deal DL-MST-106 should remain visible
      expect(find.text('DL-MST-106'), findsOneWidget);
      expect(find.text('DL-WHT-101'), findsNothing);
    });

    testWidgets('Search query filters deals by commodity or party', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(const EarningsDashboardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final searchInput = find.byType(TextField).first;
      await tester.enterText(searchInput, 'Soybean');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('DL-SOY-103'), findsOneWidget);
      expect(find.text('Yellow Soybean'), findsOneWidget);
      expect(find.text('DL-WHT-101'), findsNothing);
    });

    testWidgets('CommissionRecordCard renders calculation formula, distinct quantities, and callbacks', (tester) async {
      final now = DateTime.now();
      bool tapped = false;
      bool logPaymentTapped = false;

      final record = CommissionRecord(
        dealId: 'deal-test-1',
        dealReference: 'DL-TEST-01',
        bookingReference: 'BK-001',
        commodityName: 'Chana Bold',
        gradeName: 'Special Grade',
        buyerCompanyName: 'Buyer Agro Mill',
        sellerCompanyName: 'Seller Mandi FPO',
        agreedRatePerMT: 50.0,
        quantities: const CommissionQuantityBreakdown(
          contractedQuantity: 100.0,
          deliveredQuantity: 80.0,
          acceptedQuantity: 75.0,
          rejectedQuantity: 5.0,
          unitSymbol: 'MT',
        ),
        grossRawMaterialValue: 4500000.0,
        calculatedCommission: 5000.0,
        eligibleCommission: 3750.0,
        invoicedAmount: 3750.0,
        paidAmount: 1000.0,
        outstandingAmount: 2750.0,
        disputedAmount: 0.0,
        status: CommissionStatus.partiallyPaid,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommissionRecordCard(
              record: record,
              onTap: () => tapped = true,
              onLogPayment: () => logPaymentTapped = true,
            ),
          ),
        ),
      );

      // Verify formula
      expect(find.text('Basis: 75 MT × ₹50.00/MT = ₹3750.00'), findsOneWidget);

      // Verify distinct quantities
      expect(find.text('Contracted: 100.0 MT'), findsOneWidget);
      expect(find.text('Delivered: 80.0 MT'), findsOneWidget);
      expect(find.text('Eligible: 75.0 MT'), findsOneWidget);

      // Verify raw material trade label
      expect(find.textContaining('Raw Material Trade:'), findsOneWidget);

      // Tap card
      await tester.tap(find.byType(CommissionRecordCard));
      expect(tapped, isTrue);

      // Tap log payment
      await tester.tap(find.text('Log Payment'));
      expect(logPaymentTapped, isTrue);
    });

    testWidgets('DealCommissionSheet renders formula breakdown, audit table, and payment timeline', (tester) async {
      final now = DateTime.now();
      final record = CommissionRecord(
        dealId: 'deal-sheet-test',
        dealReference: 'DL-SHEET-01',
        commodityName: 'Export Wheat',
        buyerCompanyName: 'Test Buyer Ltd',
        sellerCompanyName: 'Test Seller Ltd',
        agreedRatePerMT: 50.0,
        quantities: const CommissionQuantityBreakdown(
          contractedQuantity: 100.0,
          deliveredQuantity: 100.0,
          acceptedQuantity: 100.0,
          unitSymbol: 'MT',
        ),
        grossRawMaterialValue: 2650000.0,
        calculatedCommission: 5000.0,
        eligibleCommission: 5000.0,
        invoicedAmount: 5000.0,
        paidAmount: 5000.0,
        outstandingAmount: 0.0,
        disputedAmount: 0.0,
        status: CommissionStatus.paid,
        payments: [
          CommissionPaymentItem(
            id: 'pay-test-1',
            dealId: 'deal-sheet-test',
            amount: 5000.0,
            referenceNumber: 'UTR-TEST-12345',
            direction: 'Buyer to Broker',
            status: 'Confirmed',
            paymentDate: now,
            notes: 'Verified NEFT settlement',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        _buildTestApp(
          Scaffold(
            body: DealCommissionSheet(initialRecord: record),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Formula breakdown
      expect(find.text('APPROVED MANDI COMMISSION FORMULA'), findsOneWidget);
      expect(find.textContaining('Eligible Commission = Eligible Delivered Quantity (MT)'), findsOneWidget);

      // Fulfillment Quantities Audit
      expect(find.text('Fulfillment Quantities Audit'), findsOneWidget);
      expect(find.text('Contracted Volume'), findsOneWidget);
      expect(find.text('Eligible Delivered Volume'), findsOneWidget);

      // Financial Settlement Ledger
      expect(find.text('Financial Settlement Ledger'), findsOneWidget);
      expect(find.textContaining('Raw Material Trade Value'), findsOneWidget);

      // Payment Timeline
      expect(find.text('Commission Payment History'), findsOneWidget);
      expect(find.text('UTR-TEST-12345'), findsOneWidget);
    });

    testWidgets('LogCommissionPaymentDialog auto-fills remaining balance and validates input', (tester) async {
      final now = DateTime.now();
      final record = CommissionRecord(
        dealId: 'deal-pay-test',
        dealReference: 'DL-PAY-01',
        commodityName: 'Mustard Seed',
        buyerCompanyName: 'Buyer Corp',
        sellerCompanyName: 'Seller Corp',
        agreedRatePerMT: 60.0,
        quantities: const CommissionQuantityBreakdown(
          contractedQuantity: 100.0,
          deliveredQuantity: 100.0,
          acceptedQuantity: 100.0,
          unitSymbol: 'MT',
        ),
        grossRawMaterialValue: 5400000.0,
        calculatedCommission: 6000.0,
        eligibleCommission: 6000.0,
        invoicedAmount: 6000.0,
        paidAmount: 2000.0,
        outstandingAmount: 4000.0,
        disputedAmount: 0.0,
        status: CommissionStatus.partiallyPaid,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        _buildTestApp(
          Scaffold(
            body: LogCommissionPaymentDialog(record: record),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Remaining balance preview
      expect(find.text('₹4,000.00'), findsOneWidget);

      // Amount field is pre-filled with remaining balance 4000.00
      final amountFinder = find.widgetWithText(TextFormField, '4000.00');
      expect(amountFinder, findsOneWidget);

      // Attempt to submit without UTR number -> validation error
      final submitBtn = find.widgetWithText(AppButton, 'Save & Reconcile Payment');
      await tester.tap(submitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Reference / UTR number is required'), findsOneWidget);
    });
  });
}
