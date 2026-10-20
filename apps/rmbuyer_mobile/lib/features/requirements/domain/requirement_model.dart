/// Domain entity representing a commodity requirement posted by the buyer.
class BuyerRequirement {
  final String id;
  final String commodityName;
  final String gradeName;
  final double quantity;
  final String unit;
  final double targetPrice;
  final String status;
  final DateTime targetDate;
  final String? deliveryTerms;
  final String? brokerName;

  // Extended requirement fields
  final String? commodityId;
  final String? gradeId;
  final String? unitId;
  final String? brokerId;
  final String? paymentTerms;
  final String? packagingType;
  final String? notes;
  final double fulfilledQuantity;
  final DateTime? createdAt;

  const BuyerRequirement({
    required this.id,
    required this.commodityName,
    required this.gradeName,
    required this.quantity,
    required this.unit,
    required this.targetPrice,
    required this.status,
    required this.targetDate,
    this.deliveryTerms,
    this.brokerName,
    this.commodityId,
    this.gradeId,
    this.unitId,
    this.brokerId,
    this.paymentTerms,
    this.packagingType,
    this.notes,
    this.fulfilledQuantity = 0.0,
    this.createdAt,
  });

  bool get canCancel => status.toLowerCase() == 'open';
  bool get isDirectBrokerMandate => brokerId != null && brokerId!.isNotEmpty;
  double get totalEstimatedValue => quantity * targetPrice;

  factory BuyerRequirement.fromMap(Map<String, dynamic> map) {
    return BuyerRequirement(
      id: map['id']?.toString() ?? '',
      commodityName: (map['commodity_name'] as String?) ??
          (map['commodityName'] as String?) ??
          'Agricultural Commodity',
      gradeName: (map['grade_name'] as String?) ??
          (map['gradeName'] as String?) ??
          'Standard Grade',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'MT',
      targetPrice: (map['target_price'] as num?)?.toDouble() ??
          (map['targetPrice'] as num?)?.toDouble() ??
          0.0,
      status: map['status'] as String? ?? 'Open',
      targetDate: map['target_date'] != null
          ? DateTime.tryParse(map['target_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      deliveryTerms: map['delivery_terms_id'] as String? ?? map['deliveryTerms'] as String?,
      brokerName: map['broker_name'] as String? ?? map['brokerName'] as String?,
      commodityId: map['commodity_id'] as String?,
      gradeId: map['grade_id'] as String?,
      unitId: map['unit_id'] as String?,
      brokerId: map['broker_id'] as String?,
      paymentTerms: map['payment_terms'] as String? ?? map['paymentTerms'] as String?,
      packagingType: map['packaging_type'] as String? ?? map['packagingType'] as String?,
      notes: map['notes'] as String?,
      fulfilledQuantity: (map['fulfilled_quantity'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    // Strictly exclude any seller identities, seller contacts, or counterparty leaks
    return {
      'id': id,
      'commodity_name': commodityName,
      'grade_name': gradeName,
      'quantity': quantity,
      'unit': unit,
      'target_price': targetPrice,
      'status': status,
      'target_date': targetDate.toIso8601String(),
      'delivery_terms': deliveryTerms,
      'broker_name': brokerName,
      if (commodityId != null) 'commodity_id': commodityId,
      if (gradeId != null) 'grade_id': gradeId,
      if (unitId != null) 'unit_id': unitId,
      if (brokerId != null) 'broker_id': brokerId,
      if (paymentTerms != null) 'payment_terms': paymentTerms,
      if (packagingType != null) 'packaging_type': packagingType,
      if (notes != null) 'notes': notes,
      'fulfilled_quantity': fulfilledQuantity,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

/// Data transfer object for drafting and submitting a new buyer procurement requirement.
class CreateRequirementDto {
  final String commodityId;
  final String commodityName;
  final String gradeId;
  final String gradeName;
  final double quantity;
  final String unitId;
  final String unitSymbol;
  final double targetPrice;
  final String deliveryLocation;
  final DateTime targetDate;
  final String paymentTerms;
  final String? packagingType;
  final String? notes;
  final String visibility; // 'global' or 'restricted'
  final String? brokerId;
  final String? brokerName;
  final List<String> selectedBrokerIds;
  final List<String> selectedBrokerNames;

  const CreateRequirementDto({
    required this.commodityId,
    required this.commodityName,
    required this.gradeId,
    required this.gradeName,
    required this.quantity,
    required this.unitId,
    required this.unitSymbol,
    required this.targetPrice,
    required this.deliveryLocation,
    required this.targetDate,
    required this.paymentTerms,
    this.packagingType,
    this.notes,
    this.visibility = 'global',
    this.brokerId,
    this.brokerName,
    this.selectedBrokerIds = const [],
    this.selectedBrokerNames = const [],
  });

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Validates whether a given string is a valid RFC-4122 UUID format.
  static bool isValidUuid(String? id) {
    if (id == null) return false;
    return _uuidRegex.hasMatch(id.trim());
  }

  Map<String, dynamic> toSupabaseInsert(String companyId) {
    final effectiveBrokerId = brokerId ??
        (selectedBrokerIds.isNotEmpty ? selectedBrokerIds.first : null);

    // Defensive check: Only pass valid UUIDs to PostgreSQL to prevent 22P02 syntax exceptions
    final cleanBrokerId = (effectiveBrokerId != null && isValidUuid(effectiveBrokerId))
        ? effectiveBrokerId.trim()
        : null;

    return {
      'company_id': companyId,
      'commodity_id': commodityId,
      'grade_id': gradeId,
      'quantity': quantity,
      'unit_id': unitId,
      'target_price': targetPrice,
      'delivery_terms_id': deliveryLocation,
      'target_date': targetDate.toIso8601String(),
      'status': 'Open',
      'fulfilled_quantity': 0,
      'visibility': visibility,
      if (cleanBrokerId != null) // ignore: use_null_aware_elements
        'broker_id': cleanBrokerId,
    };
  }
}
