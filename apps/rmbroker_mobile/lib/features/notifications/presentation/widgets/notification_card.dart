import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/notification_model.dart';

/// Card widget rendering a single business notification item with actionable navigation.
class NotificationCard extends StatelessWidget {
  final BrokerNotification notification;
  final ValueChanged<BrokerNotification> onTap;
  final ValueChanged<BrokerNotification>? onAction;
  final ValueChanged<BrokerNotification>? onMarkAsRead;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    this.onAction,
    this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    final category = notification.category;
    final isUnread = !notification.isRead;

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(notification),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isUnread
                ? category.color.withValues(alpha: 0.04)
                : Colors.transparent,
            border: isUnread
                ? Border.all(color: category.color.withValues(alpha: 0.35), width: 1.2)
                : null,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Category Badge, Relative Time, Unread Dot
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Category Icon Avatar
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      category.icon,
                      size: 16,
                      color: category.color,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Category Label
                  Text(
                    category.labelEn,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: category.color,
                    ),
                  ),

                  // Urgent Badge if applicable
                  if (notification.isUrgent) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.error, width: 0.8),
                      ),
                      child: const Text(
                        'ACTION REQUIRED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Relative Timestamp
                  Text(
                    notification.formattedTime,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // Unread Dot
                  if (isUnread) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                notification.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),

              // Message / Context Reason
              Text(
                notification.contextReason.isNotEmpty
                    ? notification.contextReason
                    : notification.message,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondaryLight,
                  height: 1.35,
                ),
              ),

              // Bottom Actions Row (if actionable or unread)
              if (notification.isActionable || isUnread) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Mark as read button (if unread)
                    if (isUnread && onMarkAsRead != null) ...[
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AppColors.textSecondaryLight,
                        ),
                        icon: const Icon(LucideIcons.check, size: 14),
                        label: const Text(
                          'Mark Read',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => onMarkAsRead!(notification),
                      ),
                    ],

                    const Spacer(),

                    // Action Button (Navigate to record)
                    if (notification.isActionable) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: category.color,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(LucideIcons.externalLink, size: 13),
                        label: Text(
                          notification.actionLabel ?? 'View Record',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () {
                          if (onAction != null) {
                            onAction!(notification);
                          } else {
                            onTap(notification);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
