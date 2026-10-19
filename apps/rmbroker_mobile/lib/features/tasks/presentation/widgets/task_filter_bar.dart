import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/task_category.dart';
import '../../domain/task_filter.dart';
import '../../domain/task_priority.dart';
import '../../domain/task_status.dart';

/// Filter selection bar for tasks with status, priority, and category chips.
class TaskFilterBar extends StatelessWidget {
  final TaskFilterCriteria criteria;
  final ValueChanged<TaskFilterCriteria> onCriteriaChanged;

  const TaskFilterBar({
    super.key,
    required this.criteria,
    required this.onCriteriaChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChipItem(
                label: 'All Statuses',
                isSelected: criteria.statusFilter == null,
                onTap: () => onCriteriaChanged(
                  criteria.copyWith(statusFilter: () => null),
                ),
              ),
              const SizedBox(width: 6),
              ...TaskStatus.values.map((status) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FilterChipItem(
                    label: status.label,
                    icon: status.icon,
                    isSelected: criteria.statusFilter == status,
                    color: status.color,
                    onTap: () => onCriteriaChanged(
                      criteria.copyWith(
                        statusFilter: () => criteria.statusFilter == status
                            ? null
                            : status,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...TaskCategory.values.map((cat) {
                final isSelected = criteria.categoryFilter == cat ||
                    (cat == TaskCategory.all &&
                        criteria.categoryFilter == null);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FilterChipItem(
                    label: cat.label,
                    icon: cat.icon,
                    isSelected: isSelected,
                    onTap: () => onCriteriaChanged(
                      criteria.copyWith(
                        categoryFilter: () =>
                            cat == TaskCategory.all ? null : cat,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Priority Filter Chips & Clear Action
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChipItem(
                label: 'All Priorities',
                isSelected: criteria.priorityFilter == null,
                onTap: () => onCriteriaChanged(
                  criteria.copyWith(priorityFilter: () => null),
                ),
              ),
              const SizedBox(width: 6),
              ...TaskPriority.values.reversed.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FilterChipItem(
                    label: p.label,
                    isSelected: criteria.priorityFilter == p,
                    color: p.color,
                    onTap: () => onCriteriaChanged(
                      criteria.copyWith(
                        priorityFilter: () =>
                            criteria.priorityFilter == p ? null : p,
                      ),
                    ),
                  ),
                );
              }),
              if (!criteria.isDefault) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => onCriteriaChanged(const TaskFilterCriteria()),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.errorBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.x, size: 12, color: AppColors.error),
                        SizedBox(width: 4),
                        Text(
                          'Clear Filters',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    this.icon,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.borderLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? activeColor : AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
