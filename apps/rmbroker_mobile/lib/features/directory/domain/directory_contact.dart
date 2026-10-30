import 'package:flutter/foundation.dart';
import '../utils/phone_utils.dart';
import 'cheque_leaf_data.dart';
import 'gst_certificate_data.dart';

/// Role of the directory counterparty in commodity trade.
enum ContactRole {
  buyer('Buyer', 'buyer'),
  seller('Seller', 'seller');

  final String label;
  final String apiValue;

  const ContactRole(this.label, this.apiValue);

  static ContactRole fromString(String? val) {
    if (val == null) return ContactRole.buyer;
    final lower = val.toLowerCase().trim();
    if (lower == 'seller') return ContactRole.seller;
    return ContactRole.buyer;
  }
}

/// Authorized counterparty contact item in the broker's directory.
@immutable
class DirectoryContact {
  final String id; // crm_contacts.id
  final String userId;
  final String companyId;
  final String name;
  final String companyName;
  final String mobile;
  final String? whatsapp;
  final String? email;
  final ContactRole role;
  final bool status; // true = Active, false = Inactive / Archived
  final bool isVerified;
  final int trustScore;

  /// Stored values (`companies.district_id` / `state_id`): a master-table UUID
  /// or legacy free text. Kept unchanged so edits never overwrite them.
  final String? city;
  final String? state;

  /// Master names resolved for [city] / [state] when they are UUIDs.
  final String? cityName;
  final String? stateName;
  final DateTime createdAt;
  final int openRequirementsCount;
  final int availableOffersCount;
  final int activeDealsCount;

  // --- GST Verification Fields ---
  final String? gstin;
  final String? legalName;
  final String? tradeName;
  final String? constitution;
  final String? address;
  final String gstVerificationStatus; // 'unverified', 'gst_pending', 'broker_verified', 'gst_verified', 'rejected'
  final String? gstCertificateUrl;
  final String? gstVerifiedBy;
  final DateTime? gstVerifiedAt;

  // --- Bank Details Fields ---
  final String? bankHolderName;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? bankBranch;
  final String? bankChequeUrl;
  final String bankVerificationStatus; // 'unverified', 'cheque_leaf_provided', 'verified'
  final String? bankRecordedBy;
  final DateTime? bankRecordedAt;

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool isUuid(String? v) => v != null && _uuid.hasMatch(v.trim());

  /// Display text for a stored location value: the resolved name, else the
  /// stored text, but never a raw UUID.
  static String? _label(String? stored, String? resolved) {
    if (resolved != null && resolved.trim().isNotEmpty) return resolved.trim();
    if (stored == null || stored.trim().isEmpty || isUuid(stored)) return null;
    return stored.trim();
  }

  String? get cityLabel => _label(city, cityName);
  String? get stateLabel => _label(state, stateName);

  const DirectoryContact({
    required this.id,
    required this.userId,
    required this.companyId,
    required this.name,
    required this.companyName,
    required this.mobile,
    this.whatsapp,
    this.email,
    required this.role,
    this.status = true,
    this.isVerified = false,
    this.trustScore = 100,
    this.city,
    this.state,
    this.cityName,
    this.stateName,
    required this.createdAt,
    this.openRequirementsCount = 0,
    this.availableOffersCount = 0,
    this.activeDealsCount = 0,
    this.gstin,
    this.legalName,
    this.tradeName,
    this.constitution,
    this.address,
    this.gstVerificationStatus = CounterpartyGstStatus.unverified,
    this.gstCertificateUrl,
    this.gstVerifiedBy,
    this.gstVerifiedAt,
    this.bankHolderName,
    this.bankName,
    this.bankAccountNumber,
    this.bankIfsc,
    this.bankBranch,
    this.bankChequeUrl,
    this.bankVerificationStatus = CounterpartyBankStatus.unverified,
    this.bankRecordedBy,
    this.bankRecordedAt,
  });

  String get formattedMobile {
    final parsed = PhoneUtils.validateAndNormalize(mobile);
    return parsed.isValid ? parsed.formatted : mobile;
  }

  bool get hasLocation => cityLabel != null || stateLabel != null;

  String get locationLabel {
    final c = cityLabel;
    final s = stateLabel;
    if (c != null && s != null) return '$c, $s';
    return c ?? s ?? 'Location not specified';
  }

  int get totalMandatesCount =>
      openRequirementsCount + availableOffersCount + activeDealsCount;

  bool get isBrokerVerified =>
      gstVerificationStatus == CounterpartyGstStatus.brokerVerified;
  bool get isGstPending =>
      gstVerificationStatus == CounterpartyGstStatus.gstPending;
  bool get isGstVerified =>
      gstVerificationStatus == CounterpartyGstStatus.gstVerified;
  String get gstStatusLabel =>
      CounterpartyGstStatus.displayLabel(gstVerificationStatus);
  String get bankStatusLabel =>
      CounterpartyBankStatus.displayLabel(bankVerificationStatus);
  bool get hasChequeLeaf =>
      bankChequeUrl != null && bankChequeUrl!.trim().isNotEmpty;
  bool get hasBankDetails =>
      bankAccountNumber != null && bankAccountNumber!.trim().isNotEmpty;

  /// Masked bank account number, protecting sensitive financial data
  String get maskedBankAccount {
    final num = bankAccountNumber?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (num.length < 4) return '••••';
    final last4 = num.substring(num.length - 4);
    return '•••• •••• $last4';
  }

  /// The directory's role tab / status / search rules. Shared by the screen
  /// and the paged repository scan so both always agree on what matches.
  bool matchesFilters({String? role, String? status, String? search}) {
    if (role == 'buyer' && this.role != ContactRole.buyer) return false;
    if (role == 'seller' && this.role != ContactRole.seller) return false;
    if (status == 'active' && !this.status) return false;
    if (status == 'inactive' && this.status) return false;

    final q = search?.toLowerCase().trim() ?? '';
    if (q.isEmpty) return true;
    final digits = q.replaceAll(RegExp(r'\D'), '');

    return name.toLowerCase().contains(q) ||
        companyName.toLowerCase().contains(q) ||
        (legalName?.toLowerCase().contains(q) ?? false) ||
        (tradeName?.toLowerCase().contains(q) ?? false) ||
        (gstin?.toLowerCase().contains(q) ?? false) ||
        (email?.toLowerCase().contains(q) ?? false) ||
        (cityLabel?.toLowerCase().contains(q) ?? false) ||
        (stateLabel?.toLowerCase().contains(q) ?? false) ||
        (digits.length >= 3 &&
            mobile.replaceAll(RegExp(r'\D'), '').contains(digits));
  }

  factory DirectoryContact.fromJson(Map<String, dynamic> json) {
    return DirectoryContact(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      companyId: json['companyId']?.toString() ?? json['company_id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['userName']?.toString() ?? 'Unnamed Contact',
      companyName: json['companyName']?.toString() ?? json['company_name']?.toString() ?? 'Individual Counterparty',
      mobile: json['mobile']?.toString() ?? json['userMobile']?.toString() ?? '',
      whatsapp: json['whatsapp']?.toString(),
      email: json['email']?.toString() ?? json['userEmail']?.toString(),
      role: ContactRole.fromString(json['role']?.toString() ?? json['userRole']?.toString()),
      status: json['status'] as bool? ?? json['userStatus'] as bool? ?? true,
      isVerified: json['isVerified'] as bool? ?? json['is_verified'] as bool? ?? false,
      trustScore: (json['trustScore'] as num? ?? json['trust_score'] as num? ?? 100).toInt(),
      city: json['city']?.toString() ?? json['districtId']?.toString() ?? json['district_id']?.toString(),
      state: json['state']?.toString() ?? json['stateId']?.toString() ?? json['state_id']?.toString(),
      cityName: json['cityName']?.toString(),
      stateName: json['stateName']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
      openRequirementsCount: (json['openRequirementsCount'] as num? ?? json['open_requirements_count'] as num? ?? 0).toInt(),
      availableOffersCount: (json['availableOffersCount'] as num? ?? json['available_offers_count'] as num? ?? 0).toInt(),
      activeDealsCount: (json['activeDealsCount'] as num? ?? json['active_deals_count'] as num? ?? 0).toInt(),
      gstin: json['gstin']?.toString() ?? json['gst']?.toString(),
      legalName: json['legalName']?.toString() ?? json['legal_name']?.toString(),
      tradeName: json['tradeName']?.toString() ?? json['trade_name']?.toString(),
      constitution: json['constitution']?.toString(),
      address: json['address']?.toString() ?? json['principal_address']?.toString(),
      gstVerificationStatus: json['gstVerificationStatus']?.toString() ??
          json['gst_verification_status']?.toString() ??
          CounterpartyGstStatus.unverified,
      gstCertificateUrl: json['gstCertificateUrl']?.toString() ?? json['gst_certificate_url']?.toString(),
      gstVerifiedBy: json['gstVerifiedBy']?.toString() ?? json['gst_verified_by']?.toString(),
      gstVerifiedAt: json['gstVerifiedAt'] != null
          ? DateTime.tryParse(json['gstVerifiedAt'].toString())
          : (json['gst_verified_at'] != null ? DateTime.tryParse(json['gst_verified_at'].toString()) : null),
      bankHolderName: json['bankHolderName']?.toString() ?? json['bank_holder_name']?.toString(),
      bankName: json['bankName']?.toString() ?? json['bank_name']?.toString(),
      bankAccountNumber: json['bankAccountNumber']?.toString() ?? json['bank_account_number']?.toString(),
      bankIfsc: json['bankIfsc']?.toString() ?? json['bank_ifsc']?.toString(),
      bankBranch: json['bankBranch']?.toString() ?? json['bank_branch']?.toString(),
      bankChequeUrl: json['bankChequeUrl']?.toString() ?? json['bank_cheque_url']?.toString(),
      bankVerificationStatus: json['bankVerificationStatus']?.toString() ??
          json['bank_verification_status']?.toString() ??
          CounterpartyBankStatus.unverified,
      bankRecordedBy: json['bankRecordedBy']?.toString() ?? json['bank_recorded_by']?.toString(),
      bankRecordedAt: json['bankRecordedAt'] != null
          ? DateTime.tryParse(json['bankRecordedAt'].toString())
          : (json['bank_recorded_at'] != null ? DateTime.tryParse(json['bank_recorded_at'].toString()) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'companyId': companyId,
      'name': name,
      'companyName': companyName,
      'mobile': mobile,
      'whatsapp': whatsapp,
      'email': email,
      'role': role.apiValue,
      'status': status,
      'isVerified': isVerified,
      'trustScore': trustScore,
      'city': city,
      'state': state,
      'createdAt': createdAt.toIso8601String(),
      'openRequirementsCount': openRequirementsCount,
      'availableOffersCount': availableOffersCount,
      'activeDealsCount': activeDealsCount,
      'gstin': gstin,
      'legalName': legalName,
      'tradeName': tradeName,
      'constitution': constitution,
      'address': address,
      'gstVerificationStatus': gstVerificationStatus,
      'gstCertificateUrl': gstCertificateUrl,
      'bankHolderName': bankHolderName,
      'bankName': bankName,
      'bankAccountNumber': bankAccountNumber,
      'bankIfsc': bankIfsc,
      'bankBranch': bankBranch,
      'bankChequeUrl': bankChequeUrl,
      'bankVerificationStatus': bankVerificationStatus,
    };
  }

  DirectoryContact copyWith({
    String? id,
    String? userId,
    String? companyId,
    String? name,
    String? companyName,
    String? mobile,
    String? whatsapp,
    String? email,
    ContactRole? role,
    bool? status,
    bool? isVerified,
    int? trustScore,
    String? city,
    String? state,
    String? cityName,
    String? stateName,
    DateTime? createdAt,
    int? openRequirementsCount,
    int? availableOffersCount,
    int? activeDealsCount,
    String? gstin,
    String? legalName,
    String? tradeName,
    String? constitution,
    String? address,
    String? gstVerificationStatus,
    String? gstCertificateUrl,
    String? gstVerifiedBy,
    DateTime? gstVerifiedAt,
    String? bankHolderName,
    String? bankName,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankBranch,
    String? bankChequeUrl,
    String? bankVerificationStatus,
    String? bankRecordedBy,
    DateTime? bankRecordedAt,
  }) {
    return DirectoryContact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      mobile: mobile ?? this.mobile,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      isVerified: isVerified ?? this.isVerified,
      trustScore: trustScore ?? this.trustScore,
      city: city ?? this.city,
      state: state ?? this.state,
      cityName: cityName ?? this.cityName,
      stateName: stateName ?? this.stateName,
      createdAt: createdAt ?? this.createdAt,
      openRequirementsCount: openRequirementsCount ?? this.openRequirementsCount,
      availableOffersCount: availableOffersCount ?? this.availableOffersCount,
      activeDealsCount: activeDealsCount ?? this.activeDealsCount,
      gstin: gstin ?? this.gstin,
      legalName: legalName ?? this.legalName,
      tradeName: tradeName ?? this.tradeName,
      constitution: constitution ?? this.constitution,
      address: address ?? this.address,
      gstVerificationStatus: gstVerificationStatus ?? this.gstVerificationStatus,
      gstCertificateUrl: gstCertificateUrl ?? this.gstCertificateUrl,
      gstVerifiedBy: gstVerifiedBy ?? this.gstVerifiedBy,
      gstVerifiedAt: gstVerifiedAt ?? this.gstVerifiedAt,
      bankHolderName: bankHolderName ?? this.bankHolderName,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfsc: bankIfsc ?? this.bankIfsc,
      bankBranch: bankBranch ?? this.bankBranch,
      bankChequeUrl: bankChequeUrl ?? this.bankChequeUrl,
      bankVerificationStatus: bankVerificationStatus ?? this.bankVerificationStatus,
      bankRecordedBy: bankRecordedBy ?? this.bankRecordedBy,
      bankRecordedAt: bankRecordedAt ?? this.bankRecordedAt,
    );
  }
}

/// Summary metrics calculated across the broker's authorized counterparty pool.
@immutable
class DirectorySummaryStats {
  final int totalContacts;
  final int buyersCount;
  final int sellersCount;
  final int activeMandatesCount;

  const DirectorySummaryStats({
    this.totalContacts = 0,
    this.buyersCount = 0,
    this.sellersCount = 0,
    this.activeMandatesCount = 0,
  });

  factory DirectorySummaryStats.fromJson(Map<String, dynamic> json) {
    return DirectorySummaryStats(
      totalContacts: (json['totalContacts'] as num? ?? json['total_contacts'] as num? ?? 0).toInt(),
      buyersCount: (json['buyersCount'] as num? ?? json['buyers_count'] as num? ?? 0).toInt(),
      sellersCount: (json['sellersCount'] as num? ?? json['sellers_count'] as num? ?? 0).toInt(),
      activeMandatesCount: (json['activeMandatesCount'] as num? ?? json['active_mandates_count'] as num? ?? 0).toInt(),
    );
  }

  factory DirectorySummaryStats.fromContacts(List<DirectoryContact> contacts) {
    final active = contacts.where((c) => c.status).toList();
    final buyers = active.where((c) => c.role == ContactRole.buyer).length;
    final sellers = active.where((c) => c.role == ContactRole.seller).length;
    final mandates = contacts.fold<int>(0, (sum, c) => sum + c.totalMandatesCount);

    return DirectorySummaryStats(
      totalContacts: contacts.length,
      buyersCount: buyers,
      sellersCount: sellers,
      activeMandatesCount: mandates,
    );
  }
}

/// Input payload for creating a new contact.
@immutable
class CreateContactInput {
  final String name;
  final String companyName;
  final String mobile;
  final String? whatsapp;
  final String? email;
  final ContactRole role;
  final String? city;
  final String? state;
  final String? notes;

  // --- GST Verification Fields ---
  final String? gstin;
  final String? legalName;
  final String? tradeName;
  final String? constitution;
  final String? address;
  final String? gstRegistrationDate;
  final String gstVerificationStatus; // 'broker_verified' | 'gst_pending' | 'unverified'
  final String? gstCertificateUrl;
  final bool isBrokerVerified;

  // --- Bank Details Fields ---
  final String? bankHolderName;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? bankBranch;
  final String? bankChequeUrl;
  final String bankVerificationStatus; // 'cheque_leaf_provided' | 'unverified'
  final bool hasChequeLeaf;

  const CreateContactInput({
    required this.name,
    required this.companyName,
    required this.mobile,
    this.whatsapp,
    this.email,
    required this.role,
    this.city,
    this.state,
    this.notes,
    this.gstin,
    this.legalName,
    this.tradeName,
    this.constitution,
    this.address,
    this.gstRegistrationDate,
    this.gstVerificationStatus = CounterpartyGstStatus.unverified,
    this.gstCertificateUrl,
    this.isBrokerVerified = false,
    this.bankHolderName,
    this.bankName,
    this.bankAccountNumber,
    this.bankIfsc,
    this.bankBranch,
    this.bankChequeUrl,
    this.bankVerificationStatus = CounterpartyBankStatus.unverified,
    this.hasChequeLeaf = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'companyName': companyName.trim(),
      'mobile': mobile.trim(),
      if (whatsapp != null && whatsapp!.trim().isNotEmpty) 'whatsapp': whatsapp!.trim(),
      if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
      'role': role.apiValue,
      if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
      if (state != null && state!.trim().isNotEmpty) 'state': state!.trim(),
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      if (gstin != null && gstin!.trim().isNotEmpty) 'gstin': gstin!.trim(),
      if (legalName != null && legalName!.trim().isNotEmpty) 'legalName': legalName!.trim(),
      if (tradeName != null && tradeName!.trim().isNotEmpty) 'tradeName': tradeName!.trim(),
      if (constitution != null && constitution!.trim().isNotEmpty) 'constitution': constitution!.trim(),
      if (address != null && address!.trim().isNotEmpty) 'address': address!.trim(),
      if (gstRegistrationDate != null) 'registration_date': gstRegistrationDate,
      'gst_verification_status': gstVerificationStatus,
      if (gstCertificateUrl != null) 'gst_certificate_url': gstCertificateUrl,
      if (bankHolderName != null && bankHolderName!.trim().isNotEmpty) 'bank_holder_name': bankHolderName!.trim(),
      if (bankName != null && bankName!.trim().isNotEmpty) 'bank_name': bankName!.trim(),
      if (bankAccountNumber != null && bankAccountNumber!.trim().isNotEmpty) 'bank_account_number': bankAccountNumber!.trim(),
      if (bankIfsc != null && bankIfsc!.trim().isNotEmpty) 'bank_ifsc': bankIfsc!.trim(),
      if (bankBranch != null && bankBranch!.trim().isNotEmpty) 'bank_branch': bankBranch!.trim(),
      if (bankChequeUrl != null) 'bank_cheque_url': bankChequeUrl,
      'bank_verification_status': bankVerificationStatus,
    };
  }
}

/// Input payload for updating an authorized contact.
@immutable
class UpdateContactInput {
  final String name;
  final String companyName;
  final String mobile;
  final String? whatsapp;
  final String? email;
  final ContactRole role;
  final String? city;
  final String? state;
  final String? notes;
  final bool? status;

  // --- GST and Bank fields ---
  final String? gstin;
  final String? legalName;
  final String? tradeName;
  final String? constitution;
  final String? address;
  final String? gstVerificationStatus;
  final String? gstCertificateUrl;
  final String? bankHolderName;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? bankBranch;
  final String? bankChequeUrl;
  final String? bankVerificationStatus;

  const UpdateContactInput({
    required this.name,
    required this.companyName,
    required this.mobile,
    this.whatsapp,
    this.email,
    required this.role,
    this.city,
    this.state,
    this.notes,
    this.status,
    this.gstin,
    this.legalName,
    this.tradeName,
    this.constitution,
    this.address,
    this.gstVerificationStatus,
    this.gstCertificateUrl,
    this.bankHolderName,
    this.bankName,
    this.bankAccountNumber,
    this.bankIfsc,
    this.bankBranch,
    this.bankChequeUrl,
    this.bankVerificationStatus,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'companyName': companyName.trim(),
      'mobile': mobile.trim(),
      if (whatsapp != null && whatsapp!.trim().isNotEmpty) 'whatsapp': whatsapp!.trim(),
      if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
      'role': role.apiValue,
      if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
      if (state != null && state!.trim().isNotEmpty) 'state': state!.trim(),
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      if (status != null) 'status': status,
      if (gstin != null && gstin!.trim().isNotEmpty) 'gstin': gstin!.trim(),
      if (legalName != null) 'legalName': legalName!.trim(),
      if (tradeName != null) 'tradeName': tradeName!.trim(),
      if (constitution != null) 'constitution': constitution!.trim(),
      if (address != null) 'address': address!.trim(),
      if (gstVerificationStatus != null) 'gst_verification_status': gstVerificationStatus,
      if (gstCertificateUrl != null) 'gst_certificate_url': gstCertificateUrl,
      if (bankHolderName != null) 'bank_holder_name': bankHolderName!.trim(),
      if (bankName != null) 'bank_name': bankName!.trim(),
      if (bankAccountNumber != null) 'bank_account_number': bankAccountNumber!.trim(),
      if (bankIfsc != null) 'bank_ifsc': bankIfsc!.trim(),
      if (bankBranch != null) 'bank_branch': bankBranch!.trim(),
      if (bankChequeUrl != null) 'bank_cheque_url': bankChequeUrl,
      if (bankVerificationStatus != null) 'bank_verification_status': bankVerificationStatus,
    };
  }
}

/// Result of duplicate collision check.
@immutable
class DuplicateCheckResult {
  final bool isDuplicate;
  final String? matchType; // 'exact_mobile' | 'company_name' | 'gstin'
  final String? existingContactName;
  final String? existingCompanyName;
  final String? existingMobile;
  final String? existingGstin;
  final String? existingRole;

  const DuplicateCheckResult({
    required this.isDuplicate,
    this.matchType,
    this.existingContactName,
    this.existingCompanyName,
    this.existingMobile,
    this.existingGstin,
    this.existingRole,
  });

  factory DuplicateCheckResult.none() => const DuplicateCheckResult(isDuplicate: false);

  factory DuplicateCheckResult.fromJson(Map<String, dynamic> json) {
    final existing = json['existingContact'] as Map<String, dynamic>?;
    return DuplicateCheckResult(
      isDuplicate: json['isDuplicate'] as bool? ?? false,
      matchType: json['matchType']?.toString(),
      existingContactName: existing?['name']?.toString(),
      existingCompanyName: existing?['companyName']?.toString(),
      existingMobile: existing?['mobile']?.toString(),
      existingGstin: existing?['gstin']?.toString() ?? existing?['gst']?.toString(),
      existingRole: existing?['role']?.toString(),
    );
  }
}

/// Linked buyer trade requirement for 360-degree contact view.
@immutable
class LinkedRequirement {
  final String id;
  final String commodityName;
  final double quantity;
  final double targetPrice;
  final String status;
  final String targetDate;

  const LinkedRequirement({
    required this.id,
    required this.commodityName,
    required this.quantity,
    required this.targetPrice,
    required this.status,
    required this.targetDate,
  });

  factory LinkedRequirement.fromJson(Map<String, dynamic> json) {
    return LinkedRequirement(
      id: json['id']?.toString() ?? '',
      commodityName: json['commodityName']?.toString() ?? 'Commodity',
      quantity: (json['quantity'] as num? ?? 0).toDouble(),
      targetPrice: (json['targetPrice'] as num? ?? json['target_price'] as num? ?? 0).toDouble(),
      status: json['status']?.toString() ?? 'Open',
      targetDate: json['targetDate']?.toString() ?? '',
    );
  }
}

/// Linked seller offer lot for 360-degree contact view.
@immutable
class LinkedOffer {
  final String id;
  final String commodityName;
  final double quantity;
  final String price;
  final String status;

  const LinkedOffer({
    required this.id,
    required this.commodityName,
    required this.quantity,
    required this.price,
    required this.status,
  });

  factory LinkedOffer.fromJson(Map<String, dynamic> json) {
    return LinkedOffer(
      id: json['id']?.toString() ?? '',
      commodityName: json['commodityName']?.toString() ?? 'Commodity',
      quantity: (json['quantity'] as num? ?? 0).toDouble(),
      price: json['price']?.toString() ?? '₹0',
      status: json['status']?.toString() ?? 'Open',
    );
  }
}

/// Linked commodity trade deal for 360-degree contact view.
@immutable
class LinkedDeal {
  final String id;
  final String commodityName;
  final double agreedQuantity;
  final String agreedPrice;
  final String status;
  final String createdAt;

  const LinkedDeal({
    required this.id,
    required this.commodityName,
    required this.agreedQuantity,
    required this.agreedPrice,
    required this.status,
    required this.createdAt,
  });

  factory LinkedDeal.fromJson(Map<String, dynamic> json) {
    return LinkedDeal(
      id: json['id']?.toString() ?? '',
      commodityName: json['commodityName']?.toString() ?? 'Commodity',
      agreedQuantity: (json['agreedQuantity'] as num? ?? 0).toDouble(),
      agreedPrice: json['agreedPrice']?.toString() ?? '₹0',
      status: json['status']?.toString() ?? 'Pending',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

/// CRM interaction activity record.
@immutable
class ContactActivity {
  final String id;
  final String type;
  final String notes;
  final String createdAt;

  const ContactActivity({
    required this.id,
    required this.type,
    required this.notes,
    required this.createdAt,
  });

  factory ContactActivity.fromJson(Map<String, dynamic> json) {
    return ContactActivity(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Note',
      notes: json['notes']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

/// Comprehensive 360-degree contact details payload.
@immutable
class ContactDetailsPayload {
  final DirectoryContact contact;
  final List<LinkedRequirement> associatedRequirements;
  final List<LinkedOffer> associatedOffers;
  final List<LinkedDeal> linkedDeals;
  final List<ContactActivity> activities;

  const ContactDetailsPayload({
    required this.contact,
    this.associatedRequirements = const [],
    this.associatedOffers = const [],
    this.linkedDeals = const [],
    this.activities = const [],
  });

  factory ContactDetailsPayload.fromJson(Map<String, dynamic> json) {
    final contactMap = json['contact'] as Map<String, dynamic>? ?? {};
    final reqsRaw = json['associatedRequirements'] as List<dynamic>? ?? [];
    final offersRaw = json['associatedOffers'] as List<dynamic>? ?? [];
    final dealsRaw = json['linkedDeals'] as List<dynamic>? ?? [];
    final actsRaw = json['activities'] as List<dynamic>? ?? [];

    return ContactDetailsPayload(
      contact: DirectoryContact.fromJson(contactMap),
      associatedRequirements: reqsRaw
          .whereType<Map<String, dynamic>>()
          .map(LinkedRequirement.fromJson)
          .toList(),
      associatedOffers: offersRaw
          .whereType<Map<String, dynamic>>()
          .map(LinkedOffer.fromJson)
          .toList(),
      linkedDeals: dealsRaw
          .whereType<Map<String, dynamic>>()
          .map(LinkedDeal.fromJson)
          .toList(),
      activities: actsRaw
          .whereType<Map<String, dynamic>>()
          .map(ContactActivity.fromJson)
          .toList(),
    );
  }
}
