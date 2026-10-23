import 'package:flutter/foundation.dart';

/// Representation of an authorized broker's profile details.
@immutable
class BrokerProfile {
  // Read-only protected fields
  final String id;
  final String role;
  final String accountStatus; // 'Active', 'Suspended', 'Pending'
  final bool isVerified;
  final int trustScore;

  // Editable profile fields
  final String fullName;
  final String mobile;
  final String email;
  final String brokerageName;
  final String businessAddress;
  final String operatingLocations; // e.g. "Jaipur Mandi, Kota, Alwar"
  final String commoditiesHandled; // e.g. "Mustard Seed, Soybean, Wheat"
  final String operatingRegions; // e.g. "Rajasthan, Madhya Pradesh, Gujarat"
  final String? profilePhotoPath;
  final DateTime updatedAt;

  const BrokerProfile({
    required this.id,
    required this.role,
    this.accountStatus = 'Active',
    this.isVerified = true,
    this.trustScore = 100,
    required this.fullName,
    required this.mobile,
    required this.email,
    this.brokerageName = 'RMBroker Trading Desk',
    this.businessAddress = '',
    this.operatingLocations = 'Jaipur Mandi, Rajasthan',
    this.commoditiesHandled = 'Mustard Seed, Soybean, Chana, Wheat',
    this.operatingRegions = 'North & Western Mandis',
    this.profilePhotoPath,
    required this.updatedAt,
  });

  /// Validate inputs before submission.
  String? validate() {
    if (fullName.trim().isEmpty) {
      return 'Full name cannot be empty';
    }
    if (fullName.trim().length < 2) {
      return 'Full name must be at least 2 characters';
    }
    if (mobile.trim().isEmpty) {
      return 'Mobile number cannot be empty';
    }
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    if (cleanMobile.length < 10) {
      return 'Mobile number must contain at least 10 digits';
    }
    if (email.trim().isEmpty) {
      return 'Email address cannot be empty';
    }
    final emailRegExp = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!emailRegExp.hasMatch(email.trim())) {
      return 'Enter a valid email address';
    }
    if (brokerageName.trim().isEmpty) {
      return 'Brokerage or business name cannot be empty';
    }
    return null;
  }

  BrokerProfile copyWith({
    String? fullName,
    String? mobile,
    String? email,
    String? brokerageName,
    String? businessAddress,
    String? operatingLocations,
    String? commoditiesHandled,
    String? operatingRegions,
    String? profilePhotoPath,
    DateTime? updatedAt,
  }) {
    return BrokerProfile(
      id: id,
      role: role,
      accountStatus: accountStatus,
      isVerified: isVerified,
      trustScore: trustScore,
      fullName: fullName ?? this.fullName,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      brokerageName: brokerageName ?? this.brokerageName,
      businessAddress: businessAddress ?? this.businessAddress,
      operatingLocations: operatingLocations ?? this.operatingLocations,
      commoditiesHandled: commoditiesHandled ?? this.commoditiesHandled,
      operatingRegions: operatingRegions ?? this.operatingRegions,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory BrokerProfile.fromJson(Map<String, dynamic> json) {
    return BrokerProfile(
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Broker',
      accountStatus: json['account_status']?.toString() ??
          json['accountStatus']?.toString() ??
          'Active',
      isVerified: json['is_verified'] as bool? ??
          json['isVerified'] as bool? ??
          true,
      trustScore: (json['trust_score'] as num? ??
              json['trustScore'] as num? ??
              100)
          .toInt(),
      fullName: json['full_name']?.toString() ??
          json['fullName']?.toString() ??
          json['name']?.toString() ??
          '',
      mobile: json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      brokerageName: json['brokerage_name']?.toString() ??
          json['brokerageName']?.toString() ??
          json['company_name']?.toString() ??
          'RMBroker Trading Desk',
      businessAddress: json['business_address']?.toString() ??
          json['businessAddress']?.toString() ??
          '',
      operatingLocations: json['operating_locations']?.toString() ??
          json['operatingLocations']?.toString() ??
          'Jaipur Mandi, Rajasthan',
      commoditiesHandled: json['commodities_handled']?.toString() ??
          json['commoditiesHandled']?.toString() ??
          'Mustard Seed, Soybean, Chana, Wheat',
      operatingRegions: json['operating_regions']?.toString() ??
          json['operatingRegions']?.toString() ??
          'North & Western Mandis',
      profilePhotoPath: json['profile_photo_path']?.toString() ??
          json['profilePhotoPath']?.toString(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'account_status': accountStatus,
      'is_verified': isVerified,
      'trust_score': trustScore,
      'full_name': fullName,
      'mobile': mobile,
      'email': email,
      'brokerage_name': brokerageName,
      'business_address': businessAddress,
      'operating_locations': operatingLocations,
      'commodities_handled': commoditiesHandled,
      'operating_regions': operatingRegions,
      'profile_photo_path': profilePhotoPath,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
