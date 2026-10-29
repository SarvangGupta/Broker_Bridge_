import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_state.dart';
import '../data/buyer_profile_repository.dart';
import '../data/device_location_service.dart';
import '../data/warehouse_repository.dart';
import '../domain/buyer_profile.dart';
import '../domain/company_warehouse.dart';

/// Screen allowing the buyer to view, add, edit, activate/deactivate,
/// and manage multiple warehouse and unloading locations for their company,
/// including high-precision GPS coordinate capture for dispatch logistics.
class WarehouseManagementScreen extends StatefulWidget {
  final WarehouseRepository? repository;
  final BuyerProfileRepository? profileRepository;
  final LocationProvider? locationProvider;

  const WarehouseManagementScreen({
    super.key,
    this.repository,
    this.profileRepository,
    this.locationProvider,
  });

  @override
  State<WarehouseManagementScreen> createState() =>
      _WarehouseManagementScreenState();
}

class _WarehouseManagementScreenState
    extends State<WarehouseManagementScreen> {
  late final WarehouseRepository _repo;
  late final BuyerProfileRepository _profileRepo;
  late final LocationProvider _locationProvider;

  BuyerProfile? _profile;
  List<CompanyWarehouse> _warehouses = [];
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? WarehouseRepository();
    _profileRepo = widget.profileRepository ?? BuyerProfileRepository();
    _locationProvider =
        widget.locationProvider ?? const DeviceLocationService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    try {
      final profile = await _profileRepo.getProfile();
      final companyId = profile.companyId;
      if (companyId == null || companyId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _profile = profile;
          _warehouses = [];
          _isLoading = false;
        });
        return;
      }

      final list = await _repo.getWarehouses(companyId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _warehouses = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load warehouses: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _openWarehouseForm([
    CompanyWarehouse? initial,
    bool autoCaptureGps = false,
  ]) async {
    final companyId = _profile?.companyId;
    if (companyId == null || companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No company associated with this buyer account.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final saved = await showModalBottomSheet<CompanyWarehouse>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WarehouseFormSheet(
        companyId: companyId,
        userId: _profile?.id ?? '',
        initial: initial,
        autoCaptureGps: autoCaptureGps,
        repository: _repo,
        locationProvider: _locationProvider,
      ),
    );

    if (saved != null && mounted) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('warehouse-save-success-snackbar'),
          content: Text(
            initial == null
                ? 'Warehouse location added successfully.'
                : 'Warehouse location updated successfully.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _toggleActive(CompanyWarehouse wh) async {
    final newStatus = !wh.isActive;
    try {
      await _repo.toggleActive(wh.id, newStatus);
      if (!mounted) return;
      setState(() {
        final idx = _warehouses.indexWhere((w) => w.id == wh.id);
        if (idx != -1) {
          _warehouses[idx] = wh.copyWith(isActive: newStatus);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus ? '${wh.name} activated.' : '${wh.name} deactivated.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('Toggle active failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update warehouse status.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteWarehouse(CompanyWarehouse wh) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Location?'),
        content: Text(
          'Are you sure you want to delete "${wh.name}"? Transporters will no longer see this unloading site.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('warehouse-confirm-delete-button'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _repo.deleteWarehouse(wh.id);
      if (!mounted) return;
      setState(() {
        _warehouses.removeWhere((w) => w.id == wh.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${wh.name} deleted.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('Delete warehouse failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete warehouse location.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openGoogleMaps(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open map URL.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  static String _formatCoordinates(double lat, double lng) {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(2)}° $latDir, ${lng.abs().toStringAsFixed(2)}° $lngDir';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
      appBar: AppBar(
        title: const Text('Warehouses & Unloading'),
        actions: [
          IconButton(
            key: const Key('warehouse-refresh-button'),
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: _warehouses.isEmpty
          ? FloatingActionButton.extended(
              key: const Key('warehouse-add-fab'),
              onPressed: _isLoading ? null : () => _openWarehouseForm(),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Add Location'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_loadFailed) {
      return AppErrorState(
        message: 'Could not load warehouse locations.',
        onRetry: _load,
      );
    }
    if (_profile?.companyId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Company information is missing. Please complete company setup first.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoBanner(),
            if (_warehouses.isEmpty)
              _buildEmptyState()
            else ...[
              _buildSavedLocationsHeader(_warehouses.length),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _warehouses.length,
                itemBuilder: (context, i) {
                  final isPrimary = i == 0 && _warehouses[i].isActive;
                  return _buildWarehouseCard(
                    _warehouses[i],
                    isPrimary: isPrimary,
                  );
                },
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildBottomActions(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      key: const Key('warehouse-info-banner'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD1E3D6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFFD8EBDD),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.mapPin,
              size: 15,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Operational delivery sites are separate from your registered GST address. Add GPS coordinates so dispatch trucks reach the exact gate.',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF22382B),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedLocationsHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              LucideIcons.warehouse,
              size: 18,
              color: Color(0xFF1E5E3A),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Saved Locations',
            key: Key('warehouse-saved-locations-header'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const Spacer(),
          Container(
            key: const Key('warehouse-count-badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count ${count == 1 ? "location" : "locations"}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E5E3A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: const Key('warehouse-empty-state'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.warehouse,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Unloading Locations Added',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your delivery godowns, mill gates, and processing plants with GPS coordinates so counterparties and transporters know exactly where to deliver.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              key: const Key('warehouse-empty-add-button'),
              label: 'Add First Warehouse',
              icon: LucideIcons.plus,
              onPressed: () => _openWarehouseForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseCard(CompanyWarehouse wh, {bool isPrimary = false}) {
    final mapsUrl = wh.googleMapsUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        key: Key('warehouse-card-${wh.id}'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Icon + (Primary badge & Name) + More Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: wh.hasGpsCoordinates
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.warehouse,
                    size: 20,
                    color: wh.hasGpsCoordinates
                        ? const Color(0xFF1E5E3A)
                        : const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPrimary) ...[
                        Container(
                          key: Key('warehouse-primary-badge-${wh.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8EBDD),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                size: 12,
                                color: Color(0xFF1E5E3A),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'PRIMARY UNLOADING POINT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: Color(0xFF1E5E3A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              wh.name,
                              key: Key('warehouse-name-${wh.id}'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                          InkWell(
                            key: Key('warehouse-toggle-${wh.id}'),
                            onTap: () => _toggleActive(wh),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: wh.isActive
                                    ? AppColors.successBackground
                                    : AppColors.errorBackground,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                wh.isActive ? 'Active' : 'Inactive',
                                key: Key('warehouse-status-${wh.id}'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: wh.isActive
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  key: Key('warehouse-more-menu-${wh.id}'),
                  icon: const Icon(
                    LucideIcons.ellipsisVertical,
                    size: 18,
                    color: AppColors.textSecondaryLight,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _openWarehouseForm(wh);
                    } else if (val == 'toggle') {
                      _toggleActive(wh);
                    } else if (val == 'delete') {
                      _deleteWarehouse(wh);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(LucideIcons.pencil,
                              size: 16, color: AppColors.textSecondaryLight),
                          SizedBox(width: 10),
                          Text('Edit Location'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            wh.isActive
                                ? LucideIcons.circlePower
                                : LucideIcons.checkCircle2,
                            size: 16,
                            color: AppColors.textSecondaryLight,
                          ),
                          SizedBox(width: 10),
                          Text(wh.isActive ? 'Deactivate' : 'Activate'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      key: Key('warehouse-delete-${wh.id}'),
                      value: 'delete',
                      child: const Row(
                        children: [
                          Icon(LucideIcons.trash2,
                              size: 16, color: AppColors.error),
                          SizedBox(width: 10),
                          Text(
                            'Delete Location',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Address line
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.mapPin,
                  size: 14,
                  color: AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    wh.pinCode != null && wh.pinCode!.isNotEmpty
                        ? '${wh.addressLine}, ${wh.pinCode}'
                        : wh.addressLine,
                    key: Key('warehouse-address-${wh.id}'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryLight,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // GPS Status block
            if (wh.hasGpsCoordinates) ...[
              Container(
                key: Key('warehouse-gps-badge-${wh.id}'),
                margin: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.mapPin,
                        size: 14,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GPS location saved',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatCoordinates(wh.latitude!, wh.longitude!)}  |  ±${(wh.gpsAccuracy ?? 12).toInt()} m accuracy',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Stylized Map Preview Box
              InkWell(
                key: Key('warehouse-map-preview-${wh.id}'),
                onTap: mapsUrl != null ? () => _openGoogleMaps(mapsUrl) : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 110,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4EDE6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD1E3D6)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _MapRoadsPainter(),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        bottom: 14,
                        child: Text(
                          wh.addressLine.split(',').first.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0.0, -0.2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 32,
                              color: Color(0xFFDC2626),
                            ),
                            Container(
                              width: 8,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (mapsUrl != null)
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 13,
                                  color: Color(0xFFEA4335),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'View on Maps',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F5132),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Action buttons: View on Maps (outlined) + Edit Location (filled surface)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: Key('warehouse-open-maps-${wh.id}'),
                      onPressed:
                          mapsUrl != null ? () => _openGoogleMaps(mapsUrl) : null,
                      icon: const Icon(LucideIcons.navigation, size: 15),
                      label: const Text('View on Maps'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F5132),
                        side: const BorderSide(color: Color(0xFF0F5132)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      key: Key('warehouse-edit-${wh.id}'),
                      onPressed: () => _openWarehouseForm(wh),
                      icon: const Icon(LucideIcons.pencil, size: 15),
                      label: const Text('Edit Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8F5E9),
                        foregroundColor: const Color(0xFF0F5132),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                key: Key('warehouse-nogps-badge-${wh.id}'),
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.mapPin,
                        size: 14,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GPS not added',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD97706),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Add GPS to guide trucks to the exact gate.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons: Add GPS (outlined) + Edit Location (filled surface)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: Key('warehouse-add-gps-${wh.id}'),
                      onPressed: () =>
                          _openWarehouseForm(wh, true),
                      icon: const Icon(LucideIcons.crosshair, size: 15),
                      label: const Text('Add GPS'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F5132),
                        side: const BorderSide(color: Color(0xFF0F5132)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      key: Key('warehouse-edit-${wh.id}'),
                      onPressed: () => _openWarehouseForm(wh),
                      icon: const Icon(LucideIcons.pencil, size: 15),
                      label: const Text('Edit Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8F5E9),
                        foregroundColor: const Color(0xFF0F5132),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Contact & unloading notes if provided
            if (wh.contactPerson != null || wh.contactPhone != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    LucideIcons.user,
                    size: 13,
                    color: AppColors.textSecondaryLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        if (wh.contactPerson != null) wh.contactPerson,
                        if (wh.contactPhone != null) wh.contactPhone,
                      ].join(' · '),
                      key: Key('warehouse-contact-${wh.id}'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (wh.unloadingNotes != null && wh.unloadingNotes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.fileText,
                    size: 13,
                    color: AppColors.textMutedLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Notes: ${wh.unloadingNotes}',
                      key: Key('warehouse-notes-${wh.id}'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textMutedLight,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            key: const Key('warehouse-add-fab'),
            onPressed: _isLoading ? null : () => _openWarehouseForm(),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text(
              'Add Location',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF064E3B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.users,
              size: 14,
              color: AppColors.textSecondaryLight,
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Brokers can receive the saved Google Maps link when a location changes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MapRoadsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fill background subtle map land color
    final bgPaint = Paint()..color = const Color(0xFFE4EDE6);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Light green plot blocks
    final plotPaint = Paint()..color = const Color(0xFFD6E6D8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 10, size.width * 0.35, size.height * 0.4),
        const Radius.circular(4),
      ),
      plotPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            10, size.height * 0.55, size.width * 0.25, size.height * 0.35),
        const Radius.circular(4),
      ),
      plotPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            size.width * 0.65, 8, size.width * 0.3, size.height * 0.35),
        const Radius.circular(4),
      ),
      plotPaint,
    );

    // White secondary roads
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadPath1 = Path()
      ..moveTo(0, size.height * 0.48)
      ..lineTo(size.width * 0.55, size.height * 0.48)
      ..lineTo(size.width * 0.75, 0);
    canvas.drawPath(roadPath1, roadPaint);

    final roadPath2 = Path()
      ..moveTo(size.width * 0.45, size.height)
      ..lineTo(size.width * 0.45, size.height * 0.48);
    canvas.drawPath(roadPath2, roadPaint);

    final roadPath3 = Path()
      ..moveTo(size.width * 0.25, 0)
      ..lineTo(size.width * 0.25, size.height * 0.48);
    canvas.drawPath(roadPath3, roadPaint);

    // Main arterial highway: pale orange/yellow with casing
    final highwayCasingPaint = Paint()
      ..color = const Color(0xFFFDE68A)
      ..strokeWidth = 9.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final highwayCenterPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final highwayPath = Path()
      ..moveTo(size.width * 0.35, size.height)
      ..cubicTo(
        size.width * 0.5,
        size.height * 0.75,
        size.width * 0.65,
        size.height * 0.65,
        size.width,
        size.height * 0.4,
      );

    canvas.drawPath(highwayPath, highwayCasingPaint);
    canvas.drawPath(highwayPath, highwayCenterPaint);

    // Highway "48" badge
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.72, size.height * 0.53),
        width: 18,
        height: 14,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(badgeRect, Paint()..color = const Color(0xFFF59E0B));
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '48',
        style: TextStyle(
          color: Colors.black,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        size.width * 0.72 - textPainter.width / 2,
        size.height * 0.53 - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WarehouseFormSheet extends StatefulWidget {
  final String companyId;
  final String userId;
  final CompanyWarehouse? initial;
  final bool autoCaptureGps;
  final WarehouseRepository repository;
  final LocationProvider locationProvider;

  const _WarehouseFormSheet({
    required this.companyId,
    required this.userId,
    this.initial,
    this.autoCaptureGps = false,
    required this.repository,
    required this.locationProvider,
  });

  @override
  State<_WarehouseFormSheet> createState() => _WarehouseFormSheetState();
}

class _WarehouseFormSheetState extends State<_WarehouseFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _pinController;
  late final TextEditingController _contactPersonController;
  late final TextEditingController _contactPhoneController;
  late final TextEditingController _notesController;
  bool _isActive = true;
  bool _isSaving = false;
  String? _errorMessage;

  // GPS State
  double? _latitude;
  double? _longitude;
  double? _gpsAccuracy;
  DateTime? _locationCapturedAt;
  bool _isCapturingGps = false;
  DeviceLocationStatus? _lastGpsStatus;
  String? _gpsStatusMessage;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _nameController = TextEditingController(text: init?.name ?? '');
    _addressController = TextEditingController(text: init?.addressLine ?? '');
    _pinController = TextEditingController(text: init?.pinCode ?? '');
    _contactPersonController =
        TextEditingController(text: init?.contactPerson ?? '');
    _contactPhoneController =
        TextEditingController(text: init?.contactPhone ?? '');
    _notesController = TextEditingController(text: init?.unloadingNotes ?? '');
    _isActive = init?.isActive ?? true;

    _latitude = init?.latitude;
    _longitude = init?.longitude;
    _gpsAccuracy = init?.gpsAccuracy;
    _locationCapturedAt = init?.locationCapturedAt;

    if (widget.autoCaptureGps && !_hasCapturedLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _captureGpsLocation();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _pinController.dispose();
    _contactPersonController.dispose();
    _contactPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _hasCapturedLocation =>
      WarehouseValidation.isValidCoordinate(_latitude, _longitude);

  Future<void> _captureGpsLocation({bool allowPoorAccuracy = false}) async {
    if (_isCapturingGps) return;
    setState(() {
      _isCapturingGps = true;
      _gpsStatusMessage = null;
    });

    try {
      final result = await widget.locationProvider.getCurrentPosition(
        allowPoorAccuracy: allowPoorAccuracy,
      );
      if (!mounted) return;

      if (result.isOk) {
        setState(() {
          _latitude = result.latitude;
          _longitude = result.longitude;
          _gpsAccuracy = result.accuracyMeters;
          _locationCapturedAt = result.timestamp ?? DateTime.now();
          _lastGpsStatus = result.status;
          _isCapturingGps = false;
          _gpsStatusMessage = result.displayMessage;
        });
      } else if (result.status == DeviceLocationStatus.poorAccuracy) {
        // Poor accuracy: keep previously saved coordinates, prompt user
        setState(() {
          _lastGpsStatus = result.status;
          _isCapturingGps = false;
          _gpsStatusMessage = result.displayMessage;
        });
      } else {
        // Failure: preserve previous coordinates, record error status
        setState(() {
          _lastGpsStatus = result.status;
          _isCapturingGps = false;
          _gpsStatusMessage = result.displayMessage;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastGpsStatus = DeviceLocationStatus.unavailable;
        _isCapturingGps = false;
        _gpsStatusMessage = 'Error accessing location service: $e';
      });
    }
  }

  Future<void> _previewGoogleMaps() async {
    final url = WarehouseValidation.buildGoogleMapsUrl(_latitude, _longitude);
    if (url != null) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _clearCoordinates() {
    setState(() {
      _latitude = null;
      _longitude = null;
      _gpsAccuracy = null;
      _locationCapturedAt = null;
      _lastGpsStatus = null;
      _gpsStatusMessage = null;
    });
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final warehouse = CompanyWarehouse(
      id: widget.initial?.id ?? '',
      companyId: widget.companyId,
      createdBy: widget.initial != null && widget.initial!.createdBy.isNotEmpty
          ? widget.initial!.createdBy
          : widget.userId,
      name: _nameController.text.trim(),
      addressLine: _addressController.text.trim(),
      pinCode: _pinController.text.trim().isEmpty
          ? null
          : _pinController.text.trim(),
      contactPerson: _contactPersonController.text.trim().isEmpty
          ? null
          : _contactPersonController.text.trim(),
      contactPhone: _contactPhoneController.text.trim().isEmpty
          ? null
          : _contactPhoneController.text.trim(),
      unloadingNotes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      isActive: _isActive,
      latitude: _latitude,
      longitude: _longitude,
      gpsAccuracy: _gpsAccuracy,
      locationCapturedAt: _locationCapturedAt,
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      final saved = await widget.repository.saveWarehouse(
        warehouse,
        userId: widget.userId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      debugPrint('Warehouse save error: $e');
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save warehouse: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.initial != null;

    return Material(
      color: AppColors.backgroundLight,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    isEdit ? LucideIcons.edit2 : LucideIcons.warehouse,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEdit
                        ? 'Edit Warehouse Location'
                        : 'Add Warehouse Location',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_errorMessage != null) ...[
                Container(
                  key: const Key('warehouse-form-error'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.errorBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _fieldLabel('Location / Warehouse Name *'),
                      TextFormField(
                        key: const Key('warehouse-input-name'),
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Central Mill Godown #2',
                        ),
                        validator: (v) =>
                            WarehouseValidation.validateName(v ?? ''),
                      ),
                      const SizedBox(height: 12),
                      _fieldLabel('Full Street Address *'),
                      TextFormField(
                        key: const Key('warehouse-input-address'),
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText:
                              'e.g. Plot 42, Mandi Industrial Area, Gate 1',
                        ),
                        validator: (v) =>
                            WarehouseValidation.validateAddress(v ?? ''),
                      ),
                      const SizedBox(height: 12),
                      _fieldLabel('PIN Code'),
                      TextFormField(
                        key: const Key('warehouse-input-pin'),
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '6-digit PIN code (optional)',
                        ),
                        validator: WarehouseValidation.validatePinCode,
                      ),
                      const SizedBox(height: 16),

                      // Dedicated Warehouse GPS Location section
                      _buildGpsSection(),

                      const SizedBox(height: 16),
                      _fieldLabel('Contact Person'),
                      TextFormField(
                        key: const Key('warehouse-input-contact-person'),
                        controller: _contactPersonController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Suresh Kumar (Manager)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _fieldLabel('Contact Phone'),
                      TextFormField(
                        key: const Key('warehouse-input-contact-phone'),
                        controller: _contactPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: '10-digit mobile number',
                        ),
                        validator: WarehouseValidation.validatePhone,
                      ),
                      const SizedBox(height: 12),
                      _fieldLabel('Unloading Notes / Instructions'),
                      TextFormField(
                        key: const Key('warehouse-input-notes'),
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText:
                              'e.g. Entry restricted for trailers after 8 PM; forklift available.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          key: const Key('warehouse-input-active-switch'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Operational / Active',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          subtitle: const Text(
                            'Inactive locations are hidden from new dispatch selections.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          value: _isActive,
                          onChanged: (val) => setState(() => _isActive = val),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      key: const Key('warehouse-form-submit'),
                      label: _isSaving ? 'Saving…' : 'Save Location',
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGpsSection() {
    final isPermissionDenied = _lastGpsStatus ==
            DeviceLocationStatus.permissionDenied ||
        _lastGpsStatus == DeviceLocationStatus.permissionDeniedForever;
    final isServiceDisabled =
        _lastGpsStatus == DeviceLocationStatus.serviceDisabled;
    final isPoorAccuracy =
        _lastGpsStatus == DeviceLocationStatus.poorAccuracy;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hasCapturedLocation
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.navigation,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Warehouse GPS Location',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ),
              _buildStatusIndicator(),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Stand at the actual warehouse gate or unloading entrance when capturing GPS coordinates to ensure accurate dispatch logistics.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondaryLight,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),

          // Coordinates display if captured
          if (_hasCapturedLocation) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.successBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Latitude',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                            Text(
                              _latitude!.toStringAsFixed(6),
                              key: const Key('warehouse-gps-lat-text'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Longitude',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                            Text(
                              _longitude!.toStringAsFixed(6),
                              key: const Key('warehouse-gps-lng-text'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_gpsAccuracy != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Accuracy: ±${_gpsAccuracy!.toStringAsFixed(1)} m',
                      key: const Key('warehouse-gps-accuracy-text'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('warehouse-gps-preview-button'),
                    icon: const Icon(LucideIcons.mapPin, size: 14),
                    label: const Text('Open in Google Maps'),
                    onPressed: _previewGoogleMaps,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('warehouse-gps-refresh-button'),
                  tooltip: 'Refresh GPS',
                  icon: _isCapturingGps
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.refreshCw, size: 16),
                  onPressed: _isCapturingGps ? null : () => _captureGpsLocation(),
                ),
                IconButton(
                  key: const Key('warehouse-gps-clear-button'),
                  tooltip: 'Clear Coordinates',
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  onPressed: _clearCoordinates,
                ),
              ],
            ),
          ] else ...[
            // Not captured action
            AppButton(
              key: const Key('warehouse-gps-capture-button'),
              label: _isCapturingGps
                  ? 'Capturing GPS Location…'
                  : 'Use Current GPS Location',
              icon: LucideIcons.crosshair,
              isLoading: _isCapturingGps,
              onPressed: _isCapturingGps ? null : () => _captureGpsLocation(),
            ),
          ],

          // Feedback or warning banners
          if (_gpsStatusMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isPermissionDenied || isServiceDisabled || isPoorAccuracy
                    ? AppColors.errorBackground
                    : AppColors.successBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _gpsStatusMessage!,
                key: const Key('warehouse-gps-message'),
                style: TextStyle(
                  fontSize: 11.5,
                  color: isPermissionDenied || isServiceDisabled || isPoorAccuracy
                      ? AppColors.error
                      : AppColors.success,
                ),
              ),
            ),
          ],

          if (isPoorAccuracy) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('warehouse-gps-retry-button'),
                    icon: const Icon(LucideIcons.refreshCw, size: 13),
                    label: const Text('Retry GPS'),
                    onPressed: () => _captureGpsLocation(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    key: const Key('warehouse-gps-accept-poor-button'),
                    onPressed: () => _captureGpsLocation(allowPoorAccuracy: true),
                    child: const Text('Accept Anyway'),
                  ),
                ),
              ],
            ),
          ],

          if (isPermissionDenied) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('warehouse-gps-settings-button'),
              icon: const Icon(LucideIcons.settings, size: 14),
              label: const Text('Open App Settings'),
              onPressed: () => widget.locationProvider.openAppSettings(),
            ),
          ],

          if (isServiceDisabled) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('warehouse-gps-loc-settings-button'),
              icon: const Icon(LucideIcons.settings, size: 14),
              label: const Text('Turn on Location Services'),
              onPressed: () =>
                  widget.locationProvider.openLocationSettings(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (_hasCapturedLocation) {
      return Container(
        key: const Key('warehouse-gps-status-captured'),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.successBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.checkCircle2, size: 11, color: AppColors.success),
            SizedBox(width: 3),
            Text(
              'Location captured',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    }

    if (_lastGpsStatus == DeviceLocationStatus.permissionDenied ||
        _lastGpsStatus == DeviceLocationStatus.permissionDeniedForever) {
      return Container(
        key: const Key('warehouse-gps-status-denied'),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.errorBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Location permission unavailable',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.error,
          ),
        ),
      );
    }

    return Container(
      key: const Key('warehouse-gps-status-none'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.borderLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Location not captured',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondaryLight,
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
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
}
