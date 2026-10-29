import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';

/// "More" tab hosting secondary destinations moved out of the bottom bar.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildTile(
            context,
            key: const Key('more-messages'),
            icon: LucideIcons.messagesSquare,
            title: 'Messages',
            subtitle: 'Your conversations with brokers.',
            onTap: () => context.push('/chats'),
          ),
          const SizedBox(height: 12),
          _buildTile(
            context,
            key: const Key('more-nutrition'),
            icon: LucideIcons.leaf,
            title: context.tr(Tr.navNutrition),
            subtitle: 'Explore feed ingredients and post nutrition-based requirements.',
            onTap: () => context.push('/nutrition'),
          ),
          const SizedBox(height: 12),
          _buildTile(
            context,
            key: const Key('more-profile'),
            icon: LucideIcons.user,
            title: context.tr(Tr.navProfile),
            subtitle: 'Profile, language and display settings.',
            onTap: () => context.push('/profile'),
          ),
          const SizedBox(height: 12),
          _buildTile(
            context,
            key: const Key('more-gst-verification'),
            icon: LucideIcons.badgeCheck,
            title: 'GST Verification',
            subtitle: 'Verification status and GST certificate upload.',
            onTap: () => context.push('/gst-verification'),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return AppCard(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: AppColors.textSecondaryLight,
          ),
        ],
      ),
    );
  }
}
