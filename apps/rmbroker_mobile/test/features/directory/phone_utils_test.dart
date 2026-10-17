import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/directory/utils/phone_utils.dart';

void main() {
  group('PhoneUtils Indian Mobile Normalization Tests (+91 standard)', () {
    test('normalizes standard 10-digit mobile number with +91 prefix and formatted output', () {
      final res = PhoneUtils.validateAndNormalize('9876543210');

      expect(res.isValid, isTrue);
      expect(res.normalized, equals('+919876543210'));
      expect(res.formatted, equals('+91 98765 43210'));
      expect(res.rawDigits, equals('9876543210'));
      expect(res.error, isNull);
    });

    test('sanitizes messy formatted inputs (spaces, hyphens, parentheses, dots, leading 0)', () {
      final p1 = PhoneUtils.validateAndNormalize('098765-43210');
      final p2 = PhoneUtils.validateAndNormalize('+91 98765 43210');
      final p3 = PhoneUtils.validateAndNormalize('919876543210');
      final p4 = PhoneUtils.validateAndNormalize('(987) 654.3210');

      expect(p1.isValid, isTrue);
      expect(p1.normalized, equals('+919876543210'));

      expect(p2.isValid, isTrue);
      expect(p2.normalized, equals('+919876543210'));

      expect(p3.isValid, isTrue);
      expect(p3.normalized, equals('+919876543210'));

      expect(p4.isValid, isTrue);
      expect(p4.normalized, equals('+919876543210'));
    });

    test('rejects numbers not starting with Indian telecom series 6, 7, 8, 9', () {
      final res1 = PhoneUtils.validateAndNormalize('1234567890');
      final res2 = PhoneUtils.validateAndNormalize('5876543210');

      expect(res1.isValid, isFalse);
      expect(res1.error, contains('must start with 6, 7, 8, or 9'));

      expect(res2.isValid, isFalse);
      expect(res2.error, contains('must start with 6, 7, 8, or 9'));
    });

    test('rejects short, long, or empty mobile numbers', () {
      final shortRes = PhoneUtils.validateAndNormalize('98765');
      final longRes = PhoneUtils.validateAndNormalize('987654321000');
      final emptyRes = PhoneUtils.validateAndNormalize('');
      final nullRes = PhoneUtils.validateAndNormalize(null);

      expect(shortRes.isValid, isFalse);
      expect(shortRes.error, contains('valid 10-digit'));

      expect(longRes.isValid, isFalse);
      expect(longRes.error, contains('valid 10-digit'));

      expect(emptyRes.isValid, isFalse);
      expect(emptyRes.error, contains('required'));

      expect(nullRes.isValid, isFalse);
      expect(nullRes.error, contains('required'));
    });

    test('generates safe tel: and WhatsApp URIs', () {
      final tel = PhoneUtils.getSafeTelUri('9876543210');
      final wa = PhoneUtils.getSafeWhatsAppUri('9876543210', initialMessage: 'Mandate inquiry');
      final telInvalid = PhoneUtils.getSafeTelUri('12345');
      final waInvalid = PhoneUtils.getSafeWhatsAppUri('invalid');

      expect(tel, equals('tel:+919876543210'));
      expect(wa, equals('https://wa.me/919876543210?text=Mandate%20inquiry'));
      expect(telInvalid, isNull);
      expect(waInvalid, isNull);
    });
  });
}
