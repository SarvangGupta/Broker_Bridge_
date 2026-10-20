import 'package:flutter/foundation.dart';

/// Charge item associated with a commercial offer (e.g. Mandi cess, Brokerage, Handling).
/// Conforms to transparent commercial disclosure without fabricating missing data.
class OfferChargeItem {
  final String name;
  final double rate;
  final double amount;
  final String type; // 'per_unit', 'fixed', 'percentage'
  final String? description;
  final bool includedInLandedPrice;

  const OfferChargeItem({
    required this.name,
    required this.rate,
    required this.amount,
    this.type = 'per_unit',
    this.description,
    this.includedInLandedPrice = true,
  });

  factory OfferChargeItem.fromMap(Map<String, dynamic> map) {
    return OfferChargeItem(
      name: map['name'] as String? ?? 'Commercial Charge',
      rate: (map['rate'] as num?)?.toDouble() ?? 0.0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] as String? ?? 'per_unit',
      description: map['description'] as String?,
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

/// Quality parameter specification for a commercial offer.
class OfferQualitySpec {
  final String parameterName;
  final String targetValue;
  final String? tolerance;
  final String? unit;
  final bool isMandatory;

  const OfferQualitySpec({
    required this.parameterName,
    required this.targetValue,
    this.tolerance,
    this.unit,
    this.isMandatory = true,
  });

  factory OfferQualitySpec.fromMap(Map<String, dynamic> map) {
    return OfferQualitySpec(
      parameterName: map['parameterName'] as String? ?? (map['name'] as String? ?? 'Quality Parameter'),
      targetValue: map['targetValue']?.toString() ?? (map['value']?.toString() ?? ''),
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

/// An immutable negotiation round record preserving historical commercial proposals.
/// Each round is auditable and never overwritten.
class NegotiationRound {
  final String id;
  final int versionNumber;
  final String status; // 'Proposed', 'Countered', 'Superseded', 'Accepted', 'Rejected'
  final String actorRole; // 'broker' or 'buyer'
  final String proposerName; // e.g. 'Assigned Broker Desk' or 'You (Buyer)'
  final double proposedPrice;
  final double proposedQuantity;
  final String? deliveryDate;
  final String? notes;
  final DateTime createdAt;
  final bool isCurrent;

  const NegotiationRound({
    required this.id,
    required this.versionNumber,
    required this.status,
    required this.actorRole,
    required this.proposerName,
    required this.proposedPrice,
    required this.proposedQuantity,
    this.deliveryDate,
    this.notes,
    required this.createdAt,
    this.isCurrent = false,
  });

  factory NegotiationRound.fromMap(Map<String, dynamic> map, {bool isCurrent = false}) {
    final role = map['actorRole'] as String? ?? (map['originatorRole'] as String? ?? 'broker');
    return NegotiationRound(
      id: map['id']?.toString() ?? UniqueKey().toString(),
      versionNumber: (map['versionNumber'] as num?)?.toInt() ?? (map['version_number'] as num?)?.toInt() ?? 1,
      status: map['status'] as String? ?? 'Proposed',
      actorRole: role,
      proposerName: role == 'buyer' ? 'You (Buyer Counter-Offer)' : 'Broker Desk (Commercial Proposal)',
      proposedPrice: (map['price'] as num?)?.toDouble() ??
          (map['proposedPrice'] as num?)?.toDouble() ??
          (map['offered_price'] as num?)?.toDouble() ??
          0.0,
      proposedQuantity: (map['quantity'] as num?)?.toDouble() ??
          (map['proposedQuantity'] as num?)?.toDouble() ??
          0.0,
      deliveryDate: map['deliveryDate'] as String?,
      notes: map['notes'] as String? ?? map['brokerNotes'] as String? ?? map['buyerNotes'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : (map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now()),
      isCurrent: isCurrent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'versionNumber': versionNumber,
      'status': status,
      'actorRole': actorRole,
      'proposerName': proposerName,
      'proposedPrice': proposedPrice,
      'proposedQuantity': proposedQuantity,
      'deliveryDate': deliveryDate,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'isCurrent': isCurrent,
    };
  }
}

/// Primary domain entity representing a broker-provided commercial offer for a buyer requirement.
/// Strict Counterparty Shield: Zero seller IDs, seller company names, or seller contacts exist here.
class BuyerOffer {
  final String id;
  final String requirementId;
  final String requirementDisplayId;
  final String commodityName;
  final String gradeName;
  final double offeredQuantity;
  final String unit;
  final double offeredPrice;
  final double totalEstimatedValue;
  final String status; // 'Proposed', 'Countered', 'Accepted', 'Rejected', 'Expired'
  final int versionNumber;
  final String? brokerId;
  final String brokerName;
  final String? brokerNotes;
  final DateTime? validUntil;
  final String deliveryTerms;
  final String deliveryLocation;
  final DateTime? deliveryDate;
  final String paymentTerms;
  final String packagingType;
  final String? specialConditions;
  final List<OfferChargeItem> applicableCharges;
  final List<OfferQualitySpec> qualitySpecs;
  final List<NegotiationRound> negotiationRounds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BuyerOffer({
    required this.id,
    required this.requirementId,
    required this.requirementDisplayId,
    required this.commodityName,
    required this.gradeName,
    required this.offeredQuantity,
    required this.unit,
    required this.offeredPrice,
    required this.totalEstimatedValue,
    required this.status,
    required this.versionNumber,
    this.brokerId,
    required this.brokerName,
    this.brokerNotes,
    this.validUntil,
    required this.deliveryTerms,
    required this.deliveryLocation,
    this.deliveryDate,
    required this.paymentTerms,
    required this.packagingType,
    this.specialConditions,
    this.applicableCharges = const [],
    this.qualitySpecs = const [],
    this.negotiationRounds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check whether validity period has elapsed or status is Expired.
  bool get isExpired {
    if (status.toLowerCase() == 'expired') return true;
    if (validUntil != null && DateTime.now().isAfter(validUntil!)) return true;
    return false;
  }

  /// Check whether commercial actions (Counter, Accept, Reject) are permitted.
  bool get isActionable {
    if (isExpired) return false;
    final lower = status.toLowerCase();
    return lower == 'proposed' || lower == 'sent' || lower == 'countered';
  }

  /// Whether current status is terminal.
  bool get isTerminal {
    final lower = status.toLowerCase();
    return lower == 'accepted' || lower == 'rejected' || isExpired;
  }

  factory BuyerOffer.fromMap(Map<String, dynamic> map) {
    final validUntilDate = map['validUntil'] != null
        ? DateTime.tryParse(map['validUntil'].toString())
        : (map['valid_until'] != null ? DateTime.tryParse(map['valid_until'].toString()) : null);

    final rawStatus = map['status'] as String? ?? 'Proposed';
    final isExpiredNow = validUntilDate != null && DateTime.now().isAfter(validUntilDate);
    final mappedStatus = isExpiredNow ? 'Expired' : rawStatus;

    final chargesRaw = map['applicableCharges'] as List?;
    final charges = chargesRaw != null
        ? chargesRaw.map((c) => OfferChargeItem.fromMap(c as Map<String, dynamic>)).toList()
        : <OfferChargeItem>[];

    final specsRaw = map['qualitySpecifications'] as List? ?? (map['qualitySpecs'] as List?);
    final specs = specsRaw != null
        ? specsRaw.map((s) => OfferQualitySpec.fromMap(s as Map<String, dynamic>)).toList()
        : <OfferQualitySpec>[];

    final roundsRaw = map['negotiationRounds'] as List? ?? (map['versions'] as List?);
    final rounds = roundsRaw != null
        ? roundsRaw.asMap().entries.map((entry) {
            final isLast = entry.key == roundsRaw.length - 1;
            return NegotiationRound.fromMap(entry.value as Map<String, dynamic>, isCurrent: isLast);
          }).toList()
        : <NegotiationRound>[];

    final price = (map['offeredPrice'] as num?)?.toDouble() ??
        (map['offered_price'] as num?)?.toDouble() ??
        (map['proposedPrice'] as num?)?.toDouble() ??
        0.0;

    final qty = (map['offeredQuantity'] as num?)?.toDouble() ??
        (map['proposedQuantity'] as num?)?.toDouble() ??
        (map['quantity'] as num?)?.toDouble() ??
        0.0;

    final reqId = map['requirementId'] as String? ?? (map['requirement_id'] as String? ?? '');

    return BuyerOffer(
      id: map['id']?.toString() ?? '',
      requirementId: reqId,
      requirementDisplayId: map['requirementDisplayId'] as String? ??
          (reqId.isNotEmpty ? 'REQ-${reqId.substring(0, reqId.length > 8 ? 8 : reqId.length).toUpperCase()}' : 'REQ-OFFER'),
      commodityName: map['commodityName'] as String? ?? (map['commodity_name'] as String? ?? 'Agricultural Commodity'),
      gradeName: map['gradeName'] as String? ?? (map['grade_name'] as String? ?? 'Standard Grade'),
      offeredQuantity: qty,
      unit: map['unit'] as String? ?? (map['unitSymbol'] as String? ?? 'MT'),
      offeredPrice: price,
      totalEstimatedValue: (map['totalEstimatedValue'] as num?)?.toDouble() ?? (price * qty),
      status: mappedStatus,
      versionNumber: (map['versionNumber'] as num?)?.toInt() ?? 1,
      brokerId: map['brokerId'] as String? ?? map['broker_id'] as String?,
      brokerName: map['brokerName'] as String? ?? (map['broker_name'] as String? ?? 'Assigned Broker Desk'),
      brokerNotes: map['brokerNotes'] as String? ?? map['notes'] as String?,
      validUntil: validUntilDate,
      deliveryTerms: map['deliveryTerms'] as String? ?? 'FOR Destination',
      deliveryLocation: map['deliveryLocation'] as String? ?? 'Buyer Designated Destination Mill',
      deliveryDate: map['deliveryDate'] != null ? DateTime.tryParse(map['deliveryDate'].toString()) : null,
      paymentTerms: map['paymentTerms'] as String? ?? '100% Against Delivery & Verified Weighbridge Slip',
      packagingType: map['packagingType'] as String? ?? '50kg HDPE / PP Laminated Bags',
      specialConditions: map['specialConditions'] as String?,
      applicableCharges: charges,
      qualitySpecs: specs,
      negotiationRounds: rounds,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : (map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now()),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : (map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now() : DateTime.now()),
    );
  }

  BuyerOffer copyWith({
    String? status,
    double? offeredPrice,
    double? offeredQuantity,
    int? versionNumber,
    String? brokerNotes,
    List<NegotiationRound>? negotiationRounds,
    DateTime? updatedAt,
  }) {
    return BuyerOffer(
      id: id,
      requirementId: requirementId,
      requirementDisplayId: requirementDisplayId,
      commodityName: commodityName,
      gradeName: gradeName,
      offeredQuantity: offeredQuantity ?? this.offeredQuantity,
      unit: unit,
      offeredPrice: offeredPrice ?? this.offeredPrice,
      totalEstimatedValue: (offeredPrice ?? this.offeredPrice) * (offeredQuantity ?? this.offeredQuantity),
      status: status ?? this.status,
      versionNumber: versionNumber ?? this.versionNumber,
      brokerId: brokerId,
      brokerName: brokerName,
      brokerNotes: brokerNotes ?? this.brokerNotes,
      validUntil: validUntil,
      deliveryTerms: deliveryTerms,
      deliveryLocation: deliveryLocation,
      deliveryDate: deliveryDate,
      paymentTerms: paymentTerms,
      packagingType: packagingType,
      specialConditions: specialConditions,
      applicableCharges: applicableCharges,
      qualitySpecs: qualitySpecs,
      negotiationRounds: negotiationRounds ?? this.negotiationRounds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
