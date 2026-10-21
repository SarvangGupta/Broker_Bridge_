/// Master Reference Data entities matching the PostgreSQL database schema.

class MasterCommodity {
  final String id;
  final String name;
  final String code;

  const MasterCommodity({
    required this.id,
    required this.name,
    required this.code,
  });

  factory MasterCommodity.fromMap(Map<String, dynamic> map) {
    return MasterCommodity(
      id: map['id']?.toString() ?? '',
      name: map['name'] as String? ?? 'Agricultural Commodity',
      code: map['code'] as String? ?? 'AGRI',
    );
  }
}

class MasterGrade {
  final String id;
  final String commodityId;
  final String gradeName;
  final dynamic parameters;

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
      gradeName: map['grade_name'] as String? ?? 'FAQ Standard',
      parameters: map['parameters'],
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
      name: map['name'] as String? ?? 'Metric Ton',
      symbol: map['symbol'] as String? ?? 'MT',
    );
  }
}

class MasterState {
  final String id;
  final String name;
  final String code;

  const MasterState({
    required this.id,
    required this.name,
    required this.code,
  });

  factory MasterState.fromMap(Map<String, dynamic> map) {
    return MasterState(
      id: map['id']?.toString() ?? '',
      name: map['name'] as String? ?? 'State',
      code: map['code'] as String? ?? 'IN',
    );
  }
}

class MasterDistrict {
  final String id;
  final String stateId;
  final String name;

  const MasterDistrict({
    required this.id,
    required this.stateId,
    required this.name,
  });

  factory MasterDistrict.fromMap(Map<String, dynamic> map) {
    return MasterDistrict(
      id: map['id']?.toString() ?? '',
      stateId: map['state_id']?.toString() ?? '',
      name: map['name'] as String? ?? 'Mandi District',
    );
  }
}

class MasterMandi {
  final String id;
  final String districtId;
  final String stateId;
  final String name;
  final String yardType;

  const MasterMandi({
    required this.id,
    required this.districtId,
    required this.stateId,
    required this.name,
    this.yardType = 'Principal APMC Yard',
  });

  factory MasterMandi.fromMap(Map<String, dynamic> map) {
    return MasterMandi(
      id: map['id']?.toString() ?? '',
      districtId: map['district_id']?.toString() ?? '',
      stateId: map['state_id']?.toString() ?? '',
      name: map['name'] as String? ?? 'Mandi Yard',
      yardType: map['yard_type'] as String? ?? 'Principal APMC Yard',
    );
  }
}

/// Verified fallback reference catalogs matching platform master seeds.
class MasterCommodityData {
  const MasterCommodityData._();

  static const List<MasterCommodity> verifiedCommodities = [
    MasterCommodity(
      id: '10000000-0000-0000-0000-000000000001',
      name: 'Yellow Soybean',
      code: 'SOY-YEL',
    ),
    MasterCommodity(
      id: '10000000-0000-0000-0000-000000000002',
      name: 'Desi Chana (Gram)',
      code: 'CHANA-DESI',
    ),
    MasterCommodity(
      id: '10000000-0000-0000-0000-000000000003',
      name: 'Mustard Seeds',
      code: 'MUSTARD',
    ),
    MasterCommodity(
      id: '10000000-0000-0000-0000-000000000004',
      name: 'Wheat (Sharbati & Mill Quality)',
      code: 'WHEAT',
    ),
  ];

  static const List<MasterGrade> verifiedGrades = [
    MasterGrade(
      id: '20000000-0000-0000-0000-000000000001',
      commodityId: '10000000-0000-0000-0000-000000000001',
      gradeName: 'Grade A FAQ (Moisture < 10%, Foreign Matter < 2%)',
    ),
    MasterGrade(
      id: '20000000-0000-0000-0000-000000000002',
      commodityId: '10000000-0000-0000-0000-000000000001',
      gradeName: 'Industrial Processing Grade (Oil > 18%)',
    ),
    MasterGrade(
      id: '20000000-0000-0000-0000-000000000003',
      commodityId: '10000000-0000-0000-0000-000000000002',
      gradeName: 'Bold Size FAQ (Count 60-65)',
    ),
    MasterGrade(
      id: '20000000-0000-0000-0000-000000000004',
      commodityId: '10000000-0000-0000-0000-000000000002',
      gradeName: 'Standard Mandi FAQ (Medium)',
    ),
    MasterGrade(
      id: '20000000-0000-0000-0000-000000000005',
      commodityId: '10000000-0000-0000-0000-000000000003',
      gradeName: 'High Oil Content (42% Oil)',
    ),
    MasterGrade(
      id: '20000000-0000-0000-0000-000000000006',
      commodityId: '10000000-0000-0000-0000-000000000004',
      gradeName: 'Sharbati Premium Grade 1',
    ),
  ];

  static const List<MasterUnit> verifiedUnits = [
    MasterUnit(
      id: '30000000-0000-0000-0000-000000000001',
      name: 'Metric Ton',
      symbol: 'MT',
    ),
    MasterUnit(
      id: '30000000-0000-0000-0000-000000000002',
      name: 'Quintal (100 kg)',
      symbol: 'QTL',
    ),
    MasterUnit(
      id: '30000000-0000-0000-0000-000000000003',
      name: 'Kilogram',
      symbol: 'KG',
    ),
  ];

  static const List<MasterState> verifiedStates = [
    MasterState(
      id: '40000000-0000-0000-0000-000000000001',
      name: 'Rajasthan',
      code: 'RJ',
    ),
    MasterState(
      id: '40000000-0000-0000-0000-000000000002',
      name: 'Madhya Pradesh',
      code: 'MP',
    ),
    MasterState(
      id: '40000000-0000-0000-0000-000000000003',
      name: 'Gujarat',
      code: 'GJ',
    ),
    MasterState(
      id: '40000000-0000-0000-0000-000000000004',
      name: 'Maharashtra',
      code: 'MH',
    ),
  ];

  static const List<MasterDistrict> verifiedDistricts = [
    // Rajasthan (RJ)
    MasterDistrict(
      id: '50000000-0000-0000-0000-000000000001',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Bikaner Mandi Hub',
    ),
    MasterDistrict(
      id: '50000000-0000-0000-0000-000000000002',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Jaipur Central Depot',
    ),
    MasterDistrict(
      id: '50000000-0000-0000-0000-000000000003',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Kota Agro Mandi',
    ),
    MasterDistrict(
      id: '50000000-0000-0000-0000-000000000006',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Baran District',
    ),
    MasterDistrict(
      id: '50000000-0000-0000-0000-000000000007',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Jodhpur District',
    ),
    MasterDistrict(
      id: '50000000-0000-0000-0000-000000000008',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Sri Ganganagar District',
    ),

    // Madhya Pradesh (MP)
    MasterDistrict(
      id: '50000000-0000-0000-0000-000000000004',
      stateId: '40000000-0000-0000-0000-000000000002',
      name: 'Indore Mandi Complex',
    ),
    MasterDistrict(
      id: '50000000-0000-0000-0000-000000000005',
      stateId: '40000000-0000-0000-0000-000000000002',
      name: 'Ujjain Grain Yard',
    ),
    MasterDistrict(
      id: '50000000-0000-0000-0000-000000000009',
      stateId: '40000000-0000-0000-0000-000000000002',
      name: 'Dewas District',
    ),

    // Gujarat (GJ)
    MasterDistrict(
      id: '50000000-0000-0000-0000-000000000010',
      stateId: '40000000-0000-0000-0000-000000000003',
      name: 'Rajkot District',
    ),
    MasterDistrict(
      id: '50000000-0000-0000-0000-000000000011',
      stateId: '40000000-0000-0000-0000-000000000003',
      name: 'Unjha / Mehsana District',
    ),
    MasterDistrict(
      id: '50000000-0000-0000-0000-000000000012',
      stateId: '40000000-0000-0000-0000-000000000003',
      name: 'Ahmedabad District',
    ),

    // Maharashtra (MH)
    MasterDistrict(
      id: '50000000-0000-0000-0000-000000000013',
      stateId: '40000000-0000-0000-0000-000000000004',
      name: 'Nagpur District',
    ),
    MasterDistrict(
      id: '50000000-0000-0000-0000-000000000014',
      stateId: '40000000-0000-0000-0000-000000000004',
      name: 'Akola District',
    ),
    MasterDistrict(
      id: '50000000-0000-0000-0000-000000000015',
      stateId: '40000000-0000-0000-0000-000000000004',
      name: 'Latur District',
    ),
  ];

  static const List<MasterMandi> verifiedMandis = [
    // Bikaner District
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000001',
      districtId: '50000000-0000-0000-0000-000000000001',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Bikaner Krishi Upaj Mandi (Grain Market)',
      yardType: 'Principal APMC Yard',
    ),
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000002',
      districtId: '50000000-0000-0000-0000-000000000001',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Nokha Mandi Yard',
      yardType: 'APMC Sub-Yard',
    ),
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000003',
      districtId: '50000000-0000-0000-0000-000000000001',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Sri Dungargarh Mandi',
      yardType: 'APMC Sub-Yard',
    ),

    // Jaipur District
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000004',
      districtId: '50000000-0000-0000-0000-000000000002',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Jaipur Surajpole Mandi Yard',
      yardType: 'Principal APMC Yard',
    ),
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000005',
      districtId: '50000000-0000-0000-0000-000000000002',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Muhana Terminal Mandi',
      yardType: 'Terminal Agro Market',
    ),
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000006',
      districtId: '50000000-0000-0000-0000-000000000002',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Chomu Agro Mandi',
      yardType: 'APMC Sub-Yard',
    ),

    // Kota District
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000007',
      districtId: '50000000-0000-0000-0000-000000000003',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Kota Bhamashah Krishi Upaj Mandi',
      yardType: 'Principal APMC Yard',
    ),
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000008',
      districtId: '50000000-0000-0000-0000-000000000003',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Ramganj Mandi Yard',
      yardType: 'APMC Sub-Yard',
    ),

    // Baran District
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000009',
      districtId: '50000000-0000-0000-0000-000000000006',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Baran Krishi Upaj Mandi',
      yardType: 'Principal APMC Yard',
    ),
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000010',
      districtId: '50000000-0000-0000-0000-000000000006',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Atru Mandi Yard',
      yardType: 'APMC Sub-Yard',
    ),

    // Jodhpur District
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000011',
      districtId: '50000000-0000-0000-0000-000000000007',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Jodhpur Mandi Yard (Bhagat Ki Kothi)',
      yardType: 'Principal APMC Yard',
    ),

    // Sri Ganganagar District
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000012',
      districtId: '50000000-0000-0000-0000-000000000008',
      stateId: '40000000-0000-0000-0000-000000000001',
      name: 'Sri Ganganagar Grain Mandi',
      yardType: 'Principal APMC Yard',
    ),

    // Indore District
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000013',
      districtId: '50000000-0000-0000-0000-000000000004',
      stateId: '40000000-0000-0000-0000-000000000002',
      name: 'Indore Choithram Mandi Yard',
      yardType: 'Principal APMC Yard',
    ),
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000014',
      districtId: '50000000-0000-0000-0000-000000000004',
      stateId: '40000000-0000-0000-0000-000000000002',
      name: 'Laxmibai Nagar Mandi',
      yardType: 'Grain Sub-Yard',
    ),

    // Ujjain District
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000015',
      districtId: '50000000-0000-0000-0000-000000000005',
      stateId: '40000000-0000-0000-0000-000000000002',
      name: 'Ujjain Chimanganj Mandi Yard',
      yardType: 'Principal APMC Yard',
    ),

    // Dewas District
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000016',
      districtId: '50000000-0000-0000-0000-000000000009',
      stateId: '40000000-0000-0000-0000-000000000002',
      name: 'Dewas Krishi Upaj Mandi',
      yardType: 'Principal APMC Yard',
    ),

    // Rajkot District
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000017',
      districtId: '50000000-0000-0000-0000-000000000010',
      stateId: '40000000-0000-0000-0000-000000000003',
      name: 'Rajkot Bedi Yard APMC Mandi',
      yardType: 'Principal APMC Yard',
    ),
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000018',
      districtId: '50000000-0000-0000-0000-000000000010',
      stateId: '40000000-0000-0000-0000-000000000003',
      name: 'Gondal APMC Mandi',
      yardType: 'APMC Sub-Yard',
    ),

    // Unjha / Mehsana District
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000019',
      districtId: '50000000-0000-0000-0000-000000000011',
      stateId: '40000000-0000-0000-0000-000000000003',
      name: 'Unjha APMC Spices & Grain Mandi',
      yardType: 'National Benchmark APMC',
    ),

    // Ahmedabad District
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000020',
      districtId: '50000000-0000-0000-0000-000000000012',
      stateId: '40000000-0000-0000-0000-000000000003',
      name: 'Ahmedabad APMC Market Yard (Vasna)',
      yardType: 'Principal APMC Yard',
    ),

    // Nagpur District
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000021',
      districtId: '50000000-0000-0000-0000-000000000013',
      stateId: '40000000-0000-0000-0000-000000000004',
      name: 'Nagpur Kalamna Market Yard (APMC)',
      yardType: 'Principal APMC Yard',
    ),

    // Akola District
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000022',
      districtId: '50000000-0000-0000-0000-000000000014',
      stateId: '40000000-0000-0000-0000-000000000004',
      name: 'Akola Cotton & Grain Mandi',
      yardType: 'Principal APMC Yard',
    ),

    // Latur District
    MasterMandi(
      id: '60000000-0000-0000-0000-000000000023',
      districtId: '50000000-0000-0000-0000-000000000015',
      stateId: '40000000-0000-0000-0000-000000000004',
      name: 'Latur APMC Grain Yard',
      yardType: 'Principal APMC Yard',
    ),
  ];

  static const List<Map<String, String>> verifiedLocationPresets = [
    {
      'presetName': 'Bikaner Krishi Upaj Mandi Yard',
      'stateId': '40000000-0000-0000-0000-000000000001',
      'stateName': 'Rajasthan',
      'districtId': '50000000-0000-0000-0000-000000000001',
      'districtName': 'Bikaner Mandi Hub',
      'mandiName': 'Bikaner Krishi Upaj Mandi (Grain Market)',
      'warehouseAddress': 'Warehouse A-4, Krishi Upaj Mandi Yard, Bikaner',
      'loadingFacility': 'Krishi Upaj Mandi Yard Warehouse A-4, Platform 2',
    },
    {
      'presetName': 'Kota Bhamashah Mandi Complex',
      'stateId': '40000000-0000-0000-0000-000000000001',
      'stateName': 'Rajasthan',
      'districtId': '50000000-0000-0000-0000-000000000003',
      'districtName': 'Kota Agro Mandi',
      'mandiName': 'Kota Bhamashah Krishi Upaj Mandi',
      'warehouseAddress': 'Shed 12, Bhamashah Mandi Yard, Kota',
      'loadingFacility': 'Kota Bhamashah Mandi Gate 3 Loading Platform',
    },
    {
      'presetName': 'Jaipur Surajpole Mandi Depot',
      'stateId': '40000000-0000-0000-0000-000000000001',
      'stateName': 'Rajasthan',
      'districtId': '50000000-0000-0000-0000-000000000002',
      'districtName': 'Jaipur Central Depot',
      'mandiName': 'Jaipur Surajpole Mandi Yard',
      'warehouseAddress': 'Godown 8, Surajpole Grain Mandi, Jaipur',
      'loadingFacility': 'Surajpole Mandi North Gate Loading Bay',
    },
    {
      'presetName': 'Indore Choithram Mandi Hub',
      'stateId': '40000000-0000-0000-0000-000000000002',
      'stateName': 'Madhya Pradesh',
      'districtId': '50000000-0000-0000-0000-000000000004',
      'districtName': 'Indore Mandi Complex',
      'mandiName': 'Indore Choithram Mandi Yard',
      'warehouseAddress': 'Choithram Mandi Yard Godown 15, Indore',
      'loadingFacility': 'Indore Choithram Mandi Platform 4',
    },
  ];

  static const List<String> verifiedLoadingStatuses = [
    'Ready to Load',
    'Scheduled',
    'Loading in Progress',
    'Delayed',
    'Not Ready',
  ];

  static const List<String> verifiedPaymentTerms = [
    'Payment on Delivery (CAD)',
    '15 Days Net Credit',
    'Advance Payment (100%)',
    'Letter of Credit (LC at Sight)',
    '50% Advance, 50% on Lorry Receipt (LR)',
  ];
}
