import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (status.toLowerCase()) {
      case 'open':
      case 'active':
      case 'confirmed':
      case 'ready':
      case 'ready to load':
        bg = AppColors.successBackground;
        fg = AppColors.success;
        break;
      case 'in negotiation':
      case 'negotiation':
      case 'pending':
      case 'draft':
      case 'scheduled':
        bg = AppColors.warningBackground;
        fg = AppColors.warning;
        break;
      case 'dispatched':
      case 'in transit':
      case 'loading':
      case 'partially fulfilled':
        bg = AppColors.infoBackground;
        fg = AppColors.info;
        break;
      case 'cancelled':
      case 'rejected':
      case 'expired':
      case 'blocked':
        bg = AppColors.errorBackground;
        fg = AppColors.error;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
