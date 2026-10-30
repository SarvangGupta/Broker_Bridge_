import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/preferences/app_settings_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../directory/data/ocr_extraction_service.dart';
import '../../directory/domain/gst_certificate_data.dart';
import '../../directory/presentation/widgets/gst_filing_history_sheet.dart';
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
/// Supports viewing verified credentials, full business details, GST certificate OCR extraction,
/// official portal verification, and editing permitted operational details.
class BrokerProfileScreen extends ConsumerStatefulWidget {
  const BrokerProfileScreen({super.key});

  @override
  ConsumerState<BrokerProfileScreen> createState() =>
      _BrokerProfileScreenState();
}

class _BrokerProfileScreenState extends ConsumerState<BrokerProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isExtractingOcr = false;
  String? _errorMessage;
  String? _successMessage;

  // Personal Controllers
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _designationController;

  // Business Controllers
  late TextEditingController _brokerageController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late TextEditingController _contactNumberController;
  late TextEditingController _locationsController;
  late TextEditingController _commoditiesController;
  late TextEditingController _regionsController;

  // GST Controllers
  late TextEditingController _gstinController;
  late TextEditingController _legalNameController;
  late TextEditingController _tradeNameController;
  late TextEditingController _constitutionController;
  late TextEditingController _regDateController;
  late TextEditingController _principalPlaceController;

  String _businessType = 'Proprietorship';
  String _gstStatus = 'Active';
  String _gstVerificationStatus = BrokerGstStatus.pending;
  String? _gstVerificationSource;
  DateTime? _gstVerifiedAt;
  String? _certificatePath;
  String? _certificateUrl;
  bool _brokerReviewConfirmed = false;
  String? _selectedPhotoPath;

  final _formKey = GlobalKey<FormState>();
  BrokerProfile? _currentProfile;
  final OcrExtractionService _ocrService = const OcrExtractionService();
  final ImagePicker _imagePicker = ImagePicker();

  static const List<String> _businessTypeOptions = [
    'Proprietorship',
    'Partnership',
    'Limited Liability Partnership (LLP)',
    'Private Limited Company',
    'Public Limited Company',
    'Hindu Undivided Family (HUF)',
  ];

  static const List<String> _gstStatusOptions = [
    'Active',
    'Suspended',
    'Cancelled',
    'Pending',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _mobileController = TextEditingController();
    _emailController = TextEditingController();
    _designationController = TextEditingController();

    _brokerageController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _pincodeController = TextEditingController();
    _contactNumberController = TextEditingController();
    _locationsController = TextEditingController();
    _commoditiesController = TextEditingController();
    _regionsController = TextEditingController();

    _gstinController = TextEditingController();
    _legalNameController = TextEditingController();
    _tradeNameController = TextEditingController();
    _constitutionController = TextEditingController();
    _regDateController = TextEditingController();
    _principalPlaceController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _designationController.dispose();

    _brokerageController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _contactNumberController.dispose();
    _locationsController.dispose();
    _commoditiesController.dispose();
    _regionsController.dispose();

    _gstinController.dispose();
    _legalNameController.dispose();
    _tradeNameController.dispose();
    _constitutionController.dispose();
    _regDateController.dispose();
    _principalPlaceController.dispose();
    super.dispose();
  }

  void _populateFields(BrokerProfile profile) {
    _currentProfile = profile;
    _nameController.text = profile.fullName;
    _mobileController.text = profile.mobile;
    _emailController.text = profile.email;
    _designationController.text = profile.designation;

    _brokerageController.text = profile.brokerageName;
    _businessType = _businessTypeOptions.contains(profile.businessType)
        ? profile.businessType
        : 'Proprietorship';
    _addressController.text = profile.businessAddress;
    _cityController.text = profile.city;
    _stateController.text = profile.state;
    _pincodeController.text = profile.pincode;
    _contactNumberController.text = profile.businessContactNumber;
    _locationsController.text = profile.operatingLocations;
    _commoditiesController.text = profile.commoditiesHandled;
    _regionsController.text = profile.operatingRegions;

    _gstinController.text = profile.gstin;
    _legalNameController.text = profile.legalName;
    _tradeNameController.text = profile.tradeName;
    _constitutionController.text = profile.constitution;
    _regDateController.text = profile.registrationDate;
    _gstStatus = _gstStatusOptions.contains(profile.gstStatus)
        ? profile.gstStatus
        : 'Active';
    _principalPlaceController.text = profile.principalPlaceOfBusiness;

    _certificatePath = profile.gstCertificatePath;
    _certificateUrl = profile.gstCertificateUrl;
    _gstVerificationStatus = profile.gstVerificationStatus;
    _gstVerificationSource = profile.gstVerificationSource;
    _gstVerifiedAt = profile.gstVerifiedAt;
    _brokerReviewConfirmed =
        profile.gstVerificationStatus == BrokerGstStatus.certificateReviewed;

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

  Future<void> _pickCertificate(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (picked == null) return;

      setState(() {
        _isExtractingOcr = true;
        _errorMessage = null;
      });

      final ocrResult = await _ocrService.extractGstCertificate(picked.path);

      if (mounted) {
        setState(() {
          _isExtractingOcr = false;
          _certificatePath = picked.path;
          _gstVerificationStatus = BrokerGstStatus.certificateUploaded;

          if (ocrResult.isSuccess && ocrResult.data != null) {
            final data = ocrResult.data!;
            if (data.gstin != null && data.gstin!.isNotEmpty) {
              _gstinController.text = data.gstin!;
            }
            if (data.legalName != null && data.legalName!.isNotEmpty) {
              _legalNameController.text = data.legalName!;
            }
            if (data.tradeName != null && data.tradeName!.isNotEmpty) {
              _tradeNameController.text = data.tradeName!;
            }
            if (data.constitution != null && data.constitution!.isNotEmpty) {
              _constitutionController.text = data.constitution!;
              if (_businessTypeOptions.contains(data.constitution)) {
                _businessType = data.constitution!;
              }
            }
            if (data.principalAddress != null &&
                data.principalAddress!.isNotEmpty) {
              _principalPlaceController.text = data.principalAddress!;
              if (_addressController.text.trim().isEmpty) {
                _addressController.text = data.principalAddress!;
              }
            }
            if (data.pinCode != null && data.pinCode!.isNotEmpty) {
              _pincodeController.text = data.pinCode!;
            }
            if (data.registrationDate != null &&
                data.registrationDate!.isNotEmpty) {
              _regDateController.text = data.registrationDate!;
            }
            if (data.gstStatus != null && data.gstStatus!.isNotEmpty) {
              _gstStatus = data.gstStatus!;
            }

            _successMessage =
                'GST Certificate read successfully via on-device OCR. Please review extracted fields below.';
          } else {
            _successMessage =
                'Certificate attached. Please verify or complete GST details manually.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExtractingOcr = false;
          _errorMessage = 'Failed to process document: $e';
        });
      }
    }
  }

  void _removeCertificate() {
    setState(() {
      _certificatePath = null;
      _certificateUrl = null;
      _brokerReviewConfirmed = false;
      if (_gstinController.text.trim().isEmpty) {
        _gstVerificationStatus = BrokerGstStatus.gstMissing;
      } else {
        _gstVerificationStatus = BrokerGstStatus.pending;
      }
    });
  }

  Future<void> _checkGstFilingHistory() async {
    final gstin = _gstinController.text.trim();
    if (gstin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid GSTIN first')),
      );
      return;
    }

    final normalized = GstinRules.normalize(gstin);
    if (!GstinRules.hasValidFormat(normalized)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GSTIN must follow the 15-character standard format'),
        ),
      );
      return;
    }

    GstFilingHistorySheet.show(context, gstin: normalized);
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    _errorMessage = null;
    _successMessage = null;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_currentProfile == null) return;

    // Determine verification status
    String finalVerificationStatus = _gstVerificationStatus;
    String? finalVerificationSource = _gstVerificationSource;
    DateTime? finalVerifiedAt = _gstVerifiedAt;

    if (_brokerReviewConfirmed &&
        (_certificatePath != null || _certificateUrl != null)) {
      finalVerificationStatus = BrokerGstStatus.certificateReviewed;
      finalVerificationSource = 'broker_self_review';
      finalVerifiedAt = DateTime.now();
    } else if (_gstinController.text.trim().isEmpty) {
      finalVerificationStatus = BrokerGstStatus.gstMissing;
      finalVerificationSource = null;
      finalVerifiedAt = null;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(profileRepositoryProvider);

      // Upload certificate if a local file was newly selected
      String? uploadedUrl = _certificateUrl;
      if (_certificatePath != null &&
          !_certificatePath!.startsWith('http') &&
          File(_certificatePath!).existsSync()) {
        final uploaded = await repo.uploadCertificate(
          filePath: _certificatePath!,
          userId: _currentProfile!.id,
        );
        if (uploaded != null) {
          uploadedUrl = uploaded;
        }
      }

      final updated = _currentProfile!.copyWith(
        fullName: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        designation: _designationController.text.trim(),
        brokerageName: _brokerageController.text.trim(),
        businessType: _businessType,
        businessAddress: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        businessContactNumber: _contactNumberController.text.trim(),
        operatingLocations: _locationsController.text.trim(),
        commoditiesHandled: _commoditiesController.text.trim(),
        operatingRegions: _regionsController.text.trim(),
        gstin: _gstinController.text.trim(),
        legalName: _legalNameController.text.trim(),
        tradeName: _tradeNameController.text.trim(),
        constitution: _constitutionController.text.trim().isNotEmpty
            ? _constitutionController.text.trim()
            : _businessType,
        registrationDate: _regDateController.text.trim(),
        gstStatus: _gstStatus,
        principalPlaceOfBusiness: _principalPlaceController.text.trim(),
        gstCertificatePath: _certificatePath,
        gstCertificateUrl: uploadedUrl,
        gstVerificationStatus: finalVerificationStatus,
        gstVerificationSource: finalVerificationSource,
        gstVerifiedAt: finalVerifiedAt,
        profilePhotoPath: _selectedPhotoPath,
      );

      final result = await repo.updateProfile(updated);

      if (mounted) {
        if (result is ProfileSuccess<BrokerProfile>) {
          setState(() {
            _isSaving = false;
            _isEditing = false;
            _currentProfile = result.data;
            _populateFields(result.data);
            _successMessage =
                'Broker Profile & GST credentials synchronized successfully';
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
                title: const Text('Take Photo from Camera'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final img = await _imagePicker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                  );
                  if (img != null) {
                    setState(() => _selectedPhotoPath = img.path);
                  }
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.image, color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final img = await _imagePicker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (img != null) {
                    setState(() => _selectedPhotoPath = img.path);
                  }
                },
              ),
              if (_selectedPhotoPath != null)
                ListTile(
                  leading:
                      const Icon(LucideIcons.trash2, color: AppColors.error),
                  title: const Text('Remove Custom Photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _selectedPhotoPath = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGstStatusBadge(String status) {
    Color bg;
    Color fg;
    IconData icon;
    String label = BrokerGstStatus.displayLabel(status);

    switch (status.toLowerCase()) {
      case BrokerGstStatus.gstMatched:
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        icon = LucideIcons.shieldCheck;
        break;
      case BrokerGstStatus.certificateReviewed:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        icon = LucideIcons.checkCircle2;
        break;
      case BrokerGstStatus.certificateUploaded:
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1E40AF);
        icon = LucideIcons.fileCheck;
        break;
      case BrokerGstStatus.inactive:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        icon = LucideIcons.ban;
        break;
      case BrokerGstStatus.failed:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        icon = LucideIcons.xCircle;
        break;
      case BrokerGstStatus.gstMissing:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        icon = LucideIcons.alertCircle;
        break;
      case BrokerGstStatus.pending:
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        icon = LucideIcons.clock;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
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
          IconButton(
            tooltip: isIconOnly ? 'Show labels (*)' : 'Hide labels (*)',
            icon: Text(
              '*',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color:
                    isIconOnly ? AppColors.primary : AppColors.textSecondaryLight,
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
                const Icon(
                  LucideIcons.alertTriangle,
                  size: 48,
                  color: AppColors.error,
                ),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
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
                // Error Alert
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
                        const Icon(
                          LucideIcons.alertCircle,
                          color: AppColors.error,
                          size: 18,
                        ),
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

                // Success Alert
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
                        const Icon(
                          LucideIcons.checkCircle2,
                          color: AppColors.success,
                          size: 18,
                        ),
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

                // Top Monogram & Verified Desk Identity Card
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
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
                                  Icon(
                                    LucideIcons.shieldCheck,
                                    size: 12,
                                    color: AppColors.success,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Verified Mandi Desk',
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
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
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
                        value: profile.isVerified
                            ? 'Authoritative Verified'
                            : 'Pending',
                      ),
                      _buildReadOnlyTile(
                        label: 'Trading Trust Score',
                        value: '${profile.trustScore} / 100',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 1. Personal Details Section
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(LucideIcons.user, size: 16, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
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

                      // Designation
                      _buildField(
                        label: 'Designation / Desk Role',
                        controller: _designationController,
                        enabled: _isEditing,
                        icon: LucideIcons.briefcase,
                        hint: 'e.g. Managing Director, Senior Mandi Broker',
                      ),
                      const SizedBox(height: 12),

                      // Registered Mobile
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

                      // Official Email
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
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 2. Business Details Section
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(LucideIcons.building, size: 16, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Business & Brokerage Details',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Firm Name
                      _buildField(
                        label: 'Business / Firm Name *',
                        controller: _brokerageController,
                        enabled: _isEditing,
                        icon: LucideIcons.building2,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Brokerage firm name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Business Type
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Business Type',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: _isEditing
                                  ? Colors.white
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _businessType,
                                icon: const Icon(LucideIcons.chevronDown, size: 16),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _isEditing
                                      ? AppColors.textPrimaryLight
                                      : AppColors.textSecondaryLight,
                                ),
                                onChanged: _isEditing
                                    ? (val) {
                                        if (val != null) {
                                          setState(() => _businessType = val);
                                        }
                                      }
                                    : null,
                                items: _businessTypeOptions.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
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

                      // City & State Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              label: 'City',
                              controller: _cityController,
                              enabled: _isEditing,
                              icon: LucideIcons.navigation,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildField(
                              label: 'State',
                              controller: _stateController,
                              enabled: _isEditing,
                              icon: LucideIcons.map,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // PIN Code & Contact Number Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              label: 'PIN Code',
                              controller: _pincodeController,
                              enabled: _isEditing,
                              icon: LucideIcons.hash,
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                if (val != null &&
                                    val.trim().isNotEmpty &&
                                    !RegExp(r'^\d{6}$').hasMatch(val.trim())) {
                                  return '6-digit PIN code';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildField(
                              label: 'Desk Phone Number',
                              controller: _contactNumberController,
                              enabled: _isEditing,
                              icon: LucideIcons.phoneCall,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Operating Locations
                      _buildField(
                        label: 'Operating Mandis / Locations',
                        controller: _locationsController,
                        enabled: _isEditing,
                        icon: LucideIcons.mapPin,
                        hint: 'e.g. Jaipur Mandi, Kota, Alwar, Bikaner',
                      ),
                      const SizedBox(height: 12),

                      // Commodities
                      _buildField(
                        label: 'Commodities Handled',
                        controller: _commoditiesController,
                        enabled: _isEditing,
                        icon: LucideIcons.layers,
                        hint: 'e.g. Mustard Seed, Soybean, Wheat, Chana',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 3. GST Details & Verification Status Section
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                LucideIcons.fileText,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'GST Registration & Status',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          _buildGstStatusBadge(_gstVerificationStatus),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // GSTIN with Check History Button
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'GSTIN (15 characters)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimaryLight,
                                ),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                                icon: const Icon(
                                  LucideIcons.history,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                label: const Text(
                                  'Check GST History',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: _checkGstFilingHistory,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _gstinController,
                            enabled: _isEditing,
                            textCapitalization: TextCapitalization.characters,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: _isEditing
                                  ? AppColors.textPrimaryLight
                                  : AppColors.textSecondaryLight,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. 08AAAAA0000A1Z5',
                              prefixIcon: const Icon(
                                LucideIcons.fileCheck2,
                                size: 16,
                                color: AppColors.textSecondaryLight,
                              ),
                              filled: true,
                              fillColor: _isEditing
                                  ? Colors.white
                                  : const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: AppColors.borderLight),
                              ),
                            ),
                            validator: (val) {
                              if (val != null && val.trim().isNotEmpty) {
                                final norm = GstinRules.normalize(val);
                                if (!GstinRules.hasValidFormat(norm)) {
                                  return 'Enter a valid 15-character GSTIN';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Legal Name
                      _buildField(
                        label: 'Legal Business Name (as per GST Certificate)',
                        controller: _legalNameController,
                        enabled: _isEditing,
                        icon: LucideIcons.badgeCheck,
                      ),
                      const SizedBox(height: 12),

                      // Trade Name
                      _buildField(
                        label: 'Trade Name',
                        controller: _tradeNameController,
                        enabled: _isEditing,
                        icon: LucideIcons.store,
                      ),
                      const SizedBox(height: 12),

                      // Constitution & Registration Date Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              label: 'Constitution',
                              controller: _constitutionController,
                              enabled: _isEditing,
                              icon: LucideIcons.scroll,
                              hint: 'e.g. Proprietorship',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildField(
                              label: 'Registration Date',
                              controller: _regDateController,
                              enabled: _isEditing,
                              icon: LucideIcons.calendar,
                              hint: 'DD/MM/YYYY',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Principal Place of Business
                      _buildField(
                        label: 'Principal Place of Business',
                        controller: _principalPlaceController,
                        enabled: _isEditing,
                        icon: LucideIcons.mapPin,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 4. GST Certificate Document Management & OCR
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(LucideIcons.fileCheck, size: 16, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'GST Certificate (Form GST REG-06)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Upload your government-issued certificate to auto-extract registration details using on-device OCR.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Certificate Preview / Action Cards
                      if (_isExtractingOcr)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: const [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Reading GST details via OCR...',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_certificatePath != null ||
                          _certificateUrl != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      LucideIcons.fileText,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _certificatePath?.split(RegExp(r'[\\/]')).last ??
                                              'GST_Certificate_REG06.pdf',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _certificateUrl != null
                                              ? 'Stored in Private Document Repository'
                                              : 'Loaded locally on device',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_isEditing) ...[
                                    IconButton(
                                      tooltip: 'Remove Certificate',
                                      icon: const Icon(
                                        LucideIcons.trash2,
                                        size: 18,
                                        color: AppColors.error,
                                      ),
                                      onPressed: _removeCertificate,
                                    ),
                                  ],
                                ],
                              ),
                              if (_isEditing) ...[
                                const Divider(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(LucideIcons.camera, size: 14),
                                        label: const Text('Retake Camera'),
                                        onPressed: () =>
                                            _pickCertificate(ImageSource.camera),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(LucideIcons.image, size: 14),
                                        label: const Text('Replace File'),
                                        onPressed: () =>
                                            _pickCertificate(ImageSource.gallery),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Broker Self-Review Confirmation Checkbox
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: _brokerReviewConfirmed,
                          title: const Text(
                            'Broker Verified — Certificate Reviewed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          subtitle: const Text(
                            'I confirm that I have reviewed the certificate details. (Note: OCR is not government verification)',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          onChanged: _isEditing
                              ? (val) {
                                  setState(() {
                                    _brokerReviewConfirmed = val ?? false;
                                  });
                                }
                              : null,
                        ),
                      ] else ...[
                        if (_isEditing) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    side: const BorderSide(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  icon: const Icon(LucideIcons.camera, size: 16),
                                  label: const Text('Capture Camera'),
                                  onPressed: () =>
                                      _pickCertificate(ImageSource.camera),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    backgroundColor: AppColors.primary,
                                  ),
                                  icon: const Icon(
                                    LucideIcons.uploadCloud,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Upload Gallery/PDF',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  onPressed: () =>
                                      _pickCertificate(ImageSource.gallery),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  LucideIcons.fileWarning,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No GST Certificate attached yet. Tap Edit Profile to upload.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          child: _isEditing
              ? Row(
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
              : ElevatedButton.icon(
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
        ),
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
                    child:
                        Icon(LucideIcons.copy, size: 12, color: AppColors.primary),
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
            color: enabled
                ? AppColors.textPrimaryLight
                : AppColors.textSecondaryLight,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon:
                Icon(icon, size: 16, color: AppColors.textSecondaryLight),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
