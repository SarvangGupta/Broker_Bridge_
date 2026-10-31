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
      parentId: json['commodityId']?.toString() ??
          json['commodity_id']?.toString() ??
          json['stateId']?.toString() ??
          json['state_id']?.toString(),
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

  /// True for the built-in sample lists used when live master data failed to load.
  /// Their ids are not real records, so nothing may be saved against them.
  final bool isFallback;

  const TradeMasterData({
    required this.buyerCompanies,
    required this.sellerCompanies,
    required this.commodities,
    required this.grades,
    required this.units,
    required this.states,
    required this.districts,
    this.isFallback = false,
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

  factory TradeMasterData.fallback() => const TradeMasterData(
        buyerCompanies: [
          MasterDropdownItem(
            id: '30000000-0000-0000-0000-000000000101',
            name: 'Sharma Agro Mills Ltd',
          ),
          MasterDropdownItem(
            id: '00000000-0000-0000-0000-000000000001',
            name: 'AgrInnovate Flour Mills',
          ),
          MasterDropdownItem(
            id: '00000000-0000-0000-0000-000000000002',
            name: 'North Dairy Feed Corp',
          ),
        ],
        sellerCompanies: [
          MasterDropdownItem(
            id: '30000000-0000-0000-0000-000000000201',
            name: 'Ridhi Traders',
          ),
          MasterDropdownItem(
            id: '00000000-0000-0000-0000-000000000010',
            name: 'Apex Cattle Nutrition',
          ),
          MasterDropdownItem(
            id: '00000000-0000-0000-0000-000000000011',
            name: 'Karnal Agro Traders',
          ),
        ],
        commodities: [
          MasterDropdownItem(
            id: '10000000-0000-0000-0000-000000000001',
            name: 'Mustard Seed (Sarson)',
            categoryName: 'Oilseeds & Feed Stocks',
          ),
          MasterDropdownItem(
            id: '20000000-0000-0000-0000-000000000001',
            name: 'Yellow Maize (Corn)',
            categoryName: 'Grains & Energy Ingredients',
          ),
          MasterDropdownItem(
            id: 'aa000000-0000-0000-0000-000000000001',
            name: 'Soybean DOC',
            categoryName: 'Oil Cakes & Oil Meals',
          ),
          MasterDropdownItem(
            id: '8f58c547-e988-5843-954a-6e0e57ae6b44',
            name: 'Wheat Bran',
            categoryName: 'Bran, Polish & Milling By-products',
          ),
        ],
        grades: [
          MasterDropdownItem(
            id: '11000000-0000-0000-0000-000000000001',
            name: 'FAQ (Fair Average Quality)',
            parentId: '10000000-0000-0000-0000-000000000001',
          ),
          MasterDropdownItem(
            id: '11000000-0000-0000-0000-000000000002',
            name: 'Machine Cleaned 42% Oil',
            parentId: '10000000-0000-0000-0000-000000000001',
          ),
          MasterDropdownItem(
            id: '21000000-0000-0000-0000-000000000001',
            name: 'Grade A Milling',
            parentId: '20000000-0000-0000-0000-000000000001',
          ),
          MasterDropdownItem(
            id: '21000000-0000-0000-0000-000000000002',
            name: 'Feed Grade Premium',
            parentId: '20000000-0000-0000-0000-000000000001',
          ),
          MasterDropdownItem(
            id: '5dcb586c-632a-50c0-b097-a33efae04a20',
            name: 'FAQ (Fair Average Quality)',
            parentId: '8f58c547-e988-5843-954a-6e0e57ae6b44',
          ),
        ],
        units: [
          MasterDropdownItem(
            id: '00000000-0000-0000-0000-000000000001',
            name: 'Metric Tonne',
            extra: 'MT',
          ),
          MasterDropdownItem(
            id: '00000000-0000-0000-0000-000000000002',
            name: 'Quintal',
            extra: 'Qtl',
          ),
        ],
        states: [],
        districts: [],
        isFallback: true,
      );

  /// Master id for a form unit choice ('MT' or 'Qtl'), matched on symbol or name.
  String? unitIdFor(String symbol) {
    final names = symbol == 'Qtl' ? const ['qtl', 'quintal'] : const ['mt', 'metric ton', 'metric tonne'];
    // Several rows can share a symbol (live has 'Tonn' and 'Metric Ton' as MT), so an
    // exact name wins and the result never depends on row order.
    for (final u in units) {
      if (names.contains(u.name.trim().toLowerCase())) return u.id;
    }
    for (final u in units) {
      if (names.contains(u.extra?.trim().toLowerCase())) return u.id;
    }
    return null;
  }

  /// Complete address text for a transaction to keep, independent of later edits
  /// to the saved location. City and state resolve to names, not stored ids.
  String locationSnapshot({
    required String name,
    required String address,
    String? city,
    String? state,
  }) {
    String label(List<MasterDropdownItem> items, String? value) {
      if (value == null || value.isEmpty) return '';
      return items.where((i) => i.id == value).firstOrNull?.name ?? value;
    }

    return [name, address, label(districts, city), label(states, state)].where((p) => p.isNotEmpty).join(', ');
  }

  String? stateIdFor(String? name) => _idByName(states, name);

  String? districtIdFor(String? name) => _idByName(districts, name);

  static String? _idByName(List<MasterDropdownItem> items, String? name) {
    final wanted = name?.trim().toLowerCase();
    if (wanted == null || wanted.isEmpty) return null;
    for (final item in items) {
      if (item.id.toLowerCase() == wanted || item.name.trim().toLowerCase() == wanted) return item.id;
    }
    return null;
  }

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
