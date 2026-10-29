import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/home/presentation/more_screen.dart';
import 'package:rmbuyer_mobile/features/profile/data/gst_certificate_ocr_service.dart';
import 'package:rmbuyer_mobile/features/profile/data/gst_verification_repository.dart';
import 'package:rmbuyer_mobile/features/profile/domain/buyer_profile.dart';
import 'package:rmbuyer_mobile/features/profile/domain/gst_certificate_data.dart';
import 'package:rmbuyer_mobile/features/profile/presentation/gst_verification_screen.dart';

import '../support/fake_buyer_profile_repository.dart';
import '../unit/gst_certificate_test.dart' show certificateText, validGstin;
import '../unit/gst_reference_certificate_test.dart' show referenceOcr;

// No saved company name/GSTIN, so certificates in these tests raise no
// identity mismatch; the identity group below covers that explicitly.
const _unverified = BuyerProfile(
  id: 'b-001',
  name: 'Rajesh Singhal',
  role: 'buyer',
  companyId: 'c-001',
  companyVerified: false,
);

/// Stands in for the 0054 backend: reads the latest record and, like the
/// submit RPC, stores a pending record only when the "server" succeeds.
class _FakeRecords implements GstVerificationRecordSource {
  GstVerificationRecord? record;
  Object? error;
  Object? submitError;
  Completer<void>? submitGate;
  final List<String> companiesRead = [];
  final List<GstSubmissionDraft> submitted = [];
  final List<String> uploadedPaths = [];

  @override
  bool get available => true;

  @override
  Future<GstVerificationRecord?> latestFor(String companyId) async {
    companiesRead.add(companyId);
    if (error != null) throw error!;
    return record;
  }

  @override
  Future<GstVerificationRecord> submit(
    GstSubmissionDraft draft,
    String imagePath,
  ) async {
    submitted.add(draft);
    uploadedPaths.add(imagePath);
    if (submitGate != null) await submitGate!.future;
    if (submitError != null) throw submitError!;
    record = GstVerificationRecord(
      status: GstVerificationStatus.pending,
      gstin: draft.submitted[GstField.gstin],
    );
    return record!;
  }
}

class _Harness {
  final FakeBuyerProfileRepository profiles;
  GstVerificationRecordSource records = const NoGstVerificationBackend();
  final List<ImageSource> picks = [];
  String? pickedPath = '/tmp/certificate.jpg';
  Object? pickError;
  String ocrText;

  _Harness({BuyerProfile profile = _unverified, String? ocrText})
    : profiles = FakeBuyerProfileRepository(profile: profile),
      ocrText = ocrText ?? certificateText(validGstin());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: GstVerificationScreen(
            repository: GstVerificationRepository(
              profiles: profiles,
              records: records,
            ),
            ocr: GstCertificateOcrService(recognizer: (_) async => ocrText),
            pickImage: (source) async {
              picks.add(source);
              if (pickError != null) throw pickError!;
              return pickedPath;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

String _badge(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const Key('gst-status-badge')),
        matching: find.byType(Text),
      ),
    )
    .data!;

String _field(WidgetTester tester, String name) => tester
    .widget<TextField>(find.byKey(Key('gst-field-$name')))
    .controller!
    .text;

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('More lists GST Verification', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const MoreScreen()),
    );
    expect(find.byKey(const Key('more-gst-verification')), findsOneWidget);
    expect(find.text('GST Verification'), findsOneWidget);
  });

  group('GST status truth (RMBUYER-GST-STATUS-TRUTH-01)', () {
    const legacyVerified = BuyerProfile(
      id: 'b-001',
      name: 'R',
      role: 'buyer',
      companyId: 'c-001',
      companyName: 'Apex Grain Processors Pvt Ltd',
      companyVerified: true,
    );

    testWidgets(
      'regression: is_verified=true with no GST record is NOT shown as Verified',
      (tester) async {
        // Reproduces the device defect: legacy flag true, no certificate ever submitted.
        await _Harness(profile: legacyVerified).pump(tester);
        expect(_badge(tester), 'Not Verified');
        expect(find.text('Verified'), findsNothing);
        expect(find.textContaining('business is verified'), findsNothing);
        expect(find.byKey(const Key('gst-legacy-flag-note')), findsOneWidget);
        expect(
          find.textContaining('online submission is not available yet'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('gst-take-photo')), findsOneWidget);
      },
    );

    testWidgets('an authoritative approved record shows Verified, no upload', (
      tester,
    ) async {
      final h = _Harness(profile: legacyVerified)
        ..records = (_FakeRecords()
          ..record = const GstVerificationRecord(
            status: GstVerificationStatus.approved,
          ));
      await h.pump(tester);
      expect(_badge(tester), 'Verified');
      expect(find.byKey(const Key('gst-legacy-flag-note')), findsNothing);
      expect(find.byKey(const Key('gst-take-photo')), findsNothing);
    });

    testWidgets('approved record shows Verified even without the legacy flag', (
      tester,
    ) async {
      final h = _Harness()
        ..records = (_FakeRecords()
          ..record = const GstVerificationRecord(
            status: GstVerificationStatus.approved,
          ));
      await h.pump(tester);
      expect(_badge(tester), 'Verified');
    });

    testWidgets('a pending record shows Pending and no new upload', (
      tester,
    ) async {
      final h = _Harness()
        ..records = (_FakeRecords()
          ..record = const GstVerificationRecord(
            status: GstVerificationStatus.pending,
          ));
      await h.pump(tester);
      expect(_badge(tester), 'Pending');
      expect(find.text('Submitted — Awaiting Verification.'), findsOneWidget);
      expect(find.byKey(const Key('gst-take-photo')), findsNothing);
    });

    testWidgets('a rejected record shows its reason and allows re-upload', (
      tester,
    ) async {
      final h = _Harness()
        ..records = (_FakeRecords()
          ..record = const GstVerificationRecord(
            status: GstVerificationStatus.rejected,
            rejectionReason: 'Certificate image is cut off.',
          ));
      await h.pump(tester);
      expect(_badge(tester), 'Rejected');
      expect(find.text('Certificate image is cut off.'), findsOneWidget);
      expect(find.byKey(const Key('gst-take-photo')), findsOneWidget);
    });

    testWidgets('a GST record read failure shows an error, never a status', (
      tester,
    ) async {
      final h = _Harness(profile: legacyVerified)
        ..records = (_FakeRecords()..error = Exception('timeout'));
      await h.pump(tester);
      expect(find.byKey(const Key('gst-status-badge')), findsNothing);
      expect(
        find.text('Your verification status could not be loaded.'),
        findsOneWidget,
      );
    });

    testWidgets('records are read for the signed-in user\'s own company only', (
      tester,
    ) async {
      final records = _FakeRecords();
      final h = _Harness()..records = records;
      await h.pump(tester);
      expect(records.companiesRead, ['c-001']);
    });

    testWidgets('no company: no record read and no upload', (tester) async {
      final records = _FakeRecords();
      final h = _Harness(
        profile: const BuyerProfile(id: 'b-001', name: 'R', role: 'buyer'),
      )..records = records;
      await h.pump(tester);
      expect(records.companiesRead, isEmpty);
      expect(find.byKey(const Key('gst-take-photo')), findsNothing);
    });

    testWidgets(
      'saved profile details load from the backend and OCR does not change them',
      (tester) async {
        final h = _Harness(
          profile: const BuyerProfile(
            id: 'b-001',
            name: 'R',
            role: 'buyer',
            companyId: 'c-001',
            companyName: 'Apex Grain Processors Pvt Ltd',
            companyGst: '08ADRPK6597J1ZL',
          ),
          ocrText: certificateText(validGstin()),
        );
        await h.pump(tester);
        String saved(String k) =>
            tester.widget<Text>(find.byKey(Key('gst-saved-$k'))).data!;
        expect(saved('company'), 'Apex Grain Processors Pvt Ltd');
        expect(saved('gstin'), '08ADRPK6597J1ZL');
        expect(saved('state'), 'Rajasthan');

        await _tap(tester, 'gst-take-photo');
        await _tap(tester, 'gst-submit');
        expect(saved('company'), 'Apex Grain Processors Pvt Ltd');
        expect(saved('gstin'), '08ADRPK6597J1ZL');
        expect(h.profiles.writes, isEmpty);
      },
    );
  });

  testWidgets(
    'an unverified company shows Not Verified and both upload options',
    (tester) async {
      await _Harness().pump(tester);
      expect(_badge(tester), 'Not Verified');
      expect(find.byKey(const Key('gst-take-photo')), findsOneWidget);
      expect(find.byKey(const Key('gst-pick-gallery')), findsOneWidget);
    },
  );

  testWidgets('a failed status load shows an error, not a status', (
    tester,
  ) async {
    final h = _Harness()..profiles.loadError = Exception('offline');
    await h.pump(tester);
    expect(find.byKey(const Key('gst-status-badge')), findsNothing);
    expect(
      find.text('Your verification status could not be loaded.'),
      findsOneWidget,
    );
  });

  testWidgets('camera and gallery picks fill the review form from OCR', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    await _tap(tester, 'gst-take-photo');
    expect(h.picks, [ImageSource.camera]);
    expect(find.byKey(const Key('gst-preview')), findsOneWidget);
    expect(_field(tester, 'gstin'), validGstin());
    expect(_field(tester, 'legalName'), 'MAHESH KUMAR SHARMA');
    expect(_field(tester, 'tradeName'), 'SHARMA FEED TRADERS');
    expect(_field(tester, 'constitution'), 'Proprietorship');
    expect(_field(tester, 'pinCode'), '334001');
    expect(_field(tester, 'registrationDate'), '01/07/2017');
    expect(_field(tester, 'registrationType'), 'Regular');
    expect(
      find.text('From GSTIN: PAN ABCDE1234F · State Rajasthan'),
      findsOneWidget,
    );
    await _tap(tester, 'gst-pick-gallery');
    expect(h.picks, [ImageSource.camera, ImageSource.gallery]);
  });

  testWidgets(
    'user edits are kept and flagged; missing fields are highlighted',
    (tester) async {
      final h = _Harness(
        ocrText: certificateText(validGstin())
            .replaceAll('7. Type of Registration Regular\n', ''),
      );
      await h.pump(tester);
      await _tap(tester, 'gst-pick-gallery');
      // Registration type (removed) and issue date (absent) are both highlighted.
      expect(_field(tester, 'registrationType'), '');
      expect(_field(tester, 'issueDate'), '');
      expect(
        find.text('Not found on the certificate — please enter it'),
        findsNWidgets(2),
      );

      await tester.enterText(
        find.byKey(const Key('gst-field-tradeName')),
        'SHARMA FEEDS',
      );
      await tester.pump();
      expect(_field(tester, 'tradeName'), 'SHARMA FEEDS');
      expect(find.text('Edited by you'), findsOneWidget);
    },
  );

  testWidgets('invalid fields block submission with clear errors', (
    tester,
  ) async {
    await _Harness().pump(tester);
    await _tap(tester, 'gst-take-photo');
    final g = validGstin();
    await tester.enterText(
      find.byKey(const Key('gst-field-gstin')),
      g.substring(0, 14) + (g[14] == 'A' ? 'B' : 'A'),
    );
    await tester.enterText(find.byKey(const Key('gst-field-legalName')), '');
    await tester.pump();
    await _tap(tester, 'gst-submit');
    expect(
      find.text('This GSTIN fails the check-character test'),
      findsOneWidget,
    );
    expect(
      find.text('Edited — differs from the certificate reading'),
      findsNothing,
    );
    expect(find.text('Required'), findsOneWidget);
    expect(find.byKey(const Key('gst-submit-unavailable')), findsNothing);
  });

  testWidgets(
    'a valid submission saves nothing, shows no success and stays Not Verified',
    (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await _tap(tester, 'gst-take-photo');
      await _tap(tester, 'gst-submit');
      expect(find.byKey(const Key('gst-submit-unavailable')), findsOneWidget);
      expect(find.textContaining('nothing was saved'), findsOneWidget);
      expect(_badge(tester), 'Not Verified');
      expect(h.profiles.writes, isEmpty);
    },
  );

  testWidgets('unreadable images and picker failures show an error', (
    tester,
  ) async {
    final h = _Harness(ocrText: '');
    await h.pump(tester);
    await _tap(tester, 'gst-take-photo');
    expect(find.byKey(const Key('gst-ocr-error')), findsOneWidget);

    h.pickError = Exception('camera denied');
    await _tap(tester, 'gst-take-photo');
    expect(find.textContaining('camera could not be opened'), findsOneWidget);
  });

  testWidgets('refresh re-reads the status from the backend', (tester) async {
    final records = _FakeRecords()
      ..record = const GstVerificationRecord(
        status: GstVerificationStatus.pending,
      );
    final h = _Harness()..records = records;
    await h.pump(tester);
    expect(_badge(tester), 'Pending');
    // The admin approves on the server; a refresh shows the real result.
    records.record = const GstVerificationRecord(
      status: GstVerificationStatus.approved,
    );
    await tester.tap(find.byKey(const Key('gst-refresh')));
    await tester.pumpAndSettle();
    expect(_badge(tester), 'Verified');
    expect(h.profiles.loads, 2);

    // Pull-to-refresh reads the backend again as well.
    await tester.drag(
      find.byKey(const Key('gst-status-badge')),
      const Offset(0, 800),
    );
    await tester.pumpAndSettle();
    expect(h.profiles.loads, 3);
  });

  group('reference certificate (RMBUYER-GST-E2E-VALIDATION-01)', () {
    testWidgets('every extracted value lands in its own field', (tester) async {
      await _Harness(ocrText: referenceOcr).pump(tester);
      await _tap(tester, 'gst-pick-gallery');
      expect(_field(tester, 'gstin'), '08ADRPK6597J1ZL');
      expect(_field(tester, 'legalName'), 'HARI SHANKAR KHANDELWAL');
      expect(_field(tester, 'tradeName'), 'Shiv Shanker Pashu Aahar Udyog');
      expect(_field(tester, 'constitution'), 'Proprietorship');
      expect(
        _field(tester, 'address'),
        'A-6, KABAR MARG, BANI PARK, Jaipur, Rajasthan, 302006',
      );
      expect(_field(tester, 'pinCode'), '302006');
      expect(_field(tester, 'registrationDate'), '01/07/2017');
      expect(_field(tester, 'registrationType'), 'Regular');
      expect(_field(tester, 'validityFrom'), '');
      expect(_field(tester, 'validityTo'), 'Not Applicable');
      expect(_field(tester, 'issueDate'), '16/06/2022');
      expect(
        find.text('From GSTIN: PAN ADRPK6597J · State Rajasthan'),
        findsOneWidget,
      );
      // The repaired GSTIN and trade name are called out; the unread validity
      // start is highlighted and stays editable.
      expect(
        find.text('Corrected from the OCR reading — please compare'),
        findsNWidgets(2),
      );
      expect(
        find.textContaining('could not be read (OCR read "Jo/O7/2017")'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('gst-field-validityFrom')),
        '01/07/2017',
      );
      await tester.pump();
      expect(_field(tester, 'validityFrom'), '01/07/2017');
      expect(
        find.text('Not found on the certificate — please enter it'),
        findsOneWidget,
      );
    });

    testWidgets('edits survive validation and repeated submit attempts', (
      tester,
    ) async {
      final h = _Harness(ocrText: referenceOcr);
      await h.pump(tester);
      await _tap(tester, 'gst-take-photo');
      await tester.enterText(
        find.byKey(const Key('gst-field-tradeName')),
        'Shiv Shanker Pashu Aahar Udyog',
      );
      await tester.enterText(
        find.byKey(const Key('gst-field-pinCode')),
        '30200',
      );
      await tester.pump();
      await _tap(tester, 'gst-submit');
      expect(find.text('Enter a 6-digit PIN code'), findsOneWidget);
      expect(_field(tester, 'tradeName'), 'Shiv Shanker Pashu Aahar Udyog');

      await tester.enterText(
        find.byKey(const Key('gst-field-pinCode')),
        '302006',
      );
      await tester.pump();
      await _tap(tester, 'gst-submit');
      await _tap(tester, 'gst-submit');
      expect(_field(tester, 'tradeName'), 'Shiv Shanker Pashu Aahar Udyog');
      expect(_field(tester, 'pinCode'), '302006');
      expect(find.byKey(const Key('gst-submit-unavailable')), findsOneWidget);
      expect(_badge(tester), 'Not Verified');
      expect(h.profiles.writes, isEmpty);
    });

    testWidgets('an address in another state is rejected before submission', (
      tester,
    ) async {
      await _Harness(ocrText: referenceOcr).pump(tester);
      await _tap(tester, 'gst-take-photo');
      await tester.enterText(
        find.byKey(const Key('gst-field-address')),
        'A-6, Bani Park, Ahmedabad, Gujarat, 380001',
      );
      await tester.pump();
      await _tap(tester, 'gst-submit');
      expect(
        find.text(
          'The state in this address does not match the GSTIN state code',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('gst-submit-unavailable')), findsNothing);
    });

    testWidgets('Replace re-reads the new image and replaces the values', (
      tester,
    ) async {
      final h = _Harness(ocrText: referenceOcr);
      await h.pump(tester);
      await _tap(tester, 'gst-take-photo');
      expect(_field(tester, 'legalName'), 'HARI SHANKAR KHANDELWAL');

      h.ocrText = certificateText(validGstin());
      await _tap(tester, 'gst-pick-gallery');
      expect(_field(tester, 'legalName'), 'MAHESH KUMAR SHARMA');
      expect(_field(tester, 'issueDate'), '');
    });
  });

  group('identity mismatch (RMBUYER-GST-FORM-FIX-02)', () {
    // The device case: signed-in account's company vs another business's certificate.
    const rohan = BuyerProfile(
      id: 'b-ro',
      name: 'Rohan Gupta',
      role: 'buyer',
      companyId: 'c-ro',
      companyName: 'Rohan Gupta Pvt. Ltd.',
      companyVerified: false,
    );

    testWidgets('warns, keeps the profile, and needs explicit confirmation', (
      tester,
    ) async {
      final records = _FakeRecords();
      final h = _Harness(profile: rohan, ocrText: referenceOcr)
        ..records = records;
      await h.pump(tester);
      expect(records.companiesRead, [
        'c-ro',
      ]); // the signed-in user's own company
      await _tap(tester, 'gst-take-photo');

      expect(find.byKey(const Key('gst-identity-warning')), findsOneWidget);
      expect(
        find.textContaining('Rohan Gupta Pvt. Ltd." does not match'),
        findsOneWidget,
      );
      expect(
        find.text('Your saved profile is not changed by this screen.'),
        findsOneWidget,
      );
      // The old "→" replacement wording is gone.
      expect(find.textContaining('→'), findsNothing);

      await _tap(tester, 'gst-submit');
      expect(records.submitted, isEmpty);
      expect(find.byKey(const Key('gst-identity-error')), findsOneWidget);
      expect(find.byKey(const Key('gst-submit-success')), findsNothing);

      await _tap(tester, 'gst-identity-confirm');
      await _tap(tester, 'gst-submit');
      expect(records.submitted, hasLength(1));
      // Saved company details untouched; no profile write from the client.
      expect(
        tester.widget<Text>(find.byKey(const Key('gst-saved-company'))).data,
        'Rohan Gupta Pvt. Ltd.',
      );
      expect(h.profiles.writes, isEmpty);
    });

    testWidgets('a new photo resets the confirmation', (tester) async {
      final records = _FakeRecords();
      final h = _Harness(profile: rohan, ocrText: referenceOcr)
        ..records = records;
      await h.pump(tester);
      await _tap(tester, 'gst-take-photo');
      await _tap(tester, 'gst-identity-confirm');
      await _tap(tester, 'gst-pick-gallery');
      await _tap(tester, 'gst-submit');
      expect(records.submitted, isEmpty);
      expect(find.byKey(const Key('gst-identity-error')), findsOneWidget);
    });

    testWidgets(
      'sole proprietor whose profile carries the trade name is not blocked',
      (tester) async {
        final records = _FakeRecords();
        final h = _Harness(
          profile: const BuyerProfile(
            id: 'b-hs',
            name: 'Hari Shankar',
            role: 'buyer',
            companyId: 'c-hs',
            companyName: 'Shiv Shanker Pashu Aahar Udyog',
          ),
          ocrText: referenceOcr,
        )..records = records;
        await h.pump(tester);
        await _tap(tester, 'gst-take-photo');
        expect(find.byKey(const Key('gst-identity-warning')), findsNothing);
        await _tap(tester, 'gst-submit');
        expect(records.submitted, hasLength(1));
      },
    );

    testWidgets(
      'unavailable backend: labelled "Check details", explains, never succeeds',
      (tester) async {
        final h = _Harness(profile: rohan, ocrText: referenceOcr);
        await h.pump(tester);
        await _tap(tester, 'gst-take-photo');
        expect(
          find.byKey(const Key('gst-submission-unavailable-note')),
          findsOneWidget,
        );
        expect(find.text('Check details'), findsOneWidget);
        expect(find.text('Submit for Verification'), findsNothing);
        await _tap(tester, 'gst-identity-confirm');
        await _tap(tester, 'gst-submit');
        expect(find.byKey(const Key('gst-submit-unavailable')), findsOneWidget);
        expect(find.byKey(const Key('gst-submit-success')), findsNothing);
        expect(_badge(tester), 'Not Verified');
        expect(h.profiles.writes, isEmpty);
      },
    );
  });

  group('secure submission (RMBUYER-GST-BACKEND-01)', () {
    testWidgets(
      'server-confirmed submit sends the displayed values, then reloads Pending',
      (tester) async {
        final records = _FakeRecords();
        final h = _Harness(ocrText: referenceOcr)..records = records;
        await h.pump(tester);
        await _tap(tester, 'gst-take-photo');
        // The buyer fills in the unreadable Valid-from cell from the certificate.
        await tester.enterText(
          find.byKey(const Key('gst-field-validityFrom')),
          '01/07/2017',
        );
        await tester.pump();
        await _tap(tester, 'gst-submit');

        expect(records.submitted, hasLength(1));
        final draft = records.submitted.single;
        expect(draft.submitted[GstField.gstin], '08ADRPK6597J1ZL');
        expect(
          draft.submitted[GstField.tradeName],
          'Shiv Shanker Pashu Aahar Udyog',
        );
        expect(draft.submitted[GstField.validityFrom], '01/07/2017');
        expect(draft.editedFields, {GstField.validityFrom});
        expect(records.uploadedPaths.single, '/tmp/certificate.jpg');
        // Nothing about status/approval/company travels from the client.
        expect(draft.toPayload().toString(), isNot(contains('is_verified')));

        expect(find.byKey(const Key('gst-submit-success')), findsOneWidget);
        expect(_badge(tester), 'Pending');
        expect(find.byKey(const Key('gst-take-photo')), findsNothing);
        expect(h.profiles.writes, isEmpty);
      },
    );

    testWidgets('reopening the screen reloads the saved Pending record', (
      tester,
    ) async {
      final records = _FakeRecords();
      final h = _Harness(ocrText: referenceOcr)..records = records;
      await h.pump(tester);
      await _tap(tester, 'gst-take-photo');
      await _tap(tester, 'gst-submit');

      // A fresh screen instance (navigate away and back) reads the backend again.
      await tester.pumpWidget(const SizedBox());
      await h.pump(tester);
      expect(_badge(tester), 'Pending');
      expect(find.byKey(const Key('gst-submit-success')), findsNothing);
    });

    testWidgets('a server failure shows an actionable error and no success', (
      tester,
    ) async {
      final records = _FakeRecords()
        ..submitError = const PostgrestException(
          message: 'this GSTIN is already registered',
          code: '23505',
        );
      final h = _Harness(ocrText: referenceOcr)..records = records;
      await h.pump(tester);
      await _tap(tester, 'gst-take-photo');
      await _tap(tester, 'gst-submit');
      expect(
        find.text(
          'This GSTIN is already registered for verification by another account.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('gst-submit-success')), findsNothing);
      expect(_badge(tester), 'Not Verified');
      // The buyer's values are still there to correct and retry.
      expect(_field(tester, 'gstin'), '08ADRPK6597J1ZL');
    });

    testWidgets('a timeout is reported without claiming success', (
      tester,
    ) async {
      final records = _FakeRecords()..submitError = TimeoutException('slow');
      final h = _Harness(ocrText: referenceOcr)..records = records;
      await h.pump(tester);
      await _tap(tester, 'gst-take-photo');
      await _tap(tester, 'gst-submit');
      expect(
        find.textContaining('No response from the server'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('gst-submit-success')), findsNothing);
    });

    testWidgets('a second tap while submitting does not send a duplicate', (
      tester,
    ) async {
      final records = _FakeRecords()..submitGate = Completer<void>();
      final h = _Harness(ocrText: referenceOcr)..records = records;
      await h.pump(tester);
      await _tap(tester, 'gst-take-photo');
      await tester.ensureVisible(find.byKey(const Key('gst-submit')));
      await tester.tap(find.byKey(const Key('gst-submit')));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('gst-submit')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(records.submitted, hasLength(1));
      records.submitGate!.complete();
      await tester.pumpAndSettle();
      expect(_badge(tester), 'Pending');
    });

    testWidgets('invalid values are never sent to the server', (tester) async {
      final records = _FakeRecords();
      final h = _Harness(ocrText: referenceOcr)..records = records;
      await h.pump(tester);
      await _tap(tester, 'gst-take-photo');
      await tester.enterText(
        find.byKey(const Key('gst-field-pinCode')),
        '30200',
      );
      await tester.pump();
      await _tap(tester, 'gst-submit');
      expect(records.submitted, isEmpty);
      expect(find.text('Enter a 6-digit PIN code'), findsOneWidget);
    });
  });
}
