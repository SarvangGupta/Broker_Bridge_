import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/directory_contact.dart';

/// Horizontal KPI summary metrics bar for the counterparty directory.
class DirectoryKpiBar extends StatelessWidget {
  final DirectorySummaryStats stats;
  final bool isCompact;

  const DirectoryKpiBar({
    super.key,
    required this.stats,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildKpiChip(
            label: 'Total Counterparties',
            value: stats.totalContacts.toString(),
            icon: LucideIcons.users,
            color: AppColors.primaryNavy,
          ),
          const SizedBox(width: 8),
          _buildKpiChip(
            label: 'Active Buyers',
            value: stats.buyersCount.toString(),
            icon: LucideIcons.shoppingBag,
            color: const Color(0xFF1E3A8A), // Blue
          ),
          const SizedBox(width: 8),
          _buildKpiChip(
            label: 'Active Sellers',
            value: stats.sellersCount.toString(),
            icon: LucideIcons.store,
            color: const Color(0xFF0D9488), // Teal/Emerald
          ),
          const SizedBox(width: 8),
          _buildKpiChip(
            label: 'Active Mandates',
            value: stats.activeMandatesCount.toString(),
            icon: LucideIcons.layers,
            color: const Color(0xFFD97706), // Amber
          ),
        ],
      ),
    );
  }

  Widget _buildKpiChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
