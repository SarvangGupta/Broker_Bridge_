import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_profile_model.dart';
import 'package:rmseller_mobile/features/profile/domain/business_location_model.dart';

void main() {
  group('RB-SELLER-PROFILE-OCR-MAPPING-02: Invoice OCR → Seller Profile field mapping', () {
    const service = InvoiceOcrService(nativeEngineAvailable: false);

    const existingProfile = SellerProfileModel(
      id: 'seller_map_02',
      fullName: 'Existing Name',
      email: 'existing@seller.in',
      mobile: '9000000000',
      role: 'seller',
      companyName: 'Existing Firm',
      companyGst: '',
      officeAddress: 'Existing HQ',
      businessLocation: BusinessLocationModel(
        name: 'Existing Godown',
        addressLine: 'Existing Street',
        pinCode: '110001',
      ),
    );

    const siyaram = '''
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
      क्र.सं. विवरण HSN कोड मात्रा यूनिट दर धनराशि
      1 कैटिल फीड हालर भूसी 12130000 18700 1800 336600
      बैंक : बैंक ऑफ बड़ौदा, भरवारी - कौशाम्बी
      खाता सं० - 328702000000341
      IFSC कोड - BARB0BHARWA
    ''';

    const bina = '''
      GSTIN No. 08BCIPJ4336H1ZK
      STATE : RAJASTHAN | CODE : 08
      BILL OF SUPPLY
      Mob. : 8094689777
      BINA ENTERPRISES
      Cattele Feed & Raw Materials of Cattele Feed
      82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019
      Invoice No. 223
      Date 16-10-2026
      M/s Shiv Shanker Pashu Aahar Udyog [Handwritten]
      Address F-772B Road No 6D
      V.K.I.A. - Jaipur 302013
      GSTIN No. 08ADRPK6597J1ZL
      Mobile 9828539054
      S.No. PARTICULARS HSN Code Qty. Rate AMOUNT Rs.
      1 Paddy Husk 12130000 20200 kg 1800 363600
      C/A - ICICI BANK, A/C No. 674905500169
      IFSC Code :- ICIC0006749
    ''';

    group('Test A: Siyaram Trading Company', () {
      final data = service.extractFromText(siyaram);
      final mapped = data.mapToSellerProfile(existingProfile);

      test('supplier name, GSTIN, contact and Hindi address', () {
        expect(data.firmName, 'मे० सियाराम ट्रेडिंग कम्पनी');
        expect(data.gstin, '09EBCPR5003P1Z8');
        expect(data.contactMobile, '9696700510');
        expect(data.officeAddress, 'मलिकपुर महेवा, भरवारी, कौशाम्बी');
      });

      test('both supplier numbers offered as candidates; buyer numbers are labelled buyer', () {
        final seller = data.phoneCandidates.where((c) => c.isSellerCandidate).map((c) => c.number);
        expect(seller, containsAll(['9696700510', '9919808347']));
        expect(seller, isNot(contains('9828539054')));
        expect(seller, isNot(contains('9636215042')));
      });

      test('buyer details never reach supplier fields', () {
        expect(mapped.companyGst, isNot('08ADRPK6597J1ZL'));
        expect(mapped.officeAddress, isNot(contains('जयपुर')));
        expect(mapped.companyName, isNot(contains('शिव शंकर')));
        expect(mapped.mobile, '9696700510');
      });

      test('no PIN printed for supplier → PIN/district not fabricated', () {
        expect(data.pinCode, isNull);
        expect(data.district, isNull);
        expect(mapped.businessLocation.pinCode, '110001');
      });

      test('Devanagari survives map → toMap → fromMap round trip (save & reopen)', () {
        final reopened = SellerProfileModel.fromMap(mapped.toMap());
        expect(reopened.companyName, 'मे० सियाराम ट्रेडिंग कम्पनी');
        expect(reopened.officeAddress, 'मलिकपुर महेवा, भरवारी, कौशाम्बी');
      });
    });

    group('Test B: Bina Enterprises', () {
      final data = service.extractFromText(bina);
      final mapped = data.mapToSellerProfile(existingProfile);

      test('supplier name, GSTIN, mobile and printed Jaipur address', () {
        expect(data.firmName, 'BINA ENTERPRISES');
        expect(data.gstin, '08BCIPJ4336H1ZK');
        expect(data.contactMobile, '8094689777');
        expect(data.officeAddress, '82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019');
      });

      test('PIN and district come from supplier address, not buyer PIN 302013', () {
        expect(data.pinCode, '302019');
        expect(data.district, 'Jaipur');
        expect(mapped.businessLocation.pinCode, '302019');
      });

      test('handwritten buyer details stay in buyer section', () {
        expect(data.buyerDetails?.gstin, '08ADRPK6597J1ZL');
        expect(mapped.officeAddress, isNot(contains('F-772B')));
        expect(mapped.mobile, isNot('9828539054'));
      });
    });

    group('Field mapping rules', () {
      final mapped = service.extractFromText(bina).mapToSellerProfile(existingProfile);

      test('1 & 7: Full Name, Business Name and Location Name all = firm name', () {
        expect(mapped.fullName, 'BINA ENTERPRISES');
        expect(mapped.companyName, 'BINA ENTERPRISES');
        expect(mapped.businessLocation.name, 'BINA ENTERPRISES');
      });

      test('2: GSTIN merged onto name line by OCR never lands in Business Name', () {
        const merged = '''
          GSTIN No. 08BCIPJ4336H1ZK BINA ENTERPRISES
          Mob. : 8094689777
          82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019
        ''';
        final d = service.extractFromText(merged);
        expect(d.firmName, 'BINA ENTERPRISES');
        expect(d.gstin, '08BCIPJ4336H1ZK');
        final m = d.mapToSellerProfile(existingProfile);
        expect(m.companyName, isNot(contains('08BCIPJ4336H1ZK')));
        expect(m.fullName, isNot(contains('GSTIN')));
      });

      test('2b: name-less header does not promote the GSTIN line to a name', () {
        const noName = '''
          GSTIN : 09EBCPR5003P1Z8
          BILL OF SUPPLY
          1234
        ''';
        expect(service.extractFromText(noName).firmName, isNull);
      });

      test('4: invoice without email keeps the existing profile email', () {
        final d = service.extractFromText(bina);
        expect(d.email, isNull);
        expect(d.mapToSellerProfile(existingProfile).email, 'existing@seller.in');
      });

      test('4b: printed supplier email is extracted for review but never overwrites login email', () {
        const withEmail = '''
          BINA ENTERPRISES
          82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019
          Email: Bina.Ent@Gmail.com
        ''';
        final d = service.extractFromText(withEmail);
        expect(d.email, 'bina.ent@gmail.com');
        expect(d.mapToSellerProfile(existingProfile).email, 'existing@seller.in');
      });

      test('5: HQ address excludes GSTINs, invoice numbers and contact numbers', () {
        const noisy = '''
          SHREE RAM TRADERS
          Plot 12, Grain Mandi Road, Bikaner GSTIN 08AAAAA1111A1Z5
          Mob 9829012345
          Invoice No. 77
        ''';
        final d = service.extractFromText(noisy);
        expect(d.officeAddress, 'Plot 12, Grain Mandi Road, Bikaner');
      });

      test('5b: buyer "Address:" block is never used as supplier HQ address', () {
        const onlyBuyerAddress = '''
          TAX INVOICE
          KRISHNA AGRO
          GSTIN: 08AAAAA1111A1Z5
          Bill To: Mohan Feeds
          Address: 5 Station Road, Ajmer 305001
        ''';
        final d = service.extractFromText(onlyBuyerAddress);
        expect(d.officeAddress, isNull);
        expect(d.pinCode, isNull);
      });

      test('8: Street / Mandi / Area Address = complete supplier address', () {
        expect(mapped.businessLocation.addressLine, '82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019');
        expect(mapped.officeAddress, mapped.businessLocation.addressLine);
      });

      test('10: missing values keep existing profile values (no fabrication, no blanking)', () {
        const sparse = 'BINA ENTERPRISES';
        final m = service.extractFromText(sparse).mapToSellerProfile(existingProfile);
        expect(m.mobile, '9000000000');
        expect(m.officeAddress, 'Existing HQ');
        expect(m.businessLocation.addressLine, 'Existing Street');
        expect(m.businessLocation.pinCode, '110001');
      });
    });
  });
}
