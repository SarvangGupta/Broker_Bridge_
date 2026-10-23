import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/features/dashboard/domain/dashboard_models.dart';

class _ActionVisualTheme {
  final Color bg;
  final Color border;
  final Color iconColor;
  final IconData icon;
  final bool isSolidCircle;

  const _ActionVisualTheme({
    required this.bg,
    required this.border,
    required this.iconColor,
    required this.icon,
    this.isSolidCircle = false,
  });
}

_ActionVisualTheme _resolveActionTheme(String id, IconData fallbackIcon) {
  switch (id) {
    case 'action_post_requirement':
      return const _ActionVisualTheme(
        bg: Color(0xFFE8F8F0),
        border: Color(0xFFBBF7D0),
        iconColor: Color(0xFF16A34A),
        icon: LucideIcons.plus,
        isSolidCircle: true,
      );
    case 'action_add_offer':
      return const _ActionVisualTheme(
        bg: Color(0xFFF3E8FF),
        border: Color(0xFFDDD6FE),
        iconColor: Color(0xFF7C3AED),
        icon: LucideIcons.package,
      );
    case 'action_manage_deals':
      return const _ActionVisualTheme(
        bg: Color(0xFFEFF6FF),
        border: Color(0xFFBFDBFE),
        iconColor: Color(0xFF2563EB),
        icon: Icons.handshake_outlined,
      );
    case 'action_track_dispatch':
      return const _ActionVisualTheme(
        bg: Color(0xFFFFF7ED),
        border: Color(0xFFFED7AA),
        iconColor: Color(0xFFEA580C),
        icon: LucideIcons.truck,
      );
    case 'action_view_earnings':
      return const _ActionVisualTheme(
        bg: Color(0xFFFCE7F3),
        border: Color(0xFFFBCFE8),
        iconColor: Color(0xFFE11D48),
        icon: LucideIcons.indianRupee,
      );
    case 'action_new_dispute':
      return const _ActionVisualTheme(
        bg: Color(0xFFF1F5F9),
        border: Color(0xFFE2E8F0),
        iconColor: Color(0xFF475569),
        icon: LucideIcons.fileText,
      );
    default:
      return _ActionVisualTheme(
        bg: const Color(0xFFF8FAFC),
        border: const Color(0xFFE2E8F0),
        iconColor: const Color(0xFF0F766E),
        icon: fallbackIcon,
      );
  }
}

/// Quick actions section providing direct navigation to active and roadmap desk operations.
class QuickActionsSection extends StatelessWidget {
  final List<BrokerQuickAction> actions;

  const QuickActionsSection({super.key, required this.actions});

  void _onActionTap(BuildContext context, BrokerQuickAction action) {
    if (action.route == '/commission' ||
        action.route.startsWith('/deals/') ||
        action.route == '/orders' ||
        action.route == '/disputes') {
      context.push(action.route);
    } else {
      context.go(action.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            InkWell(
              onTap: () => context.go('/work'),
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Text(
                      'All Actions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 13,
                      color: Color(0xFF0F766E),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: List.generate(actions.length, (index) {
              final action = actions[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index == actions.length - 1 ? 0 : 7,
                ),
                child: _QuickActionCard(
                  action: action,
                  onTap: () => _onActionTap(context, action),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final BrokerQuickAction action;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = _resolveActionTheme(action.id, action.icon);

    return Container(
      width: 66,
      height: 92,
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: style.border,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top: Icon
                if (style.isSolidCircle)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: style.iconColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        style.icon,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 28,
                    child: Center(
                      child: Icon(
                        style.icon,
                        size: 20,
                        color: style.iconColor,
                      ),
                    ),
                  ),

                const SizedBox(height: 5),

                // Action Title
                Text(
                  action.title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    height: 1.15,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                if (action.badge != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    action.badge!,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
