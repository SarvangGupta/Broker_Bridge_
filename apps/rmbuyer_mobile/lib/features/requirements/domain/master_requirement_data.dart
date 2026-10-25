/// Master reference data entities and verified defaults for buyer commodity requirements.
library;

class MasterCommodity {
  final String id;
  final String name;
  final String code;
  final bool status;

  /// Authoritative category name from `master_categories`; null when unavailable.
  final String? categoryName;

  /// `master_commodities.category_id`; null when the product has no category.
  final String? categoryId;

  const MasterCommodity({
    required this.id,
    required this.name,
    required this.code,
    this.status = true,
    this.categoryName,
    this.categoryId,
  });

  factory MasterCommodity.fromMap(Map<String, dynamic> map, {String? categoryName}) {
    return MasterCommodity(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Agricultural Commodity',
      code: map['code']?.toString() ?? '',
      status: map['status'] as bool? ?? true,
      categoryName: categoryName,
      categoryId: map['category_id']?.toString(),
    );
  }
}

/// An active parent category from `master_categories`.
class MasterCategory {
  final String id;
  final String name;

  const MasterCategory({required this.id, required this.name});
}

class MasterGrade {
  final String id;
  final String commodityId;
  final String gradeName;
  final Map<String, dynamic>? parameters;

  const MasterGrade({
    required this.id,
    required this.commodityId,
    required this.gradeName,
    this.parameters,
  });

  factory MasterGrade.fromMap(Map<String, dynamic> map) {
    return MasterGrade(
      id: map['id']?.toString() ?? '',
      commodityId: map['commodity_id']?.toString() ?? '',
      gradeName: map['grade_name']?.toString() ?? 'Standard Grade',
      parameters: map['parameters'] as Map<String, dynamic>?,
    );
  }
}

class MasterUnit {
  final String id;
  final String name;
  final String symbol;

  const MasterUnit({
    required this.id,
    required this.name,
    required this.symbol,
  });

  factory MasterUnit.fromMap(Map<String, dynamic> map) {
    return MasterUnit(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Metric Ton',
      symbol: map['symbol']?.toString() ?? 'MT',
    );
  }
}

/// Verified baseline reference data aligned with Supabase seed and master tables.
///
/// Commodities and grades are intentionally absent: the selectable catalogue and
/// each product's grades always come from the live shared Product Master
/// (see `RequirementsRepository.getMasterCommodities` / `getMasterGrades`).
class MasterRequirementData {
  static const List<MasterUnit> verifiedUnits = [
    MasterUnit(
      id: '22000000-0000-0000-0000-000000000001',
      name: 'Metric Ton',
      symbol: 'MT',
    ),
    MasterUnit(
      id: '22000000-0000-0000-0000-000000000002',
      name: 'Quintal',
      symbol: 'Qtl',
    ),
  ];

  static const List<String> verifiedLocations = [
    'FOR Mill Delivery, Kota Mandi',
    'FOR Factory Depot, Indore',
    'Ex-Warehouse Jaipur Central Depot',
    'FOR Warehouse Baran Mandi',
    'FOR Mill Delivery, Ujjain Mandi',
    'FOR Processing Plant, Alwar',
  ];

  static const List<String> verifiedPaymentTerms = [
    'Payment on Delivery (CAD)',
    'Advance Payment (100%)',
    '7 Days Net Credit',
    '15 Days Net Credit',
    '30 Days Net Credit',
    'Custom Commercial Terms',
  ];
}
