import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_profile_model.dart';
import 'package:rmseller_mobile/features/profile/domain/business_location_model.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_bank_details.dart';

void main() {
  group('RB-SELLER-OCR-FIELD-MAPPING-01: Supplier Invoice OCR → Seller Profile Field Mapping', () {
    const service = InvoiceOcrService(nativeEngineAvailable: false);

    // Initial base seller profile
    const initialProfile = SellerProfileModel(
      id: 'seller_test_101',
      fullName: 'Original Seller Name',
      email: 'seller@test.com',
      mobile: '9999900000',
      role: 'seller',
      companyId: 'comp_101',
      companyName: 'Old Firm Name',
      businessIdentifier: 'Old Firm Name',
      versionIdentifier: '',
      companyGst: '08OLDGST0000A1Z0',
      officeAddress: 'Old Corporate Office Road',
      state: 'OldState',
      district: 'OldDistrict',
      businessLocation: BusinessLocationModel(
        name: 'Old Godown Name',
        addressLine: 'Old Street Address',
        pinCode: '000000',
        stateName: 'OldState',
        districtName: 'OldDistrict',
      ),
      bankDetails: SellerBankDetails(
        accountHolderName: 'Old Holder',
        bankName: 'Old Bank',
        accountNumber: '1111111111',
        ifscCode: 'OLDB0000001',
        branchName: 'Old Branch',
      ),
    );

    group('Benchmark 1: INV-OCR-01 — M/s Siyaram Trading Company (Hindi Invoice)', () {
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

      test('OCR-MAP-001: Maps supplier firm name to Business Name and Business Identifier (NOT GSTIN)', () {
        final extracted = service.extractFromText(siyaramInvoiceText);
        final mapped = extracted.mapToSellerProfile(initialProfile);

        // Supplier / Business Name -> Supplier's business or firm name
        expect(mapped.companyName, contains('सियाराम ट्रेडिंग कम्पनी'));
        // Business Identifier = Firm Name (Do NOT map GSTIN into this field!)
        expect(mapped.businessIdentifier, contains('सियाराम ट्रेडिंग कम्पनी'));
        expect(mapped.businessIdentifier, isNot(contains(extracted.gstin!)));
        expect(mapped.effectiveBusinessIdentifier, contains('सियाराम ट्रेडिंग कम्पनी'));
      });

      test('OCR-MAP-002: Version Identifier maps to Form Name (BILL OF SUPPLY)', () {
        final extracted = service.extractFromText(siyaramInvoiceText);
        final mapped = extracted.mapToSellerProfile(initialProfile);

        // Version Identifier = Form Name
        expect(mapped.versionIdentifier, contains('BILL OF SUPPLY'));
      });

      test('OCR-MAP-003: Supplier GSTIN maps to GST Number / GSTIN and NEVER buyer GSTIN', () {
        final extracted = service.extractFromText(siyaramInvoiceText);
        final mapped = extracted.mapToSellerProfile(initialProfile);

        expect(mapped.companyGst, '09EBCPR5003P1Z8');
        expect(mapped.companyGst, isNot(equals('08ADRPK6597J1ZL'))); // Buyer GSTIN must never overwrite!
        expect(extracted.buyerDetails?.gstin, '08ADRPK6597J1ZL');
      });

      test('OCR-MAP-004: Supplier mobile maps to contact details and NEVER buyer mobile', () {
        final extracted = service.extractFromText(siyaramInvoiceText);
        final mapped = extracted.mapToSellerProfile(initialProfile);

        expect(mapped.mobile, '9696700510');
        expect(mapped.mobile, isNot(equals('9828539054'))); // Buyer mobile must never overwrite!
      });

      test('OCR-MAP-005: Supplier address triple-maps to HQ, Location/Street, and Shop/Godown Address', () {
        final extracted = service.extractFromText(siyaramInvoiceText);
        final mapped = extracted.mapToSellerProfile(initialProfile);

        const expectedAddr = 'मलिकपुर महेवा, भरवारी, कौशाम्बी';
        // Corporate Office / HQ Address
        expect(mapped.officeAddress, contains(expectedAddr));
        // Location and Street
        expect(mapped.businessLocation.addressLine, contains(expectedAddr));
        // Shop and Godown Address
        expect(mapped.businessLocation.name, contains(expectedAddr));
      });

      test('OCR-MAP-006: Supplier bank details (Bank Name, Account Number, IFSC, Bank Branch) map accurately', () {
        final extracted = service.extractFromText(siyaramInvoiceText);
        final mapped = extracted.mapToSellerProfile(initialProfile);

        final bank = mapped.bankDetails;
        expect(bank.bankName, contains('बैंक ऑफ बड़ौदा'));
        expect(bank.accountNumber, '328702000000341');
        expect(bank.ifscCode, 'BARB0BHARWA');
        expect(bank.branchName, contains('भरवारी - कौशाम्बी'));
        expect(bank.isVerified, isFalse); // Bank verification invariant: strictly unverified
      });

      test('OCR-MAP-007: Unicode Hindi Devanagari text survives full serialization round-trip', () {
        final extracted = service.extractFromText(siyaramInvoiceText);
        final mapped = extracted.mapToSellerProfile(initialProfile);

        final serializedMap = mapped.toMap();
        final restored = SellerProfileModel.fromMap(serializedMap);

        expect(restored.companyName, mapped.companyName);
        expect(restored.businessIdentifier, mapped.businessIdentifier);
        expect(restored.versionIdentifier, mapped.versionIdentifier);
        expect(restored.officeAddress, mapped.officeAddress);
        expect(restored.businessLocation.addressLine, mapped.businessLocation.addressLine);
        expect(restored.bankDetails.bankName, mapped.bankDetails.bankName);
        expect(restored.bankDetails.branchName, mapped.bankDetails.branchName);
      });
    });

    group('Benchmark 2: INV-OCR-02 — Bina Enterprises (English Invoice)', () {
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

      test('OCR-MAP-008: Maps supplier firm name to Business Name and Business Identifier (NOT GSTIN)', () {
        final extracted = service.extractFromText(binaInvoiceText);
        final mapped = extracted.mapToSellerProfile(initialProfile);

        // Supplier / Business Name -> Supplier's business or firm name
        expect(mapped.companyName, contains('BINA ENTERPRISES'));
        // Business Identifier = Firm Name (Do NOT map GSTIN into this field!)
        expect(mapped.businessIdentifier, contains('BINA ENTERPRISES'));
        expect(mapped.businessIdentifier, isNot(contains(extracted.gstin!)));
        expect(mapped.effectiveBusinessIdentifier, contains('BINA ENTERPRISES'));
      });

      test('OCR-MAP-009: Version Identifier maps to Form Name (BILL OF SUPPLY)', () {
        final extracted = service.extractFromText(binaInvoiceText);
        final mapped = extracted.mapToSellerProfile(initialProfile);

        expect(mapped.versionIdentifier, contains('BILL OF SUPPLY'));
      });

      test('OCR-MAP-010: Supplier GSTIN maps to GST Number / GSTIN and NEVER buyer GSTIN', () {
        final extracted = service.extractFromText(binaInvoiceText);
        final mapped = extracted.mapToSellerProfile(initialProfile);

        expect(mapped.companyGst, '08BCIPJ4336H1ZK');
        expect(mapped.companyGst, isNot(equals('08ADRPK6597J1ZL')));
        expect(extracted.buyerDetails?.gstin, '08ADRPK6597J1ZL');
      });

      test('OCR-MAP-011: Supplier mobile maps to contact details and NEVER buyer mobile', () {
        final extracted = service.extractFromText(binaInvoiceText);
        final mapped = extracted.mapToSellerProfile(initialProfile);

        expect(mapped.mobile, '8094689777');
        expect(mapped.mobile, isNot(equals('9828539054')));
      });

      test('OCR-MAP-012: Supplier address, PIN code, state, and district map accurately', () {
        final extracted = service.extractFromText(binaInvoiceText);
        final mapped = extracted.mapToSellerProfile(initialProfile);

        const expectedAddr = '82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019';
        expect(mapped.officeAddress, contains(expectedAddr));
        expect(mapped.businessLocation.addressLine, contains(expectedAddr));
        expect(mapped.businessLocation.name, contains(expectedAddr));
        expect(mapped.businessLocation.pinCode, '302019');
        expect(mapped.state, 'Rajasthan');
        expect(mapped.district, 'Jaipur');
      });

      test('OCR-MAP-013: Bank details map Bank Name, Account Number, IFSC, and Bank Branch / Location', () {
        final extracted = service.extractFromText(binaInvoiceText);
        final mapped = extracted.mapToSellerProfile(initialProfile);

        final bank = mapped.bankDetails;
        expect(bank.bankName, contains('ICICI Bank'));
        expect(bank.accountNumber, '674905500169');
        expect(bank.ifscCode, 'ICIC0006749');
        expect(bank.branchName, contains('Nirman Nagar, Jaipur'));
        expect(bank.isVerified, isFalse);
      });
    });

    group('Edge Cases: Address-PIN Conflict and Missing Values', () {
      test('OCR-MAP-014: Written address conflicting with PIN triggers conflict notice without losing original address', () {
        const conflictingInvoice = '''
          TAX INVOICE
          M/s Bharat Agri Tradelink
          MG Road, Indore, Madhya Pradesh - 302001
          GSTIN: 23ABCDE1234F1Z5
        ''';

        final extracted = service.extractFromText(conflictingInvoice);
        expect(extracted.hasPinAddressConflict, isTrue);
        expect(extracted.pinConflictNotice, isNotNull);

        final mapped = extracted.mapToSellerProfile(initialProfile);
        // Original extracted address is preserved
        expect(mapped.officeAddress, contains('MG Road, Indore, Madhya Pradesh - 302001'));
      });

      test('OCR-MAP-015: Missing or uncertain values are never fabricated and retain current values', () {
        const minimalInvoice = '''
          BILL OF SUPPLY
          M/s Simple Seeds
        ''';

        final extracted = service.extractFromText(minimalInvoice);
        expect(extracted.firmName, contains('Simple Seeds'));
        expect(extracted.gstin, isNull);
        expect(extracted.accountNumber, isNull);
        expect(extracted.ifscCode, isNull);

        final mapped = extracted.mapToSellerProfile(initialProfile);
        expect(mapped.companyName, contains('Simple Seeds'));
        expect(mapped.businessIdentifier, contains('Simple Seeds'));
        expect(mapped.versionIdentifier, contains('BILL OF SUPPLY'));
        // Unextracted fields are NOT fabricated: they retain initial profile values
        expect(mapped.companyGst, initialProfile.companyGst);
        expect(mapped.bankDetails.accountNumber, initialProfile.bankDetails.accountNumber);
        expect(mapped.bankDetails.ifscCode, initialProfile.bankDetails.ifscCode);
      });
    });
  });
}
