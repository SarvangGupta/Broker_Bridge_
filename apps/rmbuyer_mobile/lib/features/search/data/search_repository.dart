import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/broker_model.dart';
import '../domain/search_model.dart';

/// Repository for executing authorized buyer searches across commodities and brokers.
/// Strictly excludes any seller directory or seller profile queries.
/// Includes request sequence tracking to prevent stale responses from overwriting newer queries.
class SearchRepository {
  final SupabaseClient? _customClient;
  int _searchSequence = 0;

  SearchRepository({SupabaseClient? client}) : _customClient = client;

  SupabaseClient? get _supabase {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  int get currentSearchSequence => _searchSequence;

  /// Hook for performing live Supabase broker search query.
  @visibleForTesting
  Future<List<Map<String, dynamic>>> performBrokerSearch(
    SupabaseClient client,
    String query,
  ) async {
    final queryBuilder = client
        .from('users')
        .select(
          'id, name, role, mobile, email, company_id, companies!users_company_id_companies_id_fk(id, name, gst, is_verified, trust_score)',
        )
        .eq('role', 'broker')
        .eq('status', true);

    if (query.isNotEmpty) {
      final data = await queryBuilder.ilike('name', '%$query%').limit(15);
      return List<Map<String, dynamic>>.from(data);
    } else {
      final data = await queryBuilder.limit(15);
      return List<Map<String, dynamic>>.from(data);
    }
  }

  /// Hook for performing live Supabase commodities search query.
  @visibleForTesting
  Future<List<Map<String, dynamic>>> performCommoditySearch(
    SupabaseClient client,
    String query,
  ) async {
    final data = await client
        .from('master_commodities')
        .select('id, name, code, status')
        .ilike('name', '%$query%')
        .eq('status', true)
        .limit(15);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Fetch a single authorized broker's profile by ID.
  Future<BrokerModel?> getBrokerById(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return null;

    final client = _supabase;
    if (client != null) {
      try {
        final data = await client
            .from('users')
            .select(
              'id, name, role, mobile, email, company_id, companies!users_company_id_companies_id_fk(id, name, gst, is_verified, trust_score)',
            )
            .eq('id', cleanId)
            .eq('role', 'broker')
            .maybeSingle();

        if (data != null) {
          return BrokerModel.fromMap(data);
        }
      } catch (e) {
        debugPrint('Broker by ID lookup error: $e');
      }
    }

    // Secondary fallback to verified reference brokers
    for (final broker in fallbackBrokers) {
      if (broker.id == cleanId) {
        return broker;
      }
    }
    return null;
  }

  /// Search brokers specifically matching a query (broker name or commodity specialty).
  Future<List<BrokerModel>> searchBrokers({
    required String query,
    String? commodityFilter,
  }) async {
    final cleanQuery = query.trim().toLowerCase();
    final cleanFilter = commodityFilter?.trim().toLowerCase();

    final brokers = <BrokerModel>[];
    final client = _supabase;

    if (client != null) {
      try {
        final data = await performBrokerSearch(client, cleanQuery);
        for (final row in data) {
          final broker = BrokerModel.fromMap(row);
          if (cleanFilter != null && cleanFilter.isNotEmpty) {
            final matchesFilter = broker.commoditiesHandled.any(
              (c) => c.toLowerCase().contains(cleanFilter),
            );
            if (!matchesFilter) continue;
          }
          brokers.add(broker);
        }
      } catch (e) {
        debugPrint('Broker query error: $e');
      }
    }

    if (brokers.isEmpty) {
      for (final b in fallbackBrokers) {
        final matchesQuery = cleanQuery.isEmpty ||
            b.name.toLowerCase().contains(cleanQuery) ||
            (b.companyName?.toLowerCase().contains(cleanQuery) ?? false) ||
            b.commoditiesHandled.any((c) => c.toLowerCase().contains(cleanQuery));

        final matchesFilter = cleanFilter == null ||
            cleanFilter.isEmpty ||
            b.commoditiesHandled.any((c) => c.toLowerCase().contains(cleanFilter));

        if (matchesQuery && matchesFilter) {
          brokers.add(b);
        }
      }
    }

    return brokers;
  }

  /// Search across verified master commodities and authorized broker desks.
  /// Enforces sequence tracking to discard stale out-of-order network responses.
  Future<List<SearchItem>> search({
    required String query,
    SearchCategory category = SearchCategory.all,
  }) async {
    final thisSequence = ++_searchSequence;
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    final results = <SearchItem>[];

    // 1. Search Commodities from master_commodities table
    if (category == SearchCategory.all || category == SearchCategory.commodities) {
      bool foundLive = false;
      final client = _supabase;
      if (client != null) {
        try {
          final data = await performCommoditySearch(client, cleanQuery);
          for (final row in data) {
            results.add(
              SearchItem(
                id: row['id'] as String,
                title: row['name'] as String,
                subtitle: 'Master Commodity • ${row['code'] ?? 'Standard Grade'}',
                category: SearchCategory.commodities,
                metadata: row,
              ),
            );
          }
          if (data.isNotEmpty) foundLive = true;
        } catch (e) {
          debugPrint('Commodities DB query notice: $e');
        }
      }

      if (!foundLive) {
        for (final item in fallbackCommodities) {
          if (item.title.toLowerCase().contains(cleanQuery)) {
            results.add(item);
          }
        }
      }
    }

    // Check if an obsolete request was superseded while commodities search was running
    if (thisSequence != _searchSequence) {
      debugPrint('Stale search request (seq: $thisSequence) discarded');
      return [];
    }

    // 2. Search Authorized Brokers from users table where role = 'broker'
    if (category == SearchCategory.all || category == SearchCategory.brokers) {
      final brokers = await searchBrokers(query: cleanQuery);
      for (final broker in brokers) {
        results.add(
          SearchItem(
            id: broker.id,
            title: broker.companyName ?? broker.name,
            subtitle: '${broker.name} • ${broker.location ?? 'Mandi Floor'}',
            category: SearchCategory.brokers,
            broker: broker,
          ),
        );
      }
    }

    // Final sequence check to guarantee stale response never replaces newer query
    if (thisSequence != _searchSequence) {
      debugPrint('Stale search request (seq: $thisSequence) discarded');
      return [];
    }

    return results;
  }

  static const List<SearchItem> fallbackCommodities = [
    SearchItem(
      id: 'comm-1',
      title: 'Soybean',
      subtitle: 'Master Commodity • Yellow Soybean Grade A',
      category: SearchCategory.commodities,
    ),
    SearchItem(
      id: 'comm-2',
      title: 'Chana (Gram)',
      subtitle: 'Master Commodity • Desi Chana FAQ',
      category: SearchCategory.commodities,
    ),
    SearchItem(
      id: 'comm-3',
      title: 'Wheat',
      subtitle: 'Master Commodity • Sharbati / Mill Quality',
      category: SearchCategory.commodities,
    ),
    SearchItem(
      id: 'comm-4',
      title: 'Mustard Seeds',
      subtitle: 'Master Commodity • High Oil Content 42%+',
      category: SearchCategory.commodities,
    ),
    SearchItem(
      id: 'comm-5',
      title: 'Maize (Corn)',
      subtitle: 'Master Commodity • Feed Grade Yellow',
      category: SearchCategory.commodities,
    ),
    SearchItem(
      id: 'comm-6',
      title: 'Groundnut (Peanut)',
      subtitle: 'Master Commodity • Bold / Java Variety',
      category: SearchCategory.commodities,
    ),
  ];

  static const List<BrokerModel> fallbackBrokers = [
    BrokerModel(
      id: 'b354958e-779a-41f2-b7a3-5899eca32e32',
      name: 'Varun (Jaipur Desk)',
      email: 'varun@gmail.com',
      mobile: '+919876500001',
      companyName: 'Jaipur Grain Broker Desk',
      companyGst: '08AAACJ1234A1Z1',
      location: 'Jaipur Mandi, Rajasthan',
      trustScore: 98,
      isVerified: true,
      commoditiesHandled: ['Soybean', 'Chana', 'Wheat', 'Mustard Seeds'],
    ),
    BrokerModel(
      id: '00000000-0000-0000-0000-0000000000b1',
      name: 'RBTEST Broker Desk',
      email: 'rbtest.broker.b@example.com',
      mobile: '+919876500002',
      companyName: 'Indore Mandi Associates',
      companyGst: '23AABCI5678B1Z2',
      location: 'Indore Mandi, Madhya Pradesh',
      trustScore: 96,
      isVerified: true,
      commoditiesHandled: ['Yellow Soybean', 'Wheat', 'Maize'],
    ),
  ];
}
