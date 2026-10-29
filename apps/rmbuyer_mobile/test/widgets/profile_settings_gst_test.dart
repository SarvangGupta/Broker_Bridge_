import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/profile/data/gst_verification_repository.dart';
import 'package:rmbuyer_mobile/features/profile/domain/buyer_profile.dart';
import 'package:rmbuyer_mobile/features/profile/domain/gst_certificate_data.dart';
import 'package:rmbuyer_mobile/features/profile/presentation/profile_settings_screen.dart';

import '../support/fake_buyer_profile_repository.dart';

class _FakeGstSource implements GstVerificationRecordSource {
  GstVerificationRecord? record;
  bool shouldThrow;

  _FakeGstSource({this.record, this.shouldThrow = false});

  @override
  bool get available => true;

  @override
  Future<GstVerificationRecord?> latestFor(String companyId) async {
    if (shouldThrow) throw Exception('Network timeout from Supabase');
    return record;
  }

  @override
  Future<GstVerificationRecord> submit(GstSubmissionDraft draft, String imagePath) {
    throw UnimplementedError();
  }
}

void main() {
  const testProfile = BuyerProfile(
    id: 'user-001',
    name: 'Rajesh Singhal',
    mobile: '+919876543210',
    email: 'rajesh@apexprocurement.com',
    role: 'buyer',
    companyId: 'comp-100',
    companyName: 'Apex Commodities Pvt Ltd',
    companyGst: '08AAAAA1111A1Z',
    companyVerified: false,
  );

  Widget makeTestWidget({
    required _FakeGstSource gstSource,
    BuyerProfile profile = testProfile,
  }) {
    final profileRepo = FakeBuyerProfileRepository(profile: profile);
    final gstRepo = GstVerificationRepository(
      profiles: profileRepo,
      records: gstSource,
    );

    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => ProfileSettingsScreen(
            repository: profileRepo,
            gstRepository: gstRepo,
          ),
        ),
        GoRoute(
          path: '/gst-verification',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('GST Verification Screen Destination')),
          ),
        ),
        GoRoute(
          path: '/settings/warehouses',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Warehouses Screen Destination')),
          ),
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

  group('ProfileSettingsScreen GST Verification & Warehouses', () {
    testWidgets('Approved GST record displays Verified badge and view details action', (
      tester,
    ) async {
      final gstSource = _FakeGstSource(
        record: const GstVerificationRecord(
          status: GstVerificationStatus.approved,
          gstin: '08AAAAA1111A1Z',
          legalName: 'Apex Commodities Pvt Ltd',
        ),
      );

      await tester.pumpWidget(makeTestWidget(gstSource: gstSource));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-gst-card')), findsOneWidget);
      expect(find.byKey(const Key('settings-gst-verified-badge')), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Your business GST certificate is verified.'), findsOneWidget);
      expect(find.text('View Verified GST Details'), findsOneWidget);
    });

    testWidgets('Pending GST record displays Pending badge and awaiting review status', (
      tester,
    ) async {
      final gstSource = _FakeGstSource(
        record: const GstVerificationRecord(
          status: GstVerificationStatus.pending,
          gstin: '08AAAAA1111A1Z',
        ),
      );

      await tester.pumpWidget(makeTestWidget(gstSource: gstSource));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-gst-pending-badge')), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Submitted — Awaiting Admin verification.'), findsOneWidget);
      expect(find.text('View Verification Status'), findsOneWidget);
    });

    testWidgets('Rejected GST record displays Rejected badge and rejection reason', (
      tester,
    ) async {
      final gstSource = _FakeGstSource(
        record: const GstVerificationRecord(
          status: GstVerificationStatus.rejected,
          rejectionReason: 'REG-06 page 2 missing, please upload full scan',
        ),
      );

      await tester.pumpWidget(makeTestWidget(gstSource: gstSource));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-gst-rejected-badge')), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(
        find.text('Reason: REG-06 page 2 missing, please upload full scan'),
        findsOneWidget,
      );
      expect(find.text('Resubmit GST Certificate'), findsOneWidget);
    });

    testWidgets('No record / Not Submitted displays Not Verified badge and start verification action', (
      tester,
    ) async {
      final gstSource = _FakeGstSource(record: null);

      await tester.pumpWidget(makeTestWidget(gstSource: gstSource));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-gst-not-verified-badge')), findsOneWidget);
      expect(find.text('Not Verified'), findsOneWidget);
      expect(find.text('No GST certificate submitted.'), findsOneWidget);
      expect(find.text('Start Verification'), findsOneWidget);
    });

    testWidgets('GST load failure shows error banner and retry recovers on button press', (
      tester,
    ) async {
      final gstSource = _FakeGstSource(shouldThrow: true);

      await tester.pumpWidget(makeTestWidget(gstSource: gstSource));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-gst-card-error')), findsOneWidget);
      expect(
        find.text('GST verification status could not be loaded.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings-gst-retry')), findsOneWidget);

      // Now fix the backend and tap retry
      gstSource.shouldThrow = false;
      gstSource.record = const GstVerificationRecord(
        status: GstVerificationStatus.approved,
      );

      await tester.tap(find.byKey(const Key('settings-gst-retry')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-gst-card-error')), findsNothing);
      expect(find.byKey(const Key('settings-gst-verified-badge')), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('Tapping GST Verification card navigates to /gst-verification', (
      tester,
    ) async {
      final gstSource = _FakeGstSource(record: null);

      await tester.pumpWidget(makeTestWidget(gstSource: gstSource));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings-gst-card')));
      await tester.pumpAndSettle();

      expect(find.text('GST Verification Screen Destination'), findsOneWidget);
    });

    testWidgets('Tapping Warehouses & Unloading navigates to /settings/warehouses', (
      tester,
    ) async {
      final gstSource = _FakeGstSource(record: null);

      await tester.pumpWidget(makeTestWidget(gstSource: gstSource));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings-warehouses')));
      await tester.pumpAndSettle();

      expect(find.text('Warehouses Screen Destination'), findsOneWidget);
    });
  });
}
