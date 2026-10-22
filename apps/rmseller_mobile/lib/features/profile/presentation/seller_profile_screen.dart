import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../authentication/data/auth_repository.dart';
import '../../commodities/domain/master_commodity_data.dart';
import '../data/business_location_service.dart';
import '../data/seller_profile_repository.dart';
import '../domain/seller_profile_model.dart';
import 'widgets/app_settings_section.dart';

class SellerProfileScreen extends StatefulWidget {
  final SellerProfileRepository? profileRepository;
  final SecureStorageService? storageService;
  final AuthRepository? authRepository;
  final BusinessLocationService? locationService;
  final bool isInitialEdit;

  const SellerProfileScreen({
    super.key,
    this.profileRepository,
    this.storageService,
    this.authRepository,
    this.locationService,
    this.isInitialEdit = false,
  });

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  late final SellerProfileRepository _profileRepo;
  late final AuthRepository _authRepository;
  late final BusinessLocationService _locationService;

  SellerProfileModel? _profile;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isDetectingLocation = false;
  String? _saveErrorMessage;
  String? _locationStatusMessage;
  bool _locationCertainty = true;

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

  // State & District Dropdown Selections
  MasterState? _selectedState;
  MasterDistrict? _selectedDistrict;
  List<MasterDistrict> _filteredDistricts = [];

  // Coordinates internal retention
  double? _currentLat;
  double? _currentLng;
  bool _isGpsDetected = false;

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

    _nameController = TextEditingController();
    _companyController = TextEditingController();
    _mobileController = TextEditingController();
    _gstController = TextEditingController();
    _officeAddressController = TextEditingController();

    _locationNameController = TextEditingController();
    _locationAddressController = TextEditingController();
    _locationLocalityController = TextEditingController();
    _locationPinCodeController = TextEditingController();

    _isEditing = widget.isInitialEdit;
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
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _profileRepo.getProfile();
      if (!mounted) return;
      _populateControllers(profile);
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
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
      // Cascading reset: filter districts to only those in the newly selected state
      _filteredDistricts = MasterCommodityData.verifiedDistricts
          .where((d) => d.stateId == newState.id)
          .toList();
      // Clear or pick first district of new state
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
        _locationStatusMessage = 'Could not detect location. Please select state and district manually.';
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

  void _enterEditMode() {
    if (_profile != null) {
      _populateControllers(_profile!);
    }
    setState(() {
      _isEditing = true;
      _saveErrorMessage = null;
      _locationStatusMessage = null;
    });
  }

  void _cancelEdit() {
    if (_profile != null) {
      _populateControllers(_profile!);
    }
    setState(() {
      _isEditing = false;
      _saveErrorMessage = null;
      _locationStatusMessage = null;
    });
  }

  Future<void> _handleSaveProfile() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _saveErrorMessage = null;
    });

    final current =
        _profile ??
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

    final updated = current.copyWith(
      fullName: _nameController.text.trim(),
      companyName: _companyController.text.trim(),
      mobile: _mobileController.text.trim(),
      companyGst: _gstController.text.trim().toUpperCase(),
      officeAddress: _officeAddressController.text.trim(),
      state: _selectedState?.name ?? current.state,
      district: _selectedDistrict?.name ?? current.district,
      primaryMandi: _locationLocalityController.text.trim().isNotEmpty
          ? _locationLocalityController.text.trim()
          : current.primaryMandi,
      businessLocation: updatedLocation,
    );

    try {
      final saved = await _profileRepo.updateProfile(updated);
      if (!mounted) return;

      setState(() {
        _profile = saved;
        _isSaving = false;
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business profile updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveErrorMessage = 'Failed to update profile: ${e.toString()}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile. ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out of the RMSeller desk?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Business Profile' : 'Seller Profile & Mandi Desk',
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              key: const Key('appbar_edit_profile_button'),
              icon: const Icon(LucideIcons.pencil),
              tooltip: 'Edit Profile',
              onPressed: _enterEditMode,
            ),
        ],
      ),
      body: _isEditing ? _buildEditView(profile) : _buildProfileView(profile),
    );
  }

  Widget _buildProfileView(SellerProfileModel profile) {
    final loc = profile.businessLocation;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // Enterprise Entity Overview Card
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryContainer,
                child: const Icon(
                  LucideIcons.store,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                profile.companyName.isNotEmpty
                    ? profile.companyName
                    : 'Bikaner Agro Processing Ltd',
                style: AppTypography.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                profile.fullName.isNotEmpty ? profile.fullName : 'Seller Lead',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                        Text(
                          profile.isVerified
                              ? 'Verified Seller Enterprise'
                              : 'Pending Desk Verification',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: profile.isVerified
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    key: const Key('edit_profile_button'),
                    onTap: _enterEditMode,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            LucideIcons.pencil,
                            size: 11,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Business Information (Clean & Human-Readable)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    LucideIcons.building,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Business Information',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildInfoRow('Contact Person:', profile.fullName),
              const SizedBox(height: 6),
              _buildInfoRow(
                'Mobile Number:',
                profile.mobile.isNotEmpty ? profile.mobile : 'Not provided',
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                'Business Email:',
                profile.email.isNotEmpty ? profile.email : 'Not provided',
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                'GSTIN:',
                profile.companyGst.isNotEmpty
                    ? profile.companyGst
                    : 'Not provided',
              ),
              const SizedBox(height: 6),
              _buildInfoRow('Corporate HQ:', profile.officeAddress),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Business Location (Shop, Warehouse, or Godown)
        AppCard(
          key: const Key('business_location_view_card'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(
                        LucideIcons.warehouse,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Business Location (Shop / Godown)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  if (loc.isGpsDetected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            LucideIcons.mapPin,
                            size: 9,
                            color: AppColors.success,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'GPS Linked',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _buildInfoRow('Facility Name:', loc.name),
              const SizedBox(height: 6),
              _buildInfoRow('Premises Address:', loc.addressLine),
              const SizedBox(height: 6),
              _buildInfoRow('Mandi Area / Locality:', loc.locality),
              const SizedBox(height: 6),
              _buildInfoRow(
                'State & District:',
                '${loc.districtName}, ${loc.stateName}',
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                'Postal PIN Code:',
                loc.pinCode.isNotEmpty ? loc.pinCode : 'Not provided',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Trading Desk Regulations
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trading Desk Regulations',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              const Text(
                '1. All commodity sales are mediated exclusively through authorized regional brokers.\n'
                '2. Direct buyer communications and directory searches are prohibited under counterparty shield policies.\n'
                '3. Sellers are responsible for physical loading readiness at registered warehouse locations.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondaryLight,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Application Preferences (Theme, Language, Font Size, Accessibility)
        const AppSettingsSection(),
        const SizedBox(height: 16),

        // Sign Out Action
        AppButton(
          label: 'Sign Out of Seller Desk',
          icon: LucideIcons.logOut,
          variant: ButtonVariant.danger,
          onPressed: _handleSignOut,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEditView(SellerProfileModel profile) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Edit Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: const [
                Icon(LucideIcons.fileEdit, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Update your business contact details and shop/godown facility location.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

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
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Business Information Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Business & Enterprise Details',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 14),

                // Full Name
                TextFormField(
                  key: const Key('edit_full_name_field'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Seller Full Name (Contact Person) *',
                    hintText: 'e.g. Ramesh Kumar Sharma',
                    prefixIcon: Icon(LucideIcons.user, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 2) {
                      return 'Full name is required (minimum 2 characters)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Company Name
                TextFormField(
                  key: const Key('edit_company_name_field'),
                  controller: _companyController,
                  decoration: const InputDecoration(
                    labelText: 'Company / Business Name *',
                    hintText: 'e.g. Bikaner Agro Processing Ltd',
                    prefixIcon: Icon(LucideIcons.building, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 2) {
                      return 'Business name is required (minimum 2 characters)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Mobile
                TextFormField(
                  key: const Key('edit_mobile_field'),
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Registered Mobile Number *',
                    hintText: 'e.g. 9829012345',
                    prefixIcon: Icon(LucideIcons.phone, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Mobile number is required';
                    }
                    final clean = val.replaceAll(RegExp(r'[\s\-+]'), '');
                    final phoneRegex = RegExp(r'^(?:91)?[6-9]\d{9}$');
                    if (!phoneRegex.hasMatch(clean)) {
                      return 'Enter a valid 10-digit Indian mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // GSTIN
                TextFormField(
                  key: const Key('edit_gstin_field'),
                  controller: _gstController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'GSTIN (Tax Registration)',
                    hintText: 'e.g. 08AAAAA0000A1Z5',
                    prefixIcon: Icon(LucideIcons.receipt, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      final clean = val.trim().toUpperCase();
                      final gstRegex = RegExp(
                        r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
                      );
                      if (!gstRegex.hasMatch(clean)) {
                        return 'Enter a valid 15-character GSTIN (e.g. 08AAAAA0000A1Z5)';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Corporate HQ Office Address (Preserved strictly distinct from Godown)
                TextFormField(
                  key: const Key('edit_office_address_field'),
                  controller: _officeAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Corporate HQ Address (Office)',
                    hintText: 'e.g. Commercial Tower 4, Bikaner HQ',
                    prefixIcon: Icon(LucideIcons.mapPinned, size: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Business Location (Shop, Warehouse, or Godown)
          AppCard(
            key: const Key('business_location_edit_card'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Business Location (Shop / Godown)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (_isGpsDetected)
                      const Text(
                        'GPS Active',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select the physical location of your shop, warehouse, or godown for mandi logistics and lot dispatches.',
                  style: TextStyle(
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
                              ? 'Detecting...'
                              : 'Use Current Location',
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
                        label: const Text(
                          'Mandi Presets',
                          style: TextStyle(
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

                // Location Status Notice
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

                // Shop / Godown Name
                TextFormField(
                  key: const Key('edit_location_name_field'),
                  controller: _locationNameController,
                  decoration: const InputDecoration(
                    labelText: 'Shop / Warehouse / Godown Name *',
                    hintText: 'e.g. Bikaner Krishi Upaj Mandi Yard Godown A-4',
                    prefixIcon: Icon(LucideIcons.store, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 2) {
                      return 'Facility name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Premises Address Line
                TextFormField(
                  key: const Key('edit_location_address_field'),
                  controller: _locationAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Premises / Street Address',
                    hintText: 'e.g. Plot 12, Industrial Area, Mandi Road',
                    prefixIcon: Icon(LucideIcons.mapPin, size: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // Locality or Village
                TextFormField(
                  key: const Key('edit_location_locality_field'),
                  controller: _locationLocalityController,
                  decoration: const InputDecoration(
                    labelText: 'Locality, Mandi Yard, or Village',
                    hintText: 'e.g. Khara Industrial Area',
                    prefixIcon: Icon(LucideIcons.navigation, size: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // State & District Dropdown Selectors
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // State Dropdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'State *',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<MasterState>(
                            key: const Key('location_state_dropdown'),
                            value: _selectedState,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            items: MasterCommodityData.verifiedStates.map((s) {
                              return DropdownMenuItem<MasterState>(
                                value: s,
                                child: Text(
                                  s.name,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: _onStateChanged,
                            validator: (val) =>
                                val == null ? 'Select state' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // District Dropdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'District *',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<MasterDistrict>(
                            key: const Key('location_district_dropdown'),
                            value: _selectedDistrict,
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
                                val == null ? 'Select district' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Postal PIN Code
                TextFormField(
                  key: const Key('edit_location_pincode_field'),
                  controller: _locationPinCodeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Postal PIN Code',
                    hintText: 'e.g. 334001',
                    prefixIcon: Icon(LucideIcons.hash, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      if (!RegExp(r'^\d{6}$').hasMatch(val.trim())) {
                        return 'PIN code must be 6 digits';
                      }
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons: Save & Cancel
          Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const Key('cancel_profile_button'),
                  label: 'Cancel',
                  variant: ButtonVariant.outline,
                  onPressed: _isSaving ? null : _cancelEdit,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  key: const Key('save_profile_button'),
                  label: _isSaving ? 'Saving...' : 'Save Changes',
                  isLoading: _isSaving,
                  variant: ButtonVariant.primary,
                  onPressed: _isSaving ? null : _handleSaveProfile,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 135,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : 'Not provided',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }
}
