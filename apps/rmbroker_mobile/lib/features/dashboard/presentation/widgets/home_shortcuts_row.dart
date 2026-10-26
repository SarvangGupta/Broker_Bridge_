import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/dashboard_state.dart';

/// Home: three compact shortcuts (Summary · Actions · Recent Activity) that
/// open the full metrics, the full action list and the activity feed.
class HomeShortcutsRow extends StatelessWidget {
  final DashboardState state;

  const HomeShortcutsRow({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final activeDeals = state.kpiCards.where((c) => c.id == 'active_deals').firstOrNull;
    final actions = state.quickActions.where((a) => a.isImplemented).length;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ShortcutCard(
              key: const ValueKey('home_shortcut_summary'),
              icon: LucideIcons.chartColumn,
              color: const Color(0xFF16A34A),
              title: 'Summary',
              value: activeDeals?.value ?? '—',
              caption: 'Active deals',
              onTap: () => context.go('/dashboard/summary'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ShortcutCard(
              key: const ValueKey('home_shortcut_actions'),
              icon: LucideIcons.zap,
              color: const Color(0xFF2563EB),
              title: 'Actions',
              value: '$actions',
              caption: 'Quick actions',
              onTap: () => context.go('/dashboard/actions'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ShortcutCard(
              key: const ValueKey('home_shortcut_activity'),
              icon: LucideIcons.clock,
              color: const Color(0xFF7C3AED),
              title: 'Recent Activity',
              value: '${state.recentActivities.length}',
              caption: 'Latest updates',
              onTap: () => context.push('/notifications'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String caption;
  final VoidCallback onTap;

  const _ShortcutCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.caption,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title: $value $caption',
      excludeSemantics: true,
      child: Material(
        color: color.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withValues(alpha: 0.18)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 2, 10),
              child: Row(
                children: [
                  // Icon with its label underneath (label scales, never splits a word)
                  SizedBox(
                    width: 50,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                          child: Icon(icon, size: 18, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            title.replaceFirst(' ', '\n'),
                            key: ValueKey('home_shortcut_label_$title'),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryNavy,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ),
                        Text(
                          caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight, height: 1.2),
                        ),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textSecondaryLight),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
