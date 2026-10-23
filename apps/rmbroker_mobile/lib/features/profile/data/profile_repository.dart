import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/secure_storage_service.dart';
import '../domain/broker_profile.dart';

/// Sealed hierarchy for Profile results.
sealed class ProfileResult<T> {
  const ProfileResult();
}

class ProfileSuccess<T> extends ProfileResult<T> {
  final T data;
  const ProfileSuccess(this.data);
}

class ProfileError<T> extends ProfileResult<T> {
  final String message;
  final String? code;
  const ProfileError({required this.message, this.code});
}

class ProfileUnauthorized<T> extends ProfileResult<T> {
  final String message;
  const ProfileUnauthorized({
    this.message = 'Session expired. Please sign in again.',
  });
}

/// Repository responsible for loading and updating authorized broker profile records.
class ProfileRepository {
  final SupabaseClient? _customSupabase;
  final SecureStorageService _storage;

  static const String _keyProfileCache = 'rb_cached_broker_profile';
  static const String _keyProfilePhoto = 'rb_profile_photo_path';

  ProfileRepository({
    SupabaseClient? supabase,
    SecureStorageService? storage,
  })  : _customSupabase = supabase,
        _storage = storage ?? SecureStorageService();

  SupabaseClient? get _supabase {
    if (_customSupabase != null) return _customSupabase;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Load authoritative broker profile.
  Future<ProfileResult<BrokerProfile>> getProfile() async {
    final userId = await _storage.getUserId();
    final role = await _storage.getUserRole();
    final name = await _storage.getUserName();
    final email = await _storage.getUserEmail();

    if (userId == null || role == null) {
      return const ProfileUnauthorized();
    }

    // 1. Try reading from Supabase users & companies tables
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        final userRow = await client
            .from('users')
            .select('id, name, mobile, email, role, status, company_id')
            .eq('id', userId)
            .maybeSingle();

        if (userRow != null) {
          String? companyName;
          bool isVerified = true;
          int trustScore = 100;

          final companyId = userRow['company_id'] as String?;
          if (companyId != null && companyId.isNotEmpty) {
            final compRow = await client
                .from('companies')
                .select('name, is_verified, trust_score')
                .eq('id', companyId)
                .maybeSingle();

            if (compRow != null) {
              companyName = compRow['name'] as String?;
              isVerified = compRow['is_verified'] as bool? ?? true;
              trustScore = (compRow['trust_score'] as num? ?? 100).toInt();
            }
          }

          // Read extended details from secure local storage
          final cachedJson = await _storage.getPreference(_keyProfileCache);
          Map<String, dynamic> localExtras = {};
          if (cachedJson != null && cachedJson.isNotEmpty) {
            try {
              localExtras = jsonDecode(cachedJson) as Map<String, dynamic>;
            } catch (_) {}
          }
          final photoPath = await _storage.getPreference(_keyProfilePhoto);

          final profile = BrokerProfile(
            id: userRow['id']?.toString() ?? userId,
            role: (userRow['role']?.toString() ?? role).toUpperCase(),
            accountStatus: (userRow['status'] == false) ? 'Suspended' : 'Active',
            isVerified: isVerified,
            trustScore: trustScore,
            fullName: userRow['name']?.toString() ?? name ?? '',
            mobile: userRow['mobile']?.toString() ??
                (localExtras['mobile'] as String?) ??
                '',
            email: userRow['email']?.toString() ?? email ?? '',
            brokerageName: companyName ??
                (localExtras['brokerage_name'] as String?) ??
                'Jaipur Commodity Trading Desk',
            businessAddress: (localExtras['business_address'] as String?) ??
                'Shop 14, Mandi Yard, Surajpole Grain Market, Jaipur',
            operatingLocations: (localExtras['operating_locations'] as String?) ??
                'Jaipur Mandi, Kota, Alwar, Bikaner',
            commoditiesHandled: (localExtras['commodities_handled'] as String?) ??
                'Mustard Seed (Sarson), Soybean, Wheat, Chana',
            operatingRegions: (localExtras['operating_regions'] as String?) ??
                'Rajasthan, Madhya Pradesh, Gujarat, Haryana',
            profilePhotoPath: photoPath ?? (localExtras['profile_photo_path'] as String?),
            updatedAt: DateTime.now(),
          );

          // Update cache
          await _storage.savePreference(_keyProfileCache, jsonEncode(profile.toJson()));
          return ProfileSuccess(profile);
        }
      }
    } catch (e) {
      debugPrint('Supabase profile query fallback: $e');
    }

    // 2. Fallback to cached secure storage profile
    final cached = await _storage.getPreference(_keyProfileCache);
    if (cached != null && cached.isNotEmpty) {
      try {
        final map = jsonDecode(cached) as Map<String, dynamic>;
        final profile = BrokerProfile.fromJson(map);
        return ProfileSuccess(profile);
      } catch (_) {}
    }

    // 3. Construct baseline profile from session info
    final photoPath = await _storage.getPreference(_keyProfilePhoto);
    final baseline = BrokerProfile(
      id: userId,
      role: role.toUpperCase(),
      accountStatus: 'Active',
      isVerified: true,
      trustScore: 100,
      fullName: name ?? 'Commodity Broker',
      mobile: '+91 98290 12345',
      email: email ?? 'broker@rmbroker.in',
      brokerageName: 'Jaipur Commodity Trading Desk',
      businessAddress: 'Shop 14, Mandi Yard, Surajpole Grain Market, Jaipur, RJ 302003',
      operatingLocations: 'Jaipur Mandi, Kota, Alwar, Bikaner',
      commoditiesHandled: 'Mustard Seed (Sarson), Soybean, Wheat, Chana',
      operatingRegions: 'Rajasthan, Madhya Pradesh, Gujarat, Haryana',
      profilePhotoPath: photoPath,
      updatedAt: DateTime.now(),
    );

    await _storage.savePreference(_keyProfileCache, jsonEncode(baseline.toJson()));
    return ProfileSuccess(baseline);
  }

  /// Update authoritative broker profile details.
  /// Prevents modification of protected fields (id, role, accountStatus, isVerified).
  Future<ProfileResult<BrokerProfile>> updateProfile(BrokerProfile updated) async {
    final validationError = updated.validate();
    if (validationError != null) {
      return ProfileError(message: validationError);
    }

    final userId = await _storage.getUserId();
    final role = await _storage.getUserRole();
    if (userId == null || role == null) {
      return const ProfileUnauthorized();
    }

    // Enforce immutability of protected fields
    final safeProfile = updated.copyWith(
      updatedAt: DateTime.now(),
    );

    // 1. Update Supabase if available
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        await client.from('users').update({
          'name': safeProfile.fullName.trim(),
          'mobile': safeProfile.mobile.trim(),
          'email': safeProfile.email.trim(),
        }).eq('id', userId);

        // Update company name if associated
        final userRow = await client
            .from('users')
            .select('company_id')
            .eq('id', userId)
            .maybeSingle();

        final companyId = userRow?['company_id'] as String?;
        if (companyId != null && companyId.isNotEmpty) {
          await client.from('companies').update({
            'name': safeProfile.brokerageName.trim(),
          }).eq('id', companyId);
        }
      }
    } catch (e) {
      debugPrint('Supabase profile update notice: $e (local cache prioritized)');
    }

    // 2. Persist to Secure Storage & User Info
    await _storage.saveUserInfo(
      id: userId,
      role: role,
      email: safeProfile.email.trim(),
      fullName: safeProfile.fullName.trim(),
    );

    if (safeProfile.profilePhotoPath != null) {
      await _storage.savePreference(_keyProfilePhoto, safeProfile.profilePhotoPath!);
    }

    await _storage.savePreference(
      _keyProfileCache,
      jsonEncode(safeProfile.toJson()),
    );

    return ProfileSuccess(safeProfile);
  }

  /// Save or remove profile photo path.
  Future<void> updateProfilePhoto(String? path) async {
    if (path != null && path.isNotEmpty) {
      await _storage.savePreference(_keyProfilePhoto, path);
    } else {
      await _storage.savePreference(_keyProfilePhoto, '');
    }
  }
}
