import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/commission_calculator.dart';
import '../../domain/commission_model.dart';
import '../../../invoices/presentation/widgets/create_invoice_sheet.dart';
import '../controllers/commission_controller.dart';
import 'log_commission_payment_dialog.dart';

/// Bottom sheet displaying the full mathematical breakdown, quantities audit,
/// payment timeline, and adjustment history for a single deal.
class DealCommissionSheet extends ConsumerStatefulWidget {
  final CommissionRecord initialRecord;

  const DealCommissionSheet({
    super.key,
    required this.initialRecord,
  });

  static Future<void> show(BuildContext context, {required CommissionRecord record}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DealCommissionSheet(initialRecord: record),
    );
  }

  @override
  ConsumerState<DealCommissionSheet> createState() => _DealCommissionSheetState();
}

class _DealCommissionSheetState extends ConsumerState<DealCommissionSheet> {
  final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  void _showAdjustRateDialog(CommissionRecord record) {
    final rateController = TextEditingController(text: record.agreedRatePerMT.toStringAsFixed(2));
    final reasonController = TextEditingController();
    bool isSaving = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Adjust Commission Rate'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rate changes are auditable and strictly preserve historical calculation records.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 12),
                    if (errorText != null) ...[
                      Text(errorText!, style: const TextStyle(fontSize: 12, color: AppColors.error)),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: rateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'New Commission Rate (₹/MT)*',
                        prefixIcon: Icon(LucideIcons.indianRupee, size: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Adjustment Reason*',
                        hintText: 'e.g. Mandi fee renegotiation with seller',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newRate = double.tryParse(rateController.text.trim());
                          final reason = reasonController.text.trim();
                          if (newRate == null || newRate < 0) {
                            setDialogState(() => errorText = 'Enter a valid rate >= 0');
                            return;
                          }
                          if (reason.isEmpty) {
                            setDialogState(() => errorText = 'Reason is required');
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final ok = await ref.read(commissionControllerProvider.notifier).adjustCommission(
                                dealId: record.dealId,
                                newRatePerMT: newRate,
                                reason: reason,
                              );
                          if (ok) {
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          } else {
                            setDialogState(() {
                              isSaving = false;
                              errorText = 'Failed to apply adjustment';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Adjustment'),
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
    // Read freshest record from state if present
    final state = ref.watch(commissionControllerProvider);
    final record = state.allRecords.firstWhere(
      (r) => r.dealId == widget.initialRecord.dealId,
      orElse: () => widget.initialRecord,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title & Navigation (Back / Close)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(LucideIcons.arrowLeft, size: 22, color: AppColors.textPrimaryLight),
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                record.dealReference,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              record.status.displayLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.commodityName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Counterparties
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _PartyTile(
                      role: 'Buyer Enterprise',
                      name: record.buyerCompanyName,
                      icon: LucideIcons.building2,
                    ),
                    const Divider(height: 14),
                    _PartyTile(
                      role: 'Seller Enterprise',
                      name: record.sellerCompanyName,
                      icon: LucideIcons.store,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Section 1: Pure Mathematical Breakdown Card
              const Text(
                'Authoritative Commission Calculation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(LucideIcons.calculator, size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'APPROVED MANDI COMMISSION FORMULA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Eligible Commission = Eligible Delivered Quantity (MT) × Agreed Commission Rate (${record.commissionBasis})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Eligible Delivered MT', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight)),
                              Text(
                                '${record.quantities.eligibleDeliveredQuantityMT.toStringAsFixed(2)} MT',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          const Text('×', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Agreed Rate', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight)),
                              Text(
                                '₹${record.agreedRatePerMT.toStringAsFixed(2)} / MT',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          const Text('=', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Commission', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight)),
                              Text(
                                CommissionCalculator.formatCurrency(record.eligibleCommission),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primaryDark),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Section 2: 7-Tier Quantities Audit
              const Text(
                'Fulfillment Quantities Audit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _QuantityAuditRow('Contracted Volume', '${record.quantities.contractedQuantity} ${record.quantities.unitSymbol}'),
                    _QuantityAuditRow('Dispatched Volume', '${record.quantities.dispatchedQuantity} ${record.quantities.unitSymbol}'),
                    _QuantityAuditRow('Delivered Volume', '${record.quantities.deliveredQuantity} ${record.quantities.unitSymbol}'),
                    _QuantityAuditRow('Accepted Volume', '${record.quantities.acceptedQuantity} ${record.quantities.unitSymbol}'),
                    if (record.quantities.rejectedQuantity > 0)
                      _QuantityAuditRow('Rejected Volume', '${record.quantities.rejectedQuantity} ${record.quantities.unitSymbol}', isNegative: true),
                    if (record.quantities.disputedQuantity > 0)
                      _QuantityAuditRow('Disputed Volume', '${record.quantities.disputedQuantity} ${record.quantities.unitSymbol}', isNegative: true),
                    const Divider(height: 16),
                    _QuantityAuditRow(
                      'Eligible Delivered Volume',
                      '${record.quantities.eligibleDeliveredQuantityMT} MT',
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Section 3: Financial Settlement Overview
              const Text(
                'Financial Settlement Ledger',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _LedgerRow('Raw Material Trade Value', CommissionCalculator.formatCurrency(record.grossRawMaterialValue), subtitle: '(Fiduciary Gross Deal Turnover - Excluded from Brokerage)'),
                    _LedgerRow('Calculated Brokerage Accrual', CommissionCalculator.formatCurrency(record.calculatedCommission)),
                    _LedgerRow('Eligible Brokerage Commission', CommissionCalculator.formatCurrency(record.eligibleCommission), isHighlight: true),
                    if (record.invoicedAmount > 0)
                      _LedgerRow('Invoiced Amount', CommissionCalculator.formatCurrency(record.invoicedAmount), subtitle: record.invoiceNumber != null ? 'Invoice: ${record.invoiceNumber}' : null),
                    _LedgerRow('Received Brokerage Payment', CommissionCalculator.formatCurrency(record.paidAmount), color: AppColors.success),
                    if (record.disputedAmount > 0)
                      _LedgerRow('Disputed / Withheld Commission', CommissionCalculator.formatCurrency(record.disputedAmount), color: AppColors.error),
                    const Divider(height: 16),
                    _LedgerRow(
                      'Outstanding Receivable',
                      CommissionCalculator.formatCurrency(record.outstandingAmount),
                      isBold: true,
                      color: record.outstandingAmount > 0 ? AppColors.warning : AppColors.success,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section 4: Logged Payments History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Commission Payment History',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  if (record.status.canLogPayment)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      ),
                      onPressed: () => LogCommissionPaymentDialog.show(context, record: record),
                      icon: const Icon(LucideIcons.plus, size: 14, color: AppColors.primary),
                      label: const Text('Add Payment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (record.payments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Center(
                    child: Text(
                      'No commission payments recorded yet for this deal.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                  ),
                )
              else
                ...record.payments.map((p) => _PaymentHistoryItem(payment: p, dateFormat: _dateFormat)),
              const SizedBox(height: 16),

              // Section 5: Rate Adjustments History
              if (record.adjustments.isNotEmpty) ...[
                const Text(
                  'Adjustment Audit History',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                ...record.adjustments.map((a) => _AdjustmentHistoryItem(adjustment: a, dateFormat: _dateFormat)),
                const SizedBox(height: 16),
              ],

              // Invoicing Action
              if (record.quantities.eligibleDeliveredQuantity > 0) ...[
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(LucideIcons.fileSpreadsheet, size: 16),
                    label: const Text('Generate / Review Commission Invoice', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () {
                      CreateInvoiceSheet.show(context, record: record);
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Actions Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showAdjustRateDialog(record),
                      icon: const Icon(LucideIcons.edit3, size: 16),
                      label: const Text('Adjust Rate', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  if (record.status.canLogPayment) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: 'Log Payment',
                        icon: const Icon(LucideIcons.receipt, size: 16, color: Colors.white),
                        onPressed: () => LogCommissionPaymentDialog.show(context, record: record),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _PartyTile extends StatelessWidget {
  final String role;
  final String name;
  final IconData icon;

  const _PartyTile({
    required this.role,
    required this.name,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight)),
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight)),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuantityAuditRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isNegative;

  const _QuantityAuditRow(
    this.label,
    this.value, {
    this.isBold = false,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isNegative ? AppColors.error : AppColors.textSecondaryLight,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isNegative ? AppColors.error : (isBold ? AppColors.primaryDark : AppColors.textPrimaryLight),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final String label;
  final String amount;
  final String? subtitle;
  final bool isBold;
  final bool isHighlight;
  final Color? color;

  const _LedgerRow(
    this.label,
    this.amount, {
    this.subtitle,
    this.isBold = false,
    this.isHighlight = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isBold ? FontWeight.w800 : (isHighlight ? FontWeight.w700 : FontWeight.w500),
                  color: isBold ? AppColors.textPrimaryLight : AppColors.textSecondaryLight,
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  fontSize: isBold ? 14 : 12.5,
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                  color: color ?? (isHighlight ? AppColors.primaryDark : AppColors.textPrimaryLight),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentHistoryItem extends StatelessWidget {
  final CommissionPaymentItem payment;
  final DateFormat dateFormat;

  const _PaymentHistoryItem({
    required this.payment,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.checkCircle2, size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    payment.referenceNumber,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
                  ),
                ],
              ),
              Text(
                CommissionCalculator.formatCurrency(payment.amount),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                payment.direction,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
              Text(
                dateFormat.format(payment.paymentDate),
                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
          if (payment.notes != null) ...[
            const SizedBox(height: 4),
            Text(
              payment.notes!,
              style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdjustmentHistoryItem extends StatelessWidget {
  final CommissionAdjustment adjustment;
  final DateFormat dateFormat;

  const _AdjustmentHistoryItem({
    required this.adjustment,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF9333EA).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9333EA).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Commission Rate Adjusted',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF9333EA)),
              ),
              Text(
                dateFormat.format(adjustment.createdAt),
                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Previous: ₹${adjustment.previousCommission.toStringAsFixed(2)}  →  Adjusted: ₹${adjustment.adjustedCommission.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
          ),
          const SizedBox(height: 2),
          Text(
            'Reason: ${adjustment.reason} (By: ${adjustment.adjustedBy})',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
          ),
        ],
      ),
    );
  }
}
