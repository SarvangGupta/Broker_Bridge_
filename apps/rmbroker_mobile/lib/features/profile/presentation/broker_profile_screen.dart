import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/preferences/app_settings_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/profile_repository.dart';
import '../domain/broker_profile.dart';

/// Riverpod provider for ProfileRepository.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

/// Riverpod provider for loading and caching the broker profile.
final brokerProfileProvider =
    FutureProvider.autoDispose<BrokerProfile>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  final result = await repo.getProfile();
  if (result is ProfileSuccess<BrokerProfile>) {
    return result.data;
  } else if (result is ProfileUnauthorized) {
    throw Exception('Authentication session expired. Please sign in.');
  } else if (result is ProfileError) {
    throw Exception((result as ProfileError).message);
  }
  throw Exception('Unable to load broker profile');
});

/// Authoritative Broker Profile Screen.
/// Supports viewing verified credentials and editing permitted operational details.
class BrokerProfileScreen extends ConsumerStatefulWidget {
  const BrokerProfileScreen({super.key});

  @override
  ConsumerState<BrokerProfileScreen> createState() =>
      _BrokerProfileScreenState();
}

class _BrokerProfileScreenState extends ConsumerState<BrokerProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _brokerageController;
  late TextEditingController _addressController;
  late TextEditingController _locationsController;
  late TextEditingController _commoditiesController;
  late TextEditingController _regionsController;

  final _formKey = GlobalKey<FormState>();
  BrokerProfile? _currentProfile;
  String? _selectedPhotoPath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _mobileController = TextEditingController();
    _emailController = TextEditingController();
    _brokerageController = TextEditingController();
    _addressController = TextEditingController();
    _locationsController = TextEditingController();
    _commoditiesController = TextEditingController();
    _regionsController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _brokerageController.dispose();
    _addressController.dispose();
    _locationsController.dispose();
    _commoditiesController.dispose();
    _regionsController.dispose();
    super.dispose();
  }

  void _populateFields(BrokerProfile profile) {
    _currentProfile = profile;
    _nameController.text = profile.fullName;
    _mobileController.text = profile.mobile;
    _emailController.text = profile.email;
    _brokerageController.text = profile.brokerageName;
    _addressController.text = profile.businessAddress;
    _locationsController.text = profile.operatingLocations;
    _commoditiesController.text = profile.commoditiesHandled;
    _regionsController.text = profile.operatingRegions;
    _selectedPhotoPath = profile.profilePhotoPath;
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _errorMessage = null;
      if (_currentProfile != null) {
        _populateFields(_currentProfile!);
      }
    });
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return; // Prevent duplicate submission
    _errorMessage = null;
    _successMessage = null;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_currentProfile == null) return;

    final updated = _currentProfile!.copyWith(
      fullName: _nameController.text.trim(),
      mobile: _mobileController.text.trim(),
      email: _emailController.text.trim(),
      brokerageName: _brokerageController.text.trim(),
      businessAddress: _addressController.text.trim(),
      operatingLocations: _locationsController.text.trim(),
      commoditiesHandled: _commoditiesController.text.trim(),
      operatingRegions: _regionsController.text.trim(),
      profilePhotoPath: _selectedPhotoPath,
    );

    final validationErr = updated.validate();
    if (validationErr != null) {
      setState(() => _errorMessage = validationErr);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(profileRepositoryProvider);
      final result = await repo.updateProfile(updated);

      if (mounted) {
        if (result is ProfileSuccess<BrokerProfile>) {
          setState(() {
            _isSaving = false;
            _isEditing = false;
            _currentProfile = result.data;
            _populateFields(result.data);
            _successMessage = 'Profile updated and synchronized successfully';
          });
          ref.invalidate(brokerProfileProvider);
        } else if (result is ProfileError) {
          setState(() {
            _isSaving = false;
            _errorMessage = (result as ProfileError).message;
          });
        } else if (result is ProfileUnauthorized) {
          setState(() {
            _isSaving = false;
            _errorMessage = 'Session expired. Please sign in again.';
          });
          context.go('/login');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to update profile: $e';
        });
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile Photo Options',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(LucideIcons.camera, color: AppColors.primary),
                title: const Text('Use Standard Desk Monogram'),
                subtitle: const Text('Render crisp initials on trading badge'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedPhotoPath = null;
                  });
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.image, color: AppColors.primary),
                title: const Text('Set Verified Desk Avatar'),
                subtitle: const Text('Apply registered broker identity image'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedPhotoPath = 'assets/icons/broker_verified_badge.png';
                  });
                },
              ),
              if (_selectedPhotoPath != null)
                ListTile(
                  leading: const Icon(LucideIcons.trash2, color: AppColors.error),
                  title: const Text('Remove Custom Photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedPhotoPath = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(brokerProfileProvider);
    final settings = ref.watch(appSettingsProvider);
    final isIconOnly = settings.iconOnlyMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Broker Profile'),
        actions: [
          // Asterisk icon-only toggle
          IconButton(
            tooltip: isIconOnly ? 'Show labels (*)' : 'Hide labels (*)',
            icon: Text(
              '*',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isIconOnly ? AppColors.primary : AppColors.textSecondaryLight,
              ),
            ),
            onPressed: () =>
                ref.read(appSettingsProvider.notifier).toggleIconOnlyMode(),
          ),
          if (!_isEditing)
            IconButton(
              tooltip: 'Edit Profile',
              icon: const Icon(LucideIcons.edit2, size: 20),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _errorMessage = null;
                  _successMessage = null;
                });
              },
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertTriangle, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  'Error loading profile',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(brokerProfileProvider),
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (profile) {
          if (_currentProfile == null) {
            _populateFields(profile);
          }

          final initials = profile.fullName
              .split(' ')
              .where((s) => s.isNotEmpty)
              .take(2)
              .map((s) => s[0].toUpperCase())
              .join();

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Success / Error alerts
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_successMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.successBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Top Badge & Avatar Card
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.primaryContainer,
                            backgroundImage: (_selectedPhotoPath != null &&
                                    File(_selectedPhotoPath!).existsSync())
                                ? FileImage(File(_selectedPhotoPath!))
                                : null,
                            child: (_selectedPhotoPath == null ||
                                    !File(_selectedPhotoPath!).existsSync())
                                ? Text(
                                    initials.isNotEmpty ? initials : 'BR',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryDark,
                                    ),
                                  )
                                : null,
                          ),
                          if (_isEditing)
                            InkWell(
                              onTap: _showPhotoOptions,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  LucideIcons.camera,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.brokerageName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              profile.role,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          StatusBadge(
                            status: profile.accountStatus.toUpperCase(),
                            isLive: profile.accountStatus == 'Active',
                          ),
                          if (profile.isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.successBackground,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.success.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.shieldCheck, size: 12, color: AppColors.success),
                                  SizedBox(width: 4),
                                  Text(
                                    'Verified Desk',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Read-Only Security & Credentials Section
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(LucideIcons.lock, size: 16, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Protected Desk Identifiers',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      _buildReadOnlyTile(
                        label: 'Account ID',
                        value: profile.id,
                        copyable: true,
                      ),
                      _buildReadOnlyTile(
                        label: 'Desk Role',
                        value: profile.role,
                      ),
                      _buildReadOnlyTile(
                        label: 'Mandi Verification',
                        value: profile.isVerified ? 'Authoritative Verified' : 'Pending',
                      ),
                      _buildReadOnlyTile(
                        label: 'Trading Trust Score',
                        value: '${profile.trustScore} / 100',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Editable Fields Section
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isEditing ? LucideIcons.edit3 : LucideIcons.user,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isEditing ? 'Edit Broker Details' : 'Broker Desk Information',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Full Name
                      _buildField(
                        label: 'Full Name *',
                        controller: _nameController,
                        enabled: _isEditing,
                        icon: LucideIcons.user,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Full name is required';
                          }
                          if (val.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Mobile Number
                      _buildField(
                        label: 'Registered Mobile Number *',
                        controller: _mobileController,
                        enabled: _isEditing,
                        icon: LucideIcons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Mobile number is required';
                          }
                          final digits = val.replaceAll(RegExp(r'\D'), '');
                          if (digits.length < 10) {
                            return 'Enter a valid 10-digit mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Email Address
                      _buildField(
                        label: 'Official Email *',
                        controller: _emailController,
                        enabled: _isEditing,
                        icon: LucideIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!val.contains('@') || !val.contains('.')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Brokerage / Firm Name
                      _buildField(
                        label: 'Brokerage / Trading Firm Name *',
                        controller: _brokerageController,
                        enabled: _isEditing,
                        icon: LucideIcons.building,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Brokerage firm name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Business Address
                      _buildField(
                        label: 'Office / Mandi Address',
                        controller: _addressController,
                        enabled: _isEditing,
                        icon: LucideIcons.mapPin,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),

                      // Operating Locations / Mandis
                      _buildField(
                        label: 'Operating Mandis / Trading Locations',
                        controller: _locationsController,
                        enabled: _isEditing,
                        icon: LucideIcons.navigation,
                        hint: 'e.g. Jaipur Mandi, Kota, Alwar, Bikaner',
                      ),
                      const SizedBox(height: 12),

                      // Commodities Handled
                      _buildField(
                        label: 'Commodities & Raw Materials Handled',
                        controller: _commoditiesController,
                        enabled: _isEditing,
                        icon: LucideIcons.layers,
                        hint: 'e.g. Mustard Seed, Soybean, Wheat, Chana',
                      ),
                      const SizedBox(height: 12),

                      // Operating Regions
                      _buildField(
                        label: 'Operating Regions / States',
                        controller: _regionsController,
                        enabled: _isEditing,
                        icon: LucideIcons.globe,
                        hint: 'e.g. Rajasthan, Madhya Pradesh, Gujarat',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Edit Mode Action Buttons
                if (_isEditing)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _cancelEdit,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: AppColors.borderLight),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Profile',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                        _errorMessage = null;
                        _successMessage = null;
                      });
                    },
                    icon: const Icon(LucideIcons.edit2, size: 16),
                    label: const Text(
                      'Edit Profile Information',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReadOnlyTile({
    required String label,
    required String value,
    bool copyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              if (copyable) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(LucideIcons.copy, size: 12, color: AppColors.primary),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            fontSize: 13,
            color: enabled ? AppColors.textPrimaryLight : AppColors.textSecondaryLight,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 16, color: AppColors.textSecondaryLight),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
