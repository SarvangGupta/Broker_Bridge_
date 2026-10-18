import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Reusable badge counter overlay for notification entry points (e.g. AppBar bell).
class NotificationBadge extends StatelessWidget {
  final int count;
  final Widget child;

  const NotificationBadge({
    super.key,
    required this.count,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;

    final displayCount = count > 99 ? '99+' : '$count';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: 6,
          right: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.error.withValues(alpha: 0.35),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Text(
                displayCount,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
