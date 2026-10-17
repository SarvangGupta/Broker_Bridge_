import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'package:rmbroker_mobile/core/widgets/confirmation_dialog.dart';
import 'package:rmbroker_mobile/core/widgets/status_badge.dart';
import 'package:rmbroker_mobile/features/authentication/domain/broker_user.dart';

/// Top branding bar and profile access header for RMBroker Dashboard.
class DashboardHeader extends StatelessWidget implements PreferredSizeWidget {
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

                // Settings link
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(
                    LucideIcons.settings,
                    color: AppColors.textSecondaryLight,
                    size: 18,
                  ),
                  title: const Text(
                    'Desk Settings & Preferences',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    context.go('/more');
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
  Widget build(BuildContext context) {
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
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Global Search',
          icon: const Icon(LucideIcons.search, size: 20),
          onPressed: () => context.push('/search'),
        ),
        IconButton(
          tooltip: 'Desk Notifications',
          icon: const Icon(LucideIcons.bell, size: 20),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications stream active on broker desk'),
                duration: Duration(seconds: 2),
              ),
            );
          },
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
