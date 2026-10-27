import 'master_commodity_data.dart';

/// One address captured in the Warehouse / Loading Location form.
///
/// Only the warehouse state/district reach dedicated columns
/// (`availabilities.state_id` / `district_id`). Everything else is carried as
/// readable text in the existing fields (`warehouseName`, `loading_remarks`,
/// `officeLocation`), so [LotLocation] encodes and decodes that text.
class LotAddress {
  /// Optional facility name, or gate / shed / platform details for loading.
  final String label;
  final String address;
  final String? stateId;
  final String stateName;
  final String? districtId;
  final String districtName;
  final String pinCode;

  const LotAddress({
    this.label = '',
    this.address = '',
    this.stateId,
    this.stateName = '',
    this.districtId,
    this.districtName = '',
    this.pinCode = '',
  });

  bool get hasContent =>
      label.trim().isNotEmpty ||
      address.trim().isNotEmpty ||
      pinCode.trim().isNotEmpty;

  /// Short one-line summary for review cards.
  String get summary => [
    label,
    address,
    if (districtName.isNotEmpty || stateName.isNotEmpty)
      [districtName, stateName].where((s) => s.isNotEmpty).join(', '),
    if (pinCode.isNotEmpty) 'PIN $pinCode',
  ].where((s) => s.trim().isNotEmpty).join(' · ');
}

class LotLocation {
  static const String sameAsWarehouseMarker = 'Same as registered warehouse';
  static const String _sep = ' · ';

  final LotAddress warehouse;
  final bool loadingSameAsWarehouse;

  /// Gate / shed / platform details kept even when the loading address is shared.
  final String loadingPoint;
  final LotAddress loading;
  final bool officeSameAsWarehouse;
  final LotAddress office;

  const LotLocation({
    this.warehouse = const LotAddress(),
    this.loadingSameAsWarehouse = true,
    this.loadingPoint = '',
    this.loading = const LotAddress(),
    this.officeSameAsWarehouse = true,
    this.office = const LotAddress(),
  });

  /// Text stored in `warehouseName` (state/district go to their own columns).
  String get warehouseText => [
    warehouse.label,
    warehouse.address,
    if (warehouse.pinCode.isNotEmpty) 'PIN ${warehouse.pinCode}',
  ].where((s) => s.trim().isNotEmpty).join(_sep);

  /// Text stored in `loading_remarks`.
  String get loadingRemarksText => loadingSameAsWarehouse
      ? [
          sameAsWarehouseMarker,
          loadingPoint,
        ].where((s) => s.trim().isNotEmpty).join(_sep)
      : LotAddress(
          label: loadingPoint,
          address: loading.address,
          stateName: loading.stateName,
          districtName: loading.districtName,
          pinCode: loading.pinCode,
        ).summary;

  /// Text stored in `officeLocation`.
  String get officeText =>
      officeSameAsWarehouse ? sameAsWarehouseMarker : office.summary;

  /// Rebuilds the form state from the stored text fields.
  ///
  /// Legacy lots stored the same free text for warehouse and loading; that is
  /// read back as "same as warehouse". Unparseable text lands in the address
  /// field so nothing is silently dropped.
  static LotLocation decode({
    required String? warehouseText,
    required String? loadingText,
    required String? officeText,
    MasterState? warehouseState,
    MasterDistrict? warehouseDistrict,
    List<MasterState> states = const [],
  }) {
    final warehouse = _decodeWarehouse(warehouseText ?? '').withRegion(
      warehouseState,
      warehouseDistrict,
    );

    final loadingRaw = (loadingText ?? '').trim();
    bool loadingShared = true;
    String loadingPoint = '';
    LotAddress loading = const LotAddress();
    if (loadingRaw.startsWith(sameAsWarehouseMarker)) {
      loadingPoint = loadingRaw
          .substring(sameAsWarehouseMarker.length)
          .replaceFirst(RegExp(r'^\s*·\s*'), '')
          .trim();
    } else if (loadingRaw.isEmpty ||
        loadingRaw == (warehouseText ?? '').trim()) {
      loadingShared = true;
    } else {
      loadingShared = false;
      final parsed = _decodeAddress(loadingRaw, states);
      loadingPoint = parsed.label;
      loading = LotAddress(
        address: parsed.address,
        stateId: parsed.stateId,
        stateName: parsed.stateName,
        districtName: parsed.districtName,
        pinCode: parsed.pinCode,
      );
    }

    final officeRaw = (officeText ?? '').trim();
    final officeShared = officeRaw.isEmpty || officeRaw == sameAsWarehouseMarker;

    return LotLocation(
      warehouse: warehouse,
      loadingSameAsWarehouse: loadingShared,
      loadingPoint: loadingPoint,
      loading: loading,
      officeSameAsWarehouse: officeShared,
      office: officeShared ? const LotAddress() : _decodeAddress(officeRaw, states),
    );
  }

  static LotAddress _decodeWarehouse(String text) {
    final parts = _split(text);
    String pin = '';
    parts.removeWhere((p) {
      final m = RegExp(r'^PIN\s*(\d{6})$').firstMatch(p);
      if (m != null) pin = m.group(1)!;
      return m != null;
    });
    if (parts.length >= 2) {
      return LotAddress(
        label: parts.first,
        address: parts.sublist(1).join(_sep),
        pinCode: pin,
      );
    }
    return LotAddress(address: parts.join(_sep), pinCode: pin);
  }

  static LotAddress _decodeAddress(String text, List<MasterState> states) {
    final parts = _split(text);
    String pin = '';
    String? stateId;
    String stateName = '';
    String districtName = '';
    parts.removeWhere((p) {
      final m = RegExp(r'^PIN\s*(\d{6})$').firstMatch(p);
      if (m != null) {
        pin = m.group(1)!;
        return true;
      }
      for (final s in states) {
        final suffix = ', ${s.name}';
        if (p == s.name || p.endsWith(suffix)) {
          stateId = s.id;
          stateName = s.name;
          districtName = p == s.name
              ? ''
              : p.substring(0, p.length - suffix.length);
          return true;
        }
      }
      return false;
    });
    final hasLabel = parts.length >= 2;
    return LotAddress(
      label: hasLabel ? parts.first : '',
      address: (hasLabel ? parts.sublist(1) : parts).join(_sep),
      stateId: stateId,
      stateName: stateName,
      districtName: districtName,
      pinCode: pin,
    );
  }

  static List<String> _split(String text) => text
      .split('·')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

extension on LotAddress {
  LotAddress withRegion(MasterState? state, MasterDistrict? district) =>
      LotAddress(
        label: label,
        address: address,
        stateId: state?.id,
        stateName: state?.name ?? '',
        districtId: district?.id,
        districtName: district?.name ?? '',
        pinCode: pinCode,
      );
}
