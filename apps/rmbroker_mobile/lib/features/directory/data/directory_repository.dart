import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/security/secure_storage_service.dart';
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
  final DirectorySummaryStats stats;

  const DirectoryListPayload({
    required this.contacts,
    required this.stats,
  });
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

  /// Load counterparty contacts with optional filters.
  Future<DirectoryDataResult<DirectoryListPayload>> getContacts({
    String? role, // 'all' | 'buyer' | 'seller'
    String? search,
    String? status, // 'all' | 'active' | 'inactive'
  }) async {
    // 1. Attempt authoritative Next.js REST endpoint
    try {
      final response = await _apiClient.get(
        '/broker/directory',
        queryParameters: {
          if (role != null && role != 'all') 'role': role,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          if (status != null && status != 'all') 'status': status,
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
          final contacts = rawList
              .whereType<Map<String, dynamic>>()
              .map(DirectoryContact.fromJson)
              .toList();

          final statsMap = payloadData['stats'] as Map<String, dynamic>?;
          final stats = statsMap != null
              ? DirectorySummaryStats.fromJson(statsMap)
              : DirectorySummaryStats.fromContacts(contacts);

          return DirectorySuccess(
            DirectoryListPayload(contacts: contacts, stats: stats),
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

    // 2. Direct Supabase PostgREST query if user has an active session
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;

      if (client != null && session != null && !session.isExpired) {
        final brokerId = session.user.id;

        // Fetch raw crm_contacts assigned to caller broker
        final response = await client
            .from('crm_contacts')
            .select(
              'id, broker_id, user_id, company_id, last_activity_at, created_at, '
              'users(id, name, mobile, email, role, status), '
              'companies(id, name, status, is_verified, trust_score, district_id, state_id)',
            )
            .eq('broker_id', brokerId)
            .order('created_at', ascending: false);

        final rawList = response as List<dynamic>;
        final contacts = <DirectoryContact>[];

        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            final u = item['users'] as Map<String, dynamic>? ?? {};
            final c = item['companies'] as Map<String, dynamic>? ?? {};

            contacts.add(
              DirectoryContact(
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
                createdAt: item['created_at'] != null
                    ? DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now()
                    : DateTime.now(),
              ),
            );
          }
        }

        final stats = DirectorySummaryStats.fromContacts(contacts);
        return DirectorySuccess(
          DirectoryListPayload(contacts: contacts, stats: stats),
        );
      }
    } catch (dbErr) {
      debugPrint('Supabase direct directory query notice: $dbErr');
    }

    // 3. Honest Unavailable State (when REST route is not mounted and DB is unreachable)
    return const DirectoryUnavailable(
      contractNotice:
          'Authoritative endpoint /api/v1/broker/directory is pending backend exposure. '
          'Contact data is not shown to prevent presenting fabricated or unverified counterparty records.',
    );
  }

  /// Server-side duplicate prevention check against normalized mobile and company name.
  Future<DuplicateCheckResult> checkDuplicate({
    required String mobile,
    required String companyName,
  }) async {
    final phoneRes = PhoneUtils.validateAndNormalize(mobile);
    if (!phoneRes.isValid) {
      return DuplicateCheckResult.none();
    }

    try {
      final response = await _apiClient.post(
        '/broker/directory/check-duplicate',
        data: {
          'mobile': phoneRes.normalized,
          'companyName': companyName.trim(),
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return DuplicateCheckResult.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {
      // Fallback: check against local/Supabase database
    }

    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null) {
        final brokerId = session.user.id;

        // Search for existing user with same mobile under this broker
        final existingByMobile = await client
            .from('crm_contacts')
            .select('id, users!inner(id, name, mobile, role), companies!inner(name)')
            .eq('broker_id', brokerId)
            .or('users.mobile.eq.${phoneRes.normalized},users.mobile.eq.${phoneRes.rawDigits}')
            .limit(1);

        final list = existingByMobile as List;
        if (list.isNotEmpty) {
          final row = list.first;
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
      }
    } catch (_) {}

    return DuplicateCheckResult.none();
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

    // 2. Pre-check for duplicate mobile
    final dupCheck = await checkDuplicate(
      mobile: phoneRes.normalized,
      companyName: input.companyName,
    );

    if (dupCheck.isDuplicate && dupCheck.matchType == 'exact_mobile') {
      return DirectoryError(
        message:
            'A contact with mobile number ${phoneRes.formatted} already exists (${dupCheck.existingCompanyName}). '
            'Duplicate creation prevented.',
        isDuplicate: true,
        duplicateInfo: dupCheck,
      );
    }

    // 3. Attempt REST POST
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
      final serverError = dioErr.response?.data?['error']?.toString();
      if (serverError != null) {
        return DirectoryError(message: serverError);
      }
    } catch (_) {}

    // 4. Supabase direct fallback insert
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null) {
        final brokerId = session.user.id;

        // Insert company
        final compRes = await client
            .from('companies')
            .insert({
              'name': input.companyName.trim(),
              'district_id': input.city?.trim(),
              'state_id': input.state?.trim(),
              'status': true,
              'is_verified': false,
              'trust_score': 100,
            })
            .select('id')
            .single();

        final companyId = compRes['id'] as String;

        // Insert user
        final userRes = await client
            .from('users')
            .insert({
              'name': input.name.trim(),
              'mobile': phoneRes.normalized,
              'email': input.email?.trim(),
              'role': input.role.apiValue,
              'status': true,
              'company_id': companyId,
            })
            .select('id')
            .single();

        final userId = userRes['id'] as String;

        // Link in crm_contacts
        final contactRes = await client
            .from('crm_contacts')
            .insert({
              'broker_id': brokerId,
              'company_id': companyId,
              'user_id': userId,
              'last_activity_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();

        final contactId = contactRes['id'] as String;

        // Optional initial note
        if (input.notes != null && input.notes!.trim().isNotEmpty) {
          await client.from('crm_activities').insert({
            'contact_id': contactId,
            'type': 'Note',
            'notes': input.notes!.trim(),
          });
        }

        return DirectorySuccess(contactId);
      }
    } catch (e) {
      debugPrint('Supabase direct contact create error: $e');
    }

    return const DirectoryUnavailable(
      contractNotice: 'Backend is offline or endpoint /api/v1/broker/directory is unavailable.',
    );
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
      final serverError = dioErr.response?.data?['error']?.toString();
      if (serverError != null) return DirectoryError(message: serverError);
    } catch (_) {}

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
          await client.from('companies').update({
            'name': input.companyName.trim(),
            'district_id': input.city?.trim(),
            'state_id': input.state?.trim(),
            if (input.status != null) 'status': input.status,
          }).eq('id', compId);
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

  /// Toggle contact status (Active / Inactive soft archival).
  Future<DirectoryDataResult<bool>> toggleContactStatus(String contactId) async {
    try {
      final response = await _apiClient.post(
        '/broker/directory/$contactId/toggle-status',
      );

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
    } catch (_) {}

    // Direct Supabase fallback
    try {
      final client = _supabase;
      if (client != null) {
        final row = await client
            .from('crm_contacts')
            .select('user_id, users(status)')
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
    try {
      final response = await _apiClient.get('/broker/directory/$contactId');

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          return DirectorySuccess(
            ContactDetailsPayload.fromJson(data['data'] as Map<String, dynamic>),
          );
        }
        return DirectoryError(message: data['error']?.toString() ?? 'Failed to load details');
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401) {
        return const DirectoryUnauthorized();
      }
    } catch (_) {}

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
              'users(id, name, mobile, email, role, status), '
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
        );

        return DirectorySuccess(
          ContactDetailsPayload(
            contact: contact,
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
}
