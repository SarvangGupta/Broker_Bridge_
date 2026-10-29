import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/profile/data/buyer_profile_repository.dart';
import 'package:rmbuyer_mobile/features/profile/data/gst_certificate_ocr_service.dart';
import 'package:rmbuyer_mobile/features/profile/data/gst_draft_repository.dart';
import 'package:rmbuyer_mobile/features/profile/data/gst_verification_repository.dart';
import 'package:rmbuyer_mobile/features/profile/domain/buyer_profile.dart';
import 'package:rmbuyer_mobile/features/profile/domain/gst_certificate_data.dart';
import 'package:rmbuyer_mobile/features/profile/presentation/gst_verification_screen.dart';
import 'package:rmbuyer_mobile/features/profile/presentation/profile_settings_screen.dart';

class _FakeProfileRepo extends BuyerProfileRepository {
  final BuyerProfile _p;
  _FakeProfileRepo(this._p);

  @override
  Future<BuyerProfile> getProfile() async {
    return _p;
  }
}

class _FakeGstSource implements GstVerificationRecordSource {
  final GstVerificationRecord? record;
  bool shouldThrow;
  _FakeGstSource({this.record, this.shouldThrow = false});

  @override
  bool get available => true;

  @override
  Future<GstVerificationRecord?> latestFor(String companyId) async {
    if (shouldThrow) throw Exception('Backend load error');
    return record;
  }

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
  group('RMBUYER-GST-DRAFT-BLANK-01: 10 Regression Scenarios', () {
    const testProfile = BuyerProfile(
      id: 'buyer-user-001',
      name: 'Ramesh Patel',
      mobile: '+919876543210',
      email: 'ramesh@patelagro.com',
      role: 'buyer',
      companyId: 'company-patel-001',
      companyName: 'Patel Agro Industries Ltd',
      companyGst: '24AAAAA0000A1Z5',
      companyVerified: false,
    );

    late InMemoryGstDraftStorage draftStorage;
    late GstDraftRepository draftRepo;

    setUp(() {
      draftStorage = InMemoryGstDraftStorage();
      draftRepo = GstDraftRepository(storage: draftStorage);
    });

    Widget createTestApp({
      required BuyerProfile profile,
      required GstVerificationRecordSource gstSource,
      bool initialAtProfile = true,
      bool autoResumeOnGst = false,
      String? initialLocation,
    }) {
      final profileRepo = _FakeProfileRepo(profile);
      final gstRepo = GstVerificationRepository(
        profiles: profileRepo,
        records: gstSource,
      );

      final router = GoRouter(
        initialLocation: initialLocation ?? (initialAtProfile ? '/profile' : '/gst-verification'),
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => ProfileSettingsScreen(
              repository: profileRepo,
              gstRepository: gstRepo,
              draftRepository: draftRepo,
            ),
          ),
          GoRoute(
            path: '/gst-verification',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final resumeDraft = autoResumeOnGst ||
                  state.uri.queryParameters['resumeDraft'] == 'true' ||
                  extra?['resumeDraft'] == true;
              return GstVerificationScreen(
                repository: gstRepo,
                draftRepository: draftRepo,
                ocr: GstCertificateOcrService(recognizer: (_) async => ''),
                pickImage: (_) async => '/non_existent/dummy.png',
                autoResumeDraft: resumeDraft,
              );
            },
          ),
        ],
      );

      return ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      );
    }

    // 1. Tapping Continue Draft opens the screen with restored values
    testWidgets('1. Tapping Continue Draft in Profile & Settings opens GST screen with restored values', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final draft = GstDraft(
        companyId: testProfile.companyId!,
        userId: testProfile.id,
        values: {
          GstField.gstin: '24AAAAA0000A1Z5',
          GstField.legalName: 'Patel Agro Industries Ltd',
          GstField.address: 'Plot 12, GIDC Estate, Ahmedabad, Gujarat',
          GstField.pinCode: '380001',
          GstField.validityFrom: '01/07/2017',
        },
        savedAt: DateTime.now(),
      );
      await draftRepo.saveDraft(draft);

      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: _FakeGstSource(record: null),
        initialAtProfile: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Draft Saved'), findsOneWidget);
      expect(find.text('Continue Draft'), findsOneWidget);

      // Tap on the GST verification draft card
      await tester.tap(find.byKey(const Key('settings-gst-card')));
      await tester.pumpAndSettle();

      // GST Verification screen is open, NOT blank, and review fields are restored
      expect(find.text('GST Verification'), findsOneWidget);
      expect(find.byKey(const Key('gst-step-progress')), findsOneWidget);
      expect(find.text('Step 3 of 4'), findsOneWidget);

      final legalNameField = tester.widget<TextField>(
        find.byKey(const Key('gst-field-legalName')),
      );
      expect(legalNameField.controller!.text, 'Patel Agro Industries Ltd');

      final gstinField = tester.widget<TextField>(
        find.byKey(const Key('gst-field-gstin')),
      );
      expect(gstinField.controller!.text, '24AAAAA0000A1Z5');
    });

    // 2. Valid local draft restores all fields into controllers
    testWidgets('2. Valid local draft restores all 11 fields into controllers without omission', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final draft = GstDraft(
        companyId: testProfile.companyId!,
        userId: testProfile.id,
        values: {
          GstField.gstin: '24AAAAA0000A1Z5',
          GstField.legalName: 'Patel Agro Industries Ltd',
          GstField.tradeName: 'Patel Agro',
          GstField.constitution: 'Public Limited Company',
          GstField.address: 'Plot 12, GIDC Estate, Ahmedabad, Gujarat',
          GstField.pinCode: '380001',
          GstField.registrationDate: '01/07/2017',
          GstField.registrationType: 'Regular',
          GstField.validityFrom: '01/07/2017',
          GstField.validityTo: 'Not Applicable',
          GstField.issueDate: '05/07/2017',
        },
        savedAt: DateTime.now(),
      );
      await draftRepo.saveDraft(draft);

      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: _FakeGstSource(record: null),
        initialAtProfile: false,
        autoResumeOnGst: true,
      ));
      await tester.pumpAndSettle();

      for (final f in GstField.values) {
        final field = tester.widget<TextField>(find.byKey(Key('gst-field-${f.name}')));
        expect(field.controller!.text, draft.values[f]);
      }
    });

    // 3. Draft with missing Valid From restores successfully
    testWidgets('3. Draft with missing Valid From restores successfully without throwing or blanking', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final draft = GstDraft(
        companyId: testProfile.companyId!,
        userId: testProfile.id,
        values: {
          GstField.gstin: '24AAAAA0000A1Z5',
          GstField.legalName: 'Patel Agro Industries Ltd',
          GstField.address: 'Plot 12, GIDC Estate, Ahmedabad, Gujarat',
          GstField.pinCode: '380001',
          // validityFrom intentionally omitted
        },
        savedAt: DateTime.now(),
      );
      await draftRepo.saveDraft(draft);

      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: _FakeGstSource(record: null),
        initialAtProfile: false,
        autoResumeOnGst: true,
      ));
      await tester.pumpAndSettle();

      final valFromField = tester.widget<TextField>(
        find.byKey(const Key('gst-field-validityFrom')),
      );
      expect(valFromField.controller!.text, '');
      expect(find.byKey(const Key('gst-field-legalName')), findsOneWidget);
    });

    // 4. Null optional fields do not crash the screen
    testWidgets('4. Null optional fields in draft do not crash or blank the screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Only minimal fields
      final draft = GstDraft(
        companyId: testProfile.companyId!,
        userId: testProfile.id,
        values: {
          GstField.gstin: '24AAAAA0000A1Z5',
          GstField.legalName: 'Patel Agro Industries Ltd',
        },
        savedAt: DateTime.now(),
      );
      await draftRepo.saveDraft(draft);

      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: _FakeGstSource(record: null),
        initialAtProfile: false,
        autoResumeOnGst: true,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gst-field-tradeName')), findsOneWidget);
      expect(find.byKey(const Key('gst-field-constitution')), findsOneWidget);
    });

    // 5. Missing certificate file does not blank the form
    testWidgets('5. Missing certificate file does not blank the review form', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final draft = GstDraft(
        companyId: testProfile.companyId!,
        userId: testProfile.id,
        values: {
          GstField.gstin: '24AAAAA0000A1Z5',
          GstField.legalName: 'Patel Agro Industries Ltd',
          GstField.address: 'Plot 12, GIDC Estate, Ahmedabad, Gujarat',
          GstField.pinCode: '380001',
        },
        imagePath: null, // missing certificate file
        savedAt: DateTime.now(),
      );
      await draftRepo.saveDraft(draft);

      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: _FakeGstSource(record: null),
        initialAtProfile: false,
        autoResumeOnGst: true,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gst-field-legalName')), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
    });

    // 6. Corrupt draft data produces visible recovery state
    testWidgets('6. Corrupt draft data in storage falls back gracefully without blanking', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Write corrupted JSON into storage
      await draftStorage.write(
        'gst_draft_${testProfile.companyId}_${testProfile.id}',
        '{"invalid": "corrupt json structure missing expected keys", "values": 12345}',
      );

      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: _FakeGstSource(record: null),
        initialAtProfile: false,
        autoResumeOnGst: true,
      ));
      await tester.pumpAndSettle();

      // Screen opens normally in Step 1 (Upload), NOT blank
      expect(find.byKey(const Key('gst-step-progress')), findsOneWidget);
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
    });

    // 7. Draft loading failure produces Retry or ErrorState instead of blank screen
    testWidgets('7. Backend failure on load produces clear Error State with Retry instead of blank screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final failingSource = _FakeGstSource(record: null, shouldThrow: true);

      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: failingSource,
        initialAtProfile: false,
        autoResumeOnGst: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Your verification status could not be loaded.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      // Recover backend and retry
      failingSource.shouldThrow = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gst-step-progress')), findsOneWidget);
      expect(find.text('Not Verified'), findsOneWidget);
    });

    // 8. Saving and reopening preserves edits
    testWidgets('8. Saving draft and reopening restores updated edits accurately', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final draft1 = GstDraft(
        companyId: testProfile.companyId!,
        userId: testProfile.id,
        values: {
          GstField.gstin: '24AAAAA0000A1Z5',
          GstField.legalName: 'Initial Name',
          GstField.address: 'Plot 12, GIDC Estate, Ahmedabad, Gujarat',
          GstField.pinCode: '380001',
        },
        savedAt: DateTime.now(),
      );
      await draftRepo.saveDraft(draft1);

      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: _FakeGstSource(record: null),
        initialAtProfile: false,
        autoResumeOnGst: true,
      ));
      await tester.pumpAndSettle();

      // Modify legal name
      final legalNameField = find.byKey(const Key('gst-field-legalName'));
      await tester.enterText(legalNameField, 'Updated Legal Enterprise Ltd');
      await tester.pumpAndSettle();

      // Tap Save Draft
      await tester.ensureVisible(find.byKey(const Key('gst-save-draft')));
      await tester.tap(find.byKey(const Key('gst-save-draft')));
      await tester.pumpAndSettle();

      // Inspect persisted draft
      final updated = await draftRepo.getDraft(
        companyId: testProfile.companyId!,
        userId: testProfile.id,
      );
      expect(updated, isNotNull);
      expect(updated!.values[GstField.legalName], 'Updated Legal Enterprise Ltd');
    });

    // 9. Draft belonging to another user/company cannot be loaded (scoped isolation)
    testWidgets('9. Draft belonging to another company/user is strictly isolated', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Save draft for Company B and User B
      final otherDraft = GstDraft(
        companyId: 'company-other-999',
        userId: 'other-user-999',
        values: {
          GstField.gstin: '27BBBBB9999B1Z1',
          GstField.legalName: 'Other Firm Restricted',
        },
        savedAt: DateTime.now(),
      );
      await draftRepo.saveDraft(otherDraft);

      // Open screen for Patel Agro (Company Patel 001)
      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: _FakeGstSource(record: null),
        initialAtProfile: false,
        autoResumeOnGst: true,
      ));
      await tester.pumpAndSettle();

      // No draft should be resumed for this user
      expect(find.byKey(const Key('gst-draft-banner')), findsNothing);
      expect(find.text('Step 1 of 4'), findsOneWidget);
    });

    // 10. New verification session still opens normally
    testWidgets('10. New verification session without draft opens normally in Step 1 Upload', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: _FakeGstSource(record: null),
        initialAtProfile: false,
        autoResumeOnGst: false,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gst-step-progress')), findsOneWidget);
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
      expect(find.text('GST certificate'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.byKey(const Key('gst-draft-banner')), findsNothing);
    });
  });
}

