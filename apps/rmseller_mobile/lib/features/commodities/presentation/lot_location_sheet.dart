import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../profile/domain/business_location_model.dart';
import '../domain/lot_location.dart';
import '../domain/master_commodity_data.dart';

/// Result of a device GPS + reverse-geocode lookup.
class GpsAddress {
  final String address;
  final String? stateId;
  final String? districtId;
  final String pinCode;

  /// Only certain results populate state/district; others fill the address only.
  final bool isCertain;

  const GpsAddress({
    this.address = '',
    this.stateId,
    this.districtId,
    this.pinCode = '',
    this.isCertain = false,
  });
}

typedef GpsAddressLookup = Future<GpsAddress?> Function();
typedef DistrictLoader = Future<List<MasterDistrict>> Function(String stateId);

/// Opens the Warehouse / Loading Location form. Returns null on cancel.
Future<LotLocation?> showLotLocationSheet({
  required BuildContext context,
  required LotLocation initial,
  required List<MasterState> states,
  required DistrictLoader loadDistricts,
  GpsAddressLookup? gpsLookup,
  bool highlightMissing = false,
  List<BusinessLocationModel> savedWarehouses = const [],
}) {
  return showModalBottomSheet<LotLocation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => LotLocationForm(
      initial: initial,
      states: states,
      loadDistricts: loadDistricts,
      gpsLookup: gpsLookup,
      highlightMissing: highlightMissing,
      savedWarehouses: savedWarehouses,
    ),
  );
}

class LotLocationForm extends StatefulWidget {
  final LotLocation initial;
  final List<MasterState> states;
  final DistrictLoader loadDistricts;
  final List<BusinessLocationModel> savedWarehouses;

  /// Null when no GPS provider is configured; the GPS action is then disabled.
  final GpsAddressLookup? gpsLookup;

  /// Validate on open, so only the missing required fields are flagged
  /// (saved values stay prefilled).
  final bool highlightMissing;

  const LotLocationForm({
    super.key,
    required this.initial,
    required this.states,
    required this.loadDistricts,
    this.gpsLookup,
    this.highlightMissing = false,
    this.savedWarehouses = const [],
  });

  @override
  State<LotLocationForm> createState() => _LotLocationFormState();
}

class _LotLocationFormState extends State<LotLocationForm> {
  final _formKey = GlobalKey<FormState>();
  late final _AddressFields _warehouse;
  late final _AddressFields _loading;
  late final _AddressFields _office;
  late final TextEditingController _loadingPoint;
  late bool _loadingShared;
  late bool _officeShared;
  bool _saving = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _warehouse = _AddressFields(i.warehouse);
    _loading = _AddressFields(i.loading);
    _office = _AddressFields(i.office);
    _loadingPoint = TextEditingController(text: i.loadingPoint);
    _loadingShared = i.loadingSameAsWarehouse;
    _officeShared = i.officeSameAsWarehouse;
    for (final f in [_warehouse, _loading, _office]) {
      if (f.stateId != null) _loadDistricts(f, keepDistrictName: true);
    }
  }

  @override
  void dispose() {
    _warehouse.dispose();
    _loading.dispose();
    _office.dispose();
    _loadingPoint.dispose();
    super.dispose();
  }

  Future<void> _loadDistricts(
    _AddressFields f, {
    bool keepDistrictName = false,
  }) async {
    final stateId = f.stateId;
    if (stateId == null) return;
    setState(() => f.loadingDistricts = true);
    List<MasterDistrict> list = [];
    try {
      list = await widget.loadDistricts(stateId);
    } catch (_) {}
    if (!mounted || f.stateId != stateId) return;
    setState(() {
      f.districts = list;
      f.loadingDistricts = false;
      // Resolve a decoded district name, otherwise drop an incompatible district.
      final match = list.where(
        (d) =>
            d.id == f.districtId ||
            (keepDistrictName &&
                f.pendingDistrictName.isNotEmpty &&
                d.name.toLowerCase() == f.pendingDistrictName.toLowerCase()),
      );
      f.districtId = match.isNotEmpty ? match.first.id : null;
      f.pendingDistrictName = '';
    });
  }

  void _onStateChanged(_AddressFields f, String? stateId) {
    if (stateId == null || stateId == f.stateId) return;
    setState(() {
      f.stateId = stateId;
      f.districtId = null;
      f.districts = [];
      _formError = null;
    });
    _loadDistricts(f);
  }

  Future<void> _useGps(_AddressFields f) async {
    final lookup = widget.gpsLookup;
    if (lookup == null) return;
    setState(() => f.locating = true);
    GpsAddress? result;
    try {
      result = await lookup();
    } catch (_) {}
    if (!mounted) return;
    setState(() => f.locating = false);
    if (result == null) {
      _snack('Could not get your location. Please enter the address manually.');
      return;
    }
    setState(() {
      if (result!.address.isNotEmpty) f.address.text = result.address;
      if (result.pinCode.isNotEmpty) f.pin.text = result.pinCode;
    });
    final known = widget.states.any((s) => s.id == result!.stateId);
    if (result.isCertain && known) {
      setState(() {
        f.stateId = result!.stateId;
        f.districtId = result.districtId;
      });
      await _loadDistricts(f);
    } else {
      _snack('Location found. Please select the state and district.');
    }
  }

  void _applyPresetWarehouse(BusinessLocationModel wh) {
    setState(() {
      _warehouse.label.text = wh.name;
      _warehouse.address.text = wh.addressLine;
      _warehouse.pin.text = wh.pinCode;
      _warehouse.stateId = wh.stateId;
      _warehouse.districtId = wh.districtId;
      _warehouse.pendingDistrictName = wh.districtName;
      _formError = null;
    });
    if (wh.stateId.isNotEmpty) {
      _loadDistricts(_warehouse, keepDistrictName: true);
    }
  }

  Future<void> _setShared({required bool loading, required bool value}) async {
    final fields = loading ? _loading : _office;
    if (value && fields.hasContent) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Use warehouse address?'),
          content: Text(
            'The separate ${loading ? 'loading' : 'office'} address you '
            'entered will be replaced by the warehouse address when you save.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep separate'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Use warehouse'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      if (loading) {
        _loadingShared = value;
      } else {
        _officeShared = value;
      }
      _formError = null;
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  void _save() {
    if (_saving) return;
    final ok = _formKey.currentState!.validate();
    if (!ok) {
      setState(() => _formError = 'Please complete the highlighted fields.');
      return;
    }
    setState(() => _saving = true);
    Navigator.pop(
      context,
      LotLocation(
        warehouse: _warehouse.toAddress(widget.states),
        loadingSameAsWarehouse: _loadingShared,
        loadingPoint: _loadingPoint.text.trim(),
        loading: _loadingShared
            ? const LotAddress()
            : _loading.toAddress(widget.states),
        officeSameAsWarehouse: _officeShared,
        office: _officeShared
            ? const LotAddress()
            : _office.toAddress(widget.states),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Form(
                  key: _formKey,
                  autovalidateMode: widget.highlightMissing
                      ? AutovalidateMode.always
                      : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      if (_formError != null) _errorBanner(_formError!),
                      _section(
                        icon: LucideIcons.warehouse,
                        title: 'Registered Warehouse / Storage Location',
                        children: [
                          if (widget.savedWarehouses.isNotEmpty) ...[
                            Text(
                              'Choose from saved warehouses:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                for (final wh in widget.savedWarehouses)
                                  ActionChip(
                                    key: Key('saved_warehouse_${wh.name.replaceAll(' ', '_')}'),
                                    avatar: const Icon(LucideIcons.warehouse, size: 14),
                                    label: Text(
                                      wh.name.isNotEmpty ? wh.name : wh.addressLine,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onPressed: () => _applyPresetWarehouse(wh),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          AppTextField(
                            controller: _warehouse.label,
                            label: 'Location name (optional)',
                            hint: 'e.g. Main Warehouse, Godown A',
                          ),
                          const SizedBox(height: 12),
                          ..._addressFields(_warehouse, required: true),
                        ],
                      ),
                      _section(
                        icon: LucideIcons.truck,
                        title: 'Actual Physical Loading / Dispatch Location',
                        children: [
                          _sameAsCheckbox(
                            key: const Key('loadingSameAsWarehouse'),
                            value: _loadingShared,
                            onChanged: (v) =>
                                _setShared(loading: true, value: v),
                          ),
                          if (_loadingShared) _sharedSummary(),
                          if (!_loadingShared) ...[
                            const SizedBox(height: 4),
                            ..._addressFields(_loading, required: true),
                          ],
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _loadingPoint,
                            label: 'Gate / shed / platform (optional)',
                            hint: 'e.g. Gate 2, Shed 4 loading platform',
                          ),
                        ],
                      ),
                      _section(
                        icon: LucideIcons.building2,
                        title: 'Enterprise Office Location (Registered HQ)',
                        children: [
                          _sameAsCheckbox(
                            key: const Key('officeSameAsWarehouse'),
                            value: _officeShared,
                            onChanged: (v) =>
                                _setShared(loading: false, value: v),
                          ),
                          if (_officeShared) _sharedSummary(),
                          if (!_officeShared) ...[
                            const SizedBox(height: 4),
                            AppTextField(
                              controller: _office.label,
                              label: 'Office name (optional)',
                              hint: 'e.g. Head Office',
                            ),
                            const SizedBox(height: 12),
                            ..._addressFields(_office, required: true),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _actions(),
          ],
        );
      },
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              const Icon(LucideIcons.mapPin, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Warehouse / Loading Location',
                  style: AppTypography.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
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
    // Material (not a decorated Container) so the checkbox tiles can ink.
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.grey.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
          ),
        ),
      ),
    );
  }

  Widget _sameAsCheckbox({
    required Key key,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return CheckboxListTile(
      key: key,
      value: value,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.primary,
      title: const Text(
        'Same as Registered Warehouse / Storage Location',
        style: TextStyle(fontSize: 13),
      ),
      onChanged: (v) => onChanged(v ?? false),
    );
  }

  /// Rebuilt with the warehouse controllers so it stays in sync while typing.
  Widget _sharedSummary() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _warehouse.label,
        _warehouse.address,
        _warehouse.pin,
      ]),
      builder: (context, _) {
        final text = _warehouse.toAddress(widget.states).summary;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.link, size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text.isEmpty
                      ? 'Uses the warehouse address above.'
                      : 'Uses warehouse: $text',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _addressFields(_AddressFields f, {required bool required}) {
    final gpsAvailable = widget.gpsLookup != null;
    return [
      OutlinedButton.icon(
        onPressed: gpsAvailable && !f.locating ? () => _useGps(f) : null,
        icon: f.locating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(LucideIcons.locateFixed, size: 16),
        label: Text(f.locating ? 'Locating…' : 'Use GPS Location'),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Text(
          gpsAvailable
              ? 'Or enter the address manually below.'
              : 'GPS is not available in this app yet. Enter the address manually below.',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondaryLight,
          ),
        ),
      ),
      AppTextField(
        controller: f.address,
        label: required ? 'Address *' : 'Address',
        hint: 'Plot / building, street, area',
        maxLines: 2,
        validator: (v) => required && (v == null || v.trim().isEmpty)
            ? 'Address is required'
            : null,
      ),
      const SizedBox(height: 12),
      // Keyed on the value so programmatic changes (GPS) re-seed initialValue.
      DropdownButtonFormField<String>(
        key: ValueKey('state-${f.hashCode}-${f.stateId}'),
        initialValue: widget.states.any((s) => s.id == f.stateId)
            ? f.stateId
            : null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'State *'),
        items: [
          for (final s in widget.states)
            DropdownMenuItem(
              value: s.id,
              child: Text(s.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (id) => _onStateChanged(f, id),
        validator: (v) => v == null ? 'Select a state' : null,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey(
          'district-${f.hashCode}-${f.stateId}-${f.districts.length}-${f.districtId}',
        ),
        initialValue: f.districts.any((d) => d.id == f.districtId)
            ? f.districtId
            : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'District *',
          hintText: f.loadingDistricts
              ? 'Loading…'
              : (f.stateId == null ? 'Select a state first' : 'Select'),
        ),
        items: [
          for (final d in f.districts)
            DropdownMenuItem(
              value: d.id,
              child: Text(d.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (id) => setState(() => f.districtId = id),
        validator: (v) => v == null ? 'Select a district' : null,
      ),
      const SizedBox(height: 12),
      AppTextField(
        controller: f.pin,
        label: 'PIN code',
        hint: '6 digits',
        keyboardType: TextInputType.number,
        validator: (v) {
          final t = v?.trim() ?? '';
          return t.isEmpty || RegExp(r'^\d{6}$').hasMatch(t)
              ? null
              : 'Enter a 6-digit PIN code';
        },
      ),
    ];
  }

  Widget _fitLabel(String text) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, style: AppTypography.labelLarge),
  );

  Widget _actions() {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          10 + MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            // Styled like AppButton, but labels scale down on narrow screens.
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _fitLabel('Cancel'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    elevation: 0,
                  ),
                  child: _fitLabel('Save Location'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mutable editing state for one address block.
class _AddressFields {
  final TextEditingController label;
  final TextEditingController address;
  final TextEditingController pin;
  String? stateId;
  String? districtId;
  String pendingDistrictName;
  List<MasterDistrict> districts = [];
  bool loadingDistricts = false;
  bool locating = false;

  _AddressFields(LotAddress a)
    : label = TextEditingController(text: a.label),
      address = TextEditingController(text: a.address),
      pin = TextEditingController(text: a.pinCode),
      stateId = a.stateId,
      districtId = a.districtId,
      pendingDistrictName = a.districtName;

  bool get hasContent =>
      label.text.trim().isNotEmpty ||
      address.text.trim().isNotEmpty ||
      pin.text.trim().isNotEmpty;

  LotAddress toAddress(List<MasterState> states) {
    String stateName = '';
    for (final s in states) {
      if (s.id == stateId) stateName = s.name;
    }
    String districtName = '';
    for (final d in districts) {
      if (d.id == districtId) districtName = d.name;
    }
    return LotAddress(
      label: label.text.trim(),
      address: address.text.trim(),
      stateId: stateId,
      stateName: stateName,
      districtId: districtId,
      districtName: districtName,
      pinCode: pin.text.trim(),
    );
  }

  void dispose() {
    label.dispose();
    address.dispose();
    pin.dispose();
  }
}
