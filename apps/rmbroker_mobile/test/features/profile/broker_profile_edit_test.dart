import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/features/authentication/domain/broker_user.dart';
import 'package:rmbroker_mobile/features/dashboard/presentation/widgets/broker_welcome_banner.dart';
import 'package:rmbroker_mobile/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:rmbroker_mobile/features/profile/data/profile_repository.dart';
import 'package:rmbroker_mobile/features/profile/domain/broker_profile.dart';
import 'package:rmbroker_mobile/features/profile/presentation/broker_profile_screen.dart';

void main() {
  late SecureStorageService storage;

  setUp(() async {
    storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    await storage.clearAll();
    await storage.saveUserInfo(
      id: 'broker-test-202',
      role: 'broker',
      email: 'mukesh@sharmatrading.in',
      fullName: 'Mukesh Sharma',
    );
  });

  group('RMBROKER-PROFILE-EDIT-FIX-01: Domain Model & Validation', () {
    test('BrokerProfile supports all personal, business and GST fields', () {
      final now = DateTime.now();
      final profile = BrokerProfile(
        id: 'broker-test-202',
        role: 'BROKER',
        fullName: 'Mukesh Sharma',
        mobile: '9829098290',
        email: 'mukesh@sharmatrading.in',
        designation: 'Managing Director',
        profilePhotoPath: '/data/user/0/photo.jpg',
        brokerageName: 'Sharma Mandi Brokerage Desk',
        businessType: 'Proprietorship',
        businessAddress: 'Shop 15, Mandi Yard, Surajpole, Jaipur',
        city: 'Jaipur',
        state: 'Rajasthan',
        pincode: '302003',
        businessContactNumber: '01412567890',
        operatingLocations: 'Jaipur Mandi, Kota, Alwar',
        commoditiesHandled: 'Mustard Seed, Soybean, Wheat',
        operatingRegions: 'North & Western Mandis',
        gstin: '08AAAAA0000A1Z5',
        legalName: 'MUKESH SHARMA TRADING CO',
        tradeName: 'Sharma Mandi Brokerage Desk',
        constitution: 'Proprietorship',
        registrationDate: '01/07/2017',
        gstStatus: 'Active',
        principalPlaceOfBusiness: 'Shop 15, Mandi Yard, Surajpole, Jaipur, RJ',
        gstCertificatePath: '/data/user/0/cert.pdf',
        gstCertificateUrl: 'https://example.com/cert.pdf',
        gstVerificationStatus: BrokerGstStatus.certificateReviewed,
        gstVerificationSource: 'broker_self_review',
        gstVerifiedAt: now,
        updatedAt: now,
      );

      expect(profile.validate(), isNull);
      expect(profile.designation, 'Managing Director');
      expect(profile.businessType, 'Proprietorship');
      expect(profile.city, 'Jaipur');
      expect(profile.state, 'Rajasthan');
      expect(profile.pincode, '302003');
      expect(profile.businessContactNumber, '01412567890');
      expect(profile.gstin, '08AAAAA0000A1Z5');
      expect(profile.legalName, 'MUKESH SHARMA TRADING CO');
      expect(profile.tradeName, 'Sharma Mandi Brokerage Desk');
      expect(profile.constitution, 'Proprietorship');
      expect(profile.gstVerificationStatus, BrokerGstStatus.certificateReviewed);
      expect(profile.gstVerificationSource, 'broker_self_review');
      expect(profile.gstVerifiedAt, now);
    });

    test('Validates PIN code and GSTIN structure', () {
      final now = DateTime.now();
      final base = BrokerProfile(
        id: 'broker-test-202',
        role: 'BROKER',
        fullName: 'Mukesh Sharma',
        mobile: '9829098290',
        email: 'mukesh@sharmatrading.in',
        brokerageName: 'Sharma Mandi',
        updatedAt: now,
      );

      // Invalid PIN code
      final badPin = base.copyWith(pincode: '30200'); // only 5 digits
      expect(badPin.validate(), contains('PIN code must be a valid 6-digit number'));

      // Valid PIN code
      final goodPin = base.copyWith(pincode: '302003');
      expect(goodPin.validate(), isNull);

      // Invalid GSTIN (not 15 chars)
      final badGst = base.copyWith(gstin: '08AAAA');
      expect(badGst.validate(), contains('GSTIN must follow the 15-character standard format'));

      // Valid GSTIN
      final goodGst = base.copyWith(gstin: '08AAAAA0000A1Z5');
      expect(goodGst.validate(), isNull);
    });

    test('toJson and fromJson preserves all profile fields across serialization', () {
      final now = DateTime.now();
      final original = BrokerProfile(
        id: 'broker-test-202',
        role: 'BROKER',
        fullName: 'Mukesh Sharma',
        mobile: '9829098290',
        email: 'mukesh@sharmatrading.in',
        designation: 'Managing Director',
        brokerageName: 'Sharma Mandi Desk',
        businessType: 'Partnership',
        businessAddress: 'Shop 15, Mandi Yard',
        city: 'Jaipur',
        state: 'Rajasthan',
        pincode: '302003',
        businessContactNumber: '01412567890',
        operatingLocations: 'Jaipur, Kota',
        commoditiesHandled: 'Mustard Seed',
        operatingRegions: 'Rajasthan',
        gstin: '08AAAAA0000A1Z5',
        legalName: 'SHARMA BROTHERS',
        tradeName: 'Sharma Mandi Desk',
        constitution: 'Partnership',
        registrationDate: '01/07/2017',
        gstStatus: 'Active',
        principalPlaceOfBusiness: 'Shop 15, Mandi Yard, Jaipur',
        gstCertificatePath: '/tmp/cert.jpg',
        gstCertificateUrl: 'https://storage/cert.jpg',
        gstVerificationStatus: BrokerGstStatus.gstMatched,
        gstVerificationSource: 'official_portal',
        gstVerifiedAt: now,
        updatedAt: now,
      );

      final json = original.toJson();
      final reconstructed = BrokerProfile.fromJson(json);

      expect(reconstructed.id, original.id);
      expect(reconstructed.designation, original.designation);
      expect(reconstructed.businessType, original.businessType);
      expect(reconstructed.city, original.city);
      expect(reconstructed.state, original.state);
      expect(reconstructed.pincode, original.pincode);
      expect(reconstructed.businessContactNumber, original.businessContactNumber);
      expect(reconstructed.gstin, original.gstin);
      expect(reconstructed.legalName, original.legalName);
      expect(reconstructed.tradeName, original.tradeName);
      expect(reconstructed.constitution, original.constitution);
      expect(reconstructed.gstVerificationStatus, BrokerGstStatus.gstMatched);
      expect(reconstructed.gstVerificationSource, 'official_portal');
    });

    test('BrokerGstStatus display labels match micro-sprint specification', () {
      expect(
        BrokerGstStatus.displayLabel(BrokerGstStatus.gstMissing),
        'GST Details Missing',
      );
      expect(
        BrokerGstStatus.displayLabel(BrokerGstStatus.pending),
        'Pending Verification',
      );
      expect(
        BrokerGstStatus.displayLabel(BrokerGstStatus.certificateUploaded),
        'Certificate Uploaded',
      );
      expect(
        BrokerGstStatus.displayLabel(BrokerGstStatus.certificateReviewed),
        'Broker Verified — Certificate Reviewed',
      );
      expect(
        BrokerGstStatus.displayLabel(BrokerGstStatus.gstMatched),
        'GST Details Matched with Official GST Portal',
      );
      expect(
        BrokerGstStatus.displayLabel(BrokerGstStatus.inactive),
        'GST Registration Inactive',
      );
      expect(
        BrokerGstStatus.displayLabel(BrokerGstStatus.failed),
        'Verification Failed',
      );
    });
  });

  group('RMBROKER-PROFILE-EDIT-FIX-01: GST Verification Invalidation on GSTIN Change', () {
    test('Modifying GSTIN invalidates previous verification status', () async {
      final repo = ProfileRepository(storage: storage, localOnlyForTesting: true);
      final initialResult = await repo.getProfile();
      expect(initialResult, isA<ProfileSuccess<BrokerProfile>>());

      final initialProfile = (initialResult as ProfileSuccess<BrokerProfile>).data;

      // 1. Save profile with an established GSTIN and verified status
      final verifiedProfile = initialProfile.copyWith(
        gstin: '08AAAAA0000A1Z5',
        legalName: 'ORIGINAL BUSINESS NAME',
        gstCertificatePath: '/data/user/cert.jpg',
        gstVerificationStatus: BrokerGstStatus.certificateReviewed,
        gstVerificationSource: 'broker_self_review',
        gstVerifiedAt: DateTime.now(),
      );

      final saveResult1 = await repo.updateProfile(verifiedProfile);
      expect(saveResult1, isA<ProfileSuccess<BrokerProfile>>());
      final saved1 = (saveResult1 as ProfileSuccess<BrokerProfile>).data;
      expect(saved1.gstVerificationStatus, BrokerGstStatus.certificateReviewed);

      // 2. Change the GSTIN to a different number
      final changedGstinProfile = saved1.copyWith(
        gstin: '08BBBBB1111B2Z6',
        legalName: 'NEW BUSINESS NAME',
      );

      final saveResult2 = await repo.updateProfile(changedGstinProfile);
      expect(saveResult2, isA<ProfileSuccess<BrokerProfile>>());
      final saved2 = (saveResult2 as ProfileSuccess<BrokerProfile>).data;

      // Invalidation verified: previous verified status must not carry forward!
      expect(saved2.gstVerificationStatus, isNot(BrokerGstStatus.certificateReviewed));
      expect(saved2.gstVerificationStatus, BrokerGstStatus.certificateUploaded);
      expect(saved2.gstVerificationSource, isNull);
      expect(saved2.gstVerifiedAt, isNull);
    });

    test('Clearing GSTIN resets status to gst_missing', () async {
      final repo = ProfileRepository(storage: storage, localOnlyForTesting: true);
      final initialResult = await repo.getProfile();
      final initialProfile = (initialResult as ProfileSuccess<BrokerProfile>).data;

      // Save profile with empty GSTIN
      final clearedGst = initialProfile.copyWith(gstin: '');
      final res = await repo.updateProfile(clearedGst);
      expect(res, isA<ProfileSuccess<BrokerProfile>>());
      final saved = (res as ProfileSuccess<BrokerProfile>).data;

      expect(saved.gstVerificationStatus, BrokerGstStatus.gstMissing);
      expect(saved.gstVerifiedAt, isNull);
    });
  });

  group('RMBROKER-PROFILE-EDIT-FIX-01: Dashboard Navigation & Entry Points', () {
    testWidgets('BrokerWelcomeBanner renders greeting card and edit profile button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const broker = BrokerUser(
        id: 'broker-test-202',
        role: 'broker',
        fullName: 'Mukesh Mandi Broker',
        email: 'mukesh@brokerbridge.in',
      );

      final repo = ProfileRepository(storage: storage, localOnlyForTesting: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: BrokerWelcomeBanner(broker: broker),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Home greeting card exists
      expect(find.byKey(const ValueKey('home_greeting_card')), findsOneWidget);
      expect(find.text('Mukesh Sharma'), findsOneWidget);

      // Dedicated edit profile icon button exists
      expect(
        find.byKey(const ValueKey('dashboard_edit_profile_button')),
        findsOneWidget,
      );
    });

    testWidgets('DashboardHeader renders BB logo and actions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const broker = BrokerUser(
        id: 'broker-test-202',
        role: 'broker',
        fullName: 'Mukesh Sharma',
        email: 'mukesh@brokerbridge.in',
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              appBar: DashboardHeader(broker: broker),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('BB'), findsOneWidget);
      expect(find.text('RMBroker'), findsOneWidget);
      expect(find.text('COMMODITY DESK'), findsOneWidget);
    });
  });

  group('RMBROKER-PROFILE-EDIT-FIX-01: BrokerProfileScreen Form & UI Sections', () {
    testWidgets('Renders all 5 sections and supports edit mode flow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = ProfileRepository(storage: storage, localOnlyForTesting: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: BrokerProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Section titles
      expect(find.text('Broker Profile'), findsOneWidget);
      expect(find.text('Contact Information'), findsOneWidget);
      expect(find.text('Business Details'), findsOneWidget);
      expect(find.text('GST Registration'), findsOneWidget);
      expect(find.text('Address & Locations'), findsOneWidget);

      // Edit action exists in appbar
      expect(find.byTooltip('Edit Profile'), findsOneWidget);

      // Tap Edit Profile
      await tester.tap(find.byTooltip('Edit Profile'));
      await tester.pumpAndSettle();

      // In edit mode: Title changes to Edit Profile and Save button appears
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Tap Back to cancel edit
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Restores view mode title
      expect(find.text('Broker Profile'), findsOneWidget);
    });
  });
}

