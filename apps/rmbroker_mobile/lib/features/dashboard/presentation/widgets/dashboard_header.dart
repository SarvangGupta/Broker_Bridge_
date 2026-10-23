import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'package:rmbroker_mobile/core/preferences/app_settings_provider.dart';
import 'package:rmbroker_mobile/core/widgets/confirmation_dialog.dart';
import 'package:rmbroker_mobile/core/widgets/status_badge.dart';
import 'package:rmbroker_mobile/features/authentication/domain/broker_user.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/widgets/notification_badge.dart';

/// Top branding bar and profile access header for RMBroker Dashboard.
class DashboardHeader extends ConsumerWidget implements PreferredSizeWidget {
  final BrokerUser? broker;
  final Future<void> Function()? onSignOut;

  const DashboardHeader({super.key, this.broker, this.onSignOut});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4);

  void _showProfileModal(BuildContext context) {
    final name = broker?.fullName.isNotEmpty == true
        ? broker!.fullName
        : 'Authorized Broker';
    final role = (broker?.role ?? 'Broker').toUpperCase();
    final email = broker?.email.isNotEmpty == true
        ? broker!.email
        : 'broker@rmbroker.in';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppColors.surfaceLight,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        name
                            .split(' ')
                            .where((s) => s.isNotEmpty)
                            .take(2)
                            .map((s) => s[0].toUpperCase())
                            .join(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: AppColors.borderLight),
                const SizedBox(height: 4),

                // Desk Information Row
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(
                    LucideIcons.mapPin,
                    color: AppColors.textSecondaryLight,
                    size: 18,
                  ),
                  title: const Text(
                    'Jaipur Mandi Commodity Exchange',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: const Text(
                    'Active Trading Desk',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),

                // Profile link
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(
                    LucideIcons.userCheck,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  title: const Text(
                    'My Broker Profile',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: const Text(
                    'View & edit credentials, commodities & mandi locations',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: const Icon(LucideIcons.chevronRight, size: 16),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    context.push('/profile');
                  },
                ),

                // Market Price Broadcast link
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(
                    LucideIcons.radio,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  title: const Text(
                    'Market Price Broadcast',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: const Text(
                    'Broadcast latest verified seller prices to associated buyers',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: const Icon(LucideIcons.chevronRight, size: 16),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    context.push('/broadcast/market-price');
                  },
                ),

                // Broadcast Price History link
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(
                    LucideIcons.history,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  title: const Text(
                    'Broadcast Price History',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: const Text(
                    'Audit sent prices, buyer recipients & delivery logs',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: const Icon(LucideIcons.chevronRight, size: 16),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    context.push('/broadcast/history');
                  },
                ),

                // Settings link
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(
                    LucideIcons.settings,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  title: const Text(
                    'Desk Settings & Preferences',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: const Text(
                    'Theme, language, eye-protection & label modes',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: const Icon(LucideIcons.chevronRight, size: 16),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    context.push('/settings');
                  },
                ),

                // Icon-Only Asterisk Mode quick toggle inside modal
                Consumer(
                  builder: (context, modalRef, _) {
                    final settings = modalRef.watch(appSettingsProvider);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '*',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      title: const Text(
                        'Asterisk (*) Icon-Only Mode',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      subtitle: Text(
                        settings.iconOnlyMode ? 'Labels hidden' : 'Labels visible',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      trailing: Switch(
                        value: settings.iconOnlyMode,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) {
                          modalRef
                              .read(appSettingsProvider.notifier)
                              .setIconOnlyMode(val);
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(height: 4),
                const Divider(color: AppColors.borderLight),
                const SizedBox(height: 10),

                // Sign Out action
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(LucideIcons.logOut, size: 18),
                    label: const Text(
                      'Sign Out from Desk',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () async {
                      Navigator.pop(bottomSheetContext);
                      final confirmed = await ConfirmationDialog.show(
                        context,
                        title: 'Sign Out',
                        message:
                            'Are you sure you want to end your active broker session?',
                        confirmLabel: 'Sign Out',
                        isDestructive: true,
                      );

                      if (confirmed == true && context.mounted) {
                        if (onSignOut != null) {
                          await onSignOut!();
                        }
                        if (context.mounted) {
                          context.go('/login');
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final settings = ref.watch(appSettingsProvider);

    final initials =
        (broker?.fullName.isNotEmpty == true ? broker!.fullName : 'BB')
            .split(' ')
            .where((s) => s.isNotEmpty)
            .take(2)
            .map((s) => s[0].toUpperCase())
            .join();

    return AppBar(
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'BB',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'RMBroker',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              Text(
                'COMMODITY DESK',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        const StatusBadge(status: 'LIVE', isLive: true),
        // Asterisk (*) global icon-only label toggle button
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: settings.iconOnlyMode ? 'Show labels (*)' : 'Hide labels (*)',
          icon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: settings.iconOnlyMode
                  ? AppColors.primary
                  : AppColors.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '*',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: settings.iconOnlyMode ? Colors.white : AppColors.primary,
              ),
            ),
          ),
          onPressed: () => ref.read(appSettingsProvider.notifier).toggleIconOnlyMode(),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Global Search',
          icon: const Icon(LucideIcons.search, size: 20),
          onPressed: () => context.push('/search'),
        ),
        NotificationBadge(
          count: unreadCount,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Desk Notifications',
            icon: const Icon(LucideIcons.bell, size: 20),
            onPressed: () => context.push('/notifications'),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showProfileModal(context),
          child: Padding(
            padding: const EdgeInsets.only(right: 14, left: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryContainer.withValues(
                alpha: 0.5,
              ),
              child: Text(
                initials.isNotEmpty ? initials : 'B',
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
