import 'package:flutter/foundation.dart';

/// Represents a seller's physical shop, warehouse, or godown facility location.
@immutable
class BusinessLocationModel {
  final String name;
  final String addressLine;
  final String locality;
  final String stateId;
  final String stateName;
  final String districtId;
  final String districtName;
  final String pinCode;
  final double? latitude;
  final double? longitude;
  final bool isGpsDetected;

  const BusinessLocationModel({
    this.name = 'Bikaner Krishi Upaj Mandi Yard Godown A-4',
    this.addressLine = 'Plot 12, Industrial Area, Krishi Upaj Mandi Road',
    this.locality = 'Khara Industrial Area',
    this.stateId = '40000000-0000-0000-0000-000000000001',
    this.stateName = 'Rajasthan',
    this.districtId = '50000000-0000-0000-0000-000000000001',
    this.districtName = 'Bikaner Mandi Hub',
    this.pinCode = '334001',
    this.latitude = 28.0229,
    this.longitude = 73.3119,
    this.isGpsDetected = false,
  });

  BusinessLocationModel copyWith({
    String? name,
    String? addressLine,
    String? locality,
    String? stateId,
    String? stateName,
    String? districtId,
    String? districtName,
    String? pinCode,
    double? latitude,
    double? longitude,
    bool? isGpsDetected,
  }) {
    return BusinessLocationModel(
      name: name ?? this.name,
      addressLine: addressLine ?? this.addressLine,
      locality: locality ?? this.locality,
      stateId: stateId ?? this.stateId,
      stateName: stateName ?? this.stateName,
      districtId: districtId ?? this.districtId,
      districtName: districtName ?? this.districtName,
      pinCode: pinCode ?? this.pinCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isGpsDetected: isGpsDetected ?? this.isGpsDetected,
    );
  }

  factory BusinessLocationModel.fromMap(Map<String, dynamic> map) {
    return BusinessLocationModel(
      name:
          map['name']?.toString() ??
          'Bikaner Krishi Upaj Mandi Yard Godown A-4',
      addressLine:
          map['address_line']?.toString() ??
          map['addressLine']?.toString() ??
          'Plot 12, Industrial Area, Krishi Upaj Mandi Road',
      locality: map['locality']?.toString() ?? 'Khara Industrial Area',
      stateId:
          map['state_id']?.toString() ??
          map['stateId']?.toString() ??
          '40000000-0000-0000-0000-000000000001',
      stateName:
          map['state_name']?.toString() ??
          map['stateName']?.toString() ??
          'Rajasthan',
      districtId:
          map['district_id']?.toString() ??
          map['districtId']?.toString() ??
          '50000000-0000-0000-0000-000000000001',
      districtName:
          map['district_name']?.toString() ??
          map['districtName']?.toString() ??
          'Bikaner Mandi Hub',
      pinCode:
          map['pin_code']?.toString() ?? map['pinCode']?.toString() ?? '334001',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 28.0229,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 73.3119,
      isGpsDetected:
          map['is_gps_detected'] == true || map['isGpsDetected'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address_line': addressLine,
      'locality': locality,
      'state_id': stateId,
      'state_name': stateName,
      'district_id': districtId,
      'district_name': districtName,
      'pin_code': pinCode,
      'latitude': latitude,
      'longitude': longitude,
      'is_gps_detected': isGpsDetected,
    };
  }

  String get fullAddressText {
    final parts = [
      if (name.isNotEmpty) name,
      if (addressLine.isNotEmpty) addressLine,
      if (locality.isNotEmpty) locality,
      if (districtName.isNotEmpty) districtName,
      if (stateName.isNotEmpty) stateName,
      if (pinCode.isNotEmpty) 'PIN: $pinCode',
    ];
    return parts.join(', ');
  }
}
