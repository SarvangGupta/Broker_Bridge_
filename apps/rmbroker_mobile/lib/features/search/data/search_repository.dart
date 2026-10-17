import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rmbroker_mobile/core/network/api_client.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/features/search/domain/search_result.dart';

/// Custom exception thrown when search endpoint or backend contract is pending exposure.
class SearchUnavailableException implements Exception {
  final String message;
  final String? diagnosticCode;
  const SearchUnavailableException(this.message, [this.diagnosticCode]);

  @override
  String toString() => 'SearchUnavailableException: $message ($diagnosticCode)';
}

/// Provider for SearchRepository singleton.
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository();
});

/// Data access repository for RMBroker unified global search & communication.
class SearchRepository {
  final ApiClient? _customApiClient;
  final SupabaseClient? _customSupabase;
  final SecureStorageService storage;

  static const String _recentSearchesKey = 'rmbroker_recent_searches_secure';
  static const int _maxRecentSearches = 8;

  SearchRepository({
    ApiClient? apiClient,
    SupabaseClient? supabase,
    SecureStorageService? storage,
  })  : _customApiClient = apiClient,
        _customSupabase = supabase,
        storage = storage ?? SecureStorageService();

  ApiClient get apiClient =>
      _customApiClient ?? ApiClient(storage: storage);

  SupabaseClient? get supabase {
    if (_customSupabase != null) return _customSupabase;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Normalizes and trims user query.
  String sanitizeQuery(String raw) {
    return raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
  }

  /// Executes permission-aware global search across all authorized record types.
  Future<GlobalSearchResults> searchGlobal({
    required String query,
    SearchEntityType filterType = SearchEntityType.all,
    CancelToken? cancelToken,
  }) async {
    final cleanQuery = sanitizeQuery(query);
    if (cleanQuery.length < 2) {
      return GlobalSearchResults.empty();
    }

    // 1. Primary Strategy: Next.js authoritative REST API (/broker/search)
    try {
      final response = await apiClient.get(
        '/broker/search',
        queryParameters: {
          'q': cleanQuery,
          'entity': filterType.value,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          final payload = data['data'];
          if (payload is Map<String, dynamic> && payload['results'] != null) {
            return GlobalSearchResults.fromJson(
              payload['results'] as Map<String, dynamic>,
            );
          }
        }
      }
    } on DioException catch (dioErr) {
      // If cancelled by newer request, rethrow so controller knows it was superseded
      if (CancelToken.isCancel(dioErr)) {
        rethrow;
      }
      // If 404 or connection refused, fallback to direct Supabase PostgREST
    } catch (_) {
      // Proceed to fallback
    }

    // 2. Secondary Strategy: Direct Supabase PostgREST query under authenticated broker session
    try {
      final client = supabase;
      if (client == null) {
        throw const SearchUnavailableException(
          'Supabase backend service is not initialized on this client session.',
          'RB-SRCH-NO-CLIENT',
        );
      }

      final currentBrokerId = client.auth.currentUser?.id;
      final safePattern = '%$cleanQuery%';

      List<SearchContactItem> contacts = [];
      List<SearchMaterialItem> materials = [];
      List<SearchRequirementItem> requirements = [];
      List<SearchOfferItem> offers = [];
      List<SearchDealItem> deals = [];

      final searchAll = filterType == SearchEntityType.all;

      // A. Contacts search
      if (searchAll || filterType == SearchEntityType.contacts) {
        try {
          var queryBuilder = client
              .from('crm_contacts')
              .select(
                'id, role, users!inner(id, name, mobile, status), companies!inner(id, name, district_id, is_verified)',
              );

          if (currentBrokerId != null) {
            queryBuilder = queryBuilder.eq('broker_id', currentBrokerId);
          }

          final contactRows = await queryBuilder.limit(10);
          contacts = (contactRows as List<dynamic>).map((row) {
            final user = row['users'] as Map<String, dynamic>? ?? {};
            final company = row['companies'] as Map<String, dynamic>? ?? {};
            return SearchContactItem(
              id: row['id']?.toString() ?? '',
              userId: user['id']?.toString() ?? '',
              name: user['name']?.toString() ?? 'Unnamed Contact',
              companyName: company['name']?.toString() ?? 'Unnamed Business',
              role: (row['role']?.toString() ?? 'buyer').toLowerCase() == 'seller' ? 'Seller' : 'Buyer',
              mobile: user['mobile']?.toString() ?? '',
              formattedMobile: user['mobile']?.toString() ?? '',
              city: company['district_id']?.toString(),
              status: user['status'] is bool ? user['status'] : true,
              isVerified: company['is_verified'] is bool ? company['is_verified'] : false,
              url: '/directory?contactId=${row['id']}',
            );
          }).where((c) {
            final q = cleanQuery.toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                c.companyName.toLowerCase().contains(q) ||
                c.mobile.contains(q);
          }).toList();
        } catch (_) {
          // If table query restricted by RLS, contacts remain empty
        }
      }

      // B. Materials (Master Commodities)
      if (searchAll || filterType == SearchEntityType.materials) {
        try {
          final commodityRows = await client
              .from('master_commodities')
              .select('id, name, code, master_categories(name)')
              .or('name.ilike.$safePattern,code.ilike.$safePattern')
              .limit(10);

          materials = (commodityRows as List<dynamic>).map((row) {
            final cat = row['master_categories'] as Map<String, dynamic>?;
            return SearchMaterialItem(
              id: row['id']?.toString() ?? '',
              name: row['name']?.toString() ?? 'Commodity',
              code: row['code']?.toString(),
              categoryName: cat?['name']?.toString(),
              url: '/work',
            );
          }).toList();
        } catch (_) {}
      }

      // C. Requirements
      if (searchAll || filterType == SearchEntityType.requirements) {
        try {
          var reqQuery = client
              .from('requirements')
              .select('id, quantity, target_price, status, target_date, master_commodities(name), companies(name)');
          if (currentBrokerId != null) {
            reqQuery = reqQuery.or('broker_id.eq.$currentBrokerId,visibility.eq.global');
          }
          final reqRows = await reqQuery.limit(10);
          requirements = (reqRows as List<dynamic>).map((row) {
            final comm = row['master_commodities'] as Map<String, dynamic>?;
            final comp = row['companies'] as Map<String, dynamic>?;
            return SearchRequirementItem(
              id: row['id']?.toString() ?? '',
              commodityName: comm?['name']?.toString() ?? 'Commodity',
              quantity: (row['quantity'] as num?)?.toDouble() ?? 0.0,
              unitSymbol: 'MT',
              targetPrice: (row['target_price'] as num?)?.toDouble() ?? 0.0,
              buyerCompanyName: comp?['name']?.toString() ?? 'Buyer Company',
              status: row['status']?.toString() ?? 'OPEN',
              targetDate: row['target_date']?.toString(),
              url: '/work',
            );
          }).where((r) {
            final q = cleanQuery.toLowerCase();
            return r.commodityName.toLowerCase().contains(q) ||
                r.buyerCompanyName.toLowerCase().contains(q);
          }).toList();
        } catch (_) {}
      }

      // D. Offers (Availabilities)
      if (searchAll || filterType == SearchEntityType.offers) {
        try {
          var offerQuery = client
              .from('availabilities')
              .select('id, lot_number, available_quantity, asking_price, status, master_commodities(name), companies(name)');
          if (currentBrokerId != null) {
            offerQuery = offerQuery.or('broker_id.eq.$currentBrokerId,visibility.eq.global');
          }
          final offerRows = await offerQuery.limit(10);
          offers = (offerRows as List<dynamic>).map((row) {
            final comm = row['master_commodities'] as Map<String, dynamic>?;
            final comp = row['companies'] as Map<String, dynamic>?;
            return SearchOfferItem(
              id: row['id']?.toString() ?? '',
              lotNumber: row['lot_number']?.toString(),
              commodityName: comm?['name']?.toString() ?? 'Commodity',
              availableQuantity: (row['available_quantity'] as num?)?.toDouble() ?? 0.0,
              unitSymbol: 'MT',
              askingPrice: (row['asking_price'] as num?)?.toDouble() ?? 0.0,
              sellerCompanyName: comp?['name']?.toString() ?? 'Seller Company',
              status: row['status']?.toString() ?? 'ACTIVE',
              url: '/work',
            );
          }).where((o) {
            final q = cleanQuery.toLowerCase();
            return o.commodityName.toLowerCase().contains(q) ||
                o.sellerCompanyName.toLowerCase().contains(q);
          }).toList();
        } catch (_) {}
      }

      // E. Deals
      if (searchAll || filterType == SearchEntityType.deals) {
        try {
          var dealQuery = client
              .from('deals')
              .select('id, agreed_quantity, agreed_price, status, created_at');
          if (currentBrokerId != null) {
            dealQuery = dealQuery.eq('broker_id', currentBrokerId);
          }
          final dealRows = await dealQuery.limit(10);
          deals = (dealRows as List<dynamic>).map((row) {
            return SearchDealItem(
              id: row['id']?.toString() ?? '',
              dealRef: 'DEAL-${(row['id']?.toString() ?? '').split('-').first.toUpperCase()}',
              commodityName: 'Agri Lot',
              agreedQuantity: (row['agreed_quantity'] as num?)?.toDouble() ?? 0.0,
              agreedPrice: (row['agreed_price'] as num?)?.toDouble() ?? 0.0,
              buyerName: 'Authorized Buyer',
              sellerName: 'Authorized Seller',
              status: row['status']?.toString() ?? 'NEGOTIATION',
              createdAt: row['created_at']?.toString() ?? '',
              url: '/deals',
            );
          }).toList();
        } catch (_) {}
      }

      final total = contacts.length + materials.length + requirements.length + offers.length + deals.length;
      if (total > 0) {
        return GlobalSearchResults(
          contacts: contacts,
          materials: materials,
          requirements: requirements,
          offers: offers,
          deals: deals,
          totalCount: total,
        );
      }
    } catch (_) {
      // Handled below
    }

    // 3. Fallback: If both REST and Supabase PostgREST direct access are unavailable or restricted
    throw const SearchUnavailableException(
      'Global search REST contract (/api/v1/broker/search) is pending backend exposure. Please retry or contact desk admin.',
      'RB-SRCH-UNAVAILABLE-01',
    );
  }

  /// Returns recent authorized contacts with verified mobile for Floating Speed-Dial.
  Future<List<QuickDialContactItem>> getQuickDialContacts() async {
    try {
      final response = await apiClient.get('/broker/search/quick-dial');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          final list = data['data'] as List<dynamic>? ?? [];
          return list
              .map((e) => QuickDialContactItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {
      // Fallback: Query Supabase crm_contacts directly
    }

    try {
      final client = supabase;
      if (client == null) return const [];
      final currentBrokerId = client.auth.currentUser?.id;
      var query = client
          .from('crm_contacts')
          .select('id, role, users!inner(name, mobile), companies!inner(name, is_verified)');
      if (currentBrokerId != null) {
        query = query.eq('broker_id', currentBrokerId);
      }
      final rows = await query.limit(10);
      return (rows as List<dynamic>).map((r) {
        final user = r['users'] as Map<String, dynamic>? ?? {};
        final comp = r['companies'] as Map<String, dynamic>? ?? {};
        return QuickDialContactItem(
          id: r['id']?.toString() ?? '',
          name: user['name']?.toString() ?? 'Unnamed Contact',
          companyName: comp['name']?.toString() ?? 'Business Partner',
          role: (r['role']?.toString() ?? 'buyer').toLowerCase() == 'seller' ? 'Seller' : 'Buyer',
          mobile: user['mobile']?.toString() ?? '',
          formattedMobile: user['mobile']?.toString() ?? '',
          isVerified: comp['is_verified'] is bool ? comp['is_verified'] : false,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Retrieves privately stored recent search history from secure device storage.
  Future<List<String>> getRecentSearches() async {
    try {
      final raw = await storage.read(key: _recentSearchesKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).take(_maxRecentSearches).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Adds a query to secure device search history.
  Future<List<String>> addRecentSearch(String query) async {
    final clean = sanitizeQuery(query);
    if (clean.length < 2) return getRecentSearches();

    try {
      final current = await getRecentSearches();
      final updated = [clean, ...current.where((s) => s.toLowerCase() != clean.toLowerCase())];
      final capped = updated.take(_maxRecentSearches).toList();
      await storage.write(key: _recentSearchesKey, value: jsonEncode(capped));
      return capped;
    } catch (_) {
      return const [];
    }
  }

  /// Removes an individual query from recent search history.
  Future<List<String>> removeRecentSearch(String query) async {
    try {
      final current = await getRecentSearches();
      final updated = current.where((s) => s.toLowerCase() != query.toLowerCase()).toList();
      await storage.write(key: _recentSearchesKey, value: jsonEncode(updated));
      return updated;
    } catch (_) {
      return const [];
    }
  }

  /// Clears all recent searches from secure storage.
  Future<void> clearRecentSearches() async {
    try {
      await storage.delete(key: _recentSearchesKey);
    } catch (_) {}
  }
}
