import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'package:rmbroker_mobile/features/dashboard/domain/dashboard_models.dart';

/// Visual theme tokens for activity category cards.
class _ActivityVisualTheme {
  final Color surfaceColor;
  final Color borderColor;
  final Color iconContainerColor;
  final Color iconColor;

  const _ActivityVisualTheme({
    required this.surfaceColor,
    required this.borderColor,
    required this.iconContainerColor,
    required this.iconColor,
  });
}

_ActivityVisualTheme _resolveActivityTheme(String category) {
  switch (category.toLowerCase()) {
    case 'deals':
      return const _ActivityVisualTheme(
        surfaceColor: Color(0xFFF0FDFA), // Teal 50
        borderColor: Color(0xFF99F6E4), // Teal 200
        iconContainerColor: Color(0xFFCCFBF1), // Teal 100
        iconColor: Color(0xFF0F766E), // Teal 700
      );
    case 'logistics':
      return const _ActivityVisualTheme(
        surfaceColor: Color(0xFFFFF7ED), // Orange 50
        borderColor: Color(0xFFFED7AA), // Orange 200
        iconContainerColor: Color(0xFFFFEDD5), // Orange 100
        iconColor: Color(0xFFC2410C), // Orange 700
      );
    case 'requirements':
      return const _ActivityVisualTheme(
        surfaceColor: Color(0xFFEFF6FF), // Blue 50
        borderColor: Color(0xFFBFDBFE), // Blue 200
        iconContainerColor: Color(0xFFDBEAFE), // Blue 100
        iconColor: Color(0xFF1D4ED8), // Blue 700
      );
    case 'finance':
      return const _ActivityVisualTheme(
        surfaceColor: Color(0xFFF0FDF4), // Green 50
        borderColor: Color(0xFFA7F3D0), // Green 200
        iconContainerColor: Color(0xFFD1FAE5), // Green 100
        iconColor: Color(0xFF059669), // Green 700
      );
    case 'disputes':
      return const _ActivityVisualTheme(
        surfaceColor: Color(0xFFFEF2F2), // Red 50
        borderColor: Color(0xFFFECACA), // Red 200
        iconContainerColor: Color(0xFFFEE2E2), // Red 100
        iconColor: Color(0xFFDC2626), // Red 700
      );
    default:
      return const _ActivityVisualTheme(
        surfaceColor: Color(0xFFF8FAFC),
        borderColor: Color(0xFFE2E8F0),
        iconContainerColor: Color(0xFFF1F5F9),
        iconColor: Color(0xFF0F766E),
      );
  }
}

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryLight,
                letterSpacing: -0.3,
              ),
            ),
            InkWell(
              onTap: () => context.push('/notifications'),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.primaryLight.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(LucideIcons.chevronRight, size: 12, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (activities.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = activities[index];
              final theme = _resolveActivityTheme(item.category);
              final icon = _getCategoryIcon(item.category);

              return Container(
                decoration: BoxDecoration(
                  color: theme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.borderColor, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: item.route != null ? () => context.push(item.route!) : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Themed icon container
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: theme.iconContainerColor,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(
                              child: Icon(icon, size: 16, color: theme.iconColor),
                            ),
                          ),
                          const SizedBox(width: 10),
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
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: theme.iconColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.iconContainerColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.relativeTime,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: theme.iconColor.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.description,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondaryLight,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (item.route != null) ...[
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Icon(
                                LucideIcons.chevronRight,
                                size: 14,
                                color: theme.iconColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          )
        else if (isAuthoritative)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: const [
                Icon(
                  LucideIcons.clock,
                  size: 18,
                  color: AppColors.textMutedLight,
                ),
                SizedBox(width: 10),
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(
                  LucideIcons.fileClock,
                  size: 16,
                  color: AppColors.textSecondaryLight,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Authoritative event stream connects via /api/v1/broker/dashboard. Real deals, dispatches, and notifications will populate here once active.',
                    style: TextStyle(
                      fontSize: 11.5,
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
