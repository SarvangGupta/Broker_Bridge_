import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/notification_category.dart';

/// Horizontal scrollable category filter bar with unread counts and quick unread toggle.
class NotificationFilterBar extends StatelessWidget {
  final NotificationCategory selectedCategory;
  final bool unreadOnly;
  final Map<NotificationCategory, int> categoryCounts;
  final ValueChanged<NotificationCategory> onCategorySelected;
  final VoidCallback onToggleUnreadOnly;

  const NotificationFilterBar({
    super.key,
    required this.selectedCategory,
    required this.unreadOnly,
    required this.categoryCounts,
    required this.onCategorySelected,
    required this.onToggleUnreadOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Quick "Unread Only" toggle pill
              InkWell(
                onTap: onToggleUnreadOnly,
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: unreadOnly
                        ? AppColors.primary
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: unreadOnly
                          ? AppColors.primary
                          : AppColors.borderLight,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        unreadOnly ? LucideIcons.checkCircle2 : LucideIcons.circleDot,
                        size: 14,
                        color: unreadOnly ? Colors.white : AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Unread Only',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: unreadOnly ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Category Pills
              ...NotificationCategory.values.map((category) {
                final isSelected = selectedCategory == category;
                final count = categoryCounts[category] ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    showCheckmark: false,
                    selected: isSelected,
                    onSelected: (_) => onCategorySelected(category),
                    backgroundColor: AppColors.surfaceLight,
                    selectedColor: category.color.withValues(alpha: 0.16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? category.color : AppColors.borderLight,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    avatar: Icon(
                      category.icon,
                      size: 14,
                      color: isSelected ? category.color : AppColors.textSecondaryLight,
                    ),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          category.labelEn,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? category.color : AppColors.textPrimaryLight,
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? category.color
                                  : AppColors.textSecondaryLight.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
