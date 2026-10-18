import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'package:rmbroker_mobile/core/widgets/app_button.dart';
import 'package:rmbroker_mobile/core/widgets/app_card.dart';
import 'package:rmbroker_mobile/core/widgets/app_loading_indicator.dart';
import 'package:rmbroker_mobile/features/commission/domain/commission_calculator.dart';
import 'package:rmbroker_mobile/features/invoices/presentation/controllers/invoice_controller.dart';
import 'package:rmbroker_mobile/features/invoices/domain/invoice_model.dart';
import 'package:rmbroker_mobile/features/invoices/presentation/widgets/invoice_document_preview.dart';

/// Full screen displaying complete details, line items, payment history,
/// and audit trail for a single commission invoice.
class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final String invoiceId;

  const InvoiceDetailScreen({
    super.key,
    required this.invoiceId,
  });

  @override
  ConsumerState<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
  final _dateOnly = DateFormat('dd MMM yyyy');

  void _showApplyCreditNoteDialog(CommissionInvoice invoice) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    bool isSaving = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Apply Credit Note / Adjustment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outstanding Balance: ${CommissionCalculator.formatCurrency(invoice.outstandingAmount)}',
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
                        labelText: 'Credit Note Amount (₹)*',
                        prefixIcon: Icon(LucideIcons.indianRupee, size: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Mandatory Business Reason*',
                        hintText: 'e.g., Moisture deduction credit note agreed between parties',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                          final reason = reasonController.text.trim();

                          final dto = ApplyCreditNoteDto(
                            invoiceId: invoice.id,
                            creditAmount: amount,
                            reason: reason,
                            authorizedBy: 'Authorized Broker Intermediary',
                          );

                          final valErr = dto.validate(invoice);
                          if (valErr != null) {
                            setDialogState(() => errorText = valErr);
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                            errorText = null;
                          });

                          final navigator = Navigator.of(ctx);
                          final ok = await ref
                              .read(invoiceControllerProvider.notifier)
                              .applyCreditNote(dto);

                          if (ok) {
                            navigator.pop();
                          } else {
                            final state = ref.read(invoiceControllerProvider);
                            setDialogState(() {
                              isSaving = false;
                              errorText = state.errorMessage ?? 'Failed to apply credit note';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Apply Credit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRecordPaymentDialog(CommissionInvoice invoice) {
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
              title: const Text('Record Invoice Payment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outstanding Balance: ${CommissionCalculator.formatCurrency(invoice.outstandingAmount)}',
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: utrController,
                      decoration: const InputDecoration(
                        labelText: 'Bank UTR / Transaction Ref*',
                        hintText: 'e.g. UTR99281729104',
                        prefixIcon: Icon(LucideIcons.receipt, size: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                          final utr = utrController.text.trim();

                          if (amount <= 0) {
                            setDialogState(() => errorText = 'Enter a valid payment amount');
                            return;
                          }
                          if (utr.isEmpty) {
                            setDialogState(() => errorText = 'Enter a bank UTR / transaction reference');
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
                            final state = ref.read(invoiceControllerProvider);
                            setDialogState(() {
                              isSaving = false;
                              errorText = state.errorMessage ?? 'Payment failed';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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
    final invoice = state.allInvoices.firstWhere(
      (inv) => inv.id == widget.invoiceId,
      orElse: () => CommissionInvoice(
        id: widget.invoiceId,
        invoiceNumber: 'INV-PENDING',
        dealId: '',
        dealReference: '',
        bookingReference: '',
        billedToParty: 'Counterparty',
        buyerCompanyName: 'Buyer',
        sellerCompanyName: 'Seller',
        commodityName: 'Commodity',
        gradeName: 'Grade',
        eligibleDeliveredQuantity: 0.0,
        agreedRatePerMT: 0.0,
        lineItems: const [],
        subtotalAmount: 0.0,
        totalAmount: 0.0,
        outstandingAmount: 0.0,
        status: InvoiceStatus.draft,
        issueDate: DateTime.now(),
        dueDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

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
              context.go('/invoices');
            }
          },
        ),
        title: Text(invoice.invoiceNumber),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.fileText),
            tooltip: 'Preview Document',
            onPressed: () => InvoiceDocumentPreview.show(context, invoice: invoice),
          ),
        ],
      ),
      body: state.isLoading && invoice.dealReference.isEmpty
          ? const Center(child: AppLoadingIndicator(message: 'Loading invoice details...'))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Top Status Header Card
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              invoice.invoiceNumber,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              invoice.status.displayLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        invoice.commodityName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Grade: ${invoice.gradeName}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _DetailMeta(label: 'Issue Date', value: _dateOnly.format(invoice.issueDate)),
                          _DetailMeta(
                            label: 'Due Date',
                            value: _dateOnly.format(invoice.dueDate),
                            isAlert: invoice.isOverdue,
                          ),
                          _DetailMeta(label: 'Deal Ref', value: invoice.dealReference),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Counterparties Card
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.building2, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Text('Buyer:', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              invoice.buyerCompanyName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        children: [
                          const Icon(LucideIcons.store, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Text('Seller:', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              invoice.sellerCompanyName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Calculation Breakdown & Line Items Card
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.calculator, size: 16, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Calculation Breakdown & Items',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          'Formula: ${invoice.calculationFormula}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...invoice.lineItems.map((li) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    li.description,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  CommissionCalculator.formatCurrency(li.amount),
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          )),
                      const Divider(height: 20),
                      _SummaryRow('Subtotal', CommissionCalculator.formatCurrency(invoice.subtotalAmount)),
                      _SummaryRow('GST / Tax (Non-assumed)', '₹${invoice.taxAmount.toStringAsFixed(2)}'),
                      if (invoice.creditedAmount > 0)
                        _SummaryRow(
                          'Credit Notes / Adjustments',
                          '-${CommissionCalculator.formatCurrency(invoice.creditedAmount)}',
                          isCredit: true,
                        ),
                      const Divider(height: 14),
                      _SummaryRow('Total Invoiced', CommissionCalculator.formatCurrency(invoice.totalAmount), isBold: true),
                      _SummaryRow('Total Paid', CommissionCalculator.formatCurrency(invoice.paidAmount), isSuccess: true),
                      const Divider(height: 14),
                      _SummaryRow(
                        'Outstanding Due',
                        CommissionCalculator.formatCurrency(invoice.outstandingAmount),
                        isBalanceDue: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Recorded Payments Timeline Card
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.receipt, size: 16, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Recorded Commission Payments',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (invoice.paymentReferences.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No payment receipts recorded against this invoice yet.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                          ),
                        )
                      else
                        ...invoice.paymentReferences.map((utr) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.checkCircle2, size: 16, color: AppColors.success),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'UTR Reference: $utr',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const Text(
                                    'Reconciled',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Audit History
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.history, size: 16, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Invoice Audit Trail',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...invoice.auditTrail.map((aud) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        aud.description,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        '${aud.actor} • ${_dateFormat.format(aud.timestamp)}',
                                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Bottom Action Buttons
                Row(
                  children: [
                    if (invoice.outstandingAmount > 0) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(LucideIcons.tag, size: 14),
                          label: const Text('Credit Note'),
                          onPressed: () => _showApplyCreditNoteDialog(invoice),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          label: 'Log Payment',
                          onPressed: () => _showRecordPaymentDialog(invoice),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: AppButton(
                          label: 'Preview Document',
                          onPressed: () => InvoiceDocumentPreview.show(context, invoice: invoice),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _DetailMeta extends StatelessWidget {
  final String label;
  final String value;
  final bool isAlert;

  const _DetailMeta({required this.label, required this.value, this.isAlert = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isAlert ? AppColors.error : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isSuccess;
  final bool isCredit;
  final bool isBalanceDue;

  const _SummaryRow(
    this.label,
    this.value, {
    this.isBold = false,
    this.isSuccess = false,
    this.isCredit = false,
    this.isBalanceDue = false,
  });

  @override
  Widget build(BuildContext context) {
    Color valColor = AppColors.textPrimaryLight;
    if (isSuccess) valColor = AppColors.success;
    if (isCredit) valColor = const Color(0xFF9333EA);
    if (isBalanceDue) valColor = AppColors.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBalanceDue || isBold ? 12.5 : 11.5,
              fontWeight: isBalanceDue || isBold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBalanceDue ? 14 : (isBold ? 13 : 12),
              fontWeight: isBalanceDue || isBold ? FontWeight.w800 : FontWeight.w700,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }
}
