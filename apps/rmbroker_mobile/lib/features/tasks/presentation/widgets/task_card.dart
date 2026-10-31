import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/task_model.dart';
import '../../domain/task_priority.dart';
import '../../domain/task_status.dart';

/// Clean, action-oriented card widget rendering a broker follow-up task.
/// Matches the approved My Tasks UX design concept.
class TaskCard extends StatelessWidget {
  final BrokerTask task;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggleComplete,
    this.onEdit,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == TaskStatus.completed;
    final isCancelled = task.status == TaskStatus.cancelled;

    // Pastel Priority Colors
    Color priorityBg;
    Color priorityTextColor;
    switch (task.priority) {
      case TaskPriority.urgent:
        priorityBg = const Color(0xFFFEE2E2);
        priorityTextColor = const Color(0xFFDC2626);
        break;
      case TaskPriority.high:
        priorityBg = const Color(0xFFFEF3C7);
        priorityTextColor = const Color(0xFFD97706);
        break;
      case TaskPriority.normal:
        priorityBg = const Color(0xFFE6F4EA);
        priorityTextColor = const Color(0xFF0F766E);
        break;
      case TaskPriority.low:
        priorityBg = const Color(0xFFF1F5F9);
        priorityTextColor = const Color(0xFF64748B);
        break;
    }

    // Clean Timing Pill Properties
    Color timingBg;
    Color timingTextColor;
    IconData timingIcon;
    String timingText = task.timeLabel;

    if (isCompleted) {
      timingBg = const Color(0xFFF0FDF4);
      timingTextColor = const Color(0xFF16A34A);
      timingIcon = LucideIcons.checkCheck;
    } else if (isCancelled) {
      timingBg = const Color(0xFFF1F5F9);
      timingTextColor = const Color(0xFF64748B);
      timingIcon = LucideIcons.ban;
      timingText = 'Cancelled';
    } else if (task.isOverdue) {
      timingBg = const Color(0xFFFEE2E2);
      timingTextColor = const Color(0xFFDC2626);
      timingIcon = LucideIcons.alertTriangle;
    } else if (task.isDueToday) {
      timingBg = const Color(0xFFFFFBEB);
      timingTextColor = const Color(0xFFD97706);
      timingIcon = LucideIcons.calendar;
    } else {
      timingBg = const Color(0xFFEFF6FF);
      timingTextColor = const Color(0xFF2563EB);
      timingIcon = LucideIcons.clock;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('task_card_${task.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row: Checkbox, Title, Priority Pill, 3-dot Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkbox
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: InkWell(
                        key: ValueKey('task_toggle_${task.id}'),
                        onTap: onToggleComplete,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isCompleted
                                  ? AppColors.primary
                                  : const Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                          ),
                          child: isCompleted
                              ? const Icon(
                                  Icons.check,
                                  size: 15,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isCompleted
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF0F172A),
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Priority Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: priorityBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.priority.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: priorityTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),

                    // 3-dot Action Menu
                    SizedBox(
                      width: 28,
                      height: 24,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_vert,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'details':
                              onTap();
                              break;
                            case 'edit':
                              if (onEdit != null) {
                                onEdit!();
                              } else {
                                onTap();
                              }
                              break;
                            case 'toggle':
                              onToggleComplete();
                              break;
                            case 'cancel':
                              if (onCancel != null) onCancel!();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'details',
                            child: Row(
                              children: [
                                Icon(LucideIcons.eye, size: 16, color: Color(0xFF475569)),
                                SizedBox(width: 10),
                                Text('View details', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(LucideIcons.pencil, size: 16, color: Color(0xFF475569)),
                                SizedBox(width: 10),
                                Text('Edit task', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  isCompleted ? LucideIcons.rotateCcw : LucideIcons.checkCheck,
                                  size: 16,
                                  color: const Color(0xFF475569),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isCompleted ? 'Reopen task' : 'Mark as complete',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          if (!isCancelled)
                            const PopupMenuItem(
                              value: 'cancel',
                              child: Row(
                                children: [
                                  Icon(LucideIcons.ban, size: 16, color: AppColors.error),
                                  SizedBox(width: 10),
                                  Text(
                                    'Cancel task',
                                    style: TextStyle(fontSize: 13, color: AppColors.error),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Context Row (Deal / Mandate / Location / Buyer)
                Padding(
                  padding: const EdgeInsets.only(left: 34, top: 4),
                  child: _buildContextRow(),
                ),

                // Notes Snippet
                if (task.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 34, top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            LucideIcons.fileText,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            task.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Timing Pill Badge
                Padding(
                  padding: const EdgeInsets.only(left: 34, top: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: timingBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(timingIcon, size: 12, color: timingTextColor),
                        const SizedBox(width: 5),
                        Text(
                          timingText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: timingTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContextRow() {
    IconData icon = LucideIcons.bookmark;
    String text = '';

    if (task.linkedRecord != null) {
      final lr = task.linkedRecord!;
      if (lr.type == LinkedRecordType.deal) {
        icon = LucideIcons.building2;
        final ref = lr.reference;
        final name = task.contactName ?? lr.title;
        text = 'Deal $ref${name.isNotEmpty ? ' · $name' : ''}';
      } else if (lr.type == LinkedRecordType.requirement) {
        icon = LucideIcons.layers;
        final ref = lr.reference;
        final name = task.contactName ?? lr.title;
        text = 'Buyer Mandate $ref${name.isNotEmpty ? ' · $name' : ''}';
      } else if (lr.type == LinkedRecordType.offer) {
        icon = LucideIcons.package;
        final ref = lr.reference;
        final name = task.contactName ?? lr.title;
        text = 'Seller Offer $ref${name.isNotEmpty ? ' · $name' : ''}';
      } else if (lr.type == LinkedRecordType.invoice) {
        icon = LucideIcons.fileSpreadsheet;
        final ref = lr.reference;
        final name = task.contactName ?? lr.title;
        text = 'Invoice $ref${name.isNotEmpty ? ' · $name' : ''}';
      } else {
        icon = lr.type.icon;
        final ref = lr.reference;
        final name = task.contactName ?? lr.title;
        text = '$ref${name.isNotEmpty ? ' · $name' : ''}';
      }
    } else if (task.contactName != null && task.contactName!.isNotEmpty) {
      icon = LucideIcons.users;
      text = '${task.category.label} · ${task.contactName}';
    } else {
      icon = LucideIcons.bookmark;
      text = task.category.label;
    }

    // Special location pattern check (e.g. Mandi Yard)
    if (task.title.contains('Kota Mandi Yard')) {
      text = 'Kota Mandi Yard';
      icon = LucideIcons.mapPin;
    }

    return Row(
      children: [
        Icon(icon, size: 13, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
