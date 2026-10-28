import 'business_location_model.dart';
import 'seller_bank_details.dart';
import 'seller_commodity_expertise.dart';

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
  final SellerBankDetails bankDetails;
  final String? invoiceDocumentUrl;
  final String? invoiceDocumentName;
  final String? chequeDocumentUrl;
  final String? chequeDocumentName;
  final String businessIdentifier;
  final String versionIdentifier;
  final List<SellerCommodityExpertise> commodityExpertise;

  const SellerProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.mobile = '',
    required this.role,
    this.companyId = '',
    this.companyName = '',
    this.businessIdentifier = '',
    this.versionIdentifier = '',
    this.companyGst = '',
    this.primaryMandi = 'Bikaner Krishi Upaj Mandi',
    this.state = 'Rajasthan',
    this.district = 'Bikaner',
    this.businessType = 'Commodity Processor & Mill',
    this.trustScore = 98,
    this.isVerified = true,
    this.officeAddress = 'Commercial Tower 4, Bikaner Corporate Hub',
    this.businessLocation = const BusinessLocationModel(),
    this.bankDetails = const SellerBankDetails(),
    this.invoiceDocumentUrl,
    this.invoiceDocumentName,
    this.chequeDocumentUrl,
    this.chequeDocumentName,
    this.commodityExpertise = const [],
  });

  bool get hasInvoiceDocument =>
      invoiceDocumentUrl != null && invoiceDocumentUrl!.trim().isNotEmpty;

  bool get hasChequeDocument =>
      chequeDocumentUrl != null && chequeDocumentUrl!.trim().isNotEmpty;

  /// IDs of approved commodities for priority matching.
  List<String> get expertiseCommodityIds =>
      commodityExpertise.where((e) => e.isApproved && e.id.isNotEmpty).map((e) => e.id).toList();

  /// Normalized names of all expertise commodities (both approved and custom).
  List<String> get expertiseCommodityNames =>
      commodityExpertise.map((e) => e.commodityName).toList();

  /// Business Identifier is strictly the Firm Name (never GSTIN).
  String get effectiveBusinessIdentifier =>
      businessIdentifier.isNotEmpty ? businessIdentifier : companyName;

  SellerProfileModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? mobile,
    String? role,
    String? companyId,
    String? companyName,
    String? businessIdentifier,
    String? versionIdentifier,
    String? companyGst,
    String? primaryMandi,
    String? state,
    String? district,
    String? businessType,
    int? trustScore,
    bool? isVerified,
    String? officeAddress,
    BusinessLocationModel? businessLocation,
    SellerBankDetails? bankDetails,
    String? invoiceDocumentUrl,
    String? invoiceDocumentName,
    String? chequeDocumentUrl,
    String? chequeDocumentName,
    List<SellerCommodityExpertise>? commodityExpertise,
  }) {
    return SellerProfileModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      role: role ?? this.role,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      businessIdentifier: businessIdentifier ?? this.businessIdentifier,
      versionIdentifier: versionIdentifier ?? this.versionIdentifier,
      companyGst: companyGst ?? this.companyGst,
      primaryMandi: primaryMandi ?? this.primaryMandi,
      state: state ?? this.state,
      district: district ?? this.district,
      businessType: businessType ?? this.businessType,
      trustScore: trustScore ?? this.trustScore,
      isVerified: isVerified ?? this.isVerified,
      officeAddress: officeAddress ?? this.officeAddress,
      businessLocation: businessLocation ?? this.businessLocation,
      bankDetails: bankDetails ?? this.bankDetails,
      invoiceDocumentUrl: invoiceDocumentUrl ?? this.invoiceDocumentUrl,
      invoiceDocumentName: invoiceDocumentName ?? this.invoiceDocumentName,
      chequeDocumentUrl: chequeDocumentUrl ?? this.chequeDocumentUrl,
      chequeDocumentName: chequeDocumentName ?? this.chequeDocumentName,
      commodityExpertise: commodityExpertise ?? this.commodityExpertise,
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

    SellerBankDetails bank;
    if (map['bank_details'] is Map<String, dynamic>) {
      bank = SellerBankDetails.fromMap(
        map['bank_details'] as Map<String, dynamic>,
      );
    } else if (map['bank_account_number'] != null || map['bank_ifsc'] != null) {
      bank = SellerBankDetails(
        accountHolderName: map['bank_holder_name']?.toString() ?? '',
        bankName: map['bank_name']?.toString() ?? '',
        accountNumber: map['bank_account_number']?.toString() ?? '',
        ifscCode: map['bank_ifsc']?.toString() ?? '',
        branchName: map['bank_branch']?.toString() ?? '',
        isVerified: map['bank_is_verified'] == true,
        verificationStatus: map['bank_verification_status']?.toString() ?? 'unverified',
      );
    } else {
      bank = const SellerBankDetails();
    }

    List<SellerCommodityExpertise> expertise = [];
    final rawExpertise = map['commodity_expertise'] ?? map['commodityExpertise'] ?? map['commodities'];
    if (rawExpertise is List) {
      for (final item in rawExpertise) {
        if (item is Map<String, dynamic>) {
          expertise.add(SellerCommodityExpertise.fromMap(item));
        } else if (item is Map) {
          expertise.add(SellerCommodityExpertise.fromMap(Map<String, dynamic>.from(item)));
        } else if (item is String && item.trim().isNotEmpty) {
          expertise.add(SellerCommodityExpertise(id: '', commodityName: item.trim()));
        }
      }
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
      businessIdentifier:
          map['business_identifier']?.toString() ??
          map['businessIdentifier']?.toString() ??
          map['company_name']?.toString() ??
          map['companyName']?.toString() ??
          '',
      versionIdentifier:
          map['version_identifier']?.toString() ??
          map['versionIdentifier']?.toString() ??
          map['invoice_document_name']?.toString() ??
          '',
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
      bankDetails: bank,
      invoiceDocumentUrl: map['invoice_document_url']?.toString(),
      invoiceDocumentName: map['invoice_document_name']?.toString(),
      chequeDocumentUrl: map['cheque_document_url']?.toString(),
      chequeDocumentName: map['cheque_document_name']?.toString(),
      commodityExpertise: expertise,
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
      'business_identifier': businessIdentifier.isNotEmpty ? businessIdentifier : companyName,
      'version_identifier': versionIdentifier,
      'company_gst': companyGst,
      'primary_mandi': primaryMandi,
      'state': state,
      'district': district,
      'business_type': businessType,
      'trust_score': trustScore,
      'is_verified': isVerified,
      'office_address': officeAddress,
      'business_location': businessLocation.toMap(),
      'bank_details': bankDetails.toMap(),
      'invoice_document_url': invoiceDocumentUrl,
      'invoice_document_name': invoiceDocumentName,
      'cheque_document_url': chequeDocumentUrl,
      'cheque_document_name': chequeDocumentName,
      'commodity_expertise': commodityExpertise.map((e) => e.toMap()).toList(),
    };
  }
}
