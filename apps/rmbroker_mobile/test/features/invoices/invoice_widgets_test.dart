import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/invoices/data/invoice_repository.dart';
import 'package:rmbroker_mobile/features/invoices/domain/invoice_model.dart';
import 'package:rmbroker_mobile/features/invoices/domain/reconciliation_model.dart';
import 'package:rmbroker_mobile/features/invoices/presentation/controllers/invoice_controller.dart';
import 'package:rmbroker_mobile/features/invoices/presentation/screens/invoice_detail_screen.dart';
import 'package:rmbroker_mobile/features/invoices/presentation/screens/invoice_list_screen.dart';
import 'package:rmbroker_mobile/features/invoices/presentation/widgets/invoice_card.dart';
import 'package:rmbroker_mobile/features/invoices/presentation/widgets/invoice_document_preview.dart';
import 'package:rmbroker_mobile/features/invoices/presentation/widgets/reconciliation_exception_card.dart';
import 'package:rmbroker_mobile/features/invoices/presentation/widgets/statement_document_preview.dart';

final testInvoice = CommissionInvoice(
  id: 'inv-widget-101',
  invoiceNumber: 'INV-2026-0042',
  dealId: 'deal-bkg-0042',
  dealReference: 'DL-2026-0891',
  bookingReference: 'BKG-2026-0042',
  commissionRecordId: 'comm-deal-0042',
  billedToParty: 'Buyer Enterprise',
  buyerCompanyName: 'Sharma Agro Mills Ltd',
  sellerCompanyName: 'Kisan Krishi Producer Co',
  commodityName: 'Mustard Seed (Sarson)',
  gradeName: 'Grade-A Bold',
  eligibleDeliveredQuantity: 50.0,
  agreedRatePerMT: 60.0,
  calculationBasis: '₹/MT',
  lineItems: const [
    InvoiceLineItem(
      id: 'li-1',
      description: 'Brokerage Commission on 50.0 MT Mustard Seed',
      quantity: 50.0,
      unitRate: 60.0,
      amount: 3000.0,
    ),
  ],
  subtotalAmount: 3000.0,
  taxAmount: 0.0,
  totalAmount: 3000.0,
  paidAmount: 1500.0,
  creditedAmount: 0.0,
  outstandingAmount: 1500.0,
  disputedAmount: 0.0,
  status: InvoiceStatus.partiallyPaid,
  issueDate: DateTime(2026, 3, 1),
  dueDate: DateTime(2026, 3, 15),
  paymentReferences: const ['UTR99281729104'],
  auditTrail: [
    InvoiceAuditEntry(
      id: 'aud-1',
      action: 'created',
      description: 'Invoice INV-2026-0042 generated for 50 MT',
      actor: 'Broker Desk',
      timestamp: DateTime(2026, 3, 1),
    ),
  ],
  createdAt: DateTime(2026, 3, 1),
  updatedAt: DateTime(2026, 3, 5),
);

Widget _buildTestApp(Widget child, {InvoiceRepository? repository}) {
  return ProviderScope(
    overrides: [
      if (repository != null)
        invoiceRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('InvoiceCard Widget Tests', () {
    testWidgets('Renders invoice number, commodity, rate, and outstanding balance', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          InvoiceCard(
            invoice: testInvoice,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('INV-2026-0042'), findsOneWidget);
      expect(find.textContaining('Mustard Seed'), findsOneWidget);
      expect(find.textContaining('₹60'), findsWidgets);
      expect(find.textContaining('Partially Paid'), findsOneWidget);
      expect(find.textContaining('₹1,500'), findsWidgets);
    });
  });

  group('InvoiceDocumentPreview Widget Tests', () {
    testWidgets('Renders printable Mandi invoice header, line items, and audit notice', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          InvoiceDocumentPreview(invoice: testInvoice),
        ),
      );

      expect(find.text('Invoice Document Preview'), findsOneWidget);
      expect(find.text('RMBROKER COMMODITY DESK'), findsOneWidget);
      expect(find.text('INV-2026-0042'), findsOneWidget);
      expect(find.textContaining('Sharma Agro Mills Ltd'), findsWidgets);
      expect(find.text('STATUTORY FIDUCIARY NOTICE'), findsOneWidget);
    });
  });

  group('StatementDocumentPreview Widget Tests', () {
    testWidgets('Renders statement period, opening balance, invoiced, received, and closing balance', (tester) async {
      final repo = InvoiceRepository();
      final statement = await repo.generateStatement(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
      );

      await tester.pumpWidget(
        _buildTestApp(
          StatementDocumentPreview(statement: statement),
        ),
      );

      expect(find.text('Broker Statement Preview'), findsOneWidget);
      expect(find.textContaining('Opening Balance'), findsOneWidget);
      expect(find.textContaining('CLOSING OUTSTANDING BALANCE'), findsOneWidget);
      expect(find.text('STATEMENT TRANSACTION LEDGER'), findsOneWidget);
    });
  });

  group('ReconciliationExceptionCard Widget Tests', () {
    testWidgets('Renders discrepancy type, invoice reference, and variance amount', (tester) async {
      final inconsistency = ReconciliationInconsistency(
        id: 'inc-test-1',
        invoiceNumber: 'INV-2026-0044',
        dealReference: 'DL-2026-0044',
        counterparty: 'Sharma Agro',
        ruleViolation: 'Overpayment Detected',
        severity: InconsistencySeverity.critical,
        description: 'Payment of ₹1,000 exceeds remaining balance by ₹500',
        invoiceAmount: 1000.0,
        recordedPayments: 1500.0,
        variance: 500.0,
        suggestedResolution: 'Refund or credit note',
        detectedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _buildTestApp(
          ReconciliationExceptionCard(inconsistency: inconsistency),
        ),
      );

      expect(find.text('Overpayment Detected'), findsOneWidget);
      expect(find.text('INV-2026-0044'), findsOneWidget);
      expect(find.textContaining('exceeds remaining balance'), findsOneWidget);
      expect(find.textContaining('₹500.00'), findsOneWidget);
    });
  });

  group('InvoiceDetailScreen Widget Tests', () {
    testWidgets('Renders invoice details, line items, payment actions, and audit trail', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildTestApp(
          const InvoiceDetailScreen(invoiceId: 'inv-2026-0043'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('INV-2026-0043'), findsWidgets);
      expect(find.text('Marwar Edible Oils Pvt Ltd'), findsWidgets);
      expect(find.text('Log Payment'), findsOneWidget);
      expect(find.text('Credit Note'), findsOneWidget);
      expect(find.text('Invoice Audit Trail'), findsOneWidget);
    });

    testWidgets('Tapping Record Payment opens payment recording dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildTestApp(
          const InvoiceDetailScreen(invoiceId: 'inv-2026-0043'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Log Payment'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Record Invoice Payment'), findsOneWidget);
      expect(find.text('Bank UTR / Transaction Ref*'), findsOneWidget);
      expect(find.text('Payment Mode'), findsOneWidget);
    });
  });

  group('InvoiceListScreen 3-Tab Financial Center Tests', () {
    testWidgets('Renders Invoices, Statements, and Reconciliation tabs', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildTestApp(
          const InvoiceListScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Invoices & Reconciliation'), findsOneWidget);
      expect(find.text('Invoices'), findsWidgets);
      expect(find.text('Statements'), findsWidgets);
      expect(find.text('Reconciliation'), findsWidgets);

      // Verify status filter chips on Invoices tab
      expect(find.textContaining('All'), findsWidgets);
      expect(find.text('Issued'), findsWidgets);
      expect(find.text('Partially Paid'), findsWidgets);
      expect(find.text('Paid'), findsWidgets);

      // Switch to Statements tab
      await tester.tap(find.text('Statements'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Brokerage Commission Statement'), findsOneWidget);
      expect(find.text('Preview / Export Financial Statement'), findsOneWidget);

      // Switch to Reconciliation tab
      await tester.tap(find.text('Reconciliation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Financial Reconciliation Status'), findsOneWidget);
      expect(find.text('Reconciliation Exceptions & Alerts'), findsOneWidget);
    });
  });
}
