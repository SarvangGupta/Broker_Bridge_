import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../data/auth_repository.dart';

class AccessDeniedScreen extends StatelessWidget {
  final String email;
  final String role;
  final String? message;

  const AccessDeniedScreen({
    super.key,
    required this.email,
    required this.role,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.errorBackground,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.shieldAlert,
                    size: 56,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Access Restricted',
                  style: AppTypography.displayMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message ??
                      'Your account ($email) with role "$role" is not authorized to access the RMSeller Supply Desk. Access is strictly limited to authorized commodity sellers.',
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: 'Sign Out & Return to Login',
                  onPressed: () async {
                    await AuthRepository().signOut();
                    AppRouter.authNotifier.setUnauthenticated();
                  },
                  icon: LucideIcons.logOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
