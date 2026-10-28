import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../authentication/data/auth_repository.dart';
import '../../commodities/domain/master_commodity_data.dart';
import '../data/business_location_service.dart';
import '../data/invoice_document_service.dart';
import '../data/invoice_ocr_service.dart';
import '../data/seller_profile_repository.dart';
import '../domain/invoice_extracted_data.dart';
import '../domain/seller_bank_details.dart';
import '../domain/seller_profile_model.dart';
import '../domain/cheque_extracted_data.dart';
import '../../commodities/data/commodities_repository.dart';
import '../domain/seller_commodity_expertise.dart';
import 'profile_strings.dart';
import 'widgets/invoice_preview_dialog.dart';
import 'widgets/profile_review_confirmation_sheet.dart';

class SellerProfileScreen extends StatefulWidget {
  final SellerProfileRepository? profileRepository;
  final SecureStorageService? storageService;
  final AuthRepository? authRepository;
  final BusinessLocationService? locationService;
  final InvoiceOcrService? ocrService;
  final InvoiceDocumentService? documentService;
  final CommoditiesRepository? commoditiesRepository;
  final bool isInitialEdit;
  final bool initialScanInvoice;
  final Locale? forcedLocale;
  final bool? isHindi;
  final InvoiceExtractedData? initialExtractedInvoiceData;
  final SelectedInvoiceDocument? initialInvoiceDocument;

  const SellerProfileScreen({
    super.key,
    this.profileRepository,
    this.storageService,
    this.authRepository,
    this.locationService,
    this.ocrService,
    this.documentService,
    this.commoditiesRepository,
    this.isInitialEdit = false,
    this.initialScanInvoice = false,
    this.forcedLocale,
    this.isHindi,
    this.initialExtractedInvoiceData,
    this.initialInvoiceDocument,
  });

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  late final SellerProfileRepository _profileRepo;
  late final AuthRepository _authRepository;
  late final BusinessLocationService _locationService;
  late final InvoiceOcrService _ocrService;
  late final InvoiceDocumentService _documentService;
  late final CommoditiesRepository _commoditiesRepository;

  bool? _manualLanguageIsHindi;

  ProfileStrings _getStrings(BuildContext context) {
    if (_manualLanguageIsHindi != null) {
      return ProfileStrings(isHindi: _manualLanguageIsHindi!);
    }
    if (widget.isHindi != null) {
      return ProfileStrings(isHindi: widget.isHindi!);
    }
    if (widget.forcedLocale != null) {
      return ProfileStrings(isHindi: widget.forcedLocale!.languageCode == 'hi');
    }
    final locale = Localizations.maybeLocaleOf(context);
    return ProfileStrings(isHindi: locale?.languageCode == 'hi');
  }

  SellerProfileModel? _profile;
  List<SellerCommodityExpertise> _selectedExpertise = [];
  List<MasterCommodity> _allCatalogueCommodities = [];
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isDetectingLocation = false;
  String? _saveErrorMessage;
  String? _locationStatusMessage;
  bool _locationCertainty = true;
  final Set<String> _expandedSections = {};

  final _formKey = GlobalKey<FormState>();

  // Text Editing Controllers for Business Information
  late final TextEditingController _nameController;
  late final TextEditingController _companyController;
  late final TextEditingController _mobileController;
  late final TextEditingController _gstController;
  late final TextEditingController _officeAddressController;

  // Text Editing Controllers for Business Location (Shop / Warehouse / Godown)
  late final TextEditingController _locationNameController;
  late final TextEditingController _locationAddressController;
  late final TextEditingController _locationLocalityController;
  late final TextEditingController _locationPinCodeController;

  // Text Editing Controllers for Bank Details
  late final TextEditingController _bankHolderController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _bankAccountController;
  late final TextEditingController _bankIfscController;
  late final TextEditingController _bankBranchController;
  late final TextEditingController _bankMicrController;

  // State & District Dropdown Selections
  MasterState? _selectedState;
  MasterDistrict? _selectedDistrict;
  List<MasterDistrict> _filteredDistricts = [];

  // Coordinates internal retention
  double? _currentLat;
  double? _currentLng;
  bool _isGpsDetected = false;

  // Invoice & OCR states
  SelectedInvoiceDocument? _selectedInvoiceDocument;
  InvoiceExtractedData? _extractedInvoiceData;
  bool _isExtractingInvoice = false;
  String? _invoiceStatusNotice;
  bool _invoiceNoticeIsError = false;

  // Cheque & OCR states
  SelectedInvoiceDocument? _selectedChequeDocument;
  ChequeExtractedData? _extractedChequeData;
  bool _isExtractingCheque = false;
  String? _chequeStatusNotice;
  bool _chequeNoticeIsError = false;

  @override
  void initState() {
    super.initState();
    _profileRepo =
        widget.profileRepository ??
        SellerProfileRepository(storage: widget.storageService);
    _authRepository =
        widget.authRepository ?? AuthRepository(storage: widget.storageService);
    _locationService =
        widget.locationService ?? const BusinessLocationService();
    _ocrService = widget.ocrService ?? const InvoiceOcrService();
    _documentService = widget.documentService ?? InvoiceDocumentService();
    _commoditiesRepository =
        widget.commoditiesRepository ?? CommoditiesRepository();

    _nameController = TextEditingController();
    _companyController = TextEditingController();
    _mobileController = TextEditingController();
    _gstController = TextEditingController();
    _officeAddressController = TextEditingController();

    _locationNameController = TextEditingController();
    _locationAddressController = TextEditingController();
    _locationLocalityController = TextEditingController();
    _locationPinCodeController = TextEditingController();

    _bankHolderController = TextEditingController();
    _bankNameController = TextEditingController();
    _bankAccountController = TextEditingController();
    _bankIfscController = TextEditingController();
    _bankBranchController = TextEditingController();
    _bankMicrController = TextEditingController();

    _isEditing = widget.isInitialEdit || widget.initialScanInvoice;
    if (widget.initialExtractedInvoiceData != null) {
      _extractedInvoiceData = widget.initialExtractedInvoiceData;
      _selectedInvoiceDocument = widget.initialInvoiceDocument ??
          SelectedInvoiceDocument(
            localPath: 'sample_business_invoice.pdf',
            fileName: 'sample_business_invoice.pdf',
            fileSizeBytes: 2048,
            isUploaded: false,
          );
      _invoiceStatusNotice = widget.initialExtractedInvoiceData!.hasPinAddressConflict
          ? widget.initialExtractedInvoiceData!.pinConflictNotice
          : 'Invoice data extracted. Review and tap "Apply Suggestions" to prefill.';
    }
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _mobileController.dispose();
    _gstController.dispose();
    _officeAddressController.dispose();

    _locationNameController.dispose();
    _locationAddressController.dispose();
    _locationLocalityController.dispose();
    _locationPinCodeController.dispose();

    _bankHolderController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _bankBranchController.dispose();
    _bankMicrController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final savedLang = await _profileRepo.storage.getPreference('app_language_pref');
      if (savedLang != null && _manualLanguageIsHindi == null && mounted) {
        _manualLanguageIsHindi = savedLang == 'hi';
      }
      final profile = await _profileRepo.getProfile();
      if (!mounted) return;
      _populateControllers(profile);
      setState(() {
        _profile = profile;
        _selectedExpertise = List.from(profile.commodityExpertise);
        _isLoading = false;
      });

      unawaited(_loadCatalogueCommodities());

      if (widget.initialScanInvoice && mounted) {
        _startScanInvoiceFlow();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCatalogueCommodities() async {
    try {
      final catalogue = await _commoditiesRepository.getMasterCommodities();
      if (mounted) {
        setState(() {
          _allCatalogueCommodities = catalogue;
        });
      }
    } catch (_) {}
  }

  void _populateControllers(SellerProfileModel profile) {
    _nameController.text = profile.fullName;
    _companyController.text = profile.companyName;
    _mobileController.text = profile.mobile;
    _gstController.text = profile.companyGst;
    _officeAddressController.text = profile.officeAddress;

    final loc = profile.businessLocation;
    _locationNameController.text = loc.name;
    _locationAddressController.text = loc.addressLine;
    _locationLocalityController.text = loc.locality;
    _locationPinCodeController.text = loc.pinCode;

    _currentLat = loc.latitude;
    _currentLng = loc.longitude;
    _isGpsDetected = loc.isGpsDetected;

    final bank = profile.bankDetails;
    _bankHolderController.text = bank.accountHolderName;
    _bankNameController.text = bank.bankName;
    _bankAccountController.text = bank.accountNumber;
    _bankIfscController.text = bank.ifscCode;
    _bankBranchController.text = bank.branchName;
    _bankMicrController.text = bank.micrCode;

    if (profile.invoiceDocumentUrl != null &&
        profile.invoiceDocumentUrl!.isNotEmpty) {
      _selectedInvoiceDocument = SelectedInvoiceDocument(
        localPath: profile.invoiceDocumentUrl!,
        fileName: profile.invoiceDocumentName ?? 'persisted_business_invoice.pdf',
        fileSizeBytes: 0,
        isUploaded: true,
        remoteStoragePath: profile.invoiceDocumentUrl,
      );
    }

    if (profile.chequeDocumentUrl != null &&
        profile.chequeDocumentUrl!.isNotEmpty) {
      _selectedChequeDocument = SelectedInvoiceDocument(
        localPath: profile.chequeDocumentUrl!,
        fileName: profile.chequeDocumentName ?? 'persisted_cheque_leaf.jpg',
        fileSizeBytes: 0,
        isUploaded: true,
        remoteStoragePath: profile.chequeDocumentUrl,
      );
    }

    // Resolve State in verifiedStates catalog
    MasterState stateMatch = MasterCommodityData.verifiedStates.firstWhere(
      (s) =>
          s.id == loc.stateId ||
          s.name.toLowerCase() == loc.stateName.toLowerCase(),
      orElse: () => MasterCommodityData.verifiedStates.first,
    );
    _selectedState = stateMatch;

    // Filter districts for matched state
    _filteredDistricts = MasterCommodityData.verifiedDistricts
        .where((d) => d.stateId == stateMatch.id)
        .toList();

    // Resolve District in filtered districts
    MasterDistrict districtMatch = _filteredDistricts.firstWhere(
      (d) =>
          d.id == loc.districtId ||
          d.name.toLowerCase().contains(loc.districtName.toLowerCase()),
      orElse: () => _filteredDistricts.isNotEmpty
          ? _filteredDistricts.first
          : MasterCommodityData.verifiedDistricts.first,
    );
    _selectedDistrict = districtMatch;
  }

  void _onStateChanged(MasterState? newState) {
    if (newState == null) return;
    setState(() {
      _selectedState = newState;
      _filteredDistricts = MasterCommodityData.verifiedDistricts
          .where((d) => d.stateId == newState.id)
          .toList();
      _selectedDistrict = _filteredDistricts.isNotEmpty
          ? _filteredDistricts.first
          : null;
      _locationStatusMessage = null;
    });
  }

  Future<void> _handleUseCurrentLocation() async {
    setState(() {
      _isDetectingLocation = true;
      _locationStatusMessage = null;
    });

    try {
      final result = await _locationService.getCurrentLocation();
      if (!mounted) return;

      setState(() {
        _isDetectingLocation = false;
        _selectedState = result.state;
        _filteredDistricts = MasterCommodityData.verifiedDistricts
            .where((d) => d.stateId == result.state.id)
            .toList();
        _selectedDistrict = result.district;

        if (_locationLocalityController.text.trim().isEmpty) {
          _locationLocalityController.text = result.locality;
        }
        if (_locationPinCodeController.text.trim().isEmpty) {
          _locationPinCodeController.text = result.pinCode;
        }

        _currentLat = result.latitude;
        _currentLng = result.longitude;
        _isGpsDetected = true;
        _locationCertainty = result.isCertain;
        _locationStatusMessage = result.isCertain
            ? 'Location verified: ${result.district.name}, ${result.state.name}'
            : (result.message ??
                  'Approximate region detected. Please verify state and district.');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDetectingLocation = false;
        _locationCertainty = false;
        _locationStatusMessage =
            'Could not detect location. Please select state and district manually.';
      });
    }
  }

  void _showLocationPresetsSheet() {
    final presets = _locationService.getLocationPresets();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Trading Hub Godown',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Quickly configure your godown facility for prominent regional mandi hubs.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...presets.map((preset) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          LucideIcons.warehouse,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        preset['presetName'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${preset['warehouseAddress']} • ${preset['districtName']}, ${preset['stateName']}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _applyPreset(preset);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _applyPreset(Map<String, String> preset) {
    final stateId = preset['stateId'];
    final districtId = preset['districtId'];

    MasterState stateMatch = MasterCommodityData.verifiedStates.firstWhere(
      (s) => s.id == stateId,
      orElse: () => MasterCommodityData.verifiedStates.first,
    );

    List<MasterDistrict> matchingDistricts = MasterCommodityData
        .verifiedDistricts
        .where((d) => d.stateId == stateMatch.id)
        .toList();

    MasterDistrict districtMatch = matchingDistricts.firstWhere(
      (d) => d.id == districtId,
      orElse: () => matchingDistricts.isNotEmpty
          ? matchingDistricts.first
          : MasterCommodityData.verifiedDistricts.first,
    );

    setState(() {
      _selectedState = stateMatch;
      _filteredDistricts = matchingDistricts;
      _selectedDistrict = districtMatch;

      _locationNameController.text =
          preset['presetName'] ?? _locationNameController.text;
      _locationAddressController.text =
          preset['warehouseAddress'] ?? _locationAddressController.text;
      _locationLocalityController.text =
          preset['mandiName'] ?? _locationLocalityController.text;
      _locationCertainty = true;
      _locationStatusMessage = 'Selected trading hub: ${preset['presetName']}';
    });
  }

  void _enterEditMode({bool scanInvoice = false}) {
    if (_profile != null) {
      _populateControllers(_profile!);
    }
    setState(() {
      _isEditing = true;
      _saveErrorMessage = null;
      _locationStatusMessage = null;
    });
    if (scanInvoice) {
      _startScanInvoiceFlow();
    }
  }

  void _cancelEdit() {
    if (_profile != null) {
      _populateControllers(_profile!);
    }
    setState(() {
      _selectedExpertise = List.from(_profile?.commodityExpertise ?? []);
      _isEditing = false;
      _saveErrorMessage = null;
      _locationStatusMessage = null;
      _extractedInvoiceData = null;
      _invoiceStatusNotice = null;
      _selectedChequeDocument = null;
      _extractedChequeData = null;
      _chequeStatusNotice = null;
    });
  }

  void _startScanInvoiceFlow() {
    final s = _getStrings(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.scanBusinessInvoice,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                s.scanInvoiceSubtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 16),
              ListTile(
                key: const Key('modal_option_camera'),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(LucideIcons.camera, color: AppColors.primary, size: 20),
                ),
                title: Text(s.camera, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(s.takePhotoCameraSub, style: const TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleScanCamera();
                },
              ),
              ListTile(
                key: const Key('modal_option_gallery'),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(LucideIcons.image, color: AppColors.primary, size: 20),
                ),
                title: Text(s.gallery, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(s.chooseGallerySub, style: const TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleScanGallery();
                },
              ),
              ListTile(
                key: const Key('modal_option_file'),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(LucideIcons.fileText, color: AppColors.primary, size: 20),
                ),
                title: Text(s.pdfOrFile, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(s.selectPdfSub, style: const TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleScanFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleScanCamera() async {
    final s = _getStrings(context);
    try {
      final doc = await _documentService.captureFromCamera();
      if (doc != null && mounted) {
        setState(() {
          _selectedInvoiceDocument = doc;
          _isEditing = true;
        });
        await _processInvoiceExtraction(doc);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _invoiceStatusNotice = s.errCameraPermission;
        _invoiceNoticeIsError = true;
      });
    }
  }

  Future<void> _handleScanGallery() async {
    final s = _getStrings(context);
    try {
      final doc = await _documentService.pickFromGallery();
      if (doc != null && mounted) {
        setState(() {
          _selectedInvoiceDocument = doc;
          _isEditing = true;
        });
        await _processInvoiceExtraction(doc);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _invoiceStatusNotice = s.errGalleryPermission;
        _invoiceNoticeIsError = true;
      });
    }
  }

  Future<void> _handleScanFile() async {
    final s = _getStrings(context);
    try {
      final doc = await _documentService.pickDocumentFile();
      if (doc != null && mounted) {
        setState(() {
          _selectedInvoiceDocument = doc;
          _isEditing = true;
        });
        await _processInvoiceExtraction(doc);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _invoiceStatusNotice = s.errFileSelection;
        _invoiceNoticeIsError = true;
      });
    }
  }

  Future<void> _processInvoiceExtraction(SelectedInvoiceDocument doc) async {
    final s = _getStrings(context);
    setState(() {
      _isExtractingInvoice = true;
      _invoiceStatusNotice = null;
      _invoiceNoticeIsError = false;
    });

    final res = await _ocrService.extractFromFile(File(doc.localPath));
    if (!mounted) return;

    setState(() {
      _isExtractingInvoice = false;
      _extractedInvoiceData = res.data;
      if (res.isSuccess) {
        _invoiceStatusNotice = s.ocrSuccessNotice;
        _invoiceNoticeIsError = false;
      } else if (res.isEngineBlocked) {
        _invoiceStatusNotice = res.errorMessage ?? s.ocrBlockedNotice;
        _invoiceNoticeIsError = false;
      } else {
        _invoiceStatusNotice = res.errorMessage ?? s.textExtractionFailed;
        _invoiceNoticeIsError = true;
      }
    });
  }

  void _applyExtractedSuggestions() {
    final s = _getStrings(context);
    final data = _extractedInvoiceData;
    if (data == null) return;

    setState(() {
      if (data.firmName != null && data.firmName!.isNotEmpty) {
        _companyController.text = data.firmName!;
      }
      if (data.gstin != null && data.gstin!.isNotEmpty) {
        _gstController.text = data.gstin!;
      }
      if (data.officeAddress != null && data.officeAddress!.isNotEmpty) {
        _officeAddressController.text = data.officeAddress!;
        _locationAddressController.text = data.officeAddress!;
        _locationNameController.text = data.officeAddress!;
      }
      if (data.pinCode != null && data.pinCode!.isNotEmpty) {
        _locationPinCodeController.text = data.pinCode!;
      }
      if (data.contactMobile != null && data.contactMobile!.isNotEmpty) {
        _mobileController.text = data.contactMobile!;
      }

      // Auto-suggest State and District from Indian PIN resolution
      if (data.state != null && data.state!.isNotEmpty) {
        final stateMatch = MasterCommodityData.verifiedStates.firstWhere(
          (st) => st.name.toLowerCase() == data.state!.toLowerCase(),
          orElse: () => _selectedState ?? MasterCommodityData.verifiedStates.first,
        );
        _selectedState = stateMatch;
        _filteredDistricts = MasterCommodityData.verifiedDistricts
            .where((d) => d.stateId == stateMatch.id)
            .toList();

        if (data.district != null && data.district!.isNotEmpty) {
          final districtMatch = _filteredDistricts.firstWhere(
            (d) => d.name.toLowerCase().contains(data.district!.toLowerCase()),
            orElse: () => _filteredDistricts.isNotEmpty
                ? _filteredDistricts.first
                : (_selectedDistrict ?? MasterCommodityData.verifiedDistricts.first),
          );
          _selectedDistrict = districtMatch;
        }
      }

      // Bank details
      if (data.accountHolderName != null && data.accountHolderName!.isNotEmpty) {
        _bankHolderController.text = data.accountHolderName!;
      }
      if (data.bankName != null && data.bankName!.isNotEmpty) {
        _bankNameController.text = data.bankName!;
      }
      if (data.accountNumber != null && data.accountNumber!.isNotEmpty) {
        _bankAccountController.text = data.accountNumber!;
      }
      if (data.ifscCode != null && data.ifscCode!.isNotEmpty) {
        _bankIfscController.text = data.ifscCode!;
      }
      if (data.branchName != null && data.branchName!.isNotEmpty) {
        _bankBranchController.text = data.branchName!;
      }

      if (data.hasPinAddressConflict && data.pinConflictNotice != null) {
        _invoiceStatusNotice = '${s.pinConflictNotice} (${data.pinConflictNotice})';
        _invoiceNoticeIsError = false;
      } else if (data.hasArithmeticMismatch && data.arithmeticMismatchNotice != null) {
        _invoiceStatusNotice = '⚠️ ${data.arithmeticMismatchNotice}';
        _invoiceNoticeIsError = false;
      } else {
        _invoiceStatusNotice = s.invoiceSourceNotice;
        _invoiceNoticeIsError = false;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.suggestionsAppliedSnack),
        backgroundColor: AppColors.info,
      ),
    );
  }

  void _openInvoicePreviewDialog() {
    final s = _getStrings(context);
    final doc = _selectedInvoiceDocument;
    if (doc == null) return;

    showDialog(
      context: context,
      builder: (ctx) => InvoicePreviewDialog(
        document: doc,
        strings: s,
        onRetakeCamera: _handleScanCamera,
        onReplaceGallery: _handleScanGallery,
        onRemove: () {
          setState(() {
            _selectedInvoiceDocument = null;
            _extractedInvoiceData = null;
            _invoiceStatusNotice = null;
          });
        },
      ),
    );
  }

  Future<void> _handleChequeCamera() async {
    final s = _getStrings(context);
    try {
      final doc = await _documentService.captureFromCamera();
      if (doc != null && mounted) {
        setState(() {
          _selectedChequeDocument = doc;
          _isEditing = true;
        });
        await _processChequeExtraction(doc);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chequeStatusNotice = s.errCameraPermission;
        _chequeNoticeIsError = true;
      });
    }
  }

  Future<void> _handleChequeGallery() async {
    final s = _getStrings(context);
    try {
      final doc = await _documentService.pickFromGallery();
      if (doc != null && mounted) {
        setState(() {
          _selectedChequeDocument = doc;
          _isEditing = true;
        });
        await _processChequeExtraction(doc);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chequeStatusNotice = s.errGalleryPermission;
        _chequeNoticeIsError = true;
      });
    }
  }

  Future<void> _processChequeExtraction(SelectedInvoiceDocument doc) async {
    final s = _getStrings(context);
    setState(() {
      _isExtractingCheque = true;
      _chequeStatusNotice = null;
      _chequeNoticeIsError = false;
    });

    final res = await _ocrService.extractChequeFromFile(File(doc.localPath));
    if (!mounted) return;

    setState(() {
      _isExtractingCheque = false;
      _extractedChequeData = res.data;
      if (res.isSuccess) {
        _chequeStatusNotice = s.chequeExtractedSuccess;
        _chequeNoticeIsError = false;
        _applyChequeExtractedSuggestions(showSnack: false);
      } else if (res.isEngineBlocked) {
        _chequeStatusNotice = res.errorMessage ?? s.ocrBlockedNotice;
        _chequeNoticeIsError = false;
      } else {
        _chequeStatusNotice = res.errorMessage ?? s.chequeExtractionFailed;
        _chequeNoticeIsError = true;
      }
    });
  }

  void _applyChequeExtractedSuggestions({bool showSnack = true}) {
    final s = _getStrings(context);
    final data = _extractedChequeData;
    if (data == null) return;

    setState(() {
      if (data.accountHolderName != null && data.accountHolderName!.isNotEmpty) {
        _bankHolderController.text = data.accountHolderName!;
      }
      if (data.bankName != null && data.bankName!.isNotEmpty) {
        _bankNameController.text = data.bankName!;
      }
      if (data.accountNumber != null && data.accountNumber!.isNotEmpty) {
        _bankAccountController.text = data.accountNumber!;
      }
      if (data.ifscCode != null && data.ifscCode!.isNotEmpty) {
        _bankIfscController.text = data.ifscCode!;
      }
      if (data.branchName != null && data.branchName!.isNotEmpty) {
        _bankBranchController.text = data.branchName!;
      }
      if (data.micrCode != null && data.micrCode!.isNotEmpty) {
        _bankMicrController.text = data.micrCode!;
      }
      _chequeStatusNotice = s.chequeSourceNotice;
    });

    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.chequeExtractedSuccess),
          backgroundColor: AppColors.info,
        ),
      );
    }
  }

  void _removeCheque() {
    setState(() {
      _selectedChequeDocument = null;
      _extractedChequeData = null;
      _chequeStatusNotice = null;
    });
  }

  void _openChequePreviewDialog() {
    final s = _getStrings(context);
    final doc = _selectedChequeDocument;
    if (doc == null) return;

    showDialog(
      context: context,
      builder: (ctx) => InvoicePreviewDialog(
        document: doc,
        strings: s,
        onRetakeCamera: _handleChequeCamera,
        onReplaceGallery: _handleChequeGallery,
        onRemove: _removeCheque,
      ),
    );
  }

  void _handleEnterBankManually() {
    setState(() {
      _chequeStatusNotice = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_getStrings(context).isHindi
            ? 'मैन्युअल प्रविष्टि: कृपया बैंक विवरण फ़ील्ड में दर्ज करें।'
            : 'Manual entry: Please enter your bank details below.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Triggers the mandatory explicit confirmation step.
  /// STRICT MANDATE: Never writes to database before seller confirms in this dialog.
  void _initiateSaveWorkflow() {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final current = _profile ??
        const SellerProfileModel(
          id: '20000000-0000-0000-0000-000000000001',
          fullName: 'Seller Lead',
          email: 'seller@demo.com',
          role: 'seller',
        );

    final updatedLocation = current.businessLocation.copyWith(
      name: _locationNameController.text.trim(),
      addressLine: _locationAddressController.text.trim(),
      locality: _locationLocalityController.text.trim(),
      stateId: _selectedState?.id ?? current.businessLocation.stateId,
      stateName: _selectedState?.name ?? current.businessLocation.stateName,
      districtId: _selectedDistrict?.id ?? current.businessLocation.districtId,
      districtName:
          _selectedDistrict?.name ?? current.businessLocation.districtName,
      pinCode: _locationPinCodeController.text.trim(),
      latitude: _currentLat,
      longitude: _currentLng,
      isGpsDetected: _isGpsDetected,
    );

    final updatedBank = SellerBankDetails(
      accountHolderName: _bankHolderController.text.trim(),
      bankName: _bankNameController.text.trim(),
      accountNumber: _bankAccountController.text.trim(),
      ifscCode: _bankIfscController.text.trim().toUpperCase(),
      branchName: _bankBranchController.text.trim(),
      micrCode: _bankMicrController.text.trim(),
      isVerified: false, // Strictly unverified
      verificationStatus: 'unverified',
    );

    final proposed = current.copyWith(
      fullName: _nameController.text.trim(),
      companyName: _companyController.text.trim(),
      businessIdentifier: _companyController.text.trim(),
      versionIdentifier: _extractedInvoiceData?.documentType ?? current.versionIdentifier,
      mobile: _mobileController.text.trim(),
      companyGst: _gstController.text.trim().toUpperCase(),
      officeAddress: _officeAddressController.text.trim(),
      state: _selectedState?.name ?? current.state,
      district: _selectedDistrict?.name ?? current.district,
      primaryMandi: _locationLocalityController.text.trim().isNotEmpty
          ? _locationLocalityController.text.trim()
          : current.primaryMandi,
      businessLocation: updatedLocation,
      bankDetails: updatedBank,
      commodityExpertise: List.from(_selectedExpertise),
      invoiceDocumentUrl: _selectedInvoiceDocument?.localPath,
      invoiceDocumentName: _selectedInvoiceDocument?.fileName,
      chequeDocumentUrl: _selectedChequeDocument?.localPath,
      chequeDocumentName: _selectedChequeDocument?.fileName,
    );

    // Present mandatory confirmation sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProfileReviewConfirmationSheet(
        key: const Key('profile_review_confirmation_sheet'),
        currentProfile: current,
        proposedProfile: proposed,
        isInvoiceAssisted: _selectedInvoiceDocument != null,
        isChequeAssisted: _selectedChequeDocument != null,
        onConfirm: () => _executeAuthoritativeSave(proposed),
        onCancel: () {},
      ),
    );
  }

  /// Authoritatively persist confirmed changes to server and local cache.
  Future<void> _executeAuthoritativeSave(SellerProfileModel proposed) async {
    setState(() {
      _isSaving = true;
      _saveErrorMessage = null;
    });

    try {
      var toSave = proposed;
      // Handle private storage upload if new document attached
      if (_selectedInvoiceDocument != null && !_selectedInvoiceDocument!.isUploaded) {
        try {
          final uploaded = await _documentService.uploadDocument(
            document: _selectedInvoiceDocument!,
            companyId: proposed.companyId.isNotEmpty ? proposed.companyId : proposed.id,
          );
          _selectedInvoiceDocument = uploaded;
          toSave = toSave.copyWith(
            invoiceDocumentUrl: uploaded.remoteStoragePath,
            invoiceDocumentName: uploaded.fileName,
          );
        } catch (uploadErr) {
          debugPrint('Document upload notice: $uploadErr');
        }
      }

      // Handle private storage upload if new cheque attached
      if (_selectedChequeDocument != null && !_selectedChequeDocument!.isUploaded) {
        try {
          final uploadedCheque = await _documentService.uploadDocument(
            document: _selectedChequeDocument!,
            companyId: proposed.companyId.isNotEmpty ? proposed.companyId : proposed.id,
          );
          _selectedChequeDocument = uploadedCheque;
          toSave = toSave.copyWith(
            chequeDocumentUrl: uploadedCheque.remoteStoragePath,
            chequeDocumentName: uploadedCheque.fileName,
          );
        } catch (uploadErr) {
          debugPrint('Cheque document upload notice: $uploadErr');
        }
      }

      final opType = _selectedInvoiceDocument != null && _selectedChequeDocument != null
          ? 'INVOICE_AND_CHEQUE_ASSISTED_EDIT'
          : _selectedChequeDocument != null
              ? 'CHEQUE_ASSISTED_EDIT'
              : _selectedInvoiceDocument != null
                  ? 'INVOICE_ASSISTED_EDIT'
                  : 'MANUAL_EDIT';

      final saved = await _profileRepo.updateProfile(
        toSave,
        operationType: opType,
      );

      if (!mounted) return;

      setState(() {
        _profile = saved;
        _isSaving = false;
        _isEditing = false;
        _selectedInvoiceDocument = _selectedInvoiceDocument?.copyWith(isUploaded: true);
        _selectedChequeDocument = _selectedChequeDocument?.copyWith(isUploaded: true);
      });

      final s = _getStrings(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.profileSavedSuccess),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final s = _getStrings(context);
      setState(() {
        _isSaving = false;
        _saveErrorMessage = '${s.profileSaveFailed} ${e.toString()}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${s.profileSaveFailed} ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    final s = _getStrings(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.signOut),
        content: Text(
          s.isHindi
              ? 'क्या आप वाकई आरएम-सेलर डेस्क से लॉग आउट करना चाहते हैं?'
              : 'Are you sure you want to sign out of the RMSeller desk?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              s.signOut,
              style: const TextStyle(color: Colors.white),
            ),
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
    final s = _getStrings(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final profile =
        _profile ??
        const SellerProfileModel(
          id: '20000000-0000-0000-0000-000000000001',
          fullName: 'Seller Lead',
          email: 'seller@demo.com',
          role: 'seller',
        );

    return PopScope(
      canPop: !_isEditing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscardChanges();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          titleSpacing: 8,
          title: Text(
            _isEditing ? s.editProfile : s.sellerProfileTitle,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            // Instant Bilingual Language Switcher Button (English <-> हिन्दी)
            TextButton(
              key: const Key('toggle_profile_language_button'),
              onPressed: () {
                final nextIsHindi = !s.isHindi;
                setState(() {
                  _manualLanguageIsHindi = nextIsHindi;
                });
                unawaited(
                  _profileRepo.storage.savePreference(
                    'app_language_pref',
                    nextIsHindi ? 'hi' : 'en',
                  ),
                );
              },
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.languages, size: 13),
                  const SizedBox(width: 2),
                  Text(
                    s.isHindi ? 'EN' : 'हिन्दी',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (_isEditing) ...[
              OutlinedButton(
                key: const Key('cancel_profile_button'),
                onPressed: _isSaving ? null : _confirmDiscardChanges,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(s.cancel, style: const TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 3),
              ElevatedButton(
                key: const Key('save_profile_button'),
                onPressed: _isSaving ? null : _initiateSaveWorkflow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        s.save,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(width: 4),
            ] else ...[
              PopupMenuButton<String>(
                key: const Key('profile_overflow_menu'),
                icon: const Icon(LucideIcons.ellipsisVertical),
                tooltip: 'More options',
                onSelected: (value) {
                  if (value == 'logout') {
                    _handleSignOut();
                  } else if (value == 'scan_invoice') {
                    _enterEditMode(scanInvoice: true);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    key: const Key('profile_menu_scan_invoice'),
                    value: 'scan_invoice',
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.scanLine,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            s.scanBusinessInvoice,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    key: const Key('profile_menu_logout'),
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.logOut,
                          size: 18,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            s.signOut,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        body: _isEditing ? _buildEditView(profile, s) : _buildProfileView(profile, s),
      ),
    );
  }

  bool get _hasUnsavedChanges {
    final p = _profile;
    if (p == null) return false;
    final loc = p.businessLocation;
    final bank = p.bankDetails;
    return _nameController.text.trim() != p.fullName ||
        _companyController.text.trim() != p.companyName ||
        _mobileController.text.trim() != p.mobile ||
        _gstController.text.trim().toUpperCase() !=
            p.companyGst.toUpperCase() ||
        _officeAddressController.text.trim() != p.officeAddress ||
        _locationNameController.text.trim() != loc.name ||
        _locationAddressController.text.trim() != loc.addressLine ||
        _locationLocalityController.text.trim() != loc.locality ||
        _locationPinCodeController.text.trim() != loc.pinCode ||
        _bankHolderController.text.trim() != bank.accountHolderName ||
        _bankNameController.text.trim() != bank.bankName ||
        _bankAccountController.text.trim() != bank.accountNumber ||
        _bankIfscController.text.trim().toUpperCase() != bank.ifscCode.toUpperCase() ||
        _bankBranchController.text.trim() != bank.branchName ||
        _bankMicrController.text.trim() != bank.micrCode ||
        !_areExpertiseListsEqual(_selectedExpertise, p.commodityExpertise) ||
        (_selectedInvoiceDocument != null && !_selectedInvoiceDocument!.isUploaded) ||
        (_selectedChequeDocument != null && !_selectedChequeDocument!.isUploaded);
  }

  bool _areExpertiseListsEqual(
    List<SellerCommodityExpertise> a,
    List<SellerCommodityExpertise> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || !a[i].matchesNormalized(b[i].commodityName)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges) {
      _cancelEdit();
      return;
    }
    final s = _getStrings(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.discardDialogTitle),
        content: Text(s.discardDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.continueEditing),
          ),
          TextButton(
            key: const Key('discard_changes_button'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              s.discard,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (discard == true && mounted) _cancelEdit();
  }

  Widget _buildProfileView(SellerProfileModel profile, ProfileStrings s) {
    final loc = profile.businessLocation;
    final bank = profile.bankDetails;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        // Compact business header
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primaryContainer,
                    child: const Icon(
                      LucideIcons.store,
                      size: 24,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.companyName.isNotEmpty
                              ? profile.companyName
                              : 'Bikaner Agro Processing Ltd',
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.fullName.isNotEmpty
                              ? profile.fullName
                              : 'Seller Lead',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: profile.isVerified
                                ? AppColors.successBackground
                                : AppColors.warningBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                profile.isVerified
                                    ? LucideIcons.shieldCheck
                                    : LucideIcons.alertTriangle,
                                size: 13,
                                color: profile.isVerified
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  profile.isVerified
                                      ? (s.isHindi ? 'सत्यापित विक्रेता' : 'Verified Seller Enterprise')
                                      : (s.isHindi ? 'सत्यापन लंबित' : 'Pending Desk Verification'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: profile.isVerified
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    key: const Key('edit_profile_button'),
                    onPressed: () => _enterEditMode(),
                    icon: const Icon(LucideIcons.pencil, size: 14),
                    label: Text(s.isHindi ? 'संपादित करें' : 'Edit'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Scan Business Invoice Banner
              InkWell(
                key: const Key('btn_scan_invoice_banner'),
                onTap: () => _enterEditMode(scanInvoice: true),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.scanLine, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.scanBusinessInvoice,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary),
                            ),
                            Text(
                              s.scanInvoiceSubtitle,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Section 1: Business Details
        _buildAccordion(
          id: 'business',
          key: const Key('profile_section_business'),
          icon: LucideIcons.building,
          title: s.businessDetails,
          subtitle: s.businessIdentitySub,
          children: [
            _buildInfoRow(LucideIcons.user, s.fullName, profile.fullName, s),
            _buildInfoRow(LucideIcons.store, s.businessName, profile.companyName, s),
            _buildInfoRow(LucideIcons.phone, s.mobileNumber, profile.mobile, s),
            _buildInfoRow(LucideIcons.mail, s.email, profile.email, s),
            _buildInfoRow(LucideIcons.receipt, s.gstinLabel, profile.companyGst, s),
            _buildInfoRow(LucideIcons.building2, s.corporateOfficeHqAddress, profile.officeAddress, s),
          ],
        ),

        // Section 2: Personal & Account Details
        _buildAccordion(
          id: 'personal',
          key: const Key('profile_section_personal'),
          icon: LucideIcons.user,
          title: s.personalContactDetails,
          subtitle: s.contactDetailsSub,
          children: [
            _buildInfoRow(LucideIcons.user, s.fullName, profile.fullName, s),
            _buildInfoRow(LucideIcons.phone, s.mobileNumber, profile.mobile, s),
            _buildInfoRow(LucideIcons.mail, s.email, profile.email, s),
            _buildInfoRow(LucideIcons.shield, s.role, s.sellerRoleTitle, s),
          ],
        ),

        // Section 3: Business Address (Shop & Godown)
        _buildAccordion(
          id: 'location',
          key: const Key('business_location_view_card'),
          icon: LucideIcons.mapPin,
          title: s.businessLocationTitle,
          subtitle: s.businessLocationSub,
          trailing: loc.isGpsDetected
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    s.gpsLinked,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                )
              : null,
          children: [
            _buildInfoRow(LucideIcons.warehouse, s.locationNameLabel, loc.name, s),
            _buildInfoRow(LucideIcons.map, s.streetAddressLabel, loc.addressLine, s),
            _buildInfoRow(LucideIcons.navigation, s.localityLandmarkLabel, loc.locality, s),
            _buildInfoRow(
              LucideIcons.landmark,
              s.districtLabel,
              '${loc.districtName}, ${loc.stateName}',
              s,
            ),
            _buildInfoRow(LucideIcons.hash, s.pinCodeLabel, loc.pinCode, s),
          ],
        ),

        // Section 4: Bank Details
        _buildAccordion(
          id: 'bank',
          key: const Key('profile_section_bank'),
          icon: LucideIcons.landmark,
          title: s.bankDetailsTitle,
          subtitle: bank.isConfigured
              ? '${bank.bankName} (${bank.maskedAccountNumber})'
              : (s.isHindi ? 'निपटान बैंक खाता जोड़ें' : 'Add settlement bank account'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: bank.isVerified ? AppColors.successBackground : AppColors.warningBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              bank.isVerified ? s.verifiedBadge : s.unverifiedBadge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: bank.isVerified ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
          children: [
            _buildInfoRow(LucideIcons.userCheck, s.beneficiary, bank.accountHolderName, s),
            _buildInfoRow(LucideIcons.building, s.bank, bank.bankName, s),
            _buildInfoRow(LucideIcons.creditCard, s.accountNumber, bank.maskedAccountNumber, s),
            _buildInfoRow(LucideIcons.binary, s.ifscCode, bank.ifscCode, s),
            if (bank.branchName.isNotEmpty)
              _buildInfoRow(LucideIcons.mapPin, s.branchNameOptional, bank.branchName, s),
            if (bank.micrCode.isNotEmpty)
              _buildInfoRow(LucideIcons.hash, s.micrCode, bank.micrCode, s),
            const SizedBox(height: 6),
            Text(
              s.bankPrivacyNotice,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight, fontStyle: FontStyle.italic),
            ),
          ],
        ),

        // Section 5: My Commodity Expertise
        _buildAccordion(
          id: 'expertise',
          key: const Key('profile_section_commodity_expertise'),
          icon: LucideIcons.sprout,
          title: s.myCommodityExpertiseTitle,
          subtitle: profile.commodityExpertise.isEmpty
              ? (s.isHindi ? 'कोई कमोडिटी निर्दिष्ट नहीं' : 'No commodities specified')
              : '${profile.commodityExpertise.length} ${s.isHindi ? "कमोडिटी व्यापार में" : "commodities traded"}',
          trailing: profile.commodityExpertise.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${profile.commodityExpertise.length} ${s.isHindi ? "चयनित" : "Selected"}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : null,
          children: [
            if (profile.commodityExpertise.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  s.noExpertiseSelected,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profile.commodityExpertise.map((exp) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: exp.isApproved
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.warning.withValues(alpha: 0.15),
                      child: Icon(
                        exp.isApproved ? LucideIcons.check : LucideIcons.clock,
                        size: 12,
                        color: exp.isApproved
                            ? AppColors.primary
                            : AppColors.warning,
                      ),
                    ),
                    label: Text(
                      exp.isApproved
                          ? exp.commodityName
                          : '${exp.commodityName} ${s.isHindi ? "(सत्यापन लंबित)" : "(Pending)"}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: exp.isApproved
                            ? AppColors.textPrimaryLight
                            : AppColors.warning,
                      ),
                    ),
                    backgroundColor: AppColors.surfaceLight,
                    side: BorderSide(
                      color: exp.isApproved
                          ? AppColors.borderLight
                          : AppColors.warning.withValues(alpha: 0.4),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 8),
            Text(
              s.isHindi
                  ? 'प्राथमिकता सूचना: पोस्टिंग स्क्रीन पर त्वरित लिस्टिंग के लिए विशेषज्ञता वाली कमोडिटीज पहले दिखेंगी।'
                  : 'Priority Notice: Expertise commodities appear first under "My Expertise" on the posting screen for quick listing creation.',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),

        // Section 6: Documents & Invoice
        _buildAccordion(
          id: 'documents',
          key: const Key('profile_section_documents'),
          icon: LucideIcons.fileCheck,
          title: s.documentsAndInvoice,
          subtitle: profile.hasInvoiceDocument
              ? (profile.invoiceDocumentName ?? s.attachedInvoiceSubtitle)
              : s.documentsSubtitle,
          children: [
            if (_selectedInvoiceDocument != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.fileText, color: AppColors.primary),
                title: Text(_selectedInvoiceDocument!.fileName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(_selectedInvoiceDocument!.isUploaded ? s.serverVerifiedDocument : s.draftDocument),
                trailing: TextButton(
                  onPressed: _openInvoicePreviewDialog,
                  child: Text(s.inspect),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextButton.icon(
                  key: const Key('btn_attach_invoice_profile_view'),
                  onPressed: () => _enterEditMode(scanInvoice: true),
                  icon: const Icon(LucideIcons.upload, size: 16),
                  label: Text(s.attachBusinessInvoice),
                ),
              ),
          ],
        ),

        // Section 7: Trading Desk Rules
        _buildAccordion(
          id: 'rules',
          key: const Key('profile_section_rules'),
          icon: LucideIcons.fileText,
          title: s.tradingDeskRules,
          subtitle: s.tradingDeskRulesSub,
          children: [
            Text(
              s.tradingDeskRulesContent,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
          ],
        ),

        // Section 8: App Preferences
        _buildAccordion(
          id: 'prefs',
          key: const Key('profile_section_preferences'),
          icon: LucideIcons.settings,
          title: s.appPreferences,
          subtitle: s.appPreferencesSub,
          children: [
            Text(
              s.appPreferencesDesc,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('profile_open_settings'),
                onPressed: () => context.push('/settings'),
                icon: const Icon(LucideIcons.settings, size: 16),
                label: Text(s.openSettings),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccordion({
    required String id,
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
    Widget? trailing,
  }) {
    final expanded = _expandedSections.contains(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        key: key,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() {
                expanded
                    ? _expandedSections.remove(id)
                    : _expandedSections.add(id);
              }),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: AppColors.info),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTypography.titleSmall),
                        if (!expanded)
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    trailing,
                    const SizedBox(width: 6),
                  ],
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      LucideIcons.chevronDown,
                      size: 20,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [const Divider(height: 20), ...children],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditView(SellerProfileModel profile, ProfileStrings s) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_saveErrorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.4),
                ),
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
                      _saveErrorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _initiateSaveWorkflow,
                    child: Text(s.isHindi ? 'पुनः प्रयास करें' : 'Retry'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Invoice Scanning Card (Phase 2 & Phase 3)
          AppCard(
            key: const Key('edit_invoice_document_card'),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.scanLine, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.scanBusinessInvoice,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    if (_isExtractingInvoice) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  s.isHindi
                      ? 'व्यवसाय का बिल स्कैन करें या चुनें। निकाली गई जानकारी आपके स्पष्ट सत्यापन के लिए फॉर्म में भरी जाएगी।'
                      : 'Capture or pick a business invoice. Values prefill review fields for your explicit confirmation.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 12),

                // Intake Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('btn_scan_invoice_camera'),
                        onPressed: _isExtractingInvoice ? null : _handleScanCamera,
                        icon: const Icon(LucideIcons.camera, size: 16),
                        label: Text(s.camera, style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('btn_scan_invoice_gallery'),
                        onPressed: _isExtractingInvoice ? null : _handleScanGallery,
                        icon: const Icon(LucideIcons.image, size: 16),
                        label: Text(s.gallery, style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('btn_scan_invoice_file'),
                        onPressed: _isExtractingInvoice ? null : _handleScanFile,
                        icon: const Icon(LucideIcons.fileText, size: 16),
                        label: Text(s.pdfOrFile, style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                      ),
                    ),
                  ],
                ),

                // Tappable Attached Preview
                if (_selectedInvoiceDocument != null) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    key: const Key('invoice_attached_preview_card'),
                    onTap: _openInvoicePreviewDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.fileText, color: AppColors.primary, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedInvoiceDocument!.fileName,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _selectedInvoiceDocument!.isUploaded
                                      ? (s.isHindi ? 'सर्वर पर सत्यापित दस्तावेज़' : 'Server Verified Document')
                                      : (s.isHindi ? 'स्थानीय ड्राफ्ट • जांचने / बदलने के लिए टैप करें' : 'Local draft • Tap to inspect / retake'),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                ),
                              ],
                            ),
                          ),
                          const Icon(LucideIcons.externalLink, size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ],

                // Extraction Notice Banner
                if (_invoiceStatusNotice != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _invoiceNoticeIsError ? AppColors.errorBackground : AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _invoiceNoticeIsError ? AppColors.error.withValues(alpha: 0.4) : AppColors.info.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _invoiceNoticeIsError ? LucideIcons.alertCircle : LucideIcons.info,
                          size: 16,
                          color: _invoiceNoticeIsError ? AppColors.error : AppColors.info,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _invoiceStatusNotice!,
                            style: TextStyle(
                              fontSize: 11,
                              color: _invoiceNoticeIsError ? AppColors.error : AppColors.info,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Apply Suggestions Button (If extracted)
                if (_extractedInvoiceData != null && !_extractedInvoiceData!.isEmpty) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    key: const Key('btn_apply_invoice_suggestions'),
                    onPressed: _applyExtractedSuggestions,
                    icon: const Icon(LucideIcons.sparkles, size: 15),
                    label: Text(s.applySuggestions),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 36),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          _buildExpertiseEditCard(s),
          const SizedBox(height: 12),

          _buildEditGroup(
            icon: LucideIcons.store,
            title: s.businessDetails,
            children: [
              TextFormField(
                key: const Key('edit_company_name_field'),
                controller: _companyController,
                decoration: InputDecoration(
                  labelText: '${s.businessName} *',
                  hintText: s.companyHint,
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 2) {
                    return s.errBusinessNameRequired;
                  }
                  return null;
                },
              ),
              TextFormField(
                key: const Key('edit_office_address_field'),
                controller: _officeAddressController,
                maxLines: null,
                decoration: InputDecoration(
                  labelText: s.corporateOfficeHqAddress,
                  hintText: s.hqAddressHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),

          _buildEditGroup(
            icon: LucideIcons.contact,
            title: s.personalContactDetails,
            children: [
              TextFormField(
                key: const Key('edit_full_name_field'),
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '${s.fullName} *',
                  hintText: s.fullNameHint,
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 2) {
                    return s.isHindi
                        ? 'पूरा नाम आवश्यक है (कम से कम 2 अक्षर)'
                        : 'Full name is required (minimum 2 characters)';
                  }
                  return null;
                },
              ),
              TextFormField(
                key: const Key('edit_mobile_field'),
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: '${s.mobileNumber} *',
                  hintText: s.mobileHint,
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return s.errInvalidMobile;
                  }
                  final clean = val.replaceAll(RegExp(r'[\s\-+]'), '');
                  final phoneRegex = RegExp(r'^(?:91)?[6-9]\d{9}$');
                  if (!phoneRegex.hasMatch(clean)) {
                    return s.errInvalidMobile;
                  }
                  return null;
                },
              ),
              TextFormField(
                key: const Key('edit_email_field_readonly'),
                initialValue: profile.email,
                enabled: false,
                decoration: InputDecoration(
                  labelText: s.isHindi ? 'व्यावसायिक ईमेल' : 'Business Email',
                  helperText: s.isHindi ? 'लॉगिन ईमेल — यहाँ से बदला नहीं जा सकता' : 'Login email — cannot be changed here',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          _buildEditGroup(
            icon: LucideIcons.fileText,
            title: s.isHindi ? 'व्यावसायिक पहचान' : 'Business Identifiers',
            children: [
              TextFormField(
                key: const Key('edit_gstin_field'),
                controller: _gstController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: s.gstinLabel,
                  hintText: s.gstinHint,
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val != null && val.trim().isNotEmpty) {
                    final clean = val.trim().toUpperCase();
                    final gstRegex = RegExp(
                      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
                    );
                    if (!gstRegex.hasMatch(clean)) {
                      return s.errInvalidGstin;
                    }
                  }
                  return null;
                },
              ),
            ],
          ),

          // Business Location (Shop, Warehouse, or Godown)
          AppCard(
            key: const Key('business_location_edit_card'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.isHindi ? 'दुकान और गोदाम' : 'Shop & Godown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (_isGpsDetected)
                      Text(
                        s.isHindi ? 'GPS सक्रिय' : 'GPS Active',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  s.businessLocationSub,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Location Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('btn_use_current_location'),
                        onPressed: _isDetectingLocation
                            ? null
                            : _handleUseCurrentLocation,
                        icon: _isDetectingLocation
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(LucideIcons.crosshair, size: 16),
                        label: Text(
                          _isDetectingLocation
                              ? s.detectingGps
                              : s.detectCurrentGps,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('btn_location_presets'),
                        onPressed: _showLocationPresetsSheet,
                        icon: const Icon(LucideIcons.warehouse, size: 16),
                        label: Text(
                          s.isHindi ? 'मंडी प्रीसेट' : 'Mandi Presets',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_locationStatusMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _locationCertainty
                          ? AppColors.successBackground
                          : AppColors.warningBackground,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _locationCertainty
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _locationCertainty
                              ? LucideIcons.checkCircle2
                              : LucideIcons.alertTriangle,
                          size: 16,
                          color: _locationCertainty
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locationStatusMessage!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _locationCertainty
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextFormField(
                  key: const Key('edit_location_name_field'),
                  controller: _locationNameController,
                  decoration: InputDecoration(
                    labelText: '${s.locationNameLabel} *',
                    hintText: s.locationNameHint,
                    prefixIcon: const Icon(LucideIcons.store, size: 18),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 2) {
                      return s.errLocationNameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  key: const Key('edit_location_address_field'),
                  controller: _locationAddressController,
                  decoration: InputDecoration(
                    labelText: s.streetAddressLabel,
                    hintText: s.streetAddressHint,
                    prefixIcon: const Icon(LucideIcons.mapPin, size: 18),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  key: const Key('edit_location_locality_field'),
                  controller: _locationLocalityController,
                  decoration: InputDecoration(
                    labelText: s.localityLandmarkLabel,
                    hintText: s.localityHint,
                    prefixIcon: const Icon(LucideIcons.navigation, size: 18),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s.stateLabel} *',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<MasterState>(
                            key: const Key('location_state_dropdown'),
                            initialValue: _selectedState,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            items: MasterCommodityData.verifiedStates.map((st) {
                              return DropdownMenuItem<MasterState>(
                                value: st,
                                child: Text(
                                  st.name,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: _onStateChanged,
                            validator: (val) =>
                                val == null ? s.selectState : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s.districtLabel} *',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<MasterDistrict>(
                            key: const Key('location_district_dropdown'),
                            initialValue: _selectedDistrict,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            items: _filteredDistricts.map((d) {
                              return DropdownMenuItem<MasterDistrict>(
                                value: d,
                                child: Text(
                                  d.name,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (newDist) {
                              setState(() => _selectedDistrict = newDist);
                            },
                            validator: (val) =>
                                val == null ? s.selectDistrict : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextFormField(
                  key: const Key('edit_location_pincode_field'),
                  controller: _locationPinCodeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: s.pinCodeLabel,
                    hintText: s.pinCodeHint,
                    prefixIcon: const Icon(LucideIcons.hash, size: 18),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      if (!RegExp(r'^\d{6}$').hasMatch(val.trim())) {
                        return s.errInvalidPin;
                      }
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Bank Details Section (Phase 5 - Cheque leaf OCR & Bank Settlement)
          _buildEditGroup(
            icon: LucideIcons.landmark,
            title: s.isHindi ? 'बैंक विवरण (व्यापार निपटान)' : 'Bank Details (Trade Settlement)',
            children: [
              // Cheque Scanning Intake Card
              Container(
                key: const Key('cheque_intake_card'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.scanLine, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.scanCheque,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                        if (_isExtractingCheque) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.scanChequeSubtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 12),

                    // Cheque Intake Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('btn_pick_cheque_camera'),
                            onPressed: _isExtractingCheque ? null : _handleChequeCamera,
                            icon: const Icon(LucideIcons.camera, size: 15),
                            label: Text(s.camera, style: const TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('btn_pick_cheque_gallery'),
                            onPressed: _isExtractingCheque ? null : _handleChequeGallery,
                            icon: const Icon(LucideIcons.image, size: 15),
                            label: Text(s.gallery, style: const TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('btn_enter_bank_manually'),
                            onPressed: _handleEnterBankManually,
                            icon: const Icon(LucideIcons.pencilLine, size: 15),
                            label: Text(s.enterManually, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Tappable Attached Cheque Preview
                    if (_selectedChequeDocument != null) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        key: const Key('cheque_attached_preview_card'),
                        onTap: _openChequePreviewDialog,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(LucideIcons.receipt, color: AppColors.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedChequeDocument!.fileName,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          _selectedChequeDocument!.isUploaded
                                              ? (s.isHindi ? 'सर्वर पर सुरक्षित चेक दस्तावेज़' : 'Server Private Cheque Document')
                                              : (s.isHindi ? 'स्थानीय चेक ड्राफ्ट • देखने के लिए टैप करें' : 'Local Cheque Leaf • Tap to inspect'),
                                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(LucideIcons.externalLink, size: 14, color: AppColors.primary),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    key: const Key('btn_retake_cheque'),
                                    onPressed: _isExtractingCheque ? null : _handleChequeCamera,
                                    icon: const Icon(LucideIcons.camera, size: 13),
                                    label: Text(s.retakeCheque, style: const TextStyle(fontSize: 11)),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton.icon(
                                    key: const Key('btn_replace_cheque'),
                                    onPressed: _isExtractingCheque ? null : _handleChequeGallery,
                                    icon: const Icon(LucideIcons.image, size: 13),
                                    label: Text(s.replaceCheque, style: const TextStyle(fontSize: 11)),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton.icon(
                                    key: const Key('btn_remove_cheque'),
                                    onPressed: _removeCheque,
                                    icon: const Icon(LucideIcons.trash2, size: 13, color: AppColors.error),
                                    label: Text(
                                      s.removeCheque,
                                      style: const TextStyle(fontSize: 11, color: AppColors.error),
                                    ),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Cheque Extraction Notice Banner
                    if (_chequeStatusNotice != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _chequeNoticeIsError ? AppColors.errorBackground : AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _chequeNoticeIsError ? AppColors.error.withValues(alpha: 0.4) : AppColors.info.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _chequeNoticeIsError ? LucideIcons.alertCircle : LucideIcons.info,
                              size: 15,
                              color: _chequeNoticeIsError ? AppColors.error : AppColors.info,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _chequeStatusNotice!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _chequeNoticeIsError ? AppColors.error : AppColors.info,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Apply Cheque Suggestions Button
                    if (_extractedChequeData != null && !_extractedChequeData!.isEmpty) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        key: const Key('btn_apply_cheque_suggestions'),
                        onPressed: () => _applyChequeExtractedSuggestions(showSnack: true),
                        icon: const Icon(LucideIcons.sparkles, size: 14),
                        label: Text(s.applySuggestions),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 34),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                key: const Key('edit_bank_holder_field'),
                controller: _bankHolderController,
                decoration: InputDecoration(
                  labelText: s.accountHolderName,
                  hintText: s.accountHolderHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              TextFormField(
                key: const Key('edit_bank_name_field'),
                controller: _bankNameController,
                decoration: InputDecoration(
                  labelText: s.bankName,
                  hintText: s.bankNameHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              TextFormField(
                key: const Key('edit_bank_account_field'),
                controller: _bankAccountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: s.accountNumber,
                  hintText: s.accountNumberHint,
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val != null && val.trim().isNotEmpty) {
                    return SellerBankDetails.validateAccountNumber(val);
                  }
                  return null;
                },
              ),
              TextFormField(
                key: const Key('edit_bank_ifsc_field'),
                controller: _bankIfscController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: s.ifscCode,
                  hintText: s.ifscHint,
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val != null && val.trim().isNotEmpty) {
                    return SellerBankDetails.validateIfsc(val);
                  }
                  return null;
                },
              ),
              TextFormField(
                key: const Key('edit_bank_branch_field'),
                controller: _bankBranchController,
                decoration: InputDecoration(
                  labelText: s.branchNameOptional,
                  hintText: s.branchHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              TextFormField(
                key: const Key('edit_bank_micr_field'),
                controller: _bankMicrController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: s.micrCodeOptional,
                  hintText: s.micrHint,
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val != null && val.trim().isNotEmpty) {
                    return SellerBankDetails.validateMicr(val);
                  }
                  return null;
                },
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.shieldCheck, size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.bankPrivacyNotice,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEditGroup({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, [
    ProfileStrings? s,
  ]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMutedLight),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 80, maxWidth: 120),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : (s?.notProvided ?? 'Not provided'),
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

  Widget _buildExpertiseEditCard(ProfileStrings s) {
    final invoiceCommodities =
        _extractedInvoiceData?.extractedCommodities ?? const [];

    return AppCard(
      key: const Key('edit_commodity_expertise_card'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sprout, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.myCommodityExpertiseTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              if (_selectedExpertise.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_selectedExpertise.length} ${s.isHindi ? "चयनित" : "selected"}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.commodityExpertiseSub,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
          ),
          const SizedBox(height: 12),

          // Invoice Suggestions (Workflow A)
          if (invoiceCommodities.isNotEmpty) ...[
            Container(
              key: const Key('invoice_commodity_suggestions_box'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.sparkles,
                            size: 15,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            s.suggestedFromInvoiceBadge,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        key: const Key('btn_dismiss_invoice_suggestions'),
                        onTap: () {
                          setState(() {
                            if (_extractedInvoiceData != null) {
                              _extractedInvoiceData = _extractedInvoiceData!
                                  .copyWith(extractedCommodities: const []);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Text(
                            s.isHindi ? 'खारिज करें' : 'Dismiss',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.isHindi
                        ? 'बिल की कमोडिटी की समीक्षा करें और अपनी विशेषज्ञता में जोड़ने के लिए टैप करें:'
                        : 'Review and tap to add invoice commodities to your declared expertise:',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: invoiceCommodities.map((rawName) {
                      final isAdded = _selectedExpertise.any(
                        (e) => e.matchesNormalized(rawName),
                      );
                      final keySafe = rawName
                          .toLowerCase()
                          .replaceAll(RegExp(r'\s+'), '_');

                      return ActionChip(
                        key: Key('btn_add_suggested_commodity_$keySafe'),
                        avatar: Icon(
                          isAdded ? LucideIcons.check : LucideIcons.plus,
                          size: 13,
                          color: isAdded
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                        label: Text(
                          isAdded ? '$rawName ${s.isHindi ? "(जोड़ा गया)" : "(Added)"}' : rawName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isAdded
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                        ),
                        backgroundColor: isAdded
                            ? AppColors.successBackground
                            : AppColors.surfaceLight,
                        side: BorderSide(
                          color: isAdded
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                        onPressed: isAdded
                            ? null
                            : () => _addSuggestedCommodity(rawName),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Selected Commodities Chips (Workflow B)
          if (_selectedExpertise.isNotEmpty) ...[
            Text(
              s.isHindi ? 'चयनित कमोडिटीज:' : 'Selected Commodities:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedExpertise.map((exp) {
                return InputChip(
                  key: Key('selected_expertise_chip_${exp.id}'),
                  avatar: CircleAvatar(
                    backgroundColor: exp.isApproved
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.warning.withValues(alpha: 0.15),
                    child: Icon(
                      exp.isApproved ? LucideIcons.check : LucideIcons.clock,
                      size: 12,
                      color: exp.isApproved
                          ? AppColors.primary
                          : AppColors.warning,
                    ),
                  ),
                  label: Text(
                    exp.isApproved
                        ? exp.commodityName
                        : '${exp.commodityName} ${s.isHindi ? "(लंबित)" : "(Pending)"}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: exp.isApproved
                          ? AppColors.textPrimaryLight
                          : AppColors.warning,
                    ),
                  ),
                  backgroundColor: AppColors.surfaceLight,
                  side: BorderSide(
                    color: exp.isApproved
                        ? AppColors.borderLight
                        : AppColors.warning.withValues(alpha: 0.4),
                  ),
                  deleteIcon: const Icon(LucideIcons.x, size: 14),
                  deleteButtonTooltipMessage: 'Remove ${exp.commodityName}',
                  onDeleted: () {
                    setState(() {
                      _selectedExpertise.removeWhere((e) => e.id == exp.id);
                    });
                  },
                );
              }).toList(),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Text(
                s.noExpertiseSelected,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Actions Row (Workflows B and C)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('btn_add_expertise_from_catalogue'),
                  onPressed: _openCatalogueCommodityPicker,
                  icon: const Icon(LucideIcons.listPlus, size: 16),
                  label: Text(
                    s.isHindi ? 'कैटलॉग से चुनें' : 'Select from Catalogue',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('btn_add_custom_commodity'),
                  onPressed: _openAddMissingCommodityDialog,
                  icon: const Icon(LucideIcons.plusCircle, size: 16),
                  label: Text(
                    s.addCommodity,
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addSuggestedCommodity(String rawName) {
    if (rawName.trim().isEmpty) return;

    if (_selectedExpertise.any((e) => e.matchesNormalized(rawName))) {
      return;
    }

    final masterMatch = _allCatalogueCommodities
        .cast<MasterCommodity?>()
        .firstWhere(
          (c) =>
              c != null &&
              SellerCommodityExpertise.areNamesMatching(c.name, rawName),
          orElse: () => null,
        );

    setState(() {
      if (masterMatch != null) {
        _selectedExpertise.add(
          SellerCommodityExpertise.fromMaster(masterMatch),
        );
      } else {
        _selectedExpertise.add(
          SellerCommodityExpertise.pending(commodityName: rawName.trim()),
        );
      }
    });
  }

  void _openCatalogueCommodityPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CatalogueCommodityPickerSheet(
        allCommodities: _allCatalogueCommodities,
        selectedIds: _selectedExpertise.map((e) => e.id).toSet(),
        onApply: (newlySelected) {
          setState(() {
            for (final c in newlySelected) {
              if (!_selectedExpertise.any(
                (e) => e.matchesNormalized(c.name),
              )) {
                _selectedExpertise.add(
                  SellerCommodityExpertise.fromMaster(c),
                );
              }
            }
          });
        },
      ),
    );
  }

  void _openAddMissingCommodityDialog() {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    String? localError;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          key: const Key('add_missing_commodity_dialog'),
          title: const Row(
            children: [
              Icon(LucideIcons.plusCircle, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('Add Commodity', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add a commodity that is unavailable in the platform catalogue. It will be saved as pending review for your profile only.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('custom_commodity_name_input'),
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Commodity Name *',
                    hintText: 'e.g. Desi Chana Bold, Organic Mustard',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('custom_commodity_category_input'),
                  controller: catCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Category (Optional)',
                    hintText: 'e.g. Pulses, Oilseeds, Grains',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (localError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    localError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warningBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(LucideIcons.info, size: 16, color: AppColors.warning),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Note: Custom commodities are saved as pending approval in your profile and do not modify the platform-wide master.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('btn_confirm_add_custom_commodity'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.length < 2) {
                  setDialogState(() {
                    localError =
                        'Enter a valid commodity name (at least 2 characters).';
                  });
                  return;
                }

                // Check duplicate against current selection
                final duplicate = _selectedExpertise.any(
                  (e) => e.matchesNormalized(name),
                );
                if (duplicate) {
                  setDialogState(() {
                    localError =
                        'Commodity "$name" is already in your expertise list.';
                  });
                  return;
                }

                // Check match against platform master
                final masterMatch = _allCatalogueCommodities
                    .cast<MasterCommodity?>()
                    .firstWhere(
                      (c) =>
                          c != null &&
                          SellerCommodityExpertise.areNamesMatching(
                            c.name,
                            name,
                          ),
                      orElse: () => null,
                    );

                if (masterMatch != null) {
                  setState(() {
                    _selectedExpertise.add(
                      SellerCommodityExpertise.fromMaster(masterMatch),
                    );
                  });
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Matched and added platform commodity "${masterMatch.name}".',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  return;
                }

                // Create pending custom commodity
                final customExp = SellerCommodityExpertise.pending(
                  commodityName: name,
                  categoryName: catCtrl.text.trim().isNotEmpty
                      ? catCtrl.text.trim()
                      : null,
                );

                setState(() {
                  _selectedExpertise.add(customExp);
                });
                Navigator.pop(dialogCtx);
              },
              child: const Text('Add Commodity'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogueCommodityPickerSheet extends StatefulWidget {
  final List<MasterCommodity> allCommodities;
  final Set<String> selectedIds;
  final ValueChanged<List<MasterCommodity>> onApply;

  const _CatalogueCommodityPickerSheet({
    required this.allCommodities,
    required this.selectedIds,
    required this.onApply,
  });

  @override
  State<_CatalogueCommodityPickerSheet> createState() =>
      _CatalogueCommodityPickerSheetState();
}

class _CatalogueCommodityPickerSheetState
    extends State<_CatalogueCommodityPickerSheet> {
  late final TextEditingController _searchCtrl;
  late final Set<String> _chosenIds;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _chosenIds = Set.from(widget.selectedIds);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.allCommodities.where((c) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.code.toLowerCase().contains(q) ||
          (c.categoryName != null && c.categoryName!.toLowerCase().contains(q));
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Commodities',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  key: const Key('expertise_catalogue_search_field'),
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search commodities...',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (val) => setState(() => _query = val.trim()),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No matching commodities found',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final c = filtered[idx];
                          final isChecked = _chosenIds.contains(c.id);

                          return CheckboxListTile(
                            key: Key('catalogue_option_${c.id}'),
                            value: isChecked,
                            title: Text(
                              c.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: c.categoryName != null
                                ? Text(
                                    c.categoryName!,
                                    style: const TextStyle(fontSize: 11),
                                  )
                                : null,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _chosenIds.add(c.id);
                                } else {
                                  _chosenIds.remove(c.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    key: const Key('btn_apply_catalogue_selection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    onPressed: () {
                      final selected = widget.allCommodities
                          .where((c) => _chosenIds.contains(c.id))
                          .toList();
                      widget.onApply(selected);
                      Navigator.pop(context);
                    },
                    child: Text('Done (${_chosenIds.length} Selected)'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

