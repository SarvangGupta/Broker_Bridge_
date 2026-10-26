import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';

/// "More" tab: entry point to Profile, Settings, Reports and Help & Support.
class SellerMoreScreen extends StatelessWidget {
  const SellerMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          _MoreMenuTile(
            key: const Key('more_menu_profile'),
            icon: LucideIcons.user,
            color: AppColors.primary,
            title: 'Profile',
            subtitle: 'View and edit your business profile',
            onTap: () => context.go('/more/profile'),
          ),
          _MoreMenuTile(
            key: const Key('more_menu_settings'),
            icon: LucideIcons.settings,
            color: AppColors.info,
            title: 'Settings',
            subtitle: 'Theme, language, font size, accessibility',
            onTap: () => context.push('/settings'),
          ),
          _MoreMenuTile(
            key: const Key('more_menu_reports'),
            icon: LucideIcons.barChart3,
            color: Colors.purple.shade400,
            title: 'Reports',
            subtitle: 'Sales history and statements',
            onTap: () => context.go('/more/reports'),
          ),
          _MoreMenuTile(
            key: const Key('more_menu_help'),
            icon: LucideIcons.helpCircle,
            color: AppColors.success,
            title: 'Help & Support',
            subtitle: 'FAQs, contact support, app guide',
            onTap: () => context.push('/help'),
          ),
        ],
      ),
    );
  }
}

class _MoreMenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MoreMenuTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: AppColors.textMutedLight,
            ),
          ],
        ),
      ),
    );
  }
}
