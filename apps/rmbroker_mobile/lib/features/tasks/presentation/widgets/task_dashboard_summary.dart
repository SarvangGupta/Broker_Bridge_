import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/task_filter.dart';

/// Concise metrics dashboard displaying live counts of authorized broker tasks.
class TaskDashboardSummaryWidget extends StatelessWidget {
  final TaskDashboardSummary summary;
  final TaskDateFilter selectedDateFilter;
  final ValueChanged<TaskDateFilter> onSelectFilter;

  const TaskDashboardSummaryWidget({
    super.key,
    required this.summary,
    required this.selectedDateFilter,
    required this.onSelectFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Action Item Summary',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
            ),
            Text(
              '${summary.totalCount} Total Mandates',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Overdue
            Expanded(
              child: _MetricCard(
                title: 'Overdue',
                count: summary.overdueCount,
                icon: LucideIcons.alertTriangle,
                color: AppColors.error,
                backgroundColor: AppColors.errorBackground,
                isSelected: selectedDateFilter == TaskDateFilter.overdue,
                onTap: () => onSelectFilter(
                  selectedDateFilter == TaskDateFilter.overdue
                      ? TaskDateFilter.all
                      : TaskDateFilter.overdue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Due Today
            Expanded(
              child: _MetricCard(
                title: 'Due Today',
                count: summary.dueTodayCount,
                icon: LucideIcons.calendar,
                color: AppColors.warning,
                backgroundColor: AppColors.warningBackground,
                isSelected: selectedDateFilter == TaskDateFilter.today,
                onTap: () => onSelectFilter(
                  selectedDateFilter == TaskDateFilter.today
                      ? TaskDateFilter.all
                      : TaskDateFilter.today,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Upcoming
            Expanded(
              child: _MetricCard(
                title: 'Upcoming',
                count: summary.upcomingCount,
                icon: LucideIcons.clock,
                color: AppColors.info,
                backgroundColor: AppColors.infoBackground,
                isSelected: selectedDateFilter == TaskDateFilter.upcoming,
                onTap: () => onSelectFilter(
                  selectedDateFilter == TaskDateFilter.upcoming
                      ? TaskDateFilter.all
                      : TaskDateFilter.upcoming,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // High Priority Open Tasks
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        LucideIcons.flame,
                        size: 16,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'High / Urgent Priority',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${summary.highPriorityOpenCount} Open',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Recently Completed
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        LucideIcons.checkCircle2,
                        size: 16,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Concluded Actions',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${summary.recentlyCompletedCount} Completed',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _MetricCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? backgroundColor : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.borderLight,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 16, color: color),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
