import 'package:flutter/foundation.dart';
import '../../directory/domain/gst_certificate_data.dart';

/// Distinct GST verification statuses for broker desks.
class BrokerGstStatus {
  const BrokerGstStatus._();

  static const String gstMissing = 'gst_missing';
  static const String pending = 'pending';
  static const String certificateUploaded = 'certificate_uploaded';
  static const String certificateReviewed = 'certificate_reviewed';
  static const String gstMatched = 'gst_matched';
  static const String inactive = 'inactive';
  static const String failed = 'failed';

  static String displayLabel(String? status) {
    switch (status?.toLowerCase().trim()) {
      case gstMissing:
        return 'GST Details Missing';
      case pending:
        return 'Pending Verification';
      case certificateUploaded:
        return 'Certificate Uploaded';
      case certificateReviewed:
        return 'Broker Verified — Certificate Reviewed';
      case gstMatched:
        return 'GST Details Matched with Official GST Portal';
      case inactive:
        return 'GST Registration Inactive';
      case failed:
        return 'Verification Failed';
      default:
        return 'Pending Verification';
    }
  }
}

/// Representation of an authorized broker's profile details.
@immutable
class BrokerProfile {
  // Read-only protected fields
  final String id;
  final String role;
  final String accountStatus; // 'Active', 'Suspended', 'Pending'
  final bool isVerified;
  final int trustScore;

  // Personal Details
  final String fullName;
  final String mobile;
  final String email;
  final String designation;
  final String? profilePhotoPath;

  // Business Details
  final String brokerageName;
  final String businessType; // Proprietorship, Partnership, LLP, Private Limited, etc.
  final String businessAddress;
  final String city;
  final String state;
  final String pincode;
  final String businessContactNumber;

  // Trading Desk Operational Fields
  final String operatingLocations;
  final String commoditiesHandled;
  final String operatingRegions;

  // GST Registration & Certificate Details
  final String gstin;
  final String legalName;
  final String tradeName;
  final String constitution;
  final String registrationDate;
  final String gstStatus; // Active, Inactive, Cancelled
  final String principalPlaceOfBusiness;
  final String? gstCertificateUrl;
  final String? gstCertificatePath;
  final String gstVerificationStatus;
  final String? gstVerificationSource;
  final DateTime? gstVerifiedAt;

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
    this.designation = 'Senior Mandi Broker',
    this.profilePhotoPath,
    this.brokerageName = 'RMBroker Trading Desk',
    this.businessType = 'Proprietorship',
    this.businessAddress = '',
    this.city = 'Jaipur',
    this.state = 'Rajasthan',
    this.pincode = '302003',
    this.businessContactNumber = '',
    this.operatingLocations = 'Jaipur Mandi, Kota, Alwar',
    this.commoditiesHandled = 'Mustard Seed, Soybean, Chana, Wheat',
    this.operatingRegions = 'North & Western Mandis',
    this.gstin = '',
    this.legalName = '',
    this.tradeName = '',
    this.constitution = 'Proprietorship',
    this.registrationDate = '',
    this.gstStatus = 'Active',
    this.principalPlaceOfBusiness = '',
    this.gstCertificateUrl,
    this.gstCertificatePath,
    this.gstVerificationStatus = BrokerGstStatus.pending,
    this.gstVerificationSource,
    this.gstVerifiedAt,
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
    if (pincode.trim().isNotEmpty && !RegExp(r'^\d{6}$').hasMatch(pincode.trim())) {
      return 'PIN code must be a valid 6-digit number';
    }
    if (gstin.trim().isNotEmpty) {
      final normalizedGst = GstinRules.normalize(gstin);
      if (!GstinRules.hasValidFormat(normalizedGst)) {
        return 'GSTIN must follow the 15-character standard format (e.g. 08AAAAA0000A1Z5)';
      }
    }
    return null;
  }

  BrokerProfile copyWith({
    String? fullName,
    String? mobile,
    String? email,
    String? designation,
    String? profilePhotoPath,
    String? brokerageName,
    String? businessType,
    String? businessAddress,
    String? city,
    String? state,
    String? pincode,
    String? businessContactNumber,
    String? operatingLocations,
    String? commoditiesHandled,
    String? operatingRegions,
    String? gstin,
    String? legalName,
    String? tradeName,
    String? constitution,
    String? registrationDate,
    String? gstStatus,
    String? principalPlaceOfBusiness,
    String? gstCertificateUrl,
    String? gstCertificatePath,
    String? gstVerificationStatus,
    String? gstVerificationSource,
    DateTime? gstVerifiedAt,
    bool resetVerification = false,
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
      designation: designation ?? this.designation,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      brokerageName: brokerageName ?? this.brokerageName,
      businessType: businessType ?? this.businessType,
      businessAddress: businessAddress ?? this.businessAddress,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      businessContactNumber: businessContactNumber ?? this.businessContactNumber,
      operatingLocations: operatingLocations ?? this.operatingLocations,
      commoditiesHandled: commoditiesHandled ?? this.commoditiesHandled,
      operatingRegions: operatingRegions ?? this.operatingRegions,
      gstin: gstin ?? this.gstin,
      legalName: legalName ?? this.legalName,
      tradeName: tradeName ?? this.tradeName,
      constitution: constitution ?? this.constitution,
      registrationDate: registrationDate ?? this.registrationDate,
      gstStatus: gstStatus ?? this.gstStatus,
      principalPlaceOfBusiness:
          principalPlaceOfBusiness ?? this.principalPlaceOfBusiness,
      gstCertificateUrl: gstCertificateUrl ?? this.gstCertificateUrl,
      gstCertificatePath: gstCertificatePath ?? this.gstCertificatePath,
      gstVerificationStatus:
          gstVerificationStatus ?? this.gstVerificationStatus,
      gstVerificationSource: resetVerification
          ? null
          : (gstVerificationSource ?? this.gstVerificationSource),
      gstVerifiedAt: resetVerification
          ? null
          : (gstVerifiedAt ?? this.gstVerifiedAt),
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
      designation: json['designation']?.toString() ?? 'Senior Mandi Broker',
      profilePhotoPath: json['profile_photo_path']?.toString() ??
          json['profilePhotoPath']?.toString(),
      brokerageName: json['brokerage_name']?.toString() ??
          json['brokerageName']?.toString() ??
          json['company_name']?.toString() ??
          'RMBroker Trading Desk',
      businessType: json['business_type']?.toString() ??
          json['businessType']?.toString() ??
          'Proprietorship',
      businessAddress: json['business_address']?.toString() ??
          json['businessAddress']?.toString() ??
          '',
      city: json['city']?.toString() ?? 'Jaipur',
      state: json['state']?.toString() ?? 'Rajasthan',
      pincode: json['pincode']?.toString() ??
          json['pin_code']?.toString() ??
          '302003',
      businessContactNumber: json['business_contact_number']?.toString() ??
          json['businessContactNumber']?.toString() ??
          '',
      operatingLocations: json['operating_locations']?.toString() ??
          json['operatingLocations']?.toString() ??
          'Jaipur Mandi, Kota, Alwar',
      commoditiesHandled: json['commodities_handled']?.toString() ??
          json['commoditiesHandled']?.toString() ??
          'Mustard Seed, Soybean, Chana, Wheat',
      operatingRegions: json['operating_regions']?.toString() ??
          json['operatingRegions']?.toString() ??
          'North & Western Mandis',
      gstin: json['gstin']?.toString() ?? json['gst']?.toString() ?? '',
      legalName: json['legal_name']?.toString() ??
          json['legalName']?.toString() ??
          '',
      tradeName: json['trade_name']?.toString() ??
          json['tradeName']?.toString() ??
          '',
      constitution: json['constitution']?.toString() ?? 'Proprietorship',
      registrationDate: json['registration_date']?.toString() ??
          json['registrationDate']?.toString() ??
          '',
      gstStatus: json['gst_status']?.toString() ??
          json['gstStatus']?.toString() ??
          'Active',
      principalPlaceOfBusiness: json['principal_place_of_business']?.toString() ??
          json['principalPlaceOfBusiness']?.toString() ??
          '',
      gstCertificateUrl: json['gst_certificate_url']?.toString() ??
          json['gstCertificateUrl']?.toString(),
      gstCertificatePath: json['gst_certificate_path']?.toString() ??
          json['gstCertificatePath']?.toString(),
      gstVerificationStatus: json['gst_verification_status']?.toString() ??
          json['gstVerificationStatus']?.toString() ??
          BrokerGstStatus.pending,
      gstVerificationSource: json['gst_verification_source']?.toString() ??
          json['gstVerificationSource']?.toString(),
      gstVerifiedAt: json['gst_verified_at'] != null
          ? DateTime.tryParse(json['gst_verified_at'].toString())
          : null,
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
      'designation': designation,
      'profile_photo_path': profilePhotoPath,
      'brokerage_name': brokerageName,
      'business_type': businessType,
      'business_address': businessAddress,
      'city': city,
      'state': state,
      'pincode': pincode,
      'business_contact_number': businessContactNumber,
      'operating_locations': operatingLocations,
      'commodities_handled': commoditiesHandled,
      'operating_regions': operatingRegions,
      'gstin': gstin,
      'legal_name': legalName,
      'trade_name': tradeName,
      'constitution': constitution,
      'registration_date': registrationDate,
      'gst_status': gstStatus,
      'principal_place_of_business': principalPlaceOfBusiness,
      'gst_certificate_url': gstCertificateUrl,
      'gst_certificate_path': gstCertificatePath,
      'gst_verification_status': gstVerificationStatus,
      'gst_verification_source': gstVerificationSource,
      'gst_verified_at': gstVerifiedAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
