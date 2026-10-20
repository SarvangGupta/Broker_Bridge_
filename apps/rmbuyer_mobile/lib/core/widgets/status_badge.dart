import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// Clean semantic chip for requirements and deals status display.
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final (backgroundColor, textColor) = _resolveColors(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  (Color, Color) _resolveColors(String s) {
    final lower = s.toLowerCase().trim();
    if (lower.contains('open') || lower.contains('active')) {
      return (AppColors.infoBackground, AppColors.info);
    }
    if (lower.contains('negotiat') || lower.contains('propos') || lower.contains('pending')) {
      return (AppColors.warningBackground, AppColors.warning);
    }
    if (lower.contains('fulfilled') || lower.contains('closed') || lower.contains('confirmed') || lower.contains('booked')) {
      return (AppColors.successBackground, AppColors.success);
    }
    if (lower.contains('cancel') || lower.contains('reject') || lower.contains('dispute')) {
      return (AppColors.errorBackground, AppColors.error);
    }
    return (AppColors.borderLight, AppColors.textSecondaryLight);
  }
}
