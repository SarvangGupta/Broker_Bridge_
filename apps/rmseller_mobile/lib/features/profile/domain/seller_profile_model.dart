import 'business_location_model.dart';

/// Domain entity representing an authenticated Seller's profile and enterprise details.
class SellerProfileModel {
  final String id;
  final String fullName;
  final String email;
  final String mobile;
  final String role;
  final String companyId;
  final String companyName;
  final String companyGst;
  final String primaryMandi;
  final String state;
  final String district;
  final String businessType;
  final int trustScore;
  final bool isVerified;
  final String officeAddress;
  final BusinessLocationModel businessLocation;

  const SellerProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.mobile = '',
    required this.role,
    this.companyId = '',
    this.companyName = '',
    this.companyGst = '',
    this.primaryMandi = 'Bikaner Krishi Upaj Mandi',
    this.state = 'Rajasthan',
    this.district = 'Bikaner',
    this.businessType = 'Commodity Processor & Mill',
    this.trustScore = 98,
    this.isVerified = true,
    this.officeAddress = 'Commercial Tower 4, Bikaner Corporate Hub',
    this.businessLocation = const BusinessLocationModel(),
  });

  SellerProfileModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? mobile,
    String? role,
    String? companyId,
    String? companyName,
    String? companyGst,
    String? primaryMandi,
    String? state,
    String? district,
    String? businessType,
    int? trustScore,
    bool? isVerified,
    String? officeAddress,
    BusinessLocationModel? businessLocation,
  }) {
    return SellerProfileModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      role: role ?? this.role,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyGst: companyGst ?? this.companyGst,
      primaryMandi: primaryMandi ?? this.primaryMandi,
      state: state ?? this.state,
      district: district ?? this.district,
      businessType: businessType ?? this.businessType,
      trustScore: trustScore ?? this.trustScore,
      isVerified: isVerified ?? this.isVerified,
      officeAddress: officeAddress ?? this.officeAddress,
      businessLocation: businessLocation ?? this.businessLocation,
    );
  }

  factory SellerProfileModel.fromMap(Map<String, dynamic> map) {
    BusinessLocationModel location;
    if (map['business_location'] is Map<String, dynamic>) {
      location = BusinessLocationModel.fromMap(
        map['business_location'] as Map<String, dynamic>,
      );
    } else {
      location = BusinessLocationModel(
        name:
            map['location_name']?.toString() ??
            'Bikaner Krishi Upaj Mandi Yard Godown A-4',
        addressLine:
            map['location_address']?.toString() ??
            'Plot 12, Industrial Area, Krishi Upaj Mandi Road',
        locality:
            map['location_locality']?.toString() ?? 'Khara Industrial Area',
        stateName:
            map['location_state']?.toString() ??
            map['state']?.toString() ??
            'Rajasthan',
        districtName:
            map['location_district']?.toString() ??
            map['district']?.toString() ??
            'Bikaner Mandi Hub',
        pinCode: map['location_pincode']?.toString() ?? '334001',
      );
    }

    return SellerProfileModel(
      id: map['id']?.toString() ?? '',
      fullName:
          map['name']?.toString() ??
          map['fullName']?.toString() ??
          map['full_name']?.toString() ??
          'Seller Lead',
      email: map['email']?.toString() ?? '',
      mobile: map['mobile']?.toString() ?? '',
      role: map['role']?.toString().toLowerCase().trim() ?? 'seller',
      companyId:
          map['company_id']?.toString() ?? map['companyId']?.toString() ?? '',
      companyName:
          map['company_name']?.toString() ??
          map['companyName']?.toString() ??
          'Bikaner Agro Processing Ltd',
      companyGst:
          map['company_gst']?.toString() ??
          map['companyGst']?.toString() ??
          map['gst']?.toString() ??
          '08AAAAA0000A1Z5',
      primaryMandi:
          map['primary_mandi']?.toString() ??
          map['primaryMandi']?.toString() ??
          'Bikaner Krishi Upaj Mandi',
      state: map['state']?.toString() ?? 'Rajasthan',
      district: map['district']?.toString() ?? 'Bikaner',
      businessType:
          map['business_type']?.toString() ??
          map['businessType']?.toString() ??
          'Commodity Processor & Mill',
      trustScore: (map['trust_score'] as num?)?.toInt() ?? 98,
      isVerified: map['is_verified'] == true,
      officeAddress:
          map['office_address']?.toString() ??
          'Commercial Tower 4, Bikaner Corporate Hub',
      businessLocation: location,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': fullName,
      'email': email,
      'mobile': mobile,
      'role': role,
      'company_id': companyId,
      'company_name': companyName,
      'company_gst': companyGst,
      'primary_mandi': primaryMandi,
      'state': state,
      'district': district,
      'business_type': businessType,
      'trust_score': trustScore,
      'is_verified': isVerified,
      'office_address': officeAddress,
      'business_location': businessLocation.toMap(),
    };
  }
}
