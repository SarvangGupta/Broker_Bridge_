import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/profile/data/india_pincode_data.dart';
import 'package:rmseller_mobile/features/profile/data/india_pincode_directory.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';
import 'package:rmseller_mobile/features/profile/domain/business_location_model.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_profile_model.dart';

/// RB-SELLER-ADDRESS-PIN-COVERAGE-01 — national coverage of the bundled India Post data.
void main() {
  // One verified, single-state PIN per state/UT (mostly the capital's head post office).
  const representative = <String, List<String>>{
    'Andaman and Nicobar Islands': ['744101', 'South Andamans'],
    'Andhra Pradesh': ['520001', 'Krishna'],
    'Arunachal Pradesh': ['791111', 'Papum Pare'],
    'Assam': ['781001', 'Kamrup Metro'],
    'Bihar': ['800001', 'Patna'],
    'Chandigarh': ['160017', 'Chandigarh'],
    'Chhattisgarh': ['492001', 'Raipur'],
    'The Dadra and Nagar Haveli and Daman and Diu': ['396210', 'Daman'],
    'Delhi': ['110006', ''], // two districts (North, Central) — ambiguous by design
    'Goa': ['403001', 'North Goa'],
    'Gujarat': ['380001', 'Ahmadabad'],
    'Haryana': ['122001', 'Gurugram'],
    'Himachal Pradesh': ['171001', 'Shimla'],
    'Jammu and Kashmir': ['190001', 'Srinagar'],
    'Jharkhand': ['834001', 'Ranchi'],
    'Karnataka': ['560001', 'Bengaluru Urban'],
    'Kerala': ['695001', 'Thiruvananthapuram'],
    'Ladakh': ['194101', 'Leh Ladakh'],
    'Lakshadweep': ['682555', 'Lakshadweep District'],
    'Madhya Pradesh': ['462001', 'Bhopal'],
    'Maharashtra': ['400001', 'Mumbai'],
    'Manipur': ['795001', ''], // Imphal East / Imphal West — ambiguous by design
    'Meghalaya': ['793001', 'East Khasi Hills'],
    'Mizoram': ['796001', 'Aizawl'],
    'Nagaland': ['797001', 'Kohima'],
    'Odisha': ['751001', 'Khordha'],
    'Puducherry': ['605001', 'Pondicherry'],
    'Punjab': ['141001', 'Ludhiana'],
    'Rajasthan': ['302019', 'Jaipur'],
    'Sikkim': ['737101', 'East District'],
    'Tamil Nadu': ['600001', 'Chennai'],
    'Telangana': ['500001', 'Hyderabad'],
    'Tripura': ['799001', 'West Tripura'],
    'Uttar Pradesh': ['212201', 'Kaushambi'],
    'Uttarakhand': ['248001', 'Dehradun'],
    'West Bengal': ['700001', 'Kolkata'],
  };

  test('bundled data covers all 36 states and union territories', () {
    expect(kPinStates.length, 36);
    for (final s in representative.keys) {
      expect(kPinStates.where((k) => IndiaPinCodeDirectory.sameState(k, s)), isNotEmpty, reason: s);
    }
  });

  test('every district is linked to a valid state index', () {
    for (final d in kPinDistricts) {
      final parts = d.split('|');
      expect(parts.length, 2, reason: d);
      final idx = int.parse(parts[1]);
      expect(idx, inInclusiveRange(0, kPinStates.length - 1), reason: d);
    }
    expect(kPinDistricts.length, 737);
  });

  for (final e in representative.entries) {
    test('representative PIN ${e.value[0]} resolves to ${e.key}', () {
      final r = IndiaPinCodeDirectory.lookup(e.value[0])!;
      expect(IndiaPinCodeDirectory.sameState(r.stateName, e.key), isTrue, reason: '${r.stateName} vs ${e.key}');
      expect(r.districtName, e.value[1]);
      expect(r.stateCode, isNotEmpty);
    });
  }

  test('Hindi labels exist for every state/UT', () {
    for (final s in representative.keys) {
      expect(IndiaPinCodeDirectory.stateNameHindi(s), isNotNull, reason: s);
    }
  });

  test('PIN listed under two states resolves neither state nor district and is flagged', () {
    final r = IndiaPinCodeDirectory.lookup('503145')!;
    expect(r.isStateAmbiguous, isTrue);
    expect(r.stateName, isEmpty);
    expect(r.districtName, isEmpty);
    expect(r.stateCandidates, containsAll(['Telangana', 'Andhra Pradesh']));

    final d = const InvoiceOcrService(nativeEngineAvailable: false).extractFromText('''
KAMAREDDY AGRO TRADERS
Address: Main Road, Kamareddy - 503145
''');
    expect(d.state, isNull);
    expect(d.district, isNull);
    expect(d.pinConflictNotice, contains('more than one state'));
  });

  test('audited alias: India Post "Ganganagar" matches master "Sri Ganganagar"', () {
    expect(IndiaPinCodeDirectory.districtKey('Ganganagar'), IndiaPinCodeDirectory.districtKey('Sri Ganganagar'));
    expect(IndiaPinCodeDirectory.districtKey('Central'), 'central');
  });

  test('invoice without a PIN leaves saved state/district/PIN untouched', () {
    const saved = SellerProfileModel(
      id: 's', fullName: 'a', email: 'e@x.in', role: 'seller',
      state: 'Rajasthan', district: 'Jaipur',
      businessLocation: BusinessLocationModel(stateName: 'Rajasthan', districtName: 'Jaipur', pinCode: '302019'),
    );
    final d = const InvoiceOcrService(nativeEngineAvailable: false).extractFromText('''
मे0 सियाराम ट्रेडिंग कम्पनी
मलिकपुर महेवा, भरवारी, कौशाम्बी
वास्ते-मे० सियाराम ट्रेडिंग कम्पनी
''');
    final m = d.mapToSellerProfile(saved);
    expect(m.state, 'Rajasthan');
    expect(m.district, 'Jaipur');
    expect(m.businessLocation.pinCode, '302019');
    expect(m.businessLocation.stateName, 'Rajasthan');
    expect(m.businessLocation.districtName, 'Jaipur');
  });
}
