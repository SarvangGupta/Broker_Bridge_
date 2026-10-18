import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'package:rmbroker_mobile/core/widgets/app_card.dart';
import 'package:rmbroker_mobile/features/commission/domain/commission_calculator.dart';
import 'package:rmbroker_mobile/features/invoices/domain/invoice_model.dart';

/// Card widget displaying a single commission invoice with status badge,
/// calculation basis, counterparties, and payment indicators.
class InvoiceCard extends StatelessWidget {
  final CommissionInvoice invoice;
  final VoidCallback onTap;
  final VoidCallback? onLogPayment;

  const InvoiceCard({
    super.key,
    required this.invoice,
    required this.onTap,
    this.onLogPayment,
  });

  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return AppColors.success;
      case InvoiceStatus.partiallyPaid:
        return AppColors.info;
      case InvoiceStatus.issued:
        return const Color(0xFF2563EB); // Royal Blue
      case InvoiceStatus.overdue:
        return AppColors.error;
      case InvoiceStatus.disputed:
        return AppColors.warning;
      case InvoiceStatus.cancelledOrCredited:
        return const Color(0xFF9333EA); // Purple
      case InvoiceStatus.draft:
        return AppColors.textSecondaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(invoice.status);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Invoice Number + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        invoice.invoiceNumber,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Text(
                        invoice.dealReference,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        invoice.status.displayLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Commodity & Billed To
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.commodityName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Billed to: ${invoice.billedToParty} (${invoice.billedToParty == 'Buyer Enterprise' ? invoice.buyerCompanyName : invoice.sellerCompanyName})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Formula Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.calculator, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Formula: ${invoice.calculationFormula}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Financial Breakdown: Total Invoiced, Paid, Outstanding
            Row(
              children: [
                Expanded(
                  child: _FinancialPill(
                    label: 'Invoiced Total',
                    amount: invoice.totalAmount,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FinancialPill(
                    label: 'Paid Amount',
                    amount: invoice.paidAmount,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FinancialPill(
                    label: 'Balance Due',
                    amount: invoice.outstandingAmount,
                    color: invoice.outstandingAmount > 0
                        ? AppColors.error
                        : AppColors.textSecondaryLight,
                    isBold: invoice.outstandingAmount > 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Footer: Due Date + Quick Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.calendar,
                      size: 13,
                      color: invoice.isOverdue ? AppColors.error : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Due: ${dateFormat.format(invoice.dueDate)}${invoice.isOverdue ? ' (Overdue)' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: invoice.isOverdue ? FontWeight.w700 : FontWeight.w500,
                        color: invoice.isOverdue ? AppColors.error : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                if (invoice.outstandingAmount > 0 && onLogPayment != null)
                  InkWell(
                    onTap: onLogPayment,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.receipt, size: 12, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            'Log Payment',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancialPill extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool isBold;

  const _FinancialPill({
    required this.label,
    required this.amount,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
          ),
          const SizedBox(height: 2),
          Text(
            CommissionCalculator.formatCurrency(amount),
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
