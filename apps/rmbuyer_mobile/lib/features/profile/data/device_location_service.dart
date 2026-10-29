import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/company_warehouse.dart';

/// Status outcomes for GPS location capture.
enum DeviceLocationStatus {
  ok,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  poorAccuracy,
  invalidCoordinates,
  unavailable,
}

/// Result returned from attempting GPS location capture.
class DeviceLocationResult {
  final DeviceLocationStatus status;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime? timestamp;

  const DeviceLocationResult(
    this.status, {
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.timestamp,
  });

  bool get isOk => status == DeviceLocationStatus.ok;

  String get displayMessage {
    switch (status) {
      case DeviceLocationStatus.ok:
        return 'GPS Location captured successfully.';
      case DeviceLocationStatus.serviceDisabled:
        return 'Device GPS / Location Services are turned off. Please turn them on in device settings.';
      case DeviceLocationStatus.permissionDenied:
        return 'Location permission was denied. Permission is needed to record warehouse GPS coordinates.';
      case DeviceLocationStatus.permissionDeniedForever:
        return 'Location permission is permanently denied. Please enable it in App Settings.';
      case DeviceLocationStatus.timeout:
        return 'GPS fix timed out. Please ensure you have a clear view of the sky and retry.';
      case DeviceLocationStatus.poorAccuracy:
        return 'GPS signal is weak (accuracy: ±${accuracyMeters?.toStringAsFixed(0) ?? '?'}m). Please retry outdoors for better precision.';
      case DeviceLocationStatus.invalidCoordinates:
        return 'Captured coordinates were invalid. Please retry.';
      case DeviceLocationStatus.unavailable:
        return 'Unable to determine GPS location at this time.';
    }
  }
}

/// Abstract contract for acquiring device GPS position.
/// Allows clean mocking in unit and widget tests.
abstract class LocationProvider {
  Future<DeviceLocationResult> getCurrentPosition({
    double maxAcceptableAccuracyMeters = WarehouseValidation.acceptableAccuracyThresholdMeters,
    bool allowPoorAccuracy = false,
  });

  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

/// Geolocator-backed production implementation.
class DeviceLocationService implements LocationProvider {
  static const Duration fixTimeout = Duration(seconds: 25);

  const DeviceLocationService();

  @override
  Future<DeviceLocationResult> getCurrentPosition({
    double maxAcceptableAccuracyMeters = WarehouseValidation.acceptableAccuracyThresholdMeters,
    bool allowPoorAccuracy = false,
  }) async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return const DeviceLocationResult(DeviceLocationStatus.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const DeviceLocationResult(DeviceLocationStatus.permissionDeniedForever);
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        return const DeviceLocationResult(DeviceLocationStatus.permissionDenied);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: fixTimeout,
        ),
      );

      final lat = pos.latitude;
      final lng = pos.longitude;
      final accuracy = pos.accuracy > 0 ? pos.accuracy : null;

      if (!WarehouseValidation.isValidCoordinate(lat, lng)) {
        return const DeviceLocationResult(DeviceLocationStatus.invalidCoordinates);
      }

      // Check accuracy against configurable threshold
      if (!allowPoorAccuracy &&
          accuracy != null &&
          accuracy > maxAcceptableAccuracyMeters) {
        return DeviceLocationResult(
          DeviceLocationStatus.poorAccuracy,
          latitude: lat,
          longitude: lng,
          accuracyMeters: accuracy,
          timestamp: pos.timestamp,
        );
      }

      return DeviceLocationResult(
        DeviceLocationStatus.ok,
        latitude: lat,
        longitude: lng,
        accuracyMeters: accuracy,
        timestamp: pos.timestamp,
      );
    } on TimeoutException {
      return const DeviceLocationResult(DeviceLocationStatus.timeout);
    } on LocationServiceDisabledException {
      return const DeviceLocationResult(DeviceLocationStatus.serviceDisabled);
    } on PermissionDeniedException {
      return const DeviceLocationResult(DeviceLocationStatus.permissionDenied);
    } catch (e) {
      debugPrint('DeviceLocationService error: $e');
      return const DeviceLocationResult(DeviceLocationStatus.unavailable);
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

