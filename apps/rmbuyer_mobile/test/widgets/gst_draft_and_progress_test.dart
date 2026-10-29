import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/profile/data/buyer_profile_repository.dart';
import 'package:rmbuyer_mobile/features/profile/data/gst_certificate_ocr_service.dart';
import 'package:rmbuyer_mobile/features/profile/data/gst_draft_repository.dart';
import 'package:rmbuyer_mobile/features/profile/data/gst_verification_repository.dart';
import 'package:rmbuyer_mobile/features/profile/domain/buyer_profile.dart';
import 'package:rmbuyer_mobile/features/profile/domain/gst_certificate_data.dart';
import 'package:rmbuyer_mobile/features/profile/presentation/gst_verification_screen.dart';
import 'package:rmbuyer_mobile/features/profile/presentation/profile_settings_screen.dart';

class _FakeBuyerProfileRepo extends BuyerProfileRepository {
  final BuyerProfile _p;
  _FakeBuyerProfileRepo(this._p);

  @override
  Future<BuyerProfile> getProfile() async => _p;
}

class _FakeGstSource implements GstVerificationRecordSource {
  final GstVerificationRecord? record;
  _FakeGstSource({this.record});

  @override
  bool get available => true;

  @override
  Future<GstVerificationRecord?> latestFor(String companyId) async => record;

  @override
  Future<GstVerificationRecord> submit(GstSubmissionDraft draft, String imagePath) async {
    return GstVerificationRecord(
      status: GstVerificationStatus.pending,
      gstin: draft.submitted[GstField.gstin],
      legalName: draft.submitted[GstField.legalName],
    );
  }
}

void main() {
  group('GST Verification: 4-Step Progress & Save/Resume Draft Workflow', () {
    late InMemoryGstDraftStorage draftStorage;
    late GstDraftRepository draftRepo;
    late BuyerProfile profile;

    setUp(() {
      draftStorage = InMemoryGstDraftStorage();
      draftRepo = GstDraftRepository(storage: draftStorage);
      profile = const BuyerProfile(
        id: 'user-001',
        name: 'Rajesh Singhal',
        role: 'buyer',
        email: 'rajesh@acme.com',
        mobile: '+919876543210',
        companyId: 'company-001',
        companyName: 'Acme Agro Ltd',
        companyGst: '08AAAAA0000A1Z5',
      );
    });

    Widget createScreen({
      GstVerificationRecord? record,
      String? ocrText,
    }) {
      final gstRepo = GstVerificationRepository(
        profiles: _FakeBuyerProfileRepo(profile),
        records: _FakeGstSource(record: record),
      );

      return MaterialApp(
        home: GstVerificationScreen(
          repository: gstRepo,
          draftRepository: draftRepo,
          ocr: GstCertificateOcrService(recognizer: (_) async => ocrText ?? ''),
          pickImage: (_) async => '/tmp/cert.png',
        ),
      );
    }

    testWidgets('shows Step Progress tracker with 4 steps', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gst-step-progress')), findsOneWidget);
      expect(find.text('Verification Progress'), findsOneWidget);
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
      expect(find.text('Extract'), findsOneWidget);
      expect(find.text('Review/Draft'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
    });

    testWidgets('saves draft locally and updates draft banner', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const ocr = '''
Government of India
Form GST REG-06
Registration Certificate
Registration Number: 08AAAAA0000A1Z5
1. Legal Name: Acme Agro Ltd
2. Trade Name: Acme Agro
3. Constitution of Business: Private Limited Company
4. Address of Principal Place of Business: Plot 42, Sitapura, Jaipur, Rajasthan
PIN: 302022
5. Date of Liability: 01/07/2017
6. Period of Validity: From 01/07/2017 To Not Applicable
7. Type of Registration: Regular
''';

      await tester.pumpWidget(createScreen(ocrText: ocr));
      await tester.pumpAndSettle();

      // Trigger pick via gallery
      await tester.ensureVisible(find.byKey(const Key('gst-pick-gallery')));
      await tester.tap(find.byKey(const Key('gst-pick-gallery')));
      await tester.pumpAndSettle();

      // Form is now populated, Step progress advances to 3
      expect(find.text('Step 3 of 4'), findsOneWidget);
      expect(find.byKey(const Key('gst-save-draft')), findsOneWidget);

      // Tap Save Draft
      await tester.ensureVisible(find.byKey(const Key('gst-save-draft')));
      await tester.tap(find.byKey(const Key('gst-save-draft')));
      await tester.pumpAndSettle();

      // SnackBar shows confirmation
      expect(find.text('Draft saved locally on this device.'), findsOneWidget);

      // Verify stored in repository
      final savedDraft = await draftRepo.getDraft(
        companyId: profile.companyId!,
        userId: profile.id,
      );
      expect(savedDraft, isNotNull);
      expect(savedDraft!.values[GstField.gstin], '08AAAAA0000A1Z5');
      expect(savedDraft.values[GstField.legalName], 'Acme Agro Ltd');
      expect(savedDraft.values[GstField.validityFrom], '01/07/2017');
    });

    testWidgets('resumes and discards saved draft correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Pre-save a draft
      final preDraft = GstDraft(
        companyId: profile.companyId!,
        userId: profile.id,
        values: {
          GstField.gstin: '08AAAAA0000A1Z5',
          GstField.legalName: 'PreSaved Agro Corp',
          GstField.address: '100 Industrial Area, Jaipur, Rajasthan',
          GstField.pinCode: '302001',
          GstField.validityFrom: '01/07/2017',
        },
        imagePath: '/tmp/cert.png',
        savedAt: DateTime.now(),
      );
      await draftRepo.saveDraft(preDraft);

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Draft banner is visible
      expect(find.byKey(const Key('gst-draft-banner')), findsOneWidget);
      expect(find.text('Draft Saved on Device'), findsOneWidget);
      expect(find.byKey(const Key('gst-resume-draft-btn')), findsOneWidget);

      // Tap Resume Draft
      await tester.tap(find.byKey(const Key('gst-resume-draft-btn')));
      await tester.pumpAndSettle();

      // Form fields are pre-filled
      final nameField = tester.widget<TextField>(find.byKey(const Key('gst-field-legalName')));
      expect(nameField.controller!.text, 'PreSaved Agro Corp');

      final gstinField = tester.widget<TextField>(find.byKey(const Key('gst-field-gstin')));
      expect(gstinField.controller!.text, '08AAAAA0000A1Z5');

      // Now tap Discard
      await tester.ensureVisible(find.byKey(const Key('gst-discard-draft-btn')));
      await tester.tap(find.byKey(const Key('gst-discard-draft-btn')));
      await tester.pumpAndSettle();

      // Confirmation dialog opens
      expect(find.text('Discard Saved Draft?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('gst-confirm-discard-btn')));
      await tester.pumpAndSettle();

      // Draft is discarded
      expect(find.byKey(const Key('gst-draft-banner')), findsNothing);
      expect(await draftRepo.hasDraft(companyId: profile.companyId!, userId: profile.id), isFalse);
    });

    testWidgets('ProfileSettingsScreen shows Draft Saved badge when draft exists', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final preDraft = GstDraft(
        companyId: profile.companyId!,
        userId: profile.id,
        values: {
          GstField.gstin: '08AAAAA0000A1Z5',
          GstField.legalName: 'Drafted Firm',
        },
        savedAt: DateTime.now(),
      );
      await draftRepo.saveDraft(preDraft);

      final gstRepo = GstVerificationRepository(
        profiles: _FakeBuyerProfileRepo(profile),
        records: _FakeGstSource(record: null),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProfileSettingsScreen(
              repository: _FakeBuyerProfileRepo(profile),
              gstRepository: gstRepo,
              draftRepository: draftRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Draft Saved badge is rendered
      expect(find.byKey(const Key('settings-gst-draft-badge')), findsOneWidget);
      expect(find.text('Draft Saved'), findsOneWidget);
      expect(find.text('Continue Draft'), findsOneWidget);
      expect(find.byKey(const Key('settings-business-profile-card')), findsOneWidget);
    });
  });
}
