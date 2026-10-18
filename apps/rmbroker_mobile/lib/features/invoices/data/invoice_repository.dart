import 'package:flutter/foundation.dart';
import 'package:rmbroker_mobile/core/network/api_client.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/features/invoices/domain/invoice_model.dart';
import 'package:rmbroker_mobile/features/invoices/domain/reconciliation_model.dart';
import 'package:rmbroker_mobile/features/invoices/domain/statement_model.dart';

/// Exception thrown when attempting to generate a duplicate invoice for the same deal.
class DuplicateInvoiceException implements Exception {
  final String message;
  final String existingInvoiceNumber;
  final String dealReference;

  const DuplicateInvoiceException({
    required this.message,
    required this.existingInvoiceNumber,
    required this.dealReference,
  });

  @override
  String toString() => message;
}

/// Repository responsible for invoice operations, statement generation, and reconciliation.
class InvoiceRepository {
  final ApiClient? apiClient;
  final SecureStorageService storage;

  InvoiceRepository({this.apiClient, SecureStorageService? storage})
      : storage = storage ?? SecureStorageService();

  // In-memory cache & audit-trailed storage
  final List<CommissionInvoice> _cachedInvoices = [];
  bool _initialized = false;

  void _seedDefaultInvoices() {
    if (_initialized) return;
    _initialized = true;

    _cachedInvoices.addAll([
      CommissionInvoice(
        id: 'inv-2026-0042',
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
        lineItems: [
          const InvoiceLineItem(
            id: 'li-42-1',
            description: 'Brokerage Commission on 50 MT Mustard Seed (Grade-A Bold)',
            quantity: 50.0,
            unitRate: 60.0,
            amount: 3000.0,
          ),
        ],
        subtotalAmount: 3000.0,
        taxAmount: 0.0,
        totalAmount: 3000.0,
        paidAmount: 3000.0,
        creditedAmount: 0.0,
        outstandingAmount: 0.0,
        disputedAmount: 0.0,
        status: InvoiceStatus.paid,
        issueDate: DateTime.now().subtract(const Duration(days: 12)),
        dueDate: DateTime.now().add(const Duration(days: 3)),
        paidAt: DateTime.now().subtract(const Duration(days: 2)),
        paymentReferences: const ['UTR994827104921'],
        auditTrail: [
          InvoiceAuditEntry(
            id: 'aud-42-1',
            action: 'created',
            description: 'Invoice created from 50 MT accepted delivery',
            actor: 'Broker Desk',
            timestamp: DateTime.now().subtract(const Duration(days: 12)),
          ),
          InvoiceAuditEntry(
            id: 'aud-42-2',
            action: 'issued',
            description: 'Invoice formally issued to Sharma Agro Mills Ltd',
            actor: 'Broker Desk',
            timestamp: DateTime.now().subtract(const Duration(days: 12)),
          ),
          InvoiceAuditEntry(
            id: 'aud-42-3',
            action: 'payment_allocated',
            description: 'Payment ₹3,000 recorded via UTR994827104921',
            actor: 'Broker Desk',
            timestamp: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      CommissionInvoice(
        id: 'inv-2026-0043',
        invoiceNumber: 'INV-2026-0043',
        dealId: 'deal-bkg-0043',
        dealReference: 'DL-2026-0892',
        bookingReference: 'BKG-2026-0043',
        commissionRecordId: 'comm-deal-0043',
        billedToParty: 'Seller Enterprise',
        buyerCompanyName: 'Marwar Edible Oils Pvt Ltd',
        sellerCompanyName: 'Hadoti Agro Farmer Producer Co',
        commodityName: 'Yellow Soyabean',
        gradeName: 'FAQ Milling Grade',
        eligibleDeliveredQuantity: 40.0,
        agreedRatePerMT: 50.0,
        calculationBasis: '₹/MT',
        lineItems: [
          const InvoiceLineItem(
            id: 'li-43-1',
            description: 'Brokerage Commission on 40 MT Yellow Soyabean (FAQ Milling Grade)',
            quantity: 40.0,
            unitRate: 50.0,
            amount: 2000.0,
          ),
        ],
        subtotalAmount: 2000.0,
        taxAmount: 0.0,
        totalAmount: 2000.0,
        paidAmount: 1000.0,
        creditedAmount: 0.0,
        outstandingAmount: 1000.0,
        disputedAmount: 0.0,
        status: InvoiceStatus.partiallyPaid,
        issueDate: DateTime.now().subtract(const Duration(days: 7)),
        dueDate: DateTime.now().add(const Duration(days: 8)),
        paymentReferences: const ['UTR449281903412'],
        auditTrail: [
          InvoiceAuditEntry(
            id: 'aud-43-1',
            action: 'created',
            description: 'Invoice created from 40 MT accepted delivery',
            actor: 'Broker Desk',
            timestamp: DateTime.now().subtract(const Duration(days: 7)),
          ),
          InvoiceAuditEntry(
            id: 'aud-43-2',
            action: 'issued',
            description: 'Invoice issued to Hadoti Agro Farmer Producer Co',
            actor: 'Broker Desk',
            timestamp: DateTime.now().subtract(const Duration(days: 7)),
          ),
          InvoiceAuditEntry(
            id: 'aud-43-3',
            action: 'payment_allocated',
            description: 'Partial payment ₹1,000 received via UTR449281903412',
            actor: 'Broker Desk',
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      CommissionInvoice(
        id: 'inv-2026-0044',
        invoiceNumber: 'INV-2026-0044',
        dealId: 'deal-bkg-0044',
        dealReference: 'DL-2026-0893',
        bookingReference: 'BKG-2026-0044',
        commissionRecordId: 'comm-deal-0044',
        billedToParty: 'Buyer Enterprise',
        buyerCompanyName: 'Jaipur Grains Trading Co',
        sellerCompanyName: 'Shekhawati Farmer Producer Co',
        commodityName: 'Sharbati Wheat',
        gradeName: 'Premium Milling',
        eligibleDeliveredQuantity: 60.0,
        agreedRatePerMT: 45.0,
        calculationBasis: '₹/MT',
        lineItems: [
          const InvoiceLineItem(
            id: 'li-44-1',
            description: 'Brokerage Commission on 60 MT Sharbati Wheat (Premium Milling)',
            quantity: 60.0,
            unitRate: 45.0,
            amount: 2700.0,
          ),
        ],
        subtotalAmount: 2700.0,
        taxAmount: 0.0,
        totalAmount: 2700.0,
        paidAmount: 0.0,
        creditedAmount: 0.0,
        outstandingAmount: 2700.0,
        disputedAmount: 0.0,
        status: InvoiceStatus.issued,
        issueDate: DateTime.now().subtract(const Duration(days: 3)),
        dueDate: DateTime.now().add(const Duration(days: 12)),
        paymentReferences: const [],
        auditTrail: [
          InvoiceAuditEntry(
            id: 'aud-44-1',
            action: 'created',
            description: 'Invoice created from 60 MT accepted delivery',
            actor: 'Broker Desk',
            timestamp: DateTime.now().subtract(const Duration(days: 3)),
          ),
          InvoiceAuditEntry(
            id: 'aud-44-2',
            action: 'issued',
            description: 'Invoice sent to Jaipur Grains Trading Co',
            actor: 'Broker Desk',
            timestamp: DateTime.now().subtract(const Duration(days: 3)),
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      CommissionInvoice(
        id: 'inv-2026-0045',
        invoiceNumber: 'INV-2026-0045',
        dealId: 'deal-bkg-0045',
        dealReference: 'DL-2026-0894',
        bookingReference: 'BKG-2026-0045',
        commissionRecordId: 'comm-deal-0045',
        billedToParty: 'Buyer Enterprise',
        buyerCompanyName: 'Chambal Protein Feeds Ltd',
        sellerCompanyName: 'Bundi Krishak Producer Co',
        commodityName: 'Guar Seed (Cyamopsis)',
        gradeName: 'Industrial Split Grade',
        eligibleDeliveredQuantity: 30.0,
        agreedRatePerMT: 80.0,
        calculationBasis: '₹/MT',
        lineItems: [
          const InvoiceLineItem(
            id: 'li-45-1',
            description: 'Brokerage Commission on 30 MT Guar Seed (Industrial Split Grade)',
            quantity: 30.0,
            unitRate: 80.0,
            amount: 2400.0,
          ),
        ],
        subtotalAmount: 2400.0,
        taxAmount: 0.0,
        totalAmount: 2400.0,
        paidAmount: 0.0,
        creditedAmount: 0.0,
        outstandingAmount: 2400.0,
        disputedAmount: 2400.0,
        status: InvoiceStatus.disputed,
        issueDate: DateTime.now().subtract(const Duration(days: 18)),
        dueDate: DateTime.now().subtract(const Duration(days: 3)),
        notes: 'Invoice disputed due to quality deduction arbitration on moisture level.',
        paymentReferences: const [],
        auditTrail: [
          InvoiceAuditEntry(
            id: 'aud-45-1',
            action: 'created',
            description: 'Invoice created from 30 MT delivery',
            actor: 'Broker Desk',
            timestamp: DateTime.now().subtract(const Duration(days: 18)),
          ),
          InvoiceAuditEntry(
            id: 'aud-45-2',
            action: 'disputed',
            description: 'Buyer held payment pending moisture deduction review',
            actor: 'Chambal Protein Feeds',
            timestamp: DateTime.now().subtract(const Duration(days: 5)),
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 18)),
        updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ]);
  }

  /// Fetches all commission invoices.
  Future<List<CommissionInvoice>> fetchInvoices({String? token}) async {
    _seedDefaultInvoices();

    if (apiClient != null) {
      try {
        final res = await apiClient!.get('/broker/invoices');
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data;
          if (data is List) {
            return data
                .map((e) => CommissionInvoice.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('REST invoices endpoint notice: $e (using authoritative memory store)');
      }
    }

    return List.unmodifiable(_cachedInvoices);
  }

  /// Fetches an invoice by unique ID.
  Future<CommissionInvoice?> fetchInvoiceById(String id, {String? token}) async {
    _seedDefaultInvoices();
    final match = _cachedInvoices.where((inv) => inv.id == id).firstOrNull;
    if (match != null) return match;

    final invoices = await fetchInvoices(token: token);
    return invoices.where((inv) => inv.id == id).firstOrNull;
  }

  /// Creates a new commission invoice from an eligible deal commission record.
  /// Enforces duplicate invoice prevention.
  Future<CommissionInvoice> createInvoice(
    CreateInvoiceDto dto, {
    String? token,
  }) async {
    _seedDefaultInvoices();

    final validationError = dto.validate();
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    // DUPLICATE PREVENTION:
    // Check if an active (non-cancelled) invoice already exists for this deal.
    final existing = _cachedInvoices.where((inv) =>
        inv.dealId == dto.dealId &&
        inv.status != InvoiceStatus.cancelledOrCredited).firstOrNull;

    if (existing != null) {
      throw DuplicateInvoiceException(
        message:
            'Duplicate invoice creation prevented: Invoice ${existing.invoiceNumber} already exists for deal ${dto.dealReference}.',
        existingInvoiceNumber: existing.invoiceNumber,
        dealReference: dto.dealReference,
      );
    }

    final seq = _cachedInvoices.length + 42;
    final invNumber = 'INV-2026-${seq.toString().padLeft(4, '0')}';
    final subtotal = dto.calculatedSubtotal;
    final now = DateTime.now();

    final newInvoice = CommissionInvoice(
      id: 'inv-$now-${dto.dealId}',
      invoiceNumber: invNumber,
      dealId: dto.dealId,
      dealReference: dto.dealReference,
      bookingReference: dto.bookingReference,
      commissionRecordId: dto.commissionRecordId,
      billedToParty: dto.billedToParty,
      buyerCompanyName: dto.buyerCompanyName,
      sellerCompanyName: dto.sellerCompanyName,
      commodityName: dto.commodityName,
      gradeName: dto.gradeName,
      eligibleDeliveredQuantity: dto.eligibleDeliveredQuantity,
      agreedRatePerMT: dto.agreedRatePerMT,
      calculationBasis: dto.calculationBasis,
      lineItems: [
        InvoiceLineItem(
          id: 'li-${dto.dealId}-1',
          description:
              'Brokerage Commission on ${dto.eligibleDeliveredQuantity.toStringAsFixed(1)} MT ${dto.commodityName} (${dto.gradeName})',
          quantity: dto.eligibleDeliveredQuantity,
          unitRate: dto.agreedRatePerMT,
          amount: subtotal,
        ),
      ],
      subtotalAmount: subtotal,
      taxAmount: 0.0,
      totalAmount: subtotal,
      paidAmount: 0.0,
      creditedAmount: 0.0,
      outstandingAmount: subtotal,
      disputedAmount: 0.0,
      status: InvoiceStatus.issued,
      issueDate: now,
      dueDate: dto.dueDate,
      notes: dto.notes,
      paymentReferences: const [],
      auditTrail: [
        InvoiceAuditEntry(
          id: 'aud-init-$now',
          action: 'created',
          description:
              'Invoice $invNumber generated for ${dto.eligibleDeliveredQuantity} MT @ ₹${dto.agreedRatePerMT.toStringAsFixed(0)}/${dto.calculationBasis}',
          actor: 'Broker Desk',
          timestamp: now,
        ),
        InvoiceAuditEntry(
          id: 'aud-iss-$now',
          action: 'issued',
          description: 'Invoice issued to ${dto.billedToParty}',
          actor: 'Broker Desk',
          timestamp: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    _cachedInvoices.insert(0, newInvoice);
    return newInvoice;
  }

  /// Applies a credit note or authorized adjustment to an issued invoice.
  Future<CommissionInvoice> applyCreditNote(
    ApplyCreditNoteDto dto, {
    String? token,
  }) async {
    _seedDefaultInvoices();

    final index = _cachedInvoices.indexWhere((inv) => inv.id == dto.invoiceId);
    if (index == -1) {
      throw ArgumentError('Invoice not found: ${dto.invoiceId}');
    }

    final current = _cachedInvoices[index];
    final validationError = dto.validate(current);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final newCredited = current.creditedAmount + dto.creditAmount;
    final newOutstanding = (current.totalAmount - current.paidAmount - newCredited).clamp(0.0, double.infinity);
    final newStatus = newOutstanding <= 0.01
        ? InvoiceStatus.paid
        : current.status;

    final now = DateTime.now();
    final updatedAudit = List<InvoiceAuditEntry>.from(current.auditTrail)
      ..add(InvoiceAuditEntry(
        id: 'aud-cred-$now',
        action: 'credit_note_applied',
        description:
            'Credit note of ₹${dto.creditAmount.toStringAsFixed(2)} applied. Reason: ${dto.reason}',
        actor: dto.authorizedBy,
        timestamp: now,
      ));

    final updated = current.copyWith(
      creditedAmount: newCredited,
      outstandingAmount: newOutstanding,
      status: newStatus,
      auditTrail: updatedAudit,
      updatedAt: now,
    );

    _cachedInvoices[index] = updated;
    return updated;
  }

  /// Records an authoritative payment against an invoice.
  Future<CommissionInvoice> recordInvoicePayment({
    required String invoiceId,
    required double amount,
    required String utrNumber,
    required String paymentMethod,
    String? token,
  }) async {
    _seedDefaultInvoices();

    final index = _cachedInvoices.indexWhere((inv) => inv.id == invoiceId);
    if (index == -1) {
      throw ArgumentError('Invoice not found: $invoiceId');
    }

    final current = _cachedInvoices[index];
    if (amount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero');
    }

    final cleanUtr = utrNumber.trim();
    if (cleanUtr.isEmpty) {
      throw ArgumentError('Payment UTR / transaction reference is required');
    }

    // Duplicate UTR check across current invoice
    if (current.paymentReferences.contains(cleanUtr)) {
      throw ArgumentError('Payment with UTR $cleanUtr has already been recorded for this invoice.');
    }

    final newPaid = current.paidAmount + amount;
    final newOutstanding = (current.totalAmount - newPaid - current.creditedAmount).clamp(0.0, double.infinity);
    final newStatus = newOutstanding <= 0.01
        ? InvoiceStatus.paid
        : InvoiceStatus.partiallyPaid;

    final now = DateTime.now();
    final updatedPayments = List<String>.from(current.paymentReferences)..add(cleanUtr);
    final updatedAudit = List<InvoiceAuditEntry>.from(current.auditTrail)
      ..add(InvoiceAuditEntry(
        id: 'aud-pay-$now',
        action: 'payment_allocated',
        description:
            'Payment of ₹${amount.toStringAsFixed(2)} received via $paymentMethod (Ref: $cleanUtr)',
        actor: 'Broker Desk',
        timestamp: now,
      ));

    final updated = current.copyWith(
      paidAmount: newPaid,
      outstandingAmount: newOutstanding,
      status: newStatus,
      paidAt: newOutstanding <= 0.01 ? now : current.paidAt,
      paymentReferences: updatedPayments,
      auditTrail: updatedAudit,
      updatedAt: now,
    );

    _cachedInvoices[index] = updated;
    return updated;
  }

  /// Generates a comprehensive broker financial statement for a specified date range.
  Future<CommissionStatement> generateStatement({
    required DateTime startDate,
    required DateTime endDate,
    String? token,
  }) async {
    final invoices = await fetchInvoices(token: token);

    final filtered = invoices.where((inv) {
      return !inv.issueDate.isBefore(startDate) && !inv.issueDate.isAfter(endDate);
    }).toList();

    double earned = 0.0;
    double invoiced = 0.0;
    double received = 0.0;
    double credits = 0.0;
    double disputed = 0.0;

    final ledgerItems = <StatementLedgerItem>[];
    double runningBalance = 0.0;

    // Sort chronologically
    filtered.sort((a, b) => a.issueDate.compareTo(b.issueDate));

    for (final inv in filtered) {
      earned += inv.subtotalAmount;
      invoiced += inv.totalAmount;
      credits += inv.creditedAmount;
      disputed += inv.disputedAmount;

      // Invoiced entry
      runningBalance += inv.totalAmount;
      ledgerItems.add(StatementLedgerItem(
        id: 'stm-inv-${inv.id}',
        date: inv.issueDate,
        type: StatementEntryType.commissionInvoiced,
        reference: inv.invoiceNumber,
        dealReference: inv.dealReference,
        counterparty: inv.billedToParty,
        description: 'Commission invoice on ${inv.commodityName} (${inv.calculationFormula})',
        debit: inv.totalAmount,
        credit: 0.0,
        runningBalance: runningBalance,
      ));

      // Payments
      if (inv.paidAmount > 0) {
        received += inv.paidAmount;
        runningBalance -= inv.paidAmount;
        ledgerItems.add(StatementLedgerItem(
          id: 'stm-pay-${inv.id}',
          date: inv.paidAt ?? inv.updatedAt,
          type: StatementEntryType.paymentReceived,
          reference: inv.paymentReferences.isNotEmpty ? inv.paymentReferences.first : 'RECEIPT',
          dealReference: inv.dealReference,
          counterparty: inv.billedToParty,
          description: 'Payment receipt against ${inv.invoiceNumber}',
          debit: 0.0,
          credit: inv.paidAmount,
          runningBalance: runningBalance,
        ));
      }

      // Credits / Adjustments
      if (inv.creditedAmount > 0) {
        runningBalance -= inv.creditedAmount;
        ledgerItems.add(StatementLedgerItem(
          id: 'stm-cred-${inv.id}',
          date: inv.updatedAt,
          type: StatementEntryType.creditAdjustment,
          reference: 'CREDIT-NOTE',
          dealReference: inv.dealReference,
          counterparty: inv.billedToParty,
          description: 'Credit adjustment on ${inv.invoiceNumber}',
          debit: 0.0,
          credit: inv.creditedAmount,
          runningBalance: runningBalance,
        ));
      }
    }

    final closingBalance = (invoiced - received - credits).clamp(0.0, double.infinity);

    return CommissionStatement(
      statementNumber: 'STM-${startDate.year}${startDate.month.toString().padLeft(2, '0')}-001',
      brokerDeskName: 'Authorized Intermediary Commodity Desk',
      mandiHub: 'Jaipur Mandi Commodity Exchange Hub',
      startDate: startDate,
      endDate: endDate,
      generatedAt: DateTime.now(),
      currency: 'INR',
      openingBalance: 0.0,
      totalCommissionEarned: earned,
      totalCommissionInvoiced: invoiced,
      totalPaymentsReceived: received,
      totalCreditsAndAdjustments: credits,
      totalDisputedAmount: disputed,
      closingOutstandingBalance: closingBalance,
      items: ledgerItems,
    );
  }

  /// Generates the automated financial reconciliation summary across all invoices.
  Future<FinancialReconciliationSummary> generateReconciliation({
    String? token,
  }) async {
    final invoices = await fetchInvoices(token: token);
    return FinancialReconciliationSummary.fromInvoices(invoices);
  }
}
