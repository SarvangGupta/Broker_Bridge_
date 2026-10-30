import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'package:rmbroker_mobile/core/widgets/status_badge.dart';
import 'package:rmbroker_mobile/features/authentication/domain/broker_user.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/widgets/notification_badge.dart';

import 'broker_desk_sheet.dart';

/// Top branding bar and profile access header for RMBroker Dashboard.
class DashboardHeader extends ConsumerWidget implements PreferredSizeWidget {
  final BrokerUser? broker;
  final Future<void> Function()? onSignOut;

  const DashboardHeader({super.key, this.broker, this.onSignOut});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    // On very narrow screens the title area cannot fit the LIVE badge beside
    // the four header actions; it is dropped there rather than overflowing.
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final showLiveBadge = !narrow;
    final logoSize = narrow ? 30.0 : 36.0;

    return AppBar(
      titleSpacing: narrow ? 8 : 16,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      backgroundColor: AppColors.surfaceLight,
      title: Row(
        children: [
          // Dark teal rounded logo container with tap to view profile
          InkWell(
            onTap: () => context.push('/profile'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                color: const Color(0xFF134E4A), // Slate/dark teal
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'BB',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: narrow ? 6 : 10),
          // Shrinks (ellipsis) on narrow phones next to the action icons.
          const Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'RMBroker',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'COMMODITY DESK',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          if (showLiveBadge) ...[
            const SizedBox(width: 8),
            const StatusBadge(status: 'LIVE', isLive: true),
          ],
        ],
      ),
      actions: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Global Search',
          icon: const Icon(LucideIcons.search, size: 21, color: Color(0xFF0F172A)),
          onPressed: () => context.push('/search'),
        ),
        NotificationBadge(
          count: unreadCount,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Desk Notifications',
            icon: const Icon(LucideIcons.bell, size: 21, color: Color(0xFF0F172A)),
            onPressed: () => context.push('/notifications'),
          ),
        ),
        // Broker Desk (call / WhatsApp / directory shortcuts), formerly the Home FAB.
        IconButton(
          key: const ValueKey('header_broker_desk_button'),
          visualDensity: VisualDensity.compact,
          tooltip: 'Broker Desk',
          icon: const Icon(LucideIcons.phoneCall, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => BrokerDeskSheet.show(context),
        ),
        // Same destination as the bottom-navigation More tab.
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: IconButton(
            key: const ValueKey('header_more_button'),
            visualDensity: VisualDensity.compact,
            tooltip: 'More',
            icon: const Icon(LucideIcons.ellipsisVertical, size: 22, color: Color(0xFF0F172A)),
            onPressed: () => context.go('/more'),
          ),
        ),
      ],
    );
  }
}
