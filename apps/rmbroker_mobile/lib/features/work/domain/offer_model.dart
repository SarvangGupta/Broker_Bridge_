import 'package:flutter/foundation.dart';
import 'unit_utils.dart';

/// Lifecycle availability status for Seller Offers.
enum OfferStatus {
  open('Open', 'Active Supply', true),
  partiallyAvailable('Partially Available', 'Partially Available', true),
  reserved('Reserved', 'Reserved', false),
  unavailable('Unavailable', 'Unavailable', false),
  expired('Expired', 'Expired', false),
  cancelled('Cancelled', 'Cancelled', false);

  final String label;
  final String displayLabel;

  /// Whether this offer can be matched against new buyer requirements.
  final bool isEligibleForMatching;

  const OfferStatus(this.label, this.displayLabel, this.isEligibleForMatching);

  static OfferStatus fromString(String? val) {
    if (val == null) return OfferStatus.open;
    final clean = val.trim().toLowerCase();
    switch (clean) {
      case 'open':
      case 'active':
        return OfferStatus.open;
      case 'partially available':
        return OfferStatus.partiallyAvailable;
      case 'reserved':
        return OfferStatus.reserved;
      case 'unavailable':
        return OfferStatus.unavailable;
      case 'expired':
        return OfferStatus.expired;
      case 'cancelled':
        return OfferStatus.cancelled;
      default:
        return OfferStatus.open;
    }
  }
}

/// Loading readiness status for Mandi dispatch.
enum LoadingReadiness {
  notReady('Not Ready', 'Not Ready'),
  readyToLoad('Ready to Load', 'Ready to Load'),
  loadingInProgress('Loading in Progress', 'In Progress'),
  delayed('Delayed', 'Delayed'),
  blocked('Blocked', 'Blocked');

  final String label;
  final String displayLabel;

  const LoadingReadiness(this.label, this.displayLabel);

  static LoadingReadiness fromString(String? val) {
    if (val == null) return LoadingReadiness.notReady;
    final clean = val.trim().toLowerCase();
    for (final l in LoadingReadiness.values) {
      if (l.label.toLowerCase() == clean || l.displayLabel.toLowerCase() == clean) {
        return l;
      }
    }
    return LoadingReadiness.notReady;
  }
}

/// Domain model representing a verified Seller Commodity Lot Offer.
@immutable
class OfferItem {
  final String id;
  final String ref; // E.g. #OFF-9021
  final String lotNumber; // E.g. LOT-481902
  final String sellerCompanyId;
  final String sellerCompanyName;
  final bool isSellerVerified;
  final int sellerTrustScore;
  final String commodityId;
  final String commodityName;
  final String gradeId;
  final String gradeName;

  // --- SEPARATED QUANTITIES (ZERO AMBIGUOUS MIXING) ---
  final double offeredQuantity; // Total quantity originally posted
  final double availableQuantity; // Uncommitted balance available for matching
  final double reservedQuantity; // Under active proposed/confirmed allocations
  final double soldQuantity; // Finalized into executed contracts/deals

  final String unitId;
  final String unitName;
  final String unitSymbol;

  final double askingPrice; // ₹/MT
  final double? confidentialMinimumPrice; // Authorized broker confidential floor

  final String stateId;
  final String stateName;
  final String districtId;
  final String districtName;

  final DateTime availableFrom;
  final DateTime validUntil;
  final String validUntilFormatted;
  final bool isExpired;

  final LoadingReadiness loadingStatus;
  final String? loadingRemarks;

  final OfferStatus status;
  final int version;

  /// Optional lab-report reference. Never labeled as independently verified.
  final String? labReportUrl;
  final String labReportDisclaimer;

  final String? notes;
  final String? locationId;
  final String? locationSnapshot;
  final String? priceVisibility;
  final DateTime createdAt;

  /// Managing broker desk; only that broker can reserve the lot's stock.
  final String? brokerId;

  const OfferItem({
    required this.id,
    required this.ref,
    required this.lotNumber,
    required this.sellerCompanyId,
    required this.sellerCompanyName,
    required this.isSellerVerified,
    required this.sellerTrustScore,
    required this.commodityId,
    required this.commodityName,
    required this.gradeId,
    required this.gradeName,
    required this.offeredQuantity,
    required this.availableQuantity,
    this.reservedQuantity = 0.0,
    this.soldQuantity = 0.0,
    required this.unitId,
    required this.unitName,
    required this.unitSymbol,
    required this.askingPrice,
    this.confidentialMinimumPrice,
    required this.stateId,
    required this.stateName,
    required this.districtId,
    required this.districtName,
    required this.availableFrom,
    required this.validUntil,
    required this.validUntilFormatted,
    required this.isExpired,
    required this.loadingStatus,
    this.loadingRemarks,
    required this.status,
    this.version = 1,
    this.labReportUrl,
    this.labReportDisclaimer = 'Seller Declared / Pending Verification',
    this.notes,
    this.locationId,
    this.locationSnapshot,
    this.priceVisibility,
    required this.createdAt,
    this.brokerId,
  });

  /// True if offer has available volume and is not expired or cancelled.
  bool get canBeMatched => !isExpired && status.isEligibleForMatching && availableQuantity > 0;

  String get formattedOfferedQuantity => UnitUtils.format(offeredQuantity, unitSymbol);
  String get formattedAvailableQuantity => UnitUtils.format(availableQuantity, unitSymbol);
  String get formattedReservedQuantity => UnitUtils.format(reservedQuantity, unitSymbol);

  factory OfferItem.fromJson(Map<String, dynamic> json) {
    final totalQty = (json['total_quantity'] as num?)?.toDouble() ??
        (json['totalQuantity'] as num?)?.toDouble() ??
        (json['quantity'] as num?)?.toDouble() ??
        0.0;

    final availQty = (json['available_quantity'] as num?)?.toDouble() ??
        (json['availableQuantity'] as num?)?.toDouble() ??
        totalQty;

    final reservedQty = (json['reserved_quantity'] as num?)?.toDouble() ??
        (json['reservedQuantity'] as num?)?.toDouble() ??
        0.0;

    final soldQty = (json['sold_quantity'] as num?)?.toDouble() ??
        (json['soldQuantity'] as num?)?.toDouble() ??
        0.0;

    final untilRaw = json['valid_until'] ?? json['validUntil'];
    final parsedUntil = untilRaw != null
        ? DateTime.tryParse(untilRaw.toString()) ?? DateTime.now()
        : DateTime.now();

    final fromRaw = json['available_from'] ?? json['availableFrom'];
    final parsedFrom = fromRaw != null
        ? DateTime.tryParse(fromRaw.toString()) ?? DateTime.now()
        : DateTime.now();

    final now = DateTime.now();
    final isExpired = parsedUntil.isBefore(now);

    final rawStatus = json['status']?.toString();
    final derivedStatus = isExpired && (rawStatus == 'Open' || rawStatus == 'Active')
        ? OfferStatus.expired
        : OfferStatus.fromString(rawStatus);

    final id = json['id']?.toString() ?? '';
    final shortId = id.length >= 6 ? id.substring(0, 6).toUpperCase() : id;

    return OfferItem(
      id: id,
      ref: json['offer_ref']?.toString() ?? json['offerRef']?.toString() ?? '#OFF-$shortId',
      lotNumber: json['lot_number']?.toString() ??
          json['lotNumber']?.toString() ??
          'LOT-$shortId',
      sellerCompanyId: json['company_id']?.toString() ??
          json['companyId']?.toString() ??
          json['sellerCompanyId']?.toString() ??
          '',
      sellerCompanyName: json['seller_company_name']?.toString() ??
          json['sellerCompanyName']?.toString() ??
          'Verified Seller',
      isSellerVerified: json['seller_company_verified'] as bool? ??
          json['sellerCompanyVerified'] as bool? ??
          true,
      sellerTrustScore: (json['seller_trust_score'] as num?)?.toInt() ??
          (json['sellerTrustScore'] as num?)?.toInt() ??
          90,
      commodityId: json['commodity_id']?.toString() ??
          json['commodityId']?.toString() ??
          '',
      commodityName: json['commodity_name']?.toString() ??
          json['commodityName']?.toString() ??
          'Commodity Lot',
      gradeId: json['grade_id']?.toString() ?? json['gradeId']?.toString() ?? '',
      gradeName: json['grade_name']?.toString() ??
          json['gradeName']?.toString() ??
          'Standard Lot',
      offeredQuantity: totalQty,
      availableQuantity: availQty,
      reservedQuantity: reservedQty,
      soldQuantity: soldQty,
      unitId: json['unit_id']?.toString() ?? json['unitId']?.toString() ?? '',
      unitName: json['unit_name']?.toString() ?? json['unitName']?.toString() ?? 'Metric Tonne',
      unitSymbol: json['unit_symbol']?.toString() ?? json['unitSymbol']?.toString() ?? 'MT',
      askingPrice: (json['asking_price'] as num?)?.toDouble() ??
          (json['askingPrice'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble() ??
          0.0,
      confidentialMinimumPrice: (json['confidential_minimum_price'] as num?)?.toDouble() ??
          (json['confidentialMinimumPrice'] as num?)?.toDouble(),
      stateId: json['state_id']?.toString() ?? json['stateId']?.toString() ?? '',
      stateName: json['state_name']?.toString() ??
          json['stateName']?.toString() ??
          'Rajasthan',
      districtId: json['district_id']?.toString() ?? json['districtId']?.toString() ?? '',
      districtName: json['district_name']?.toString() ??
          json['districtName']?.toString() ??
          'Jaipur Mandi',
      availableFrom: parsedFrom,
      validUntil: parsedUntil,
      validUntilFormatted: json['valid_until_formatted']?.toString() ??
          json['validUntilFormatted']?.toString() ??
          '${parsedUntil.day} ${_monthName(parsedUntil.month)} ${parsedUntil.year}',
      isExpired: isExpired,
      loadingStatus: LoadingReadiness.fromString(
        json['loading_status']?.toString() ?? json['loadingStatus']?.toString(),
      ),
      loadingRemarks: json['loading_remarks']?.toString() ?? json['loadingRemarks']?.toString(),
      status: derivedStatus,
      version: (json['version'] as num?)?.toInt() ?? 1,
      labReportUrl: json['lab_report_url']?.toString() ?? json['file_url']?.toString(),
      labReportDisclaimer: 'Seller Declared / Pending Verification',
      notes: json['notes']?.toString(),
      locationId: json['loading_location_id']?.toString() ?? json['location_id']?.toString() ?? json['locationId']?.toString(),
      locationSnapshot: json['loading_location_snapshot']?.toString() ??
          json['location_snapshot']?.toString() ??
          json['locationSnapshot']?.toString() ??
          json['loading_remarks']?.toString() ??
          json['loadingRemarks']?.toString(),
      priceVisibility: json['price_visibility']?.toString() ??
          json['priceVisibility']?.toString() ??
          'Confidential',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      brokerId: json['broker_id']?.toString() ?? json['brokerId']?.toString(),
    );
  }

  static String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}

/// DTO for creating a new seller supply offer with client-side validation.
class CreateOfferDto {
  final String companyId;
  final String commodityId;
  final String gradeId;
  final double quantity;
  final String unitId;
  final double askingPrice;
  final double? confidentialMinimumPrice;
  final String stateId;
  final String districtId;
  final DateTime availableFrom;
  final DateTime validUntil;
  final LoadingReadiness loadingStatus;
  final String? loadingRemarks;
  final String? locationId;
  final String? locationSnapshot;
  final String? priceVisibility;

  const CreateOfferDto({
    required this.companyId,
    required this.commodityId,
    required this.gradeId,
    required this.quantity,
    required this.unitId,
    required this.askingPrice,
    this.confidentialMinimumPrice,
    required this.stateId,
    required this.districtId,
    required this.availableFrom,
    required this.validUntil,
    this.loadingStatus = LoadingReadiness.notReady,
    this.loadingRemarks,
    this.locationId,
    this.locationSnapshot,
    this.priceVisibility,
  });

  /// Validates input fields and returns error message or null if valid.
  String? validate() {
    if (companyId.trim().isEmpty) return 'Valid seller company is required';
    if (commodityId.trim().isEmpty) return 'Valid commodity is required';
    if (gradeId.trim().isEmpty) return 'Valid quality grade is required';
    if (quantity <= 0) return 'Offered quantity must be greater than zero';
    if (unitId.trim().isEmpty) return 'Valid measurement unit is required';
    if (askingPrice <= 0) return 'Asking price must be greater than zero';
    if (confidentialMinimumPrice != null && confidentialMinimumPrice! <= 0) {
      return 'Confidential minimum floor must be positive';
    }
    if (confidentialMinimumPrice != null && confidentialMinimumPrice! > askingPrice) {
      return 'Confidential minimum price cannot exceed asking price';
    }
    if (stateId.trim().isEmpty) return 'Valid state location is required';
    if (districtId.trim().isEmpty) return 'Valid district location is required';

    if (!validUntil.isAfter(availableFrom)) {
      return 'Validity expiration date must be after available-from date';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'companyId': companyId,
        'commodityId': commodityId,
        'gradeId': gradeId,
        'quantity': quantity,
        'unitId': unitId,
        'askingPrice': askingPrice,
        if (confidentialMinimumPrice != null)
          'confidentialMinimumPrice': confidentialMinimumPrice,
        'stateId': stateId,
        'districtId': districtId,
        'availableFrom': availableFrom.toIso8601String(),
        'validUntil': validUntil.toIso8601String(),
        'loadingStatus': loadingStatus.label,
        if (loadingRemarks != null && loadingRemarks!.trim().isNotEmpty)
          'loadingRemarks': loadingRemarks!.trim(),
        if (locationId != null) 'locationId': locationId,
        if (locationSnapshot != null) 'locationSnapshot': locationSnapshot,
        if (priceVisibility != null) 'priceVisibility': priceVisibility,
      };
}
