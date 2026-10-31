import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/saved_locations_repository.dart';
import '../../domain/saved_location_model.dart';
import '../controllers/master_data_controller.dart';
import 'trade_form_widgets.dart';

class ChangeLocationSheet extends ConsumerStatefulWidget {
  final String companyId;
  final String companyName;
  final String? currentLocationId;
  final LocationRole role;

  const ChangeLocationSheet({
    super.key,
    required this.companyId,
    required this.companyName,
    this.currentLocationId,
    required this.role,
  });

  static Future<SavedLocation?> show({
    required BuildContext context,
    required String companyId,
    required String companyName,
    String? currentLocationId,
    required LocationRole role,
  }) {
    return showModalBottomSheet<SavedLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChangeLocationSheet(
        companyId: companyId,
        companyName: companyName,
        currentLocationId: currentLocationId,
        role: role,
      ),
    );
  }

  @override
  ConsumerState<ChangeLocationSheet> createState() => _ChangeLocationSheetState();
}

class _ChangeLocationSheetState extends ConsumerState<ChangeLocationSheet> {
  List<SavedLocation> _locations = [];
  bool _isLoading = true;

  String? _loadError;
  bool _isAdding = false;
  SavedLocation? _editing;
  bool _isSavingNew = false;
  String? _addError;
  String? _newStateId;
  String? _newDistrictId;
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _startEdit(SavedLocation location) {
    final master = ref.read(masterDataProvider).value;
    setState(() {
      _editing = location;
      _isAdding = true;
      _addError = null;
      _nameController.text = location.name;
      _addressController.text = location.addressLine ?? location.address;
      _pinController.text = location.pinCode ?? '';
      _newStateId = master?.stateIdFor(location.state);
      _newDistrictId = master?.districtIdFor(location.city);
    });
  }

  Future<void> _saveNewLocation() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final pin = _pinController.text.trim();
    final String? error;
    if (name.isEmpty) {
      error = 'Please enter a location name';
    } else if (address.isEmpty) {
      error = 'Please enter the address';
    } else if (_newStateId == null) {
      error = 'Please select a state';
    } else if (_newDistrictId == null) {
      error = 'Please select a district';
    } else if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(pin)) {
      error = 'PIN code must be 6 digits';
    } else {
      error = null;
    }
    setState(() => _addError = error);
    if (error != null) return;

    setState(() => _isSavingNew = true);
    try {
      final repo = ref.read(savedLocationsRepositoryProvider);
      final editing = _editing;
      final saved = editing != null
          ? await repo.updateLocation(
              id: editing.id,
              companyId: widget.companyId,
              name: name,
              addressLine: address,
              stateId: _newStateId!,
              districtId: _newDistrictId!,
              pinCode: pin,
            )
          : await repo.addLocation(
              companyId: widget.companyId,
              name: name,
              addressLine: address,
              stateId: _newStateId!,
              districtId: _newDistrictId!,
              pinCode: pin,
            );
      if (mounted) Navigator.pop(context, saved);
    } on SavedLocationsUnavailable catch (e) {
      if (mounted) {
        setState(() {
          _isSavingNew = false;
          _addError = e.message;
        });
      }
    }
  }

  Widget _buildAddForm() {
    final master = ref.watch(masterDataProvider).value;
    final states = master?.states ?? const [];
    final districts = (master?.districts ?? const [])
        .where((d) => d.parentId == null || d.parentId == _newStateId)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_addError != null) TradeErrorBanner(message: _addError!),
        TextField(
          key: const Key('new_location_name'),
          controller: _nameController,
          decoration: tradeInputDecoration(hint: 'Location name'),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('new_location_address'),
          controller: _addressController,
          maxLines: 2,
          decoration: tradeInputDecoration(hint: 'Address'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const Key('new_location_state'),
          isExpanded: true,
          menuMaxHeight: 320,
          decoration: tradeInputDecoration(),
          hint: const Text('Select state', overflow: TextOverflow.ellipsis),
          initialValue: _newStateId,
          items: states
              .map((s) => DropdownMenuItem<String>(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (val) => setState(() {
            _newStateId = val;
            _newDistrictId = null;
          }),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey('new_location_district_$_newStateId'),
          isExpanded: true,
          menuMaxHeight: 320,
          decoration: tradeInputDecoration(),
          hint: const Text('Select district', overflow: TextOverflow.ellipsis),
          initialValue: _newDistrictId,
          items: districts
              .map((d) => DropdownMenuItem<String>(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: _newStateId == null ? null : (val) => setState(() => _newDistrictId = val),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('new_location_pin'),
          controller: _pinController,
          keyboardType: TextInputType.number,
          decoration: tradeInputDecoration(hint: 'PIN code'),
        ),
        const SizedBox(height: 12),
        TradeSaveButton(
          buttonKey: const Key('new_location_save'),
          label: _editing != null ? 'Update location' : 'Save location',
          savingLabel: 'Saving...',
          isSaving: _isSavingNew,
          onPressed: _saveNewLocation,
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final locs = await ref.read(savedLocationsRepositoryProvider).getSavedLocations(widget.companyId);
      if (mounted) {
        setState(() {
          _locations = locs;
          _isLoading = false;
        });
      }
    } on SavedLocationsUnavailable catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.message;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDelivery = widget.role == LocationRole.delivery;
    final title = isDelivery ? 'Select Delivery (Unloading) Location' : 'Select Stock Loading Location';
    final subtitle = widget.companyName.isNotEmpty ? widget.companyName : 'Counterparty Facilities';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.mapPin, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_loadError != null)
              Column(
                children: [
                  Text(_loadError!, style: const TextStyle(fontSize: 13, color: AppColors.error)),
                  TextButton(onPressed: _loadLocations, child: const Text('Retry')),
                ],
              )
            else if (_isAdding)
              _buildAddForm()
            else ...[
              if (_locations.isEmpty)
                _buildEmptyState()
              else
                ..._locations.map((loc) => _buildLocationCard(loc)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('add_location_btn'),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add location'),
                onPressed: () => setState(() => _isAdding = true),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(SavedLocation loc) {
    final isSelected = loc.id == widget.currentLocationId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryContainer.withValues(alpha: 0.25)
            : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.borderLight,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pop(context, loc),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Icon(LucideIcons.warehouse, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            loc.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        if (loc.isPrimary)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Primary',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.address,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('edit_location_${loc.id}'),
                tooltip: 'Edit location',
                icon: const Icon(LucideIcons.pencil, size: 16),
                onPressed: () => _startEdit(loc),
              ),
              Icon(
                isSelected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.textMutedLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(LucideIcons.mapPinOff, size: 36, color: AppColors.textMutedLight),
            SizedBox(height: 12),
            Text(
              'No Saved Locations',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              'No saved locations yet. Add one below.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
            ),
          ],
        ),
      ),
    );
  }
}
