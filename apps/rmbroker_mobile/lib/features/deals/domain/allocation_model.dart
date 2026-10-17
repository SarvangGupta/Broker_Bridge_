import 'package:flutter/foundation.dart';
import '../../work/domain/unit_utils.dart';

/// Status lifecycle for Requirement-to-Offer Allocations.
enum AllocationStatus {
  proposed('PROPOSED', 'Proposed', true),
  confirmed('CONFIRMED', 'Confirmed', true),
  committedToDeal('COMMITTED_TO_DEAL', 'Committed to Deal', false),
  released('RELEASED', 'Released', false),
  cancelled('CANCELLED', 'Cancelled', false);

  final String code;
  final String displayLabel;
  final bool isPendingAction;

  const AllocationStatus(this.code, this.displayLabel, this.isPendingAction);

  static AllocationStatus fromString(String? val) {
    if (val == null) return AllocationStatus.proposed;
    final clean = val.trim().toUpperCase();
    switch (clean) {
      case 'PROPOSED':
        return AllocationStatus.proposed;
      case 'CONFIRMED':
        return AllocationStatus.confirmed;
      case 'COMMITTED_TO_DEAL':
      case 'COMMITTED':
        return AllocationStatus.committedToDeal;
      case 'RELEASED':
        return AllocationStatus.released;
      case 'CANCELLED':
        return AllocationStatus.cancelled;
      default:
        return AllocationStatus.proposed;
    }
  }
}

/// Authoritative Allocation Record linking Requirement and Offer.
@immutable
class AllocationItem {
  final String id;
  final String reference;
  final String requirementId;
  final String availabilityId;
  final String? lotNumber;
  final String sellerCompanyId;
  final String sellerCompanyName;
  final bool sellerCompanyVerified;
  final String brokerId;
  final String? dealId;
  final double allocatedQuantity;
  final String unitId;
  final String unitName;
  final String unitSymbol;
  final String priceBasis;
  final double? allocatedPrice;
  final AllocationStatus status;
  final String? notes;
  final String? releaseReason;
  final int version;
  final DateTime allocatedAt;
  final DateTime? confirmedAt;
  final DateTime? releasedAt;

  const AllocationItem({
    required this.id,
    required this.reference,
    required this.requirementId,
    required this.availabilityId,
    this.lotNumber,
    required this.sellerCompanyId,
    required this.sellerCompanyName,
    this.sellerCompanyVerified = false,
    required this.brokerId,
    this.dealId,
    required this.allocatedQuantity,
    required this.unitId,
    required this.unitName,
    required this.unitSymbol,
    required this.priceBasis,
    this.allocatedPrice,
    required this.status,
    this.notes,
    this.releaseReason,
    this.version = 1,
    required this.allocatedAt,
    this.confirmedAt,
    this.releasedAt,
  });

  String get formattedQuantity => UnitUtils.format(allocatedQuantity, unitSymbol);

  bool get canCreateDeal =>
      status == AllocationStatus.confirmed || status == AllocationStatus.proposed;

  bool get isAlreadyCommitted => dealId != null && dealId!.isNotEmpty;

  factory AllocationItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['allocated_quantity'] as num?)?.toDouble() ??
        (json['allocatedQuantity'] as num?)?.toDouble() ??
        0.0;

    final price = (json['allocated_price'] as num?)?.toDouble() ??
        (json['allocatedPrice'] as num?)?.toDouble();

    final allocatedAtRaw = json['allocated_at'] ?? json['allocatedAt'];
    final parsedAllocatedAt = allocatedAtRaw != null
        ? DateTime.tryParse(allocatedAtRaw.toString()) ?? DateTime.now()
        : DateTime.now();

    final confirmedAtRaw = json['confirmed_at'] ?? json['confirmedAt'];
    final parsedConfirmedAt =
        confirmedAtRaw != null ? DateTime.tryParse(confirmedAtRaw.toString()) : null;

    final releasedAtRaw = json['released_at'] ?? json['releasedAt'];
    final parsedReleasedAt =
        releasedAtRaw != null ? DateTime.tryParse(releasedAtRaw.toString()) : null;

    final rawStatus = json['status']?.toString();

    return AllocationItem(
      id: json['id']?.toString() ?? '',
      reference: json['allocation_reference']?.toString() ??
          json['allocationReference']?.toString() ??
          'ALC-PENDING',
      requirementId: json['requirement_id']?.toString() ??
          json['requirementId']?.toString() ??
          '',
      availabilityId: json['availability_id']?.toString() ??
          json['availabilityId']?.toString() ??
          '',
      lotNumber: json['lot_number']?.toString() ?? json['lotNumber']?.toString(),
      sellerCompanyId: json['seller_company_id']?.toString() ??
          json['sellerCompanyId']?.toString() ??
          '',
      sellerCompanyName: json['seller_company_name']?.toString() ??
          json['sellerCompanyName']?.toString() ??
          'Seller Enterprise',
      sellerCompanyVerified: json['seller_company_verified'] as bool? ??
          json['sellerCompanyVerified'] as bool? ??
          false,
      brokerId: json['broker_id']?.toString() ?? json['brokerId']?.toString() ?? '',
      dealId: json['deal_id']?.toString() ?? json['dealId']?.toString(),
      allocatedQuantity: qty,
      unitId: json['unit_id']?.toString() ?? json['unitId']?.toString() ?? '',
      unitName: json['unit_name']?.toString() ??
          json['unitName']?.toString() ??
          'Metric Tonne',
      unitSymbol: json['unit_symbol']?.toString() ??
          json['unitSymbol']?.toString() ??
          'MT',
      priceBasis: json['price_basis']?.toString() ??
          json['priceBasis']?.toString() ??
          'FOR_DESTINATION',
      allocatedPrice: price,
      status: AllocationStatus.fromString(rawStatus),
      notes: json['notes']?.toString(),
      releaseReason: json['release_reason']?.toString() ?? json['releaseReason']?.toString(),
      version: (json['version'] as num?)?.toInt() ?? 1,
      allocatedAt: parsedAllocatedAt,
      confirmedAt: parsedConfirmedAt,
      releasedAt: parsedReleasedAt,
    );
  }
}

/// DTO for proposing a quantity allocation from requirement against offer.
class CreateAllocationDto {
  final String requirementId;
  final String availabilityId;
  final double proposedQuantity;
  final String unitSymbol;
  final double remainingRequirementQuantity;
  final double availableOfferQuantity;
  final double agreedPrice;
  final String priceBasis;
  final String? notes;

  const CreateAllocationDto({
    required this.requirementId,
    required this.availabilityId,
    required this.proposedQuantity,
    required this.unitSymbol,
    required this.remainingRequirementQuantity,
    required this.availableOfferQuantity,
    required this.agreedPrice,
    this.priceBasis = 'FOR_DESTINATION',
    this.notes,
  });

  /// Client-side validation ensuring double-safety bounds.
  String? validate() {
    if (requirementId.trim().isEmpty) return 'Target requirement ID is missing';
    if (availabilityId.trim().isEmpty) return 'Target seller offer ID is missing';
    if (proposedQuantity <= 0) return 'Allocation quantity must be greater than zero';
    if (proposedQuantity > remainingRequirementQuantity) {
      return 'Proposed quantity ($proposedQuantity $unitSymbol) exceeds remaining requirement ($remainingRequirementQuantity $unitSymbol)';
    }
    if (proposedQuantity > availableOfferQuantity) {
      return 'Proposed quantity ($proposedQuantity $unitSymbol) exceeds seller availability ($availableOfferQuantity $unitSymbol)';
    }
    if (agreedPrice <= 0) return 'Agreed price must be greater than zero';
    return null;
  }
}
