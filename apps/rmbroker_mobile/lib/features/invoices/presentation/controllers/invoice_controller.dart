import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/invoice_repository.dart';
import '../../domain/invoice_model.dart';
import '../../domain/reconciliation_model.dart';
import '../../domain/statement_model.dart';

/// State of the invoice, statement, and reconciliation management feature.
class InvoiceState {
  final List<CommissionInvoice> allInvoices;
  final List<CommissionInvoice> filteredInvoices;
  final InvoiceStatus? selectedStatus;
  final String searchQuery;
  final FinancialReconciliationSummary? reconciliationSummary;
  final CommissionStatement? activeStatement;
  final DateTime statementStartDate;
  final DateTime statementEndDate;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const InvoiceState({
    this.allInvoices = const [],
    this.filteredInvoices = const [],
    this.selectedStatus,
    this.searchQuery = '',
    this.reconciliationSummary,
    this.activeStatement,
    required this.statementStartDate,
    required this.statementEndDate,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  factory InvoiceState.initial(DateTime start, DateTime end) {
    return InvoiceState(
      statementStartDate: start,
      statementEndDate: end,
      isLoading: true,
    );
  }

  InvoiceState copyWith({
    List<CommissionInvoice>? allInvoices,
    List<CommissionInvoice>? filteredInvoices,
    InvoiceStatus? selectedStatus,
    bool clearStatus = false,
    String? searchQuery,
    FinancialReconciliationSummary? reconciliationSummary,
    CommissionStatement? activeStatement,
    DateTime? statementStartDate,
    DateTime? statementEndDate,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return InvoiceState(
      allInvoices: allInvoices ?? this.allInvoices,
      filteredInvoices: filteredInvoices ?? this.filteredInvoices,
      selectedStatus: clearStatus ? null : (selectedStatus ?? this.selectedStatus),
      searchQuery: searchQuery ?? this.searchQuery,
      reconciliationSummary: reconciliationSummary ?? this.reconciliationSummary,
      activeStatement: activeStatement ?? this.activeStatement,
      statementStartDate: statementStartDate ?? this.statementStartDate,
      statementEndDate: statementEndDate ?? this.statementEndDate,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

/// Provider for the InvoiceRepository.
final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository();
});

/// Riverpod Notifier managing commission invoices, statements, and reconciliation.
class InvoiceController extends Notifier<InvoiceState> {
  InvoiceRepository get _repository => ref.read(invoiceRepositoryProvider);

  @override
  InvoiceState build() {
    final start = DateTime.now().subtract(const Duration(days: 30));
    final end = DateTime.now().add(const Duration(days: 1));
    Future.microtask(() => loadInvoices());
    return InvoiceState.initial(start, end);
  }

  /// Loads all invoices and computes reconciliation.
  Future<void> loadInvoices() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final invoices = await _repository.fetchInvoices();
      final recon = await _repository.generateReconciliation();
      final statement = await _repository.generateStatement(
        startDate: state.statementStartDate,
        endDate: state.statementEndDate,
      );

      state = state.copyWith(
        allInvoices: invoices,
        filteredInvoices: _applyFilter(invoices, state.selectedStatus, state.searchQuery),
        reconciliationSummary: recon,
        activeStatement: statement,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load invoices: $e',
      );
    }
  }

  /// Filters by invoice status.
  void filterByStatus(InvoiceStatus? status) {
    state = state.copyWith(
      selectedStatus: status,
      clearStatus: status == null,
      filteredInvoices: _applyFilter(state.allInvoices, status, state.searchQuery),
    );
  }

  /// Searches invoices by query across invoice number, deal ref, commodity, and counterparties.
  void search(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredInvoices: _applyFilter(state.allInvoices, state.selectedStatus, query),
    );
  }

  /// Creates a new commission invoice from an approved, invoice-eligible record.
  Future<CommissionInvoice?> createInvoice(CreateInvoiceDto dto) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final newInvoice = await _repository.createInvoice(dto);
      final updatedList = List<CommissionInvoice>.from(state.allInvoices)..insert(0, newInvoice);
      final recon = FinancialReconciliationSummary.fromInvoices(updatedList);
      final statement = await _repository.generateStatement(
        startDate: state.statementStartDate,
        endDate: state.statementEndDate,
      );

      state = state.copyWith(
        allInvoices: updatedList,
        filteredInvoices: _applyFilter(updatedList, state.selectedStatus, state.searchQuery),
        reconciliationSummary: recon,
        activeStatement: statement,
        isLoading: false,
        successMessage: 'Invoice ${newInvoice.invoiceNumber} issued successfully for ${dto.dealReference}!',
      );
      return newInvoice;
    } on DuplicateInvoiceException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create invoice: $e',
      );
      return null;
    }
  }

  /// Records payment against an invoice.
  Future<bool> recordPayment({
    required String invoiceId,
    required double amount,
    required String utrNumber,
    required String paymentMethod,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final updatedInvoice = await _repository.recordInvoicePayment(
        invoiceId: invoiceId,
        amount: amount,
        utrNumber: utrNumber,
        paymentMethod: paymentMethod,
      );

      final updatedList = state.allInvoices.map((inv) {
        return inv.id == invoiceId ? updatedInvoice : inv;
      }).toList();

      final recon = FinancialReconciliationSummary.fromInvoices(updatedList);
      final statement = await _repository.generateStatement(
        startDate: state.statementStartDate,
        endDate: state.statementEndDate,
      );

      state = state.copyWith(
        allInvoices: updatedList,
        filteredInvoices: _applyFilter(updatedList, state.selectedStatus, state.searchQuery),
        reconciliationSummary: recon,
        activeStatement: statement,
        isLoading: false,
        successMessage: 'Payment of ₹${amount.toStringAsFixed(2)} reconciled against ${updatedInvoice.invoiceNumber}.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to record payment: $e',
      );
      return false;
    }
  }

  /// Applies a credit note or authorized adjustment to an invoice.
  Future<bool> applyCreditNote(ApplyCreditNoteDto dto) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final updatedInvoice = await _repository.applyCreditNote(dto);
      final updatedList = state.allInvoices.map((inv) {
        return inv.id == dto.invoiceId ? updatedInvoice : inv;
      }).toList();

      final recon = FinancialReconciliationSummary.fromInvoices(updatedList);
      final statement = await _repository.generateStatement(
        startDate: state.statementStartDate,
        endDate: state.statementEndDate,
      );

      state = state.copyWith(
        allInvoices: updatedList,
        filteredInvoices: _applyFilter(updatedList, state.selectedStatus, state.searchQuery),
        reconciliationSummary: recon,
        activeStatement: statement,
        isLoading: false,
        successMessage: 'Credit note of ₹${dto.creditAmount.toStringAsFixed(2)} applied to ${updatedInvoice.invoiceNumber}.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to apply credit note: $e',
      );
      return false;
    }
  }

  /// Updates statement period and re-generates statement.
  Future<void> updateStatementPeriod(DateTime start, DateTime end) async {
    state = state.copyWith(
      isLoading: true,
      statementStartDate: start,
      statementEndDate: end,
    );
    try {
      final statement = await _repository.generateStatement(
        startDate: start,
        endDate: end,
      );
      state = state.copyWith(
        activeStatement: statement,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to generate statement: $e',
      );
    }
  }

  static List<CommissionInvoice> _applyFilter(
    List<CommissionInvoice> invoices,
    InvoiceStatus? status,
    String query,
  ) {
    return invoices.where((inv) {
      if (status != null && inv.status != status) {
        return false;
      }
      if (query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final match = inv.invoiceNumber.toLowerCase().contains(q) ||
            inv.dealReference.toLowerCase().contains(q) ||
            inv.bookingReference.toLowerCase().contains(q) ||
            inv.commodityName.toLowerCase().contains(q) ||
            inv.buyerCompanyName.toLowerCase().contains(q) ||
            inv.sellerCompanyName.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();
  }
}

/// Global provider for InvoiceController.
final invoiceControllerProvider =
    NotifierProvider<InvoiceController, InvoiceState>(
  InvoiceController.new,
);
