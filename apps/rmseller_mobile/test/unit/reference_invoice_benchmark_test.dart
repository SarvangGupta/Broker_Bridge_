import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';

void main() {
  group('RB-SELLER-OCR-INTELLIGENCE-02: Reference Invoice Benchmark Suite', () {
    const service = InvoiceOcrService(nativeEngineAvailable: false);

    group('Benchmark 1: INV-OCR-01 — M/s Siyaram Trading Company (Hindi Mandi Invoice)', () {
      // Source: media_1793153690314.jpg
      // Printed Hindi supplier header, handwritten buyer block, line items, truck details, printed Bank of Baroda details
      const siyaramInvoiceText = '''
        GSTIN : 09EBCPR5003P1Z8
        BILL OF SUPPLY
        Original-White Duplicate-Yellow Triplicate-Pink
        मे० सियाराम ट्रेडिंग कम्पनी
        मलिकपुर महेवा, भरवारी, कौशाम्बी मो० : 9696700510, 9919808347
        कैटिल फीड के विक्रेता
        क्रम संख्या 11

        मेसर्स शिव शंकर पशु आहार उद्योग [हस्तलिखित / Handwritten]
        पता V.K.I.A., जयपुर
        शहर जयपुर
        GSTIN 08ADRPK6597J1ZL प्रदेश कोड 09
        मोबाइल नं० 9828539054, (9636215042 आशीष)

        इनवाइस दिनांक: 27/10/2026
        ट्रांसपोर्ट प्रकार: गिरी ट्रांसपोर्ट
        गाड़ी नं० RJ07GE0579

        क्र.सं. विवरण HSN कोड मात्रा यूनिट दर धनराशि
        1 कैटिल फीड हालर भूसी 12130000 18700 1800 336600
        मारफत => आशीष

        रुपये शब्दों में: तीन लाख छत्तीस हजार छः सौ रुपये मात्र
        योग 336600
        कुल धनराशि 336600
        कुल योग 336600

        सभी विवाद कौशाम्बी न्यायालय के अन्तर्गत होगा।
        भूल-चूक लेनी-देनी
        बैंक विवरण
        बैंक : बैंक ऑफ बड़ौदा, भरवारी - कौशाम्बी
        खाता सं० - 328702000000341
        IFSC कोड - BARB0BHARWA
        वास्ते-मे० सियाराम ट्रेडिंग कम्पनी
      ''';

      test('OCR-001 & OCR-003: Extracts Supplier (Printed Hindi) name and details in original Devanagari', () {
        final extracted = service.extractFromText(siyaramInvoiceText);

        expect(extracted.isHindiDocument, isTrue);
        expect(extracted.firmName, contains('सियाराम ट्रेडिंग कम्पनी'));
        expect(extracted.gstin, '09EBCPR5003P1Z8');
        expect(extracted.contactMobile, '9696700510');
        expect(extracted.officeAddress, contains('मलिकपुर महेवा, भरवारी, कौशाम्बी'));
        expect(extracted.documentType, contains('BILL OF SUPPLY'));
        expect(extracted.invoiceDate, '27/10/2026');
      });

      test('OCR-017: Extracts Vehicle / Truck registration and transport type', () {
        final extracted = service.extractFromText(siyaramInvoiceText);

        expect(extracted.vehicleNumber, isNotNull);
        expect(extracted.vehicleNumber, contains('RJ 07 GE 0579'));
        expect(extracted.transportType, contains('गिरी ट्रांसपोर्ट'));
      });

      test('OCR-005, OCR-008 & OCR-010: Separates Handwritten Buyer details into BuyerDetails cleanly', () {
        final extracted = service.extractFromText(siyaramInvoiceText);

        expect(extracted.buyerDetails, isNotNull);
        final buyer = extracted.buyerDetails!;
        expect(buyer.buyerName, contains('शिव शंकर पशु आहार उद्योग'));
        expect(buyer.gstin, '08ADRPK6597J1ZL');
        expect(buyer.gstin, isNot(equals(extracted.gstin)));
        expect(buyer.address, contains('V.K.I.A., जयपुर'));
        expect(buyer.contactMobile, '9828539054');
        expect(buyer.isHandwritten, isTrue);
      });

      test('OCR-018, OCR-020-023: Extracts commodity line items, HSN, and verifies arithmetic consistency', () {
        final extracted = service.extractFromText(siyaramInvoiceText);

        expect(extracted.lineItems, isNotEmpty);
        final item = extracted.lineItems.first;
        expect(item.description, contains('कैटिल फीड हालर भूसी'));
        expect(item.hsnCode, '12130000');
        expect(item.quantity, 18700.0);
        expect(item.rate, 1800.0);
        expect(item.amount, 336600.0);
        expect(item.isUncertain, isFalse);

        // Commodities list for seller expertise
        expect(extracted.extractedCommodities, contains('Cattle Feed / Husk'));

        // Financials
        expect(extracted.financials, isNotNull);
        final fin = extracted.financials!;
        expect(fin.grandTotal, 336600.0);
        expect(fin.amountInWords, contains('तीन लाख छत्तीस हजार'));
        expect(extracted.hasArithmeticMismatch, isFalse);
      });

      test('OCR-029-031: Extracts printed Bank of Baroda details and IFSC', () {
        final extracted = service.extractFromText(siyaramInvoiceText);

        expect(extracted.bankName, contains('बैंक ऑफ बड़ौदा'));
        expect(extracted.accountNumber, '328702000000341');
        expect(extracted.ifscCode, 'BARB0BHARWA');
      });
    });

    group('Benchmark 2: INV-OCR-02 — Bina Enterprises (Printed English Supplier with Handwritten Entries)', () {
      // Source: media_1793153745982.png
      // Printed English supplier details, handwritten buyer info, handwritten commodity/quantity, freight annotations
      const binaInvoiceText = '''
        GSTIN No. 08BCIPJ4336H1ZK
        STATE : RAJASTHAN | CODE : 08
        BILL OF SUPPLY
        Mob. : 8094689777
        BINA ENTERPRISES
        Cattele Feed & Raw Materials of Cattele Feed
        82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019

        Invoice No. 223
        Date 16-10-2026
        State Rajasthan CODE : 08

        M/s Shiv Shanker Pashu Aahar Udyog [Handwritten]
        Address F-772B Road No 6D
        V.K.I.A. - Jaipur
        GSTIN No. 08ADRPK6597J1ZL

        S.No. PARTICULARS HSN Code Qty. Rate AMOUNT Rs.
        1 Paddy Husk 12130000 20200 kg 1800 363600

        TOTAL 363600
        EXEMPTED
        Truck No. : RJ22GB-9030
        Freight Rate : 1400
        Advance : Paid
        GRAND TOTAL 363600

        Payment only in - Bina Enterprises
        C/A - ICICI BANK, A/C No. 674905500169
        IFSC Code :- ICIC0006749
        Branch :- Nirman Nagar, Jaipur
        For BINA ENTERPRISES
      ''';

      test('OCR-002, OCR-004 & OCR-007: Extracts Printed English supplier details accurately', () {
        final extracted = service.extractFromText(binaInvoiceText);

        expect(extracted.isHindiDocument, isFalse);
        expect(extracted.firmName, contains('BINA ENTERPRISES'));
        expect(extracted.gstin, '08BCIPJ4336H1ZK');
        expect(extracted.contactMobile, '8094689777');
        expect(extracted.pinCode, '302019');
        expect(extracted.state, 'Rajasthan');
        expect(extracted.district, 'Jaipur');
        expect(extracted.officeAddress, contains('82, Paraswanath Colony, Nirman Nagar'));
        expect(extracted.invoiceNumber, '223');
        expect(extracted.invoiceDate, '16-10-2026');
        expect(extracted.vehicleNumber, contains('RJ 22 GB 9030'));
      });

      test('OCR-006 & OCR-008: Extracts Handwritten Buyer information and flags handwriting explicitly', () {
        final extracted = service.extractFromText(binaInvoiceText);

        expect(extracted.buyerDetails, isNotNull);
        final buyer = extracted.buyerDetails!;
        expect(buyer.buyerName, contains('Shiv Shanker Pashu Aahar Udyog'));
        expect(buyer.gstin, '08ADRPK6597J1ZL');
        expect(buyer.address, contains('F-772B Road No 6D'));
        expect(buyer.address, contains('V.K.I.A. - Jaipur'));
        expect(buyer.isHandwritten, isTrue);
        expect(extracted.hasHandwrittenContent, isTrue);
      });

      test('OCR-019, OCR-025-027: Extracts commodity line items, freight annotation and totals', () {
        final extracted = service.extractFromText(binaInvoiceText);

        expect(extracted.lineItems, isNotEmpty);
        final item = extracted.lineItems.first;
        expect(item.description, contains('Paddy Husk'));
        expect(item.hsnCode, '12130000');
        expect(item.quantity, 20200.0);
        expect(item.unit, contains('kg'));
        expect(item.rate, 1800.0);
        expect(item.amount, 363600.0);
        expect(item.isHandwritten, isTrue);

        expect(extracted.extractedCommodities, contains('Paddy (Rice)'));

        final fin = extracted.financials!;
        expect(fin.freightCharges, 1400.0);
        expect(fin.grandTotal, 363600.0);
        expect(fin.paymentStatus, contains('Paid'));
      });

      test('OCR-029-031: Extracts ICICI Bank details and IFSC', () {
        final extracted = service.extractFromText(binaInvoiceText);

        expect(extracted.bankName, contains('ICICI Bank'));
        expect(extracted.accountNumber, '674905500169');
        expect(extracted.ifscCode, 'ICIC0006749');
      });
    });

    group('Phase G: Validation, Arithmetic Reconciliation & Uncertainty Handling', () {
      test('OCR-024: Flags arithmetic mismatch when rate * quantity != amount without overwriting source values', () {
        // Document with deliberate math error or OCR distortion (rate 5000 * qty 100 != stated 600000)
        const mismatchInvoice = '''
          TAX INVOICE
          M/s Malwa Agri Trade
          Indore, MP - 452001
          GSTIN: 23AABCM1122N1Z3
          1. Wheat Lokwan 100 Qtl @ 5000 = 600000
          Sub Total: 600000
          Grand Total: 600000
        ''';

        final extracted = service.extractFromText(mismatchInvoice);

        expect(extracted.lineItems, isNotEmpty);
        final item = extracted.lineItems.first;
        // Extracted values are preserved exactly as written in the invoice
        expect(item.quantity, 100.0);
        expect(item.rate, 5000.0);
        expect(item.amount, 600000.0); // Preserved, NOT silently replaced with 500000!

        // Arithmetic discrepancy is flagged for seller review
        expect(extracted.hasArithmeticMismatch, isTrue);
        expect(extracted.arithmeticMismatchNotice, isNotNull);
        expect(extracted.arithmeticMismatchNotice, contains('Arithmetic discrepancy'));
        expect(extracted.uncertainFields, contains('Line Item: Wheat Lokwan'));
        expect(item.isUncertain, isTrue);
      });

      test('OCR-015: Flags conflict when PIN circle state contradicts address state', () {
        const conflictingInvoice = '''
          TAX INVOICE
          M/s Bharat Krishi Udyog
          Address: 12 Grain Mandi, Ludhiana, Punjab - 334001
          GSTIN: 03AABCB1111A1Z0
        ''';

        final extracted = service.extractFromText(conflictingInvoice);

        expect(extracted.pinCode, '334001'); // 334 is Rajasthan
        expect(extracted.hasPinAddressConflict, isTrue);
        expect(extracted.pinConflictNotice, isNotNull);
        expect(extracted.pinConflictNotice, contains('Rajasthan'));
        expect(extracted.pinConflictNotice, contains('Punjab'));
      });
    });
  });
}
