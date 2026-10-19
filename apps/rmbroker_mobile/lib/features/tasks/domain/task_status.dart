import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';

/// Lifecycle statuses for broker tasks.
enum TaskStatus {
  open('Open', AppColors.primary, AppColors.primaryContainer, LucideIcons.circle),
  inProgress('In Progress', AppColors.info, AppColors.infoBackground, LucideIcons.clock),
  waiting('Waiting', AppColors.warning, AppColors.warningBackground, LucideIcons.hourglass),
  completed('Completed', AppColors.success, AppColors.successBackground, LucideIcons.checkCircle2),
  cancelled('Cancelled', AppColors.textDisabled, AppColors.backgroundLight, LucideIcons.xCircle);

  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData icon;

  const TaskStatus(this.label, this.color, this.backgroundColor, this.icon);

  /// Whether the task is still open and actionable.
  bool get isActive => this == TaskStatus.open || this == TaskStatus.inProgress || this == TaskStatus.waiting;

  /// Whether the task has concluded.
  bool get isClosed => this == TaskStatus.completed || this == TaskStatus.cancelled;

  static TaskStatus fromString(String? value) {
    if (value == null) return TaskStatus.open;
    switch (value.trim().toLowerCase()) {
      case 'open':
      case 'pending':
        return TaskStatus.open;
      case 'in_progress':
      case 'in progress':
      case 'inprogress':
        return TaskStatus.inProgress;
      case 'waiting':
      case 'blocked':
        return TaskStatus.waiting;
      case 'completed':
      case 'done':
        return TaskStatus.completed;
      case 'cancelled':
      case 'canceled':
        return TaskStatus.cancelled;
      default:
        return TaskStatus.open;
    }
  }

  /// Maps to backend crm_tasks status column ('Pending', 'Completed', 'Cancelled', 'In Progress').
  String toBackendString() {
    switch (this) {
      case TaskStatus.open:
        return 'Pending';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.waiting:
        return 'Waiting';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.cancelled:
        return 'Cancelled';
    }
  }
}
