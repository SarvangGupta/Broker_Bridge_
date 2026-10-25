import 'dart:async';

import 'package:rmbuyer_mobile/features/profile/data/buyer_profile_repository.dart';
import 'package:rmbuyer_mobile/features/profile/domain/buyer_profile.dart';

/// In-memory stand-in for the `users`/`companies` rows: saves are kept in
/// [stored] so a second screen load sees them, like a real reopen would.
class FakeBuyerProfileRepository extends BuyerProfileRepository {
  BuyerProfile stored;
  Object? loadError;
  Object? saveError;
  Completer<void>? saveGate;
  int loads = 0;
  final List<Map<String, Object?>> writes = [];

  FakeBuyerProfileRepository({BuyerProfile? profile})
    : stored =
          profile ??
          const BuyerProfile(
            id: 'b-001',
            name: 'Rajesh Singhal',
            mobile: '+919876543210',
            email: 'buyer@apexprocurement.com',
            role: 'buyer',
            companyId: 'c-001',
            companyName: 'Apex Grain Processors Pvt Ltd',
            companyGst: '08AABCA1234F1Z8',
            companyVerified: false,
          );

  @override
  Future<BuyerProfile> getProfile() async {
    loads++;
    if (loadError != null) throw loadError!;
    return stored;
  }

  @override
  Future<BuyerProfile> updateProfile(
    BuyerProfile current,
    Map<String, Object?> changes,
  ) async {
    final allowed = BuyerProfileRepository.editableChanges(changes);
    writes.add(allowed);
    if (saveGate != null) await saveGate!.future;
    if (saveError != null) throw saveError!;
    stored = stored.copyWith(
      name: allowed['name'] as String?,
      mobile: allowed['mobile'] as String?,
      clearMobile: allowed.containsKey('mobile') && allowed['mobile'] == null,
    );
    return stored;
  }
}
