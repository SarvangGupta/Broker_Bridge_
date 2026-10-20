import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/requirement_model.dart';

class RequirementCard extends StatelessWidget {
  final RequirementItem requirement;
  final VoidCallback onTap;
  final VoidCallback onFindMatches;
  final VoidCallback? onNegotiate;

  const RequirementCard({
    super.key,
    required this.requirement,
    required this.onTap,
    required this.onFindMatches,
    this.onNegotiate,
  });

  Color _getStatusColor(RequirementStatus status) {
    switch (status) {
      case RequirementStatus.open:
        return AppColors.info;
      case RequirementStatus.matching:
        return AppColors.primary;
      case RequirementStatus.partiallyAllocated:
        return const Color(0xFFD97706); // Amber
      case RequirementStatus.fullyAllocated:
      case RequirementStatus.fulfilled:
        return AppColors.success;
      case RequirementStatus.expired:
        return AppColors.textDisabled;
      case RequirementStatus.cancelled:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(requirement.status);

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
              // Top Row: Ref, Status Badge & Urgency
              Row(
                children: [
                  Text(
                    requirement.ref,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      requirement.status.displayLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (requirement.isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(LucideIcons.clock, size: 10, color: AppColors.error),
                          SizedBox(width: 3),
                          Text(
                            'Urgent',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Commodity & Grade
              Text(
                requirement.commodityName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                requirement.gradeName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 10),

              // Buyer Info
              Row(
                children: [
                  const Icon(LucideIcons.building, size: 13, color: AppColors.textSecondaryLight),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      requirement.buyerCompanyName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (requirement.isBuyerVerified)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.verified, size: 13, color: AppColors.primary),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Separated Quantities Box (Zero ambiguous mixing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                            'Requested',
                            style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            requirement.formattedRequestedQuantity,
                            style: const TextStyle(
                              fontSize: 12.5,
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
                            'Allocated',
                            style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            requirement.formattedAllocatedQuantity,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
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
                            'Remaining',
                            style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            requirement.formattedRemainingQuantity,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Target Price & Delivery terms
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(LucideIcons.indianRupee, size: 13, color: AppColors.textSecondaryLight),
                        const SizedBox(width: 4),
                        Text(
                          '₹${requirement.targetPrice.toInt()} / ${requirement.unitSymbol}',
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
                    child: Row(
                      children: [
                        const Icon(LucideIcons.mapPin, size: 13, color: AppColors.textSecondaryLight),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            requirement.deliveryTerms,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bottom Row: Fulfillment Progress & "Find Matches" CTA
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Fulfillment',
                              style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                            ),
                            Text(
                              '${requirement.fulfillmentPercentage}%',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: requirement.fulfillmentPercentage / 100,
                            minHeight: 5,
                            backgroundColor: AppColors.borderLight,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              requirement.fulfillmentPercentage == 100
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (onNegotiate != null && requirement.status != RequirementStatus.cancelled) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(LucideIcons.scale, size: 12),
                      label: Text(
                        requirement.isProposed ? 'Proposal' : 'Negotiate',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: onNegotiate,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (requirement.canBeMatched)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(LucideIcons.sparkles, size: 12, color: AppColors.primary),
                      label: const Text(
                        'Find Matches',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      onPressed: onFindMatches,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
