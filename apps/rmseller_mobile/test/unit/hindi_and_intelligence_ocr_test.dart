import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';
import 'package:rmseller_mobile/features/profile/data/india_pincode_directory.dart';

void main() {
  group('RB-SELLER-OCR-INTELLIGENCE-01: Hindi OCR, Address & Intelligence Tests', () {
    const service = InvoiceOcrService(nativeEngineAvailable: false);

    group('1. Genuine Hindi & Devanagari Invoice Extraction', () {
      test('Extracts authentic Hindi invoice with Devanagari firm name, address, and commodities', () {
        const hindiInvoice = '''
          कर चालान / TAX INVOICE
          मैसर्स श्री बालाजी एग्रो ट्रेडर्स
          पता: दुकान नं. ४५, नई कृषि उपज मंडी परिसर,
          सूरजपोल गेट के पास, बीकानेर, राजस्थान - ३३४००१
          जीएसटी सं.: 08AABCB1234F1Z5
          मोबाइल: +91 98290 12345
          बिल संख्या: BILL-2026-108
          दिनांक: 25/10/2026

          माल का विवरण:
          १. सरसों बोल्ड (Mustard Bold) - १०० बोरी
          २. चना देसी (Desi Chana) - ५० बोरी

          बैंक विवरण:
          बैंक का नाम: भारतीय स्टेट बैंक (SBI)
          खाता संख्या: 334455667788
          आईएफएससी: SBIN0001234
          खाताधारक: श्री बालाजी एग्रो ट्रेडर्स
        ''';

        final extracted = service.extractFromText(hindiInvoice);

        // Devanagari script is preserved exactly without transliteration
        expect(extracted.isHindiDocument, isTrue);
        expect(extracted.firmName, contains('श्री बालाजी एग्रो ट्रेडर्स'));
        expect(extracted.gstin, '08AABCB1234F1Z5');
        expect(extracted.contactMobile, '9829012345');
        expect(extracted.pinCode, '334001');

        // State & District resolved via PIN code intelligence
        expect(extracted.state, 'Rajasthan');
        expect(extracted.district, 'Bikaner');

        // Address captured multi-line
        expect(extracted.officeAddress, contains('दुकान नं. ४५'));
        expect(extracted.officeAddress, contains('बीकानेर, राजस्थान'));

        // Commodities extracted in Hindi/English
        expect(extracted.extractedCommodities, contains('Mustard'));
        expect(extracted.extractedCommodities, contains('Chana'));

        // Bank details preserved
        expect(extracted.accountNumber, '334455667788');
        expect(extracted.ifscCode, 'SBIN0001234');
        expect(extracted.bankName, contains('भारतीय स्टेट बैंक'));
        expect(extracted.accountHolderName, contains('श्री बालाजी एग्रो ट्रेडर्स'));
      });

      test('Extracts Devanagari numerals in GSTIN and PIN without destroying text script', () {
        const devanagariNumeralsInvoice = '''
          बीजक
          मेसर्स राजस्थान दाल मिल एंड ट्रेडिंग कंपनी
          कार्यालय पता: प्लॉट १२, रीको इंडस्ट्रियल एरिया,
          जयपुर, राजस्थान - ३०२००३
          जीएसटी: ०८AABCB१२३४F१Z५
          संपर्क: ९८२९०५४३२१
        ''';

        final extracted = service.extractFromText(devanagariNumeralsInvoice);

        expect(extracted.firmName, contains('राजस्थान दाल मिल एंड ट्रेडिंग कंपनी'));
        expect(extracted.gstin, '08AABCB1234F1Z5');
        expect(extracted.pinCode, '302003');
        expect(extracted.state, 'Rajasthan');
        expect(extracted.district, 'Jaipur');
        expect(extracted.contactMobile, '9829054321');
      });
    });

    group('2. Multi-Line Address Extraction (English & Hindi)', () {
      test('Extracts English multi-line address without merging invoice metadata', () {
        const englishInvoice = '''
          TAX INVOICE
          M/s Bikaner Agro Industries Ltd
          Registered Office:
          Plot No. 88, Phase 2, Industrial Mandi Area,
          Opposite Grain Silo, Khara,
          Bikaner, Rajasthan - 334001
          GSTIN: 08AAACF4321Q1Z8
          Phone: +91-98291-23456
          Invoice No: INV-4491
        ''';

        final extracted = service.extractFromText(englishInvoice);

        expect(extracted.officeAddress, isNotNull);
        expect(extracted.officeAddress, contains('Plot No. 88'));
        expect(extracted.officeAddress, contains('Khara'));
        expect(extracted.officeAddress, contains('Bikaner, Rajasthan - 334001'));
        // Must NOT bleed into GSTIN or Phone
        expect(extracted.officeAddress, isNot(contains('GSTIN')));
        expect(extracted.officeAddress, isNot(contains('Phone')));
        expect(extracted.officeAddress, isNot(contains('INV-4491')));
      });

      test('Extracts multiple addresses and categorizes Registered Office vs Works', () {
        const multiAddressInvoice = '''
          TAX INVOICE
          Apex Grain Processors Pvt Ltd
          Corporate Office:
          Tower 4, Corporate Hub, Mandi Road, Jaipur, Rajasthan - 302001
          Works Address:
          Khasra 412, Village Bassi, Jaipur - 303301
          GSTIN: 08AABCA9988P1Z3
        ''';

        final extracted = service.extractFromText(multiAddressInvoice);

        expect(extracted.officeAddress, contains('Tower 4'));
        expect(extracted.addressCandidates, isNotEmpty);
        expect(extracted.addressCandidates.containsKey('Corporate Office'), isTrue);
      });
    });

    group('3. India PIN Code Intelligence & Conflict Detection', () {
      test('Resolves state and district from valid 6-digit Indian PIN codes', () {
        final rjResult = IndiaPinCodeDirectory.lookup('334001');
        expect(rjResult, isNotNull);
        expect(rjResult!.stateName, 'Rajasthan');
        expect(rjResult.stateCode, 'RJ');
        expect(rjResult.districtName, 'Bikaner');

        final mpResult = IndiaPinCodeDirectory.lookup('452001');
        expect(mpResult, isNotNull);
        expect(mpResult!.stateName, 'Madhya Pradesh');
        expect(mpResult.stateCode, 'MP');
        expect(mpResult.districtName, 'Indore');

        final dlResult = IndiaPinCodeDirectory.lookup('110001');
        expect(dlResult, isNotNull);
        expect(dlResult!.stateName, 'Delhi');
        expect(dlResult.stateCode, 'DL');
      });

      test('Rejects invalid Indian PIN codes safely', () {
        expect(IndiaPinCodeDirectory.isValidPin('012345'), isFalse); // First digit cannot be 0
        expect(IndiaPinCodeDirectory.isValidPin('33400'), isFalse);  // 5 digits
        expect(IndiaPinCodeDirectory.isValidPin('3340011'), isFalse); // 7 digits
        expect(IndiaPinCodeDirectory.isValidPin('ABCDEF'), isFalse);
        expect(IndiaPinCodeDirectory.isValidPin(null), isFalse);
      });

      test('Flags conflict when PIN code state contradicts address state in document', () {
        const conflictingInvoice = '''
          TAX INVOICE
          Malwa Agro Millers
          Address: Mandi Road, Kota, Rajasthan
          PIN: 452001
          GSTIN: 23AAACM1122Q1Z4
        ''';

        final extracted = service.extractFromText(conflictingInvoice);

        expect(extracted.pinCode, '452001');
        expect(extracted.state, 'Madhya Pradesh');
        // Conflict flagged because text explicitly mentions Rajasthan while PIN 452001 is in Madhya Pradesh
        expect(extracted.hasPinAddressConflict, isTrue);
        expect(extracted.pinConflictNotice, contains('Madhya Pradesh'));
        expect(extracted.pinConflictNotice, contains('Rajasthan'));
      });
    });

    group('4. Indian Mobile Number Extraction & Disambiguation', () {
      test('Extracts Indian mobile numbers across diverse formatting', () {
        const formattedInvoices = [
          'Contact: +91 98290 12345',
          'Mobile: +91-98290-12345',
          'Mob: 09829012345',
          'Ph: 98290-12345',
          'मोबाइल: ९८२९०१२३४५',
        ];

        for (final text in formattedInvoices) {
          final res = service.extractFromText(text);
          expect(res.contactMobile, '9829012345', reason: 'Failed for format: $text');
        }
      });

      test('Disambiguates seller contact from buyer and transporter numbers', () {
        const multiPartyInvoice = '''
          TAX INVOICE
          M/s Bikaner Dal Mills
          Mobile: +91 98290 11111
          GSTIN: 08AABCB1234F1Z5

          Bill To / Buyer:
          ABC Trading Co
          Buyer Phone: +91 98290 22222

          Transporter Details:
          Vehicle No: RJ-07-GA-1234
          Driver Mobile: 98290 33333
        ''';

        final extracted = service.extractFromText(multiPartyInvoice);

        // Primary seller mobile is prioritized
        expect(extracted.contactMobile, '9829011111');
        expect(extracted.phoneCandidates.length, 3);

        final sellerCandidate = extracted.phoneCandidates.firstWhere((c) => c.number == '9829011111');
        expect(sellerCandidate.isSellerCandidate, isTrue);
        expect(sellerCandidate.contextLabel, 'Seller Contact');

        final buyerCandidate = extracted.phoneCandidates.firstWhere((c) => c.number == '9829022222');
        expect(buyerCandidate.isSellerCandidate, isFalse);
        expect(buyerCandidate.contextLabel, 'Buyer Contact');

        final transportCandidate = extracted.phoneCandidates.firstWhere((c) => c.number == '9829033333');
        expect(transportCandidate.isSellerCandidate, isFalse);
        expect(transportCandidate.contextLabel, 'Transport Contact');
      });

      test('Does not confuse PIN codes, bank accounts, or GSTINs with mobile numbers', () {
        const numericText = '''
          TAX INVOICE
          GSTIN: 08AABCB1234F1Z5
          Account No: 334455667788
          PIN Code: 334001
          Invoice Date: 2026-10-24
        ''';

        final extracted = service.extractFromText(numericText);

        expect(extracted.contactMobile, isNull);
        expect(extracted.phoneCandidates, isEmpty);
        expect(extracted.pinCode, '334001');
        expect(extracted.accountNumber, '334455667788');
      });
    });

    group('5. GSTIN Extraction Protection & Regression', () {
      test('Preserves GSTIN extraction with standard Indian formats', () {
        const validGstins = [
          '08AABCB1234F1Z5', // Rajasthan
          '23AAACM1122Q1Z4', // Madhya Pradesh
          '24AAACR5566P1Z1', // Gujarat
          '27AAACG9988K1Z9', // Maharashtra
        ];

        for (final gst in validGstins) {
          final res = service.extractFromText('GSTIN: $gst');
          expect(res.gstin, gst);
        }
      });

      test('Extracts GSTIN labeled with Hindi variants', () {
        const hindiLabeled = '''
          जीएसटी सं.: 08AABCB1234F1Z5
        ''';
        final res = service.extractFromText(hindiLabeled);
        expect(res.gstin, '08AABCB1234F1Z5');
      });

      test('Rejects invalid GSTIN formats safely', () {
        const invalidGstinTexts = [
          'GSTIN: 08AABCB1234F1Z', // 14 characters
          'GSTIN: 08AABCB1234F1Z59', // 16 characters
          'GSTIN: 999999999999999', // All digits
        ];

        for (final text in invalidGstinTexts) {
          final res = service.extractFromText(text);
          expect(res.gstin, isNull);
        }
      });
    });
  });
}
