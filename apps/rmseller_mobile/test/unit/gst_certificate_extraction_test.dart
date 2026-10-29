import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/profile/data/gst_certificate_parser.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';
import 'package:rmseller_mobile/features/profile/domain/business_location_model.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_profile_model.dart';

/// RB-SELLER-GST-CERTIFICATE-PROFILE-01.
/// [_realOcr] is the verbatim ML Kit output captured on the Redmi Note 5 Pro for the supplied
/// Form GST REG-06 (labels and values come out as separate columns; GSTIN check char read as "O").
const _realOcr = '''
Registration Number : 08AWIPG6115A1ZO
।
2
3
4
6
7
Legal Name
Irade Name, if any
Constitution of Business
Address of Principal Place of
Business
Date of Liability
Period of Validity
|Type of Registration
Signature
Name
Designation
Jurisdictional Office
|9. Date of issue of Certificate
Governnment of India
Form GST REG-06
(See Rule 10)I
Registration Certificate
समेव जयते
Raghuveer Prasad Goyal
Piyush General Store
Proprietorship
B-391, Shanti Nagar. Gurjer Ki Thadi, Jaipur, Rajasthan, 302019
Particulars of Approving Authority Centre
16/07/2020
From
Regular
Superintendent
Rajendra Singh Shekhawat
16/07/2020 To
23/07/2020
Circle-A, Jaipur- Ward-2
Not Applicable
Note: The registration certificate is required to be prominently displayed at all places of business in the State.
This is a system generated digitally signed Registration Certificate issued based on the approval of application granted on 23/07/2020 by
the sdictional authority.
''';

/// Same certificate in reading order with labels and values on one line (text-layer PDFs).
/// Shared with the widget workflow test.
const realGstOcrForTests = _realOcr;

const _readingOrder = '''
Government of India
Form GST REG-06
Registration Certificate
Registration Number : 08AWIPG6115A1Z0
1. Legal Name Raghuveer Prasad Goyal
2. Trade Name, if any Piyush General Store
3. Constitution of Business Proprietorship
4. Address of Principal Place of Business B-391, Shanti Nagar, Gurjer Ki Thadi, Jaipur, Rajasthan, 302019
5. Date of Liability 16/07/2020
6. Period of Validity From 16/07/2020 To Not Applicable
7. Type of Registration Regular
8. Particulars of Approving Authority Centre
Name Rajendra Singh Shekhawat
Designation Superintendent
Jurisdictional Office Circle-A, Jaipur - Ward-2
9. Date of issue of Certificate 23/07/2020
''';

void main() {
  const service = InvoiceOcrService(nativeEngineAvailable: false);

  for (final entry in {'real on-device OCR': _realOcr, 'reading-order text': _readingOrder}.entries) {
    group('REG-06 reference certificate (${entry.key})', () {
      final d = service.extractGstCertificateFromText(entry.value);

      test('Legal Name', () => expect(d.legalName, 'Raghuveer Prasad Goyal'));
      test('Trade Name → Business Name suggestion', () {
        expect(d.tradeName, 'Piyush General Store');
        expect(d.suggestedBusinessName, 'Piyush General Store');
      });
      test('Registration Number → GSTIN (checksum-verified)', () {
        expect(d.gstin, '08AWIPG6115A1Z0');
        expect(GstCertificateParser.isValidGstin(d.gstin!), isTrue);
      });
      test('Principal Place of Business → HQ address, complete', () {
        expect(d.principalAddress, 'B-391, Shanti Nagar, Gurjer Ki Thadi, Jaipur, Rajasthan, 302019');
      });
      test('PIN → State/District via India Post directory', () {
        expect(d.pinCode, '302019');
        expect(d.state, 'Rajasthan');
        expect(d.district, 'Jaipur');
      });
      test('Jurisdictional Office separate from the address', () {
        expect(d.jurisdictionalOffice, 'Circle-A, Jaipur - Ward-2');
        expect(d.principalAddress, isNot(contains('Circle')));
      });
      test('Issue date is 23/07/2020, never the Date of Liability 16/07/2020', () {
        expect(d.issueDate, '23/07/2020');
        expect(d.issueDate, isNot('16/07/2020'));
      });
      test('approving authority never becomes the seller name', () {
        expect(d.legalName, isNot(contains('Rajendra')));
        expect(d.tradeName, isNot(contains('Rajendra')));
        expect(d.legalName, isNot('Superintendent'));
      });
    });
  }

  test('real OCR: GSTIN "O" repair and inferred issue date are flagged for review', () {
    final d = service.extractGstCertificateFromText(_realOcr);
    expect(d.gstinCorrected, isTrue);
    expect(d.issueDateInferred, isTrue);
    expect(d.reviewNotes.join(' '), allOf(contains('08AWIPG6115A1ZO'), contains('23/07/2020')));
  });

  group('GSTIN check character', () {
    test('valid GSTINs pass, a changed character fails', () {
      expect(GstCertificateParser.isValidGstin('08AWIPG6115A1Z0'), isTrue);
      expect(GstCertificateParser.isValidGstin('08AWIPG6115A1Z1'), isFalse);
      expect(GstCertificateParser.isValidGstin('08AWIPG6115A1ZO'), isFalse);
    });
    test('repair only returns a single checksum-valid variant', () {
      expect(GstCertificateParser.repairGstin('08AWIPG6115A1ZO'), '08AWIPG6115A1Z0');
      expect(GstCertificateParser.repairGstin('O8AWIPG6115A1Z0'), '08AWIPG6115A1Z0');
      expect(GstCertificateParser.repairGstin('08AWIPG6115A1Z7'), isNull);
    });
  });

  test('no Trade Name → Business Name suggestion falls back to Legal Name', () {
    final d = service.extractGstCertificateFromText(
        _readingOrder.replaceFirst('2. Trade Name, if any Piyush General Store', '2. Trade Name, if any NA'));
    expect(d.tradeName, isNull);
    expect(d.suggestedBusinessName, 'Raghuveer Prasad Goyal');
  });

  test('only one date present → issue date left empty and flagged, liability not reused', () {
    final d = service.extractGstCertificateFromText(_realOcr.replaceAll('23/07/2020', '').replaceAll('granted on  by', ''));
    expect(d.issueDate, isNull);
    expect(d.reviewNotes.join(' '), contains('could not be told apart'));
  });

  test('a non-certificate document yields nothing', () {
    expect(service.extractGstCertificateFromText('BILL OF SUPPLY\nmisc text').isEmpty, isTrue);
  });

  group('applyToProfile', () {
    const current = SellerProfileModel(
      id: 's', fullName: 'Old Name', email: 'login@seller.in', role: 'seller', mobile: '9000000000',
      companyName: 'Old Co', companyGst: '', officeAddress: 'Old HQ',
      businessLocation: BusinessLocationModel(name: 'Godown', addressLine: 'Old street', pinCode: '334001'),
    );
    final d = service.extractGstCertificateFromText(_realOcr);

    test('maps the six fields; godown untouched without confirmation; email/mobile preserved', () {
      final m = d.applyToProfile(current);
      expect(m.fullName, 'Raghuveer Prasad Goyal');
      expect(m.companyName, 'Piyush General Store');
      expect(m.companyGst, '08AWIPG6115A1Z0');
      expect(m.officeAddress, 'B-391, Shanti Nagar, Gurjer Ki Thadi, Jaipur, Rajasthan, 302019');
      expect(m.jurisdictionalOffice, 'Circle-A, Jaipur - Ward-2');
      expect(m.gstCertificateIssueDate, '23/07/2020');
      expect(m.businessLocation.addressLine, 'Old street');
      expect(m.businessLocation.pinCode, '334001');
      expect(m.email, 'login@seller.in');
      expect(m.mobile, '9000000000');
    });

    test('godown filled only when seller confirms principal place = shop/godown', () {
      final m = d.applyToProfile(current, addressIsGodown: true);
      expect(m.businessLocation.addressLine, m.officeAddress);
      expect(m.businessLocation.pinCode, '302019');
      expect(m.businessLocation.districtName, 'Jaipur');
      expect(m.businessLocation.name, 'Godown');
    });

    test('hidden fields survive save (toMap) and reopen (fromMap)', () {
      final reopened = SellerProfileModel.fromMap(d.applyToProfile(current).toMap());
      expect(reopened.jurisdictionalOffice, 'Circle-A, Jaipur - Ward-2');
      expect(reopened.gstCertificateIssueDate, '23/07/2020');
    });
  });
}
