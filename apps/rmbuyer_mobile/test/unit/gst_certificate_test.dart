import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/profile/data/gst_certificate_parser.dart';
import 'package:rmbuyer_mobile/features/profile/domain/gst_certificate_data.dart';

/// Synthetic GSTIN (fictitious PAN) with a correct check character.
String validGstin([String first14 = '08ABCDE1234F1Z']) =>
    first14 + GstinRules.checkCharacter(first14);

/// Synthetic Form GST REG-06 text in the layout ML Kit returns for a clean photo.
String certificateText(String gstin) =>
    '''
Government of India
Form GST REG-06
Registration Certificate
Registration Number : $gstin
1. Legal Name MAHESH KUMAR SHARMA
2. Trade Name, if any SHARMA FEED TRADERS
3. Constitution of Business Proprietorship
4. Address of Principal Place of Business Plot 12, Mandi Road, Bikaner, Rajasthan, 334001
5. Date of Liability 01/07/2017
6. Period of Validity From 01/07/2017 To Not Applicable
7. Type of Registration Regular
''';

void main() {
  group('GstinRules', () {
    test('accepts a correct check character and rejects a wrong one', () {
      final g = validGstin();
      expect(GstinRules.isValid(g), isTrue);
      final wrong = g.substring(0, 14) + (g[14] == 'A' ? 'B' : 'A');
      expect(GstinRules.hasValidFormat(wrong), isTrue);
      expect(GstinRules.isValid(wrong), isFalse);
    });

    test('rejects malformed and empty input', () {
      for (final bad in [
        '',
        '08ABCDE1234F1Z',
        '8ABCDE1234F1Z5X',
        '08abcde1234f1z5',
        '08ABCDE1234F0Z5',
      ]) {
        expect(GstinRules.isValid(bad), isFalse, reason: bad);
      }
      expect(GstinRules.normalize(' 08abcde 1234f1z5 '), '08ABCDE1234F1Z5');
    });

    test('derives PAN and state from the GSTIN', () {
      final g = validGstin();
      expect(GstinRules.panOf(g), 'ABCDE1234F');
      expect(GstinRules.stateOf(g), 'Rajasthan');
      expect(GstinRules.panOf('nonsense'), isNull);
      expect(GstinRules.stateOf('99XXXXX'), isNull);
    });
  });

  group('GstSubmissionValidation', () {
    Map<GstField, String> values({String? gstin, String pin = '334001'}) => {
      GstField.gstin: gstin ?? validGstin(),
      GstField.legalName: 'MAHESH KUMAR SHARMA',
      GstField.address: 'Plot 12, Mandi Road, Bikaner',
      GstField.pinCode: pin,
    };

    test('passes a complete, valid form', () {
      expect(GstSubmissionValidation.validate(values()), isEmpty);
    });

    test('reports required, format, checksum and PIN errors', () {
      expect(GstSubmissionValidation.validate({}), {
        GstField.gstin: GstFieldError.required,
        GstField.legalName: GstFieldError.required,
        GstField.address: GstFieldError.required,
        GstField.pinCode: GstFieldError.required,
      });
      expect(
        GstSubmissionValidation.validate(
          values(gstin: '08ABCDE1234'),
        )[GstField.gstin],
        GstFieldError.invalidFormat,
      );
      final g = validGstin();
      final wrong = g.substring(0, 14) + (g[14] == 'A' ? 'B' : 'A');
      expect(
        GstSubmissionValidation.validate(values(gstin: wrong))[GstField.gstin],
        GstFieldError.invalidChecksum,
      );
      expect(
        GstSubmissionValidation.validate(
          values(pin: '03400'),
        )[GstField.pinCode],
        GstFieldError.invalidPin,
      );
    });
  });

  group('GstCertificateParser', () {
    test('extracts every REG-06 field from labelled lines', () {
      final g = validGstin();
      final d = const GstCertificateParser().parse(certificateText(g));
      expect(d.gstin, g);
      expect(d.gstinCorrected, isFalse);
      expect(d.legalName, 'MAHESH KUMAR SHARMA');
      expect(d.tradeName, 'SHARMA FEED TRADERS');
      expect(d.constitution, 'Proprietorship');
      expect(
        d.principalAddress,
        'Plot 12, Mandi Road, Bikaner, Rajasthan, 334001',
      );
      expect(d.pinCode, '334001');
      expect(d.registrationDate, '01/07/2017');
      expect(d.registrationType, 'Regular');
      expect(d.state, 'Rajasthan');
      expect(d.reviewNotes, isEmpty);
    });

    test('repairs an O/0 misread using the check character and flags it', () {
      final g = validGstin();
      final misread = 'O${g.substring(1)}';
      final d = const GstCertificateParser().parse(certificateText(misread));
      expect(d.gstin, g);
      expect(d.gstinCorrected, isTrue);
      expect(d.reviewNotes.single, contains('corrected'));
    });

    test('keeps missing fields null instead of guessing', () {
      final d = const GstCertificateParser().parse(
        'Form GST REG-06\nRegistration Certificate\n',
      );
      expect(d.isEmpty, isTrue);
      expect(d.toFieldMap().values.every((v) => v == null), isTrue);
    });
  });
}
