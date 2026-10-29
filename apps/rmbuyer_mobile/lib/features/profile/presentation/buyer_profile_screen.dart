import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../l10n/app_localizations.dart';
import '../data/buyer_profile_repository.dart';
import '../data/gst_draft_repository.dart';
import '../data/gst_verification_repository.dart';
import '../domain/buyer_profile.dart';
import '../domain/gst_certificate_data.dart';

/// Edit Profile: structured, cohesive business profile editor.
/// The buyer's personal name and mobile number are editable and saved to `public.users`.
/// Company business details are protected and governed by GST verification.
/// Direct shortcuts provide access to GST verification and warehouse management.
class BuyerProfileScreen extends StatefulWidget {
  final BuyerProfileRepository? repository;
  /// Defaults to the source selected for this build ([defaultGstVerificationSource]).
  final GstVerificationRecordSource? gstRecords;
  final GstDraftRepository? draftRepository;

  const BuyerProfileScreen({
    super.key,
    this.repository,
    this.gstRecords,
    this.draftRepository,
  });

  @override
  State<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends State<BuyerProfileScreen> {
  late final BuyerProfileRepository _repo;
  late final GstDraftRepository _draftRepo;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();

  BuyerProfile? _profile;
  GstVerificationRecord? _gstRecord;
  GstVerificationStatus? _gstStatus;
  GstDraft? _draft;
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _isSaving = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? BuyerProfileRepository();
    _draftRepo = widget.draftRepository ?? GstDraftRepository();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final profile = await _repo.getProfile();
      GstVerificationStatus? gstStatus;
      GstVerificationRecord? gstRecord;
      GstDraft? draft;
      final companyId = profile.companyId;
      if (companyId != null && companyId.isNotEmpty) {
        try {
          final records = widget.gstRecords ?? defaultGstVerificationSource();
          final record = await records.latestFor(companyId);
          gstRecord = record;
          gstStatus = record?.status ?? GstVerificationStatus.notSubmitted;
        } catch (e) {
          debugPrint('GST verification status load failed: ${e.runtimeType}');
        }

        try {
          draft = await _draftRepo.getDraft(
            companyId: companyId,
            userId: profile.id,
          );
        } catch (e) {
          debugPrint('GST draft load failed: $e');
        }
      }
      if (!mounted) return;
      _nameController.text = profile.name;
      _mobileController.text = profile.mobile ?? '';
      setState(() {
        _profile = profile;
        _gstRecord = gstRecord;
        _gstStatus = gstStatus;
        _draft = draft;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Profile load failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  /// Only fields whose value differs from the saved profile.
  Map<String, Object?> _changes() {
    final profile = _profile;
    if (profile == null) return const {};
    final changes = <String, Object?>{};
    final name = _nameController.text.trim();
    if (name != profile.name) changes['name'] = name;

    final mobileText = _mobileController.text.trim();
    final mobile = mobileText.isEmpty
        ? null
        : BuyerProfileValidation.normalizeMobile(mobileText);
    if (mobile != profile.mobile) changes['mobile'] = mobile;
    return changes;
  }

  bool get _isDirty => _changes().isNotEmpty;

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _saveFailed = false);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final changes = _changes();
    final messenger = ScaffoldMessenger.of(context);
    if (changes.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr(Tr.profNoChanges))),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final saved = await _repo.updateProfile(_profile!, changes);
      if (!mounted) return;
      _nameController.text = saved.name;
      _mobileController.text = saved.mobile ?? '';
      setState(() {
        _profile = saved;
        _isSaving = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.tr(Tr.profSaveSuccess)),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('Profile save failed: $e');
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveFailed = true;
      });
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr(Tr.profUnsavedTitle)),
        content: Text(ctx.tr(Tr.profUnsavedBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr(Tr.commonKeepEditing)),
          ),
          TextButton(
            key: const Key('profile-discard'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.tr(Tr.commonDiscard)),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isLoading || _loadFailed || !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard() && mounted) {
          _nameController.text = _profile?.name ?? '';
          _mobileController.text = _profile?.mobile ?? '';
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(title: Text(context.tr(Tr.titleEditProfile))),
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    final profile = _profile;
    if (_loadFailed || profile == null) {
      return AppErrorState(
        message: context.tr(Tr.profileLoadError),
        onRetry: _load,
      );
    }

    return Form(
      key: _formKey,
      onChanged: () => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_saveFailed) ...[
            Container(
              key: const Key('profile-save-error'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.circleAlert,
                    size: 18,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr(Tr.profSaveError),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Section 1: Personal Details
          _section(
            icon: LucideIcons.user,
            title: context.tr(Tr.profPersonal),
            children: [
              _label(context.tr(Tr.profName)),
              TextFormField(
                key: const Key('profile-name-field'),
                controller: _nameController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.words,
                maxLength: BuyerProfileValidation.nameMax,
                decoration: const InputDecoration(counterText: ''),
                validator: (v) =>
                    switch (BuyerProfileValidation.validateName(v ?? '')) {
                      NameError.required => context.tr(Tr.valNameRequired),
                      NameError.length => context.tr(Tr.valNameLength),
                      null => null,
                    },
              ),
              const SizedBox(height: 14),
              _label(context.tr(Tr.profMobile)),
              TextFormField(
                key: const Key('profile-mobile-field'),
                controller: _mobileController,
                enabled: !_isSaving,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: context.tr(Tr.profMobileHint),
                  prefixIcon: const Icon(LucideIcons.phone, size: 18),
                ),
                validator: (v) {
                  final text = v?.trim() ?? '';
                  if (text.isEmpty) return null;
                  return BuyerProfileValidation.normalizeMobile(text) == null
                      ? context.tr(Tr.valMobileInvalid)
                      : null;
                },
              ),
              const SizedBox(height: 14),
              _readOnly(
                context.tr(Tr.profEmail),
                profile.email,
                key: const Key('profile-email'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 2: Company Details (Protected & Read-Only)
          Builder(
            builder: (context) {
              final isFromDraft = _gstRecord == null && _draft != null;
              final effectiveLegalName = _gstRecord?.legalName ?? (isFromDraft ? _draft!.values[GstField.legalName] : null);
              final effectiveTradeName = _gstRecord?.tradeName ?? (isFromDraft ? _draft!.values[GstField.tradeName] : null);
              final effectiveConstitution = _gstRecord?.constitution ?? (isFromDraft ? _draft!.values[GstField.constitution] : null);
              final effectiveAddress = _gstRecord?.principalAddress ?? (isFromDraft ? _draft!.values[GstField.address] : null);
              final effectivePin = _gstRecord?.pinCode ?? (isFromDraft ? _draft!.values[GstField.pinCode] : null);
              final effectiveCompanyName = profile.companyName ?? (isFromDraft ? (effectiveTradeName ?? effectiveLegalName) : null);

              return _section(
                icon: LucideIcons.building2,
                title: context.tr(Tr.profCompany),
                children: [
                  _readOnly(context.tr(Tr.profCompanyName), effectiveCompanyName),
                  if (effectiveLegalName != null && effectiveLegalName != effectiveCompanyName)
                    _readOnly('Legal Business Name', effectiveLegalName),
                  if (effectiveTradeName != null && effectiveTradeName != effectiveCompanyName)
                    _readOnly('Trade Name', effectiveTradeName),
                  if (effectiveConstitution != null)
                    _readOnly('Constitution', effectiveConstitution),
                  if (effectiveAddress != null)
                    _readOnly('Principal Address', effectiveAddress),
                  if (effectivePin != null)
                    _readOnly('PIN Code', effectivePin),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        LucideIcons.lock,
                        size: 14,
                        color: AppColors.textMutedLight,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isFromDraft
                              ? 'Details shown above are restored from your saved local draft. Submit your certificate for Admin verification to finalize your business details.'
                              : 'Company legal and business details are populated through verified GST certificates and cannot be directly edited here.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isFromDraft ? AppColors.warning : AppColors.textMutedLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Section 3: GST Details and Verification Shortcut
          Builder(
            builder: (context) {
              final isFromDraft = _gstRecord == null && _draft != null;
              final effectiveGstin = profile.companyGst ?? _gstRecord?.gstin ?? (isFromDraft ? _draft!.values[GstField.gstin] : null);
              final verificationStatusText = switch (_gstStatus) {
                GstVerificationStatus.approved => context.tr(Tr.profVerified),
                GstVerificationStatus.pending => 'Pending Verification',
                GstVerificationStatus.rejected => 'Rejected',
                _ when isFromDraft => 'Draft Saved (Unsubmitted)',
                null => null,
                _ => context.tr(Tr.profNotVerified),
              };

              return _section(
                icon: LucideIcons.badgeCheck,
                title: 'GST Details & Verification',
                children: [
                  _readOnly(
                    context.tr(Tr.profGstin),
                    effectiveGstin,
                  ),
                  _readOnly(
                    context.tr(Tr.profVerification),
                    verificationStatusText,
                    key: const Key('profile-verification'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('profile-gst-action-btn'),
                    icon: Icon(
                      isFromDraft ? LucideIcons.playCircle : LucideIcons.shieldCheck,
                      size: 16,
                    ),
                    label: Text(
                      _gstStatus == GstVerificationStatus.approved
                          ? 'View GST Verification'
                          : isFromDraft
                              ? 'Continue GST Draft'
                              : 'Verify Business GST',
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      await context.push(
                        isFromDraft
                            ? '/gst-verification?resumeDraft=true'
                            : '/gst-verification',
                        extra: {'resumeDraft': isFromDraft},
                      );
                      if (mounted) _load();
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Section 4: Warehouse Management Shortcut
          _section(
            icon: LucideIcons.warehouse,
            title: 'Operational Warehouses',
            children: [
              const Text(
                'Manage multiple unloading locations, depot addresses, and set your primary delivery site for trade contracts.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('profile-warehouses-action-btn'),
                icon: const Icon(LucideIcons.mapPin, size: 16),
                label: const Text('Manage Warehouses & Depots'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => context.push('/settings/warehouses'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 5: Account and Security Notes
          _section(
            icon: LucideIcons.shieldAlert,
            title: context.tr(Tr.profAccount),
            children: [
              _readOnly(
                context.tr(Tr.profRole),
                switch (profile.role) {
                  'buyer' => context.tr(Tr.profRoleBuyer),
                  'admin' => context.tr(Tr.profRoleAdmin),
                  _ => null,
                },
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.shieldCheck,
                    size: 14,
                    color: AppColors.textMutedLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.tr(Tr.profProtectedNote),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMutedLight,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          AppButton(
            key: const Key('profile-save'),
            label: _isSaving
                ? context.tr(Tr.commonSaving)
                : context.tr(Tr.commonSave),
            isLoading: _isSaving,
            icon: LucideIcons.save,
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimaryLight,
      ),
    ),
  );

  Widget _readOnly(String label, String? value, {Key? key}) {
    final shown = value ?? context.tr(Tr.commonNotProvided);
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            shown,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: value == null
                  ? AppColors.textMutedLight
                  : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
