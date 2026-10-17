import 'package:flutter/foundation.dart';

@immutable
class MasterDropdownItem {
  final String id;
  final String name;
  final String? extra;

  const MasterDropdownItem({
    required this.id,
    required this.name,
    this.extra,
  });

  factory MasterDropdownItem.fromJson(Map<String, dynamic> json) {
    return MasterDropdownItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      extra: json['symbol']?.toString() ?? json['categoryName']?.toString() ?? json['code']?.toString(),
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
