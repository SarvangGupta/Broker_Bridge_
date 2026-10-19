import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';

/// Priority levels for broker tasks and business follow-ups.
enum TaskPriority {
  low('Low', AppColors.textSecondaryLight, AppColors.backgroundLight),
  normal('Normal', AppColors.info, AppColors.infoBackground),
  high('High', AppColors.warning, AppColors.warningBackground),
  urgent('Urgent', AppColors.error, AppColors.errorBackground);

  final String label;
  final Color color;
  final Color backgroundColor;

  const TaskPriority(this.label, this.color, this.backgroundColor);

  static TaskPriority fromString(String? value) {
    if (value == null) return TaskPriority.normal;
    switch (value.trim().toLowerCase()) {
      case 'low':
        return TaskPriority.low;
      case 'medium':
      case 'normal':
        return TaskPriority.normal;
      case 'high':
        return TaskPriority.high;
      case 'urgent':
      case 'critical':
        return TaskPriority.urgent;
      default:
        return TaskPriority.normal;
    }
  }

  /// Backend string representation (compatible with Drizzle schema text column).
  String toBackendString() {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.normal:
        return 'Normal';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }
}
