import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../data/gst_certificate_ocr_service.dart';
import '../data/gst_draft_repository.dart';
import '../data/gst_verification_repository.dart';
import '../domain/gst_certificate_data.dart';

/// Returns the picked image's path, or null when the user cancels.
typedef CertificateImagePicker = Future<String?> Function(ImageSource source);

Future<String?> _pickWithImagePicker(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    imageQuality: 90,
    maxWidth: 2400,
  );
  return file?.path;
}

/// GST Verification: shows the backend verification status and lets an
/// unverified buyer photograph their GST certificate, read it on-device and
/// review the extracted values. Verification status is read only; this screen
/// never writes the company record and never marks the buyer verified.
class GstVerificationScreen extends StatefulWidget {
  final GstVerificationRepository? repository;
  final GstDraftRepository? draftRepository;
  final GstCertificateOcrService ocr;
  final CertificateImagePicker pickImage;
  final bool autoResumeDraft;

  const GstVerificationScreen({
    super.key,
    this.repository,
    this.draftRepository,
    this.ocr = const GstCertificateOcrService(),
    this.pickImage = _pickWithImagePicker,
    this.autoResumeDraft = false,
  });

  @override
  State<GstVerificationScreen> createState() => _GstVerificationScreenState();
}

class _GstVerificationScreenState extends State<GstVerificationScreen> {
  static const _labels = {
    GstField.gstin: 'GSTIN',
    GstField.legalName: 'Legal business name',
    GstField.tradeName: 'Trade name',
    GstField.constitution: 'Constitution of business',
    GstField.address: 'Principal place of business',
    GstField.pinCode: 'PIN code',
    GstField.registrationDate: 'Registration date',
    GstField.registrationType: 'Registration type',
    GstField.validityFrom: 'Valid from',
    GstField.validityTo: 'Valid to',
    GstField.issueDate: 'Certificate issue date',
  };

  late final GstVerificationRepository _repo;
  late final GstDraftRepository _draftRepo;
  final Map<GstField, TextEditingController> _controllers = {
    for (final f in GstField.values) f: TextEditingController(),
  };

  GstVerificationState? _state;
  GstDraft? _activeDraft;
  bool _isLoading = true;
  bool _loadFailed = false;

  String? _imagePath;
  bool _isReading = false;
  String? _ocrError;
  GstCertificateData? _ocr;
  Map<GstField, GstFieldError> _errors = const {};
  bool _submitBlocked = false;
  bool _isSubmitting = false;
  bool _isSavingDraft = false;
  bool _submitted = false;
  String? _submitError;
  bool _identityConfirmed = false;
  bool _identityError = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? GstVerificationRepository();
    _draftRepo = widget.draftRepository ?? GstDraftRepository();
    for (final c in _controllers.values) {
      c.addListener(_onEdited);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onEdited() {
    if (mounted) setState(() => _submitBlocked = false);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final state = await _repo.loadStatus();
      GstDraft? draft;
      final companyId = state.profile.companyId ?? '';
      final userId = state.profile.id;
      if (companyId.isNotEmpty && userId.isNotEmpty) {
        draft = await _draftRepo.getDraft(companyId: companyId, userId: userId);
      }
      if (!mounted) return;
      setState(() {
        _state = state;
        _activeDraft = draft;
        _isLoading = false;
      });
      if (draft != null && widget.autoResumeDraft && _ocr == null) {
        _resumeDraft();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  void _resumeDraft() {
    final draft = _activeDraft;
    if (draft == null) return;
    for (final f in GstField.values) {
      _controllers[f]!.text = draft.values[f] ?? '';
    }

    setState(() {
      _imagePath = (draft.imagePath != null && draft.imagePath!.isNotEmpty)
          ? draft.imagePath
          : null;
      _ocr = GstCertificateData(
        gstin: draft.values[GstField.gstin],
        legalName: draft.values[GstField.legalName],
        tradeName: draft.values[GstField.tradeName],
        constitution: draft.values[GstField.constitution],
        principalAddress: draft.values[GstField.address],
        pinCode: draft.values[GstField.pinCode],
        registrationDate: draft.values[GstField.registrationDate],
        registrationType: draft.values[GstField.registrationType],
        validityFrom: draft.values[GstField.validityFrom],
        validityTo: draft.values[GstField.validityTo],
        issueDate: draft.values[GstField.issueDate],
      );
      _errors = const {};
      _submitBlocked = false;
    });
  }

  Future<void> _discardDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Saved Draft?'),
        content: const Text(
          'This will remove your unsubmitted review draft saved on this device. You will need to upload your certificate again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('gst-confirm-discard-btn'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final state = _state;
      if (state != null) {
        await _draftRepo.clearDraft(
          companyId: state.profile.companyId ?? '',
          userId: state.profile.id,
        );
      }
      if (!mounted) return;
      setState(() {
        _activeDraft = null;
        _imagePath = null;
        _ocr = null;
        for (final c in _controllers.values) {
          c.clear();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft discarded.')),
      );
    }
  }

  Future<void> _saveDraft() async {
    final state = _state;
    if (state == null) return;
    setState(() => _isSavingDraft = true);
    final companyId = state.profile.companyId ?? '';
    final userId = state.profile.id;
    final draft = GstDraft(
      companyId: companyId,
      userId: userId,
      values: _currentValues,
      imagePath: _imagePath,
      savedAt: DateTime.now(),
      editedFields: _editedFields,
    );
    await _draftRepo.saveDraft(draft);
    if (!mounted) return;
    setState(() {
      _activeDraft = draft;
      _isSavingDraft = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Draft saved locally on this device.'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  Future<void> _pick(ImageSource source) async {
    final String? path;
    try {
      path = await widget.pickImage(source);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _ocrError = source == ImageSource.camera
            ? 'The camera could not be opened. Check the camera permission and try again.'
            : 'The gallery could not be opened. Check the photo permission and try again.',
      );
      return;
    }
    if (path == null || !mounted) return;
    setState(() {
      _imagePath = path;
      _isReading = true;
      _ocrError = null;
      _ocr = null;
      _errors = const {};
      _submitBlocked = false;
      // A new certificate needs its own identity confirmation.
      _identityConfirmed = false;
      _identityError = false;
    });
    final result = await widget.ocr.extract(path);
    if (!mounted) return;
    final data = result.isSuccess ? result.data : const GstCertificateData();
    final values = data.toFieldMap();
    for (final f in GstField.values) {
      _controllers[f]!.text = values[f] ?? '';
    }
    setState(() {
      _isReading = false;
      _ocr = data;
      _ocrError = result.errorMessage;
    });
  }

  Map<GstField, String> get _currentValues => {
    for (final f in GstField.values) f: _controllers[f]!.text.trim(),
  };

  /// Fields whose reviewed value differs from what OCR extracted.
  Set<GstField> get _editedFields {
    final original = _ocr?.toFieldMap() ?? const {};
    return {
      for (final f in GstField.values)
        if (_controllers[f]!.text.trim() != (original[f] ?? '')) f,
    };
  }

  Future<void> _submit() async {
    // A second tap while a submission is in flight never sends a duplicate.
    if (_isSubmitting) return;
    final errors = GstSubmissionValidation.validate(_currentValues);
    // A certificate that looks like another business needs explicit confirmation.
    final identityUnconfirmed =
        _identityIssues.isNotEmpty && !_identityConfirmed;
    setState(() {
      _errors = errors;
      _submitError = null;
      _identityError = identityUnconfirmed;
      // Without the secure backend a valid form stops here and nothing is sent.
      _submitBlocked =
          errors.isEmpty && !identityUnconfirmed && !_repo.submissionAvailable;
    });
    final ocr = _ocr;
    final imagePath = _imagePath;
    if (errors.isNotEmpty ||
        identityUnconfirmed ||
        !_repo.submissionAvailable ||
        ocr == null ||
        imagePath == null) {
      return;
    }
    // Exactly the values on screen, including the buyer's edits.
    final draft = GstSubmissionDraft.fromForm(_currentValues, ocr);
    setState(() => _isSubmitting = true);
    try {
      await _repo.submit(draft, imagePath);
      if (!mounted) return;
      if (_state != null) {
        await _draftRepo.clearDraft(
          companyId: _state!.profile.companyId ?? '',
          userId: _state!.profile.id,
        );
      }
      // Success only after the server returned the saved pending record.
      setState(() {
        _activeDraft = null;
        _isSubmitting = false;
        _submitted = true;
        _imagePath = null;
        _ocr = null;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = GstSubmissionException.describe(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('GST Verification'),
        actions: [
          IconButton(
            key: const Key('gst-refresh'),
            tooltip: 'Refresh status',
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: _isLoading && _state == null
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed || _state == null
          ? AppErrorState(
              message: 'Your verification status could not be loaded.',
              onRetry: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  _buildStepProgress(),
                  const SizedBox(height: 16),
                  _statusCard(_state!),
                  if (_activeDraft != null &&
                      (_state!.status == GstVerificationStatus.notSubmitted ||
                          _state!.status == GstVerificationStatus.rejected))
                    _draftBanner(),
                  if (_submitted) ...[
                    const SizedBox(height: 12),
                    Container(
                      key: const Key('gst-submit-success'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.successBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Submitted. The server saved your certificate and details for review.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _savedProfileCard(_state!),
                  if (_state!.status == GstVerificationStatus.notSubmitted ||
                      _state!.status == GstVerificationStatus.rejected) ...[
                    const SizedBox(height: 16),
                    _uploadCard(),
                    if (_isReading) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text('Reading certificate on this device…'),
                      ),
                    ],
                    if (_ocr != null) ...[
                      const SizedBox(height: 16),
                      _reviewCard(),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  int get _currentStep {
    if (_state?.status == GstVerificationStatus.approved ||
        _state?.status == GstVerificationStatus.pending) {
      return 4;
    }
    if (_ocr != null) {
      return 3;
    }
    if (_imagePath != null || _isReading) {
      return 2;
    }
    return 1;
  }

  Widget _buildStepProgress() {
    final cur = _currentStep;
    final steps = [
      (1, 'Upload'),
      (2, 'Extract'),
      (3, 'Review/Draft'),
      (4, 'Status'),
    ];

    return AppCard(
      key: const Key('gst-step-progress'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Verification Progress',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              Text(
                'Step $cur of 4',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 2,
                              color: i == 0
                                  ? Colors.transparent
                                  : (cur >= steps[i].$1
                                      ? AppColors.primary
                                      : AppColors.borderLight),
                            ),
                          ),
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: cur >= steps[i].$1
                                ? AppColors.primary
                                : AppColors.borderLight,
                            child: Text(
                              '${steps[i].$1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: cur >= steps[i].$1
                                    ? Colors.white
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 2,
                              color: i == steps.length - 1
                                  ? Colors.transparent
                                  : (cur > steps[i].$1
                                      ? AppColors.primary
                                      : AppColors.borderLight),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[i].$2,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: cur == steps[i].$1
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: cur >= steps[i].$1
                              ? AppColors.textPrimaryLight
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _draftBanner() {
    final draft = _activeDraft;
    if (draft == null) return const SizedBox.shrink();
    final dateStr =
        DateFormat('dd/MM/yyyy HH:mm').format(draft.savedAt.toLocal());
    return Container(
      key: const Key('gst-draft-banner'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.fileClock, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              const Text(
                'Draft Saved on Device',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'You have an unsubmitted review draft saved locally on this device. You can resume editing or submit for Admin verification.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_ocr == null)
                ElevatedButton.icon(
                  key: const Key('gst-resume-draft-btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  icon: const Icon(LucideIcons.playCircle, size: 14),
                  label: const Text('Resume Draft'),
                  onPressed: _resumeDraft,
                ),
              OutlinedButton.icon(
                key: const Key('gst-discard-draft-btn'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.error,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                icon: const Icon(LucideIcons.trash2, size: 14),
                label: const Text('Discard'),
                onPressed: _discardDraft,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusCard(GstVerificationState state) {
    final (label, detail, color, background, icon) = switch (state.status) {
      GstVerificationStatus.approved => (
        'Verified',
        'Your GST certificate was reviewed and approved.',
        AppColors.success,
        AppColors.successBackground,
        LucideIcons.badgeCheck,
      ),
      GstVerificationStatus.pending => (
        'Pending',
        'Submitted — Awaiting Verification.',
        AppColors.info,
        AppColors.infoBackground,
        LucideIcons.clock,
      ),
      GstVerificationStatus.rejected => (
        'Rejected',
        state.record?.rejectionReason ?? 'Your submission was rejected.',
        AppColors.error,
        AppColors.errorBackground,
        LucideIcons.circleX,
      ),
      GstVerificationStatus.notSubmitted => (
        'Not Verified',
        _repo.submissionAvailable
            ? 'No GST certificate submitted. Upload your GST Registration Certificate (Form GST REG-06) to start verification.'
            : 'No GST certificate submitted. You can read and check your certificate below; online submission is not available yet.',
        AppColors.warning,
        AppColors.warningBackground,
        LucideIcons.shieldAlert,
      ),
      GstVerificationStatus.noCompany => (
        'Not Verified',
        'Your account is not linked to a company yet, so GST verification is not available. Please contact support.',
        AppColors.warning,
        AppColors.warningBackground,
        LucideIcons.shieldAlert,
      ),
    };
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  key: const Key('gst-status-badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(fontWeight: FontWeight.w700, color: color),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detail,
                  key: const Key('gst-status-detail'),
                  style: const TextStyle(color: AppColors.textSecondaryLight),
                ),
                if (state.hasUnbackedLegacyFlag) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Your company account carries an older "verified" mark, but no GST certificate has been submitted or reviewed for it.',
                    key: Key('gst-legacy-flag-note'),
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Details saved on the backend today. OCR results below are separate and
  /// unsaved until a secure submission exists.
  Widget _savedProfileCard(GstVerificationState state) {
    final p = state.profile;
    final rec = state.record;
    final gst = rec?.gstin ?? p.companyGst;
    final derivedState = gst == null
        ? null
        : GstinRules.stateOf(GstinRules.normalize(gst));
    final hasBackendRecord = rec != null &&
        (rec.legalName != null || rec.principalAddress != null);

    Widget row(String label, String? value, String key) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
              value ?? 'Not saved',
              key: Key(key),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
    return AppCard(
      key: const Key('gst-saved-profile'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saved profile details',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          row('Company name', p.companyName, 'gst-saved-company'),
          row('GSTIN', gst, 'gst-saved-gstin'),
          row('State (from GSTIN)', derivedState, 'gst-saved-state'),
          if (hasBackendRecord) ...[
            if (rec.legalName != null)
              row('Legal name', rec.legalName, 'gst-saved-legal-name'),
            if (rec.tradeName != null)
              row('Trade name', rec.tradeName, 'gst-saved-trade-name'),
            if (rec.constitution != null)
              row('Constitution', rec.constitution, 'gst-saved-constitution'),
            if (rec.principalAddress != null)
              row('Principal address', rec.principalAddress, 'gst-saved-address'),
            if (rec.pinCode != null)
              row('PIN code', rec.pinCode, 'gst-saved-pin'),
            if (rec.registrationType != null)
              row('Registration type', rec.registrationType, 'gst-saved-reg-type'),
            if (rec.registrationDate != null)
              row('Registration date', rec.registrationDate, 'gst-saved-reg-date'),
            if (rec.validityFrom != null)
              row('Valid from', rec.validityFrom, 'gst-saved-validity-from'),
            if (rec.validityTo != null)
              row('Valid to', rec.validityTo, 'gst-saved-validity-to'),
            if (rec.issueDate != null)
              row('Issue date', rec.issueDate, 'gst-saved-issue-date'),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'Legal name, trade name, constitution, address, PIN, registration type and dates are not stored by the server yet.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
            ),
          ],
        ],
      ),
    );
  }

  Widget _uploadCard() {
    final hasImage = _imagePath != null && _imagePath!.isNotEmpty;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'GST certificate',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'Photograph the full certificate on a flat surface in good light. The text is read on this device.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
          ),
          if (hasImage) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_imagePath!),
                key: const Key('gst-preview'),
                height: 220,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  height: 80,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.fileWarning, size: 18, color: AppColors.warning),
                      SizedBox(width: 8),
                      Text('Preview unavailable', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const Key('gst-take-photo'),
                  label: hasImage ? 'Retake' : 'Take Photo',
                  icon: LucideIcons.camera,
                  variant: AppButtonVariant.outline,
                  onPressed: _isReading
                      ? null
                      : () => _pick(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  key: const Key('gst-pick-gallery'),
                  label: hasImage ? 'Replace' : 'Gallery',
                  icon: LucideIcons.image,
                  variant: AppButtonVariant.outline,
                  onPressed: _isReading
                      ? null
                      : () => _pick(ImageSource.gallery),
                ),
              ),
            ],
          ),
          if (_ocrError != null) ...[
            const SizedBox(height: 10),
            Text(
              _ocrError!,
              key: const Key('gst-ocr-error'),
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reviewCard() {
    final ocrValues = _ocr!.toFieldMap();
    final edited = _editedFields;
    final gstin = GstinRules.normalize(_controllers[GstField.gstin]!.text);
    final pan = GstinRules.panOf(gstin);
    final state = GstinRules.stateOf(gstin);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Review extracted details',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'Check every value against your certificate and correct anything that was misread.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
          ),
          for (final note in _ocr!.reviewNotes) ...[
            const SizedBox(height: 8),
            Text(
              note,
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
          const SizedBox(height: 8),
          for (final f in GstField.values)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                key: Key('gst-field-${f.name}'),
                controller: _controllers[f],
                maxLines: f == GstField.address ? 3 : 1,
                textCapitalization: f == GstField.gstin
                    ? TextCapitalization.characters
                    : TextCapitalization.none,
                keyboardType: f == GstField.pinCode
                    ? TextInputType.number
                    : null,
                decoration: InputDecoration(
                  labelText:
                      '${_labels[f]}${GstSubmissionValidation.requiredFields.contains(f) ? ' *' : ''}',
                  helperText: _helperFor(f, ocrValues[f], edited.contains(f)),
                  helperStyle: TextStyle(
                    color: ocrValues[f] == null
                        ? AppColors.warning
                        : AppColors.info,
                  ),
                  errorText: _errorText(_errors[f]),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'From GSTIN: PAN ${pan ?? '—'} · State ${state ?? '—'}',
            key: const Key('gst-derived'),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryLight,
            ),
          ),
          ..._identitySection(),
          const SizedBox(height: 16),
          if (!_repo.submissionAvailable) ...[
            const Text(
              'Online submission is not available yet. You can check your details here; nothing is saved or sent.',
              key: Key('gst-submission-unavailable-note'),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('gst-save-draft'),
                  icon: const Icon(LucideIcons.save, size: 16),
                  label: Text(_isSavingDraft ? 'Saving…' : 'Save Draft'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isSubmitting || _isSavingDraft ? null : _saveDraft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppButton(
                  key: const Key('gst-submit'),
                  label: _repo.submissionAvailable
                      ? 'Submit for Verification'
                      : 'Check details',
                  icon: _repo.submissionAvailable
                      ? LucideIcons.send
                      : LucideIcons.listChecks,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ),
            ],
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            Text(
              _submitError!,
              key: const Key('gst-submit-error'),
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          if (_submitBlocked) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('gst-submit-unavailable'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Online submission is not available yet. Your details were checked but nothing was saved or sent. Your status remains Not Verified.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _helperFor(GstField f, String? ocrValue, bool isEdited) {
    if (ocrValue == null) {
      return 'Not found on the certificate — please enter it';
    }
    if (f == GstField.gstin && isEdited) {
      return 'Edited — differs from the certificate reading';
    }
    if (isEdited) return 'Edited by you';
    if ((f == GstField.gstin && _ocr!.gstinCorrected) ||
        _ocr!.correctedFields.contains(f)) {
      return 'Corrected from the OCR reading — please compare';
    }
    return null;
  }

  String? _errorText(GstFieldError? e) => switch (e) {
    null => null,
    GstFieldError.required => 'Required',
    GstFieldError.invalidFormat => 'Enter a 15-character GSTIN',
    GstFieldError.invalidChecksum =>
      'This GSTIN fails the check-character test',
    GstFieldError.invalidPin => 'Enter a 6-digit PIN code',
    GstFieldError.stateMismatch =>
      'The state in this address does not match the GSTIN state code',
  };

  Set<GstIdentityIssue> get _identityIssues {
    final profile = _state?.profile;
    if (profile == null) return const {};
    final values = _currentValues;
    return GstIdentityCheck.compare(
      savedGstin: profile.companyGst,
      savedCompanyName: profile.companyName,
      gstin: values[GstField.gstin] ?? '',
      legalName: values[GstField.legalName] ?? '',
      tradeName: values[GstField.tradeName] ?? '',
    );
  }

  /// Warns when the certificate looks like it belongs to a different business
  /// than the signed-in buyer's company. The profile is never changed here.
  List<Widget> _identitySection() {
    final issues = _identityIssues;
    if (issues.isEmpty) return const [];
    final profile = _state?.profile;
    if (profile == null) return const [];
    final values = _currentValues;
    final certNames = [values[GstField.legalName], values[GstField.tradeName]]
        .whereType<String>()
        .where((n) => n.isNotEmpty)
        .map((n) => '"$n"')
        .join(' / ');
    return [
      const SizedBox(height: 12),
      // Material (not a decorated Container) so the CheckboxListTile's ink shows.
      Material(
        key: const Key('gst-identity-warning'),
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Check that this certificate belongs to your business',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              if (issues.contains(GstIdentityIssue.gstinDiffers))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Your profile has GSTIN ${profile.companyGst}; this certificate shows '
                    '${GstinRules.normalize(values[GstField.gstin]!)}.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              if (issues.contains(GstIdentityIssue.nameDiffers))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Your profile company "${profile.companyName}" does not match '
                    'the certificate name $certNames.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Your saved profile is not changed by this screen.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              CheckboxListTile(
                key: const Key('gst-identity-confirm'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _identityConfirmed,
                onChanged: (v) => setState(() {
                  _identityConfirmed = v ?? false;
                  if (_identityConfirmed) _identityError = false;
                }),
                title: const Text(
                  'I confirm this certificate belongs to my business',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              if (_identityError)
                const Text(
                  'Confirm that this certificate belongs to your business before continuing.',
                  key: Key('gst-identity-error'),
                  style: TextStyle(color: AppColors.error, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    ];
  }
}
