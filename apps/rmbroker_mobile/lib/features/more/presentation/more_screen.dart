import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/broker_user.dart';

/// More tools, language toggle, and broker settings screen.
class MoreScreen extends StatelessWidget {
  final AuthRepository? authRepository;

  const MoreScreen({super.key, this.authRepository});

  @override
  Widget build(BuildContext context) {
    final authRepo = authRepository ?? AuthRepository();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('More Tools & Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Dynamic Profile Card
          FutureBuilder<BrokerUser?>(
            future: authRepo.getCurrentBroker(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              final name = user?.fullName.isNotEmpty == true
                  ? user!.fullName
                  : 'Authorized Broker Desk';
              final role = (user?.role ?? 'Broker').toUpperCase();
              final email = user?.email.isNotEmpty == true
                  ? user!.email
                  : 'Jaipur Commodity Exchange Hub';

              final initials = name
                  .split(' ')
                  .where((part) => part.isNotEmpty)
                  .take(2)
                  .map((part) => part[0].toUpperCase())
                  .join();

              return AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        initials.isNotEmpty ? initials : 'BR',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimaryLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  role,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
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
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Tools List
          AppCard(
            padding: EdgeInsets.zero,
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                ListTile(
                  leading: const Icon(
                    LucideIcons.globe,
                    color: AppColors.primary,
                  ),
                  title: const Text('Language / भाषा'),
                  subtitle: const Text('English & हिन्दी'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Language parity active: English & Hindi',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    LucideIcons.indianRupee,
                    color: AppColors.primary,
                  ),
                  title: const Text('Brokerage & Commission Ledger'),
                  subtitle: const Text('Track earnings, invoicing & payments'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => context.push('/commission'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    LucideIcons.fileSpreadsheet,
                    color: AppColors.primary,
                  ),
                  title: const Text('Commission Invoices & Statements'),
                  subtitle: const Text('Issue invoices, statements & reconciliation'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => context.push('/invoices'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    LucideIcons.checkSquare,
                    color: AppColors.primary,
                  ),
                  title: const Text('Broker Tasks & Follow-ups'),
                  subtitle: const Text('Track action items, priorities & business follow-ups'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => context.push('/tasks'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    LucideIcons.bell,
                    color: AppColors.primary,
                  ),
                  title: const Text('Notifications & Activity Center'),
                  subtitle: const Text('Operational alerts, mandates, deals & invoices'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => context.push('/notifications'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    LucideIcons.shieldCheck,
                    color: AppColors.primary,
                  ),
                  title: const Text('Security & Access Logs'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    LucideIcons.fileText,
                    color: AppColors.primary,
                  ),
                  title: const Text('Audit Trails & Reports'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    LucideIcons.info,
                    color: AppColors.primary,
                  ),
                  title: const Text('Fiduciary Disclaimer'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Broker Fiduciary Boundary'),
                        content: const Text(
                          '${AppConfig.fiduciaryNoticeEn}\n\n${AppConfig.fiduciaryNoticeHi}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Understood'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

          // Logout Button
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.errorBackground),
            ),
            tileColor: AppColors.errorBackground.withValues(alpha: 0.4),
            leading: const Icon(LucideIcons.logOut, color: AppColors.error),
            title: const Text(
              'Sign Out from Desk',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
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
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
