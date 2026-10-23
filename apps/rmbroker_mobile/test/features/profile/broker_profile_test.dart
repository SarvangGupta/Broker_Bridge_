import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
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
      id: 'broker-test-101',
      role: 'broker',
      email: 'nilesh@brokerbridge.in',
      fullName: 'Nilesh Commodity Broker',
    );
  });

  group('Feature A: Broker Profile Domain & Validation Tests', () {
    test('Valid profile passes validation without errors', () {
      final profile = BrokerProfile(
        id: 'broker-test-101',
        role: 'BROKER',
        fullName: 'Nilesh Sharma',
        mobile: '9829012345',
        email: 'nilesh@brokerbridge.in',
        brokerageName: 'Sharma Commodity Mandi Desk',
        businessAddress: 'Shop 24, Mandi Yard, Jaipur',
        updatedAt: DateTime.now(),
      );

      expect(profile.validate(), isNull);
    });

    test('Rejects empty or short full name', () {
      final emptyName = BrokerProfile(
        id: 'broker-test-101',
        role: 'BROKER',
        fullName: '  ',
        mobile: '9829012345',
        email: 'nilesh@brokerbridge.in',
        updatedAt: DateTime.now(),
      );
      expect(emptyName.validate(), contains('Full name cannot be empty'));

      final shortName = emptyName.copyWith(fullName: 'N');
      expect(shortName.validate(), contains('at least 2 characters'));
    });

    test('Rejects invalid mobile number', () {
      final shortMobile = BrokerProfile(
        id: 'broker-test-101',
        role: 'BROKER',
        fullName: 'Nilesh Sharma',
        mobile: '12345',
        email: 'nilesh@brokerbridge.in',
        updatedAt: DateTime.now(),
      );
      expect(shortMobile.validate(), contains('at least 10 digits'));
    });

    test('Rejects invalid email format', () {
      final badEmail = BrokerProfile(
        id: 'broker-test-101',
        role: 'BROKER',
        fullName: 'Nilesh Sharma',
        mobile: '9829012345',
        email: 'invalid-email-address',
        updatedAt: DateTime.now(),
      );
      expect(badEmail.validate(), contains('valid email address'));
    });

    test('Protected fields remain immutable across copyWith and updates', () {
      final original = BrokerProfile(
        id: 'protected-id-99',
        role: 'ADMIN',
        accountStatus: 'Active',
        isVerified: true,
        trustScore: 98,
        fullName: 'Nilesh Original',
        mobile: '9829012345',
        email: 'nilesh@brokerbridge.in',
        updatedAt: DateTime.now(),
      );

      final updated = original.copyWith(
        fullName: 'Nilesh Modified',
        mobile: '9829099999',
      );

      expect(updated.id, 'protected-id-99');
      expect(updated.role, 'ADMIN');
      expect(updated.accountStatus, 'Active');
      expect(updated.isVerified, isTrue);
      expect(updated.trustScore, 98);
      expect(updated.fullName, 'Nilesh Modified');
      expect(updated.mobile, '9829099999');
    });
  });

  group('Feature A: Profile Repository & Persistence Tests', () {
    test('Loads baseline profile and saves updates', () async {
      final repo = ProfileRepository(storage: storage);
      final result = await repo.getProfile();

      expect(result, isA<ProfileSuccess<BrokerProfile>>());
      final profile = (result as ProfileSuccess<BrokerProfile>).data;
      expect(profile.id, 'broker-test-101');
      expect(profile.fullName, 'Nilesh Commodity Broker');

      // Update details
      final updatedProfile = profile.copyWith(
        fullName: 'Nilesh Sharma (Chief Broker)',
        brokerageName: 'Nilesh Trading Corporation',
        businessAddress: 'Jaipur Grain Terminal Yard 4',
      );

      final updateResult = await repo.updateProfile(updatedProfile);
      expect(updateResult, isA<ProfileSuccess<BrokerProfile>>());

      // Re-read from repository to verify persistence across restarts
      final reloadResult = await repo.getProfile();
      expect(reloadResult, isA<ProfileSuccess<BrokerProfile>>());
      final reloaded = (reloadResult as ProfileSuccess<BrokerProfile>).data;
      expect(reloaded.fullName, 'Nilesh Sharma (Chief Broker)');
      expect(reloaded.brokerageName, 'Nilesh Trading Corporation');
      expect(reloaded.businessAddress, 'Jaipur Grain Terminal Yard 4');
    });
  });

  group('Feature A: BrokerProfileScreen Widget Tests', () {
    testWidgets('Renders broker profile, read-only identifiers, and edit mode toggle',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const BrokerProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Header and badges
      expect(find.text('Broker Profile'), findsOneWidget);
      expect(find.text('Protected Desk Identifiers'), findsOneWidget);
      expect(find.text('Account ID'), findsOneWidget);
      expect(find.text('Desk Role'), findsOneWidget);
      expect(find.text('Mandi Verification'), findsOneWidget);

      // Check Edit button
      expect(find.text('Edit Profile Information'), findsOneWidget);

      // Tap Edit Profile Information
      await tester.tap(find.text('Edit Profile Information'));
      await tester.pumpAndSettle();

      // In edit mode, Save Profile and Cancel buttons appear
      expect(find.text('Save Profile'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel to exit edit mode
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Profile Information'), findsOneWidget);
    });
  });
}
