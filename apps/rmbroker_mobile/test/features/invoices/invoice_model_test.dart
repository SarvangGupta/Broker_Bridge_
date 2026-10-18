import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/invoices/domain/invoice_model.dart';

void main() {
  group('CommissionInvoice Model & Mathematics Tests (Sprint RB-FL-12)', () {
    test('Calculates outstanding balance correctly based on total, paid, and credited amounts', () {
      final invoice = CommissionInvoice(
        id: 'inv-test-1',
        invoiceNumber: 'INV-2026-0001',
        dealId: 'deal-101',
        dealReference: 'DL-WHT-101',
        bookingReference: 'BK-2026-001',
        commissionRecordId: 'comm-101',
        billedToParty: 'Buyer Enterprise',
        buyerCompanyName: 'Rajasthan Agro Mills Ltd',
        sellerCompanyName: 'Hadoti Krishi Mandi FPO',
        commodityName: 'Sharbati Wheat',
        gradeName: 'A-Grade',
        eligibleDeliveredQuantity: 100.0,
        agreedRatePerMT: 50.0,
        calculationBasis: '₹/MT',
        lineItems: const [
          InvoiceLineItem(
            id: 'li-1',
            description: 'Brokerage commission for 100 MT Wheat',
            quantity: 100.0,
            unitRate: 50.0,
            amount: 5000.0,
          ),
        ],
        subtotalAmount: 5000.0,
        taxAmount: 0.0,
        totalAmount: 5000.0,
        paidAmount: 2000.0,
        creditedAmount: 500.0,
        outstandingAmount: 2500.0,
        disputedAmount: 0.0,
        status: InvoiceStatus.partiallyPaid,
        issueDate: DateTime(2026, 3, 1),
        dueDate: DateTime(2026, 3, 15),
        paymentReferences: const ['UTR1001'],
        auditTrail: const [],
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 5),
      );

      // Total (₹5000) - Paid (₹2000) - Credited (₹500) = ₹2500 Outstanding
      expect(invoice.totalAmount, 5000.0);
      expect(invoice.paidAmount, 2000.0);
      expect(invoice.creditedAmount, 500.0);
      expect(invoice.outstandingAmount, 2500.0);
      expect(invoice.isFullyPaid, isFalse);
    });

    test('isFullyPaid returns true when outstanding is zero or within 0.01 tolerance', () {
      final paidInvoice = CommissionInvoice(
        id: 'inv-test-2',
        invoiceNumber: 'INV-2026-0002',
        dealId: 'deal-102',
        dealReference: 'DL-MUST-102',
        bookingReference: 'BK-2026-002',
        commissionRecordId: 'comm-102',
        billedToParty: 'Seller Supplier',
        buyerCompanyName: 'Jaipur Edible Oils',
        sellerCompanyName: 'Alwar Mustard Growers FPO',
        commodityName: 'Mustard Seed',
        gradeName: 'Standard Bold',
        eligibleDeliveredQuantity: 50.0,
        agreedRatePerMT: 60.0,
        calculationBasis: '₹/MT',
        lineItems: const [],
        subtotalAmount: 3000.0,
        taxAmount: 0.0,
        totalAmount: 3000.0,
        paidAmount: 3000.0,
        creditedAmount: 0.0,
        outstandingAmount: 0.0,
        disputedAmount: 0.0,
        status: InvoiceStatus.paid,
        issueDate: DateTime(2026, 3, 1),
        dueDate: DateTime(2026, 3, 15),
        paymentReferences: const ['UTR2001'],
        auditTrail: const [],
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 10),
      );

      expect(paidInvoice.isFullyPaid, isTrue);
    });

    test('Strict Fiduciary Separation: raw material transaction value is never invoice total', () {
      // Trade of 100 MT Wheat @ ₹25,000/MT has gross trade turnover = ₹25,00,000
      // Broker commission rate is ₹50/MT -> Commission = ₹5,000.
      const double tradeTurnover = 2500000.0;
      const double deliveredQty = 100.0;
      const double brokerRate = 50.0;
      final double calculatedCommission = deliveredQty * brokerRate;

      final invoice = CommissionInvoice(
        id: 'inv-trade-val',
        invoiceNumber: 'INV-2026-9999',
        dealId: 'deal-trade-1',
        dealReference: 'DL-TURNOVER-1',
        bookingReference: 'BK-2026-99',
        commissionRecordId: 'comm-trade-1',
        billedToParty: 'Buyer Enterprise',
        buyerCompanyName: 'Agro Corp',
        sellerCompanyName: 'Kisan FPO',
        commodityName: 'Sharbati Wheat',
        gradeName: 'Grade-A',
        eligibleDeliveredQuantity: deliveredQty,
        agreedRatePerMT: brokerRate,
        calculationBasis: '₹/MT',
        lineItems: const [],
        subtotalAmount: calculatedCommission,
        taxAmount: 0.0,
        totalAmount: calculatedCommission,
        paidAmount: 0.0,
        creditedAmount: 0.0,
        outstandingAmount: calculatedCommission,
        disputedAmount: 0.0,
        status: InvoiceStatus.issued,
        issueDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 14)),
        paymentReferences: const [],
        auditTrail: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Verify invoice total is strictly the broker commission (₹5,000), NOT gross commodity turnover (₹25,00,000)
      expect(invoice.totalAmount, 5000.0);
      expect(invoice.totalAmount, isNot(tradeTurnover));
      expect(tradeTurnover - invoice.totalAmount, 2495000.0);
    });

    test('Invoice status display text and code serialization roundtrip', () {
      expect(InvoiceStatus.draft.code, 'draft');
      expect(InvoiceStatus.issued.code, 'issued');
      expect(InvoiceStatus.partiallyPaid.code, 'partially_paid');
      expect(InvoiceStatus.paid.code, 'paid');
      expect(InvoiceStatus.overdue.code, 'overdue');
      expect(InvoiceStatus.disputed.code, 'disputed');
      expect(InvoiceStatus.cancelledOrCredited.code, 'cancelled');

      expect(InvoiceStatus.fromString('partially_paid'), InvoiceStatus.partiallyPaid);
      expect(InvoiceStatus.fromString('cancelled_or_credited'), InvoiceStatus.cancelledOrCredited);
      expect(InvoiceStatus.fromString('unknown_status'), InvoiceStatus.draft);
    });
  });

  group('CreateInvoiceDto Validation Tests', () {
    test('Valid DTO passes validation', () {
      final dto = CreateInvoiceDto(
        dealId: 'deal-valid-1',
        dealReference: 'DL-2026-VAL',
        bookingReference: 'BK-2026-VAL',
        commissionRecordId: 'comm-valid-1',
        billedToParty: 'Buyer Enterprise',
        buyerCompanyName: 'Rajasthan Agro',
        sellerCompanyName: 'Hadoti FPO',
        commodityName: 'Wheat',
        gradeName: 'Grade-A',
        eligibleDeliveredQuantity: 80.0,
        agreedRatePerMT: 45.0,
        calculationBasis: '₹/MT',
        dueDate: DateTime.now().add(const Duration(days: 14)),
      );

      expect(dto.validate(), isNull);
      expect(dto.calculatedSubtotal, 3600.0); // 80 * 45
    });

    test('Rejects missing dealId or dealReference', () {
      final dto = CreateInvoiceDto(
        dealId: '',
        dealReference: 'DL-1',
        bookingReference: 'BK-1',
        commissionRecordId: 'comm-1',
        billedToParty: 'Buyer',
        buyerCompanyName: 'Buyer Co',
        sellerCompanyName: 'Seller Co',
        commodityName: 'Paddy',
        gradeName: 'Basmati',
        eligibleDeliveredQuantity: 50.0,
        agreedRatePerMT: 40.0,
        calculationBasis: '₹/MT',
        dueDate: DateTime.now(),
      );

      expect(dto.validate(), contains('Deal identifier'));
    });

    test('Rejects zero or negative eligible delivered quantity', () {
      final dtoZero = CreateInvoiceDto(
        dealId: 'deal-0',
        dealReference: 'DL-0',
        bookingReference: 'BK-0',
        commissionRecordId: 'comm-0',
        billedToParty: 'Buyer',
        buyerCompanyName: 'Buyer Co',
        sellerCompanyName: 'Seller Co',
        commodityName: 'Paddy',
        gradeName: 'Basmati',
        eligibleDeliveredQuantity: 0.0,
        agreedRatePerMT: 40.0,
        calculationBasis: '₹/MT',
        dueDate: DateTime.now(),
      );
      expect(dtoZero.validate(), contains('delivered quantity must be greater than zero'));

      final dtoNegative = dtoZero.copyWith(eligibleDeliveredQuantity: -5.0);
      expect(dtoNegative.validate(), contains('delivered quantity must be greater than zero'));
    });

    test('Rejects zero or negative commission rate', () {
      final dtoRate = CreateInvoiceDto(
        dealId: 'deal-rate',
        dealReference: 'DL-RATE',
        bookingReference: 'BK-RATE',
        commissionRecordId: 'comm-rate',
        billedToParty: 'Buyer',
        buyerCompanyName: 'Buyer Co',
        sellerCompanyName: 'Seller Co',
        commodityName: 'Paddy',
        gradeName: 'Basmati',
        eligibleDeliveredQuantity: 50.0,
        agreedRatePerMT: 0.0,
        calculationBasis: '₹/MT',
        dueDate: DateTime.now(),
      );
      expect(dtoRate.validate(), contains('Agreed commission rate must be greater than zero'));
    });
  });

  group('ApplyCreditNoteDto Validation & Auditing Tests', () {
    final baseInvoice = CommissionInvoice(
      id: 'inv-credit-test',
      invoiceNumber: 'INV-2026-0088',
      dealId: 'deal-credit-1',
      dealReference: 'DL-CREDIT-1',
      bookingReference: 'BK-CREDIT-1',
      commissionRecordId: 'comm-credit-1',
      billedToParty: 'Buyer Enterprise',
      buyerCompanyName: 'Shree Krishna Agro',
      sellerCompanyName: 'Mandi Traders FPO',
      commodityName: 'Mustard',
      gradeName: 'Bold',
      eligibleDeliveredQuantity: 100.0,
      agreedRatePerMT: 50.0,
      calculationBasis: '₹/MT',
      lineItems: const [],
      subtotalAmount: 5000.0,
      taxAmount: 0.0,
      totalAmount: 5000.0,
      paidAmount: 2000.0,
      creditedAmount: 0.0,
      outstandingAmount: 3000.0,
      disputedAmount: 0.0,
      status: InvoiceStatus.partiallyPaid,
      issueDate: DateTime(2026, 3, 1),
      dueDate: DateTime(2026, 3, 15),
      paymentReferences: const ['UTR-3001'],
      auditTrail: const [],
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 5),
    );

    test('Valid credit note within outstanding balance passes validation', () {
      final dto = ApplyCreditNoteDto(
        invoiceId: baseInvoice.id,
        creditAmount: 1000.0,
        reason: 'Authorized Mandi moisture weight settlement reduction',
        authorizedBy: 'Operations Desk',
      );

      expect(dto.validate(baseInvoice), isNull);
    });

    test('Rejects credit note exceeding current outstanding balance', () {
      final excessiveDto = ApplyCreditNoteDto(
        invoiceId: baseInvoice.id,
        creditAmount: 3500.0, // Outstanding is only 3000.0
        reason: 'Excess credit attempt',
        authorizedBy: 'Desk',
      );

      expect(
        excessiveDto.validate(baseInvoice),
        contains('exceeds invoice outstanding balance'),
      );
    });

    test('Rejects empty reason or zero credit amount', () {
      final zeroDto = ApplyCreditNoteDto(
        invoiceId: baseInvoice.id,
        creditAmount: 0.0,
        reason: 'Some reason',
        authorizedBy: 'Desk',
      );
      expect(zeroDto.validate(baseInvoice), contains('must be greater than zero'));

      final noReasonDto = ApplyCreditNoteDto(
        invoiceId: baseInvoice.id,
        creditAmount: 500.0,
        reason: '   ',
        authorizedBy: 'Desk',
      );
      expect(noReasonDto.validate(baseInvoice), contains('detailed business reason is required'));
    });
  });
}
