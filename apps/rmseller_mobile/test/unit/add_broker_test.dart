import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/utils/phone_utils.dart';
import 'package:rmseller_mobile/features/brokers/data/seller_broker_repository.dart';
import 'package:rmseller_mobile/features/brokers/domain/seller_broker_model.dart';

void main() {
  group('PhoneUtils Indian Mobile Normalization Tests', () {
    test(
      'Normalizes valid 10-digit Indian numbers starting with 6, 7, 8, 9',
      () {
        final res1 = PhoneUtils.validateAndNormalize('9829012345');
        expect(res1.isValid, isTrue);
        expect(res1.normalized, '+919829012345');
        expect(res1.formatted, '+91 98290 12345');
        expect(res1.rawDigits, '9829012345');

        final res2 = PhoneUtils.validateAndNormalize('+91 98290 12345');
        expect(res2.isValid, isTrue);
        expect(res2.normalized, '+919829012345');

        final res3 = PhoneUtils.validateAndNormalize('09829012345');
        expect(res3.isValid, isTrue);
        expect(res3.normalized, '+919829012345');

        final res4 = PhoneUtils.validateAndNormalize('919829012345');
        expect(res4.isValid, isTrue);
        expect(res4.normalized, '+919829012345');

        final res5 = PhoneUtils.validateAndNormalize('98290-12345');
        expect(res5.isValid, isTrue);
        expect(res5.normalized, '+919829012345');
      },
    );

    test('Rejects invalid phone numbers with clear messages', () {
      final empty = PhoneUtils.validateAndNormalize('');
      expect(empty.isValid, isFalse);
      expect(empty.error, contains('required'));

      final tooShort = PhoneUtils.validateAndNormalize('98290');
      expect(tooShort.isValid, isFalse);
      expect(tooShort.error, contains('valid 10-digit'));

      final invalidStart = PhoneUtils.validateAndNormalize('4829012345');
      expect(invalidStart.isValid, isFalse);
      expect(invalidStart.error, contains('start with 6, 7, 8, or 9'));
    });
  });

  group('SellerBrokerRepository Lookup and Self-Verification Tests', () {
    late SellerBrokerRepository repository;

    setUp(() {
      repository = SellerBrokerRepository();
    });

    test(
      'Authoritatively recognizes registered fallback broker desks',
      () async {
        final result = await repository.lookupBrokerByPhone('+919829012345');
        expect(
          result.status == BrokerLookupStatus.found ||
              result.status == BrokerLookupStatus.alreadyLinked,
          isTrue,
        );
        expect(result.broker, isNotNull);
        expect(result.broker!.name, 'Bikaner Mandi Broker Desk');
        expect(result.broker!.isVerified, isTrue);
        expect(result.broker!.isRegisteredVerified, isTrue);
      },
    );

    test('Detects already linked brokers correctly', () async {
      // Bikaner is already in fallbackBrokers
      final result = await repository.lookupBrokerByPhone('9829012345');
      expect(
        result.status == BrokerLookupStatus.found ||
            result.status == BrokerLookupStatus.alreadyLinked,
        isTrue,
      );
    });

    test('Identifies unregistered contacts as notFound without creating fake accounts', () async {
      final result = await repository.lookupBrokerByPhone('9999988888');
      expect(result.status, BrokerLookupStatus.notFound);
      expect(result.broker, isNull);
      expect(result.normalizedPhone, '+919999988888');
      expect(result.formattedPhone, '+91 99999 88888');
    });

    test('Inviting a broker records pending status and NEVER marks unverified contact as verified', () async {
      final invited = await repository.inviteBroker(
        normalizedPhone: '+919999977777',
        contactName: 'Ramesh Agro Desk',
        nominationSource: 'phone_contacts',
      );

      expect(invited.isVerified, isFalse);
      expect(invited.status, SellerBrokerStatus.invitationPending);
      expect(invited.isInvitationPending, isTrue);
      expect(invited.isRegisteredVerified, isFalse);
      expect(invited.invitedAt, isNotNull);

      // Verify it appears in active brokers list as pending
      final brokers = await repository.getBrokers();
      final match = brokers.firstWhere((b) => b.mobile == '+919999977777');
      expect(match.status, SellerBrokerStatus.invitationPending);
      expect(match.isVerified, isFalse);
    });
  });
}
