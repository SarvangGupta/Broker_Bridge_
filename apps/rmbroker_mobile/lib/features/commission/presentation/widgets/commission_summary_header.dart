import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/commission_calculator.dart';
import '../../domain/commission_model.dart';

/// Top header for Broker Earnings & Commission summary metrics.
/// STRICT FIDUCIARY NOTICE: Gross raw material trade turnover is explicitly isolated.
class CommissionSummaryHeader extends StatelessWidget {
  final CommissionSummary summary;
  final VoidCallback? onFiduciaryTap;

  const CommissionSummaryHeader({
    super.key,
    required this.summary,
    this.onFiduciaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fiduciary Boundary Banner
        InkWell(
          onTap: onFiduciaryTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.shieldAlert, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fiduciary Boundary: Brokerage is solely based on agreed per-MT fee on delivered quantity. Gross trade turnover (${CommissionCalculator.formatCurrency(summary.totalGrossDealValuation)}) is not brokerage income.',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryLight,
                      height: 1.25,
                    ),
                  ),
                ),
                const Icon(LucideIcons.info, size: 14, color: AppColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Primary Hero Metric: Total Eligible Commission
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(LucideIcons.award, size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Authoritative Eligible Commission',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${summary.totalEligibleQuantityMT.toStringAsFixed(1)} MT Verified',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                CommissionCalculator.formatCurrency(summary.totalEligibleCommission),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Calculated across ${summary.totalDealsCount} mediated deal allocations (${summary.period})',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 4-Grid Breakdown: Invoiced, Received, Outstanding, Disputed
        Row(
          children: [
            Expanded(
              child: _MetricSubCard(
                title: 'Invoiced',
                amount: summary.totalInvoicedCommission,
                icon: LucideIcons.fileText,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricSubCard(
                title: 'Received',
                amount: summary.totalReceivedCommission,
                icon: LucideIcons.checkCircle2,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricSubCard(
                title: 'Outstanding',
                amount: summary.totalOutstandingCommission,
                icon: LucideIcons.clock,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricSubCard(
                title: 'Disputed',
                amount: summary.totalDisputedCommission,
                icon: LucideIcons.alertTriangle,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricSubCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  const _MetricSubCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            CommissionCalculator.formatCurrency(amount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: amount > 0 ? color : AppColors.textPrimaryLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
