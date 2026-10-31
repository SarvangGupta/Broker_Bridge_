import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loading_indicator.dart';
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

/// Authoritative, simplified Broker Profile Screen.
/// Standardizes broker profile, GST details, verification badges, and responsive editing.
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

  // Business & Address Controllers
  late TextEditingController _brokerageController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late TextEditingController _locationsController;
  late TextEditingController _commoditiesController;

  // GST Controllers (Source of truth for business details)
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

  // List of mandis & commodities as chips
  List<String> _mandisList = [];
  List<String> _commoditiesList = [];

  final _formKey = GlobalKey<FormState>();
  BrokerProfile? _currentProfile;
  String? _savedSnapshot;
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

  static const List<String> _stateOptions = [
    'Rajasthan',
    'Madhya Pradesh',
    'Gujarat',
    'Haryana',
    'Punjab',
    'Uttar Pradesh',
    'Maharashtra',
    'Delhi',
  ];

  /// Below this a field can't show its value beside its suffix icon.
  static const double _minEditColumnWidth = 136;

  /// Dropdown horizontal content padding (10 + 10) plus its arrow icon (24)
  /// and input border.
  static const double _dropdownChromeWidth = 46;

  static const TextStyle _editDropdownTextStyle = TextStyle(
    fontSize: 12.5,
    color: Color(0xFF0F172A),
    fontWeight: FontWeight.w600,
  );

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _mobileController = TextEditingController();
    _emailController = TextEditingController();
    _designationController = TextEditingController();

    _brokerageController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _pincodeController = TextEditingController();
    _locationsController = TextEditingController();
    _commoditiesController = TextEditingController();

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
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _locationsController.dispose();
    _commoditiesController.dispose();

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
    _designationController.text = profile.designation.isNotEmpty
        ? profile.designation
        : 'Managing Director & Mandi Broker';

    _brokerageController.text = profile.effectiveTradeName;
    _businessType = _businessTypeOptions.contains(profile.effectiveConstitution)
        ? profile.effectiveConstitution
        : 'Proprietorship';
    _cityController.text = profile.city.isNotEmpty ? profile.city : 'Jaipur';
    _stateController.text = profile.state.isNotEmpty ? profile.state : 'Rajasthan';
    _pincodeController.text = profile.pincode.isNotEmpty ? profile.pincode : '302016';
    _locationsController.text = profile.operatingLocations;
    _commoditiesController.text = profile.commoditiesHandled;

    _mandisList = profile.operatingLocations
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (_mandisList.isEmpty) {
      _mandisList = ['Jaipur', 'Kota', 'Alwar', 'Bikaner'];
    }

    _commoditiesList = profile.commoditiesHandled
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (_commoditiesList.isEmpty) {
      _commoditiesList = [
        'Mustard Seed (Sarson)',
        'Soybean',
        'Wheat',
        'Maize',
        'Chana',
      ];
    }

    _gstinController.text = profile.gstin;
    _legalNameController.text = profile.effectiveLegalName;
    _tradeNameController.text = profile.effectiveTradeName;
    _constitutionController.text = profile.effectiveConstitution;
    _regDateController.text = profile.registrationDate.isNotEmpty
        ? profile.registrationDate
        : '01 Jul 2017';
    _gstStatus = profile.gstStatus.isNotEmpty ? profile.gstStatus : 'Active';
    _principalPlaceController.text = profile.effectiveAddress;

    _certificatePath = profile.gstCertificatePath;
    _certificateUrl = profile.gstCertificateUrl;
    _gstVerificationStatus = profile.gstVerificationStatus;
    _gstVerificationSource = profile.gstVerificationSource;
    _gstVerifiedAt = profile.gstVerifiedAt;
    _brokerReviewConfirmed =
        profile.gstVerificationStatus == BrokerGstStatus.certificateReviewed;

    _selectedPhotoPath = profile.profilePhotoPath;
    _savedSnapshot = _formSnapshot();
  }

  void _cancelEdit() {
    if (_isSaving) return;
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
              _brokerageController.text = data.tradeName!;
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
                'GST Certificate read via on-device OCR. Please review auto-filled details.';
          } else {
            _successMessage =
                'Certificate attached. Please verify or update GST details.';
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

  void _viewCertificateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'GST Registration Certificate',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_certificatePath != null &&
                  File(_certificatePath!).existsSync()) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(_certificatePath!),
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.fileCheck2,
                          size: 26, color: Color(0xFF0F766E)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Form GST REG-06 Verified',
                              style: TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'GSTIN: ${_gstinController.text.isNotEmpty ? _gstinController.text : "08ADRPK6597J1ZL"}',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text('Legal Name: ${_legalNameController.text}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Trade Name: ${_tradeNameController.text}',
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF475569))),
              const SizedBox(height: 4),
              Text('Principal Place: ${_principalPlaceController.text}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Everything the form can change, as it stands right now.
  String _formSnapshot() => [
        _nameController.text,
        _mobileController.text,
        _emailController.text,
        _designationController.text,
        _legalNameController.text,
        _tradeNameController.text,
        _gstinController.text,
        _regDateController.text,
        _principalPlaceController.text,
        _cityController.text,
        _stateController.text,
        _pincodeController.text,
        _businessType,
        _gstStatus,
        _certificatePath,
        _selectedPhotoPath,
        ..._mandisList,
        '|',
        ..._commoditiesList,
      ].map((v) => v?.trim()).join('\u0001');

  void _showSnack(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  void _showSaveError(String message, {SnackBarAction? action}) {
    setState(() {
      _isSaving = false;
      _errorMessage = message;
    });
    // The banner sits at the top of the list, usually scrolled out of view.
    _showSnack(message, action: action);
  }

  /// Validates every field; on failure scrolls to the topmost invalid one.
  bool _validateAndRevealFirstError() {
    final invalid = _formKey.currentState!.validateGranularly();
    if (invalid.isEmpty) return true;

    double top(FormFieldState<Object?> field) {
      final box = field.context.findRenderObject() as RenderBox?;
      return box?.localToGlobal(Offset.zero).dy ?? double.infinity;
    }

    final first = invalid.reduce((a, b) => top(a) <= top(b) ? a : b);
    Scrollable.ensureVisible(
      first.context,
      alignment: 0.2,
      duration: const Duration(milliseconds: 250),
    );
    return false;
  }

  Future<void> _saveProfile() async {
    if (_isSaving || _currentProfile == null) return;

    if (_formSnapshot() == _savedSnapshot) {
      _showSnack('No changes to save');
      return;
    }

    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (!_validateAndRevealFirstError()) return;

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

      String? uploadedUrl = _certificateUrl;
      // Only a newly picked certificate needs uploading.
      if (_certificatePath != null &&
          _certificatePath != _currentProfile!.gstCertificatePath &&
          !_certificatePath!.startsWith('http') &&
          File(_certificatePath!).existsSync()) {
        try {
          final uploaded = await repo.uploadCertificate(
            filePath: _certificatePath!,
            userId: _currentProfile!.id,
          );
          if (uploaded != null) {
            uploadedUrl = uploaded;
          }
        } catch (e) {
          debugPrint('Certificate upload failed: $e');
          if (mounted) {
            _showSaveError(
              'Could not upload the GST certificate, so nothing was saved. Check your connection and try again.',
            );
          }
          return;
        }
      }

      final updated = _currentProfile!.copyWith(
        fullName: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        designation: _designationController.text.trim(),
        brokerageName: _tradeNameController.text.trim().isNotEmpty
            ? _tradeNameController.text.trim()
            : _brokerageController.text.trim(),
        businessType: _businessType,
        businessAddress: _principalPlaceController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        operatingLocations: _mandisList.join(', '),
        commoditiesHandled: _commoditiesList.join(', '),
        gstin: _gstinController.text.trim(),
        legalName: _legalNameController.text.trim(),
        tradeName: _tradeNameController.text.trim(),
        constitution: _businessType,
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
      if (!mounted) return;

      switch (result) {
        case ProfileSuccess<BrokerProfile>(:final data):
          setState(() {
            _isSaving = false;
            _isEditing = false;
            _populateFields(data);
          });
          ref.invalidate(brokerProfileProvider);
          _showSnack('Profile updated successfully');
        case ProfileError<BrokerProfile>(:final message):
          _showSaveError(message);
        case ProfileUnauthorized<BrokerProfile>():
          // Stay on the form so the entered values aren't lost to a redirect.
          _showSaveError(
            'Your session has expired, so your changes were not saved. Sign in again to continue.',
            action: SnackBarAction(
              label: 'Sign in',
              onPressed: () => context.go('/login'),
            ),
          );
      }
    } catch (e) {
      debugPrint('Profile save failed: $e');
      if (mounted) {
        _showSaveError(ProfileRepository.describeSaveError(e));
      }
    }
  }

  Widget _buildSaveChangesBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              key: const ValueKey('edit_profile_save_changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Saving...',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
                leading: const Icon(LucideIcons.camera, color: Color(0xFF0F766E)),
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
                leading: const Icon(LucideIcons.image, color: Color(0xFF0F766E)),
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
                  leading: const Icon(LucideIcons.trash2, color: AppColors.error),
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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(brokerProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: _isEditing && profileAsync.hasValue
          ? _buildSaveChangesBar()
          : null,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(
            LucideIcons.arrowLeft,
            size: 20,
            color: Color(0xFF0F172A),
          ),
          tooltip: 'Back',
          onPressed: () {
            if (_isEditing) {
              _cancelEdit();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: Text(
          _isEditing ? 'Edit Profile' : 'Broker Profile',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(
                LucideIcons.pencil,
                size: 20,
                color: Color(0xFF0F172A),
              ),
              tooltip: 'Edit Profile',
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _errorMessage = null;
                  _successMessage = null;
                });
              },
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: SizedBox(
                height: 36,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(
          child: AppLoadingIndicator(message: 'Loading broker profile...'),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.alertTriangle,
                  size: 40,
                  color: AppColors.error,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Error loading profile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Retry',
                  onPressed: () => ref.invalidate(brokerProfileProvider),
                ),
              ],
            ),
          ),
        ),
        data: (profile) {
          if (_currentProfile == null) {
            _populateFields(profile);
          }

          final initial = profile.fullName.trim().isNotEmpty
              ? profile.fullName.trim()[0].toUpperCase()
              : 'V';

          return Form(
            key: _formKey,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // Error Alert
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
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
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.checkCircle2,
                          color: Color(0xFF16A34A),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(
                              color: Color(0xFF166534),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (!_isEditing) ...[
                  // ================= VIEW MODE =================

                  // 1. Compact Profile Header Card
                  _buildProfileHeaderCard(profile, initial),
                  const SizedBox(height: 12),

                  // 2. Contact Information
                  _buildContactCard(profile),
                  const SizedBox(height: 12),

                  // 3. Business Details
                  _buildBusinessDetailsCard(profile),
                  const SizedBox(height: 12),

                  // 4. GST Registration
                  _buildGstRegistrationCard(profile),
                  const SizedBox(height: 12),

                  // 5. Address & Locations
                  _buildAddressLocationsCard(profile),
                ] else ...[
                  // ================= EDIT MODE =================
                  _buildEditModeContent(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // VIEW MODE WIDGETS
  // ==========================================

  Widget _buildProfileHeaderCard(BrokerProfile profile, String initial) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with camera badge
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBEF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF99F6E4),
                        width: 1.5,
                      ),
                    ),
                    child: (_selectedPhotoPath != null &&
                            File(_selectedPhotoPath!).existsSync())
                        ? ClipOval(
                            child: Image.file(
                              File(_selectedPhotoPath!),
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ),
                  ),
                  InkWell(
                    onTap: _showPhotoOptions,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(
                        LucideIcons.camera,
                        size: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Name, Trade Name, Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.effectiveTradeName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Badges and Trust Score
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F7F2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            profile.role,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ),

                        // KYC Verification Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: profile.isVerified
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                profile.isVerified
                                    ? LucideIcons.check
                                    : LucideIcons.clock,
                                size: 12,
                                color: profile.isVerified
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                profile.isVerified
                                    ? 'KYC Verified'
                                    : 'KYC Pending',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: profile.isVerified
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Trust Score Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFEF3C7)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Trust Score ${profile.trustScore} / 100',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF92400E),
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
            ],
          ),
          const SizedBox(height: 12),

          // Smart Broker ID
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.fileText,
                  size: 15,
                  color: Color(0xFF0F766E),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Broker ID: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  profile.displayBrokerId,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: profile.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Broker ID copied: ${profile.displayBrokerId}'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      LucideIcons.copy,
                      size: 15,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(BrokerProfile profile) {
    return _buildSectionCard(
      title: 'Contact Information',
      icon: LucideIcons.user,
      onEdit: () => setState(() => _isEditing = true),
      children: [
        // Phone
        Row(
          children: [
            const Icon(LucideIcons.phone, size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 10),
            Text(
              profile.mobile,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Verified',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF16A34A),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        const SizedBox(height: 12),

        // Email
        Row(
          children: [
            const Icon(LucideIcons.mail, size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 10),
            Text(
              profile.email,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Verified',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF16A34A),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBusinessDetailsCard(BrokerProfile profile) {
    return _buildSectionCard(
      title: 'Business Details',
      icon: LucideIcons.store,
      onEdit: () => setState(() => _isEditing = true),
      children: [
        _buildKeyValRow('Legal Business Name', profile.effectiveLegalName,
            isBold: true),
        const SizedBox(height: 10),
        _buildKeyValRow('Trade Name', profile.effectiveTradeName),
        const SizedBox(height: 10),
        _buildKeyValRow('Business Type', profile.effectiveConstitution),
        const SizedBox(height: 10),
        _buildKeyValRow(
          'Registration Date',
          profile.registrationDate.isNotEmpty
              ? profile.registrationDate
              : '01 Jul 2017',
        ),
      ],
    );
  }

  Widget _buildGstRegistrationCard(BrokerProfile profile) {
    final isReviewed =
        profile.gstVerificationStatus == BrokerGstStatus.certificateReviewed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with wrap to prevent overflow on narrow screens
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F7F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.fileSpreadsheet,
                      size: 16,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'GST Registration',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isReviewed
                      ? const Color(0xFFDCFCE7)
                      : (profile.gstin.isNotEmpty
                          ? const Color(0xFFDBEAFE)
                          : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isReviewed ? LucideIcons.check : LucideIcons.clock,
                      size: 12,
                      color: isReviewed
                          ? const Color(0xFF16A34A)
                          : (profile.gstin.isNotEmpty
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isReviewed
                          ? 'Verified'
                          : (profile.gstin.isNotEmpty
                              ? 'Certificate Uploaded'
                              : 'Pending Details'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isReviewed
                            ? const Color(0xFF16A34A)
                            : (profile.gstin.isNotEmpty
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFFD97706)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // GSTIN Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GSTIN',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          profile.gstin.isNotEmpty
                              ? profile.gstin
                              : '08ADRPK6597J1ZL',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                                text: profile.gstin.isNotEmpty
                                    ? profile.gstin
                                    : '08ADRPK6597J1ZL'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('GSTIN copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Icon(
                            LucideIcons.copy,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // View Certificate Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(LucideIcons.fileText, size: 14),
                  label: const Text(
                    'View Certificate',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  onPressed: _viewCertificateModal,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Status Rows
          _buildStatusRow(
            icon: LucideIcons.globe,
            label: 'Registration Status (Govt.)',
            value: profile.gstStatus.isNotEmpty ? profile.gstStatus : 'Active',
            valueColor: const Color(0xFF16A34A),
          ),
          const SizedBox(height: 8),
          _buildStatusRow(
            icon: LucideIcons.fileCheck,
            label: 'Certificate Status',
            value: (profile.gstCertificatePath != null ||
                    profile.gstCertificateUrl != null ||
                    profile.gstin.isNotEmpty)
                ? 'Uploaded'
                : 'Not Uploaded',
            valueColor: const Color(0xFF0F766E),
          ),
          const SizedBox(height: 8),
          _buildStatusRow(
            icon: LucideIcons.shieldCheck,
            label: 'Broker Review Status',
            value: isReviewed ? 'Verified' : 'Pending Review',
            valueColor: isReviewed
                ? const Color(0xFF16A34A)
                : const Color(0xFFD97706),
          ),
          const SizedBox(height: 10),

          // Check GST History Button
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                foregroundColor: const Color(0xFF0F766E),
              ),
              icon: const Icon(LucideIcons.history, size: 14),
              label: const Text(
                'Check GST Filing History',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: _checkGstFilingHistory,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressLocationsCard(BrokerProfile profile) {
    return _buildSectionCard(
      title: 'Address & Locations',
      icon: LucideIcons.mapPin,
      onEdit: () => setState(() => _isEditing = true),
      children: [
        // Principal Place of Business
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                LucideIcons.building,
                size: 15,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Principal Place of Business',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.effectiveAddress,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // City, State, PIN Code 3-column row
        Row(
          children: [
            Expanded(
              child: _buildMiniDataBox(
                icon: LucideIcons.mapPin,
                label: 'City',
                value: profile.city.isNotEmpty ? profile.city : 'Jaipur',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniDataBox(
                icon: LucideIcons.building2,
                label: 'State',
                value: profile.state.isNotEmpty ? profile.state : 'Rajasthan',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniDataBox(
                icon: LucideIcons.pin,
                label: 'PIN Code',
                value: profile.pincode.isNotEmpty ? profile.pincode : '302016',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        const SizedBox(height: 10),

        // Operating Mandis
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(LucideIcons.store, size: 15, color: Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Operating Mandis',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.operatingLocations.isNotEmpty
                        ? profile.operatingLocations
                        : 'Jaipur, Kota, Alwar, Bikaner',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        const SizedBox(height: 10),

        // Commodities Handled
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(LucideIcons.layers, size: 15, color: Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Commodities Handled',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.commoditiesHandled.isNotEmpty
                        ? profile.commoditiesHandled
                        : 'Mustard Seed (Sarson), Soybean, Wheat, Maize, Chana',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // EDIT MODE WIDGETS
  // ==========================================

  Widget _buildEditModeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Profile Photo & Basic Info
        _buildEditSectionCard(
          title: 'Profile Photo & Basic Info',
          icon: LucideIcons.user,
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBEF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF99F6E4),
                        width: 1.5,
                      ),
                    ),
                    child: (_selectedPhotoPath != null &&
                            File(_selectedPhotoPath!).existsSync())
                        ? ClipOval(
                            child: Image.file(
                              File(_selectedPhotoPath!),
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Center(
                            child: Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text[0].toUpperCase()
                                  : 'V',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ),
                  ),
                  InkWell(
                    onTap: _showPhotoOptions,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F766E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.camera,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildEditField(
              label: 'Full Name *',
              controller: _nameController,
              validator: (v) {
                final name = v?.trim() ?? '';
                if (name.isEmpty) return 'Full name is required';
                return name.length < 2
                    ? 'Full name must be at least 2 characters'
                    : null;
              },
            ),
            const SizedBox(height: 12),

            _buildEditField(
              label: 'Role / Designation',
              controller: _designationController,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2. Contact Information
        _buildEditSectionCard(
          title: 'Contact Information',
          icon: LucideIcons.phone,
          children: [
            _buildEditField(
              label: 'Registered Mobile Number *',
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              suffixBadge: 'Verified',
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                if (digits.isEmpty) return 'Mobile number is required';
                return digits.length < 10
                    ? 'Mobile number must have at least 10 digits'
                    : null;
              },
            ),
            const SizedBox(height: 12),

            _buildEditField(
              label: 'Official Email *',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              suffixBadge: 'Verified',
              validator: (v) => RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$')
                      .hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Enter a valid email',
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 3. Business Details (From GST Certificate)
        _buildEditSectionCard(
          title: 'Business Details (From GST Certificate)',
          icon: LucideIcons.store,
          children: [
            // Info notice
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.info, size: 15, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'These details are auto-filled from your GST certificate. Update by uploading a new certificate if any changes.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF1E40AF),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _buildEditField(
              label: 'Legal Business Name *',
              controller: _legalNameController,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Legal business name is required'
                  : null,
              minLines: 1,
              maxLines: 5,
            ),
            const SizedBox(height: 12),

            _buildEditField(
              label: 'Trade Name',
              controller: _tradeNameController,
              minLines: 1,
              maxLines: 5,
            ),
            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 10.0;
                final businessTypeField = _buildEditDropdown(
                  label: 'Business Type',
                  value: _businessTypeOptions.contains(_businessType)
                      ? _businessType
                      : _businessTypeOptions.first,
                  options: _businessTypeOptions,
                  onChanged: (v) => setState(() => _businessType = v),
                );
                final registrationDateField = _buildEditField(
                  label: 'Registration Date',
                  controller: _regDateController,
                  suffixIcon: LucideIcons.calendar,
                );
                final columnWidth = (constraints.maxWidth - spacing) / 2;
                final fitsSideBySide = columnWidth >= _minEditColumnWidth &&
                    columnWidth >=
                        _dropdownRequiredWidth(context, _businessType);
                return fitsSideBySide
                    ? _buildEditFieldRow(
                        spacing: spacing,
                        children: [businessTypeField, registrationDateField],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          businessTypeField,
                          const SizedBox(height: 12),
                          registrationDateField,
                        ],
                      );
              },
            ),
            const SizedBox(height: 12),

            // Re-upload / Retake Certificate Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFF0F766E)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(LucideIcons.uploadCloud, size: 15),
                label: Text(
                  _isExtractingOcr
                      ? 'Scanning Certificate...'
                      : 'Re-upload / Update GST Certificate',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onPressed: _isExtractingOcr
                    ? null
                    : () {
                        showModalBottomSheet(
                          context: context,
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(LucideIcons.camera,
                                      color: Color(0xFF0F766E)),
                                  title: const Text('Capture with Camera'),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _pickCertificate(ImageSource.camera);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(LucideIcons.image,
                                      color: Color(0xFF0F766E)),
                                  title: const Text('Choose from Gallery'),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _pickCertificate(ImageSource.gallery);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 4. Address (From GST Certificate)
        _buildEditSectionCard(
          title: 'Address (From GST Certificate)',
          icon: LucideIcons.mapPin,
          children: [
            _buildEditField(
              label: 'Principal Place of Business *',
              controller: _principalPlaceController,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Principal place of business is required'
                  : null,
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 8.0;
                final selectedState =
                    _stateOptions.contains(_stateController.text)
                        ? _stateController.text
                        : _stateOptions.first;
                final cityField = _buildEditField(
                  label: 'City *',
                  controller: _cityController,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'City is required'
                      : null,
                );
                final stateField = _buildEditDropdown(
                  label: 'State *',
                  value: selectedState,
                  options: _stateOptions,
                  onChanged: (v) => setState(() => _stateController.text = v),
                );
                final pinField = _buildEditField(
                  label: 'PIN Code *',
                  controller: _pincodeController,
                  keyboardType: TextInputType.number,
                  validator: (v) => RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Enter a 6-digit PIN code',
                );

                final minimumWidth = _dropdownRequiredWidth(
                  context,
                  selectedState,
                );
                bool fits(int columns) {
                  final columnWidth =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                  return columnWidth >= _minEditColumnWidth &&
                      columnWidth >= minimumWidth;
                }

                if (fits(3)) {
                  return _buildEditFieldRow(
                    spacing: spacing,
                    children: [cityField, stateField, pinField],
                  );
                }
                // City names run long, so City keeps the full row on phones.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cityField,
                    const SizedBox(height: 12),
                    if (fits(2))
                      _buildEditFieldRow(
                        spacing: spacing,
                        children: [stateField, pinField],
                      )
                    else ...[
                      stateField,
                      const SizedBox(height: 12),
                      pinField,
                    ],
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 5. Operating Mandis
        _buildEditSectionCard(
          title: 'Operating Mandis',
          icon: LucideIcons.store,
          children: [
            const Text(
              'Select mandis where you operate',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._mandisList.map((m) => Chip(
                      backgroundColor: const Color(0xFFF1F5F9),
                      label: Text(m, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(LucideIcons.x, size: 14),
                      onDeleted: () {
                        setState(() => _mandisList.remove(m));
                      },
                    )),
                ActionChip(
                  avatar: const Icon(LucideIcons.plus,
                      size: 14, color: Color(0xFF0F766E)),
                  label: const Text('Add Mandi',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w700)),
                  onPressed: () => _promptAddItem('Add Operating Mandi', (val) {
                    if (val.isNotEmpty && !_mandisList.contains(val)) {
                      setState(() => _mandisList.add(val));
                    }
                  }),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 6. Commodities Handled
        _buildEditSectionCard(
          title: 'Commodities Handled',
          icon: LucideIcons.layers,
          children: [
            const Text(
              'Select commodities you deal in',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._commoditiesList.map((c) => Chip(
                      backgroundColor: const Color(0xFFF1F5F9),
                      label: Text(c, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(LucideIcons.x, size: 14),
                      onDeleted: () {
                        setState(() => _commoditiesList.remove(c));
                      },
                    )),
                ActionChip(
                  avatar: const Icon(LucideIcons.plus,
                      size: 14, color: Color(0xFF0F766E)),
                  label: const Text('Add Commodity',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w700)),
                  onPressed:
                      () => _promptAddItem('Add Handled Commodity', (val) {
                    if (val.isNotEmpty && !_commoditiesList.contains(val)) {
                      setState(() => _commoditiesList.add(val));
                    }
                  }),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  void _promptAddItem(String title, ValueChanged<String> onAdd) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name...',
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onAdd(textController.text.trim());
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER REUSABLE CARD & FIELD BUILDERS
  // ==========================================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required VoidCallback onEdit,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F7F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: const Color(0xFF0F766E)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Icon(LucideIcons.pencil,
                          size: 13, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildEditSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF0F766E)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  /// Equal-width fields, top aligned so a validation error under one field
  /// doesn't shift its neighbours.
  Widget _buildEditFieldRow({
    required double spacing,
    required List<Widget> children,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Expanded(child: children[i]),
        ],
      ],
    );
  }

  /// Width a dropdown needs to show [value] on one line, as the app renders it.
  double _dropdownRequiredWidth(BuildContext context, String value) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: _editDropdownTextStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width + _dropdownChromeWidth;
    painter.dispose();
    return width;
  }

  Widget _buildEditDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            // The dense button is one line tall; drop it only when the
            // selection needs a second line, so short values keep their height.
            final fitsOneLine = constraints.maxWidth >=
                _dropdownRequiredWidth(context, value);
            return DropdownButtonFormField<String>(
              initialValue: value,
              isExpanded: true,
              isDense: fitsOneLine,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              style: _editDropdownTextStyle,
              selectedItemBuilder: (context) => options
                  .map(
                    (o) => Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        o,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              items: options
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(
                        o,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildKeyValRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniDataBox({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: const Color(0xFF0F766E)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEditField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int? minLines,
    int maxLines = 1,
    String? suffixBadge,
    IconData? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
            ),
            suffixIcon: suffixBadge != null
                ? Container(
                    margin: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      suffixBadge,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  )
                : (suffixIcon != null
                    ? Icon(suffixIcon, size: 16, color: const Color(0xFF64748B))
                    : null),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
