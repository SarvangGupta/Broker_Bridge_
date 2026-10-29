import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/profile/data/gst_certificate_parser.dart';
import 'package:rmbuyer_mobile/features/profile/domain/gst_certificate_data.dart';

/// RMBUYER-GST-E2E-VALIDATION-01 reference fixture: the owner-supplied amended
/// Form GST REG-06. This is the verbatim on-device ML Kit output captured for
/// that certificate photo (shared with RMSeller's
/// gst_certificate_amended_photo_test.dart). The image itself is not stored.
const referenceOcr = '''
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

/// The same certificate as a clean, label-on-the-same-line reading (what a
/// sharp, straight scan yields), to show the parser's ceiling.
const cleanReferenceOcr = '''
Form GST REG-06
Registration Certificate
Registration Number :08ADRPK6597J1ZL
1. Legal Name HARI SHANKAR KHANDELWAL
2. Trade Name, if any Shiv Shanker Pashu Aahar Udyog
3. Additional trade names, if any
4. Constitution of Business Proprietorship
5. Address of Principal Place of Business A-6, KABAR MARG,, BANI PARK, Jaipur, Rajasthan, 302006
6. Date of Liability 01/07/2017
7. Date of Validity From 01/07/2017 To Not Applicable
8. Type of Registration Regular
9. Date of issue of Certificate 16/06/2022
''';

const _gstin = '08ADRPK6597J1ZL';
const _address = 'A-6, KABAR MARG, BANI PARK, Jaipur, Rajasthan, 302006';

GstCertificateData _parse(String text) =>
    const GstCertificateParser().parse(text);

void main() {
  test('the reference GSTIN passes the existing format and checksum rules', () {
    expect(GstinRules.isValid(_gstin), isTrue);
    expect(GstinRules.panOf(_gstin), 'ADRPK6597J');
    expect(GstinRules.stateOf(_gstin), 'Rajasthan');
    expect(_gstin.substring(0, 2), '08');
  });

  group('real phone capture of the reference certificate', () {
    final d = _parse(referenceOcr);

    test('GSTIN: OCR "6S97" repaired via the check character and flagged', () {
      expect(d.gstin, _gstin);
      expect(d.gstinCorrected, isTrue);
      expect(d.reviewNotes.join(' '), contains('08ADRPK6S97J1ZL'));
    });

    test(
      'names are not swapped; empty additional-trade-names row is ignored',
      () {
        expect(d.legalName, 'HARI SHANKAR KHANDELWAL');
        expect(d.tradeName, isNot(contains('Additional')));
      },
    );

    test(
      'trade name: OCR "Paslhu" corrected to "Pashu" and flagged for review',
      () {
        expect(d.tradeName, 'Shiv Shanker Pashu Aahar Udyog');
        expect(d.correctedFields, {GstField.tradeName});
        expect(
          d.reviewNotes.join(' '),
          contains('read as "Shiv Shanker Paslhu Aahar Udyog"'),
        );
      },
    );

    test('constitution, address, PIN and state', () {
      expect(d.constitution, 'Proprietorship');
      expect(d.principalAddress, _address);
      expect(d.pinCode, '302006');
      expect(d.state, 'Rajasthan');
    });

    test('liability date, registration type and issue date', () {
      expect(d.registrationDate, '01/07/2017');
      expect(d.registrationType, 'Regular');
      expect(d.issueDate, '16/06/2022');
      expect(d.reviewNotes.join(' '), contains('issue date'));
    });

    test('validity: unreadable start cell left empty and flagged, end is Not Applicable', () {
      // This photo's "From" value cell was read as "Jo/O7/2017": "J" is not a
      // known digit confusable, so the date is not guessed or borrowed.
      expect(d.validityFrom, isNull);
      expect(
        d.reviewNotes.join(' '),
        contains('could not be read (OCR read "Jo/O7/2017")'),
      );
      expect(d.validityTo, 'Not Applicable');
      expect(d.issueDate, isNot(d.validityFrom));
    });

    test('approving authority and timestamp never leak into buyer fields', () {
      final all = d.toFieldMap().values.nonNulls.join(' ');
      expect(all, isNot(contains('Ram Niwas')));
      expect(all, isNot(contains('16:33')));
      expect(all, isNot(contains('2022.06')));
    });

    test('reviewed values pass client validation', () {
      final values = {
        for (final e in d.toFieldMap().entries) e.key: e.value ?? '',
      };
      expect(GstSubmissionValidation.validate(values), isEmpty);
    });
  });

  test('clean reading of the reference certificate yields every field', () {
    final d = _parse(cleanReferenceOcr);
    expect(d.gstin, _gstin);
    expect(d.gstinCorrected, isFalse);
    expect(d.legalName, 'HARI SHANKAR KHANDELWAL');
    expect(d.tradeName, 'Shiv Shanker Pashu Aahar Udyog');
    expect(d.constitution, 'Proprietorship');
    expect(d.principalAddress, _address);
    expect(d.pinCode, '302006');
    expect(d.state, 'Rajasthan');
    expect(d.registrationDate, '01/07/2017');
    expect(d.validityFrom, '01/07/2017');
    expect(d.validityTo, 'Not Applicable');
    expect(d.registrationType, 'Regular');
    expect(d.issueDate, '16/06/2022');
  });

  group('degraded images (simulated OCR output)', () {
    test('partially obscured: missing name and address rows stay null', () {
      final d = _parse(
        referenceOcr
            .replaceFirst('|HARI SHANKAR KHANDELWAL\n', '')
            .replaceFirst('Shiv Shanker Paslhu Aahar Udyog\n', '')
            .replaceFirst(
              '|A-6, KABAR MARG,, BANI PARK, Jaipur, Rajasthan, 302006\n',
              '',
            ),
      );
      expect(d.legalName, isNull);
      expect(d.tradeName, isNull);
      expect(d.principalAddress, isNull);
      expect(d.pinCode, isNull);
      expect(d.gstin, _gstin);
      expect(d.constitution, 'Proprietorship');
    });

    test('low quality: an unrepairable GSTIN is kept as read and flagged, not changed', () {
      final d = _parse(
        referenceOcr.replaceFirst('08ADRPK6S97J1ZL', '08ADRPK6S97J1ZQ'),
      );
      expect(d.gstin, '08ADRPK6S97J1ZQ');
      expect(d.gstinCorrected, isFalse);
      expect(
        d.reviewNotes.join(' '),
        contains('failed the GSTIN check-character test'),
      );
      // Autocorrection does not touch any other field.
      expect(d.legalName, 'HARI SHANKAR KHANDELWAL');
      expect(d.principalAddress, _address);
    });

    test('skewed: value lines read before labels still map correctly', () {
      final lines = referenceOcr.split('\n');
      final values = lines
          .where((l) => l.startsWith('|') || l == 'Regular')
          .toList();
      final reordered = [
        ...values,
        ...lines.where((l) => !values.contains(l)),
      ].join('\n');
      final d = _parse(reordered);
      expect(d.gstin, _gstin);
      expect(d.legalName, 'HARI SHANKAR KHANDELWAL');
      expect(d.constitution, 'Proprietorship');
      expect(d.principalAddress, _address);
      expect(d.registrationType, 'Regular');
    });

    test('unsupported image (not a certificate) yields no values', () {
      final d = _parse('TAX INVOICE\nBill No 123\nTotal 4500.00\n');
      expect(d.isEmpty, isTrue);
      expect(d.toFieldMap().values.every((v) => v == null), isTrue);
    });
  });

  group('state consistency', () {
    test('an address naming another state is rejected; same state passes', () {
      final base = {
        GstField.gstin: _gstin,
        GstField.legalName: 'HARI SHANKAR KHANDELWAL',
        GstField.address: _address,
        GstField.pinCode: '302006',
      };
      expect(GstSubmissionValidation.validate(base), isEmpty);
      final wrong = {
        ...base,
        GstField.address: 'A-6, Bani Park, Ahmedabad, Gujarat, 380001',
      };
      expect(GstSubmissionValidation.validate(wrong), {
        GstField.address: GstFieldError.stateMismatch,
      });
      // An address that names no state is not guessed at.
      final none = {...base, GstField.address: 'A-6, Bani Park'};
      expect(GstSubmissionValidation.validate(none), isEmpty);
    });
  });

  group('validity dates (RMBUYER-GST-FORM-FIX-02)', () {
    // The reference capture with a legible "From" cell: the value sits in the
    // value column, on its own line, as ML Kit returns it for a sharper photo.
    String withLegibleFrom(String cell) =>
        referenceOcr.replaceFirst('Jo/O7/2017', cell);

    test('valid-from read from the value column returns 01/07/2017', () {
      final d = _parse(withLegibleFrom('01/07/2017'));
      expect(d.validityFrom, '01/07/2017');
      expect(
        d.reviewNotes.join(' '),
        contains('Valid-from date 01/07/2017 was identified from the layout'),
      );
    });

    test(
      'liability, valid from, valid to and issue date stay distinct fields',
      () {
        final d = _parse(withLegibleFrom('01/07/2017'));
        expect(d.registrationDate, '01/07/2017');
        expect(d.validityFrom, '01/07/2017');
        expect(d.validityTo, 'Not Applicable');
        expect(d.issueDate, '16/06/2022');
      },
    );

    test('unambiguous O/I confusables in the date cell are repaired', () {
      expect(_parse(withLegibleFrom('01/O7/2017')).validityFrom, '01/07/2017');
      expect(_parse(withLegibleFrom('Ol/07/2017')).validityFrom, '01/07/2017');
    });

    test('valid-from never comes from the issue date or signature timestamp', () {
      // Only liability + issue date legible: the second date is the issue date.
      final d = _parse(referenceOcr);
      expect(d.validityFrom, isNull);
      expect(d.issueDate, '16/06/2022');
      expect(
        d.toFieldMap().values.nonNulls,
        isNot(contains(startsWith('2022.06'))),
      );
    });

    test('a different valid-from date is kept as read, not overwritten by liability', () {
      final d = _parse(withLegibleFrom('15/08/2019'));
      expect(d.registrationDate, '01/07/2017');
      expect(d.validityFrom, '15/08/2019');
      expect(d.issueDate, '16/06/2022');
    });

    test('labelled "From ... To ..." still wins over layout', () {
      final d = _parse(cleanReferenceOcr);
      expect(d.validityFrom, '01/07/2017');
      expect(d.reviewNotes.join(' '), isNot(contains('Valid-from date')));
    });
  });

  group('trade-name OCR repair is narrow', () {
    String fix(String s) => GstCertificateParser.repairTradeName(s);

    test('one stray interior character in a known word is removed', () {
      expect(
        fix('Shiv Shanker Paslhu Aahar Udyog'),
        'Shiv Shanker Pashu Aahar Udyog',
      );
      expect(
        fix('SHIV SHANKER PASLHU AAHAR UDYOG'),
        'SHIV SHANKER PASHU AAHAR UDYOG',
      );
      expect(fix('Gupta Tradlers'), 'Gupta Traders');
    });

    test('correct, unknown and substituted words are never changed', () {
      for (final s in [
        'Shiv Shanker Pashu Aahar Udyog',
        'Pashupati Feeds', // a different, legitimate word
        'Pashu Aahat Udyog', // substitution, not insertion: left for the buyer
        'Rohan Gupta', // names are not in the vocabulary
        'Shanker Paslu', // not one deletion away from a vocabulary word
        'Feedsx', // the extra character is the last one, not interior
      ]) {
        expect(fix(s), s, reason: s);
      }
    });

    test('no global l→h substitution', () {
      expect(fix('Lalit Mills'), 'Lalit Mills');
      expect(fix('Shiv Dal Mill'), 'Shiv Dal Mill');
    });
  });

  group('identity check against the saved profile', () {
    Set<GstIdentityIssue> check({
      String? gst,
      String? company,
      String gstin = _gstin,
    }) => GstIdentityCheck.compare(
      savedGstin: gst,
      savedCompanyName: company,
      gstin: gstin,
      legalName: 'HARI SHANKAR KHANDELWAL',
      tradeName: 'Shiv Shanker Pashu Aahar Udyog',
    );

    test(
      'a different business is flagged (device case: Rohan Gupta Pvt. Ltd.)',
      () {
        expect(check(company: 'Rohan Gupta Pvt. Ltd.'), {
          GstIdentityIssue.nameDiffers,
        });
      },
    );

    test('a different saved GSTIN is flagged', () {
      expect(
        check(
          gst: '27AAAAA0000A1Z5',
          company: 'Shiv Shanker Pashu Aahar Udyog',
        ),
        {GstIdentityIssue.gstinDiffers},
      );
    });

    test('sole proprietor: profile under the legal name OR the trade name is not flagged', () {
      expect(check(company: 'Hari Shankar Khandelwal'), isEmpty);
      expect(check(company: 'M/s. Shiv Shanker Pashu Aahar Udyog'), isEmpty);
      expect(
        check(company: 'Shiv Shanker Pashu Aahar Udyog Pvt Ltd', gst: _gstin),
        isEmpty,
      );
    });

    test('empty profile values are not treated as a mismatch', () {
      expect(check(), isEmpty);
    });
  });

  group('submission preparation', () {
    test(
      'keeps the buyer\'s edits, records OCR values and flags edited fields',
      () {
        final ocr = _parse(referenceOcr);
        final form = {
          for (final e in ocr.toFieldMap().entries) e.key: e.value ?? '',
          GstField.tradeName: 'Shiv Shanker Pashu Aahar Udyog Co',
          GstField.gstin: ' 08adrpk6597j1zl ',
        };
        final draft = GstSubmissionDraft.fromForm(form, ocr);
        expect(
          draft.submitted[GstField.tradeName],
          'Shiv Shanker Pashu Aahar Udyog Co',
        );
        expect(draft.ocr[GstField.tradeName], 'Shiv Shanker Pashu Aahar Udyog');
        expect(draft.submitted[GstField.gstin], _gstin);
        expect(draft.editedFields, {GstField.tradeName});
        expect(draft.gstinEdited, isFalse);
        // Absent values stay null, never a placeholder.
        expect(draft.submitted[GstField.validityFrom], isNull);
      },
    );

    test('payload never carries status, verification or company fields', () {
      final ocr = _parse(referenceOcr);
      final draft = GstSubmissionDraft.fromForm({
        for (final e in ocr.toFieldMap().entries) e.key: e.value ?? '',
      }, ocr);
      final flat = draft.toPayload().toString();
      for (final forbidden in [
        'is_verified',
        'status',
        'trust_score',
        'company_id',
        'reviewer',
      ]) {
        expect(flat, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}
