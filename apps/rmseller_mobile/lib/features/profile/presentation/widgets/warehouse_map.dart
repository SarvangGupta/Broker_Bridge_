import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/device_location_service.dart';
import '../profile_strings.dart';

/// OpenStreetMap tiles (no API key). Tests switch tiles off to avoid network calls.
class WarehouseMapTiles {
  static bool enabled = true;

  static List<Widget> layers() => [
        if (enabled)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.brokerbridge.rmseller_mobile',
          ),
      ];
}

/// Google Maps link for confirmed coordinates (search URL — opens the app or browser).
Uri googleMapsUri(double lat, double lng) => Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}');

/// The removed "Use Current Location" stub always returned this Bikaner point and the model
/// used it as a default. Such stored values are kept but never presented as a confirmed pin.
bool isLegacyPlaceholderCoordinates(double lat, double lng) =>
    (lat - 28.0229).abs() < 1e-6 && (lng - 73.3119).abs() < 1e-6;

String formatCoordinates(double lat, double lng) => '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

Widget _pin() => const Icon(Icons.location_on, color: AppColors.primary, size: 40);

/// Small non-interactive map showing the confirmed warehouse pin.
class WarehouseMapPreview extends StatelessWidget {
  final double latitude;
  final double longitude;

  const WarehouseMapPreview({super.key, required this.latitude, required this.longitude});

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 150,
        child: FlutterMap(
          key: ValueKey('preview-$latitude-$longitude'),
          options: MapOptions(
            initialCenter: point,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            ...WarehouseMapTiles.layers(),
            MarkerLayer(markers: [Marker(point: point, width: 40, height: 40, alignment: Alignment.topCenter, child: _pin())]),
          ],
        ),
      ),
    );
  }
}

/// Full-screen picker. Returns the confirmed [LatLng], or null when cancelled.
/// Nothing is selected until the seller taps the map or uses their current location.
class WarehouseMapPickerScreen extends StatefulWidget {
  final LatLng? initial;
  final ProfileStrings strings;
  final DeviceLocationService locationService;

  const WarehouseMapPickerScreen({
    super.key,
    required this.strings,
    this.initial,
    this.locationService = const DeviceLocationService(),
  });

  @override
  State<WarehouseMapPickerScreen> createState() => _WarehouseMapPickerScreenState();
}

class _WarehouseMapPickerScreenState extends State<WarehouseMapPickerScreen> {
  static const _indiaCenter = LatLng(22.5, 79.0);
  final _mapController = MapController();
  LatLng? _selected;
  bool _locating = false;
  String? _notice;
  DeviceLocationStatus? _lastFailure;

  /// Set only when the pin came from a live GPS fix (cleared when the seller moves it).
  double? _fixAccuracy;
  bool _pinFromPhone = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  Future<void> _useCurrentLocation() async {
    final s = widget.strings;
    setState(() {
      _locating = true;
      _notice = null;
      _lastFailure = null;
    });
    final r = await widget.locationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (r.isOk) {
        _selected = LatLng(r.latitude!, r.longitude!);
        _pinFromPhone = true;
        _fixAccuracy = r.accuracyMeters;
        try {
          _mapController.move(_selected!, 17);
        } catch (_) {
          // Map not laid out (e.g. tiles/offline); the pin and coordinates still update.
        }
      } else {
        _lastFailure = r.status;
        _notice = switch (r.status) {
          DeviceLocationStatus.serviceDisabled => s.locationServiceOff,
          DeviceLocationStatus.permissionDenied => s.locationPermissionDenied,
          DeviceLocationStatus.permissionDeniedForever => s.locationPermissionBlocked,
          DeviceLocationStatus.timeout => s.locationTimeout,
          _ => s.locationUnavailable,
        };
      }
    });
  }

  void _placePin(LatLng point) => setState(() {
        _selected = point;
        _pinFromPhone = false;
        _fixAccuracy = null;
      });

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final sel = _selected;
    return Scaffold(
      appBar: AppBar(title: Text(s.setWarehouseOnMap)),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              key: const Key('warehouse_map_picker'),
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.initial ?? _indiaCenter,
                initialZoom: widget.initial != null ? 16 : 5,
                onTap: (_, point) => _placePin(point),
              ),
              children: [
                ...WarehouseMapTiles.layers(),
                if (sel != null)
                  MarkerLayer(markers: [Marker(point: sel, width: 40, height: 40, alignment: Alignment.topCenter, child: _pin())]),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    sel == null ? s.tapMapToPlacePin : formatCoordinates(sel.latitude, sel.longitude),
                    key: const Key('warehouse_picker_coordinates'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (_pinFromPhone && sel != null) ...[
                    const SizedBox(height: 4),
                    if (_fixAccuracy != null)
                      Text(s.accuracyLabel(_fixAccuracy!.round()), key: const Key('warehouse_picker_accuracy'),
                          textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                    Text(s.phoneLocationNotice, key: const Key('warehouse_picker_phone_notice'), textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: AppColors.info)),
                  ],
                  if (_notice != null) ...[
                    const SizedBox(height: 6),
                    Text(_notice!, key: const Key('warehouse_picker_notice'), textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppColors.warning)),
                    if (_lastFailure == DeviceLocationStatus.permissionDeniedForever ||
                        _lastFailure == DeviceLocationStatus.serviceDisabled)
                      TextButton(
                        key: const Key('btn_picker_open_settings'),
                        onPressed: () => _lastFailure == DeviceLocationStatus.serviceDisabled
                            ? widget.locationService.openLocationSettings()
                            : widget.locationService.openAppSettings(),
                        child: Text(s.openSettings),
                      ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('btn_picker_use_current_location'),
                    onPressed: _locating ? null : _useCurrentLocation,
                    icon: _locating
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.locateFixed, size: 16),
                    label: Text(_lastFailure != null ? s.retry : s.useMyCurrentLocation),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('btn_picker_cancel'),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(s.cancel),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          key: const Key('btn_picker_confirm'),
                          onPressed: sel == null ? null : () => Navigator.of(context).pop(sel),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                          child: Text(s.confirmLocation),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
