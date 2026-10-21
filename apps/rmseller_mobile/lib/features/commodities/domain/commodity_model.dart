/// Domain entity representing a commodity supply lot/availability listed by the Seller.
class SellerCommodity {
  final String id;
  final String lotNumber;
  final String commodityName;
  final String gradeName;
  final double totalQuantity;
  final double availableQuantity;
  final double reservedQuantity;
  final double soldQuantity;
  final String unit;
  final double askingPrice;
  final double? confidentialMinimumPrice;
  final String stateName;
  final String districtName;
  final String loadingStatus;
  final String status; // 'Open', 'Active', 'Reserved', 'Fulfilled', 'Expired', 'Cancelled'
  final DateTime availableFrom;
  final DateTime validUntil;
  final String? brokerId;
  final String? brokerName;
  final String? brokerPhone;
  final String? brokerLocation;
  final String? commodityId;
  final String? gradeId;
  final String? unitId;
  final String? stateId;
  final String? districtId;
  final String? paymentTerms;
  final String? officeLocation;
  final String? warehouseName;
  final String? mandiName;
  final String? loadingRemarks;
  final String? labReportNumber;
  final String? labName;
  final String? labReportFileUrl;
  final String? labReportFileName;
  final int version;
  final DateTime createdAt;

  const SellerCommodity({
    required this.id,
    required this.lotNumber,
    required this.commodityName,
    required this.gradeName,
    required this.totalQuantity,
    required this.availableQuantity,
    this.reservedQuantity = 0.0,
    this.soldQuantity = 0.0,
    required this.unit,
    required this.askingPrice,
    this.confidentialMinimumPrice,
    required this.stateName,
    required this.districtName,
    this.loadingStatus = 'Ready to Load',
    required this.status,
    required this.availableFrom,
    required this.validUntil,
    this.brokerId,
    this.brokerName,
    this.brokerPhone,
    this.brokerLocation,
    this.commodityId,
    this.gradeId,
    this.unitId,
    this.stateId,
    this.districtId,
    this.paymentTerms = 'Payment on Delivery (CAD)',
    this.officeLocation = 'Bikaner Commercial Head Office',
    this.warehouseName = 'Krishi Upaj Mandi Yard Warehouse A-4',
    this.mandiName = 'Bikaner Krishi Upaj Mandi (Grain Market)',
    this.loadingRemarks,
    this.labReportNumber,
    this.labName,
    this.labReportFileUrl,
    this.labReportFileName,
    this.version = 1,
    required this.createdAt,
  });

  bool get isActive => status.toLowerCase() == 'open' || status.toLowerCase() == 'active';
  bool get isExpired => DateTime.now().isAfter(validUntil) || status.toLowerCase() == 'expired';
  bool get isDirectBrokerMandate => brokerId != null && brokerId!.isNotEmpty;
  double get totalEstimatedValue => totalQuantity * askingPrice;
  double get availableEstimatedValue => availableQuantity * askingPrice;

  // Convenience aliases
  String? get assignedBrokerId => brokerId;
  String? get assignedBrokerName => brokerName;
  String get name => commodityName;
  double get quantityTotal => totalQuantity;

  factory SellerCommodity.fromMap(Map<String, dynamic> map) {
    return SellerCommodity(
      id: map['id']?.toString() ?? '',
      lotNumber: map['lot_number'] as String? ?? 'LOT-${(map['id']?.toString() ?? '000').substring(0, 5).toUpperCase()}',
      commodityName: (map['commodity_name'] as String?) ??
          (map['commodityName'] as String?) ??
          'Agricultural Commodity',
      gradeName: (map['grade_name'] as String?) ??
          (map['gradeName'] as String?) ??
          'Standard Grade FAQ',
      totalQuantity: (map['total_quantity'] as num?)?.toDouble() ??
          (map['quantity'] as num?)?.toDouble() ??
          0.0,
      availableQuantity: (map['available_quantity'] as num?)?.toDouble() ??
          (map['quantity'] as num?)?.toDouble() ??
          0.0,
      reservedQuantity: (map['reserved_quantity'] as num?)?.toDouble() ?? 0.0,
      soldQuantity: (map['sold_quantity'] as num?)?.toDouble() ?? 0.0,
      unit: (map['unit'] as String?) ?? 'MT',
      askingPrice: (map['asking_price'] as num?)?.toDouble() ??
          (map['price'] as num?)?.toDouble() ??
          0.0,
      confidentialMinimumPrice: (map['confidential_minimum_price'] as num?)?.toDouble(),
      stateName: (map['state_name'] as String?) ?? 'Rajasthan',
      districtName: (map['district_name'] as String?) ?? 'Bikaner',
      loadingStatus: (map['loading_status'] as String?) ?? 'Ready to Load',
      status: map['status'] as String? ?? 'Open',
      availableFrom: map['available_from'] != null
          ? DateTime.tryParse(map['available_from'].toString()) ?? DateTime.now()
          : DateTime.now(),
      validUntil: map['valid_until'] != null
          ? DateTime.tryParse(map['valid_until'].toString()) ?? DateTime.now().add(const Duration(days: 7))
          : DateTime.now().add(const Duration(days: 7)),
      brokerId: map['broker_id'] as String?,
      brokerName: map['broker_name'] as String? ??
          (map['broker_id'] != null ? 'Assigned Mandi Broker Desk' : null),
      brokerPhone: map['broker_phone'] as String?,
      brokerLocation: map['broker_location'] as String?,
      commodityId: map['commodity_id'] as String?,
      gradeId: map['grade_id'] as String?,
      unitId: map['unit_id'] as String?,
      stateId: map['state_id'] as String?,
      districtId: map['district_id'] as String?,
      paymentTerms: map['payment_terms'] as String? ?? 'Payment on Delivery (CAD)',
      officeLocation: map['office_location'] as String? ?? 'Bikaner Commercial Head Office',
      warehouseName: map['warehouse_name'] as String? ?? 'Krishi Upaj Mandi Yard Warehouse A-4',
      mandiName: map['mandi_name'] as String? ?? 'Bikaner Krishi Upaj Mandi (Grain Market)',
      loadingRemarks: map['loading_remarks'] as String?,
      labReportNumber: map['lab_report_number'] as String?,
      labName: map['lab_name'] as String?,
      labReportFileUrl: map['lab_report_file_url'] as String?,
      labReportFileName: map['lab_report_file_name'] as String?,
      version: (map['version'] as num?)?.toInt() ?? 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lot_number': lotNumber,
      'commodity_name': commodityName,
      'grade_name': gradeName,
      'total_quantity': totalQuantity,
      'available_quantity': availableQuantity,
      'reserved_quantity': reservedQuantity,
      'sold_quantity': soldQuantity,
      'unit': unit,
      'asking_price': askingPrice,
      'confidential_minimum_price': confidentialMinimumPrice,
      'state_name': stateName,
      'district_name': districtName,
      'loading_status': loadingStatus,
      'status': status,
      'available_from': availableFrom.toIso8601String(),
      'valid_until': validUntil.toIso8601String(),
      'broker_id': brokerId,
      'broker_name': brokerName,
      'broker_phone': brokerPhone,
      'broker_location': brokerLocation,
      'payment_terms': paymentTerms,
      'office_location': officeLocation,
      'warehouse_name': warehouseName,
      'mandi_name': mandiName,
      'loading_remarks': loadingRemarks,
      'lab_report_number': labReportNumber,
      'lab_name': labName,
      'lab_report_file_url': labReportFileUrl,
      'lab_report_file_name': labReportFileName,
      'version': version,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SellerCommodity copyWith({
    String? id,
    String? lotNumber,
    String? commodityName,
    String? gradeName,
    double? totalQuantity,
    double? availableQuantity,
    double? reservedQuantity,
    double? soldQuantity,
    String? unit,
    double? askingPrice,
    double? confidentialMinimumPrice,
    String? stateName,
    String? districtName,
    String? loadingStatus,
    String? status,
    DateTime? availableFrom,
    DateTime? validUntil,
    String? brokerId,
    String? brokerName,
    String? brokerPhone,
    String? brokerLocation,
    String? commodityId,
    String? gradeId,
    String? unitId,
    String? stateId,
    String? districtId,
    String? paymentTerms,
    String? officeLocation,
    String? warehouseName,
    String? mandiName,
    String? loadingRemarks,
    String? labReportNumber,
    String? labName,
    String? labReportFileUrl,
    String? labReportFileName,
    int? version,
    DateTime? createdAt,
  }) {
    return SellerCommodity(
      id: id ?? this.id,
      lotNumber: lotNumber ?? this.lotNumber,
      commodityName: commodityName ?? this.commodityName,
      gradeName: gradeName ?? this.gradeName,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
      soldQuantity: soldQuantity ?? this.soldQuantity,
      unit: unit ?? this.unit,
      askingPrice: askingPrice ?? this.askingPrice,
      confidentialMinimumPrice: confidentialMinimumPrice ?? this.confidentialMinimumPrice,
      stateName: stateName ?? this.stateName,
      districtName: districtName ?? this.districtName,
      loadingStatus: loadingStatus ?? this.loadingStatus,
      status: status ?? this.status,
      availableFrom: availableFrom ?? this.availableFrom,
      validUntil: validUntil ?? this.validUntil,
      brokerId: brokerId ?? this.brokerId,
      brokerName: brokerName ?? this.brokerName,
      brokerPhone: brokerPhone ?? this.brokerPhone,
      brokerLocation: brokerLocation ?? this.brokerLocation,
      commodityId: commodityId ?? this.commodityId,
      gradeId: gradeId ?? this.gradeId,
      unitId: unitId ?? this.unitId,
      stateId: stateId ?? this.stateId,
      districtId: districtId ?? this.districtId,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      officeLocation: officeLocation ?? this.officeLocation,
      warehouseName: warehouseName ?? this.warehouseName,
      mandiName: mandiName ?? this.mandiName,
      loadingRemarks: loadingRemarks ?? this.loadingRemarks,
      labReportNumber: labReportNumber ?? this.labReportNumber,
      labName: labName ?? this.labName,
      labReportFileUrl: labReportFileUrl ?? this.labReportFileUrl,
      labReportFileName: labReportFileName ?? this.labReportFileName,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// DTO for creating a new commodity lot listing.
class CreateCommodityDto {
  final String commodityId;
  final String commodityName;
  final String gradeId;
  final String gradeName;
  final String lotNumber;
  final double totalQuantity;
  final String unitId;
  final String unitSymbol;
  final double askingPrice;
  final double? confidentialMinimumPrice;
  final String stateId;
  final String stateName;
  final String districtId;
  final String districtName;
  final String loadingStatus;
  final DateTime availableFrom;
  final DateTime validUntil;
  final String visibility; // 'global' or 'restricted'
  final String? brokerId;
  final String? brokerName;
  final String? brokerPhone;
  final String? brokerLocation;
  final List<String> selectedBrokerIds;
  final String paymentTerms;
  final String officeLocation;
  final String? warehouseName;
  final String? mandiName;
  final String? loadingRemarks;
  final String? labReportNumber;
  final String? labName;
  final String? labReportFileUrl;
  final String? labReportFileName;

  const CreateCommodityDto({
    required this.commodityId,
    required this.commodityName,
    required this.gradeId,
    required this.gradeName,
    required this.lotNumber,
    required this.totalQuantity,
    required this.unitId,
    required this.unitSymbol,
    required this.askingPrice,
    this.confidentialMinimumPrice,
    required this.stateId,
    required this.stateName,
    required this.districtId,
    required this.districtName,
    this.loadingStatus = 'Ready to Load',
    required this.availableFrom,
    required this.validUntil,
    this.visibility = 'global',
    this.brokerId,
    this.brokerName,
    this.brokerPhone,
    this.brokerLocation,
    this.selectedBrokerIds = const [],
    this.paymentTerms = 'Payment on Delivery (CAD)',
    this.officeLocation = 'Bikaner Commercial Head Office',
    this.warehouseName = 'Krishi Upaj Mandi Yard Warehouse A-4',
    this.mandiName = 'Bikaner Krishi Upaj Mandi (Grain Market)',
    this.loadingRemarks,
    this.labReportNumber,
    this.labName,
    this.labReportFileUrl,
    this.labReportFileName,
  });

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isValidUuid(String? id) {
    if (id == null) return false;
    return _uuidRegex.hasMatch(id.trim());
  }

  Map<String, dynamic> toSupabaseInsert(String companyId) {
    final effectiveBrokerId = brokerId ??
        (selectedBrokerIds.isNotEmpty ? selectedBrokerIds.first : null);

    final cleanBrokerId = (effectiveBrokerId != null && isValidUuid(effectiveBrokerId))
        ? effectiveBrokerId.trim()
        : null;

    return {
      'company_id': companyId,
      'commodity_id': commodityId,
      'grade_id': gradeId,
      'quantity': totalQuantity.toInt(), // integer column in schema
      'unit_id': unitId,
      'price': askingPrice.toString(), // numeric column in schema
      'state_id': stateId,
      'district_id': districtId,
      'visibility': visibility,
      'status': 'Open',
      'lot_number': lotNumber.trim(),
      'total_quantity': totalQuantity.toString(),
      'available_quantity': totalQuantity.toString(),
      'reserved_quantity': '0',
      'sold_quantity': '0',
      'asking_price': askingPrice.toString(),
      if (confidentialMinimumPrice != null)
        'confidential_minimum_price': confidentialMinimumPrice!.toString(),
      'available_from': availableFrom.toIso8601String(),
      'valid_until': validUntil.toIso8601String(),
      'loading_status': loadingStatus,
      if (loadingRemarks != null && loadingRemarks!.isNotEmpty)
        'loading_remarks': loadingRemarks,
      'version': 1,
      if (cleanBrokerId != null) 'broker_id': cleanBrokerId,
    };
  }
}
