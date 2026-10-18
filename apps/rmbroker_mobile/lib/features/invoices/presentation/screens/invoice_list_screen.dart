import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'package:rmbroker_mobile/core/widgets/app_card.dart';
import 'package:rmbroker_mobile/core/widgets/app_empty_state.dart';
import 'package:rmbroker_mobile/core/widgets/app_loading_indicator.dart';
import 'package:rmbroker_mobile/features/commission/domain/commission_calculator.dart';
import 'package:rmbroker_mobile/features/invoices/presentation/controllers/invoice_controller.dart';
import 'package:rmbroker_mobile/features/invoices/domain/invoice_model.dart';
import 'package:rmbroker_mobile/features/invoices/presentation/widgets/invoice_card.dart';
import 'package:rmbroker_mobile/features/invoices/presentation/widgets/reconciliation_exception_card.dart';
import 'package:rmbroker_mobile/features/invoices/presentation/widgets/statement_document_preview.dart';

/// Top-level screen for Commission Invoices, Financial Statements, and Reconciliation.
class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showRecordPaymentModal(CommissionInvoice invoice) {
    final amountController = TextEditingController(text: invoice.outstandingAmount.toStringAsFixed(2));
    final utrController = TextEditingController();
    String method = 'NEFT';
    bool isSaving = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Text('Record Payment: ${invoice.invoiceNumber}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outstanding: ${CommissionCalculator.formatCurrency(invoice.outstandingAmount)}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                    const SizedBox(height: 10),
                    if (errorText != null) ...[
                      Text(errorText!, style: const TextStyle(fontSize: 12, color: AppColors.error)),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount (₹)*',
                        prefixIcon: Icon(LucideIcons.indianRupee, size: 16),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: utrController,
                      decoration: const InputDecoration(
                        labelText: 'Bank UTR / Transaction Ref*',
                        prefixIcon: Icon(LucideIcons.receipt, size: 16),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      decoration: const InputDecoration(labelText: 'Payment Mode'),
                      items: const [
                        DropdownMenuItem(value: 'NEFT', child: Text('NEFT Transfer')),
                        DropdownMenuItem(value: 'RTGS', child: Text('RTGS Transfer')),
                        DropdownMenuItem(value: 'IMPS', child: Text('IMPS Instant')),
                        DropdownMenuItem(value: 'Cheque', child: Text('Bank Cheque')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => method = v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                          final utr = utrController.text.trim();

                          if (amount <= 0) {
                            setDialogState(() => errorText = 'Enter a valid amount');
                            return;
                          }
                          if (utr.isEmpty) {
                            setDialogState(() => errorText = 'Enter a bank UTR reference');
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                            errorText = null;
                          });

                          final navigator = Navigator.of(ctx);
                          final ok = await ref
                              .read(invoiceControllerProvider.notifier)
                              .recordPayment(
                                invoiceId: invoice.id,
                                amount: amount,
                                utrNumber: utr,
                                paymentMethod: method,
                              );

                          if (ok) {
                            navigator.pop();
                          } else {
                            final s = ref.read(invoiceControllerProvider);
                            setDialogState(() {
                              isSaving = false;
                              errorText = s.errorMessage ?? 'Payment failed';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Record Payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoiceControllerProvider);
    final controller = ref.read(invoiceControllerProvider.notifier);

    // Snackbar listeners
    ref.listen<InvoiceState>(invoiceControllerProvider, (prev, next) {
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!), backgroundColor: AppColors.success),
        );
      }
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: AppColors.error),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Invoices & Reconciliation'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: 'Refresh Ledger',
            onPressed: () => controller.loadInvoices(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryLight,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Invoices', icon: Icon(LucideIcons.fileSpreadsheet, size: 16)),
            Tab(text: 'Statements', icon: Icon(LucideIcons.fileText, size: 16)),
            Tab(text: 'Reconciliation', icon: Icon(LucideIcons.scale, size: 16)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Invoices
          _buildInvoicesTab(state, controller),
          // Tab 2: Statements
          _buildStatementsTab(state, controller),
          // Tab 3: Reconciliation
          _buildReconciliationTab(state, controller),
        ],
      ),
    );
  }

  Widget _buildInvoicesTab(InvoiceState state, InvoiceController controller) {
    // Totals across all invoices
    double totalInvoiced = 0.0;
    double totalPaid = 0.0;
    double totalOutstanding = 0.0;

    for (final inv in state.allInvoices) {
      totalInvoiced += inv.totalAmount;
      totalPaid += inv.paidAmount;
      totalOutstanding += inv.outstandingAmount;
    }

    return Column(
      children: [
        // Search & KPI Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Search Input
              TextField(
                controller: _searchController,
                onChanged: (q) => controller.search(q),
                decoration: InputDecoration(
                  hintText: 'Search invoices, deals, parties...',
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            controller.search('');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),

              // KPI Row
              Row(
                children: [
                  Expanded(
                    child: _MiniSummaryCard(
                      label: 'Total Invoiced',
                      value: CommissionCalculator.formatCurrency(totalInvoiced),
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniSummaryCard(
                      label: 'Total Received',
                      value: CommissionCalculator.formatCurrency(totalPaid),
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniSummaryCard(
                      label: 'Outstanding',
                      value: CommissionCalculator.formatCurrency(totalOutstanding),
                      color: totalOutstanding > 0 ? AppColors.error : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Status Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All (${state.allInvoices.length})',
                      isSelected: state.selectedStatus == null,
                      onTap: () => controller.filterByStatus(null),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Issued',
                      isSelected: state.selectedStatus == InvoiceStatus.issued,
                      onTap: () => controller.filterByStatus(InvoiceStatus.issued),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Partially Paid',
                      isSelected: state.selectedStatus == InvoiceStatus.partiallyPaid,
                      onTap: () => controller.filterByStatus(InvoiceStatus.partiallyPaid),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Paid',
                      isSelected: state.selectedStatus == InvoiceStatus.paid,
                      onTap: () => controller.filterByStatus(InvoiceStatus.paid),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Overdue',
                      isSelected: state.selectedStatus == InvoiceStatus.overdue,
                      onTap: () => controller.filterByStatus(InvoiceStatus.overdue),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Disputed',
                      isSelected: state.selectedStatus == InvoiceStatus.disputed,
                      onTap: () => controller.filterByStatus(InvoiceStatus.disputed),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Invoices List
        Expanded(
          child: state.isLoading && state.allInvoices.isEmpty
              ? const Center(child: AppLoadingIndicator(message: 'Loading invoices...'))
              : state.filteredInvoices.isEmpty
                  ? const Center(
                      child: AppEmptyState(
                        title: 'No Invoices Found',
                        description: 'No commission invoices match your filter criteria.',
                        icon: LucideIcons.fileSpreadsheet,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: state.filteredInvoices.length,
                      itemBuilder: (context, index) {
                        final invoice = state.filteredInvoices[index];
                        return InvoiceCard(
                          invoice: invoice,
                          onTap: () => context.push('/invoices/${invoice.id}'),
                          onLogPayment: () => _showRecordPaymentModal(invoice),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildStatementsTab(InvoiceState state, InvoiceController controller) {
    final statement = state.activeStatement;

    return state.isLoading && statement == null
        ? const Center(child: AppLoadingIndicator(message: 'Generating statement...'))
        : ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Statement Header Card
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Brokerage Commission Statement',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (statement != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statement.statementNumber,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Period: ${_dateFormat.format(state.statementStartDate)} – ${_dateFormat.format(state.statementEndDate)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                    const Divider(height: 20),
                    if (statement != null) ...[
                      Row(
                        children: [
                          Expanded(child: _StatementTile(label: 'Invoiced', amount: statement.totalCommissionInvoiced, color: AppColors.primary)),
                          const SizedBox(width: 8),
                          Expanded(child: _StatementTile(label: 'Received', amount: statement.totalPaymentsReceived, color: AppColors.success)),
                          const SizedBox(width: 8),
                          Expanded(child: _StatementTile(label: 'Closing', amount: statement.closingOutstandingBalance, color: AppColors.error, isBold: true)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Export / Preview Button
              if (statement != null)
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    icon: const Icon(LucideIcons.fileText, size: 16),
                    label: const Text('Preview / Export Financial Statement'),
                    onPressed: () => StatementDocumentPreview.show(context, statement: statement),
                  ),
                ),
              const SizedBox(height: 16),

              // Ledger Transactions List
              const Text(
                'Transaction Ledger Rows',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
              ),
              const SizedBox(height: 8),

              if (statement == null || statement.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No ledger entries found for the selected period.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                  ),
                )
              else
                ...statement.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: item.debit > 0
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                item.debit > 0 ? LucideIcons.fileText : LucideIcons.receipt,
                                size: 16,
                                color: item.debit > 0 ? AppColors.primary : AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.reference,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    item.description,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item.debit > 0
                                      ? '+${CommissionCalculator.formatCurrency(item.debit)}'
                                      : '-${CommissionCalculator.formatCurrency(item.credit)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: item.debit > 0 ? AppColors.textPrimaryLight : AppColors.success,
                                  ),
                                ),
                                Text(
                                  _dateFormat.format(item.date),
                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          );
  }

  Widget _buildReconciliationTab(InvoiceState state, InvoiceController controller) {
    final recon = state.reconciliationSummary;

    return state.isLoading && recon == null
        ? const Center(child: AppLoadingIndicator(message: 'Computing reconciliation...'))
        : ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Reconciliation Summary Overview Card
              if (recon != null) ...[
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.scale, size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Financial Reconciliation Status',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const Divider(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _ReconStat(
                              label: 'Fully Paid',
                              count: recon.fullyPaidCount,
                              color: AppColors.success,
                            ),
                          ),
                          Expanded(
                            child: _ReconStat(
                              label: 'Partially Paid',
                              count: recon.partiallyPaidCount,
                              color: AppColors.info,
                            ),
                          ),
                          Expanded(
                            child: _ReconStat(
                              label: 'Unpaid Due',
                              count: recon.unpaidCount,
                              color: AppColors.error,
                            ),
                          ),
                          Expanded(
                            child: _ReconStat(
                              label: 'Overpaid',
                              count: recon.overpaidCount,
                              color: const Color(0xFF9333EA),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Inconsistencies & Exceptions Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Reconciliation Exceptions & Alerts',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: recon.inconsistencies.isNotEmpty
                            ? AppColors.error.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${recon.inconsistencies.length} Flagged',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: recon.inconsistencies.isNotEmpty ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (recon.inconsistencies.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(LucideIcons.checkCheck, size: 32, color: AppColors.success),
                          SizedBox(height: 8),
                          Text(
                            'All invoices and payments are fully reconciled.\nNo variances or overpayments detected.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...recon.inconsistencies.map((inc) => ReconciliationExceptionCard(
                        inconsistency: inc,
                      )),
              ],
            ],
          );
  }
}

class _MiniSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniSummaryCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}

class _StatementTile extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool isBold;

  const _StatementTile({required this.label, required this.amount, required this.color, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight)),
        const SizedBox(height: 2),
        Text(
          CommissionCalculator.formatCurrency(amount),
          style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.w800 : FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class _ReconStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ReconStat({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
