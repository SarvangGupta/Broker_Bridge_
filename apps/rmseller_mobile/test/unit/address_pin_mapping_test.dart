import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/profile/data/india_pincode_directory.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_profile_model.dart';

/// RB-SELLER-ADDRESS-PIN-FIX-01
void main() {
  const service = InvoiceOcrService(nativeEngineAvailable: false);

  group('India Post PIN directory', () {
    test('resolves district and state from the PIN (not a 3-digit guess)', () {
      final jaipur = IndiaPinCodeDirectory.lookup('302019')!;
      expect(jaipur.stateName, 'Rajasthan');
      expect(jaipur.districtName, 'Jaipur');
      expect(jaipur.stateCode, 'RJ');

      final kaushambi = IndiaPinCodeDirectory.lookup('212201')!;
      expect(kaushambi.stateName, 'Uttar Pradesh');
      expect(kaushambi.districtName, 'Kaushambi');
    });

    test('multi-district PIN is reported as ambiguous with all candidates', () {
      final r = IndiaPinCodeDirectory.lookup('110001')!;
      expect(r.isAmbiguous, isTrue);
      expect(r.districtName, isEmpty);
      expect(r.districtCandidates, containsAll(['Central', 'New Delhi']));
    });

    test('malformed or unknown PINs return null', () {
      expect(IndiaPinCodeDirectory.lookup('012345'), isNull);
      expect(IndiaPinCodeDirectory.lookup('33400'), isNull);
      expect(IndiaPinCodeDirectory.isKnownPin('100001'), isFalse);
      expect(IndiaPinCodeDirectory.lookup('100001'), isNull);
    });

    test('Hindi state names for display', () {
      expect(IndiaPinCodeDirectory.stateNameHindi('Uttar Pradesh'), 'उत्तर प्रदेश');
      expect(IndiaPinCodeDirectory.stateNameHindi('Rajasthan'), 'राजस्थान');
      expect(IndiaPinCodeDirectory.sameState('The Dadra and Nagar Haveli and Daman and Diu',
          'Dadra and Nagar Haveli and Daman and Diu'), isTrue);
    });
  });

  group('Supplier address extraction', () {
    test('English multi-line address with PIN → HQ, street, PIN, state, district', () {
      const text = '''
GSTIN No. 08BCIPJ4336H1ZK
BINA ENTERPRISES
Address: 82, Paraswanath Colony,
Nirman Nagar, Jaipur (Raj.)-302019
Mob. : 8094689777
Invoice No. 223
For BINA ENTERPRISES
''';
      final d = service.extractFromText(text);
      expect(d.officeAddress, '82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019');
      expect(d.pinCode, '302019');
      expect(d.state, 'Rajasthan');
      expect(d.district, 'Jaipur');
      expect(d.hasPinAddressConflict, isFalse);
    });

    test('Hindi supplier address, buyer block emitted first, GSTIN/phone next to address', () {
      const text = '''
GSTIN : 09EBCPR5003P1Z8
मेसर्स शिव शंकर पशु आहार उद्योग
पता V.K.I.A., जयपुर - 302013
क्र.स.
मे0 सियाराम ट्रेडिंग कम्पनी
मलिकपुर महेवा, भरवारी, कौशाम्बी मो० : 9696700510, 9919808347
वास्ते-मे० सियाराम ट्रेडिंग कम्पनी
''';
      final d = service.extractFromText(text);
      expect(d.officeAddress, 'मलिकपुर महेवा, भरवारी, कौशाम्बी');
      expect(d.pinCode, isNull, reason: 'buyer PIN 302013 must not become the supplier PIN');
      expect(d.state, isNull);
      expect(d.district, isNull);
    });

    test('labelled but unknown PIN is kept and flagged for review', () {
      const text = '''
SHREE KRISHNA TRADERS
Address: 14, Grain Mandi Road, Bikaner
PIN: 100001
''';
      final d = service.extractFromText(text);
      expect(d.pinCode, '100001');
      expect(d.state, isNull);
      expect(d.hasPinAddressConflict, isTrue);
      expect(d.pinConflictNotice, contains('not found in the India Post directory'));
    });

    test('PIN conflicting with the written state is flagged, address kept intact', () {
      const text = '''
BHARAT KRISHI UDYOG
Address: 12 Grain Mandi, Ludhiana, Punjab - 334001
''';
      final d = service.extractFromText(text);
      expect(d.officeAddress, '12 Grain Mandi, Ludhiana, Punjab - 334001');
      expect(d.hasPinAddressConflict, isTrue);
      expect(d.pinConflictNotice, contains('Rajasthan'));
    });

    test('ambiguous PIN without a district hint asks the seller to choose', () {
      const text = '''
DELHI GRAIN TRADERS
Address: 5 Connaught Place - 110001
''';
      final d = service.extractFromText(text);
      expect(d.state, 'Delhi');
      expect(d.district, isNull);
      expect(d.pinConflictNotice, contains('more than one district'));
    });

    test('ambiguous PIN resolved by a district named in the address', () {
      const text = '''
DELHI GRAIN TRADERS
Address: 5 Janpath, New Delhi - 110001
''';
      final d = service.extractFromText(text);
      expect(d.district, 'New Delhi');
      expect(d.hasPinAddressConflict, isFalse);
    });

    test('item totals are never taken as a PIN', () {
      const text = '''
SHREE KRISHNA TRADERS
Address: 14, Grain Mandi Road, Bikaner
1 Wheat 1001 100 qtl 2400 240000
योग 334001
''';
      expect(service.extractFromText(text).pinCode, isNull);
    });

    test('address survives map → save (toMap) → reopen (fromMap) unchanged', () {
      const text = '''
मे0 सियाराम ट्रेडिंग कम्पनी
मलिकपुर महेवा, भरवारी, कौशाम्बी मो० : 9696700510
वास्ते-मे० सियाराम ट्रेडिंग कम्पनी
''';
      const base = SellerProfileModel(id: 'x', fullName: 'a', email: 'e@x.in', role: 'seller');
      final mapped = service.extractFromText(text).mapToSellerProfile(base);
      final reopened = SellerProfileModel.fromMap(mapped.toMap());
      expect(reopened.officeAddress, 'मलिकपुर महेवा, भरवारी, कौशाम्बी');
      expect(reopened.businessLocation.addressLine, 'मलिकपुर महेवा, भरवारी, कौशाम्बी');
      expect(reopened.businessLocation.name, 'मे० सियाराम ट्रेडिंग कम्पनी');
    });
  });
}
