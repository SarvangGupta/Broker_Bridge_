/// Operational warehouse or unloading location for a buyer enterprise.
///
/// Distinct from the company's registered GST address: a company may have
/// one legal registered address and multiple operational delivery / unloading
/// warehouses.
class CompanyWarehouse {
  final String id;
  final String companyId;
  final String createdBy;
  final String name;
  final String addressLine;
  final String? stateId;
  final String? districtId;
  final String? pinCode;
  final String? contactPerson;
  final String? contactPhone;
  final String? unloadingNotes;
  final bool isActive;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracy;
  final DateTime? locationCapturedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CompanyWarehouse({
    required this.id,
    required this.companyId,
    required this.createdBy,
    required this.name,
    required this.addressLine,
    this.stateId,
    this.districtId,
    this.pinCode,
    this.contactPerson,
    this.contactPhone,
    this.unloadingNotes,
    this.isActive = true,
    this.latitude,
    this.longitude,
    this.gpsAccuracy,
    this.locationCapturedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether valid, bounded GPS coordinates are present for this warehouse.
  bool get hasGpsCoordinates =>
      WarehouseValidation.isValidCoordinate(latitude, longitude);

  /// Authoritative Google Maps URL constructed directly from saved coordinates.
  /// Returns null if coordinates are not captured or invalid.
  String? get googleMapsUrl =>
      WarehouseValidation.buildGoogleMapsUrl(latitude, longitude);

  factory CompanyWarehouse.fromRow(Map<String, dynamic> row) {
    DateTime parseDate(Object? val) {
      if (val is DateTime) return val;
      return DateTime.tryParse(val?.toString() ?? '') ?? DateTime.now();
    }

    DateTime? parseNullableDate(Object? val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    double? parseDouble(Object? val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return CompanyWarehouse(
      id: row['id']?.toString() ?? '',
      companyId: row['company_id']?.toString() ?? '',
      createdBy: row['created_by']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      addressLine: row['address_line']?.toString() ?? '',
      stateId: row['state_id']?.toString(),
      districtId: row['district_id']?.toString(),
      pinCode: row['pin_code']?.toString(),
      contactPerson: row['contact_person']?.toString(),
      contactPhone: row['contact_phone']?.toString(),
      unloadingNotes: row['unloading_notes']?.toString(),
      isActive: row['is_active'] != false,
      latitude: parseDouble(row['latitude']),
      longitude: parseDouble(row['longitude']),
      gpsAccuracy: parseDouble(row['gps_accuracy']),
      locationCapturedAt: parseNullableDate(row['location_captured_at']),
      createdAt: parseDate(row['created_at']),
      updatedAt: parseDate(row['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'company_id': companyId,
      'created_by': createdBy,
      'name': name.trim(),
      'address_line': addressLine.trim(),
      'state_id': stateId,
      'district_id': districtId,
      'pin_code': pinCode?.trim().isEmpty == true ? null : pinCode?.trim(),
      'contact_person':
          contactPerson?.trim().isEmpty == true ? null : contactPerson?.trim(),
      'contact_phone':
          contactPhone?.trim().isEmpty == true ? null : contactPhone?.trim(),
      'unloading_notes':
          unloadingNotes?.trim().isEmpty == true ? null : unloadingNotes?.trim(),
      'is_active': isActive,
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': gpsAccuracy,
      'location_captured_at': locationCapturedAt?.toUtc().toIso8601String(),
    };
  }

  CompanyWarehouse copyWith({
    String? id,
    String? companyId,
    String? createdBy,
    String? name,
    String? addressLine,
    String? stateId,
    String? districtId,
    String? pinCode,
    String? contactPerson,
    String? contactPhone,
    String? unloadingNotes,
    bool? isActive,
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    DateTime? locationCapturedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearCoordinates = false,
  }) {
    return CompanyWarehouse(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      createdBy: createdBy ?? this.createdBy,
      name: name ?? this.name,
      addressLine: addressLine ?? this.addressLine,
      stateId: stateId ?? this.stateId,
      districtId: districtId ?? this.districtId,
      pinCode: pinCode ?? this.pinCode,
      contactPerson: contactPerson ?? this.contactPerson,
      contactPhone: contactPhone ?? this.contactPhone,
      unloadingNotes: unloadingNotes ?? this.unloadingNotes,
      isActive: isActive ?? this.isActive,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      gpsAccuracy: clearCoordinates ? null : (gpsAccuracy ?? this.gpsAccuracy),
      locationCapturedAt: clearCoordinates
          ? null
          : (locationCapturedAt ?? this.locationCapturedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Validation rules for operational warehouses and coordinates.
class WarehouseValidation {
  const WarehouseValidation._();

  static const int nameMin = 2;
  static const int nameMax = 100;
  static const int addressMin = 5;
  static const int addressMax = 300;

  /// Latitude must be between -90 and +90 degrees.
  static const double minLatitude = -90.0;
  static const double maxLatitude = 90.0;

  /// Longitude must be between -180 and +180 degrees.
  static const double minLongitude = -180.0;
  static const double maxLongitude = 180.0;

  /// Configurable acceptable GPS accuracy threshold in meters.
  /// Fixes with higher radius are flagged for retry.
  static const double acceptableAccuracyThresholdMeters = 100.0;

  static String? validateName(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return 'Warehouse or location name is required.';
    if (v.length < nameMin) return 'Name must be at least $nameMin characters.';
    if (v.length > nameMax) return 'Name cannot exceed $nameMax characters.';
    return null;
  }

  static String? validateAddress(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return 'Full address is required.';
    if (v.length < addressMin) {
      return 'Address must be at least $addressMin characters.';
    }
    if (v.length > addressMax) {
      return 'Address cannot exceed $addressMax characters.';
    }
    return null;
  }

  static String? validatePinCode(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(v)) {
      return 'Enter a valid 6-digit Indian PIN code.';
    }
    return null;
  }

  static String? validatePhone(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return null;
    final digits = v.replaceAll(RegExp(r'[\s-]'), '');
    final norm = digits.startsWith('+91')
        ? digits.substring(3)
        : (digits.length == 11 && digits.startsWith('0'))
            ? digits.substring(1)
            : digits;
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(norm)) {
      return 'Enter a valid 10-digit mobile number.';
    }
    return null;
  }

  /// Validates that both latitude and longitude are valid numbers within realistic bounds.
  static bool isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lat.isInfinite || lng.isNaN || lng.isInfinite) return false;
    if (lat < minLatitude || lat > maxLatitude) return false;
    if (lng < minLongitude || lng > maxLongitude) return false;
    // Disallow exact (0.0, 0.0) null-island coordinates
    if (lat.abs() < 0.000001 && lng.abs() < 0.000001) return false;
    return true;
  }

  /// Builds a clean Google Maps URL in format:
  /// `https://www.google.com/maps/search/?api=1&query=LATITUDE%2CLONGITUDE`
  /// Never fabricates a URL if coordinates are invalid or missing.
  static String? buildGoogleMapsUrl(double? lat, double? lng) {
    if (!isValidCoordinate(lat, lng)) return null;
    final query = Uri.encodeComponent('$lat,$lng');
    return 'https://www.google.com/maps/search/?api=1&query=$query';
  }
}
