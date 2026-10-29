import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/core/security/secure_storage_service.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';
import 'package:rmseller_mobile/features/profile/data/seller_profile_repository.dart';
import 'package:rmseller_mobile/features/profile/domain/business_location_model.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_bank_details.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_commodity_expertise.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_profile_model.dart';
import 'package:rmseller_mobile/features/profile/presentation/profile_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Reference Invoice 1: M/s Siyaram Trading Company (INV-OCR-01 - Hindi printed + handwritten)
  const String rawSiyaramOcr = '''
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

  // Reference Invoice 2: Bina Enterprises (INV-OCR-02 - English printed + handwritten)
  const String rawBinaOcr = '''
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

  group('MICRO-SPRINT RB-SELLER-HINDI-UNICODE-01: Hindi Language & Unicode Audit', () {
    late SecureStorageService storage;
    late SellerProfileRepository repository;
    const ocrService = InvoiceOcrService(nativeEngineAvailable: false);

    setUp(() async {
      storage = SecureStorageService();
      storage.enableMemoryFallbackForTesting();
      await storage.clearAll();
      repository = SellerProfileRepository(storage: storage);
    });

    // -------------------------------------------------------------------------
    // TEST A: Hindi invoice, English app UI
    // -------------------------------------------------------------------------
    test('Test A: Hindi invoice content preserves Devanagari script in English UI mode without translation or transliteration', () {
      final extracted = ocrService.extractFromText(rawSiyaramOcr);
      final englishStrings = const ProfileStrings(isHindi: false);

      // Verify English UI mode is active
      expect(englishStrings.isHindi, isFalse);
      expect(englishStrings.businessName, equals('Business Name'));
      expect(englishStrings.corporateOfficeHqAddress, equals('Corporate Office HQ Address'));

      // Extracted firm name must remain strictly in original Devanagari
      expect(extracted.firmName, equals('मे० सियाराम ट्रेडिंग कम्पनी'));
      expect(extracted.firmName, isNot(contains('Siyaram')));
      expect(extracted.firmName, isNot(contains('Trading Company')));

      // Extracted address must remain strictly in Devanagari
      expect(extracted.officeAddress, contains('मलिकपुर महेवा, भरवारी, कौशाम्बी'));
      expect(extracted.officeAddress, isNot(contains('Malikpur')));
      expect(extracted.officeAddress, isNot(contains('Kaushambi')));

      // Extracted commodity must preserve original Hindi text
      expect(extracted.extractedCommodities.any((c) => c.contains('कैटिल फीड')), isTrue);
      expect(extracted.extractedCommodities.any((c) => c.toLowerCase() == 'cattle feed'), isFalse);

      // Bank name in Hindi
      expect(extracted.bankName, contains('बैंक ऑफ बड़ौदा'));

      // Supplier profile mapping preserves exact Devanagari values
      const baseProfile = SellerProfileModel(
        id: 'test-seller-1',
        fullName: 'रामेश्वर दयाल',
        email: 'rameshwar@siyaram.in',
        role: 'seller',
      );
      final mapped = extracted.mapToSellerProfile(baseProfile);

      expect(mapped.companyName, equals('मे० सियाराम ट्रेडिंग कम्पनी'));
      expect(mapped.businessIdentifier, equals('मे० सियाराम ट्रेडिंग कम्पनी'));
      expect(mapped.officeAddress, contains('मलिकपुर महेवा, भरवारी, कौशाम्बी'));
      expect(mapped.businessLocation.name, equals('मे० सियाराम ट्रेडिंग कम्पनी'));
      expect(mapped.businessLocation.addressLine, contains('मलिकपुर महेवा, भरवारी, कौशाम्बी'));
      expect(mapped.businessLocation.addressLine, contains('मलिकपुर महेवा, भरवारी, कौशाम्बी'));
    });

    // -------------------------------------------------------------------------
    // TEST B: Hindi invoice, Hindi app UI
    // -------------------------------------------------------------------------
    test('Test B: Hindi invoice content and Hindi UI labels display correctly together', () {
      final extracted = ocrService.extractFromText(rawSiyaramOcr);
      final hindiStrings = const ProfileStrings(isHindi: true);

      // Verify Hindi UI labels
      expect(hindiStrings.isHindi, isTrue);
      expect(hindiStrings.businessName, equals('व्यवसाय का नाम'));
      expect(hindiStrings.corporateOfficeHqAddress, equals('कॉर्पोरेट कार्यालय का मुख्य पता'));
      expect(hindiStrings.personalContactDetails, equals('व्यक्तिगत और संपर्क विवरण'));
      expect(hindiStrings.bankDetailsTitle, equals('बैंक विवरण'));

      // Data values must remain identical Devanagari
      expect(extracted.firmName, equals('मे० सियाराम ट्रेडिंग कम्पनी'));
      expect(extracted.officeAddress, contains('मलिकपुर महेवा, भरवारी, कौशाम्बी'));
      expect(extracted.extractedCommodities.any((c) => c.contains('कैटिल फीड')), isTrue);
      expect(extracted.bankName, contains('बैंक ऑफ बड़ौदा'));
    });

    // -------------------------------------------------------------------------
    // TEST C: English invoice, Hindi app UI
    // -------------------------------------------------------------------------
    test('Test C: English invoice content remains in English while UI labels are in Hindi', () {
      final extracted = ocrService.extractFromText(rawBinaOcr);
      final hindiStrings = const ProfileStrings(isHindi: true);

      // UI labels are in Hindi
      expect(hindiStrings.businessName, equals('व्यवसाय का नाम'));
      expect(hindiStrings.corporateOfficeHqAddress, equals('कॉर्पोरेट कार्यालय का मुख्य पता'));
      expect(hindiStrings.save, equals('सेव करें'));
      expect(hindiStrings.cancel, equals('रद्द करें'));

      // Extracted business name and address MUST remain English (never transliterated into Hindi)
      expect(extracted.firmName, contains('BINA ENTERPRISES'));
      expect(extracted.firmName, isNot(contains('बीना')));
      expect(extracted.officeAddress, contains('Paraswanath Colony'));
      expect(extracted.officeAddress, isNot(contains('पारसनाथ')));

      // GSTIN & Bank
      expect(extracted.gstin, equals('08BCIPJ4336H1ZK'));
      expect(extracted.bankName?.toUpperCase(), contains('ICICI'));
    });

    // -------------------------------------------------------------------------
    // TEST D: Mixed-language invoice coexistence
    // -------------------------------------------------------------------------
    test('Test D: Mixed-language invoice fields coexist without corruption or mojibake', () {
      const mixedInvoiceOcr = '''
TAX INVOICE / कर चालान
मे० श्री राम एग्रो ट्रेडर्स
Near Krishi Upaj Mandi Yard, Khara Industrial Area
Bikaner, Rajasthan - 334001
GSTIN: 08AABCS9988D1Z3
Mob: 9414012345
Account: पंजाब नेशनल बैंक
IFSC: PUNB0123456
A/C: 1234002100056789

क्र.सं. विवरण HSN कोड मात्रा यूनिट दर धनराशि
1 चना दाल (Chana Dal) 12050000 50 बोरी 4500 225000
2 ग्वार गम (Guar Gum) 13020000 20 बैग 6000 120000
''';

      final extracted = ocrService.extractFromText(mixedInvoiceOcr);

      // Firm name contains Hindi
      expect(extracted.firmName, contains('श्री राम एग्रो ट्रेडर्स'));
      // Address contains English
      expect(extracted.officeAddress, contains('Near Krishi Upaj Mandi Yard'));
      expect(extracted.pinCode, equals('334001'));
      expect(extracted.gstin, equals('08AABCS9988D1Z3'));
      // Bank contains Hindi
      expect(extracted.bankName, contains('पंजाब नेशनल बैंक'));
      expect(extracted.ifscCode, equals('PUNB0123456'));
      expect(extracted.accountNumber, equals('1234002100056789'));

      // Commodity list has Hindi & English
      expect(extracted.extractedCommodities.any((c) => c.contains('चना दाल') || c.contains('ग्वार गम')), isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST E: Edit and Save Hindi profile values
    // -------------------------------------------------------------------------
    test('Test E: Editing and saving Hindi profile values survives roundtrip and reopening intact', () async {
      const initialProfile = SellerProfileModel(
        id: 'seller-hindi-roundtrip-01',
        fullName: 'रामेश्वर दयाल',
        email: 'rameshwar@siyaram.in',
        role: 'seller',
        companyName: 'सियाराम ट्रेडिंग कम्पनी',
        businessIdentifier: 'सियाराम ट्रेडिंग कम्पनी',
        versionIdentifier: 'BILL OF SUPPLY',
        companyGst: '09AABCS1429B1ZB',
        mobile: '9415236789',
        officeAddress: 'मलिकपुर महेवा, भरवारी, कौशाम्बी',
        state: 'Uttar Pradesh',
        district: 'Kaushambi',
        businessLocation: BusinessLocationModel(
          name: 'मलिकपुर महेवा, भरवारी, कौशाम्बी',
          addressLine: 'मलिकपुर महेवा, भरवारी, कौशाम्बी',
          locality: 'भरवारी मंडी क्षेत्र',
          stateName: 'Uttar Pradesh',
          districtName: 'Kaushambi',
          pinCode: '212201',
        ),
        bankDetails: SellerBankDetails(
          accountHolderName: 'सियाराम ट्रेडिंग कम्पनी',
          bankName: 'बैंक ऑफ बड़ौदा',
          accountNumber: '25890100004567',
          ifscCode: 'BARB0BHARWA',
          branchName: 'भरवारी',
        ),
        commodityExpertise: [
          SellerCommodityExpertise(id: 'c1', commodityName: 'कैटिल फीड', isApproved: true),
          SellerCommodityExpertise(id: 'c2', commodityName: 'चोकर', isApproved: false),
        ],
      );

      // 1. Initial save
      await repository.updateProfile(initialProfile);

      // 2. Fetch from repository
      final loaded1 = await repository.getProfile();
      expect(loaded1.companyName, equals('सियाराम ट्रेडिंग कम्पनी'));
      expect(loaded1.officeAddress, equals('मलिकपुर महेवा, भरवारी, कौशाम्बी'));
      expect(loaded1.bankDetails.bankName, equals('बैंक ऑफ बड़ौदा'));
      expect(loaded1.commodityExpertise.first.commodityName, equals('कैटिल फीड'));

      // 3. Edit to updated Hindi content
      final editedProfile = loaded1.copyWith(
        companyName: 'मे० सियाराम एग्रो इंडस्ट्रीज',
        businessIdentifier: 'मे० सियाराम एग्रो इंडस्ट्रीज',
        officeAddress: 'मंडी यार्ड, मंझनपुर, कौशाम्बी',
        businessLocation: loaded1.businessLocation.copyWith(
          name: 'मंडी यार्ड, मंझनपुर, कौशाम्बी',
          addressLine: 'प्लॉट 5, कृषि मंडी परिसर',
        ),
      );

      // 4. Save modified profile
      final updated = await repository.updateProfile(editedProfile);
      expect(updated.companyName, equals('मे० सियाराम एग्रो इंडस्ट्रीज'));

      // 5. Reopen profile fresh from repository/storage
      final reloaded = await repository.getProfile();
      expect(reloaded.companyName, equals('मे० सियाराम एग्रो इंडस्ट्रीज'));
      expect(reloaded.businessIdentifier, equals('मे० सियाराम एग्रो इंडस्ट्रीज'));
      expect(reloaded.officeAddress, equals('मंडी यार्ड, मंझनपुर, कौशाम्बी'));
      expect(reloaded.businessLocation.addressLine, equals('प्लॉट 5, कृषि मंडी परिसर'));
      expect(reloaded.bankDetails.bankName, equals('बैंक ऑफ बड़ौदा'));
      expect(reloaded.commodityExpertise[0].commodityName, equals('कैटिल फीड'));
    });

    // -------------------------------------------------------------------------
    // TEST F: Language switching preserves stored data values
    // -------------------------------------------------------------------------
    test('Test F: Switching UI language alters strings but preserves underlying profile values', () {
      const profile = SellerProfileModel(
        id: 'seller-lang-switch',
        fullName: 'विजय शर्मा',
        email: 'vijay@siyaram.in',
        role: 'seller',
        companyName: 'सियाराम ट्रेडिंग कम्पनी',
        officeAddress: 'मलिकपुर महेवा, भरवारी, कौशाम्बी',
      );

      // In English UI mode
      final enStrings = const ProfileStrings(isHindi: false);
      expect(enStrings.businessName, equals('Business Name'));
      expect(enStrings.corporateOfficeHqAddress, equals('Corporate Office HQ Address'));
      // Underlying data is strictly intact
      expect(profile.companyName, equals('सियाराम ट्रेडिंग कम्पनी'));
      expect(profile.officeAddress, equals('मलिकपुर महेवा, भरवारी, कौशाम्बी'));

      // Switch to Hindi UI mode
      final hiStrings = const ProfileStrings(isHindi: true);
      expect(hiStrings.businessName, equals('व्यवसाय का नाम'));
      expect(hiStrings.corporateOfficeHqAddress, equals('कॉर्पोरेट कार्यालय का मुख्य पता'));
      // Underlying data remains identical without alteration
      expect(profile.companyName, equals('सियाराम ट्रेडिंग कम्पनी'));
      expect(profile.officeAddress, equals('मलिकपुर महेवा, भरवारी, कौशाम्बी'));
    });

    // -------------------------------------------------------------------------
    // TEST G: Unicode round-trip byte & codepoint fidelity
    // -------------------------------------------------------------------------
    test('Test G: Full Unicode round trip ensures exact code point & UTF-8 serialization equality', () {
      const originalHindiText = 'मे० सियाराम ट्रेडिंग कम्पनी, मलिकपुर महेवा, भरवारी, कौशाम्बी - बैंक ऑफ बड़ौदा (कैटिल फीड)';

      const originalModel = SellerProfileModel(
        id: 'unicode-fidelity-1',
        fullName: 'रामेश्वर दयाल',
        email: 'rameshwar@siyaram.in',
        role: 'seller',
        companyName: 'मे० सियाराम ट्रेडिंग कम्पनी',
        businessIdentifier: 'मे० सियाराम ट्रेडिंग कम्पनी',
        versionIdentifier: 'BILL OF SUPPLY',
        officeAddress: 'मलिकपुर महेवा, भरवारी, कौशाम्बी',
        bankDetails: SellerBankDetails(
          accountHolderName: 'मे० सियाराम ट्रेडिंग कम्पनी',
          bankName: 'बैंक ऑफ बड़ौदा',
          branchName: 'भरवारी',
        ),
        commodityExpertise: [
          SellerCommodityExpertise(id: 'c1', commodityName: 'कैटिल फीड', isApproved: true),
        ],
      );

      // 1. Model -> toMap()
      final map = originalModel.toMap();

      // 2. toMap() -> JSON string (UTF-8)
      final jsonStr = jsonEncode(map);

      // Verify no ASCII escaping corruption or loss
      expect(jsonStr, contains('मे० सियाराम ट्रेडिंग कम्पनी'));
      expect(jsonStr, contains('मलिकपुर महेवा, भरवारी, कौशाम्बी'));
      expect(jsonStr, contains('बैंक ऑफ बड़ौदा'));

      // 3. UTF-8 byte serialization round trip
      final utf8Bytes = utf8.encode(jsonStr);
      final decodedJsonStr = utf8.decode(utf8Bytes);
      expect(decodedJsonStr, equals(jsonStr));

      // 4. JSON string -> fromMap()
      final decodedMap = jsonDecode(decodedJsonStr) as Map<String, dynamic>;
      final reloadedModel = SellerProfileModel.fromMap(decodedMap);

      // 5. Code-point level equality
      expect(reloadedModel.companyName.codeUnits, equals(originalModel.companyName.codeUnits));
      expect(reloadedModel.businessIdentifier.codeUnits, equals(originalModel.businessIdentifier.codeUnits));
      expect(reloadedModel.officeAddress.codeUnits, equals(originalModel.officeAddress.codeUnits));
      expect(reloadedModel.bankDetails.bankName.codeUnits, equals(originalModel.bankDetails.bankName.codeUnits));
      expect(reloadedModel.commodityExpertise.first.commodityName.codeUnits,
          equals(originalModel.commodityExpertise.first.commodityName.codeUnits));

      // Ensure no character conversion to ASCII question marks or mojibake
      expect(reloadedModel.companyName, isNot(contains('?')));
      expect(reloadedModel.companyName, isNot(contains('Ã')));
      expect(reloadedModel.officeAddress, isNot(contains('?')));
      expect(originalHindiText, contains(reloadedModel.companyName));
    });

    // -------------------------------------------------------------------------
    // TEST H: Existing functionality regression guard
    // -------------------------------------------------------------------------
    test('Test H: GSTIN extraction, phone extraction, supplier/buyer separation, and bank details remain robust', () {
      final siyaram = ocrService.extractFromText(rawSiyaramOcr);
      final bina = ocrService.extractFromText(rawBinaOcr);

      // 1. Siyaram Invoice Regressions
      expect(siyaram.gstin, equals('09EBCPR5003P1Z8'));
      expect(siyaram.contactMobile, equals('9696700510'));
      expect(siyaram.vehicleNumber?.replaceAll(' ', ''), equals('RJ07GE0579'));
      expect(siyaram.accountNumber, equals('328702000000341'));
      expect(siyaram.ifscCode, equals('BARB0BHARWA'));
      expect(siyaram.branchName, contains('भरवारी'));

      // Buyer separation: buyer details must NOT overwrite seller
      expect(siyaram.buyerDetails, isNotNull);
      expect(siyaram.buyerDetails!.buyerName, contains('शिव शंकर पशु आहार उद्योग'));
      expect(siyaram.buyerDetails!.gstin, equals('08ADRPK6597J1ZL'));
      expect(siyaram.buyerDetails!.contactMobile, equals('9828539054'));
      expect(siyaram.firmName, isNot(equals(siyaram.buyerDetails!.buyerName)));

      // 2. Bina Invoice Regressions
      expect(bina.gstin, equals('08BCIPJ4336H1ZK'));
      expect(bina.contactMobile, equals('8094689777'));
      expect(bina.invoiceNumber, equals('223'));
      expect(bina.accountNumber, equals('674905500169'));
      expect(bina.ifscCode, equals('ICIC0006749'));
      expect(bina.branchName, contains('Nirman Nagar'));

      // Buyer separation
      expect(bina.buyerDetails, isNotNull);
      expect(bina.buyerDetails!.buyerName, contains('Shiv Shanker Pashu Aahar Udyog'));
      expect(bina.buyerDetails!.gstin, equals('08ADRPK6597J1ZL'));
      expect(bina.firmName, isNot(equals(bina.buyerDetails!.buyerName)));
    });
  });
}
