import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/preferences/app_settings_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/buyer_profile_repository.dart';
import '../data/gst_draft_repository.dart';
import '../data/gst_verification_repository.dart';
import '../data/warehouse_repository.dart';
import '../domain/buyer_profile.dart';
import '../domain/company_warehouse.dart';
import '../domain/gst_certificate_data.dart';

/// Profile & Settings hub: cohesive, modern business profile experience covering
/// personal identity, registered business details, GST verification with draft resumption,
/// operational warehouses/unloading locations, and application settings.
class ProfileSettingsScreen extends ConsumerStatefulWidget {
  final BuyerProfileRepository? repository;
  final AuthRepository? authRepository;
  final GstVerificationRepository? gstRepository;
  final GstDraftRepository? draftRepository;
  final WarehouseRepository? warehouseRepository;

  const ProfileSettingsScreen({
    super.key,
    this.repository,
    this.authRepository,
    this.gstRepository,
    this.draftRepository,
    this.warehouseRepository,
  });

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  late final BuyerProfileRepository _repo;
  late final AuthRepository _authRepo;
  late final GstVerificationRepository _gstRepo;
  late final GstDraftRepository _draftRepo;
  late final WarehouseRepository _warehouseRepo;

  BuyerProfile? _profile;
  GstVerificationState? _gstState;
  GstDraft? _draft;
  List<CompanyWarehouse> _warehouses = [];
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _gstLoading = true;
  bool _gstLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? BuyerProfileRepository();
    _authRepo = widget.authRepository ?? AuthRepository();
    _gstRepo = widget.gstRepository ?? GstVerificationRepository();
    _draftRepo = widget.draftRepository ?? GstDraftRepository();
    _warehouseRepo = widget.warehouseRepository ?? WarehouseRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
      _gstLoading = true;
      _gstLoadFailed = false;
    });

    BuyerProfile? profile;
    try {
      profile = await _repo.getProfile();
    } catch (e) {
      debugPrint('Profile summary load failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
      return;
    }

    GstVerificationState? gstState;
    bool gstFailed = false;
    try {
      gstState = await _gstRepo.loadStatus();
    } catch (e) {
      debugPrint('GST verification status load failed: $e');
      gstFailed = true;
    }

    GstDraft? draft;
    List<CompanyWarehouse> warehouses = [];
    final companyId = profile.companyId;
    if (companyId != null && companyId.isNotEmpty) {
      try {
        draft = await _draftRepo.getDraft(
          companyId: companyId,
          userId: profile.id,
        );
      } catch (e) {
        debugPrint('GST draft check failed: $e');
      }

      try {
        warehouses = await _warehouseRepo.getWarehouses(companyId);
      } catch (e) {
        debugPrint('Warehouses load failed: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _gstState = gstState;
      _draft = draft;
      _warehouses = warehouses;
      _isLoading = false;
      _gstLoading = false;
      _gstLoadFailed = gstFailed;
    });
  }

  Future<void> _openEditProfile() async {
    await context.push('/settings/profile');
    if (mounted) _load();
  }

  Future<void> _openGstVerification({bool resumeDraft = false}) async {
    final query = resumeDraft ? '?resumeDraft=true' : '';
    await context.push(
      '/gst-verification$query',
      extra: {'resumeDraft': resumeDraft},
    );
    if (mounted) _load();
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          ctx.tr(Tr.signOutTitle),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          ctx.tr(Tr.signOutBody),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr(Tr.commonCancel)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(ctx.tr(Tr.signOutConfirm)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authRepo.signOut();
      AppRouter.authNotifier.setUnauthenticated();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(context.tr(Tr.titleProfileSettings)),
        actions: [
          IconButton(
            tooltip: context.tr(Tr.commonRetry),
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Section 1: Personal Profile
              _buildPersonalSection(),
              const SizedBox(height: 12),

              // Section 2: Business Profile (when profile loaded)
              if (_profile != null) ...[
                _buildBusinessSection(),
                const SizedBox(height: 12),
              ],

              // Section 3: GST Verification Card (when profile loaded)
              if (_profile != null) ...[
                _buildGstCard(),
                const SizedBox(height: 12),
              ],

              // Section 4: Warehouses and Unloading Locations Summary
              if (_profile != null && _warehouses.isNotEmpty) ...[
                _buildWarehousesSection(),
                const SizedBox(height: 12),
              ],

              // Section 5: Profile & App Settings Actions
              _buildSettingsSection(),
              const SizedBox(height: 12),

              // Sign Out
              AppCard(
                padding: EdgeInsets.zero,
                child: _tile(
                  key: const Key('settings-sign-out'),
                  icon: LucideIcons.logOut,
                  title: context.tr(Tr.hubSignOut),
                  color: AppColors.error,
                  onTap: _handleSignOut,
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'RMBuyer Mobile v1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMutedLight,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Section 1: Personal Profile (Avatar, Full Name, Mobile, Email, Edit Action)
  Widget _buildPersonalSection() {
    if (_isLoading) {
      return const AppCard(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    final profile = _profile;
    if (_loadFailed || profile == null) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(LucideIcons.cloudOff, size: 20, color: AppColors.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr(Tr.profileLoadError),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ),
            TextButton(
              key: const Key('settings-profile-retry'),
              onPressed: _load,
              child: Text(context.tr(Tr.commonRetry)),
            ),
          ],
        ),
      );
    }

    final name = profile.name.isEmpty
        ? context.tr(Tr.commonNotProvided)
        : profile.name;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            child: Text(
              profile.name.isNotEmpty
                  ? profile.name.characters.first.toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
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
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                if (profile.email != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    profile.email!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (profile.mobile != null && profile.mobile!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    profile.mobile!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton.icon(
            key: const Key('settings-edit-profile-action'),
            icon: const Icon(LucideIcons.pencil, size: 14),
            label: Text(context.tr(Tr.hubEditProfile)),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.primary,
            ),
            onPressed: _openEditProfile,
          ),
        ],
      ),
    );
  }

  /// Section 2: Business Profile (Legal name, Trade name, Constitution, Address, State/PIN, GSTIN)
  Widget _buildBusinessSection() {
    if (_profile == null) return const SizedBox.shrink();
    final profile = _profile!;
    final record = _gstState?.record;
    final draft = _draft;
    final isFromDraft = record == null && draft != null;

    final companyName = profile.companyName ??
        (isFromDraft ? (draft.values[GstField.tradeName] ?? draft.values[GstField.legalName]) : null) ??
        record?.tradeName ??
        record?.legalName;
    final legalName = record?.legalName ?? (isFromDraft ? draft.values[GstField.legalName] : null);
    final tradeName = record?.tradeName ?? (isFromDraft ? draft.values[GstField.tradeName] : null);
    final constitution = record?.constitution ?? (isFromDraft ? draft.values[GstField.constitution] : null);
    final address = record?.principalAddress ?? (isFromDraft ? draft.values[GstField.address] : null);
    final pin = record?.pinCode ?? (isFromDraft ? draft.values[GstField.pinCode] : null);
    final gstin = profile.companyGst ?? record?.gstin ?? (isFromDraft ? draft.values[GstField.gstin] : null);

    final hasCompleteDetails = legalName != null && gstin != null && address != null;
    final hasPartialDetails = !hasCompleteDetails && (companyName != null || gstin != null);

    final statusText = record?.status == GstVerificationStatus.approved
        ? 'GST Verified'
        : record?.status == GstVerificationStatus.pending
            ? 'Pending Review'
            : record?.status == GstVerificationStatus.rejected
                ? 'Needs Review'
                : isFromDraft
                    ? 'Draft in Progress'
                    : hasCompleteDetails
                        ? 'Complete'
                        : hasPartialDetails
                            ? 'Partial Details'
                            : 'Details Missing';
    final statusColor = record?.status == GstVerificationStatus.approved || (!isFromDraft && hasCompleteDetails)
        ? AppColors.success
        : isFromDraft || record?.status == GstVerificationStatus.pending || hasPartialDetails
            ? AppColors.warning
            : record?.status == GstVerificationStatus.rejected
                ? AppColors.error
                : AppColors.textMutedLight;
    final statusBg = record?.status == GstVerificationStatus.approved || (!isFromDraft && hasCompleteDetails)
        ? AppColors.successBackground
        : isFromDraft || record?.status == GstVerificationStatus.pending || hasPartialDetails
            ? AppColors.warningBackground
            : record?.status == GstVerificationStatus.rejected
                ? AppColors.errorBackground
                : AppColors.borderLight;

    return AppCard(
      key: const Key('settings-business-profile-card'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.building2, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Business Profile',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _detailRow('Business Name', companyName),
          if (legalName != null && legalName != companyName)
            _detailRow('Legal Name', legalName),
          if (tradeName != null && tradeName != companyName)
            _detailRow('Trade Name', tradeName),
          if (constitution != null)
            _detailRow('Constitution', constitution),
          if (address != null)
            _detailRow('Address', address),
          if (pin != null)
            _detailRow('PIN', pin),
          if (gstin != null)
            _detailRow('GSTIN', gstin),

          if (isFromDraft) ...[
            const SizedBox(height: 6),
            const Text(
              'Details above are from your saved unsubmitted draft. Tap Continue Draft below to submit for Admin verification.',
              style: TextStyle(fontSize: 11, color: AppColors.warning),
            ),
          ] else if (!hasCompleteDetails) ...[
            const SizedBox(height: 6),
            const Text(
              'Complete GST verification to register your verified business legal details.',
              style: TextStyle(fontSize: 11, color: AppColors.textMutedLight),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section 3: GST Verification Card (Verified, Pending, Rejected, Draft Saved, Not Verified)
  Widget _buildGstCard() {
    if (_profile == null) return const SizedBox.shrink();

    if (_gstLoading) {
      return const AppCard(
        key: Key('settings-gst-loading'),
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }

    if (_gstLoadFailed) {
      return AppCard(
        key: const Key('settings-gst-card-error'),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(LucideIcons.triangleAlert, size: 20, color: AppColors.error),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'GST verification status could not be loaded.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ),
            TextButton(
              key: const Key('settings-gst-retry'),
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final state = _gstState;
    final status = state?.status ?? GstVerificationStatus.notSubmitted;
    final hasDraft = _draft != null &&
        status != GstVerificationStatus.approved &&
        status != GstVerificationStatus.pending;

    final (badgeLabel, badgeColor, badgeBg, desc, actionLabel) = switch (status) {
      GstVerificationStatus.approved => (
        'Verified',
        AppColors.success,
        AppColors.successBackground,
        'Your business GST certificate is verified.',
        'View Verified GST Details',
      ),
      GstVerificationStatus.pending => (
        'Pending',
        AppColors.warning,
        AppColors.warningBackground,
        'Submitted — Awaiting Admin verification.',
        'View Verification Status',
      ),
      GstVerificationStatus.rejected when hasDraft => (
        'Draft Saved',
        AppColors.warning,
        AppColors.warningBackground,
        'Draft saved locally on this device (${DateFormat('dd/MM/yyyy HH:mm').format(_draft!.savedAt.toLocal())}). Not yet submitted.',
        'Continue Draft',
      ),
      GstVerificationStatus.rejected => (
        'Rejected',
        AppColors.error,
        AppColors.errorBackground,
        state?.record?.rejectionReason != null
            ? 'Reason: ${state!.record!.rejectionReason}'
            : 'Your GST submission was rejected.',
        'Resubmit GST Certificate',
      ),
      _ when hasDraft => (
        'Draft Saved',
        AppColors.warning,
        AppColors.warningBackground,
        'Draft saved locally on this device (${DateFormat('dd/MM/yyyy HH:mm').format(_draft!.savedAt.toLocal())}). Not yet submitted.',
        'Continue Draft',
      ),
      _ => (
        'Not Verified',
        AppColors.textSecondaryLight,
        AppColors.borderLight,
        'No GST certificate submitted.',
        'Start Verification',
      ),
    };

    final badgeKey = switch (status) {
      GstVerificationStatus.approved => const Key('settings-gst-verified-badge'),
      GstVerificationStatus.pending => const Key('settings-gst-pending-badge'),
      GstVerificationStatus.rejected when hasDraft => const Key('settings-gst-draft-badge'),
      GstVerificationStatus.rejected => const Key('settings-gst-rejected-badge'),
      _ when hasDraft => const Key('settings-gst-draft-badge'),
      _ => const Key('settings-gst-not-verified-badge'),
    };

    final gstin = _profile?.companyGst ?? state?.record?.gstin;

    return AppCard(
      key: const Key('settings-gst-card'),
      onTap: () => _openGstVerification(resumeDraft: hasDraft),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.badgeCheck, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'GST Verification',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const Spacer(),
              Container(
                key: badgeKey,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          if (gstin != null && gstin.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'GSTIN: $gstin',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            desc,
            key: const Key('settings-gst-description'),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryLight,
            ),
          ),
          if (state?.hasUnbackedLegacyFlag == true) ...[
            const SizedBox(height: 6),
            const Text(
              'Your company carries an unbacked legacy flag; official GST verification is required.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                actionLabel,
                key: const Key('settings-gst-action-label'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                LucideIcons.chevronRight,
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Section 4: Warehouses and Unloading Locations
  Widget _buildWarehousesSection() {
    final activeCount = _warehouses.where((w) => w.isActive).length;
    final primaryWarehouse =
        _warehouses.where((w) => w.isActive).firstOrNull;

    return AppCard(
      key: const Key('settings-warehouses-card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.warehouse, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Warehouses & Unloading',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: activeCount > 0
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$activeCount Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: activeCount > 0 ? AppColors.primary : AppColors.textMutedLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_warehouses.isEmpty) ...[
            const Text(
              'No unloading locations registered yet. Add your warehouse or plant location so sellers and brokers know where to deliver.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ] else ...[
            Text(
              primaryWarehouse != null
                  ? 'Main Depot: ${primaryWarehouse.name}${primaryWarehouse.pinCode != null ? " (${primaryWarehouse.pinCode})" : ""}'
                  : '$activeCount active unloading location(s) configured.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimaryLight,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _tile(
            key: const Key('settings-warehouses'),
            icon: LucideIcons.mapPin,
            title: 'Manage Warehouses',
            subtitle: 'View, add, or configure unloading depots',
            onTap: () => context.push('/settings/warehouses'),
          ),
        ],
      ),
    );
  }

  /// Section 5: App Settings (Edit Profile, Warehouses, Language, Display)
  Widget _buildSettingsSection() {
    final language = ref.watch(appSettingsProvider).languagePref;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _tile(
            key: const Key('settings-edit-profile'),
            icon: LucideIcons.userPen,
            title: context.tr(Tr.hubEditProfile),
            subtitle: context.tr(Tr.hubEditProfileSub),
            onTap: _openEditProfile,
          ),
          const Divider(height: 1),
          _tile(
            key: const Key('settings-warehouses'),
            icon: LucideIcons.warehouse,
            title: 'Warehouses & Unloading',
            subtitle: 'Manage operational unloading sites',
            onTap: () => context.push('/settings/warehouses'),
          ),
          const Divider(height: 1),
          _tile(
            key: const Key('settings-language'),
            icon: LucideIcons.languages,
            title: context.tr(Tr.hubLanguage),
            subtitle: language.displayName,
            onTap: () => context.push('/settings/language'),
          ),
          const Divider(height: 1),
          _tile(
            key: const Key('settings-display'),
            icon: LucideIcons.sunMoon,
            title: context.tr(Tr.hubDisplay),
            subtitle: context.tr(Tr.hubDisplaySub),
            onTap: () => context.push('/settings/display'),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required Key key,
    required IconData icon,
    required String title,
    String? subtitle,
    Color? color,
    required VoidCallback onTap,
  }) {
    final fg = color ?? AppColors.textPrimaryLight;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        key: key,
        minTileHeight: 52,
        leading: Icon(icon, size: 20, color: color ?? AppColors.primary),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
              ),
        trailing: color == null
            ? const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.textMutedLight,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
