import 'package:flutter/foundation.dart';
import 'package:rmbroker_mobile/features/directory/utils/phone_utils.dart';

/// Supported entity categories for RMBroker global search.
enum SearchEntityType {
  all('all', 'All Results'),
  contacts('contacts', 'Contacts'),
  materials('materials', 'Materials'),
  requirements('requirements', 'Requirements'),
  offers('offers', 'Offers'),
  deals('deals', 'Deals');

  final String value;
  final String label;

  const SearchEntityType(this.value, this.label);

  static SearchEntityType fromString(String? val) {
    if (val == null) return SearchEntityType.all;
    return SearchEntityType.values.firstWhere(
      (e) => e.value.toLowerCase() == val.toLowerCase(),
      orElse: () => SearchEntityType.all,
    );
  }
}

/// Contact result (Buyer or Seller) from search.
@immutable
class SearchContactItem {
  final String id;
  final String userId;
  final String name;
  final String companyName;
  final String role; // 'Buyer' or 'Seller'
  final String mobile;
  final String formattedMobile;
  final String? city;
  final bool status;
  final bool isVerified;
  final String? telUri;
  final String? whatsappUri;
  final String url;

  const SearchContactItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.companyName,
    required this.role,
    required this.mobile,
    required this.formattedMobile,
    this.city,
    this.status = true,
    this.isVerified = false,
    this.telUri,
    this.whatsappUri,
    this.url = '',
  });

  bool get isBuyer => role.toLowerCase() == 'buyer';
  bool get isSeller => role.toLowerCase() == 'seller';

  factory SearchContactItem.fromJson(Map<String, dynamic> json) {
    final rawMobile = json['mobile']?.toString() ?? '';
    final phoneRes = PhoneUtils.validateAndNormalize(rawMobile);
    final normalized = phoneRes.isValid ? phoneRes.normalized : rawMobile;
    final formatted =
        json['formattedMobile']?.toString() ??
        (phoneRes.isValid ? phoneRes.formatted : rawMobile);

    return SearchContactItem(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Contact',
      companyName: json['companyName']?.toString() ?? 'Unnamed Business',
      role: json['role']?.toString() ?? 'Buyer',
      mobile: normalized,
      formattedMobile: formatted,
      city: json['city']?.toString() ?? json['districtId']?.toString(),
      status: json['status'] is bool ? json['status'] : true,
      isVerified: json['isVerified'] is bool ? json['isVerified'] : false,
      telUri: json['telUri']?.toString() ?? PhoneUtils.getSafeTelUri(normalized),
      whatsappUri:
          json['whatsappUri']?.toString() ??
          PhoneUtils.getSafeWhatsAppUri(normalized),
      url: json['url']?.toString() ?? '/directory',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'name': name,
    'companyName': companyName,
    'role': role,
    'mobile': mobile,
    'formattedMobile': formattedMobile,
    'city': city,
    'status': status,
    'isVerified': isVerified,
    'telUri': telUri,
    'whatsappUri': whatsappUri,
    'url': url,
  };
}

/// Raw material / Commodity result with grades.
@immutable
class SearchMaterialItem {
  final String id;
  final String name;
  final String? code;
  final String? categoryName;
  final String? industryName;
  final List<String> grades;
  final String url;

  const SearchMaterialItem({
    required this.id,
    required this.name,
    this.code,
    this.categoryName,
    this.industryName,
    this.grades = const [],
    this.url = '',
  });

  factory SearchMaterialItem.fromJson(Map<String, dynamic> json) {
    return SearchMaterialItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      categoryName: json['categoryName']?.toString(),
      industryName: json['industryName']?.toString(),
      grades:
          (json['grades'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      url: json['url']?.toString() ?? '/work',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'categoryName': categoryName,
    'industryName': industryName,
    'grades': grades,
    'url': url,
  };
}

/// Buyer Requirement / Mandate result.
@immutable
class SearchRequirementItem {
  final String id;
  final String commodityName;
  final String? gradeName;
  final double quantity;
  final String unitSymbol;
  final double targetPrice;
  final String buyerCompanyName;
  final String status;
  final String? targetDate;
  final String url;

  const SearchRequirementItem({
    required this.id,
    required this.commodityName,
    this.gradeName,
    required this.quantity,
    required this.unitSymbol,
    required this.targetPrice,
    required this.buyerCompanyName,
    required this.status,
    this.targetDate,
    this.url = '',
  });

  factory SearchRequirementItem.fromJson(Map<String, dynamic> json) {
    return SearchRequirementItem(
      id: json['id']?.toString() ?? '',
      commodityName: json['commodityName']?.toString() ?? 'Commodity',
      gradeName: json['gradeName']?.toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitSymbol: json['unitSymbol']?.toString() ?? 'MT',
      targetPrice: (json['targetPrice'] as num?)?.toDouble() ?? 0.0,
      buyerCompanyName:
          json['buyerCompanyName']?.toString() ?? 'Buyer Business',
      status: json['status']?.toString() ?? 'OPEN',
      targetDate: json['targetDate']?.toString(),
      url: json['url']?.toString() ?? '/work',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'commodityName': commodityName,
    'gradeName': gradeName,
    'quantity': quantity,
    'unitSymbol': unitSymbol,
    'targetPrice': targetPrice,
    'buyerCompanyName': buyerCompanyName,
    'status': status,
    'targetDate': targetDate,
    'url': url,
  };
}

/// Seller Offer / Availability result.
@immutable
class SearchOfferItem {
  final String id;
  final String? lotNumber;
  final String commodityName;
  final double availableQuantity;
  final String unitSymbol;
  final double askingPrice;
  final String sellerCompanyName;
  final String loadingStatus;
  final String? stateName;
  final String status;
  final String url;

  const SearchOfferItem({
    required this.id,
    this.lotNumber,
    required this.commodityName,
    required this.availableQuantity,
    required this.unitSymbol,
    required this.askingPrice,
    required this.sellerCompanyName,
    this.loadingStatus = 'Ready',
    this.stateName,
    required this.status,
    this.url = '',
  });

  factory SearchOfferItem.fromJson(Map<String, dynamic> json) {
    return SearchOfferItem(
      id: json['id']?.toString() ?? '',
      lotNumber: json['lotNumber']?.toString(),
      commodityName: json['commodityName']?.toString() ?? 'Commodity',
      availableQuantity:
          (json['availableQuantity'] as num?)?.toDouble() ?? 0.0,
      unitSymbol: json['unitSymbol']?.toString() ?? 'MT',
      askingPrice: (json['askingPrice'] as num?)?.toDouble() ?? 0.0,
      sellerCompanyName:
          json['sellerCompanyName']?.toString() ?? 'Seller Business',
      loadingStatus: json['loadingStatus']?.toString() ?? 'Ready',
      stateName: json['stateName']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      url: json['url']?.toString() ?? '/work',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'lotNumber': lotNumber,
    'commodityName': commodityName,
    'availableQuantity': availableQuantity,
    'unitSymbol': unitSymbol,
    'askingPrice': askingPrice,
    'sellerCompanyName': sellerCompanyName,
    'loadingStatus': loadingStatus,
    'stateName': stateName,
    'status': status,
    'url': url,
  };
}

/// Deal / Negotiation result.
@immutable
class SearchDealItem {
  final String id;
  final String dealRef;
  final String commodityName;
  final double agreedQuantity;
  final double agreedPrice;
  final String buyerName;
  final String sellerName;
  final String status;
  final String createdAt;
  final String url;

  const SearchDealItem({
    required this.id,
    required this.dealRef,
    required this.commodityName,
    required this.agreedQuantity,
    required this.agreedPrice,
    required this.buyerName,
    required this.sellerName,
    required this.status,
    required this.createdAt,
    this.url = '',
  });

  factory SearchDealItem.fromJson(Map<String, dynamic> json) {
    return SearchDealItem(
      id: json['id']?.toString() ?? '',
      dealRef: json['dealRef']?.toString() ?? json['id']?.toString() ?? 'DEAL',
      commodityName: json['commodityName']?.toString() ?? 'Agri Commodity',
      agreedQuantity: (json['agreedQuantity'] as num?)?.toDouble() ?? 0.0,
      agreedPrice: (json['agreedPrice'] as num?)?.toDouble() ?? 0.0,
      buyerName: json['buyerName']?.toString() ?? 'Buyer',
      sellerName: json['sellerName']?.toString() ?? 'Seller',
      status: json['status']?.toString() ?? 'NEGOTIATION',
      createdAt: json['createdAt']?.toString() ?? '',
      url: json['url']?.toString() ?? '/deals',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'dealRef': dealRef,
    'commodityName': commodityName,
    'agreedQuantity': agreedQuantity,
    'agreedPrice': agreedPrice,
    'buyerName': buyerName,
    'sellerName': sellerName,
    'status': status,
    'createdAt': createdAt,
    'url': url,
  };
}

/// Aggregated global search container.
@immutable
class GlobalSearchResults {
  final List<SearchContactItem> contacts;
  final List<SearchMaterialItem> materials;
  final List<SearchRequirementItem> requirements;
  final List<SearchOfferItem> offers;
  final List<SearchDealItem> deals;
  final int totalCount;

  const GlobalSearchResults({
    this.contacts = const [],
    this.materials = const [],
    this.requirements = const [],
    this.offers = const [],
    this.deals = const [],
    this.totalCount = 0,
  });

  factory GlobalSearchResults.empty() => const GlobalSearchResults();

  factory GlobalSearchResults.fromJson(Map<String, dynamic> json) {
    final contactsList =
        (json['contacts'] as List<dynamic>?)
            ?.map((e) => SearchContactItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    final materialsList =
        (json['materials'] as List<dynamic>?)
            ?.map((e) => SearchMaterialItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    final requirementsList =
        (json['requirements'] as List<dynamic>?)
            ?.map(
              (e) => SearchRequirementItem.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        const [];
    final offersList =
        (json['offers'] as List<dynamic>?)
            ?.map((e) => SearchOfferItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    final dealsList =
        (json['deals'] as List<dynamic>?)
            ?.map((e) => SearchDealItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    final computedTotal =
        (json['totalCount'] as num?)?.toInt() ??
        (contactsList.length +
            materialsList.length +
            requirementsList.length +
            offersList.length +
            dealsList.length);

    return GlobalSearchResults(
      contacts: contactsList,
      materials: materialsList,
      requirements: requirementsList,
      offers: offersList,
      deals: dealsList,
      totalCount: computedTotal,
    );
  }

  Map<String, dynamic> toJson() => {
    'contacts': contacts.map((e) => e.toJson()).toList(),
    'materials': materials.map((e) => e.toJson()).toList(),
    'requirements': requirements.map((e) => e.toJson()).toList(),
    'offers': offers.map((e) => e.toJson()).toList(),
    'deals': deals.map((e) => e.toJson()).toList(),
    'totalCount': totalCount,
  };
}

/// Entity counts dictionary across categories.
@immutable
class SearchCounts {
  final int all;
  final int contacts;
  final int materials;
  final int requirements;
  final int offers;
  final int deals;

  const SearchCounts({
    this.all = 0,
    this.contacts = 0,
    this.materials = 0,
    this.requirements = 0,
    this.offers = 0,
    this.deals = 0,
  });

  factory SearchCounts.fromResults(GlobalSearchResults results) {
    return SearchCounts(
      all: results.totalCount,
      contacts: results.contacts.length,
      materials: results.materials.length,
      requirements: results.requirements.length,
      offers: results.offers.length,
      deals: results.deals.length,
    );
  }

  factory SearchCounts.fromJson(Map<String, dynamic> json) {
    return SearchCounts(
      all: (json['all'] as num?)?.toInt() ?? 0,
      contacts: (json['contacts'] as num?)?.toInt() ?? 0,
      materials: (json['materials'] as num?)?.toInt() ?? 0,
      requirements: (json['requirements'] as num?)?.toInt() ?? 0,
      offers: (json['offers'] as num?)?.toInt() ?? 0,
      deals: (json['deals'] as num?)?.toInt() ?? 0,
    );
  }

  int getCount(SearchEntityType type) {
    switch (type) {
      case SearchEntityType.all:
        return all;
      case SearchEntityType.contacts:
        return contacts;
      case SearchEntityType.materials:
        return materials;
      case SearchEntityType.requirements:
        return requirements;
      case SearchEntityType.offers:
        return offers;
      case SearchEntityType.deals:
        return deals;
    }
  }
}

/// Contact item for Quick Dial & Speed-Dial modal.
@immutable
class QuickDialContactItem {
  final String id;
  final String name;
  final String companyName;
  final String role; // 'Buyer' or 'Seller'
  final String mobile;
  final String formattedMobile;
  final String? telUri;
  final String? whatsappUri;
  final bool isVerified;

  const QuickDialContactItem({
    required this.id,
    required this.name,
    required this.companyName,
    required this.role,
    required this.mobile,
    required this.formattedMobile,
    this.telUri,
    this.whatsappUri,
    this.isVerified = false,
  });

  bool get isBuyer => role.toLowerCase() == 'buyer';
  bool get isSeller => role.toLowerCase() == 'seller';

  factory QuickDialContactItem.fromJson(Map<String, dynamic> json) {
    final rawMobile = json['mobile']?.toString() ?? '';
    final phoneRes = PhoneUtils.validateAndNormalize(rawMobile);
    final normalized = phoneRes.isValid ? phoneRes.normalized : rawMobile;
    final formatted =
        json['formattedMobile']?.toString() ??
        (phoneRes.isValid ? phoneRes.formatted : rawMobile);

    return QuickDialContactItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Contact',
      companyName: json['companyName']?.toString() ?? 'Business Partner',
      role: json['role']?.toString() ?? 'Buyer',
      mobile: normalized,
      formattedMobile: formatted,
      telUri: json['telUri']?.toString() ?? PhoneUtils.getSafeTelUri(normalized),
      whatsappUri:
          json['whatsappUri']?.toString() ??
          PhoneUtils.getSafeWhatsAppUri(normalized),
      isVerified: json['isVerified'] is bool ? json['isVerified'] : false,
    );
  }
}
