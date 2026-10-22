import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/invoices/data/seller_invoices_repository.dart';

void main() {
  group('RB-SELLER-04: SellerInvoicesRepository Unit Tests', () {
    late SecureStorageService storage;
    late SellerInvoicesRepository repository;

    const testSellerId = '20000000-0000-0000-0000-000000000001';
    const testCompanyId = '20000000-0000-0000-0000-000000000101';

    setUp(() async {
      storage = SecureStorageService();
      storage.enableMemoryFallbackForTesting();
      await storage.saveUserInfo(
        id: testSellerId,
        role: 'seller',
        email: 'seller@agroenterprises.in',
        fullName: 'Bikaner Agro Commercials',
        companyId: testCompanyId,
      );
      repository = SellerInvoicesRepository(storage: storage);
    });

    test('getInvoices returns authenticated seller invoices with commercial amounts', () async {
      final invoices = await repository.getInvoices();
      expect(invoices, isNotEmpty);
      expect(invoices.every((i) => i.amount > 0), isTrue);
      expect(invoices.every((i) => i.invoiceNo.startsWith('INV-')), isTrue);
      expect(invoices.any((i) => i.commodityName.contains('Mustard')), isTrue);
    });

    test('getInvoices filters by status correctly (Paid vs Pending)', () async {
      final paidInvoices = await repository.getInvoices(statusFilter: 'Paid');
      expect(paidInvoices, isNotEmpty);
      expect(paidInvoices.every((i) => i.isPaid), isTrue);

      final pendingInvoices = await repository.getInvoices(
        statusFilter: 'Pending',
      );
      expect(pendingInvoices, isNotEmpty);
      expect(pendingInvoices.every((i) => !i.isPaid), isTrue);
    });

    test(
      'getInvoiceById returns exact invoice record with line item details',
      () async {
        final invoice = await repository.getInvoiceById('INV-2026-0042');
        expect(invoice, isNotNull);
        expect(invoice!.invoiceNo, 'INV-2026-0042');
        expect(invoice.dealId, 'DEAL-2026-052');
        expect(invoice.amount, 224000.0);
        expect(invoice.isPaid, isTrue);
        expect(invoice.paymentReference, isNotNull);
        expect(invoice.quantity, 40.0);
        expect(invoice.ratePerUnit, 5600.0);
        expect(invoice.taxableAmount, 224000.0);
        expect(invoice.gstAmount, greaterThan(0));
      },
    );

    test('getDocumentsForDeal returns Tax Invoices, Lorry Receipts, and E-Way bills', () async {
      final documents = await repository.getDocumentsForDeal('DEAL-2026-052');
      expect(documents, isNotEmpty);
      expect(documents.any((d) => d.documentType.contains('Invoice')), isTrue);
      expect(
        documents.any(
          (d) =>
              d.documentType.contains('Lorry') ||
              d.documentType.contains('Bilty'),
        ),
        isTrue,
      );
      expect(documents.any((d) => d.documentType.contains('E-Way')), isTrue);
      expect(documents.every((d) => d.fileUrl.isNotEmpty), isTrue);
    });
  });
}
