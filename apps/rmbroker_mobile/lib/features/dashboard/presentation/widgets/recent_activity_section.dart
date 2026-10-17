import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'package:rmbroker_mobile/core/widgets/app_card.dart';
import 'package:rmbroker_mobile/features/dashboard/domain/dashboard_models.dart';

/// Recent activity event stream for the broker desk.
class RecentActivitySection extends StatelessWidget {
  final List<BrokerActivityItem> activities;
  final bool isAuthoritative;

  const RecentActivitySection({
    super.key,
    required this.activities,
    this.isAuthoritative = false,
  });

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'deals':
        return Icons.handshake_outlined;
      case 'logistics':
        return LucideIcons.truck;
      case 'requirements':
        return LucideIcons.layers;
      case 'finance':
        return LucideIcons.indianRupee;
      case 'disputes':
        return LucideIcons.alertTriangle;
      default:
        return LucideIcons.activity;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'deals':
        return AppColors.primary;
      case 'logistics':
        return AppColors.warning;
      case 'requirements':
        return AppColors.secondary;
      case 'finance':
        return AppColors.success;
      case 'disputes':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
            ),
            Text(
              'Audit Stream',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (activities.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = activities[index];
              final color = _getCategoryColor(item.category);
              final icon = _getCategoryIcon(item.category);

              return AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 16, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimaryLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                item.relativeTime,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMutedLight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.description,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          )
        else if (isAuthoritative)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: const [
                Icon(
                  LucideIcons.clock,
                  size: 20,
                  color: AppColors.textMutedLight,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No recent trading desk activity recorded in current mandi session.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(
                  LucideIcons.fileClock,
                  size: 18,
                  color: AppColors.textSecondaryLight,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Authoritative event stream connects via /api/v1/broker/dashboard. Real deals, dispatches, and notifications will populate here once active.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
