/// Master reference data entities and verified defaults for buyer commodity requirements.
library;

class MasterCommodity {
  final String id;
  final String name;
  final String code;
  final bool status;

  const MasterCommodity({
    required this.id,
    required this.name,
    required this.code,
    this.status = true,
  });

  factory MasterCommodity.fromMap(Map<String, dynamic> map) {
    return MasterCommodity(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Agricultural Commodity',
      code: map['code']?.toString() ?? '',
      status: map['status'] as bool? ?? true,
    );
  }
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
class MasterRequirementData {
  static const List<MasterCommodity> verifiedCommodities = [
    MasterCommodity(
      id: '20000000-0000-0000-0000-000000000001',
      name: 'Yellow Maize (Corn)',
      code: 'MAIZE-01',
    ),
    MasterCommodity(
      id: '20000000-0000-0000-0000-000000000002',
      name: 'Sharbati Wheat',
      code: 'WHEAT-01',
    ),
    MasterCommodity(
      id: '20000000-0000-0000-0000-000000000003',
      name: 'Soybean Seed',
      code: 'SOY-01',
    ),
    MasterCommodity(
      id: '20000000-0000-0000-0000-000000000004',
      name: 'Mustard Seeds',
      code: 'MUSTARD-01',
    ),
    MasterCommodity(
      id: '20000000-0000-0000-0000-000000000005',
      name: 'Desi Chana (Gram)',
      code: 'CHANA-01',
    ),
  ];

  static const List<MasterGrade> verifiedGrades = [
    MasterGrade(
      id: '21000000-0000-0000-0000-000000000001',
      commodityId: '20000000-0000-0000-0000-000000000001',
      gradeName: 'Grade A Milling',
    ),
    MasterGrade(
      id: '21000000-0000-0000-0000-000000000002',
      commodityId: '20000000-0000-0000-0000-000000000001',
      gradeName: 'Feed Grade Premium',
    ),
    MasterGrade(
      id: '21000000-0000-0000-0000-000000000003',
      commodityId: '20000000-0000-0000-0000-000000000002',
      gradeName: 'Premium Sharbati',
    ),
    MasterGrade(
      id: '21000000-0000-0000-0000-000000000004',
      commodityId: '20000000-0000-0000-0000-000000000003',
      gradeName: 'Standard Mandi Grade',
    ),
    MasterGrade(
      id: '21000000-0000-0000-0000-000000000005',
      commodityId: '20000000-0000-0000-0000-000000000004',
      gradeName: 'High Oil 42%',
    ),
    MasterGrade(
      id: '21000000-0000-0000-0000-000000000006',
      commodityId: '20000000-0000-0000-0000-000000000005',
      gradeName: 'Standard Mandi FAQ',
    ),
  ];

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
