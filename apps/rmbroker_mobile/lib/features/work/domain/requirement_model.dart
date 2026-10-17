import 'package:flutter/foundation.dart';
import 'unit_utils.dart';

/// Authoritative status lifecycle for Buyer Requirements.
enum RequirementStatus {
  open('Open', 'Open / Sourcing', true),
  matching('Matching', 'In Matching', true),
  partiallyAllocated('Partially Allocated', 'Partially Allocated', true),
  fullyAllocated('Fully Allocated', 'Fully Allocated', false),
  fulfilled('Fulfilled', 'Fulfilled', false),
  expired('Expired', 'Expired', false),
  cancelled('Cancelled', 'Cancelled', false);

  final String label;
  final String displayLabel;

  /// Whether this requirement is eligible for active seller supply matching.
  final bool isEligibleForMatching;

  const RequirementStatus(this.label, this.displayLabel, this.isEligibleForMatching);

  static RequirementStatus fromString(String? val) {
    if (val == null) return RequirementStatus.open;
    final clean = val.trim().toLowerCase();
    switch (clean) {
      case 'new':
      case 'open':
      case 'action required':
      case 'new demand':
      case 'sourcing':
        return RequirementStatus.open;
      case 'matching':
      case 'matched':
        return RequirementStatus.matching;
      case 'partially allocated':
      case 'partially fulfilled':
        return RequirementStatus.partiallyAllocated;
      case 'fully allocated':
        return RequirementStatus.fullyAllocated;
      case 'fulfilled':
      case 'closed':
        return RequirementStatus.fulfilled;
      case 'expired':
        return RequirementStatus.expired;
      case 'cancelled':
        return RequirementStatus.cancelled;
      default:
        return RequirementStatus.open;
    }
  }
}

/// Domain model representing a Buyer Purchase Mandate on the broker desk.
@immutable
class RequirementItem {
  final String id;
  final String ref; // E.g. #REQ-8812
  final String buyerCompanyId;
  final String buyerCompanyName;
  final bool isBuyerVerified;
  final int buyerTrustScore;
  final String commodityId;
  final String commodityName;
  final String? commodityCode;
  final String? categoryName;
  final String gradeId;
  final String gradeName;
  final Map<String, dynamic>? qualityParameters;

  // --- SEPARATED QUANTITIES (ZERO AMBIGUOUS MIXING) ---
  final double requestedQuantity;
  final double allocatedQuantity;
  final double contractedQuantity;
  final double deliveredQuantity;
  final double acceptedQuantity;
  final double disputedQuantity;
  final double remainingQuantity;

  final String unitId;
  final String unitName;
  final String unitSymbol;

  final double targetPrice; // In INR per unit (e.g. ₹/MT)
  final String deliveryTerms; // E.g. FOR Destination (Karnal), Ex-Warehouse Jaipur
  final DateTime targetDate;
  final String targetDateFormatted;
  final bool isUrgent;
  final int hoursUntilTarget;
  final bool isExpired;
  final RequirementStatus status;
  final String? notes;
  final DateTime createdAt;

  const RequirementItem({
    required this.id,
    required this.ref,
    required this.buyerCompanyId,
    required this.buyerCompanyName,
    required this.isBuyerVerified,
    required this.buyerTrustScore,
    required this.commodityId,
    required this.commodityName,
    this.commodityCode,
    this.categoryName,
    required this.gradeId,
    required this.gradeName,
    this.qualityParameters,
    required this.requestedQuantity,
    required this.allocatedQuantity,
    this.contractedQuantity = 0.0,
    this.deliveredQuantity = 0.0,
    this.acceptedQuantity = 0.0,
    this.disputedQuantity = 0.0,
    required this.remainingQuantity,
    required this.unitId,
    required this.unitName,
    required this.unitSymbol,
    required this.targetPrice,
    required this.deliveryTerms,
    required this.targetDate,
    required this.targetDateFormatted,
    required this.isUrgent,
    required this.hoursUntilTarget,
    required this.isExpired,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  /// Calculate percentage of requested quantity allocated/fulfilled (0-100%).
  int get fulfillmentPercentage {
    if (requestedQuantity <= 0) return 0;
    final pct = (allocatedQuantity / requestedQuantity) * 100;
    return pct.clamp(0, 100).round();
  }

  /// Whether this requirement can be fed to the matching engine.
  bool get canBeMatched => !isExpired && status.isEligibleForMatching && remainingQuantity > 0;

  /// Quantity formatted cleanly with explicit unit symbol.
  String get formattedRequestedQuantity =>
      UnitUtils.format(requestedQuantity, unitSymbol);

  String get formattedAllocatedQuantity =>
      UnitUtils.format(allocatedQuantity, unitSymbol);

  String get formattedRemainingQuantity =>
      UnitUtils.format(remainingQuantity, unitSymbol);

  factory RequirementItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] as num?)?.toDouble() ?? 0.0;
    final fulfilled = (json['fulfilled_quantity'] as num?)?.toDouble() ??
        (json['fulfilledQuantity'] as num?)?.toDouble() ??
        0.0;
    final contracted = (json['contracted_quantity'] as num?)?.toDouble() ??
        (json['contractedQuantity'] as num?)?.toDouble() ??
        0.0;
    final delivered = (json['delivered_quantity'] as num?)?.toDouble() ??
        (json['deliveredQuantity'] as num?)?.toDouble() ??
        0.0;
    final accepted = (json['accepted_quantity'] as num?)?.toDouble() ??
        (json['acceptedQuantity'] as num?)?.toDouble() ??
        0.0;
    final disputed = (json['disputed_quantity'] as num?)?.toDouble() ??
        (json['disputedQuantity'] as num?)?.toDouble() ??
        0.0;

    final remaining = (json['remaining_quantity'] as num?)?.toDouble() ??
        (json['remainingQuantity'] as num?)?.toDouble() ??
        (qty - fulfilled).clamp(0.0, double.infinity);

    final rawTargetDate = json['target_date'] ?? json['targetDate'];
    final parsedTargetDate = rawTargetDate != null
        ? DateTime.tryParse(rawTargetDate.toString()) ?? DateTime.now()
        : DateTime.now();

    final now = DateTime.now();
    final hoursDiff = parsedTargetDate.difference(now).inHours;
    final isExpired = parsedTargetDate.isBefore(now);
    final isUrgent = hoursDiff <= 48 && hoursDiff > 0;

    final rawStatus = json['status']?.toString();
    final derivedStatus = isExpired && (rawStatus == 'Open' || rawStatus == 'New')
        ? RequirementStatus.expired
        : RequirementStatus.fromString(rawStatus);

    final id = json['id']?.toString() ?? '';
    final shortId = id.length >= 6 ? id.substring(0, 6).toUpperCase() : id;

    return RequirementItem(
      id: id,
      ref: json['requirement_ref']?.toString() ??
          json['requirementRef']?.toString() ??
          '#REQ-$shortId',
      buyerCompanyId: json['company_id']?.toString() ??
          json['companyId']?.toString() ??
          json['buyerCompanyId']?.toString() ??
          '',
      buyerCompanyName: json['buyer_company_name']?.toString() ??
          json['buyerCompanyName']?.toString() ??
          'Verified Buyer',
      isBuyerVerified: json['buyer_company_verified'] as bool? ??
          json['buyerCompanyVerified'] as bool? ??
          true,
      buyerTrustScore: (json['buyer_trust_score'] as num?)?.toInt() ??
          (json['buyerTrustScore'] as num?)?.toInt() ??
          90,
      commodityId: json['commodity_id']?.toString() ??
          json['commodityId']?.toString() ??
          '',
      commodityName: json['commodity_name']?.toString() ??
          json['commodityName']?.toString() ??
          'Agricultural Commodity',
      commodityCode: json['commodity_code']?.toString() ?? json['commodityCode']?.toString(),
      categoryName: json['category_name']?.toString() ?? json['categoryName']?.toString(),
      gradeId: json['grade_id']?.toString() ?? json['gradeId']?.toString() ?? '',
      gradeName: json['grade_name']?.toString() ??
          json['gradeName']?.toString() ??
          'Standard Grade',
      qualityParameters: json['quality_parameters'] as Map<String, dynamic>? ??
          json['qualityParameters'] as Map<String, dynamic>?,
      requestedQuantity: qty,
      allocatedQuantity: fulfilled,
      contractedQuantity: contracted,
      deliveredQuantity: delivered,
      acceptedQuantity: accepted,
      disputedQuantity: disputed,
      remainingQuantity: remaining,
      unitId: json['unit_id']?.toString() ?? json['unitId']?.toString() ?? '',
      unitName: json['unit_name']?.toString() ?? json['unitName']?.toString() ?? 'Metric Tonne',
      unitSymbol: json['unit_symbol']?.toString() ?? json['unitSymbol']?.toString() ?? 'MT',
      targetPrice: (json['target_price'] as num?)?.toDouble() ??
          (json['targetPrice'] as num?)?.toDouble() ??
          0.0,
      deliveryTerms: json['delivery_terms_id']?.toString() ??
          json['delivery_terms']?.toString() ??
          json['deliveryTerms']?.toString() ??
          'FOR Destination',
      targetDate: parsedTargetDate,
      targetDateFormatted: json['target_date_formatted']?.toString() ??
          json['targetDateFormatted']?.toString() ??
          '${parsedTargetDate.day} ${_monthName(parsedTargetDate.month)} ${parsedTargetDate.year}',
      isUrgent: isUrgent,
      hoursUntilTarget: hoursDiff,
      isExpired: isExpired,
      status: derivedStatus,
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
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

/// DTO for creating a new buyer requirement mandate with client-side validation.
class CreateRequirementDto {
  final String companyId;
  final String commodityId;
  final String gradeId;
  final double quantity;
  final String unitId;
  final double targetPrice;
  final String deliveryTerms;
  final DateTime targetDate;
  final String? notes;

  const CreateRequirementDto({
    required this.companyId,
    required this.commodityId,
    required this.gradeId,
    required this.quantity,
    required this.unitId,
    required this.targetPrice,
    required this.deliveryTerms,
    required this.targetDate,
    this.notes,
  });

  /// Validates input fields and returns error message or null if valid.
  String? validate() {
    if (companyId.trim().isEmpty) return 'Valid buyer company is required';
    if (commodityId.trim().isEmpty) return 'Valid commodity is required';
    if (gradeId.trim().isEmpty) return 'Valid quality grade is required';
    if (quantity <= 0) return 'Quantity must be greater than zero';
    if (unitId.trim().isEmpty) return 'Valid measurement unit is required';
    if (targetPrice <= 0) return 'Target price must be greater than zero';
    if (deliveryTerms.trim().isEmpty) return 'Delivery terms are required';

    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    if (targetDate.isBefore(startOfToday)) {
      return 'Required delivery date must be today or in the future';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'companyId': companyId,
        'commodityId': commodityId,
        'gradeId': gradeId,
        'quantity': quantity,
        'unitId': unitId,
        'targetPrice': targetPrice,
        'deliveryTermsId': deliveryTerms,
        'targetDate': targetDate.toIso8601String(),
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      };
}
