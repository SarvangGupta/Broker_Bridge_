import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/commission_calculator.dart';
import '../../domain/commission_model.dart';

/// Card item displaying a deal-linked brokerage commission record.
class CommissionRecordCard extends StatelessWidget {
  final CommissionRecord record;
  final VoidCallback onTap;
  final VoidCallback onLogPayment;

  const CommissionRecordCard({
    super.key,
    required this.record,
    required this.onTap,
    required this.onLogPayment,
  });

  Color _getStatusColor(CommissionStatus status) {
    switch (status) {
      case CommissionStatus.paid:
        return AppColors.success;
      case CommissionStatus.partiallyPaid:
        return AppColors.info;
      case CommissionStatus.invoiced:
        return const Color(0xFF2563EB); // Royal Blue
      case CommissionStatus.eligible:
        return AppColors.primary;
      case CommissionStatus.accruing:
        return AppColors.warning;
      case CommissionStatus.disputed:
        return AppColors.error;
      case CommissionStatus.adjusted:
        return const Color(0xFF9333EA); // Purple
      case CommissionStatus.notEligible:
        return AppColors.textSecondaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(record.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Deal Reference + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Text(
                      record.dealReference,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  if (record.bookingReference != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      record.bookingReference!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  record.status.displayLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Commodity & Counterparties
          Text(
            record.commodityName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
          if (record.gradeName != null) ...[
            const SizedBox(height: 2),
            Text(
              record.gradeName!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
          const SizedBox(height: 6),

          Row(
            children: [
              const Icon(LucideIcons.arrowRightLeft, size: 12, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${record.buyerCompanyName}  ⇄  ${record.sellerCompanyName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Calculation Formula Chip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.calculator, size: 13, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Basis: ${record.calculationFormula}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 5-Tier Quantities Summary Row
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _QuantityPill(
                label: 'Contracted',
                value: '${record.quantities.contractedQuantity.toStringAsFixed(1)} ${record.quantities.unitSymbol}',
              ),
              _QuantityPill(
                label: 'Delivered',
                value: '${record.quantities.deliveredQuantity.toStringAsFixed(1)} ${record.quantities.unitSymbol}',
              ),
              if (record.quantities.disputedQuantity > 0)
                _QuantityPill(
                  label: 'Disputed',
                  value: '${record.quantities.disputedQuantity.toStringAsFixed(1)} ${record.quantities.unitSymbol}',
                  isDanger: true,
                ),
              _QuantityPill(
                label: 'Eligible',
                value: '${record.quantities.eligibleDeliveredQuantityMT.toStringAsFixed(1)} MT',
                isHighlight: true,
              ),
            ],
          ),
          const SizedBox(height: 10),

          const Divider(height: 1),
          const SizedBox(height: 8),

          // Financial Breakdown Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _FinancialColumn(
                label: 'Eligible',
                amount: record.eligibleCommission,
                color: AppColors.primaryDark,
              ),
              _FinancialColumn(
                label: 'Received',
                amount: record.paidAmount,
                color: AppColors.success,
              ),
              _FinancialColumn(
                label: 'Outstanding',
                amount: record.outstandingAmount,
                color: record.outstandingAmount > 0 ? AppColors.warning : AppColors.textSecondaryLight,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Gross Trade Turnover Subtitle (Explicit Fiduciary Boundary)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Raw Material Trade: ${CommissionCalculator.formatCurrency(record.grossRawMaterialValue)}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              if (record.status.canLogPayment)
                InkWell(
                  onTap: onLogPayment,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: const [
                        Icon(LucideIcons.receipt, size: 12, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Log Payment',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
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

class _QuantityPill extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;
  final bool isDanger;

  const _QuantityPill({
    required this.label,
    required this.value,
    this.isHighlight = false,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.backgroundLight;
    Color textCol = AppColors.textPrimaryLight;

    if (isHighlight) {
      bg = AppColors.primary.withValues(alpha: 0.1);
      textCol = AppColors.primary;
    } else if (isDanger) {
      bg = AppColors.error.withValues(alpha: 0.1);
      textCol = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
          color: textCol,
        ),
      ),
    );
  }
}

class _FinancialColumn extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _FinancialColumn({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          CommissionCalculator.formatCurrency(amount),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
