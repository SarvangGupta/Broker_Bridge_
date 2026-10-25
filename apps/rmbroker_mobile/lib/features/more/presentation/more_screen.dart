import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/broker_user.dart';
import 'widgets/more_menu_tile.dart';

/// More hub: Profile, Tools, Finance and Settings. Each section page lists its
/// items; every item opens its existing screen.
class MoreScreen extends ConsumerWidget {
  final AuthRepository? authRepository;

  const MoreScreen({super.key, this.authRepository});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepo = authRepository ?? AuthRepository();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const MoreSectionHeader(title: 'More', subtitle: 'Tools & account settings'),
            const SizedBox(height: 16),
            FutureBuilder<BrokerUser?>(
              future: authRepo.getCurrentBroker(),
              builder: (context, snapshot) {
                final name = snapshot.data?.fullName.trim() ?? '';
                final initial = name.isNotEmpty ? name[0].toUpperCase() : null;
                return MoreMenuTile(
                  key: const Key('more_profile'),
                  icon: LucideIcons.user,
                  leadingText: initial,
                  tint: MoreTint.green,
                  title: 'Profile',
                  subtitle: 'View and manage your profile',
                  onTap: () => context.push('/profile'),
                );
              },
            ),
            const SizedBox(height: 10),
            MoreMenuTile(
              key: const Key('more_tools'),
              icon: LucideIcons.briefcase,
              tint: MoreTint.green,
              filled: true,
              title: 'Tools',
              subtitle: 'Daily tools to manage your business',
              onTap: () => context.go('/more/tools'),
            ),
            const SizedBox(height: 10),
            MoreMenuTile(
              key: const Key('more_finance'),
              icon: LucideIcons.coins,
              tint: MoreTint.orange,
              filled: true,
              title: 'Finance',
              subtitle: 'Track your earnings, invoicing and payments',
              onTap: () => context.go('/more/finance'),
            ),
            const SizedBox(height: 10),
            MoreMenuTile(
              key: const Key('more_settings'),
              icon: LucideIcons.settings,
              tint: MoreTint.purple,
              filled: true,
              title: 'Settings',
              subtitle: 'App preferences, security and system settings',
              onTap: () => context.go('/more/settings'),
            ),
            const SizedBox(height: 28),
            // Existing session action, kept below the four sections.
            ListTile(
              key: const Key('more_sign_out'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.errorBackground),
              ),
              tileColor: AppColors.errorBackground.withValues(alpha: 0.4),
              leading: const Icon(LucideIcons.logOut, color: AppColors.error),
              title: const Text(
                'Sign Out from Desk',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
              ),
              onTap: () async {
                final confirmed = await ConfirmationDialog.show(
                  context,
                  title: 'Sign Out',
                  message: 'Are you sure you want to end your active broker workstation session?',
                  confirmLabel: 'Sign Out',
                  isDestructive: true,
                );
                if (confirmed == true && context.mounted) {
                  await authRepo.signOut();
                  if (context.mounted) context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
