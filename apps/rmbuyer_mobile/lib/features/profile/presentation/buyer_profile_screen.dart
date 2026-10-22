import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/buyer_user.dart';
import 'widgets/app_settings_section.dart';

/// Buyer profile and account settings screen.
/// Surfaces buyer company info and counterparty shield status with zero seller exposure.
class BuyerProfileScreen extends StatefulWidget {
  final BuyerUser? user;
  final AuthRepository? authRepository;

  const BuyerProfileScreen({super.key, this.user, this.authRepository});

  @override
  State<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends State<BuyerProfileScreen> {
  late final AuthRepository _authRepo;
  BuyerUser? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authRepo = widget.authRepository ?? AuthRepository();
    if (widget.user != null) {
      _user = widget.user;
      _isLoading = false;
    } else {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final user = await _authRepo.getCurrentBuyer();
      if (!mounted) return;
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Confirm Sign Out',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to end your RMBuyer procurement session?',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authRepo.signOut();
      AppRouter.authNotifier.setUnauthenticated();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = _user?.fullName ?? 'Buyer Procurement Lead';
    final email = _user?.email ?? 'buyer@company.com';
    final companyName = _user?.companyName ?? 'Apex Grain Processors Pvt Ltd';
    final companyGst = _user?.companyGst ?? '08AABCA1234F1Z8';

    return Scaffold(
      appBar: AppBar(title: const Text('Buyer Profile & Settings')),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // User Identity Card
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                fullName.isNotEmpty
                                    ? fullName[0].toUpperCase()
                                    : 'B',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'BUYER PROCUREMENT ADMIN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Company Organization Profile
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.building2,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Procuring Enterprise',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimaryLight,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successBackground,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'GST VERIFIED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(),
                          const SizedBox(height: 12),
                          _buildInfoRow('Enterprise Name', companyName),
                          _buildInfoRow('Registered GSTIN', companyGst),
                          _buildInfoRow(
                            'Business Type',
                            'Commodity Processor & Manufacturer',
                          ),
                          _buildInfoRow('Enterprise Trust Score', '98 / 100'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Counterparty Isolation Shield Notice
                    AppCard(
                      color: AppColors.primaryContainer.withValues(alpha: 0.6),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                LucideIcons.shieldCheck,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Counterparty Isolation Shield',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'RMBuyer guarantees strict fiduciary separation. All seller communications, warehouse visits, and negotiation counter-proposals are verified through licensed mandi brokers. Seller direct contact details remain confidential to prevent off-platform transaction exposure.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryDark,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Application Preferences (Theme, Language, Font Size, Accessibility)
                    const AppSettingsSection(),
                    const SizedBox(height: 16),

                    // Environment & App Specs
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ecosystem Configuration',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            'Application',
                            '${AppConfig.appName} (${AppConfig.appVersion})',
                          ),
                          _buildInfoRow(
                            'Environment',
                            'Shared RMBroker Ecosystem',
                          ),
                          _buildInfoRow(
                            'Mobile Engine',
                            'Flutter 3.47.6 • Dart 3.13.5',
                          ),
                          _buildInfoRow(
                            'Database Ref',
                            'Shared Supabase DBaaS (imztlkvkxzeaekxvmcfe)',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sign Out Button
                    AppButton(
                      label: 'Sign Out of RMBuyer',
                      onPressed: _handleLogout,
                      variant: AppButtonVariant.outline,
                      icon: LucideIcons.logOut,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
