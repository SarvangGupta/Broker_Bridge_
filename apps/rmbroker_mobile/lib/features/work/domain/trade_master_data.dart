import 'package:flutter/foundation.dart';

@immutable
class MasterDropdownItem {
  final String id;
  final String name;
  final String? extra;

  /// Commodities: authoritative category name from `master_categories` (null = unavailable).
  final String? categoryName;

  /// Grades: the commodity this grade belongs to (`master_grades.commodity_id`).
  final String? parentId;

  const MasterDropdownItem({
    required this.id,
    required this.name,
    this.extra,
    this.categoryName,
    this.parentId,
  });

  factory MasterDropdownItem.fromJson(Map<String, dynamic> json) {
    return MasterDropdownItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      extra: json['symbol']?.toString() ?? json['categoryName']?.toString() ?? json['code']?.toString(),
      categoryName: json['categoryName']?.toString() ?? json['category_name']?.toString(),
      parentId: json['commodityId']?.toString() ?? json['commodity_id']?.toString(),
    );
  }
}

@immutable
class TradeMasterData {
  final List<MasterDropdownItem> buyerCompanies;
  final List<MasterDropdownItem> sellerCompanies;
  final List<MasterDropdownItem> commodities;
  final List<MasterDropdownItem> grades;
  final List<MasterDropdownItem> units;
  final List<MasterDropdownItem> states;
  final List<MasterDropdownItem> districts;

  const TradeMasterData({
    required this.buyerCompanies,
    required this.sellerCompanies,
    required this.commodities,
    required this.grades,
    required this.units,
    required this.states,
    required this.districts,
  });

  factory TradeMasterData.empty() => const TradeMasterData(
        buyerCompanies: [],
        sellerCompanies: [],
        commodities: [],
        grades: [],
        units: [],
        states: [],
        districts: [],
      );

  MasterDropdownItem? commodityById(String? id) {
    if (id == null) return null;
    for (final c in commodities) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Only the grades linked to [commodityId]; never the full grade list (KI-43).
  List<MasterDropdownItem> gradesFor(String? commodityId) {
    if (commodityId == null || commodityId.isEmpty) return const [];
    return grades.where((g) => g.parentId == commodityId).toList();
  }

  /// True when [gradeId] is one of [commodityId]'s own grades.
  bool isValidProductGrade(String? commodityId, String? gradeId) {
    if (gradeId == null || gradeId.isEmpty) return false;
    return gradesFor(commodityId).any((g) => g.id == gradeId);
  }

  factory TradeMasterData.fromJson(Map<String, dynamic> json) {
    List<MasterDropdownItem> parseList(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(MasterDropdownItem.fromJson)
          .toList();
    }

    return TradeMasterData(
      buyerCompanies: parseList(json['buyerCompanies']),
      sellerCompanies: parseList(json['sellerCompanies']),
      commodities: parseList(json['commodities']),
      grades: parseList(json['grades']),
      units: parseList(json['units']),
      states: parseList(json['states']),
      districts: parseList(json['districts']),
    );
  }
}
