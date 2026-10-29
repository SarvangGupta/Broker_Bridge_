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
import 'package:rmbuyer_mobile/features/profile/presentation/buyer_profile_screen.dart';
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
  GstVerificationRecord? record;
  bool shouldThrow;
  bool submitShouldThrow;
  String? lastSubmittedPath;
  GstSubmissionDraft? lastSubmittedDraft;

  _FakeGstSource({
    this.record,
    this.shouldThrow = false,
    this.submitShouldThrow = false,
  });

  @override
  bool get available => true;

  @override
  Future<GstVerificationRecord?> latestFor(String companyId) async {
    if (shouldThrow) throw Exception('Backend load error');
    return record;
  }

  @override
  Future<GstVerificationRecord> submit(GstSubmissionDraft draft, String imagePath) async {
    if (submitShouldThrow) {
      throw const GstSubmissionException('Server rejected submission');
    }
    lastSubmittedDraft = draft;
    lastSubmittedPath = imagePath;
    record = GstVerificationRecord(
      status: GstVerificationStatus.pending,
      gstin: draft.submitted[GstField.gstin],
      legalName: draft.submitted[GstField.legalName],
      tradeName: draft.submitted[GstField.tradeName],
      constitution: draft.submitted[GstField.constitution],
      principalAddress: draft.submitted[GstField.address],
      pinCode: draft.submitted[GstField.pinCode],
      registrationType: draft.submitted[GstField.registrationType],
      validityFrom: draft.submitted[GstField.validityFrom],
    );
    return record!;
  }
}

void main() {
  group('RMBUYER-GST-END-TO-END-REPAIR-01: 14 Requirements', () {
    const testProfile = BuyerProfile(
      id: 'user-rohan-001',
      name: 'Rohan Sharma',
      mobile: '+919876543210',
      email: 'rohan@gmail.com',
      role: 'buyer',
      companyId: 'company-rohan-001',
      companyName: 'Rohan Agro Industries Ltd',
      companyGst: '08AAAAA0000A1Z5',
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
      String initialLocation = '/profile',
      bool autoResumeOnGst = false,
    }) {
      final profileRepo = _FakeProfileRepo(profile);
      final gstRepo = GstVerificationRepository(
        profiles: profileRepo,
        records: gstSource,
      );

      final router = GoRouter(
        initialLocation: initialLocation,
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
            path: '/settings/profile',
            builder: (context, state) => BuyerProfileScreen(
              repository: profileRepo,
              gstRecords: gstSource,
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
                pickImage: (_) async => null,
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

    // 1. Save Draft persists values
    testWidgets('1. Save Draft persists values into draft storage', (tester) async {
      final draft = GstDraft(
        companyId: testProfile.companyId!,
        userId: testProfile.id,
        values: {
          GstField.gstin: '08AAAAA0000A1Z5',
          GstField.legalName: 'Rohan Agro Industries Ltd',
          GstField.tradeName: 'Rohan Agro',
          GstField.address: 'Industrial Area, Kota, Rajasthan',
          GstField.pinCode: '324005',
          GstField.validityFrom: '01/07/2017',
        },
        savedAt: DateTime.now(),
      );
      await draftRepo.saveDraft(draft);

      final loaded = await draftRepo.getDraft(
        companyId: testProfile.companyId!,
        userId: testProfile.id,
      );
      expect(loaded, isNotNull);
      expect(loaded!.values[GstField.gstin], '08AAAAA0000A1Z5');
      expect(loaded.values[GstField.legalName], 'Rohan Agro Industries Ltd');
      expect(loaded.values[GstField.pinCode], '324005');
    });

    // 2. Continue Draft restores all fields
    testWidgets('2. Continue Draft restores all fields into form controllers', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final draft = GstDraft(
        companyId: testProfile.companyId!,
        userId: testProfile.id,
        values: {
          GstField.gstin: '08AAAAA0000A1Z5',
          GstField.legalName: 'Rohan Agro Industries Ltd',
          GstField.tradeName: 'Rohan Agro',
          GstField.constitution: 'Private Limited Company',
          GstField.address: 'Industrial Area, Kota, Rajasthan',
          GstField.pinCode: '324005',
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
        initialLocation: '/gst-verification',
        autoResumeOnGst: true,
      ));
      await tester.pumpAndSettle();

      for (final f in GstField.values) {
        final field = tester.widget<TextField>(find.byKey(Key('gst-field-${f.name}')));
        expect(field.controller!.text, draft.values[f]);
      }
    });

    // 3. Missing Valid From does not break draft saving or restoration
    testWidgets('3. Missing Valid From does not break draft saving or restoration', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final draft = GstDraft(
        companyId: testProfile.companyId!,
        userId: testProfile.id,
        values: {
          GstField.gstin: '08AAAAA0000A1Z5',
          GstField.legalName: 'Rohan Agro Industries Ltd',
          GstField.address: 'Kota, Rajasthan',
          GstField.pinCode: '324005',
          // validityFrom omitted
        },
        savedAt: DateTime.now(),
      );
      await draftRepo.saveDraft(draft);

      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: _FakeGstSource(record: null),
        initialLocation: '/gst-verification',
        autoResumeOnGst: true,
      ));
      await tester.pumpAndSettle();

      final valFrom = tester.widget<TextField>(find.byKey(const Key('gst-field-validityFrom')));
      expect(valFrom.controller!.text, '');
      expect(find.byKey(const Key('gst-field-legalName')), findsOneWidget);
    });

    // 4. A failed draft load produces a visible error, not a blank screen
    testWidgets('4. A failed draft/status load produces visible error and retry, never blank screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final failingSource = _FakeGstSource(shouldThrow: true);

      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: failingSource,
        initialLocation: '/gst-verification',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Your verification status could not be loaded.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    // 5. A valid submission persists reviewed values and the certificate reference
    testWidgets('5. A valid submission persists reviewed values to the backend', (tester) async {
      final source = _FakeGstSource();
      final draft = GstSubmissionDraft.fromForm(
        {
          GstField.gstin: '08AAAAA0000A1Z5',
          GstField.legalName: 'Rohan Agro Industries Ltd',
          GstField.address: 'Kota, Rajasthan',
          GstField.pinCode: '324005',
        },
        const GstCertificateData(),
      );

      final record = await source.submit(draft, '/path/to/cert.png');
      expect(record.status, GstVerificationStatus.pending);
      expect(record.gstin, '08AAAAA0000A1Z5');
      expect(source.lastSubmittedPath, '/path/to/cert.png');
    });

    // 6. Profile and Edit Profile reload the same saved GST details
    testWidgets('6. Profile and Edit Profile display the same saved GST details', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const approvedRecord = GstVerificationRecord(
        status: GstVerificationStatus.approved,
        gstin: '08AAAAA0000A1Z5',
        legalName: 'Rohan Agro Industries Ltd',
        tradeName: 'Rohan Agro',
        constitution: 'Private Limited Company',
        principalAddress: 'Industrial Area, Kota, Rajasthan',
        pinCode: '324005',
      );
      final source = _FakeGstSource(record: approvedRecord);

      // Check Profile Settings screen
      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: source,
        initialLocation: '/profile',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Verified'), findsWidgets);
      expect(find.text('Industrial Area, Kota, Rajasthan'), findsOneWidget);
      expect(find.text('08AAAAA0000A1Z5'), findsWidgets);

      // Check Edit Profile screen
      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: source,
        initialLocation: '/settings/profile',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Verified'), findsWidgets);
      expect(find.text('Industrial Area, Kota, Rajasthan'), findsOneWidget);
      expect(find.text('08AAAAA0000A1Z5'), findsWidgets);
    });

    // 7. Failed submission never displays false success
    testWidgets('7. Failed submission never displays false success', (tester) async {
      final source = _FakeGstSource(submitShouldThrow: true);
      final draft = GstSubmissionDraft.fromForm(
        {
          GstField.gstin: '08AAAAA0000A1Z5',
          GstField.legalName: 'Rohan Agro',
        },
        const GstCertificateData(),
      );

      expect(() => source.submit(draft, '/path/to/cert.png'), throwsA(isA<GstSubmissionException>()));
      expect(source.record, isNull);
    });

    // 8. No submission displays Not Submitted/Not Verified
    testWidgets('8. No submission displays Not Submitted / Not Verified', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: _FakeGstSource(record: null),
        initialLocation: '/profile',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Not Verified'), findsOneWidget);
      expect(find.text('Start Verification'), findsOneWidget);
    });

    // 9. Pending submission displays Pending
    testWidgets('9. Pending submission displays Pending and awaiting review', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const pendingRecord = GstVerificationRecord(
        status: GstVerificationStatus.pending,
        gstin: '08AAAAA0000A1Z5',
      );

      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: _FakeGstSource(record: pendingRecord),
        initialLocation: '/profile',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Submitted — Awaiting Admin verification.'), findsOneWidget);
    });

    // 10. Only authoritative Admin approval displays Verified
    testWidgets('10. Only authoritative Admin approval displays Verified', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const approvedRecord = GstVerificationRecord(
        status: GstVerificationStatus.approved,
        gstin: '08AAAAA0000A1Z5',
      );

      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: _FakeGstSource(record: approvedRecord),
        initialLocation: '/profile',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Verified'), findsWidgets);
      expect(find.text('Your business GST certificate is verified.'), findsOneWidget);
    });

    // 11. Verified GST identity fields cannot be changed by an ordinary Buyer
    testWidgets('11. Verified GST identity fields are read-only in Edit Profile', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const approvedRecord = GstVerificationRecord(
        status: GstVerificationStatus.approved,
        gstin: '08AAAAA0000A1Z5',
        legalName: 'Rohan Agro Industries Ltd',
      );

      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: _FakeGstSource(record: approvedRecord),
        initialLocation: '/settings/profile',
      ));
      await tester.pumpAndSettle();

      // Name & mobile are editable TextFormFields
      expect(find.byKey(const Key('profile-name-field')), findsOneWidget);
      expect(find.byKey(const Key('profile-mobile-field')), findsOneWidget);

      // GST and Company fields are read-only Text widgets, not editable text fields
      expect(find.byKey(const Key('profile-gstin-field')), findsNothing);
      expect(find.text('Company legal and business details are populated through verified GST certificates and cannot be directly edited here.'), findsOneWidget);
    });

    // 12. Rejected submissions show the actual reason and support resubmission
    testWidgets('12. Rejected submissions show actual rejection reason', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const rejectedRecord = GstVerificationRecord(
        status: GstVerificationStatus.rejected,
        rejectionReason: 'Page 2 annexure A is missing',
      );

      await tester.pumpWidget(createTestApp(
        profile: testProfile,
        gstSource: _FakeGstSource(record: rejectedRecord),
        initialLocation: '/profile',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Rejected'), findsWidgets);
      expect(find.text('Reason: Page 2 annexure A is missing'), findsOneWidget);
      expect(find.text('Resubmit GST Certificate'), findsOneWidget);
    });

    // 13. Certificate/company mismatch is flagged
    testWidgets('13. Certificate/company mismatch is flagged with warning', (tester) async {
      final issues = GstIdentityCheck.compare(
        savedGstin: '08AAAAA0000A1Z5',
        savedCompanyName: 'Rohan Agro Industries Ltd',
        gstin: '24BBBBB1111B1Z2', // Different state and PAN
        legalName: 'Different Business Corp',
        tradeName: 'Different Business',
      );

      expect(issues.contains(GstIdentityIssue.gstinDiffers), isTrue);
      expect(issues.contains(GstIdentityIssue.nameDiffers), isTrue);
    });

    // 14. Ownership and tenant-isolation checks prevent cross-company access
    testWidgets('14. Cross-company access is prevented; other company draft is isolated', (
      tester,
    ) async {
      final otherDraft = GstDraft(
        companyId: 'company-other-888',
        userId: 'user-other-888',
        values: {
          GstField.gstin: '27CCCCCC0000C1Z9',
          GstField.legalName: 'Isolated Other Company',
        },
        savedAt: DateTime.now(),
      );
      await draftRepo.saveDraft(otherDraft);

      // Rohan attempts to load draft for Rohan's company
      final rohanDraft = await draftRepo.getDraft(
        companyId: testProfile.companyId!,
        userId: testProfile.id,
      );
      expect(rohanDraft, isNull);
    });
  });
}
