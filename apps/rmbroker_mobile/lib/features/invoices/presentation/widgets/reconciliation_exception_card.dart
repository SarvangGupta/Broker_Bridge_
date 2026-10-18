import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'package:rmbroker_mobile/core/widgets/app_card.dart';
import 'package:rmbroker_mobile/features/commission/domain/commission_calculator.dart';
import 'package:rmbroker_mobile/features/invoices/domain/reconciliation_model.dart';

/// Card displaying a financial reconciliation exception or inconsistency.
class ReconciliationExceptionCard extends StatelessWidget {
  final ReconciliationInconsistency inconsistency;
  final VoidCallback? onResolve;

  const ReconciliationExceptionCard({
    super.key,
    required this.inconsistency,
    this.onResolve,
  });

  Color _getSeverityColor(InconsistencySeverity severity) {
    switch (severity) {
      case InconsistencySeverity.critical:
        return AppColors.error;
      case InconsistencySeverity.warning:
        return AppColors.warning;
      case InconsistencySeverity.info:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = _getSeverityColor(inconsistency.severity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Rule Violation + Severity Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.alertTriangle, size: 16, color: severityColor),
                    const SizedBox(width: 8),
                    Text(
                      inconsistency.ruleViolation,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: severityColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: severityColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    inconsistency.severity.displayLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: severityColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Target References
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    inconsistency.invoiceNumber,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  inconsistency.dealReference,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                ),
                const Spacer(),
                Text(
                  'Variance: ${CommissionCalculator.formatCurrency(inconsistency.variance)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Description
            Text(
              inconsistency.description,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimaryLight, height: 1.3),
            ),
            const SizedBox(height: 8),

            // Suggested Action Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.arrowRightCircle, size: 13, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Action: ${inconsistency.suggestedResolution}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
