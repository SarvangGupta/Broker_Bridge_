import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:rmbuyer_mobile/features/profile/data/buyer_profile_repository.dart';
import 'package:rmbuyer_mobile/features/profile/data/gst_verification_repository.dart';
import 'package:rmbuyer_mobile/features/profile/domain/buyer_profile.dart';
import 'package:rmbuyer_mobile/features/profile/domain/gst_certificate_data.dart';

import '../support/fake_buyer_profile_repository.dart';

class _Records implements GstVerificationRecordSource {
  final GstVerificationRecord? record;
  const _Records(this.record);
  @override
  bool get available => true;
  @override
  Future<GstVerificationRecord?> latestFor(String companyId) async => record;
  @override
  Future<GstVerificationRecord> submit(
    GstSubmissionDraft draft,
    String imagePath,
  ) => throw UnimplementedError();
}

GstVerificationRepository _repo(
  BuyerProfile p, [
  GstVerificationRecordSource? r,
]) => GstVerificationRepository(
  profiles: FakeBuyerProfileRepository(profile: p),
  records: r ?? const NoGstVerificationBackend(),
);

const _legacyVerified = BuyerProfile(
  id: 'b-1',
  name: 'R',
  role: 'buyer',
  companyId: 'c-1',
  companyVerified: true,
);

void main() {
  group('status source', () {
    test(
      'legacy is_verified=true with no GST record is notSubmitted',
      () async {
        final s = await _repo(_legacyVerified).loadStatus();
        expect(s.status, GstVerificationStatus.notSubmitted);
        expect(s.hasUnbackedLegacyFlag, isTrue);
      },
    );

    test('is_verified=false and no record is notSubmitted', () async {
      final s = await _repo(
        const BuyerProfile(
          id: 'b-1',
          name: 'R',
          role: 'buyer',
          companyId: 'c-1',
          companyVerified: false,
        ),
      ).loadStatus();
      expect(s.status, GstVerificationStatus.notSubmitted);
      expect(s.hasUnbackedLegacyFlag, isFalse);
    });

    test('only a record sets approved / pending / rejected', () async {
      for (final st in [
        GstVerificationStatus.approved,
        GstVerificationStatus.pending,
        GstVerificationStatus.rejected,
      ]) {
        final s = await _repo(
          _legacyVerified,
          _Records(GstVerificationRecord(status: st)),
        ).loadStatus();
        expect(s.status, st);
      }
    });

    test('the live backend has no submission support yet', () {
      expect(const NoGstVerificationBackend().available, isFalse);
      expect(_repo(_legacyVerified).submissionAvailable, isFalse);
    });

    test(
      'profile read failure propagates (screen shows an error, not a status)',
      () async {
        final profiles = FakeBuyerProfileRepository()
          ..loadError = Exception('offline');
        final repo = GstVerificationRepository(profiles: profiles);
        expect(repo.loadStatus(), throwsException);
      },
    );
  });

  group('GstVerificationRecord.fromRow', () {
    test('parses the planned buyer_gst_verifications columns', () {
      final r = GstVerificationRecord.fromRow({
        'status': 'rejected',
        'gstin': '08ADRPK6597J1ZL',
        'rejection_reason': 'Blurred image',
        'submitted_at': '2026-10-29T06:00:00Z',
        'reviewed_at': '2026-10-29T07:00:00Z',
      });
      expect(r.status, GstVerificationStatus.rejected);
      expect(r.rejectionReason, 'Blurred image');
      expect(r.reviewedAt, DateTime.utc(2026, 10, 29, 7));
    });

    test('an unknown or missing status throws instead of being guessed', () {
      expect(
        () => GstVerificationRecord.fromRow({'status': 'verified'}),
        throwsFormatException,
      );
      expect(() => GstVerificationRecord.fromRow({}), throwsFormatException);
    });
  });

  group('backend selection never reaches production before rollout', () {
    test('default build uses no GST backend', () {
      expect(AppConfig.gstVerificationBackendEnabled, isFalse);
      expect(defaultGstVerificationSource(), isA<NoGstVerificationBackend>());
    });

    test('the flag is refused for the production project and allowed for a test project', () {
      expect(
        AppConfig.gstVerificationBackendAllowed(
          requested: true,
          supabaseUrl: 'https://${AppConfig.productionProjectRef}.supabase.co',
        ),
        isFalse,
      );
      expect(
        AppConfig.gstVerificationBackendAllowed(
          requested: true,
          supabaseUrl: 'https://brokerbridge-test.supabase.co',
        ),
        isTrue,
      );
      expect(
        AppConfig.gstVerificationBackendAllowed(
          requested: false,
          supabaseUrl: 'https://brokerbridge-test.supabase.co',
        ),
        isFalse,
      );
    });

    test('server errors map by SQLSTATE to buyer-facing text', () {
      expect(
        GstSubmissionException.describe(
          const PostgrestException(message: 'x', code: '42501'),
        ),
        contains('not allowed'),
      );
      expect(
        GstSubmissionException.describe(
          const PostgrestException(message: 'invalid GSTIN', code: '22023'),
        ),
        contains('invalid GSTIN'),
      );
    });
  });

  group('company mapping and client writes', () {
    test('company comes from the users row; no fallback company id', () {
      final p = BuyerProfileRepository.profileFromRows({
        'id': 'b-1',
        'name': 'R',
        'role': 'buyer',
        'company_id': null,
      }, null);
      expect(p.companyId, isNull);
      expect(p.companyVerified, isNull);
    });

    test('approval and trust fields are dropped before any client write', () {
      final allowed = BuyerProfileRepository.editableChanges({
        'name': 'R',
        'mobile': '+919876543210',
        'is_verified': true,
        'status': true,
        'trust_score': 100,
        'company_id': 'other',
        'role': 'admin',
      });
      expect(allowed.keys.toSet(), {'name', 'mobile'});
    });
  });
}
