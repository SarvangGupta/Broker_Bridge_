import 'dart:io';
import '../domain/cheque_leaf_data.dart';
import '../domain/gst_certificate_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/security/session_guard.dart';
import '../domain/directory_contact.dart';
import '../utils/phone_utils.dart';

/// Sealed hierarchy for Directory API responses.
sealed class DirectoryDataResult<T> {
  const DirectoryDataResult();
}

class DirectorySuccess<T> extends DirectoryDataResult<T> {
  final T data;
  const DirectorySuccess(this.data);
}

class DirectoryUnavailable<T> extends DirectoryDataResult<T> {
  final String contractNotice;
  const DirectoryUnavailable({required this.contractNotice});
}

class DirectoryError<T> extends DirectoryDataResult<T> {
  final String message;
  final String? code;
  final bool isDuplicate;
  final DuplicateCheckResult? duplicateInfo;

  const DirectoryError({
    required this.message,
    this.code,
    this.isDuplicate = false,
    this.duplicateInfo,
  });
}

class DirectoryUnauthorized<T> extends DirectoryDataResult<T> {
  final String message;
  const DirectoryUnauthorized({
    this.message = 'Authentication session expired. Please sign in again.',
  });
}

/// Directory list payload grouping contacts and summary stats.
class DirectoryListPayload {
  final List<DirectoryContact> contacts;

  /// Stats over all of the broker's contacts; sent with the first page only.
  final DirectorySummaryStats? stats;

  /// More rows exist after this page; continue with [nextCursor].
  final bool hasMore;
  final String? nextCursor;

  const DirectoryListPayload({
    required this.contacts,
    this.stats,
    this.hasMore = false,
    this.nextCursor,
  });
}

/// Keyset position after the last row of a page: `crm_contacts.created_at`
/// plus `id` (the list order). Wire format `<created_at>|<id>`, shared with
/// the API so either path can continue a list started by the other.
@immutable
class DirectoryCursor {
  final String createdAt;
  final String id;

  const DirectoryCursor(this.createdAt, this.id);

  static final _timestamp = RegExp(
    r'^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}(:?\d{2})?)?$',
  );

  static DirectoryCursor? tryParse(String? raw) {
    if (raw == null) return null;
    final sep = raw.lastIndexOf('|');
    if (sep <= 0) return null;
    final createdAt = raw.substring(0, sep).trim();
    final id = raw.substring(sep + 1).trim();
    if (!DirectoryContact.isUuid(id) || !_timestamp.hasMatch(createdAt)) return null;
    return DirectoryCursor(createdAt, id);
  }

  static DirectoryCursor? fromRow(Map<String, dynamic> row) =>
      tryParse('${row['created_at']}|${row['id']}');

  String encode() => '$createdAt|$id';
}

/// Open mandate counts keyed by company id.
class MandateCounts {
  final Map<String, int> requirements;
  final Map<String, int> offers;
  final Map<String, int> deals;

  const MandateCounts({
    this.requirements = const {},
    this.offers = const {},
    this.deals = const {},
  });

  int totalFor(String companyId) =>
      (requirements[companyId] ?? 0) + (offers[companyId] ?? 0) + (deals[companyId] ?? 0);
}

/// Authoritative repository for broker counterparty directory.
class DirectoryRepository {
  final ApiClient? _customApiClient;
  final SupabaseClient? _customSupabase;
  final SecureStorageService _storage;

  DirectoryRepository({
    ApiClient? apiClient,
    SupabaseClient? supabase,
    SecureStorageService? storage,
  })  : _customApiClient = apiClient,
        _customSupabase = supabase,
        _storage = storage ?? SecureStorageService();

  ApiClient get _apiClient =>
      _customApiClient ?? ApiClient(storage: _storage);

  SupabaseClient? get _supabase {
    if (_customSupabase != null) return _customSupabase;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // Supabase access points (overridable in tests; production uses PostgREST).
  // --------------------------------------------------------------------------

  /// Signed-in broker's user id, or null without a valid session.
  @visibleForTesting
  String? activeBrokerId() {
    final session = _supabase?.auth.currentSession;
    if (session == null || session.isExpired) return null;
    return session.user.id;
  }

  /// The broker's CRM contacts whose user has one of [mobiles]. Throws on error.
  /// Filters on the embedded `users` resource (`users.mobile=in.(…)`); a
  /// top-level `or=(users.mobile.eq…)` is rejected by PostgREST (PGRST100).
  @visibleForTesting
  Future<List<Map<String, dynamic>>> queryContactsByMobile(
    String brokerId,
    List<String> mobiles,
  ) async {
    final rows = await _supabase!
        .from('crm_contacts')
        .select('id, removed_at, users!user_id!inner(id, name, mobile, role), companies(name)')
        .eq('broker_id', brokerId)
        .inFilter('users.mobile', mobiles)
        .limit(1);
    return (rows as List).whereType<Map<String, dynamic>>().toList();
  }

  /// Master district/state names keyed by id, for ids stored on companies.
  /// Throws on error.
  @visibleForTesting
  Future<Map<String, String>> fetchLocationNames(Set<String> ids) async {
    final client = _supabase!;
    final list = ids.toList();
    final results = await Future.wait([
      client.from('master_districts').select('id, name').inFilter('id', list),
      client.from('master_states').select('id, name').inFilter('id', list),
    ]);
    return {
      for (final rows in results)
        for (final r in (rows as List).whereType<Map<String, dynamic>>())
          if (r['name'] != null) r['id'].toString(): r['name'].toString(),
    };
  }

  /// Creates the company, the user and the broker's CRM link; returns the
  /// `crm_contacts.id`. `created_by` defaults to `auth.uid()` server-side,
  /// which makes the new rows readable to the broker. Throws on error.
  @visibleForTesting
  Future<String> insertContactRecords(
    String brokerId,
    CreateContactInput input,
    String normalizedMobile,
  ) async {
    final client = _supabase!;
    final compData = <String, dynamic>{
      'name': input.companyName.trim(),
      'district_id': input.city?.trim(),
      'state_id': input.state?.trim(),
      'status': true,
      'is_verified': input.isBrokerVerified,
      'trust_score': input.isBrokerVerified ? 100 : 80,
    };

    if (input.gstin != null && input.gstin!.trim().isNotEmpty) {
      compData['gst'] = input.gstin!.trim().toUpperCase();
    }
    if (input.legalName != null && input.legalName!.trim().isNotEmpty) {
      compData['legal_name'] = input.legalName!.trim();
    }
    if (input.tradeName != null && input.tradeName!.trim().isNotEmpty) {
      compData['trade_name'] = input.tradeName!.trim();
    }
    if (input.constitution != null && input.constitution!.trim().isNotEmpty) {
      compData['constitution'] = input.constitution!.trim();
    }
    if (input.address != null && input.address!.trim().isNotEmpty) {
      compData['principal_address'] = input.address!.trim();
    }
    if (input.gstRegistrationDate != null && input.gstRegistrationDate!.trim().isNotEmpty) {
      compData['registration_date'] = input.gstRegistrationDate!.trim();
    }
    compData['gst_verification_status'] = input.gstVerificationStatus;
    if (input.gstCertificateUrl != null) {
      compData['gst_certificate_url'] = input.gstCertificateUrl;
    }
    if (input.isBrokerVerified) {
      compData['gst_verified_by'] = brokerId;
      compData['gst_verified_at'] = DateTime.now().toIso8601String();
    }

    if (input.hasChequeLeaf && input.bankAccountNumber != null && input.bankAccountNumber!.trim().isNotEmpty) {
      compData['bank_holder_name'] = input.bankHolderName?.trim();
      compData['bank_name'] = input.bankName?.trim();
      compData['bank_account_number'] = input.bankAccountNumber?.trim();
      compData['bank_ifsc'] = input.bankIfsc?.trim().toUpperCase();
      compData['bank_branch'] = input.bankBranch?.trim();
      compData['bank_cheque_url'] = input.bankChequeUrl;
      compData['bank_verification_status'] = CounterpartyBankStatus.chequeLeafProvided;
      compData['bank_is_verified'] = false;
      compData['bank_recorded_by'] = brokerId;
      compData['bank_recorded_at'] = DateTime.now().toIso8601String();
    }

    final compRes = await client
        .from('companies')
        .insert(compData)
        .select('id')
        .single();
    final companyId = compRes['id'] as String;

    final userRes = await client
        .from('users')
        .insert({
          'name': input.name.trim(),
          'mobile': normalizedMobile,
          'email': input.email?.trim(),
          'role': input.role.apiValue,
          'status': true,
          'company_id': companyId,
        })
        .select('id')
        .single();

    final contactRes = await client
        .from('crm_contacts')
        .insert({
          'broker_id': brokerId,
          'company_id': companyId,
          'user_id': userRes['id'] as String,
          'last_activity_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    if (input.gstVerificationStatus == CounterpartyGstStatus.gstPending && input.gstin != null) {
      try {
        await client.from('counterparty_verification_requests').insert({
          'company_id': companyId,
          'broker_id': brokerId,
          'role': input.role.apiValue,
          'gstin': input.gstin!.trim().toUpperCase(),
          'legal_name': input.legalName?.trim(),
          'trade_name': input.tradeName?.trim() ?? input.companyName.trim(),
          'status': 'pending',
        });
      } catch (e) {
        debugPrint('Counterparty verification request notice: $e');
      }
    }

    return contactRes['id'] as String;
  }

  @visibleForTesting
  Future<void> insertInitialNote(String contactId, String notes) async {
    await _supabase!.from('crm_activities').insert({
      'contact_id': contactId,
      'type': 'Note',
      'notes': notes,
    });
  }

  /// Page size used by the directory screen.
  static const int directoryPageSize = 30;

  /// Rows per request for a full (unpaged) scan; under PostgREST's 1000-row
  /// response cap, which silently truncated the previous single query.
  static const int _scanChunk = 500;

  /// A filtered page (status/search) scans at most this many requests before
  /// returning what it found; `hasMore` lets the screen continue.
  static const int _maxScanRequests = 5;

  /// One keyset page of the broker's contacts, newest first. [role] is pushed
  /// down to PostgREST; status and search are applied by the caller (they
  /// span users and companies, which PostgREST cannot OR across). Throws.
  @visibleForTesting
  Future<List<Map<String, dynamic>>> queryContactRows(
    String brokerId, {
    String? role,
    DirectoryCursor? after,
    required int limit,
  }) async {
    final users = role == null ? 'users!user_id' : 'users!user_id!inner';
    var query = _supabase!
        .from('crm_contacts')
        .select(
          'id, broker_id, user_id, company_id, last_activity_at, created_at, '
          '$users(id, name, mobile, email, role, status), '
          'companies(id, name, status, is_verified, trust_score, district_id, state_id)',
        )
        .eq('broker_id', brokerId)
        .filter('removed_at', 'is', 'null');
    // Same rule as ContactRole.fromString: anything but "seller" is a buyer.
    if (role == 'seller') query = query.ilike('users.role', 'seller');
    if (role == 'buyer') {
      query = query.or('role.is.null,role.not.ilike.seller', referencedTable: 'users');
    }
    if (after != null) {
      final ts = after.createdAt;
      query = query.or('created_at.lt."$ts",and(created_at.eq."$ts",id.lt.${after.id})');
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);
    return (rows as List).whereType<Map<String, dynamic>>().toList();
  }

  /// Open requirements, open offers and active deals of this broker for
  /// [companyIds]. Throws.
  @visibleForTesting
  Future<MandateCounts> fetchMandateCounts(String brokerId, List<String> companyIds) async {
    final client = _supabase!;
    final reqs = <String, int>{};
    final offers = <String, int>{};
    final deals = <String, int>{};
    void bump(Map<String, int> m, Object? id) {
      if (id != null) m[id.toString()] = (m[id.toString()] ?? 0) + 1;
    }

    // Chunked so the id list never makes an oversized URL.
    for (var i = 0; i < companyIds.length; i += 100) {
      final ids = companyIds.sublist(i, (i + 100).clamp(0, companyIds.length));
      final inList = ids.join(',');
      final results = await Future.wait([
        _fetchAll((from, to) => client
            .from('requirements')
            .select('id, company_id')
            .eq('broker_id', brokerId)
            .inFilter('company_id', ids)
            .inFilter('status', const ['Open', 'Partially Fulfilled'])
            .order('id', ascending: true)
            .range(from, to)),
        _fetchAll((from, to) => client
            .from('availabilities')
            .select('id, company_id')
            .eq('broker_id', brokerId)
            .inFilter('company_id', ids)
            .eq('status', 'Open')
            .order('id', ascending: true)
            .range(from, to)),
        _fetchAll((from, to) => client
            .from('deals')
            .select('id, buyer_id, seller_id')
            .eq('broker_id', brokerId)
            .or('buyer_id.in.($inList),seller_id.in.($inList)')
            .not('status', 'in', '("Closed","Cancelled")')
            .order('id', ascending: true)
            .range(from, to)),
      ]);
      for (final r in results[0]) {
        bump(reqs, r['company_id']);
      }
      for (final a in results[1]) {
        bump(offers, a['company_id']);
      }
      for (final d in results[2]) {
        bump(deals, d['buyer_id']);
        if (d['seller_id'] != d['buyer_id']) bump(deals, d['seller_id']);
      }
    }
    return MandateCounts(requirements: reqs, offers: offers, deals: deals);
  }

  /// Summary stats over ALL of the broker's contacts (not just loaded pages),
  /// from a light projection read in chunks. Throws.
  @visibleForTesting
  Future<DirectorySummaryStats> fetchDirectoryStats(String brokerId) async {
    final client = _supabase!;
    final rows = await _fetchAll((from, to) => client
        .from('crm_contacts')
        .select('id, company_id, users!user_id(role, status), companies(status)')
        .eq('broker_id', brokerId)
        .filter('removed_at', 'is', 'null')
        .order('id', ascending: true)
        .range(from, to));
    final companyIds = {
      for (final r in rows)
        if (r['company_id'] != null) r['company_id'].toString(),
    }.toList();
    final counts = await fetchMandateCounts(brokerId, companyIds);

    var buyers = 0, sellers = 0, mandates = 0;
    for (final r in rows) {
      final u = r['users'] as Map<String, dynamic>? ?? const {};
      final c = r['companies'] as Map<String, dynamic>? ?? const {};
      final active = (u['status'] as bool? ?? true) && (c['status'] as bool? ?? true);
      if (active) {
        ContactRole.fromString(u['role']?.toString()) == ContactRole.seller ? sellers++ : buyers++;
      }
      mandates += counts.totalFor(r['company_id']?.toString() ?? '');
    }
    return DirectorySummaryStats(
      totalContacts: rows.length,
      buyersCount: buyers,
      sellersCount: sellers,
      activeMandatesCount: mandates,
    );
  }

  /// Reads every row of a ranged query, 1000 at a time (PostgREST's cap).
  static Future<List<Map<String, dynamic>>> _fetchAll(
    Future<List<Map<String, dynamic>>> Function(int from, int to) page,
  ) async {
    const size = 1000;
    final all = <Map<String, dynamic>>[];
    for (var from = 0;; from += size) {
      final rows = await page(from, from + size - 1);
      all.addAll(rows);
      if (rows.length < size) return all;
    }
  }

  static DirectoryContact _contactFromRow(Map<String, dynamic> item) {
    final u = item['users'] as Map<String, dynamic>? ?? {};
    final c = item['companies'] as Map<String, dynamic>? ?? {};
    return DirectoryContact(
      id: item['id']?.toString() ?? '',
      userId: item['user_id']?.toString() ?? '',
      companyId: item['company_id']?.toString() ?? '',
      name: u['name']?.toString() ?? 'Unnamed Contact',
      companyName: c['name']?.toString() ?? 'Individual Counterparty',
      mobile: u['mobile']?.toString() ?? '',
      email: u['email']?.toString(),
      role: ContactRole.fromString(u['role']?.toString()),
      status: (u['status'] as bool? ?? true) && (c['status'] as bool? ?? true),
      isVerified: c['is_verified'] as bool? ?? false,
      trustScore: (c['trust_score'] as num? ?? 100).toInt(),
      city: c['district_id']?.toString(),
      state: c['state_id']?.toString(),
      createdAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.now(),
      gstin: c['gst']?.toString() ?? c['gstin']?.toString(),
      legalName: c['legal_name']?.toString(),
      tradeName: c['trade_name']?.toString(),
      constitution: c['constitution']?.toString(),
      address: c['principal_address']?.toString() ?? c['address']?.toString(),
      gstVerificationStatus: c['gst_verification_status']?.toString() ?? CounterpartyGstStatus.unverified,
      gstCertificateUrl: c['gst_certificate_url']?.toString(),
      gstVerifiedBy: c['gst_verified_by']?.toString(),
      gstVerifiedAt: c['gst_verified_at'] != null ? DateTime.tryParse(c['gst_verified_at'].toString()) : null,
      bankHolderName: c['bank_holder_name']?.toString(),
      bankName: c['bank_name']?.toString(),
      bankAccountNumber: c['bank_account_number']?.toString(),
      bankIfsc: c['bank_ifsc']?.toString(),
      bankBranch: c['bank_branch']?.toString(),
      bankChequeUrl: c['bank_cheque_url']?.toString(),
      bankVerificationStatus: c['bank_verification_status']?.toString() ?? CounterpartyBankStatus.unverified,
      bankRecordedBy: c['bank_recorded_by']?.toString(),
      bankRecordedAt: c['bank_recorded_at'] != null ? DateTime.tryParse(c['bank_recorded_at'].toString()) : null,
    );
  }

  /// A page from the direct path. Rows are read in keyset order (role pushed
  /// down) and status/search applied with the same rules as the screen.
  /// Every scanned row is either returned or skipped as a non-match, and the
  /// cursor is the last row scanned, so pages never repeat or omit a contact.
  Future<DirectoryListPayload> _directPage(
    String brokerId, {
    String? role,
    String? search,
    String? status,
    int? limit,
    DirectoryCursor? after,
  }) async {
    final roleFilter = role == 'buyer' || role == 'seller' ? role : null;
    final chunk = limit ?? _scanChunk;
    final matches = <DirectoryContact>[];
    var scanAfter = after;
    var exhausted = false;

    for (var requests = 1;; requests++) {
      // One extra row tells whether anything follows this chunk.
      final rows = await queryContactRows(
        brokerId,
        role: roleFilter,
        after: scanAfter,
        limit: chunk + 1,
      );
      final scanned = rows.length > chunk ? rows.sublist(0, chunk) : rows;
      final contacts = await _withLocationNames(scanned.map(_contactFromRow).toList());
      matches.addAll(
        contacts.where((c) => c.matchesFilters(role: role, status: status, search: search)),
      );
      if (rows.length <= chunk) {
        exhausted = true;
        break;
      }
      scanAfter = DirectoryCursor.fromRow(scanned.last);
      if (scanAfter == null) {
        throw StateError('Directory row without a valid created_at/id cursor');
      }
      if (limit != null && (matches.length >= limit || requests >= _maxScanRequests)) break;
    }

    var counted = matches;
    if (matches.isNotEmpty) {
      try {
        final counts = await fetchMandateCounts(
          brokerId,
          matches.map((c) => c.companyId).where((id) => id.isNotEmpty).toSet().toList(),
        );
        counted = [
          for (final c in matches)
            c.copyWith(
              openRequirementsCount: counts.requirements[c.companyId] ?? 0,
              availableOffersCount: counts.offers[c.companyId] ?? 0,
              activeDealsCount: counts.deals[c.companyId] ?? 0,
            ),
        ];
      } catch (e) {
        debugPrint('Directory mandate counts unavailable: $e');
      }
    }

    DirectorySummaryStats? stats;
    if (after == null) {
      try {
        stats = await fetchDirectoryStats(brokerId);
      } catch (e) {
        debugPrint('Directory stats unavailable: $e');
        stats = DirectorySummaryStats.fromContacts(counted);
      }
    }

    return DirectoryListPayload(
      contacts: counted,
      stats: stats,
      hasMore: !exhausted,
      nextCursor: exhausted ? null : scanAfter!.encode(),
    );
  }

  /// The API authenticates with the stored bearer token, which sign-in saves
  /// once; Supabase refreshes its session but not that copy. Sync it before a
  /// REST call so a valid session never sends an expired token (the API
  /// client clears the stored session on any 401). Without a valid session
  /// the REST call is skipped and the direct path reports the sign-in issue.
  Future<bool> _restAuthReady() async {
    final client = _supabase;
    if (client == null) return true;
    final session = client.auth.currentSession;
    if (session == null || session.isExpired) return false;
    try {
      if (await _storage.getToken() != session.accessToken) {
        await _storage.saveToken(session.accessToken);
      }
    } catch (e) {
      debugPrint('Directory API token sync failed: $e');
    }
    return true;
  }

  /// Adds resolved master names for location values stored as UUIDs. If the
  /// lookup fails the contacts are returned as-is (labels never show UUIDs).
  Future<List<DirectoryContact>> _withLocationNames(List<DirectoryContact> contacts) async {
    final ids = <String>{
      for (final c in contacts)
        for (final v in [c.city, c.state])
          if (DirectoryContact.isUuid(v)) v!.trim(),
    };
    if (ids.isEmpty) return contacts;
    try {
      final names = await fetchLocationNames(ids);
      return [
        for (final c in contacts)
          c.copyWith(cityName: names[c.city?.trim()], stateName: names[c.state?.trim()]),
      ];
    } catch (e) {
      debugPrint('Directory location names unavailable: $e');
      return contacts;
    }
  }

  /// Load counterparty contacts with optional filters.
  ///
  /// With [limit], returns one page (newest first) and a cursor for the next;
  /// pass that back as [cursor] to continue. Without [limit] the full list is
  /// returned (broadcast recipient selection relies on that).
  Future<DirectoryDataResult<DirectoryListPayload>> getContacts({
    String? role, // 'all' | 'buyer' | 'seller'
    String? search,
    String? status, // 'all' | 'active' | 'inactive'
    int? limit,
    String? cursor,
  }) async {
    final after = DirectoryCursor.tryParse(cursor);
    if (cursor != null && after == null) {
      return const DirectoryError(message: 'Could not continue the list. Pull to refresh.');
    }

    // 0. Wait for a usable session (startup/resume refresh) before any request.
    if (activeBrokerId() == null && _supabase != null) {
      switch (await SessionGuard.ensureValidSession(_supabase, storage: _storage)) {
        case SessionCheck.signedOut:
          return const DirectoryUnauthorized();
        case SessionCheck.offline:
          return const DirectoryError(
            message: 'Could not reach the server to restore your session. Check your connection and retry.',
          );
        case SessionCheck.valid:
          break;
      }
    }

    // 1. Attempt authoritative Next.js REST endpoint
    if (await _restAuthReady()) {
      try {
        final response = await _apiClient.get(
          '/broker/directory',
          queryParameters: {
            if (role != null && role != 'all') 'role': role,
            if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
            if (status != null && status != 'all') 'status': status,
            'limit': ?limit,
            'cursor': ?cursor,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          if (data is Map<String, dynamic>) {
            if (data['success'] == false) {
              return DirectoryError(
                message: data['error']?.toString() ?? 'Failed to load directory contacts',
              );
            }

            final payloadData = data['data'] as Map<String, dynamic>? ?? {};
            final rawList = payloadData['contacts'] as List<dynamic>? ?? [];
            final contacts = await _withLocationNames(
              rawList
                  .whereType<Map<String, dynamic>>()
                  .map(DirectoryContact.fromJson)
                  .toList(),
            );

            // Stats come with the first page only; a server without paging
            // returns the whole list and no pageInfo (hasMore stays false).
            final statsMap = payloadData['stats'];
            final pageInfo = payloadData['pageInfo'];
            final next = pageInfo is Map ? pageInfo['nextCursor']?.toString() : null;
            final hasMore = pageInfo is Map &&
                pageInfo['hasMore'] == true &&
                DirectoryCursor.tryParse(next) != null;

            return DirectorySuccess(
              DirectoryListPayload(
                contacts: contacts,
                stats: statsMap is Map<String, dynamic>
                    ? DirectorySummaryStats.fromJson(statsMap)
                    : (cursor == null ? DirectorySummaryStats.fromContacts(contacts) : null),
                hasMore: hasMore,
                nextCursor: hasMore ? next : null,
              ),
            );
          }
        }
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 401) {
          return const DirectoryUnauthorized();
        }
        debugPrint('REST directory notice: ${dioErr.message}');
      } catch (e) {
        debugPrint('REST directory query error: $e');
      }
    }

    // 2. Direct Supabase PostgREST query if user has an active session
    try {
      final brokerId = activeBrokerId();
      if (brokerId != null) {
        return DirectorySuccess(
          await _directPage(
            brokerId,
            role: role,
            search: search,
            status: status,
            limit: limit,
            after: after,
          ),
        );
      }
    } on PostgrestException catch (dbErr) {
      debugPrint('Supabase direct directory query notice: ${dbErr.code} ${dbErr.message}');
      if (dbErr.code == 'PGRST301' || dbErr.message.toLowerCase().contains('jwt')) {
        return const DirectoryUnauthorized();
      }
      return const DirectoryError(message: 'Could not load your directory. Pull to refresh or try again.');
    } catch (dbErr) {
      debugPrint('Supabase direct directory query notice: $dbErr');
      return const DirectoryError(
        message: 'Could not load your directory. Check your connection and try again.',
      );
    }

    // A client without a valid session is a sign-in problem, not a missing backend.
    if (_supabase != null) return const DirectoryUnauthorized();

    // 3. Honest Unavailable State (when REST route is not mounted and DB is unreachable)
    return const DirectoryUnavailable(
      contractNotice:
          'Authoritative endpoint /api/v1/broker/directory is pending backend exposure. '
          'Contact data is not shown to prevent presenting fabricated or unverified counterparty records.',
    );
  }

  /// Server-side duplicate prevention check against normalized mobile and GSTIN,
  /// categorizing into Case A (active), Case B (previously removed), Case C (shared available), or Case D (none).
  Future<DuplicateCheckResult> checkDuplicate({
    required String mobile,
    required String companyName,
    String? gstin,
  }) async {
    final phoneRes = PhoneUtils.validateAndNormalize(mobile);
    if (!phoneRes.isValid && (gstin == null || gstin.trim().isEmpty)) {
      return DuplicateCheckResult.none();
    }

    final brokerId = activeBrokerId();

    // 1. First, check if this broker already has this counterparty in crm_contacts (Cases A & B)
    if (brokerId != null && _supabase != null) {
      try {
        final client = _supabase!;
        // Query by GSTIN under this broker
        if (gstin != null && gstin.trim().isNotEmpty) {
          final gstContacts = await client
              .from('crm_contacts')
              .select('id, removed_at, user_id, company_id, users!user_id(id, name, mobile, role, status), companies!company_id(id, name, gst, status)')
              .eq('broker_id', brokerId)
              .ilike('companies.gst', gstin.trim().toUpperCase())
              .limit(1);

          if (gstContacts.isNotEmpty) {
            final row = gstContacts.first;
            final u = row['users'] as Map<String, dynamic>? ?? {};
            final c = row['companies'] as Map<String, dynamic>? ?? {};
            final isRemoved = row['removed_at'] != null;
            final isActive = !isRemoved && (u['status'] as bool? ?? true) && (c['status'] as bool? ?? true);
            return DuplicateCheckResult(
              isDuplicate: true,
              matchType: 'gstin',
              duplicateCase: isActive ? DuplicateCase.activeInDirectory : DuplicateCase.previouslyRemoved,
              existingContactId: row['id']?.toString(),
              existingUserId: u['id']?.toString() ?? row['user_id']?.toString(),
              existingCompanyId: c['id']?.toString() ?? row['company_id']?.toString(),
              existingContactName: u['name']?.toString(),
              existingCompanyName: c['name']?.toString(),
              existingMobile: u['mobile']?.toString(),
              existingGstin: c['gst']?.toString() ?? gstin.trim().toUpperCase(),
              existingRole: u['role']?.toString(),
            );
          }
        }

        // Query by mobile under this broker
        if (phoneRes.isValid) {
          final mobileContacts = await queryContactsByMobile(brokerId, _mobileVariants(phoneRes));
          if (mobileContacts.isNotEmpty) {
            final row = mobileContacts.first;
            final u = row['users'] as Map<String, dynamic>? ?? {};
            final c = row['companies'] as Map<String, dynamic>? ?? {};
            final isRemoved = row['removed_at'] != null;
            final isActive = !isRemoved && (u['status'] as bool? ?? true) && (c['status'] as bool? ?? true);
            return DuplicateCheckResult(
              isDuplicate: true,
              matchType: 'exact_mobile',
              duplicateCase: isActive ? DuplicateCase.activeInDirectory : DuplicateCase.previouslyRemoved,
              existingContactId: row['id']?.toString(),
              existingUserId: u['id']?.toString() ?? row['user_id']?.toString(),
              existingCompanyId: c['id']?.toString() ?? row['company_id']?.toString(),
              existingContactName: u['name']?.toString(),
              existingCompanyName: c['name']?.toString(),
              existingMobile: u['mobile']?.toString(),
              existingGstin: c['gst']?.toString(),
              existingRole: u['role']?.toString(),
            );
          }
        }
      } catch (e) {
        debugPrint('Broker duplicate check notice: $e');
      }
    }

    // 2. Second, check if counterparty exists in shared database (companies or users) not linked to this broker (Case C)
    if (_supabase != null) {
      try {
        final client = _supabase!;
        // Check companies by GSTIN
        if (gstin != null && gstin.trim().isNotEmpty) {
          final sharedGst = await client
              .from('companies')
              .select('id, name, gst, status')
              .eq('gst', gstin.trim().toUpperCase())
              .limit(1);

          if (sharedGst.isNotEmpty) {
            final c = sharedGst.first;
            return DuplicateCheckResult(
              isDuplicate: true,
              matchType: 'gstin',
              duplicateCase: DuplicateCase.sharedAvailable,
              existingCompanyId: c['id']?.toString(),
              existingCompanyName: c['name']?.toString(),
              existingGstin: c['gst']?.toString() ?? gstin.trim().toUpperCase(),
            );
          }
        }

        // Check users by mobile
        if (phoneRes.isValid) {
          final sharedUsers = await client
              .from('users')
              .select('id, name, mobile, role, status')
              .inFilter('mobile', _mobileVariants(phoneRes))
              .limit(1);

          if (sharedUsers.isNotEmpty) {
            final u = sharedUsers.first;
            return DuplicateCheckResult(
              isDuplicate: true,
              matchType: 'exact_mobile',
              duplicateCase: DuplicateCase.sharedAvailable,
              existingUserId: u['id']?.toString(),
              existingContactName: u['name']?.toString(),
              existingMobile: u['mobile']?.toString(),
              existingRole: u['role']?.toString(),
            );
          }
        }
      } catch (e) {
        debugPrint('Shared duplicate check notice: $e');
      }
    }

    // 3. Fallback: REST check if online
    if (await _restAuthReady()) {
      try {
        final response = await _apiClient.post(
          '/broker/directory/check-duplicate',
          data: {
            if (phoneRes.isValid) 'mobile': phoneRes.normalized,
            'companyName': companyName.trim(),
            if (gstin != null && gstin.trim().isNotEmpty) 'gstin': gstin.trim().toUpperCase(),
          },
        );

        if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
          return DuplicateCheckResult.fromJson(response.data as Map<String, dynamic>);
        }
      } catch (_) {
        // Fallback: check against local/Supabase database
      }
    }

    return DuplicateCheckResult.none();
  }

  /// The `error` of a JSON error body. A missing route answers with an HTML
  /// page (a String); indexing that inside the `on DioException` handler threw
  /// past the sibling `catch` and the save never reached the Supabase path.
  static String? _serverError(DioException e) {
    final data = e.response?.data;
    return data is Map ? data['error']?.toString() : null;
  }

  /// A duplicate refusal from the API (HTTP 409 / `isDuplicate: true`).
  static bool _isServerDuplicate(DioException e) {
    final data = e.response?.data;
    return e.response?.statusCode == 409 || (data is Map && data['isDuplicate'] == true);
  }

  /// Stored mobiles are `+91XXXXXXXXXX` or the bare 10 digits; match both.
  static List<String> _mobileVariants(PhoneValidationResult p) =>
      {p.normalized, p.rawDigits}.where((m) => m.isNotEmpty).toList();

  static DuplicateCheckResult _duplicateFromRow(Map<String, dynamic> row) {
    final u = row['users'] as Map<String, dynamic>? ?? {};
    final c = row['companies'] as Map<String, dynamic>? ?? {};
    return DuplicateCheckResult(
      isDuplicate: true,
      matchType: 'exact_mobile',
      existingContactName: u['name']?.toString(),
      existingCompanyName: c['name']?.toString(),
      existingMobile: u['mobile']?.toString(),
      existingRole: u['role']?.toString(),
    );
  }

  /// Create a validated counterparty contact record with server-side duplicate prevention.
  Future<DirectoryDataResult<String>> createContact(CreateContactInput input) async {
    // 1. Client-side normalization & validation
    final phoneRes = PhoneUtils.validateAndNormalize(input.mobile);
    if (!phoneRes.isValid) {
      return DirectoryError(message: phoneRes.error ?? 'Invalid mobile number');
    }

    if (input.name.trim().length < 2) {
      return const DirectoryError(message: 'Contact person name must be at least 2 characters');
    }

    if (input.companyName.trim().length < 2) {
      return const DirectoryError(message: 'Company name must be at least 2 characters');
    }

    // 2. Pre-check for duplicate mobile and GSTIN
    final dupCheck = await checkDuplicate(
      mobile: phoneRes.normalized,
      companyName: input.companyName,
      gstin: input.gstin,
    );

    if (dupCheck.isDuplicate) {
      if (dupCheck.duplicateCase == DuplicateCase.activeInDirectory) {
        return DirectoryError(
          message: 'This ${input.role.label} is already in your directory (${dupCheck.existingCompanyName ?? dupCheck.existingContactName ?? 'existing contact'}).',
          isDuplicate: true,
          duplicateInfo: dupCheck,
        );
      } else if (dupCheck.duplicateCase == DuplicateCase.previouslyRemoved) {
        return DirectoryError(
          message: 'This ${input.role.label} already exists in your database. Add them back?',
          isDuplicate: true,
          duplicateInfo: dupCheck,
        );
      } else if (dupCheck.duplicateCase == DuplicateCase.sharedAvailable) {
        return DirectoryError(
          message: 'Found ${dupCheck.existingCompanyName ?? 'counterparty'} in directory. Link to your directory?',
          isDuplicate: true,
          duplicateInfo: dupCheck,
        );
      } else {
        return DirectoryError(
          message: 'A contact with mobile number ${phoneRes.formatted} already exists (${dupCheck.existingCompanyName}). Duplicate creation prevented.',
          isDuplicate: true,
          duplicateInfo: dupCheck,
        );
      }
    }

    // 3. Attempt REST POST
    if (await _restAuthReady()) {
      try {
        final response = await _apiClient.post(
          '/broker/directory',
          data: input.toJson(),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = response.data;
          if (data is Map<String, dynamic>) {
            if (data['success'] == true && data['contactId'] != null) {
              return DirectorySuccess(data['contactId'].toString());
            }
            if (data['isDuplicate'] == true) {
              return DirectoryError(
                message: data['error']?.toString() ?? 'Duplicate contact detected on server',
                isDuplicate: true,
              );
            }
            return DirectoryError(
              message: data['error']?.toString() ?? 'Failed to create contact',
            );
          }
        }
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 401) {
          return const DirectoryUnauthorized();
        }
        final serverError = _serverError(dioErr);
        if (serverError != null) {
          // A 409 duplicate keeps its flag so the form shows it as a duplicate.
          return DirectoryError(message: serverError, isDuplicate: _isServerDuplicate(dioErr));
        }
      } catch (_) {}
    }

    // 4. Supabase direct path (used when the REST route is not deployed)
    final brokerId = activeBrokerId();
    if (brokerId == null) {
      if (_supabase != null) return const DirectoryUnauthorized();
      return const DirectoryUnavailable(
        contractNotice: 'Backend is offline or endpoint /api/v1/broker/directory is unavailable.',
      );
    }

    // Strict duplicate check: if it cannot run, do not risk a duplicate.
    try {
      final existing = await queryContactsByMobile(brokerId, _mobileVariants(phoneRes));
      if (existing.isNotEmpty) {
        final dup = _duplicateFromRow(existing.first);
        return DirectoryError(
          message:
              'A contact with mobile number ${phoneRes.formatted} already exists (${dup.existingCompanyName ?? 'existing contact'}). '
              'Duplicate creation prevented.',
          isDuplicate: true,
          duplicateInfo: dup,
        );
      }
    } catch (e) {
      debugPrint('Duplicate check before create failed: $e');
      return const DirectoryError(
        message: 'Could not check for an existing contact with this mobile number. Please try again.',
      );
    }

    final String contactId;
    try {
      contactId = await insertContactRecords(brokerId, input, phoneRes.normalized);
    } on PostgrestException catch (e) {
      debugPrint('Supabase contact create error: ${e.code} ${e.message}');
      if (e.code == 'PGRST301' || e.message.toLowerCase().contains('jwt')) {
        return const DirectoryUnauthorized();
      }
      return DirectoryError(
        message: e.code == '42501'
            ? 'Your account is not permitted to add this contact.'
            : 'Could not save the contact. Please try again.',
        code: e.code,
      );
    } catch (e) {
      debugPrint('Supabase contact create error: $e');
      return const DirectoryError(
        message: 'Could not save the contact. Check your connection and try again.',
      );
    }

    // The contact is saved; a failed optional note must not turn that into a
    // reported failure (a retry would then create a duplicate).
    final notes = input.notes?.trim() ?? '';
    if (notes.isNotEmpty) {
      try {
        await insertInitialNote(contactId, notes);
      } catch (e) {
        debugPrint('Initial contact note not saved: $e');
      }
    }
    return DirectorySuccess(contactId);
  }

  /// Update an authorized contact record.
  Future<DirectoryDataResult<bool>> updateContact(
    String contactId,
    UpdateContactInput input,
  ) async {
    final phoneRes = PhoneUtils.validateAndNormalize(input.mobile);
    if (!phoneRes.isValid) {
      return DirectoryError(message: phoneRes.error ?? 'Invalid mobile number');
    }

    // 1. Attempt REST PUT
    if (await _restAuthReady()) {
      try {
        final response = await _apiClient.put(
          '/broker/directory/$contactId',
          data: input.toJson(),
        );

        if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          if (data['success'] == true) {
            return const DirectorySuccess(true);
          }
          return DirectoryError(message: data['error']?.toString() ?? 'Update failed');
        }
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 401) {
          return const DirectoryUnauthorized();
        }
        final serverError = _serverError(dioErr);
        if (serverError != null) return DirectoryError(message: serverError);
      } catch (_) {}
    }

    // 2. Direct Supabase update fallback
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null) {
        final contact = await client
            .from('crm_contacts')
            .select('user_id, company_id')
            .eq('id', contactId)
            .single();

        final userId = contact['user_id'] as String?;
        final compId = contact['company_id'] as String?;

        if (userId != null) {
          await client.from('users').update({
            'name': input.name.trim(),
            'mobile': phoneRes.normalized,
            'email': input.email?.trim(),
            'role': input.role.apiValue,
            if (input.status != null) 'status': input.status,
          }).eq('id', userId);
        }

        if (compId != null) {
          final compUpdates = <String, dynamic>{
            'name': input.companyName.trim(),
            'district_id': input.city?.trim(),
            'state_id': input.state?.trim(),
            if (input.status != null) 'status': input.status,
          };

          if (input.gstin != null && input.gstin!.trim().isNotEmpty) {
            compUpdates['gst'] = input.gstin!.trim().toUpperCase();
          }
          if (input.legalName != null && input.legalName!.trim().isNotEmpty) {
            compUpdates['legal_name'] = input.legalName!.trim();
          }
          if (input.tradeName != null && input.tradeName!.trim().isNotEmpty) {
            compUpdates['trade_name'] = input.tradeName!.trim();
          }
          if (input.constitution != null && input.constitution!.trim().isNotEmpty) {
            compUpdates['constitution'] = input.constitution!.trim();
          }
          if (input.address != null && input.address!.trim().isNotEmpty) {
            compUpdates['principal_address'] = input.address!.trim();
          }
          if (input.gstVerificationStatus != null) {
            compUpdates['gst_verification_status'] = input.gstVerificationStatus;
          }
          if (input.gstCertificateUrl != null && input.gstCertificateUrl!.trim().isNotEmpty) {
            compUpdates['gst_certificate_url'] = input.gstCertificateUrl!.trim();
          }
          if (input.gstVerificationStatus == CounterpartyGstStatus.brokerVerified) {
            compUpdates['gst_verified_by'] = session.user.id;
            compUpdates['gst_verified_at'] = DateTime.now().toIso8601String();
            compUpdates['is_verified'] = true;
            compUpdates['trust_score'] = 100;
          }

          if (input.bankAccountNumber != null && input.bankAccountNumber!.trim().isNotEmpty) {
            compUpdates['bank_holder_name'] = input.bankHolderName?.trim();
            compUpdates['bank_name'] = input.bankName?.trim();
            compUpdates['bank_account_number'] = input.bankAccountNumber?.trim();
            compUpdates['bank_ifsc'] = input.bankIfsc?.trim().toUpperCase();
            compUpdates['bank_branch'] = input.bankBranch?.trim();
            compUpdates['bank_cheque_url'] = input.bankChequeUrl;
            compUpdates['bank_verification_status'] = input.bankVerificationStatus ?? CounterpartyBankStatus.chequeLeafProvided;
            compUpdates['bank_recorded_by'] = session.user.id;
            compUpdates['bank_recorded_at'] = DateTime.now().toIso8601String();
          }

          await client.from('companies').update(compUpdates).eq('id', compId);
        }

        await client.from('crm_contacts').update({
          'last_activity_at': DateTime.now().toIso8601String(),
        }).eq('id', contactId);

        return const DirectorySuccess(true);
      }
    } catch (e) {
      debugPrint('Supabase direct contact update error: $e');
    }

    return DirectoryUnavailable(
      contractNotice: 'Backend is offline or endpoint /api/v1/broker/directory/$contactId is unavailable.',
    );
  }

  /// Safely remove a counterparty from this broker's directory (soft removal).
  /// Preserves shared company master records, GST details, bank details, and existing deals/transactions.
  Future<DirectoryDataResult<bool>> removeContact(String contactId) async {
    // 1. Attempt REST DELETE
    if (await _restAuthReady()) {
      try {
        final response = await _apiClient.delete('/broker/directory/$contactId');
        if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          if (data['success'] == true) {
            return const DirectorySuccess(true);
          } else {
            return DirectoryError(
              message: data['error'] as String? ?? 'Failed to remove contact from directory.',
            );
          }
        }
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 401) {
          return const DirectoryUnauthorized();
        }
        final errMap = dioErr.response?.data;
        if (errMap is Map && errMap['error'] != null) {
          return DirectoryError(message: errMap['error'].toString());
        }
        debugPrint('REST remove contact DioException: $dioErr');
      } catch (e) {
        debugPrint('REST remove contact error: $e');
      }
    }

    // 2. Direct Supabase fallback
    try {
      final client = _supabase;
      final brokerId = activeBrokerId();
      if (client != null && brokerId != null) {
        final contact = await client
            .from('crm_contacts')
            .select('id, user_id, company_id')
            .eq('id', contactId)
            .eq('broker_id', brokerId)
            .maybeSingle();

        if (contact == null) {
          return const DirectoryError(message: 'Contact record not found.');
        }

        // Soft-remove the broker's relationship link in crm_contacts.
        // Master company records, users, deals, requirements, and offers remain intact.
        // Preserving the relationship record with removed_at prevents linkAssignedCounterparties
        // from resurrecting explicitly removed contacts.
        await client
            .from('crm_contacts')
            .update({'removed_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', contactId)
            .eq('broker_id', brokerId);

        return const DirectorySuccess(true);
      }
    } catch (e) {
      debugPrint('Remove contact error: $e');
      return DirectoryError(message: 'Failed to remove contact: $e');
    }

    return const DirectoryUnavailable(
      contractNotice: 'Backend is offline or remove endpoint is unavailable.',
    );
  }

  /// Restore a previously removed/inactive counterparty (Case B).
  Future<DirectoryDataResult<String>> restoreContact(String contactId) async {
    try {
      final client = _supabase;
      final brokerId = activeBrokerId();
      if (client != null && brokerId != null) {
        final contact = await client
            .from('crm_contacts')
            .select('id, user_id, company_id')
            .eq('id', contactId)
            .eq('broker_id', brokerId)
            .single();

        final userId = contact['user_id'] as String?;
        final compId = contact['company_id'] as String?;

        if (userId != null) {
          await client.from('users').update({'status': true}).eq('id', userId);
        }
        if (compId != null) {
          await client.from('companies').update({'status': true}).eq('id', compId);
        }

        await client.from('crm_contacts').update({
          'removed_at': null,
          'last_activity_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', contactId).eq('broker_id', brokerId);

        return DirectorySuccess(contactId);
      }
    } catch (e) {
      debugPrint('Restore contact error: $e');
      return DirectoryError(message: 'Failed to restore contact: $e');
    }

    return const DirectoryUnavailable(
      contractNotice: 'Backend is offline or restore endpoint is unavailable.',
    );
  }

  /// Link an existing shared counterparty to this broker desk (Case C).
  /// Preserves private notes from other brokers.
  Future<DirectoryDataResult<String>> linkSharedCounterparty({
    required String companyId,
    String? userId,
    String? notes,
  }) async {
    try {
      final client = _supabase;
      final brokerId = activeBrokerId();
      if (client != null && brokerId != null) {
        final res = await client
            .from('crm_contacts')
            .insert({
              'broker_id': brokerId,
              'company_id': companyId,
              if (userId != null) 'user_id': userId,
              'last_activity_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();

        final newContactId = res['id'] as String;

        if (notes != null && notes.trim().isNotEmpty) {
          await insertInitialNote(newContactId, notes.trim());
        }

        return DirectorySuccess(newContactId);
      }
    } catch (e) {
      debugPrint('Link shared counterparty error: $e');
      return DirectoryError(message: 'Failed to link counterparty: $e');
    }

    return const DirectoryUnavailable(
      contractNotice: 'Backend is offline or linking endpoint is unavailable.',
    );
  }

  /// Toggle contact status (Active / Inactive soft archival).
  Future<DirectoryDataResult<bool>> toggleContactStatus(String contactId) async {
    // The server route is `PATCH …/status` (the app used to POST a
    // non-existent `…/toggle-status`, so every toggle failed first; KI-41).
    if (await _restAuthReady()) {
      try {
        final response = await _apiClient.patch('/broker/directory/$contactId/status');

        if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          if (data['success'] == true) {
            return DirectorySuccess(data['newStatus'] as bool? ?? true);
          }
          return DirectoryError(message: data['error']?.toString() ?? 'Status update failed');
        }
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 401) {
          return const DirectoryUnauthorized();
        }
        final serverError = _serverError(dioErr);
        if (serverError != null) return DirectoryError(message: serverError);
      } catch (_) {}
    }

    // Direct Supabase fallback
    try {
      final client = _supabase;
      if (client != null) {
        final row = await client
            .from('crm_contacts')
            .select('user_id, users!user_id(status)')
            .eq('id', contactId)
            .single();

        final userId = row['user_id'] as String?;
        final currentStatus = (row['users'] as Map<String, dynamic>?)?['status'] as bool? ?? true;
        final newStatus = !currentStatus;

        if (userId != null) {
          await client.from('users').update({'status': newStatus}).eq('id', userId);
        }

        return DirectorySuccess(newStatus);
      }
    } catch (_) {}

    return const DirectoryUnavailable(
      contractNotice: 'Unable to update status: Backend endpoint not reachable.',
    );
  }

  /// Load comprehensive 360-degree contact profile with linked business mandates.
  Future<DirectoryDataResult<ContactDetailsPayload>> getContactDetails(
    String contactId,
  ) async {
    // 1. Attempt REST GET
    if (await _restAuthReady()) {
      try {
        final response = await _apiClient.get('/broker/directory/$contactId');

        if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          if (data['success'] == true && data['data'] is Map<String, dynamic>) {
            final payload = ContactDetailsPayload.fromJson(data['data'] as Map<String, dynamic>);
            final contact = (await _withLocationNames([payload.contact])).single;
            return DirectorySuccess(
              ContactDetailsPayload(
                contact: contact,
                associatedRequirements: payload.associatedRequirements,
                associatedOffers: payload.associatedOffers,
                linkedDeals: payload.linkedDeals,
                activities: payload.activities,
              ),
            );
          }
          return DirectoryError(message: data['error']?.toString() ?? 'Failed to load details');
        }
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 401) {
          return const DirectoryUnauthorized();
        }
        final serverError = _serverError(dioErr);
        if (serverError != null) return DirectoryError(message: serverError);
      } catch (_) {}
    }

    // 2. Direct Supabase query fallback
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null) {
        final brokerId = session.user.id;

        // Fetch core contact
        final contactRow = await client
            .from('crm_contacts')
            .select(
              'id, broker_id, user_id, company_id, last_activity_at, created_at, '
              'users!user_id(id, name, mobile, email, role, status), '
              'companies(id, name, status, is_verified, trust_score, district_id, state_id)',
            )
            .eq('id', contactId)
            .single();

        final u = contactRow['users'] as Map<String, dynamic>? ?? {};
        final c = contactRow['companies'] as Map<String, dynamic>? ?? {};
        final companyId = contactRow['company_id'] as String;

        // Fetch linked requirements
        final reqsRes = await client
            .from('requirements')
            .select('id, quantity, target_price, status, target_date, master_commodities(name)')
            .eq('company_id', companyId)
            .eq('broker_id', brokerId)
            .order('created_at', ascending: false)
            .limit(6);

        final reqs = (reqsRes as List<dynamic>).map((r) {
          final com = (r['master_commodities'] as Map<String, dynamic>?)?['name']?.toString() ?? 'Commodity';
          return LinkedRequirement(
            id: r['id']?.toString() ?? '',
            commodityName: com,
            quantity: (r['quantity'] as num? ?? 0).toDouble(),
            targetPrice: (r['target_price'] as num? ?? 0).toDouble(),
            status: r['status']?.toString() ?? 'Open',
            targetDate: r['target_date']?.toString() ?? '',
          );
        }).toList();

        // Fetch linked offers
        final offersRes = await client
            .from('availabilities')
            .select('id, quantity, asking_price, status, master_commodities(name)')
            .eq('company_id', companyId)
            .eq('broker_id', brokerId)
            .order('created_at', ascending: false)
            .limit(6);

        final offers = (offersRes as List<dynamic>).map((o) {
          final com = (o['master_commodities'] as Map<String, dynamic>?)?['name']?.toString() ?? 'Commodity';
          return LinkedOffer(
            id: o['id']?.toString() ?? '',
            commodityName: com,
            quantity: (o['quantity'] as num? ?? 0).toDouble(),
            price: '₹${o['asking_price'] ?? 0}',
            status: o['status']?.toString() ?? 'Open',
          );
        }).toList();

        // Fetch CRM activities
        final actRes = await client
            .from('crm_activities')
            .select('id, type, notes, created_at')
            .eq('contact_id', contactId)
            .order('created_at', ascending: false)
            .limit(10);

        final activities = (actRes as List<dynamic>).map((a) {
          return ContactActivity(
            id: a['id']?.toString() ?? '',
            type: a['type']?.toString() ?? 'Note',
            notes: a['notes']?.toString() ?? '',
            createdAt: a['created_at']?.toString() ?? '',
          );
        }).toList();

        final contact = DirectoryContact(
          id: contactRow['id']?.toString() ?? '',
          userId: contactRow['user_id']?.toString() ?? '',
          companyId: companyId,
          name: u['name']?.toString() ?? 'Unnamed Contact',
          companyName: c['name']?.toString() ?? 'Individual Counterparty',
          mobile: u['mobile']?.toString() ?? '',
          email: u['email']?.toString(),
          role: ContactRole.fromString(u['role']?.toString()),
          status: (u['status'] as bool? ?? true) && (c['status'] as bool? ?? true),
          isVerified: c['is_verified'] as bool? ?? false,
          trustScore: (c['trust_score'] as num? ?? 100).toInt(),
          city: c['district_id']?.toString(),
          state: c['state_id']?.toString(),
          createdAt: DateTime.tryParse(contactRow['created_at']?.toString() ?? '') ?? DateTime.now(),
          openRequirementsCount: reqs.where((r) => r.status == 'Open').length,
          availableOffersCount: offers.where((o) => o.status == 'Open').length,
          activeDealsCount: 0,
          gstin: c['gst']?.toString() ?? c['gstin']?.toString(),
          legalName: c['legal_name']?.toString(),
          tradeName: c['trade_name']?.toString(),
          constitution: c['constitution']?.toString(),
          address: c['principal_address']?.toString() ?? c['address']?.toString(),
          gstVerificationStatus: c['gst_verification_status']?.toString() ?? CounterpartyGstStatus.unverified,
          gstCertificateUrl: c['gst_certificate_url']?.toString(),
          gstVerifiedBy: c['gst_verified_by']?.toString(),
          gstVerifiedAt: c['gst_verified_at'] != null ? DateTime.tryParse(c['gst_verified_at'].toString()) : null,
          bankHolderName: c['bank_holder_name']?.toString(),
          bankName: c['bank_name']?.toString(),
          bankAccountNumber: c['bank_account_number']?.toString(),
          bankIfsc: c['bank_ifsc']?.toString(),
          bankBranch: c['bank_branch']?.toString(),
          bankChequeUrl: c['bank_cheque_url']?.toString(),
          bankVerificationStatus: c['bank_verification_status']?.toString() ?? CounterpartyBankStatus.unverified,
          bankRecordedBy: c['bank_recorded_by']?.toString(),
          bankRecordedAt: c['bank_recorded_at'] != null ? DateTime.tryParse(c['bank_recorded_at'].toString()) : null,
        );

        final resolvedContact = (await _withLocationNames([contact])).single;

        return DirectorySuccess(
          ContactDetailsPayload(
            contact: resolvedContact,
            associatedRequirements: reqs,
            associatedOffers: offers,
            linkedDeals: const [],
            activities: activities,
          ),
        );
      }
    } catch (e) {
      debugPrint('Supabase direct contact details error: $e');
    }

    return DirectoryUnavailable(
      contractNotice: 'Endpoint /api/v1/broker/directory/$contactId is unavailable.',
    );
  }
  /// Admin review approval or rejection of a counterparty verification request.
  Future<DirectoryDataResult<bool>> reviewCounterpartyVerification({
    required String requestId,
    required bool approve,
    String? reason,
  }) async {
    try {
      if (_supabase != null) {
        await _supabase!.rpc('review_counterparty_verification', params: {
          'p_request_id': requestId,
          'p_approve': approve,
          'p_reason': reason,
        });
        return const DirectorySuccess(true);
      }
      return const DirectorySuccess(true);
    } catch (e) {
      return DirectoryError(message: 'Failed to review verification request: $e');
    }
  }

  /// Uploads certificate or cheque leaf document to private Supabase storage.
  Future<String?> uploadDocument({
    required String filePath,
    required String bucket,
    required String destinationPath,
  }) async {
    try {
      if (_supabase != null) {
        final file = File(filePath);
        if (await file.exists()) {
          final res = await _supabase!.storage.from(bucket).upload(destinationPath, file);
          return res;
        }
      }
      return destinationPath;
    } catch (e) {
      debugPrint('Document upload notice: $e');
      return destinationPath;
    }
  }
}
