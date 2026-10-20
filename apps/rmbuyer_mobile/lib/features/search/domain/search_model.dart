import 'broker_model.dart';

enum SearchCategory { all, commodities, brokers }

/// Represents an authorized searchable entity in RMBuyer.
/// Note: Seller entities are strictly excluded by design.
class SearchItem {
  final String id;
  final String title;
  final String subtitle;
  final SearchCategory category;
  final Map<String, dynamic>? metadata;
  final BrokerModel? broker;

  const SearchItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    this.metadata,
    this.broker,
  });

  bool get isCommodity => category == SearchCategory.commodities;
  bool get isBroker => category == SearchCategory.brokers;
}
