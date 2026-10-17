import 'package:flutter/foundation.dart';
import '../../work/domain/unit_utils.dart';

/// Deal lifecycle statuses aligned strictly with backend `DealLifecycleStatus`.
enum DealStatus {
  draft('Draft', 'Draft', true),
  negotiation('Negotiation', 'Negotiating', true),
  awaitingBuyerConfirmation('Awaiting Buyer Confirmation', 'Awaiting Buyer', true),
  awaitingSellerConfirmation('Awaiting Seller Confirmation', 'Awaiting Seller', true),
  readyToFinalize('Ready to Finalize', 'Ready to Finalize', true),
  finalized('Finalized', 'Finalized', false),
  inFulfillment('In Fulfillment', 'In Fulfillment', false),
  completed('Completed', 'Completed', false),
  cancelled('Cancelled', 'Cancelled', false),
  disputed('Disputed', 'Disputed', false);

  final String code;
  final String displayLabel;
  final bool isOperational;

  const DealStatus(this.code, this.displayLabel, this.isOperational);

  static DealStatus fromString(String? val) {
    if (val == null) return DealStatus.draft;
    final clean = val.trim().toLowerCase();
    switch (clean) {
      case 'draft':
        return DealStatus.draft;
      case 'negotiation':
        return DealStatus.negotiation;
      case 'awaiting buyer confirmation':
      case 'awaiting buyer':
        return DealStatus.awaitingBuyerConfirmation;
      case 'awaiting seller confirmation':
      case 'awaiting seller':
        return DealStatus.awaitingSellerConfirmation;
      case 'ready to finalize':
      case 'ready_to_finalize':
        return DealStatus.readyToFinalize;
      case 'finalized':
        return DealStatus.finalized;
      case 'in fulfillment':
      case 'dispatch pending':
      case 'in transit':
      case 'active':
        return DealStatus.inFulfillment;
      case 'completed':
      case 'delivered':
        return DealStatus.completed;
      case 'cancelled':
        return DealStatus.cancelled;
      case 'disputed':
        return DealStatus.disputed;
      default:
        return DealStatus.draft;
    }
  }
}

/// Dual-party deal confirmation tracker.
@immutable
class DealConfirmationState {
  final int latestVersionNumber;
  final bool buyerConfirmed;
  final DateTime? buyerConfirmedAt;
  final bool sellerConfirmed;
  final DateTime? sellerConfirmedAt;
  final bool canFinalize;

  const DealConfirmationState({
    this.latestVersionNumber = 1,
    this.buyerConfirmed = false,
    this.buyerConfirmedAt,
    this.sellerConfirmed = false,
    this.sellerConfirmedAt,
    this.canFinalize = false,
  });

  factory DealConfirmationState.fromJson(Map<String, dynamic> json) {
    final buyerAt = json['buyerConfirmedAt'] != null
        ? DateTime.tryParse(json['buyerConfirmedAt'].toString())
        : null;
    final sellerAt = json['sellerConfirmedAt'] != null
        ? DateTime.tryParse(json['sellerConfirmedAt'].toString())
        : null;

    final buyerConf = json['buyerConfirmed'] as bool? ?? false;
    final sellerConf = json['sellerConfirmed'] as bool? ?? false;

    return DealConfirmationState(
      latestVersionNumber: (json['latestVersionNumber'] as num?)?.toInt() ?? 1,
      buyerConfirmed: buyerConf,
      buyerConfirmedAt: buyerAt,
      sellerConfirmed: sellerConf,
      sellerConfirmedAt: sellerAt,
      canFinalize: (json['canFinalize'] as bool?) ?? (buyerConf && sellerConf),
    );
  }
}

/// Summary deal item for lists and overview tiles.
@immutable
class DealItem {
  final String id;
  final String ref;
  final String quotationId;
  final String requirementId;
  final String? allocationId;
  final String? allocationReference;
  final String? bookingReference;
  final String commodityName;
  final String? gradeName;
  final String buyerCompanyId;
  final String buyerCompanyName;
  final String sellerCompanyId;
  final String sellerCompanyName;
  final double agreedQuantity;
  final String unitSymbol;
  final double agreedPrice;
  final double totalValuation;
  final String priceBasis;
  final String? deliveryLocation;
  final String? deliveryDate;
  final DealStatus status;
  final int latestVersionNumber;
  final bool buyerConfirmed;
  final bool sellerConfirmed;
  final DateTime createdAt;
  final DateTime? closedAt;

  const DealItem({
    required this.id,
    required this.ref,
    required this.quotationId,
    required this.requirementId,
    this.allocationId,
    this.allocationReference,
    this.bookingReference,
    required this.commodityName,
    this.gradeName,
    required this.buyerCompanyId,
    required this.buyerCompanyName,
    required this.sellerCompanyId,
    required this.sellerCompanyName,
    required this.agreedQuantity,
    required this.unitSymbol,
    required this.agreedPrice,
    required this.totalValuation,
    required this.priceBasis,
    this.deliveryLocation,
    this.deliveryDate,
    required this.status,
    this.latestVersionNumber = 1,
    this.buyerConfirmed = false,
    this.sellerConfirmed = false,
    required this.createdAt,
    this.closedAt,
  });

  String get formattedQuantity => UnitUtils.format(agreedQuantity, unitSymbol);

  factory DealItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['agreedQuantity'] as num?)?.toDouble() ??
        (json['agreed_quantity'] as num?)?.toDouble() ??
        (json['quantity'] as num?)?.toDouble() ??
        0.0;

    final price = (json['agreedPrice'] as num?)?.toDouble() ??
        (json['agreed_price'] as num?)?.toDouble() ??
        (json['price'] as num?)?.toDouble() ??
        0.0;

    final valuation = (json['totalValuation'] as num?)?.toDouble() ??
        (json['total_valuation'] as num?)?.toDouble() ??
        (qty * price);

    final createdRaw = json['createdAt'] ?? json['created_at'];
    final parsedCreatedAt = createdRaw != null
        ? DateTime.tryParse(createdRaw.toString()) ?? DateTime.now()
        : DateTime.now();

    final closedRaw = json['closedAt'] ?? json['closed_at'];
    final parsedClosedAt = closedRaw != null ? DateTime.tryParse(closedRaw.toString()) : null;

    final id = json['id']?.toString() ?? '';
    final shortId = id.length >= 6 ? id.substring(0, 6).toUpperCase() : id;

    return DealItem(
      id: id,
      ref: json['bookingReference']?.toString() ??
          json['booking_reference']?.toString() ??
          'DL-$shortId',
      quotationId: json['quotationId']?.toString() ?? json['quotation_id']?.toString() ?? '',
      requirementId: json['requirementId']?.toString() ?? json['requirement_id']?.toString() ?? '',
      allocationId: json['allocationId']?.toString() ?? json['allocation_id']?.toString(),
      allocationReference: json['allocationReference']?.toString() ??
          json['allocation_reference']?.toString(),
      bookingReference: json['bookingReference']?.toString() ??
          json['booking_reference']?.toString(),
      commodityName: json['commodityName']?.toString() ??
          json['commodity_name']?.toString() ??
          'Agricultural Commodity',
      gradeName: json['gradeName']?.toString() ?? json['grade_name']?.toString(),
      buyerCompanyId: json['buyerCompanyId']?.toString() ?? json['buyer_id']?.toString() ?? '',
      buyerCompanyName: json['buyerCompanyName']?.toString() ??
          json['buyer_company_name']?.toString() ??
          'Buyer Mandate',
      sellerCompanyId: json['sellerCompanyId']?.toString() ?? json['seller_id']?.toString() ?? '',
      sellerCompanyName: json['sellerCompanyName']?.toString() ??
          json['seller_company_name']?.toString() ??
          'Seller Lot',
      agreedQuantity: qty,
      unitSymbol: json['unitSymbol']?.toString() ?? json['unit_symbol']?.toString() ?? 'MT',
      agreedPrice: price,
      totalValuation: valuation,
      priceBasis: json['priceBasis']?.toString() ??
          json['price_basis']?.toString() ??
          'FOR_DESTINATION',
      deliveryLocation: json['deliveryLocation']?.toString() ?? json['delivery_location']?.toString(),
      deliveryDate: json['deliveryDate']?.toString() ?? json['delivery_date']?.toString(),
      status: DealStatus.fromString(json['status']?.toString()),
      latestVersionNumber: (json['latestVersionNumber'] as num?)?.toInt() ?? 1,
      buyerConfirmed: json['buyerConfirmed'] as bool? ?? false,
      sellerConfirmed: json['sellerConfirmed'] as bool? ?? false,
      createdAt: parsedCreatedAt,
      closedAt: parsedClosedAt,
    );
  }
}

/// Comprehensive deal detail with contract terms, confirmations, and audit trail.
@immutable
class DealDetailItem {
  final DealItem deal;
  final DealConfirmationState confirmations;
  final String deliveryTerms;
  final String paymentTerms;
  final String packagingType;
  final double brokerCommissionRate;
  final String commissionBasis;
  final String? notes;

  const DealDetailItem({
    required this.deal,
    required this.confirmations,
    required this.deliveryTerms,
    required this.paymentTerms,
    required this.packagingType,
    required this.brokerCommissionRate,
    this.commissionBasis = '₹/MT',
    this.notes,
  });

  factory DealDetailItem.fromJson(Map<String, dynamic> json) {
    final deal = DealItem.fromJson(json['summary'] as Map<String, dynamic>? ?? json);
    final conf = json['confirmations'] != null
        ? DealConfirmationState.fromJson(json['confirmations'] as Map<String, dynamic>)
        : DealConfirmationState(
            latestVersionNumber: deal.latestVersionNumber,
            buyerConfirmed: deal.buyerConfirmed,
            sellerConfirmed: deal.sellerConfirmed,
            canFinalize: deal.buyerConfirmed && deal.sellerConfirmed,
          );

    return DealDetailItem(
      deal: deal,
      confirmations: conf,
      deliveryTerms: json['deliveryTerms']?.toString() ?? 'FOR Destination Mandi',
      paymentTerms: json['paymentTerms']?.toString() ?? '100% Advance against Lorry Receipt',
      packagingType: json['packagingType']?.toString() ?? '50kg HDPE / Jute Bags',
      brokerCommissionRate: (json['brokerCommissionRate'] as num?)?.toDouble() ?? 50.0,
      commissionBasis: json['commissionBasis']?.toString() ?? '₹/MT',
      notes: json['notes']?.toString(),
    );
  }
}

/// DTO for creating a deal from an authorized allocation.
class CreateDealDto {
  final String allocationId;
  final double agreedPrice;
  final double agreedQuantity;
  final String priceBasis;
  final String deliveryLocation;
  final DateTime deliveryDate;
  final String deliveryTerms;
  final String paymentTerms;
  final String packagingType;
  final double brokerCommissionRate;
  final String commissionBasis;
  final String? notes;

  const CreateDealDto({
    required this.allocationId,
    required this.agreedPrice,
    required this.agreedQuantity,
    this.priceBasis = 'FOR_DESTINATION',
    required this.deliveryLocation,
    required this.deliveryDate,
    this.deliveryTerms = 'FOR Destination Warehouse',
    this.paymentTerms = 'RTGS / NEFT on Dispatch Inspection',
    this.packagingType = 'Standard Jute / HDPE Bags',
    this.brokerCommissionRate = 50.0,
    this.commissionBasis = '₹/MT',
    this.notes,
  });

  String? validate() {
    if (allocationId.trim().isEmpty) return 'Valid allocation reference is required';
    if (agreedPrice <= 0) return 'Agreed price must be greater than zero';
    if (agreedQuantity <= 0) return 'Agreed quantity must be greater than zero';
    if (deliveryLocation.trim().isEmpty) return 'Delivery location is required';
    if (brokerCommissionRate < 0) return 'Broker commission rate cannot be negative';
    return null;
  }
}

/// Type of material difference detected between term versions.
enum MaterialDiffType {
  increased('increased'),
  reduced('reduced'),
  changed('changed'),
  added('added'),
  removed('removed');

  final String code;
  const MaterialDiffType(this.code);

  static MaterialDiffType fromString(String? val) {
    if (val == null) return MaterialDiffType.changed;
    switch (val.toLowerCase().trim()) {
      case 'increased':
        return MaterialDiffType.increased;
      case 'reduced':
        return MaterialDiffType.reduced;
      case 'added':
        return MaterialDiffType.added;
      case 'removed':
        return MaterialDiffType.removed;
      default:
        return MaterialDiffType.changed;
    }
  }
}

/// Represents a detected material field difference between two deal term snapshots.
@immutable
class MaterialDiffItem {
  final String field;
  final String label;
  final dynamic oldValue;
  final dynamic newValue;
  final MaterialDiffType type;

  const MaterialDiffItem({
    required this.field,
    required this.label,
    required this.oldValue,
    required this.newValue,
    required this.type,
  });

  bool get isMaterial => true;

  factory MaterialDiffItem.fromJson(Map<String, dynamic> json) {
    return MaterialDiffItem(
      field: json['field']?.toString() ?? '',
      label: json['label']?.toString() ?? json['field']?.toString() ?? '',
      oldValue: json['oldValue'] ?? json['old_value'],
      newValue: json['newValue'] ?? json['new_value'],
      type: MaterialDiffType.fromString(
        json['type']?.toString() ?? json['diffType']?.toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'label': label,
      'oldValue': oldValue,
      'newValue': newValue,
      'type': type.code,
    };
  }
}

/// Represents an immutable version in the deal negotiation timeline.
@immutable
class DealVersionItem {
  final String id;
  final int versionNumber;
  final String status;
  final String actorId;
  final String actorName;
  final String actorRole;
  final DateTime createdAt;
  final Map<String, dynamic> snapshot;
  final List<MaterialDiffItem> diffs;
  final String? changeReason;

  const DealVersionItem({
    required this.id,
    required this.versionNumber,
    required this.status,
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    required this.createdAt,
    required this.snapshot,
    this.diffs = const [],
    this.changeReason,
  });

  factory DealVersionItem.fromJson(Map<String, dynamic> json) {
    final rawDiffs = json['diffs'] as List<dynamic>? ?? [];
    final diffList = rawDiffs
        .whereType<Map<String, dynamic>>()
        .map(MaterialDiffItem.fromJson)
        .toList();

    final createdRaw = json['createdAt'] ?? json['created_at'];
    final parsedCreated = createdRaw != null
        ? DateTime.tryParse(createdRaw.toString()) ?? DateTime.now()
        : DateTime.now();

    final rawSnapshot = json['snapshot'] ?? json['snapshot_payload'] ?? {};
    final snapshotMap = rawSnapshot is Map<String, dynamic>
        ? rawSnapshot
        : <String, dynamic>{};

    return DealVersionItem(
      id: json['id']?.toString() ?? '',
      versionNumber: (json['versionNumber'] as num?)?.toInt() ??
          (json['version_number'] as num?)?.toInt() ??
          1,
      status: json['status']?.toString() ?? 'Negotiation',
      actorId: json['actorId']?.toString() ?? json['actor_id']?.toString() ?? '',
      actorName: json['actorName']?.toString() ??
          json['actor_name']?.toString() ??
          'Broker Desk',
      actorRole: json['actorRole']?.toString() ??
          json['actor_role']?.toString() ??
          'broker',
      createdAt: parsedCreated,
      snapshot: snapshotMap,
      diffs: diffList,
      changeReason: json['changeReason']?.toString() ??
          json['change_reason']?.toString(),
    );
  }
}

/// DTO for proposing an amendment to deal terms.
class UpdateDealTermsDto {
  final String dealId;
  final int expectedVersion;
  final double agreedPrice;
  final double agreedQuantity;
  final String priceBasis;
  final String deliveryLocation;
  final DateTime deliveryDate;
  final String deliveryTerms;
  final String paymentTerms;
  final String packagingType;
  final double brokerCommissionRate;
  final String commissionBasis;
  final String? reason;

  const UpdateDealTermsDto({
    required this.dealId,
    required this.expectedVersion,
    required this.agreedPrice,
    required this.agreedQuantity,
    this.priceBasis = 'FOR_DESTINATION',
    required this.deliveryLocation,
    required this.deliveryDate,
    this.deliveryTerms = 'FOR Destination Mandi',
    this.paymentTerms = 'RTGS / NEFT on Dispatch Inspection',
    this.packagingType = 'Standard Jute / HDPE Bags',
    this.brokerCommissionRate = 50.0,
    this.commissionBasis = '₹/MT',
    this.reason,
  });

  String? validate() {
    if (dealId.trim().isEmpty) return 'Deal identifier is required';
    if (expectedVersion <= 0) return 'Invalid expected version number';
    if (agreedPrice <= 0) return 'Agreed price must be greater than zero';
    if (agreedQuantity <= 0) return 'Agreed quantity must be greater than zero';
    if (deliveryLocation.trim().isEmpty) return 'Delivery location is required';
    if (brokerCommissionRate < 0) return 'Broker commission rate cannot be negative';
    if (reason != null && reason!.trim().isNotEmpty && reason!.trim().length < 3) {
      return 'Amendment reason must be at least 3 characters for audit logging';
    }
    return null;
  }

  Map<String, dynamic> toSnapshot() {
    return {
      'dealId': dealId,
      'agreedPrice': agreedPrice,
      'agreedQuantity': agreedQuantity,
      'priceBasis': priceBasis,
      'deliveryLocation': deliveryLocation,
      'deliveryDate': deliveryDate.toIso8601String().substring(0, 10),
      'deliveryTerms': deliveryTerms,
      'paymentTerms': paymentTerms,
      'packagingType': packagingType,
      'brokerCommissionRate': brokerCommissionRate,
      'commissionBasis': commissionBasis,
      'buyerConfirmed': false,
      'sellerConfirmed': false,
    };
  }
}

/// DTO for recording formal party confirmation of deal terms.
class PartyConfirmationDto {
  final String dealId;
  final int versionNumber;
  final String party; // 'BUYER' | 'SELLER'
  final String? verificationNotes;

  const PartyConfirmationDto({
    required this.dealId,
    required this.versionNumber,
    required this.party,
    this.verificationNotes,
  });

  String? validate() {
    if (dealId.trim().isEmpty) return 'Deal ID is required';
    if (versionNumber <= 0) return 'Valid version number is required';
    final p = party.toUpperCase().trim();
    if (p != 'BUYER' && p != 'SELLER') {
      return "Party must be either 'BUYER' or 'SELLER'";
    }
    return null;
  }
}

/// Material change detection and visual diff calculation engine.
/// Fully mirrors the backend version-engine.ts algorithms.
class DealVersionEngine {
  const DealVersionEngine._();

  static const List<Map<String, dynamic>> _materialFields = [
    {
      'name': 'rate',
      'label': 'Rate / Price',
      'keys': ['rate', 'price', 'agreedPrice', 'agreed_price', 'offeredPrice'],
      'isNumeric': true,
    },
    {
      'name': 'quantity',
      'label': 'Quantity',
      'keys': ['quantity', 'agreedQuantity', 'agreed_quantity', 'totalQuantity'],
      'isNumeric': true,
    },
    {
      'name': 'priceBasis',
      'label': 'Price Basis',
      'keys': ['priceBasis', 'price_basis'],
      'isNumeric': false,
    },
    {
      'name': 'deliveryDate',
      'label': 'Delivery Date',
      'keys': ['deliveryDate', 'delivery_date', 'targetDate', 'target_date'],
      'isNumeric': false,
    },
    {
      'name': 'deliveryTerms',
      'label': 'Delivery Terms',
      'keys': ['deliveryTerms', 'delivery_terms'],
      'isNumeric': false,
    },
    {
      'name': 'deliveryLocation',
      'label': 'Delivery Location',
      'keys': ['deliveryLocation', 'delivery_location', 'warehouse'],
      'isNumeric': false,
    },
    {
      'name': 'paymentTerms',
      'label': 'Payment Terms',
      'keys': ['paymentTerms', 'payment_terms'],
      'isNumeric': false,
    },
    {
      'name': 'packagingType',
      'label': 'Packaging Type',
      'keys': ['packagingType', 'packaging_type'],
      'isNumeric': false,
    },
    {
      'name': 'brokerCommissionRate',
      'label': 'Brokerage Rate',
      'keys': ['brokerCommissionRate', 'brokerageRate', 'brokerage_rate'],
      'isNumeric': true,
    },
  ];

  static dynamic _normalizeValue(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) {
      final trimmed = val.trim();
      if (trimmed.isEmpty) return null;
      final parsedNum = double.tryParse(trimmed);
      if (parsedNum != null && !trimmed.contains('-') && !trimmed.contains('/')) {
        return parsedNum;
      }
      if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(trimmed)) {
        return trimmed.substring(0, 10);
      }
      return trimmed;
    }
    if (val is DateTime) {
      return val.toIso8601String().substring(0, 10);
    }
    return val;
  }

  /// Returns true if any material commercial field has changed between snapshots.
  static bool detectMaterialChanges(
    Map<String, dynamic>? oldSnapshot,
    Map<String, dynamic>? newSnapshot,
  ) {
    if (oldSnapshot == null && newSnapshot == null) return false;
    if (oldSnapshot == null || newSnapshot == null) return true;

    for (final field in _materialFields) {
      final keys = (field['keys'] as List).cast<String>();
      dynamic oldVal;
      dynamic newVal;

      for (final key in keys) {
        if (oldSnapshot.containsKey(key) && oldSnapshot[key] != null) {
          oldVal = oldSnapshot[key];
          break;
        }
      }

      for (final key in keys) {
        if (newSnapshot.containsKey(key) && newSnapshot[key] != null) {
          newVal = newSnapshot[key];
          break;
        }
      }

      final normOld = _normalizeValue(oldVal);
      final normNew = _normalizeValue(newVal);

      if (normOld != normNew) {
        if (normOld == null && normNew == null) continue;
        return true;
      }
    }
    return false;
  }

  /// Calculates detailed material differences with directionality.
  static List<MaterialDiffItem> getMaterialDiffList(
    Map<String, dynamic>? oldSnapshot,
    Map<String, dynamic>? newSnapshot,
  ) {
    final diffs = <MaterialDiffItem>[];
    if (newSnapshot == null) return diffs;

    for (final field in _materialFields) {
      final keys = (field['keys'] as List).cast<String>();
      final isNumeric = field['isNumeric'] as bool? ?? false;
      dynamic oldVal;
      dynamic newVal;

      if (oldSnapshot != null) {
        for (final key in keys) {
          if (oldSnapshot.containsKey(key) && oldSnapshot[key] != null) {
            oldVal = oldSnapshot[key];
            break;
          }
        }
      }

      for (final key in keys) {
        if (newSnapshot.containsKey(key) && newSnapshot[key] != null) {
          newVal = newSnapshot[key];
          break;
        }
      }

      final normOld = _normalizeValue(oldVal);
      final normNew = _normalizeValue(newVal);

      if (normOld != normNew) {
        if (normOld == null && normNew == null) continue;

        MaterialDiffType type = MaterialDiffType.changed;
        if (normOld == null && normNew != null) {
          type = MaterialDiffType.added;
        } else if (normOld != null && normNew == null) {
          type = MaterialDiffType.removed;
        } else if (isNumeric && normOld is num && normNew is num) {
          type = normNew > normOld
              ? MaterialDiffType.increased
              : MaterialDiffType.reduced;
        }

        diffs.add(
          MaterialDiffItem(
            field: field['name'] as String,
            label: field['label'] as String,
            oldValue: normOld,
            newValue: normNew,
            type: type,
          ),
        );
      }
    }
    return diffs;
  }
}
