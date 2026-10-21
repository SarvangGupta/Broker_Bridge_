import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/features/invoices/domain/seller_invoice_model.dart';
import 'package:rmseller_mobile/features/invoices/presentation/invoice_details_screen.dart';

void main() {
  group('RB-SELLER-04: InvoiceDetailsScreen Widget Tests', () {
    final testInvoice = SellerInvoice(
      id: 'INV-TEST-0042',
      dealId: 'DEAL-2026-052',
      sellerId: '20000000-0000-0000-0000-000000000101',
      invoiceNo: 'INV-2026-0042',
      amount: 224000.0,
      status: 'Paid',
      fileUrl: 'https://brokerbridge.mandi/invoices/INV-2026-0042.pdf',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      paidAt: DateTime.now().subtract(const Duration(days: 1)),
      commodityName: 'Mustard Seeds (42% Oil Content)',
      gradeName: 'High Oil Content (42% Oil)',
      quantity: 40.0,
      unit: 'MT',
      ratePerUnit: 5600.0,
      brokerDeskName: 'Kota Agro Brokerage',
      bookingReference: 'BKG-2026-0520',
      paymentReference: 'UTR-HDFC-90218820',
    );

    Widget createScreen() {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: InvoiceDetailsScreen(
          invoiceId: testInvoice.id,
          initialInvoice: testInvoice,
        ),
      );
    }

    testWidgets('Renders invoice numbers, status, and broker mediation context', (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pump();

      expect(find.text('INV-2026-0042'), findsAtLeastNWidgets(1));
      expect(find.text('TAX INVOICE'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Kota Agro Brokerage'), findsOneWidget);
      expect(find.text('BKG-2026-0520'), findsOneWidget);
      expect(find.text('UTR-HDFC-90218820'), findsOneWidget);
    });

    testWidgets('Renders line items, volume, rate, and tax calculation', (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pump();

      expect(find.text('Mustard Seeds (42% Oil Content)'), findsOneWidget);
      expect(find.text('40.0 MT'), findsOneWidget);
      expect(find.text('₹5600'), findsOneWidget);
      expect(find.textContaining('224000'), findsAtLeastNWidgets(1));
      expect(find.textContaining('CGST'), findsOneWidget);
      expect(find.textContaining('SGST'), findsOneWidget);
    });

    testWidgets('Renders Counterparty Shield notice and document action buttons', (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pump();

      expect(find.textContaining('Counterparty Shield'), findsOneWidget);
      expect(find.text('View Linked Deal Contract'), findsOneWidget);
    });
  });
}
