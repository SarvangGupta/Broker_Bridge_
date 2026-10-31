import 'package:flutter/foundation.dart';

enum LocationRole { delivery, loading, both }

@immutable
class SavedLocation {
  final String id;
  final String companyId;
  final String name; // e.g. "Jaipur Main Warehouse", "Kota Godown"
  final String address; // e.g. "Ring Road, Vidhyadhar Nagar, Jaipur, Rajasthan - 302039"
  final String? city;
  final String? state;
  final String? pinCode;
  final String? addressLine; // Street part of [address], for editing
  final bool isPrimary;
  final LocationRole role;

  const SavedLocation({
    required this.id,
    required this.companyId,
    required this.name,
    required this.address,
    this.city,
    this.state,
    this.pinCode,
    this.addressLine,
    this.isPrimary = false,
    this.role = LocationRole.both,
  });

  /// Detailed immutable snapshot text representing this location at the time of transaction.
  String get locationSnapshot => '$name, $address';

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'name': name,
        'address': address,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (pinCode != null) 'pinCode': pinCode,
        'isPrimary': isPrimary,
        'role': role.name,
      };

  /// Maps a `company_warehouses` row. `state_id` and `district_id` stay as stored.
  factory SavedLocation.fromWarehouseRow(Map<String, dynamic> row) {
    final line = row['address_line']?.toString() ?? '';
    final pin = row['pin_code']?.toString();
    return SavedLocation(
      id: row['id']?.toString() ?? '',
      companyId: row['company_id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      address: pin == null || pin.isEmpty ? line : '$line - $pin',
      city: row['district_id']?.toString(),
      state: row['state_id']?.toString(),
      pinCode: pin,
      addressLine: line,
      isPrimary: row['is_default'] == true,
    );
  }

  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    return SavedLocation(
      id: json['id']?.toString() ?? '',
      companyId: json['companyId']?.toString() ?? json['company_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Warehouse Facility',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      pinCode: json['pinCode']?.toString() ?? json['pin_code']?.toString(),
      isPrimary: json['isPrimary'] == true || json['is_primary'] == true,
      role: json['role'] == 'delivery'
          ? LocationRole.delivery
          : json['role'] == 'loading'
              ? LocationRole.loading
              : LocationRole.both,
    );
  }

  SavedLocation copyWith({
    String? id,
    String? companyId,
    String? name,
    String? address,
    String? city,
    String? state,
    String? pinCode,
    bool? isPrimary,
    LocationRole? role,
  }) {
    return SavedLocation(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pinCode: pinCode ?? this.pinCode,
      isPrimary: isPrimary ?? this.isPrimary,
      role: role ?? this.role,
    );
  }
}

