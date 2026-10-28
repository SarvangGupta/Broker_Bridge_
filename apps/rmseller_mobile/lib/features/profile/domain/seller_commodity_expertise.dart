/// Domain model representing a seller's declared commodity trading expertise.
/// Supports both authoritative platform commodities (from `master_commodities`)
/// and seller-suggested custom commodities (pending platform approval).
class SellerCommodityExpertise {
  /// Authoritative commodity ID if approved; or client-generated ID if pending.
  final String id;

  /// Commodity name (e.g. 'Wheat', 'Mustard Seed', 'Chana Desi').
  final String commodityName;

  /// Standard commodity code if matched to master (e.g. 'WHT-01').
  final String? commodityCode;

  /// Category name (e.g. 'Grains & Cereals', 'Oilseeds', 'Pulses').
  final String? categoryName;

  /// True if verified against the platform master commodity catalogue;
  /// False if seller-added custom commodity awaiting review.
  final bool isApproved;

  /// Optional ISO timestamp when added.
  final DateTime? addedAt;

  const SellerCommodityExpertise({
    required this.id,
    required this.commodityName,
    this.commodityCode,
    this.categoryName,
    this.isApproved = true,
    this.addedAt,
  });

  /// Factory creating an approved expertise entry from an authoritative MasterCommodity.
  factory SellerCommodityExpertise.fromMaster(
    dynamic master, {
    DateTime? addedAt,
  }) {
    return SellerCommodityExpertise(
      id: master.id as String,
      commodityName: master.name as String,
      commodityCode: master.code as String?,
      categoryName: master.categoryName as String?,
      isApproved: true,
      addedAt: addedAt ?? DateTime.now(),
    );
  }

  /// Factory creating a pending/seller-added custom commodity expertise entry.
  factory SellerCommodityExpertise.pending({
    required String commodityName,
    String? categoryName,
    String? id,
    DateTime? addedAt,
  }) {
    final now = addedAt ?? DateTime.now();
    return SellerCommodityExpertise(
      id: id ?? 'custom-${now.millisecondsSinceEpoch}',
      commodityName: commodityName.trim(),
      categoryName: categoryName?.trim(),
      isApproved: false,
      addedAt: now,
    );
  }

  /// Normalize a commodity name for duplicate prevention.
  static String normalizeName(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '');
  }

  /// Whether two names match after normalization.
  static bool areNamesMatching(String name1, String name2) {
    return normalizeName(name1) == normalizeName(name2);
  }

  /// Whether this entry matches a query or another commodity by normalized name.
  bool matchesNormalized(String otherName) {
    return normalizeName(commodityName) == normalizeName(otherName);
  }

  SellerCommodityExpertise copyWith({
    String? id,
    String? commodityName,
    String? commodityCode,
    String? categoryName,
    bool? isApproved,
    DateTime? addedAt,
  }) {
    return SellerCommodityExpertise(
      id: id ?? this.id,
      commodityName: commodityName ?? this.commodityName,
      commodityCode: commodityCode ?? this.commodityCode,
      categoryName: categoryName ?? this.categoryName,
      isApproved: isApproved ?? this.isApproved,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'commodity_name': commodityName,
      'commodity_code': commodityCode,
      'category_name': categoryName,
      'is_approved': isApproved,
      'added_at': addedAt?.toIso8601String(),
    };
  }

  factory SellerCommodityExpertise.fromMap(Map<String, dynamic> map) {
    DateTime? added;
    if (map['added_at'] != null) {
      added = DateTime.tryParse(map['added_at'].toString());
    }
    return SellerCommodityExpertise(
      id: map['id']?.toString() ?? '',
      commodityName: map['commodity_name']?.toString() ??
          map['name']?.toString() ??
          'Agricultural Commodity',
      commodityCode: map['commodity_code']?.toString() ?? map['code']?.toString(),
      categoryName: map['category_name']?.toString() ?? map['category']?.toString(),
      isApproved: map['is_approved'] == true || map['isApproved'] == true,
      addedAt: added,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SellerCommodityExpertise &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          normalizeName(commodityName) == normalizeName(other.commodityName);

  @override
  int get hashCode => id.hashCode ^ normalizeName(commodityName).hashCode;

  @override
  String toString() =>
      'SellerCommodityExpertise($commodityName, approved: $isApproved)';
}
