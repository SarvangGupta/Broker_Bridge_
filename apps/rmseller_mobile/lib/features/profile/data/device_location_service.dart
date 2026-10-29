import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum DeviceLocationStatus { ok, serviceDisabled, permissionDenied, permissionDeniedForever, timeout, unavailable }

class DeviceLocationResult {
  final DeviceLocationStatus status;
  final double? latitude;
  final double? longitude;

  /// Reported accuracy radius in metres, when the platform provides it.
  final double? accuracyMeters;

  const DeviceLocationResult(this.status, {this.latitude, this.longitude, this.accuracyMeters});

  bool get isOk => status == DeviceLocationStatus.ok;
}

/// Reads the device's real GPS position for the warehouse map picker.
/// Never returns a substitute location: every failure is reported as a status.
class DeviceLocationService {
  const DeviceLocationService();

  static const Duration fixTimeout = Duration(seconds: 25);

  Future<DeviceLocationResult> getCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const DeviceLocationResult(DeviceLocationStatus.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const DeviceLocationResult(DeviceLocationStatus.permissionDeniedForever);
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
        return const DeviceLocationResult(DeviceLocationStatus.permissionDenied);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: fixTimeout),
      );
      return DeviceLocationResult(
        DeviceLocationStatus.ok,
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracyMeters: pos.accuracy > 0 ? pos.accuracy : null,
      );
    } on TimeoutException {
      return const DeviceLocationResult(DeviceLocationStatus.timeout);
    } on LocationServiceDisabledException {
      return const DeviceLocationResult(DeviceLocationStatus.serviceDisabled);
    } on PermissionDeniedException {
      return const DeviceLocationResult(DeviceLocationStatus.permissionDenied);
    } catch (_) {
      return const DeviceLocationResult(DeviceLocationStatus.unavailable);
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
