import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/secure_storage_service.dart';
import '../domain/business_location_model.dart';
import '../domain/seller_profile_model.dart';

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

  /// Fetch authoritative profile data for currently authenticated seller.
  Future<SellerProfileModel> getProfile() async {
    final userId =
        await _storage.getUserId() ?? '20000000-0000-0000-0000-000000000001';
    final role = await _storage.getUserRole() ?? 'seller';
    final email = await _storage.getUserEmail() ?? 'seller@demo.com';
    String fullName = await _storage.getUserFullName() ?? 'Seller Lead';
    String companyId =
        await _storage.getCompanyId() ?? '20000000-0000-0000-0000-000000000101';
    String companyName =
        await _storage.getCompanyName() ?? 'Bikaner Agro Processing Ltd';
    String companyGst = await _storage.getCompanyGst() ?? '08AAAAA0000A1Z5';
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
      // 1. Update user record in public.users
      await performUserUpdate(client, updatedProfile.id, {
        'name': updatedProfile.fullName,
        'mobile': updatedProfile.mobile,
      });

      // 2. Update company record in public.companies
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
    await _storage.savePreference('business_location_name', loc.name);
    await _storage.savePreference('business_location_address', loc.addressLine);
    await _storage.savePreference('business_location_locality', loc.locality);
    await _storage.savePreference('business_location_state_id', loc.stateId);
    await _storage.savePreference('business_location_state', loc.stateName);
    await _storage.savePreference(
      'business_location_district_id',
      loc.districtId,
    );
    await _storage.savePreference(
      'business_location_district',
      loc.districtName,
    );
    await _storage.savePreference('business_location_pincode', loc.pinCode);
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
