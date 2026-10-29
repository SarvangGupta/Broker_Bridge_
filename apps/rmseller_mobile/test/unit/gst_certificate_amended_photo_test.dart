import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/profile/data/gst_certificate_parser.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';

/// RB-SELLER-GST-CERTIFICATE-PARSER-FIX-01.
/// Verbatim ML Kit output captured on the Redmi Note 5 Pro (2026-10-28) for the supplied phone
/// photo of an amended Form GST REG-06 (/sdcard/Download/GST.jpg). Features that broke the
/// parser: "|" table borders glued to values, the emblem motto read as Devanagari noise between
/// the names and the constitution, an extra "Additional trade names" row, "S" for "5" in the
/// GSTIN, and a garbled digital-signature timestamp.
const realAmendedPhotoOcr = '''
৪
।
7.
Name
2.
३
4
6.
5.
Registration Number :08ADRPK6S97J1ZL
Signature
Legal Name
Trade Name, if any
Additional trade names, if any
Designation
Constitution of Business
|Address of Principal Place of
Business
Date ofLiability
Date ofValidity
Type of Registration
Particulars of Approving Authority
Jurisdictional Office
9. Date of issue of Certificate
Registration Certificate
Goveri॥eut ॥fIlia
Form GST REG-06
/See Rule 10(1))
|HARI SHANKAR KHANDELWAL
Shiv Shanker Paslhu Aahar Udyog
ाथगेय जग)
|Proprietorship
|A-6, KABAR MARG,, BANI PARK, Jaipur, Rajasthan, 302006
|01/07/2017
From
Regular
Signature
Superintendent
Jo/O7/2017
३Not Verified
FNENOe:16:33
৮ale: 2022.06.jd
Ram Niwas Sirowa
|16/06/2022
চesgServices Tax Act, 2017
|Circle-H, Jaipur I, AC/ CTO Ward
To
ব্
(Amended)
Not Applicable
Note: The registration certificate is required to be proninently displayedl at all places of Business/Office(s) in the State.
is is a system generatcd digilally signed Registration Certiicate issue base on (he approval of a]Pplication gauted o 1606/2022 ৮y
jurisdictional authority.
''';

void main() {
  final d = const InvoiceOcrService(nativeEngineAvailable: false).extractGstCertificateFromText(realAmendedPhotoOcr);

  test('1. Legal Name', () => expect(d.legalName, 'HARI SHANKAR KHANDELWAL'));

  test('2. Trade Name — taken from the trade-name row, as OCR read it', () {
    // The camera image prints "Pashu"; ML Kit read "Paslhu". The parser keeps OCR output as-is
    // (no dictionary "corrections"); the seller fixes it in the editable Business Name field.
    expect(d.tradeName, 'Shiv Shanker Paslhu Aahar Udyog');
    expect(d.suggestedBusinessName, d.tradeName);
  });

  test('9. Legal Name and Trade Name not swapped; empty "Additional trade names" row ignored', () {
    expect(d.legalName, isNot(contains('Shiv')));
    expect(d.tradeName, isNot(contains('KHANDELWAL')));
    expect(d.tradeName, isNot(contains('Additional')));
  });

  test('3. Certificate issue date', () => expect(d.issueDate, '16/06/2022'));

  test('6–8. issue date is not the liability/validity date nor the signature timestamp', () {
    expect(d.issueDate, isNot('01/07/2017'));
    expect(d.issueDate, isNot(contains('2022.06')));
    expect(d.issueDate, isNot(contains('16:33')));
  });

  test('4. GSTIN 08ADRPK6597J1ZL (OCR "S" repaired via check character, flagged)', () {
    expect(d.gstin, '08ADRPK6597J1ZL');
    expect(GstCertificateParser.isValidGstin('08ADRPK6597J1ZL'), isTrue);
    expect(d.gstinCorrected, isTrue);
    expect(d.reviewNotes.join(' '), contains('08ADRPK6S97J1ZL'));
  });

  test('5. Principal place of business, PIN, State, District', () {
    expect(d.principalAddress, 'A-6, KABAR MARG, BANI PARK, Jaipur, Rajasthan, 302006');
    expect(d.pinCode, '302006');
    expect(d.state, 'Rajasthan');
    expect(d.district, 'Jaipur');
  });

  test('Constitution and Jurisdictional Office', () {
    expect(d.constitution, 'Proprietorship');
    expect(d.jurisdictionalOffice, 'Circle-H, Jaipur I, AC / CTO Ward');
  });

  test('approving authority never becomes the seller', () {
    expect(d.legalName, isNot(contains('Ram Niwas')));
    expect(d.tradeName, isNot(contains('Ram Niwas')));
  });

  test('10. unreadable fields stay empty and reviewable — never filled with unrelated text', () {
    // Remove the names and the issue-date value: they must come back null, not borrowed from elsewhere.
    final damaged = realAmendedPhotoOcr
        .replaceFirst('|HARI SHANKAR KHANDELWAL\n', '')
        .replaceFirst('Shiv Shanker Paslhu Aahar Udyog\n', '')
        .replaceFirst('|16/06/2022\n', '');
    final x = const InvoiceOcrService(nativeEngineAvailable: false).extractGstCertificateFromText(damaged);
    expect(x.legalName, isNull);
    expect(x.tradeName, isNull);
    expect(x.issueDate, isNull);
    expect(x.reviewNotes.join(' '), contains('issue date'));
    expect(x.gstin, '08ADRPK6597J1ZL');
  });
}
