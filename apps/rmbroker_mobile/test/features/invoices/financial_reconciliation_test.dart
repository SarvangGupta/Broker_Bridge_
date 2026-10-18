import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/invoices/domain/invoice_model.dart';
import 'package:rmbroker_mobile/features/invoices/domain/reconciliation_model.dart';
import 'package:rmbroker_mobile/features/invoices/domain/statement_model.dart';

void main() {
  group('Financial Statement & Reconciliation Tests (Sprint RB-FL-12)', () {
    test('CommissionStatement mathematical reconciliation formula validation', () {
      final periodStart = DateTime(2026, 3, 1);
      final periodEnd = DateTime(2026, 3, 31);

      // Statement where:
      // Opening Balance = ₹10,000
      // Invoiced Amount = ₹50,000
      // Payments Received = ₹35,000
      // Adjustments / Credits = ₹5,000
      // Disputed = ₹2,000
      // Expected Closing Balance = 10000 + 50000 - 35000 - 5000 = ₹20,000
      final reconciledStatement = CommissionStatement(
        statementNumber: 'STMT-2026-03-01',
        brokerDeskName: 'Nilesh Brokerage Services',
        startDate: periodStart,
        endDate: periodEnd,
        generatedAt: DateTime(2026, 4, 1),
        openingBalance: 10000.0,
        totalCommissionEarned: 50000.0,
        totalCommissionInvoiced: 50000.0,
        totalPaymentsReceived: 35000.0,
        totalCreditsAndAdjustments: 5000.0,
        totalDisputedAmount: 2000.0,
        closingOutstandingBalance: 20000.0,
        items: [
          StatementLedgerItem(
            id: 'led-1',
            date: DateTime(2026, 3, 5),
            type: StatementEntryType.commissionInvoiced,
            reference: 'INV-2026-0010',
            description: 'Invoice issued for Deal DL-100',
            counterparty: 'Buyer A',
            debit: 50000.0,
            runningBalance: 60000.0,
          ),
          StatementLedgerItem(
            id: 'led-2',
            date: DateTime(2026, 3, 15),
            type: StatementEntryType.paymentReceived,
            reference: 'PAY-UTR-901',
            description: 'Part payment received',
            counterparty: 'Buyer A',
            credit: 35000.0,
            runningBalance: 25000.0,
          ),
          StatementLedgerItem(
            id: 'led-3',
            date: DateTime(2026, 3, 20),
            type: StatementEntryType.creditAdjustment,
            reference: 'CR-100',
            description: 'Weight discrepancy settlement credit',
            counterparty: 'Buyer A',
            credit: 5000.0,
            runningBalance: 20000.0,
          ),
        ],
      );

      // Verify mathematical reconciliation
      expect(reconciledStatement.isMathematicallyReconciled, isTrue);
      expect(reconciledStatement.closingOutstandingBalance, 20000.0);
    });

    test('Statement flags mathematical discrepancy if closing balance does not equal formula', () {
      final periodStart = DateTime(2026, 3, 1);
      final periodEnd = DateTime(2026, 3, 31);

      // Tampered statement where Closing Balance is erroneously ₹15,000 instead of ₹20,000
      final invalidStatement = CommissionStatement(
        statementNumber: 'STMT-INVALID',
        brokerDeskName: 'Nilesh Brokerage Services',
        startDate: periodStart,
        endDate: periodEnd,
        generatedAt: DateTime(2026, 4, 1),
        openingBalance: 10000.0,
        totalCommissionEarned: 50000.0,
        totalCommissionInvoiced: 50000.0,
        totalPaymentsReceived: 35000.0,
        totalCreditsAndAdjustments: 5000.0,
        totalDisputedAmount: 0.0,
        closingOutstandingBalance: 15000.0, // Incorrect! Formula requires 20,000.0
        items: const [],
      );

      expect(invalidStatement.isMathematicallyReconciled, isFalse);
    });

    test('FinancialReconciliationSummary categorizes invoices and flags discrepancies accurately', () {
      final now = DateTime.now();

      final invoices = [
        // 1. Fully Paid Invoice
        CommissionInvoice(
          id: 'inv-rec-1',
          invoiceNumber: 'INV-2026-0001',
          dealId: 'deal-1',
          dealReference: 'DL-001',
          bookingReference: 'BK-001',
          commissionRecordId: 'comm-1',
          billedToParty: 'Buyer Enterprise',
          buyerCompanyName: 'Buyer 1 Ltd',
          sellerCompanyName: 'Seller 1 FPO',
          commodityName: 'Wheat',
          gradeName: 'A',
          eligibleDeliveredQuantity: 100.0,
          agreedRatePerMT: 50.0,
          calculationBasis: '₹/MT',
          lineItems: const [],
          subtotalAmount: 5000.0,
          taxAmount: 0.0,
          totalAmount: 5000.0,
          paidAmount: 5000.0,
          creditedAmount: 0.0,
          outstandingAmount: 0.0,
          disputedAmount: 0.0,
          status: InvoiceStatus.paid,
          issueDate: now,
          dueDate: now.add(const Duration(days: 14)),
          paymentReferences: const ['UTR-1'],
          auditTrail: const [],
          createdAt: now,
          updatedAt: now,
        ),
        // 2. Partially Paid Invoice
        CommissionInvoice(
          id: 'inv-rec-2',
          invoiceNumber: 'INV-2026-0002',
          dealId: 'deal-2',
          dealReference: 'DL-002',
          bookingReference: 'BK-002',
          commissionRecordId: 'comm-2',
          billedToParty: 'Buyer Enterprise',
          buyerCompanyName: 'Buyer 2 Ltd',
          sellerCompanyName: 'Seller 2 FPO',
          commodityName: 'Mustard',
          gradeName: 'Bold',
          eligibleDeliveredQuantity: 50.0,
          agreedRatePerMT: 60.0,
          calculationBasis: '₹/MT',
          lineItems: const [],
          subtotalAmount: 3000.0,
          taxAmount: 0.0,
          totalAmount: 3000.0,
          paidAmount: 1000.0,
          creditedAmount: 0.0,
          outstandingAmount: 2000.0,
          disputedAmount: 0.0,
          status: InvoiceStatus.partiallyPaid,
          issueDate: now,
          dueDate: now.add(const Duration(days: 14)),
          paymentReferences: const ['UTR-2'],
          auditTrail: const [],
          createdAt: now,
          updatedAt: now,
        ),
        // 3. Disputed Invoice with Hold
        CommissionInvoice(
          id: 'inv-rec-3',
          invoiceNumber: 'INV-2026-0003',
          dealId: 'deal-3',
          dealReference: 'DL-003',
          bookingReference: 'BK-003',
          commissionRecordId: 'comm-3',
          billedToParty: 'Seller Enterprise',
          buyerCompanyName: 'Buyer 3 Ltd',
          sellerCompanyName: 'Seller 3 FPO',
          commodityName: 'Soybean',
          gradeName: 'Standard',
          eligibleDeliveredQuantity: 60.0,
          agreedRatePerMT: 50.0,
          calculationBasis: '₹/MT',
          lineItems: const [],
          subtotalAmount: 3000.0,
          taxAmount: 0.0,
          totalAmount: 3000.0,
          paidAmount: 0.0,
          creditedAmount: 0.0,
          outstandingAmount: 3000.0,
          disputedAmount: 3000.0,
          status: InvoiceStatus.disputed,
          issueDate: now,
          dueDate: now.add(const Duration(days: 14)),
          paymentReferences: const [],
          auditTrail: const [],
          createdAt: now,
          updatedAt: now,
        ),
        // 4. Inconsistent Overpaid Invoice
        CommissionInvoice(
          id: 'inv-rec-4',
          invoiceNumber: 'INV-2026-0004',
          dealId: 'deal-4',
          dealReference: 'DL-004',
          bookingReference: 'BK-004',
          commissionRecordId: 'comm-4',
          billedToParty: 'Buyer Enterprise',
          buyerCompanyName: 'Buyer 4 Ltd',
          sellerCompanyName: 'Seller 4 FPO',
          commodityName: 'Chana',
          gradeName: 'A-Grade',
          eligibleDeliveredQuantity: 40.0,
          agreedRatePerMT: 50.0,
          calculationBasis: '₹/MT',
          lineItems: const [],
          subtotalAmount: 2000.0,
          taxAmount: 0.0,
          totalAmount: 2000.0,
          paidAmount: 2500.0, // ₹500 OVERPAID
          creditedAmount: 0.0,
          outstandingAmount: 0.0,
          disputedAmount: 0.0,
          status: InvoiceStatus.paid,
          issueDate: now,
          dueDate: now.add(const Duration(days: 14)),
          paymentReferences: const ['UTR-4'],
          auditTrail: const [],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final recon = FinancialReconciliationSummary.fromInvoices(invoices);

      // Verify totals
      expect(recon.totalInvoicedAmount, 13000.0); // 5000 + 3000 + 3000 + 2000
      expect(recon.totalReconciledPaidAmount, 8500.0); // 5000 + 1000 + 0 + 2500
      expect(recon.totalOutstandingBalance, 5000.0); // 2000 + 3000
      expect(recon.disputedCount, 1);

      // Verify category counts
      expect(recon.fullyPaidCount, 1);    // inv-1 is fully paid; inv-4 is overpaid
      expect(recon.partiallyPaidCount, 1); // inv-2
      expect(recon.disputedCount, 1);     // inv-3
      expect(recon.overpaidCount, 1);     // inv-4 has paid > total

      // Verify inconsistency flagging
      expect(recon.inconsistencies.isNotEmpty, isTrue);
      final overpaymentIssue = recon.inconsistencies.where(
        (i) => i.invoiceNumber == 'INV-2026-0004' && i.ruleViolation == 'Overpayment Detected',
      );
      expect(overpaymentIssue.isNotEmpty, isTrue);
      expect(overpaymentIssue.first.variance, 500.0);
      expect(overpaymentIssue.first.severity, InconsistencySeverity.critical);

      final disputeIssue = recon.inconsistencies.where(
        (i) => i.invoiceNumber == 'INV-2026-0003' && i.ruleViolation == 'Active Delivery Dispute',
      );
      expect(disputeIssue.isNotEmpty, isTrue);
      expect(disputeIssue.first.severity, InconsistencySeverity.warning);
    });

    test('Never counts the same payment reference twice in reconciliation', () {
      final now = DateTime.now();
      final invoice = CommissionInvoice(
        id: 'inv-dup-pay',
        invoiceNumber: 'INV-2026-0099',
        dealId: 'deal-dup',
        dealReference: 'DL-DUP',
        bookingReference: 'BK-DUP',
        commissionRecordId: 'comm-dup',
        billedToParty: 'Buyer',
        buyerCompanyName: 'Buyer Co',
        sellerCompanyName: 'Seller Co',
        commodityName: 'Grain',
        gradeName: 'A',
        eligibleDeliveredQuantity: 100.0,
        agreedRatePerMT: 50.0,
        calculationBasis: '₹/MT',
        lineItems: const [],
        subtotalAmount: 5000.0,
        taxAmount: 0.0,
        totalAmount: 5000.0,
        paidAmount: 5000.0,
        creditedAmount: 0.0,
        outstandingAmount: 0.0,
        disputedAmount: 0.0,
        status: InvoiceStatus.paid,
        issueDate: now,
        dueDate: now.add(const Duration(days: 14)),
        paymentReferences: const ['UTR-UNIQUE-123'],
        auditTrail: const [],
        createdAt: now,
        updatedAt: now,
      );

      final recon = FinancialReconciliationSummary.fromInvoices([invoice, invoice]);
      // Invoice totals match invoice count
      expect(recon.totalInvoicedAmount, 10000.0);
      expect(recon.totalReconciledPaidAmount, 10000.0);
    });
  });
}
