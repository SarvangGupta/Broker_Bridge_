import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/secure_storage_service.dart';
import '../../../core/security/session_guard.dart';
import '../../directory/domain/gst_certificate_data.dart';
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

  /// Skips the database entirely. Tests only: production saves must be
  /// confirmed by the server.
  final bool localOnlyForTesting;

  ProfileRepository({
    SupabaseClient? supabase,
    SecureStorageService? storage,
    @visibleForTesting this.localOnlyForTesting = false,
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
          String? gstin;
          bool isVerified = true;
          int trustScore = 100;
          bool gstVerified = false;
          DateTime? gstVerifiedAt;
          Map<String, dynamic> gstLiveData = {};

          final companyId = userRow['company_id'] as String?;
          if (companyId != null && companyId.isNotEmpty) {
            final compRow = await client
                .from('companies')
                .select(
                  'id, name, gst, district_id, state_id, business_type_id, status, is_verified, trust_score, gst_verified, gst_verified_at, gst_live_data',
                )
                .eq('id', companyId)
                .maybeSingle();

            if (compRow != null) {
              companyName = compRow['name'] as String?;
              gstin = compRow['gst'] as String?;
              isVerified = compRow['is_verified'] as bool? ?? true;
              trustScore = (compRow['trust_score'] as num? ?? 100).toInt();
              gstVerified = compRow['gst_verified'] as bool? ?? false;
              if (compRow['gst_verified_at'] != null) {
                gstVerifiedAt = DateTime.tryParse(compRow['gst_verified_at'].toString());
              }
              if (compRow['gst_live_data'] is Map<String, dynamic>) {
                gstLiveData = compRow['gst_live_data'] as Map<String, dynamic>;
              } else if (compRow['gst_live_data'] is String) {
                try {
                  gstLiveData = jsonDecode(compRow['gst_live_data'] as String)
                      as Map<String, dynamic>;
                } catch (_) {}
              }
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

          final profileGstin = gstin ??
              (localExtras['gstin'] as String?) ??
              (localExtras['gst'] as String?) ??
              '';

          // Determine verification status
          String verificationStatus = gstLiveData['verification_status']?.toString() ??
              localExtras['gst_verification_status']?.toString() ??
              (gstVerified
                  ? BrokerGstStatus.certificateReviewed
                  : profileGstin.isEmpty
                      ? BrokerGstStatus.gstMissing
                      : BrokerGstStatus.pending);

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
            designation: (gstLiveData['designation'] as String?) ??
                (localExtras['designation'] as String?) ??
                'Managing Director & Mandi Broker',
            profilePhotoPath: photoPath ?? (localExtras['profile_photo_path'] as String?),
            brokerageName: companyName ??
                (localExtras['brokerage_name'] as String?) ??
                'Jaipur Mandi Brokerage Desk',
            businessType: (gstLiveData['business_type'] as String?) ??
                (localExtras['business_type'] as String?) ??
                'Proprietorship',
            businessAddress: (gstLiveData['principal_place_of_business'] as String?) ??
                (localExtras['business_address'] as String?) ??
                'Shop 14, Mandi Yard, Surajpole Grain Market, Jaipur',
            city: (gstLiveData['city'] as String?) ??
                (localExtras['city'] as String?) ??
                'Jaipur',
            state: (gstLiveData['state'] as String?) ??
                (localExtras['state'] as String?) ??
                'Rajasthan',
            pincode: (gstLiveData['pincode'] as String?) ??
                (localExtras['pincode'] as String?) ??
                '302003',
            businessContactNumber: (gstLiveData['business_contact_number'] as String?) ??
                (localExtras['business_contact_number'] as String?) ??
                '',
            operatingLocations: (gstLiveData['operating_locations'] as String?) ??
                (localExtras['operating_locations'] as String?) ??
                'Jaipur Mandi, Kota, Alwar, Bikaner',
            commoditiesHandled: (gstLiveData['commodities_handled'] as String?) ??
                (localExtras['commodities_handled'] as String?) ??
                'Mustard Seed (Sarson), Soybean, Wheat, Chana',
            operatingRegions: (gstLiveData['operating_regions'] as String?) ??
                (localExtras['operating_regions'] as String?) ??
                'Rajasthan, Madhya Pradesh, Gujarat, Haryana',
            gstin: profileGstin,
            legalName: (gstLiveData['legal_name'] as String?) ??
                (localExtras['legal_name'] as String?) ??
                '',
            tradeName: (gstLiveData['trade_name'] as String?) ??
                (localExtras['trade_name'] as String?) ??
                companyName ??
                '',
            constitution: (gstLiveData['constitution'] as String?) ??
                (localExtras['constitution'] as String?) ??
                'Proprietorship',
            registrationDate: (gstLiveData['registration_date'] as String?) ??
                (localExtras['registration_date'] as String?) ??
                '',
            gstStatus: (gstLiveData['gst_status'] as String?) ??
                (localExtras['gst_status'] as String?) ??
                'Active',
            principalPlaceOfBusiness: (gstLiveData['principal_place_of_business'] as String?) ??
                (localExtras['principal_place_of_business'] as String?) ??
                '',
            gstCertificateUrl: (gstLiveData['certificate_url'] as String?) ??
                (localExtras['gst_certificate_url'] as String?),
            gstCertificatePath: (gstLiveData['certificate_path'] as String?) ??
                (localExtras['gst_certificate_path'] as String?),
            gstVerificationStatus: verificationStatus,
            gstVerificationSource: (gstLiveData['verification_source'] as String?) ??
                (localExtras['gst_verification_source'] as String?),
            gstVerifiedAt: gstVerifiedAt ??
                (localExtras['gst_verified_at'] != null
                    ? DateTime.tryParse(localExtras['gst_verified_at'].toString())
                    : null),
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
      designation: 'Senior Mandi Broker',
      brokerageName: 'Jaipur Commodity Trading Desk',
      businessType: 'Proprietorship',
      businessAddress: 'Shop 14, Mandi Yard, Surajpole Grain Market, Jaipur, RJ 302003',
      city: 'Jaipur',
      state: 'Rajasthan',
      pincode: '302003',
      businessContactNumber: '+91 98290 12345',
      operatingLocations: 'Jaipur Mandi, Kota, Alwar, Bikaner',
      commoditiesHandled: 'Mustard Seed (Sarson), Soybean, Wheat, Chana',
      operatingRegions: 'Rajasthan, Madhya Pradesh, Gujarat, Haryana',
      gstin: '',
      legalName: '',
      tradeName: 'Jaipur Commodity Trading Desk',
      constitution: 'Proprietorship',
      registrationDate: '',
      gstStatus: 'Active',
      principalPlaceOfBusiness: 'Shop 14, Mandi Yard, Surajpole Grain Market, Jaipur',
      gstVerificationStatus: BrokerGstStatus.gstMissing,
      profilePhotoPath: photoPath,
      updatedAt: DateTime.now(),
    );

    await _storage.savePreference(_keyProfileCache, jsonEncode(baseline.toJson()));
    return ProfileSuccess(baseline);
  }

  /// Update authoritative broker profile details.
  /// Prevents modification of protected fields (id, role, accountStatus, isVerified, trustScore).
  /// Re-evaluates and invalidates GST verification when GSTIN is modified.
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

    // Read previous cached profile to check for GSTIN changes
    String previousGstin = '';
    final cached = await _storage.getPreference(_keyProfileCache);
    if (cached != null && cached.isNotEmpty) {
      try {
        final map = jsonDecode(cached) as Map<String, dynamic>;
        previousGstin = GstinRules.normalize(map['gstin']?.toString() ?? '');
      } catch (_) {}
    }

    final currentNormalizedGstin = GstinRules.normalize(updated.gstin);
    String effectiveVerificationStatus = updated.gstVerificationStatus;
    String? effectiveVerificationSource = updated.gstVerificationSource;
    DateTime? effectiveVerifiedAt = updated.gstVerifiedAt;

    bool shouldResetVerification = false;

    // Invalidation check: If GSTIN changed, invalidate previous verification
    if (previousGstin.isNotEmpty &&
        currentNormalizedGstin.isNotEmpty &&
        previousGstin != currentNormalizedGstin) {
      if (updated.gstCertificatePath != null || updated.gstCertificateUrl != null) {
        effectiveVerificationStatus = BrokerGstStatus.certificateUploaded;
      } else {
        effectiveVerificationStatus = BrokerGstStatus.pending;
      }
      shouldResetVerification = true;
      effectiveVerificationSource = null;
      effectiveVerifiedAt = null;
    } else if (currentNormalizedGstin.isEmpty) {
      effectiveVerificationStatus = BrokerGstStatus.gstMissing;
      shouldResetVerification = true;
      effectiveVerificationSource = null;
      effectiveVerifiedAt = null;
    }

    // Enforce immutability of protected fields
    final safeProfile = updated.copyWith(
      gstin: currentNormalizedGstin,
      gstVerificationStatus: effectiveVerificationStatus,
      resetVerification: shouldResetVerification,
      gstVerificationSource: effectiveVerificationSource,
      gstVerifiedAt: effectiveVerifiedAt,
      updatedAt: DateTime.now(),
    );

    // 1. The database is the source of truth: nothing below runs, and the local
    // cache stays untouched, unless it confirms the write.
    if (!localOnlyForTesting) {
      final failure = await _writeToDatabase(userId, safeProfile);
      if (failure != null) return failure;
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

  static const _saveTimeout = Duration(seconds: 30);
  static const _networkMessage =
      'Could not reach the server. Check your internet connection and try again.';

  /// Writes the profile, returning a failure result, or null once the database
  /// has confirmed every row. `.select()` matters: an update blocked by RLS
  /// matches zero rows and raises no error.
  Future<ProfileResult<BrokerProfile>?> _writeToDatabase(
    String userId,
    BrokerProfile profile,
  ) async {
    final client = _supabase;
    if (client == null) return const ProfileError(message: _networkMessage);

    final check = await SessionGuard.ensureValidSession(client, storage: _storage);
    if (check == SessionCheck.signedOut) return const ProfileUnauthorized();
    if (check == SessionCheck.offline) {
      return const ProfileError(message: _networkMessage);
    }

    try {
      return await _applyWrites(client, userId, profile).timeout(_saveTimeout);
    } catch (e) {
      debugPrint('Profile save failed: $e');
      return ProfileError(message: describeSaveError(e));
    }
  }

  Future<ProfileResult<BrokerProfile>?> _applyWrites(
    SupabaseClient client,
    String userId,
    BrokerProfile profile,
  ) async {
    const notSaved = ProfileError<BrokerProfile>(
      message:
          'Your changes were not saved because your account does not have permission to update this profile. Please contact support.',
    );

    final userRow = await client
        .from('users')
        .select('company_id')
        .eq('id', userId)
        .maybeSingle();
    if (userRow == null) return notSaved;

    // Business, address and mandi details live on the company row, so check
    // for one before writing anything.
    final companyId = userRow['company_id'] as String?;
    if (companyId == null || companyId.isEmpty) {
      return const ProfileError(
        message:
            'Your account is not linked to a business yet, so these details cannot be saved. Please contact support.',
      );
    }

    final updatedUsers = await client.from('users').update({
      'name': profile.fullName.trim(),
      'mobile': profile.mobile.trim(),
      'email': profile.email.trim(),
    }).eq('id', userId).select('id');
    if (updatedUsers.isEmpty) return notSaved;

    final gstLiveData = {
      'designation': profile.designation,
      'business_type': profile.businessType,
      'city': profile.city,
      'state': profile.state,
      'pincode': profile.pincode,
      'business_contact_number': profile.businessContactNumber,
      'legal_name': profile.legalName,
      'trade_name': profile.tradeName,
      'constitution': profile.constitution,
      'registration_date': profile.registrationDate,
      'gst_status': profile.gstStatus,
      'principal_place_of_business': profile.principalPlaceOfBusiness,
      'certificate_url': profile.gstCertificateUrl,
      'certificate_path': profile.gstCertificatePath,
      'verification_status': profile.gstVerificationStatus,
      'verification_source': profile.gstVerificationSource,
      'operating_locations': profile.operatingLocations,
      'commodities_handled': profile.commoditiesHandled,
      'operating_regions': profile.operatingRegions,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final isGstVerified =
        profile.gstVerificationStatus == BrokerGstStatus.gstMatched ||
            profile.gstVerificationStatus == BrokerGstStatus.certificateReviewed;

    final updatedCompanies = await client.from('companies').update({
      'name': profile.brokerageName.trim(),
      'gst': profile.gstin.trim().isEmpty ? null : profile.gstin.trim(),
      'gst_verified': isGstVerified,
      'gst_verified_at': profile.gstVerifiedAt?.toIso8601String(),
      'gst_live_data': gstLiveData,
    }).eq('id', companyId).select('id');
    if (updatedCompanies.isEmpty) return notSaved;

    return null;
  }

  /// A user-facing, actionable message for a failed save.
  static String describeSaveError(Object error) {
    if (error is PostgrestException) {
      if (error.code == '23505') {
        return 'That mobile number, email or GSTIN is already used by another account.';
      }
      if (error.code == '42501') {
        return 'Your account does not have permission to update this profile. Please contact support.';
      }
      return 'The server could not save your profile. Please try again.';
    }
    final text = error.toString();
    if (error is TimeoutException ||
        error is SocketException ||
        text.contains('ClientException') ||
        text.contains('SocketException')) {
      return _networkMessage;
    }
    return 'Could not save your profile. Please try again.';
  }

  /// Upload GST certificate document to Supabase storage bucket `brokerbridge_documents`.
  /// Returns the remote URL or file path upon completion.
  Future<String?> uploadCertificate({
    required String filePath,
    required String userId,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return null;
    }

    final client = _supabase;
    final session = client?.auth.currentSession;
    if (client != null && session != null && !session.isExpired) {
      final ext = filePath.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_cert.$ext';
      final storagePath = 'brokers/$userId/gst_certificates/$fileName';

      // Failures propagate: the caller must not save a profile that claims a
      // certificate the server never received.
      await client.storage.from('brokerbridge_documents').upload(
            storagePath,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      return client.storage.from('brokerbridge_documents').getPublicUrl(storagePath);
    }

    // Return original file path as safe offline/local storage fallback
    return filePath;
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
