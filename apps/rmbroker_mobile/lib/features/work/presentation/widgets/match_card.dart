import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/match_model.dart';

class MatchCard extends StatelessWidget {
  final SupplyMatchItem match;
  final VoidCallback onTap;
  final VoidCallback? onAllocate;

  const MatchCard({
    super.key,
    required this.match,
    required this.onTap,
    this.onAllocate,
  });

  Color _getClassificationColor(MatchClassification classification) {
    switch (classification) {
      case MatchClassification.strongMatch:
        return AppColors.success;
      case MatchClassification.goodMatch:
        return AppColors.primary;
      case MatchClassification.partialMatch:
        return const Color(0xFFD97706);
      case MatchClassification.lowMatch:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = match.offer;
    final classColor = _getClassificationColor(match.classification);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      color: AppColors.surfaceLight,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Score Banner
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: classColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.sparkles, size: 12, color: classColor),
                        const SizedBox(width: 4),
                        Text(
                          '${match.totalScore.toInt()}% — ${match.classification.displayLabel}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: classColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    offer.ref,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Seller Company & Verification
              Row(
                children: [
                  const Icon(LucideIcons.store, size: 14, color: AppColors.textSecondaryLight),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      offer.sellerCompanyName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (offer.isSellerVerified)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.verified, size: 13, color: AppColors.primary),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${offer.commodityName} • ${offer.gradeName}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 10),

              // Metrics Row: Quantity Coverage & Asking vs Target Price
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quantity Coverage',
                            style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${match.availableQuantityMT.toInt()} / ${match.requiredQuantityMT.toInt()} MT (${match.coveragePercentage.round()}%)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Offered Price',
                            style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${offer.askingPrice.toInt()} / ${offer.unitSymbol}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: match.priceDifference <= 0
                                  ? AppColors.success
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Compatibility Reasons (Green Checkmarks)
              if (match.compatibilityReasons.isNotEmpty) ...[
                const SizedBox(height: 2),
                ...match.compatibilityReasons.take(2).map((reason) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.checkCircle2, size: 12, color: AppColors.success),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reason,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimaryLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // Unmet Criteria / Risks (Amber Alerts)
              if (match.unmetCriteria.isNotEmpty) ...[
                const SizedBox(height: 2),
                ...match.unmetCriteria.take(2).map((risk) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.alertTriangle, size: 12, color: Color(0xFFD97706)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            risk,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 8),
              // Safety Disclaimers (ADR-004 & Quantity Rule)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.goldMuted.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.info, size: 11, color: AppColors.goldDark),
                    SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Recommendation only. Match does not reserve stock or create a deal.',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.goldDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (onAllocate != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(LucideIcons.gitCommit, size: 14),
                    label: const Text(
                      'Allocate Supply to Mandate',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    onPressed: onAllocate,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
