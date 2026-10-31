import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/profile/domain/broker_profile.dart';

void main() {
  group('BrokerProfile Smart ID & GST Source of Truth', () {
    final now = DateTime.now();

    test('displayBrokerId derives a stable 6-character identifier deterministically', () {
      final profile1 = BrokerProfile(
        id: 'b354958e-779a-41f2-b7a3-5899eca32e32',
        role: 'BROKER',
        fullName: 'Varun',
        mobile: '+91 98765 00000',
        email: 'varun@gmail.com',
        updatedAt: now,
      );

      final profile2 = BrokerProfile(
        id: 'b354958e-779a-41f2-b7a3-5899eca32e32',
        role: 'BROKER',
        fullName: 'Varun',
        mobile: '+91 98765 00000',
        email: 'varun@gmail.com',
        updatedAt: now,
      );

      // Verify stability across instances
      expect(profile1.displayBrokerId, startsWith('BRK-'));
      expect(profile1.displayBrokerId.length, equals(10));
      expect(profile1.displayBrokerId, equals(profile2.displayBrokerId));
    });

    test('One source of truth優先 GST extracted details over manual entries', () {
      final profile = BrokerProfile(
        id: 'user-1',
        role: 'BROKER',
        fullName: 'Varun',
        mobile: '+91 98765 00000',
        email: 'varun@gmail.com',
        brokerageName: 'Manual Name',
        tradeName: 'Varun Agro Trading',
        legalName: 'HARI SHANKAR KHANDELWAL',
        businessType: 'Old Type',
        constitution: 'Proprietorship',
        businessAddress: 'Old Address',
        principalPlaceOfBusiness: 'Shiv Shanker Pashu Aahar Udyog, Bani Park',
        updatedAt: now,
      );

      expect(profile.effectiveTradeName, equals('Varun Agro Trading'));
      expect(profile.effectiveLegalName, equals('HARI SHANKAR KHANDELWAL'));
      expect(profile.effectiveConstitution, equals('Proprietorship'));
      expect(profile.effectiveAddress, equals('Shiv Shanker Pashu Aahar Udyog, Bani Park'));
    });

    test('Fallback correctly applies when GST fields are absent', () {
      final profile = BrokerProfile(
        id: 'user-2',
        role: 'BROKER',
        fullName: 'Aman',
        mobile: '+91 98765 43210',
        email: 'aman@mandi.in',
        brokerageName: 'Aman Trading Co',
        legalName: '',
        tradeName: '',
        constitution: '',
        businessType: 'Partnership',
        updatedAt: now,
      );

      expect(profile.effectiveTradeName, equals('Aman Trading Co'));
      expect(profile.effectiveLegalName, equals('Aman Trading Co'));
      expect(profile.effectiveConstitution, equals('Partnership'));
    });

    test('Validation enforces clean phone, email, and GSTIN formatting', () {
      final validProfile = BrokerProfile(
        id: 'user-3',
        role: 'BROKER',
        fullName: 'Varun',
        mobile: '+91 98765 00000',
        email: 'varun@gmail.com',
        brokerageName: 'Varun Agro Trading',
        gstin: '08ADRPK6597J1ZL',
        updatedAt: now,
      );
      expect(validProfile.validate(), isNull);

      final invalidGst = validProfile.copyWith(gstin: 'INVALID_GST');
      expect(invalidGst.validate(), contains('15-character standard format'));
    });
  });
}
