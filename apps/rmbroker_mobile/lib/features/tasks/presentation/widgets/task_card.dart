import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/task_model.dart';
import '../../domain/task_status.dart';

/// Card widget rendering a single broker follow-up task with quick toggle and detail navigation.
class TaskCard extends StatelessWidget {
  final BrokerTask task;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggleComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == TaskStatus.completed;
    final isCancelled = task.status == TaskStatus.cancelled;

    Color dueBadgeColor = AppColors.textSecondaryLight;
    Color dueBadgeBg = AppColors.backgroundLight;
    IconData dueIcon = LucideIcons.clock;

    if (isCompleted) {
      dueBadgeColor = AppColors.success;
      dueBadgeBg = AppColors.successBackground;
      dueIcon = LucideIcons.checkCheck;
    } else if (isCancelled) {
      dueBadgeColor = AppColors.textDisabled;
      dueBadgeBg = AppColors.backgroundLight;
      dueIcon = LucideIcons.ban;
    } else if (task.isOverdue) {
      dueBadgeColor = AppColors.error;
      dueBadgeBg = AppColors.errorBackground;
      dueIcon = LucideIcons.alertTriangle;
    } else if (task.isDueToday) {
      dueBadgeColor = AppColors.warning;
      dueBadgeBg = AppColors.warningBackground;
      dueIcon = LucideIcons.calendar;
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: InkWell(
        key: ValueKey('task_card_${task.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Checkbox, Title, Priority Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Toggle Complete Action
                InkWell(
                  key: ValueKey('task_toggle_${task.id}'),
                  onTap: onToggleComplete,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      isCompleted
                          ? LucideIcons.checkCircle2
                          : (isCancelled
                              ? LucideIcons.xCircle
                              : LucideIcons.circle),
                      size: 22,
                      color: isCompleted
                          ? AppColors.success
                          : (isCancelled
                              ? AppColors.textDisabled
                              : AppColors.borderLight),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Title and Counterparty snippet
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isCompleted
                              ? AppColors.textSecondaryLight
                              : AppColors.textPrimaryLight,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (task.contactName != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.building2,
                              size: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                task.contactName!,
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
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Priority Indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: task.priority.backgroundColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: task.priority.color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    task.priority.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: task.priority.color,
                    ),
                  ),
                ),
              ],
            ),

            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Text(
                  task.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Bottom Row: Due Date, Category, and Linked Record Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Due Date Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: dueBadgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(dueIcon, size: 12, color: dueBadgeColor),
                      const SizedBox(width: 5),
                      Text(
                        task.timeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: dueBadgeColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Linked Record Reference Tag or Category
                if (task.linkedRecord != null)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            task.linkedRecord!.type.icon,
                            size: 11,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              task.linkedRecord!.reference,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Text(
                    task.category.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondaryLight,
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
