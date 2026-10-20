/// Deal confirmation lifecycle status matching authoritative backend enum.
enum DealConfirmationStatus {
  awaitingBuyerConfirmation('Awaiting Buyer Confirmation'),
  buyerConfirmed('Buyer Confirmed'),
  awaitingSellerConfirmation('Awaiting Seller Confirmation'),
  confirmed('Confirmed'),
  amendmentRequired('Amendment Required'),
  expired('Expired');

  final String label;
  const DealConfirmationStatus(this.label);

  static DealConfirmationStatus fromString(String? raw) {
    if (raw == null) return DealConfirmationStatus.awaitingBuyerConfirmation;
    final clean = raw.trim().toLowerCase();
    if (clean.contains('buyer confirmed')) return DealConfirmationStatus.buyerConfirmed;
    if (clean.contains('seller confirmation')) return DealConfirmationStatus.awaitingSellerConfirmation;
    if (clean.contains('confirmed') || clean.contains('booked')) return DealConfirmationStatus.confirmed;
    if (clean.contains('amendment')) return DealConfirmationStatus.amendmentRequired;
    if (clean.contains('expired')) return DealConfirmationStatus.expired;
    return DealConfirmationStatus.awaitingBuyerConfirmation;
  }
}

/// Commercial charge breakdown item (e.g. Brokerage, Mandi Cess, Weighbridge, Escrow QA).
class BuyerSideCharge {
  final String name;
  final double rate;
  final double amount;
  final String type;
  final String description;
  final bool includedInLandedPrice;

  const BuyerSideCharge({
    required this.name,
    required this.rate,
    required this.amount,
    required this.type,
    required this.description,
    this.includedInLandedPrice = true,
  });

  factory BuyerSideCharge.fromMap(Map<String, dynamic> map) {
    return BuyerSideCharge(
      name: map['name'] as String? ?? 'Commercial Fee',
      rate: (map['rate'] as num?)?.toDouble() ?? 0.0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] as String? ?? 'per_unit',
      description: map['description'] as String? ?? '',
      includedInLandedPrice: map['includedInLandedPrice'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'rate': rate,
      'amount': amount,
      'type': type,
      'description': description,
      'includedInLandedPrice': includedInLandedPrice,
    };
  }
}

/// Quality specification parameter agreed during negotiation.
class BuyerQualitySpec {
  final String parameterName;
  final String targetValue;
  final String? tolerance;
  final String? unit;
  final bool isMandatory;

  const BuyerQualitySpec({
    required this.parameterName,
    required this.targetValue,
    this.tolerance,
    this.unit,
    this.isMandatory = true,
  });

  factory BuyerQualitySpec.fromMap(Map<String, dynamic> map) {
    return BuyerQualitySpec(
      parameterName: map['parameterName'] as String? ??
          map['name'] as String? ??
          'Quality Parameter',
      targetValue: map['targetValue']?.toString() ??
          map['value']?.toString() ??
          'Standard',
      tolerance: map['tolerance'] as String?,
      unit: map['unit'] as String?,
      isMandatory: map['isMandatory'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'parameterName': parameterName,
      'targetValue': targetValue,
      'tolerance': tolerance,
      'unit': unit,
      'isMandatory': isMandatory,
    };
  }
}

/// Complete negotiated commercial terms snapshot for final deal review.
class FinalDealCommercialTerms {
  final String commodityName;
  final String gradeName;
  final double quantity;
  final String unitSymbol;
  final double basePricePerUnit;
  final double netLandedPricePerUnit;
  final double totalEstimatedValue;
  final List<BuyerSideCharge> applicableCharges;
  final double totalChargesPerUnit;
  final String deliveryLocation;
  final String? deliveryState;
  final String? deliveryDistrict;
  final String? deliveryCity;
  final DateTime? deliveryWindowStart;
  final DateTime? deliveryWindowEnd;
  final DateTime? deliveryDate;
  final String paymentTerms;
  final String packagingType;
  final String freightTerms;
  final String inspectionRequirements;
  final String? specialConditions;
  final String? remarks;
  final List<BuyerQualitySpec> qualityParameters;

  const FinalDealCommercialTerms({
    required this.commodityName,
    required this.gradeName,
    required this.quantity,
    required this.unitSymbol,
    required this.basePricePerUnit,
    required this.netLandedPricePerUnit,
    required this.totalEstimatedValue,
    required this.applicableCharges,
    required this.totalChargesPerUnit,
    required this.deliveryLocation,
    this.deliveryState,
    this.deliveryDistrict,
    this.deliveryCity,
    this.deliveryWindowStart,
    this.deliveryWindowEnd,
    this.deliveryDate,
    required this.paymentTerms,
    required this.packagingType,
    required this.freightTerms,
    required this.inspectionRequirements,
    this.specialConditions,
    this.remarks,
    required this.qualityParameters,
  });

  factory FinalDealCommercialTerms.fromMap(Map<String, dynamic> map) {
    final rawCharges = map['applicableCharges'] as List<dynamic>? ?? [];
    final charges = rawCharges
        .map((c) => BuyerSideCharge.fromMap(c as Map<String, dynamic>))
        .toList();

    final rawQuality = map['qualityParameters'] as List<dynamic>? ?? [];
    final specs = rawQuality
        .map((q) => BuyerQualitySpec.fromMap(q as Map<String, dynamic>))
        .toList();

    return FinalDealCommercialTerms(
      commodityName: map['commodityName'] as String? ?? 'Commercial Commodity',
      gradeName: map['gradeName'] as String? ?? 'Standard Grade',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unitSymbol: map['unitSymbol'] as String? ?? 'MT',
      basePricePerUnit: (map['basePricePerUnit'] as num?)?.toDouble() ?? 0.0,
      netLandedPricePerUnit:
          (map['netLandedPricePerUnit'] as num?)?.toDouble() ?? 0.0,
      totalEstimatedValue:
          (map['totalEstimatedValue'] as num?)?.toDouble() ?? 0.0,
      applicableCharges: charges,
      totalChargesPerUnit:
          (map['totalChargesPerUnit'] as num?)?.toDouble() ?? 0.0,
      deliveryLocation:
          map['deliveryLocation'] as String? ?? 'Buyer Designated Hub',
      deliveryState: map['deliveryState'] as String?,
      deliveryDistrict: map['deliveryDistrict'] as String?,
      deliveryCity: map['deliveryCity'] as String?,
      deliveryWindowStart: map['deliveryWindowStart'] != null
          ? DateTime.tryParse(map['deliveryWindowStart'].toString())
          : null,
      deliveryWindowEnd: map['deliveryWindowEnd'] != null
          ? DateTime.tryParse(map['deliveryWindowEnd'].toString())
          : null,
      deliveryDate: map['deliveryDate'] != null
          ? DateTime.tryParse(map['deliveryDate'].toString())
          : null,
      paymentTerms: map['paymentTerms'] as String? ??
          '100% Against Delivery via Broker Escrow',
      packagingType: map['packagingType'] as String? ?? 'Standard Bags',
      freightTerms: map['freightTerms'] as String? ?? 'FOR Destination',
      inspectionRequirements: map['inspectionRequirements'] as String? ??
          'Third-party NABL lab testing',
      specialConditions: map['specialConditions'] as String?,
      remarks: map['remarks'] as String?,
      qualityParameters: specs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commodityName': commodityName,
      'gradeName': gradeName,
      'quantity': quantity,
      'unitSymbol': unitSymbol,
      'basePricePerUnit': basePricePerUnit,
      'netLandedPricePerUnit': netLandedPricePerUnit,
      'totalEstimatedValue': totalEstimatedValue,
      'applicableCharges': applicableCharges.map((c) => c.toMap()).toList(),
      'totalChargesPerUnit': totalChargesPerUnit,
      'deliveryLocation': deliveryLocation,
      'deliveryState': deliveryState,
      'deliveryDistrict': deliveryDistrict,
      'deliveryCity': deliveryCity,
      'deliveryWindowStart': deliveryWindowStart?.toIso8601String(),
      'deliveryWindowEnd': deliveryWindowEnd?.toIso8601String(),
      'deliveryDate': deliveryDate?.toIso8601String(),
      'paymentTerms': paymentTerms,
      'packagingType': packagingType,
      'freightTerms': freightTerms,
      'inspectionRequirements': inspectionRequirements,
      'specialConditions': specialConditions,
      'remarks': remarks,
      'qualityParameters': qualityParameters.map((q) => q.toMap()).toList(),
    };
  }
}

/// Authoritative Final Deal Review entity matching backend contract.
/// STRICT PRIVACY: Seller identities, IDs, phone numbers, and seller locations
/// are completely omitted from this model.
class FinalDealReviewData {
  final String dealId;
  final String requestId;
  final String requirementDisplayId;
  final DealConfirmationStatus status;
  final String rawStatus;
  final int versionNumber;
  final bool hasPreviousVersion;
  final int? previousVersionNumber;
  final FinalDealCommercialTerms currentTerms;
  final FinalDealCommercialTerms? previousTerms;
  final String brokerName;
  final String brokerAgency;
  final String? brokerNotes;
  final DateTime snapshotTimestamp;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FinalDealReviewData({
    required this.dealId,
    required this.requestId,
    required this.requirementDisplayId,
    required this.status,
    required this.rawStatus,
    required this.versionNumber,
    required this.hasPreviousVersion,
    this.previousVersionNumber,
    required this.currentTerms,
    this.previousTerms,
    required this.brokerName,
    required this.brokerAgency,
    this.brokerNotes,
    required this.snapshotTimestamp,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isConfirmable =>
      status == DealConfirmationStatus.awaitingBuyerConfirmation;

  bool get isConfirmed =>
      status == DealConfirmationStatus.buyerConfirmed ||
      status == DealConfirmationStatus.confirmed;

  bool get isAmendmentRequired =>
      status == DealConfirmationStatus.amendmentRequired;

  factory FinalDealReviewData.fromMap(Map<String, dynamic> map) {
    return FinalDealReviewData(
      dealId: map['dealId'] as String? ?? map['id'] as String? ?? '',
      requestId: map['requestId'] as String? ?? '',
      requirementDisplayId: map['requirementDisplayId'] as String? ?? 'REQ-TRADE',
      status: DealConfirmationStatus.fromString(map['status'] as String?),
      rawStatus: map['rawStatus'] as String? ?? map['status'] as String? ?? '',
      versionNumber: (map['versionNumber'] as num?)?.toInt() ?? 1,
      hasPreviousVersion: map['hasPreviousVersion'] as bool? ?? false,
      previousVersionNumber: (map['previousVersionNumber'] as num?)?.toInt(),
      currentTerms: FinalDealCommercialTerms.fromMap(
          map['currentTerms'] as Map<String, dynamic>? ?? {}),
      previousTerms: map['previousTerms'] != null
          ? FinalDealCommercialTerms.fromMap(
              map['previousTerms'] as Map<String, dynamic>)
          : null,
      brokerName: map['brokerName'] as String? ?? 'Assigned Broker',
      brokerAgency: map['brokerAgency'] as String? ?? 'BrokerBridge Commodity Desk',
      brokerNotes: map['brokerNotes'] as String?,
      snapshotTimestamp: map['snapshotTimestamp'] != null
          ? DateTime.tryParse(map['snapshotTimestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dealId': dealId,
      'requestId': requestId,
      'requirementDisplayId': requirementDisplayId,
      'status': status.label,
      'rawStatus': rawStatus,
      'versionNumber': versionNumber,
      'hasPreviousVersion': hasPreviousVersion,
      'previousVersionNumber': previousVersionNumber,
      'currentTerms': currentTerms.toMap(),
      'previousTerms': previousTerms?.toMap(),
      'brokerName': brokerName,
      'brokerAgency': brokerAgency,
      'brokerNotes': brokerNotes,
      'snapshotTimestamp': snapshotTimestamp.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

/// Explicit Confirmation Input Payload
class ConfirmDealInput {
  final String dealId;
  final int expectedVersion;
  final bool buyerConfirmed;

  const ConfirmDealInput({
    required this.dealId,
    required this.expectedVersion,
    required this.buyerConfirmed,
  });

  void validate() {
    if (dealId.trim().isEmpty) {
      throw ArgumentError('Deal reference is required for confirmation.');
    }
    if (expectedVersion < 1) {
      throw ArgumentError('Invalid version sequence.');
    }
    if (!buyerConfirmed) {
      throw ArgumentError('Explicit confirmation agreement is required.');
    }
  }
}

/// Deal Amendment Request Input Payload
class RequestAmendmentInput {
  final String dealId;
  final int expectedVersion;
  final String reason;

  const RequestAmendmentInput({
    required this.dealId,
    required this.expectedVersion,
    required this.reason,
  });

  void validate() {
    if (dealId.trim().isEmpty) {
      throw ArgumentError('Deal reference is required.');
    }
    if (expectedVersion < 1) {
      throw ArgumentError('Invalid version sequence.');
    }
    if (reason.trim().length < 5) {
      throw ArgumentError('Amendment reason must be at least 5 characters.');
    }
  }
}
