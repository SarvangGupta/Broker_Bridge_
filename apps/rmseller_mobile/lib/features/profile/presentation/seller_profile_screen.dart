import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../authentication/data/auth_repository.dart';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({super.key});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final SecureStorageService _storage = SecureStorageService();
  final AuthRepository _authRepository = AuthRepository();

  String _fullName = 'Seller Lead';
  String _email = 'seller@demo.com';
  String _companyName = 'Bikaner Agro Processing Ltd';
  String _companyGst = '08AAAAA0000A1Z5';
  String _role = 'seller';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final name = await _storage.getUserFullName();
    final email = await _storage.getUserEmail();
    final comp = await _storage.getCompanyName();
    final gst = await _storage.getCompanyGst();
    final role = await _storage.getUserRole();

    if (!mounted) return;
    setState(() {
      _fullName = name ?? 'Seller Lead';
      _email = email ?? 'seller@demo.com';
      _companyName = comp ?? 'Bikaner Agro Processing Ltd';
      _companyGst = gst ?? '08AAAAA0000A1Z5';
      _role = role ?? 'seller';
      _isLoading = false;
    });
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of the RMSeller desk?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authRepository.signOut();
      AppRouter.authNotifier.setUnauthenticated();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Seller Profile & Mandi Desk'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enterprise Entity Card
          AppCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primaryContainer,
                  child: const Icon(LucideIcons.store, size: 36, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(_companyName, style: AppTypography.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(_fullName, style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(LucideIcons.shieldCheck, size: 14, color: AppColors.success),
                      SizedBox(width: 6),
                      Text(
                        'Verified Seller Enterprise',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Business Details
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Business & Tax Registration', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 12),
                _buildInfoRow('GSTIN:', _companyGst),
                const SizedBox(height: 8),
                _buildInfoRow('Registered Email:', _email),
                const SizedBox(height: 8),
                _buildInfoRow('Enterprise Role:', _role.toUpperCase()),
                const SizedBox(height: 8),
                _buildInfoRow('Primary Mandi Hub:', 'Bikaner Krishi Upaj Mandi'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Operating Guidelines
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trading Desk Regulations', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                const Text(
                  '1. All commodity sales are mediated exclusively through authorized regional brokers.\n'
                  '2. Direct buyer communications and directory searches are prohibited under counterparty shield policies.\n'
                  '3. Sellers are responsible for physical loading readiness at registered warehouse locations.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sign Out Action
          AppButton(
            label: 'Sign Out of Seller Desk',
            icon: LucideIcons.logOut,
            variant: ButtonVariant.danger,
            onPressed: _handleSignOut,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }
}
