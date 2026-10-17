import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Semantic status badge for requirements, offers, deals, and verification states.
class StatusBadge extends StatelessWidget {
  final String status;
  final bool isLive;

  const StatusBadge({super.key, required this.status, this.isLive = false});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    final lower = status.toLowerCase();
    if (lower.contains('finalized') ||
        lower.contains('confirmed') ||
        lower.contains('fulfilled') ||
        lower.contains('verified') ||
        lower == 'live' ||
        lower == 'active') {
      bg = AppColors.successBackground;
      fg = AppColors.success;
    } else if (lower.contains('negotiat') ||
        lower.contains('matching') ||
        lower.contains('allocated') ||
        lower.contains('reserved') ||
        lower.contains('open')) {
      bg = AppColors.warningBackground;
      fg = AppColors.warning;
    } else if (lower.contains('cancel') ||
        lower.contains('expired') ||
        lower.contains('unavail') ||
        lower.contains('dispute') ||
        lower.contains('error')) {
      bg = AppColors.errorBackground;
      fg = AppColors.error;
    } else {
      bg = AppColors.infoBackground;
      fg = AppColors.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
          ],
          Text(
            status,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
