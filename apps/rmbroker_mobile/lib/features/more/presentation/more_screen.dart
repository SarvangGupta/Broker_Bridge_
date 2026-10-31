import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/broker_user.dart';
import '../../profile/presentation/broker_profile_screen.dart';

/// Redesigned More hub:
/// - Header with mint/teal decorative artwork and subtitle "Your workspace & account"
/// - Dynamic Broker Profile Card with glass-ball avatar, verification badge and View Profile action
/// - Full-width Profile & Messages cards
/// - Side-by-side Tools & Finance cards (responsive)
/// - Full-width Settings card
/// - Dedicated Sign Out section with destructive styling and confirmation
class MoreScreen extends ConsumerWidget {
  final AuthRepository? authRepository;

  const MoreScreen({super.key, this.authRepository});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepo = authRepository ?? AuthRepository();
    final profileAsync = ref.watch(brokerProfileProvider);
    final profile = profileAsync.when(
      data: (p) => p,
      loading: () => null,
      error: (_, __) => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: FutureBuilder<BrokerUser?>(
          future: authRepo.getCurrentBroker(),
          builder: (context, snapshot) {
            final brokerUser = snapshot.data;

            final String fullName = profile?.fullName.isNotEmpty == true
                ? profile!.fullName
                : (brokerUser?.fullName.isNotEmpty == true
                    ? brokerUser!.fullName
                    : 'Varun');

            final String displayName = fullName.trim();
            final String initial = displayName.isNotEmpty
                ? displayName[0].toUpperCase()
                : 'V';

            final bool isVerified = profile?.isVerified ??
                (brokerUser?.isBrokerOrAdmin ?? true);

            final String firmName = profile?.brokerageName.isNotEmpty == true
                ? profile!.brokerageName
                : 'RB Traders Pvt. Ltd.';

            return LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 340;

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // 1. More Page Header with decorative artwork
                    _buildHeader(),
                    const SizedBox(height: 14),

                    // 2. Broker Profile Card
                    _buildBrokerProfileCard(
                      context: context,
                      initial: initial,
                      name: displayName,
                      firmName: firmName,
                      isVerified: isVerified,
                      photoUrl: profile?.profilePhotoPath,
                    ),
                    const SizedBox(height: 12),

                    // 3. Messages Card (Full width)
                    _buildMenuCard(
                      keyName: 'more_messages',
                      icon: LucideIcons.messagesSquare,
                      iconColor: const Color(0xFF7C3AED),
                      iconBgColor: const Color(0xFFF3E8FF),
                      title: 'Messages',
                      subtitle: 'Buyer and seller conversations',
                      onTap: () => context.push('/chats'),
                    ),
                    const SizedBox(height: 10),

                    // 4. Tools & Finance Cards (Side-by-side or stacked on narrow screens)
                    if (isNarrow) ...[
                      _buildToolsCard(context),
                      const SizedBox(height: 10),
                      _buildFinanceCard(context),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildToolsCard(context)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildFinanceCard(context)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),

                    // 5. Settings Card (Full width)
                    _buildMenuCard(
                      keyName: 'more_settings',
                      icon: LucideIcons.settings,
                      iconColor: const Color(0xFF6366F1),
                      iconBgColor: const Color(0xFFEEF2FF),
                      title: 'Settings',
                      subtitle: 'Preferences, security and app settings',
                      onTap: () => context.go('/more/settings'),
                    ),
                    const SizedBox(height: 18),

                    // 6. Sign Out Section
                    _buildSignOutTile(context, authRepo),

                    // Bottom clearance so content is never blocked by floating glass-ball nav bar
                    const SizedBox(height: 96),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'More',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryNavy,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Your workspace & account',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        _HeaderArtwork(),
      ],
    );
  }

  Widget _buildBrokerProfileCard({
    required BuildContext context,
    required String initial,
    required String name,
    required String firmName,
    required bool isVerified,
    String? photoUrl,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const Key('more_broker_identity_card'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/profile'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Glass Ball Avatar with initial
              _buildGlassAvatar(initial: initial, photoUrl: photoUrl),
              const SizedBox(width: 12),

              // Name, firm & verified status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: Color(0xFF16A34A),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      firmName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVerified ? LucideIcons.checkCircle2 : LucideIcons.clock,
                          size: 12,
                          color: isVerified
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isVerified ? 'Verified Broker' : 'Pending Verification',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isVerified
                                ? const Color(0xFF15803D)
                                : const Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // View Profile Action Pill
              Material(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: const Key('more_profile'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/profile'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFBBF7D0).withValues(alpha: 0.8),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View profile',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 14,
                          color: Color(0xFF0F766E),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassAvatar({required String initial, String? photoUrl}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 0.90,
          colors: [
            Color(0xFFCCFBF1), // Soft luminous mint highlight
            Color(0xFF99F6E4), // Pale teal
            Color(0xFF5EEAD4), // Glass mint base
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.20),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Specular glass highlight reflection
          Positioned(
            top: 4,
            left: 9,
            child: Container(
              width: 14,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.all(Radius.elliptical(14, 7)),
              ),
            ),
          ),
          Center(
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F766E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required String keyName,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key(keyName),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(icon, size: 20, color: iconColor),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolsCard(BuildContext context) {
    return Material(
      color: const Color(0xFFF0FDF4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const Key('more_tools'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/more/tools'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFDCFCE7),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF16A34A).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.briefcase,
                        size: 18,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Tools',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Daily business\nutilities',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinanceCard(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const Key('more_finance'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/more/finance'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFEF3C7),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD97706).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.coins,
                        size: 18,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Finance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Earnings, invoices\nand payments',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutTile(BuildContext context, AuthRepository authRepo) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const Key('more_sign_out'),
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final confirmed = await ConfirmationDialog.show(
            context,
            title: 'Sign Out',
            message:
                'Are you sure you want to end your active broker workstation session?',
            confirmLabel: 'Sign Out',
            isDestructive: true,
          );
          if (confirmed == true && context.mounted) {
            await authRepo.signOut();
            if (context.mounted) context.go('/login');
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFEE2E2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(
                LucideIcons.logOut,
                color: Color(0xFFDC2626),
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sign Out from Desk',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: Color(0xFFDC2626),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtle decorative glass artwork with gear and mint organic petals in the top right.
class _HeaderArtwork extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Soft ambient mint glow
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
              ),
            ),
          ),
          // Organic leaf petal left
          Positioned(
            left: 0,
            bottom: 4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF86EFAC).withValues(alpha: 0.45),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
            ),
          ),
          // 3D Glass orb with gear icon
          Positioned(
            right: 6,
            top: 0,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.35, -0.45),
                  radius: 0.90,
                  colors: [
                    Color(0xFFE6FFFA),
                    Color(0xFF99F6E4),
                    Color(0xFF2DD4BF),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.95),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Specular highlight
                  Positioned(
                    top: 4,
                    left: 8,
                    child: Container(
                      width: 12,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: const BorderRadius.all(
                          Radius.elliptical(12, 6),
                        ),
                      ),
                    ),
                  ),
                  const Icon(
                    LucideIcons.settings,
                    size: 20,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
