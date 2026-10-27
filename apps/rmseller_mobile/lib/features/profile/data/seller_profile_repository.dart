import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/secure_storage_service.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/business_location_model.dart';
import '../domain/seller_profile_model.dart';

enum ListingReadinessStatus { complete, incomplete, unverified }

/// Server-checked business-profile readiness for publishing a lot. Covers what
/// the backend requires of the firm (a linked company with a name); the
/// warehouse location is checked on the lot itself.
class ListingReadiness {
  final ListingReadinessStatus status;
  final String? firmName;

  /// The firm's registered state/district on `companies` (text ids), used
  /// only as a default region when no warehouse location is saved.
  final String? companyStateId;
  final String? companyDistrictId;

  /// Blocking problems the seller cannot fix in this screen.
  final List<String> missing;
  final String? error;

  const ListingReadiness.complete({
    this.firmName,
    this.companyStateId,
    this.companyDistrictId,
  }) : status = ListingReadinessStatus.complete,
       missing = const [],
       error = null;

  const ListingReadiness.incomplete(this.missing)
    : status = ListingReadinessStatus.incomplete,
      firmName = null,
      companyStateId = null,
      companyDistrictId = null,
      error = null;

  const ListingReadiness.unverified(String this.error)
    : status = ListingReadinessStatus.unverified,
      firmName = null,
      companyStateId = null,
      companyDistrictId = null,
      missing = const [];
}

/// Repository managing authenticated Seller profile loading, synchronization,
/// and updates against authoritative database tables (`users` and `companies`)
/// with encrypted local caching via `SecureStorageService`.
class SellerProfileRepository {
  final SupabaseClient? _customClient;
  final SecureStorageService _storage;

  SellerProfileRepository({
    SupabaseClient? supabase,
    SecureStorageService? storage,
  }) : _customClient = supabase,
       _storage = storage ?? SecureStorageService();

  SupabaseClient? get _supabase {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SecureStorageService get storage => _storage;

  /// Hook for performing profile lookup on the users table.
  @visibleForTesting
  Future<Map<String, dynamic>?> performUserLookup(
    SupabaseClient client,
    String userId,
  ) async {
    return await client
        .from('users')
        .select('id, name, email, mobile, role, company_id')
        .eq('id', userId)
        .maybeSingle();
  }

  /// Hook for performing company lookup on the companies table.
  @visibleForTesting
  Future<Map<String, dynamic>?> performCompanyLookup(
    SupabaseClient client,
    String companyId,
  ) async {
    return await client
        .from('companies')
        .select(
          'id, name, gst, is_verified, trust_score, state_id, district_id',
        )
        .eq('id', companyId)
        .maybeSingle();
  }

  /// Hook for updating user profile row in users table.
  @visibleForTesting
  Future<void> performUserUpdate(
    SupabaseClient client,
    String userId,
    Map<String, dynamic> data,
  ) async {
    await client.from('users').update(data).eq('id', userId);
  }

  /// Hook for updating company profile row in companies table.
  @visibleForTesting
  Future<void> performCompanyUpdate(
    SupabaseClient client,
    String companyId,
    Map<String, dynamic> data,
  ) async {
    await client.from('companies').update(data).eq('id', companyId);
  }

  /// Hook for updating user metadata in Supabase Auth.
  @visibleForTesting
  Future<UserResponse?> performUpdateUserMetadata(
    SupabaseClient client,
    Map<String, dynamic> data,
  ) async {
    return await client.auth.updateUser(UserAttributes(data: data));
  }

  /// The business location the seller actually saved, or null when none was
  /// saved. Fetches from the persistent database (auth metadata / availabilities)
  /// and synchronizes with secure local storage.
  Future<BusinessLocationModel?> getSavedBusinessLocation({String? userId}) async {
    final client = _supabase;
    final currentUserId = userId ?? client?.auth.currentUser?.id ?? await _storage.getUserId();

    // 1. Authoritative: check session userMetadata from the persistent database
    final meta = client?.auth.currentUser?.userMetadata;
    if (meta != null) {
      final whMap = (meta['default_warehouse'] as Map<String, dynamic>?) ??
          (meta['warehouse'] as Map<String, dynamic>?);
      if (whMap != null &&
          whMap['address_line'] != null &&
          whMap['address_line'].toString().trim().isNotEmpty) {
        final loc = BusinessLocationModel.fromMap(whMap);
        await _cacheLocationLocally(loc, currentUserId);
        return loc;
      }
    }

    // 2. Check local SecureStorage (seller-scoped, then legacy fallback)
    final userAddressKey = currentUserId != null ? 'business_location_address_$currentUserId' : null;
    final address = (userAddressKey != null ? await _storage.getPreference(userAddressKey) : null) ??
        await _storage.getPreference('business_location_address');

    final userStateKey = currentUserId != null ? 'business_location_state_$currentUserId' : null;
    final stateName = (userStateKey != null ? await _storage.getPreference(userStateKey) : null) ??
        await _storage.getPreference('business_location_state');

    if (address != null && address.trim().isNotEmpty && stateName != null && stateName.trim().isNotEmpty) {
      final userStateIdKey = currentUserId != null ? 'business_location_state_id_$currentUserId' : null;
      final stateId = (userStateIdKey != null ? await _storage.getPreference(userStateIdKey) : null) ??
          await _storage.getPreference('business_location_state_id') ?? '';

      final userDistrictIdKey = currentUserId != null ? 'business_location_district_id_$currentUserId' : null;
      final districtId = (userDistrictIdKey != null ? await _storage.getPreference(userDistrictIdKey) : null) ??
          await _storage.getPreference('business_location_district_id') ?? '';

      final userDistrictKey = currentUserId != null ? 'business_location_district_$currentUserId' : null;
      final districtName = (userDistrictKey != null ? await _storage.getPreference(userDistrictKey) : null) ??
          await _storage.getPreference('business_location_district') ?? '';

      final userNameKey = currentUserId != null ? 'business_location_name_$currentUserId' : null;
      final name = (userNameKey != null ? await _storage.getPreference(userNameKey) : null) ??
          await _storage.getPreference('business_location_name') ?? '';

      final userLocalityKey = currentUserId != null ? 'business_location_locality_$currentUserId' : null;
      final locality = (userLocalityKey != null ? await _storage.getPreference(userLocalityKey) : null) ??
          await _storage.getPreference('business_location_locality') ?? '';

      final userPinKey = currentUserId != null ? 'business_location_pincode_$currentUserId' : null;
      final pinCode = (userPinKey != null ? await _storage.getPreference(userPinKey) : null) ??
          await _storage.getPreference('business_location_pincode') ?? '';

      return BusinessLocationModel(
        name: name,
        addressLine: address,
        locality: locality,
        stateId: stateId,
        stateName: stateName,
        districtId: districtId,
        districtName: districtName,
        pinCode: pinCode,
        latitude: null,
        longitude: null,
      );
    }

    // 3. Fallback: check recent lots in availabilities for previously posted warehouse
    if (client != null && currentUserId != null) {
      try {
        final recentLot = await client
            .from('availabilities')
            .select('state_id, district_id, loading_remarks')
            .eq('seller_user_id', currentUserId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (recentLot != null && recentLot['loading_remarks'] != null) {
          final remarks = recentLot['loading_remarks'].toString().trim();
          if (remarks.isNotEmpty && !remarks.toLowerCase().contains('same as')) {
            final loc = BusinessLocationModel(
              name: 'Registered Warehouse',
              addressLine: remarks,
              locality: '',
              stateId: recentLot['state_id']?.toString() ?? '',
              stateName: '',
              districtId: recentLot['district_id']?.toString() ?? '',
              districtName: '',
              pinCode: '',
              latitude: null,
              longitude: null,
            );
            await saveBusinessLocationDefault(loc, userId: currentUserId);
            return loc;
          }
        }
      } catch (e) {
        debugPrint('Availabilities warehouse fallback notice: $e');
      }
    }

    return null;
  }

  Future<void> _cacheLocationLocally(BusinessLocationModel loc, String? currentUserId) async {
    if (currentUserId != null) {
      await _storage.savePreference('business_location_name_$currentUserId', loc.name);
      await _storage.savePreference('business_location_address_$currentUserId', loc.addressLine);
      await _storage.savePreference('business_location_locality_$currentUserId', loc.locality);
      await _storage.savePreference('business_location_state_id_$currentUserId', loc.stateId);
      await _storage.savePreference('business_location_state_$currentUserId', loc.stateName);
      await _storage.savePreference('business_location_district_id_$currentUserId', loc.districtId);
      await _storage.savePreference('business_location_district_$currentUserId', loc.districtName);
      await _storage.savePreference('business_location_pincode_$currentUserId', loc.pinCode);
    }
    // Also save legacy global keys for seamless backward compatibility
    await _storage.savePreference('business_location_name', loc.name);
    await _storage.savePreference('business_location_address', loc.addressLine);
    await _storage.savePreference('business_location_locality', loc.locality);
    await _storage.savePreference('business_location_state_id', loc.stateId);
    await _storage.savePreference('business_location_state', loc.stateName);
    await _storage.savePreference('business_location_district_id', loc.districtId);
    await _storage.savePreference('business_location_district', loc.districtName);
    await _storage.savePreference('business_location_pincode', loc.pinCode);
  }

  /// Saves the warehouse as this seller's persistent default warehouse both in
  /// local secure storage and the authoritative backend database (user metadata).
  Future<void> saveBusinessLocationDefault(
    BusinessLocationModel loc, {
    bool isUpdate = false,
    String? userId,
  }) async {
    final client = _supabase;
    final currentUserId = userId ?? client?.auth.currentUser?.id ?? await _storage.getUserId();

    // Cache locally
    await _cacheLocationLocally(loc, currentUserId);

    // Also update saved warehouses list
    await saveWarehouse(loc, setAsDefault: true, userId: currentUserId);

    // Persist to authoritative backend database (user metadata)
    if (client != null && client.auth.currentUser != null) {
      try {
        final existingWarehouses = await getSavedWarehouses(userId: currentUserId);
        final warehousesList = existingWarehouses.map((w) => w.toMap()).toList();

        await performUpdateUserMetadata(client, {
          'default_warehouse': loc.toMap(),
          'warehouse': loc.toMap(),
          'warehouses': warehousesList,
        });
      } catch (e) {
        debugPrint('Persistent warehouse backend sync notice: $e');
      }
    }
  }

  /// Retrieve all registered warehouses for this seller.
  Future<List<BusinessLocationModel>> getSavedWarehouses({String? userId}) async {
    final client = _supabase;
    final currentUserId = userId ?? client?.auth.currentUser?.id ?? await _storage.getUserId();

    // 1. Check user metadata in session
    final meta = client?.auth.currentUser?.userMetadata;
    if (meta != null && meta['warehouses'] is List) {
      final list = (meta['warehouses'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => BusinessLocationModel.fromMap(m))
          .toList();
      if (list.isNotEmpty) return list;
    }

    // 2. Check local storage
    final key = currentUserId != null ? 'saved_warehouses_$currentUserId' : 'saved_warehouses';
    final jsonStr = await _storage.getPreference(key);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final list = decoded
              .whereType<Map<String, dynamic>>()
              .map((m) => BusinessLocationModel.fromMap(m))
              .toList();
          if (list.isNotEmpty) return list;
        }
      } catch (_) {}
    }

    // 3. Fallback: single default warehouse if available
    final single = await getSavedBusinessLocation(userId: currentUserId);
    return single != null ? [single] : const [];
  }

  /// Appends or updates a warehouse in the seller's list of saved warehouses.
  Future<void> saveWarehouse(
    BusinessLocationModel loc, {
    bool setAsDefault = true,
    String? userId,
  }) async {
    final client = _supabase;
    final currentUserId = userId ?? client?.auth.currentUser?.id ?? await _storage.getUserId();

    final current = await getSavedWarehouses(userId: currentUserId);
    final updatedList = <BusinessLocationModel>[];
    bool matched = false;

    for (final existing in current) {
      final isSame = (existing.name == loc.name && existing.addressLine == loc.addressLine) ||
          (existing.addressLine == loc.addressLine && existing.districtId == loc.districtId);
      if (isSame) {
        updatedList.add(loc);
        matched = true;
      } else {
        updatedList.add(existing);
      }
    }
    if (!matched) {
      updatedList.add(loc);
    }

    // Save list to local storage
    final key = currentUserId != null ? 'saved_warehouses_$currentUserId' : 'saved_warehouses';
    final jsonStr = jsonEncode(updatedList.map((w) => w.toMap()).toList());
    await _storage.savePreference(key, jsonStr);

    if (setAsDefault) {
      await _cacheLocationLocally(loc, currentUserId);
    }
  }

  /// Hook for performing idempotent self-provisioning via RPC.
  @visibleForTesting
  Future<dynamic> performProvisioning(
    SupabaseClient client,
    String userId,
  ) async {
    return await client.rpc(
      'provision_individual_seller',
      params: {'target_auth_user_id': userId},
    );
  }

  /// Idempotently provision the authenticated seller's profile in the database.
  Future<bool> provisionCurrentSeller() async {
    final client = _supabase;
    if (client == null) return false;
    final session = client.auth.currentSession;
    if (session == null) return false;
    try {
      final res = await performProvisioning(client, session.user.id);
      debugPrint('Self-provisioning result: $res');
      return true;
    } catch (e) {
      debugPrint('Self-provisioning notice: $e');
      return false;
    }
  }

  /// Whether the signed-in seller's business profile allows listing, read
  /// from the server (`users` → `companies`). An error is reported as
  /// [ListingReadinessStatus.unverified], never as "incomplete".
  Future<ListingReadiness> checkListingReadiness() async {
    final client = _supabase;
    if (client == null) {
      // Offline/test mode: no server to verify against (and no local read,
      // which can stall without a storage plugin).
      return const ListingReadiness.complete();
    }
    var session = client.auth.currentSession;
    if (session == null || session.isExpired) {
      final recovery = await AuthRepository(
        supabase: client,
        storage: _storage,
      ).recoverSession();

      if (recovery == SessionRecoveryState.networkError) {
        return const ListingReadiness.unverified(
          'Network connection issue. Please check your internet and tap Retry.',
        );
      }
      if (recovery == SessionRecoveryState.unrecoverable) {
        return const ListingReadiness.unverified(
          'Your session has expired. Please sign in again.',
        );
      }
      session = client.auth.currentSession;
    }
    if (session == null || session.isExpired) {
      return const ListingReadiness.unverified(
        'Your session has expired. Please sign in again.',
      );
    }
    try {
      var user = await client
          .from('users')
          .select('id, name, role, status, company_id')
          .eq('id', session.user.id)
          .maybeSingle();

      if (user == null) {
        // Attempt automatic idempotent self-provisioning before reporting incomplete
        await provisionCurrentSeller();
        user = await client
            .from('users')
            .select('id, name, role, status, company_id')
            .eq('id', session.user.id)
            .maybeSingle();
      }

      if (user == null) {
        return const ListingReadiness.incomplete([
          'Your account is not yet provisioned in the database. Please complete your profile to continue.',
        ]);
      }

      final role = user['role']?.toString().toLowerCase().trim();
      final isInactive = user['status'] == false || user['status'] == 'false';
      if (role != null && role != 'seller') {
        return const ListingReadiness.incomplete([
          'Your account does not have active seller permissions. Please contact support.',
        ]);
      }
      if (isInactive) {
        return const ListingReadiness.incomplete([
          'Your account is deactivated. Please contact support.',
        ]);
      }

      final companyId = user['company_id']?.toString().trim();
      // Individual seller without a company: business profile requirement is fulfilled
      // by the seller's verified individual identity.
      if (companyId == null || companyId.isEmpty) {
        final individualName = user['name']?.toString().trim() ?? '';
        return ListingReadiness.complete(
          firmName: individualName.isNotEmpty ? individualName : 'Individual Seller',
        );
      }

      // Company-linked seller: verify enterprise company record
      final company = await client
          .from('companies')
          .select('name, gst, state_id, district_id')
          .eq('id', companyId)
          .maybeSingle();
      if (company == null) {
        return const ListingReadiness.incomplete([
          'Your business (firm) record could not be found. Please contact support.',
        ]);
      }
      final name = company['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        return const ListingReadiness.incomplete([
          'Your business (firm) name is missing. Please contact support.',
        ]);
      }
      return ListingReadiness.complete(
        firmName: name,
        companyStateId: company['state_id']?.toString(),
        companyDistrictId: company['district_id']?.toString(),
      );
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST301' ||
          (e.message.toLowerCase().contains('jwt') &&
              e.message.toLowerCase().contains('expired'))) {
        final retryRecovery = await AuthRepository(
          supabase: client,
          storage: _storage,
        ).recoverSession(force: true);
        if (retryRecovery == SessionRecoveryState.recovered) {
          return checkListingReadiness();
        }
        return const ListingReadiness.unverified(
          'Your session has expired. Please sign in again.',
        );
      }
      debugPrint('Listing readiness check failed: ${e.code}');
      return const ListingReadiness.unverified(
        'Could not check your business profile. Check your connection and retry.',
      );
    } catch (e) {
      debugPrint('Listing readiness check failed: ${e.runtimeType}');
      return const ListingReadiness.unverified(
        'Could not check your business profile. Check your connection and retry.',
      );
    }
  }

  /// The registered office address the seller saved, or null.
  Future<String?> getSavedOfficeAddress() async {
    final office = await _storage.getPreference('office_address');
    return (office == null || office.trim().isEmpty) ? null : office.trim();
  }

  /// Fetch authoritative profile data for currently authenticated seller.
  Future<SellerProfileModel> getProfile() async {
    final sessionUser = _supabase?.auth.currentUser;
    final userId =
        await _storage.getUserId() ??
        sessionUser?.id ??
        '20000000-0000-0000-0000-000000000001';
    final role = await _storage.getUserRole() ?? 'seller';
    final email =
        await _storage.getUserEmail() ?? sessionUser?.email ?? 'seller@demo.com';
    String fullName =
        await _storage.getUserFullName() ??
        (sessionUser?.userMetadata?['full_name'] as String?) ??
        (sessionUser?.userMetadata?['name'] as String?) ??
        'Seller Lead';
    String companyId = await _storage.getCompanyId() ?? '';
    String companyName = await _storage.getCompanyName() ?? '';
    String companyGst = await _storage.getCompanyGst() ?? '';
    String mobile =
        await _storage.getPreference('user_mobile') ?? '+91 98290 12345';
    String primaryMandi =
        await _storage.getPreference('primary_mandi') ??
        'Bikaner Krishi Upaj Mandi';
    String state = await _storage.getPreference('company_state') ?? 'Rajasthan';
    String district =
        await _storage.getPreference('company_district') ?? 'Bikaner';
    int trustScore = 98;
    bool isVerified = true;

    // Load separate registered office address (Corporate HQ)
    String officeAddress =
        await _storage.getPreference('office_address') ??
        'Commercial Tower 4, Bikaner Corporate Hub';

    // Load business shop / godown location details
    String locName =
        await _storage.getPreference('business_location_name') ??
        'Bikaner Krishi Upaj Mandi Yard Godown A-4';
    String locAddress =
        await _storage.getPreference('business_location_address') ??
        'Plot 12, Industrial Area, Krishi Upaj Mandi Road';
    String locLocality =
        await _storage.getPreference('business_location_locality') ??
        'Khara Industrial Area';
    String locStateId =
        await _storage.getPreference('business_location_state_id') ??
        '40000000-0000-0000-0000-000000000001';
    String locStateName =
        await _storage.getPreference('business_location_state') ?? 'Rajasthan';
    String locDistrictId =
        await _storage.getPreference('business_location_district_id') ??
        '50000000-0000-0000-0000-000000000001';
    String locDistrictName =
        await _storage.getPreference('business_location_district') ??
        'Bikaner Mandi Hub';
    String locPincode =
        await _storage.getPreference('business_location_pincode') ?? '334001';
    String? latStr = await _storage.getPreference('business_location_lat');
    String? lngStr = await _storage.getPreference('business_location_lng');
    bool isGps =
        (await _storage.getPreference('business_location_gps')) == 'true';

    final client = _supabase;
    if (client != null) {
      try {
        final userRow = await performUserLookup(client, userId);
        if (userRow != null) {
          if (userRow['name'] != null) {
            fullName = userRow['name'] as String;
          }
          if (userRow['mobile'] != null) {
            mobile = userRow['mobile'] as String;
          }
          if (userRow['company_id'] != null) {
            companyId = userRow['company_id'] as String;
          }
        }

        if (companyId.isNotEmpty) {
          final compRow = await performCompanyLookup(client, companyId);
          if (compRow != null) {
            if (compRow['name'] != null) {
              companyName = compRow['name'] as String;
            }
            if (compRow['gst'] != null) {
              companyGst = compRow['gst'] as String;
            }
            if (compRow['trust_score'] != null) {
              trustScore = (compRow['trust_score'] as num).toInt();
            }
            if (compRow['is_verified'] != null) {
              isVerified = compRow['is_verified'] == true;
            }
          }
        }

        // Cache refreshed authoritative values locally
        await _storage.saveUserInfo(
          id: userId,
          role: role,
          email: email,
          fullName: fullName,
          companyId: companyId,
          companyName: companyName,
          companyGst: companyGst,
        );
        await _storage.savePreference('user_mobile', mobile);
      } catch (e) {
        debugPrint('Authoritative backend profile lookup notice: $e');
      }
    }

    final businessLoc = BusinessLocationModel(
      name: locName,
      addressLine: locAddress,
      locality: locLocality,
      stateId: locStateId,
      stateName: locStateName,
      districtId: locDistrictId,
      districtName: locDistrictName,
      pinCode: locPincode,
      latitude: latStr != null ? double.tryParse(latStr) : 28.0229,
      longitude: lngStr != null ? double.tryParse(lngStr) : 73.3119,
      isGpsDetected: isGps,
    );

    return SellerProfileModel(
      id: userId,
      fullName: fullName,
      email: email,
      mobile: mobile,
      role: role,
      companyId: companyId,
      companyName: companyName,
      companyGst: companyGst,
      primaryMandi: primaryMandi,
      state: state,
      district: district,
      trustScore: trustScore,
      isVerified: isVerified,
      officeAddress: officeAddress,
      businessLocation: businessLoc,
    );
  }

  /// Authoritatively persist updated profile fields to backend database and secure cache.
  Future<SellerProfileModel> updateProfile(
    SellerProfileModel updatedProfile,
  ) async {
    final client = _supabase;
    if (client != null) {
      // 1. Ensure user row exists in public.users before updating
      try {
        final existing = await performUserLookup(client, updatedProfile.id);
        if (existing == null) {
          await provisionCurrentSeller();
        }
      } catch (_) {}

      // 2. Update user record in public.users
      await performUserUpdate(client, updatedProfile.id, {
        'name': updatedProfile.fullName,
        'mobile': updatedProfile.mobile,
      });

      // 3. Update company record in public.companies (if linked to a company)
      if (updatedProfile.companyId.isNotEmpty) {
        await performCompanyUpdate(client, updatedProfile.companyId, {
          'name': updatedProfile.companyName,
          'gst': updatedProfile.companyGst,
          'state_id': updatedProfile.businessLocation.stateId,
          'district_id': updatedProfile.businessLocation.districtId,
        });
      }
    }

    // 3. Persist to SecureStorage
    await _storage.saveUserInfo(
      id: updatedProfile.id,
      role: updatedProfile.role,
      email: updatedProfile.email,
      fullName: updatedProfile.fullName,
      companyId: updatedProfile.companyId,
      companyName: updatedProfile.companyName,
      companyGst: updatedProfile.companyGst,
    );
    await _storage.savePreference('user_mobile', updatedProfile.mobile);
    await _storage.savePreference('primary_mandi', updatedProfile.primaryMandi);
    await _storage.savePreference('company_state', updatedProfile.state);
    await _storage.savePreference('company_district', updatedProfile.district);
    await _storage.savePreference(
      'office_address',
      updatedProfile.officeAddress,
    );

    // Persist physical business location (shop/godown)
    final loc = updatedProfile.businessLocation;
    await saveBusinessLocationDefault(
      loc,
      isUpdate: true,
      userId: updatedProfile.id,
    );
    if (loc.latitude != null) {
      await _storage.savePreference(
        'business_location_lat',
        loc.latitude.toString(),
      );
    }
    if (loc.longitude != null) {
      await _storage.savePreference(
        'business_location_lng',
        loc.longitude.toString(),
      );
    }
    await _storage.savePreference(
      'business_location_gps',
      loc.isGpsDetected.toString(),
    );

    return updatedProfile;
  }
}
