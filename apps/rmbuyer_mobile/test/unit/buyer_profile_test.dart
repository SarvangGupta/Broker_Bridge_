import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/profile/data/buyer_profile_repository.dart';
import 'package:rmbuyer_mobile/features/profile/domain/buyer_profile.dart';

void main() {
  group('BuyerProfileValidation', () {
    test('name must be 2–80 characters after trimming', () {
      expect(BuyerProfileValidation.validateName('  '), NameError.required);
      expect(BuyerProfileValidation.validateName('A'), NameError.length);
      expect(BuyerProfileValidation.validateName('A' * 81), NameError.length);
      expect(BuyerProfileValidation.validateName(' Rajesh '), isNull);
    });

    test(
      'Indian mobile numbers normalise to +91XXXXXXXXXX; others are rejected',
      () {
        for (final ok in [
          '9876543210',
          '+91 98765 43210',
          '91-9876543210',
          '09876543210',
        ]) {
          expect(
            BuyerProfileValidation.normalizeMobile(ok),
            '+919876543210',
            reason: ok,
          );
        }
        for (final bad in [
          '12345',
          '5876543210',
          '98765432101',
          'abcdefghij',
          '+1 9876543210',
        ]) {
          expect(
            BuyerProfileValidation.normalizeMobile(bad),
            isNull,
            reason: bad,
          );
        }
      },
    );
  });

  group('BuyerProfileRepository contract', () {
    test('only name and mobile can ever be written', () {
      final filtered = BuyerProfileRepository.editableChanges({
        'name': 'New Name',
        'mobile': '+919876543210',
        'email': 'attacker@example.com',
        'role': 'admin',
        'status': true,
        'company_id': 'other-company',
        'gst': 'X',
        'is_verified': true,
      });
      expect(filtered, {'name': 'New Name', 'mobile': '+919876543210'});
    });

    test('rows map to the profile without inventing values', () {
      final p = BuyerProfileRepository.profileFromRows(
        {
          'id': 'u1',
          'name': 'Asha',
          'email': null,
          'mobile': '',
          'role': 'Buyer',
          'company_id': 'c1',
        },
        {'name': 'Kota Mills', 'gst': null, 'is_verified': true},
        authEmail: 'asha@example.com',
      );
      expect(p.name, 'Asha');
      expect(p.mobile, isNull);
      expect(p.email, 'asha@example.com');
      expect(p.role, 'buyer');
      expect(p.companyName, 'Kota Mills');
      expect(p.companyGst, isNull);
      expect(p.companyVerified, isTrue);

      final noCompany = BuyerProfileRepository.profileFromRows({
        'id': 'u2',
        'name': 'B',
        'role': 'buyer',
      }, null);
      expect(noCompany.companyName, isNull);
      expect(noCompany.companyVerified, isNull);
    });
  });
}
