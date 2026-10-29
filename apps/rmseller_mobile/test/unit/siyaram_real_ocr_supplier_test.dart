import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/profile/data/invoice_ocr_service.dart';
import 'package:rmseller_mobile/features/profile/domain/seller_profile_model.dart';

/// RB-SELLER-OCR-AUTO-VERIFY-01 — supplier fields only.
/// Fixture is the verbatim ML Kit (Devanagari model) output captured on a Redmi Note 5 Pro
/// for the Siyaram Trading Company invoice. Note the out-of-order blocks: the handwritten
/// buyer block is emitted before the printed supplier header.
const _realOcr = '''
GSTIN : 09EBCPR5003P1Z8
मेसर्स श.शकर...्शE 5] ..
पता ..K..A.,...प
शहर ..c1 पु र.
क्र.स.
१
2
3
पुस्तक संख्या
4
6
৪
9
10
11
csmN .o.ADRRK.65.91..1১2.... प्रदेश कोड ০9 ग्ाड़ी ने०.PaQ6aEQ.519..
मोबाइल नं०..285২9০64-93.6215.649. .आाष)
12
मे0 सियाराम द्रेडिंग कम्पनी
मलिकपुर महेवा, भरवारी, कौशाम्बी मो० : 9696700510, 9919808347
कैटिल फीड के विक़ेता)
कैटिल फीड हालर भूसी
............
सारफत সহাष
BILL OF SUPPLY
विवरण
बैक विवरण
रूपये शब्दों में ..तन. ल.सनहीस...E.AI.2..
टर सो.. रुपी . मA..
सभी विवाद कौशाम्बी न्यायालय के अन्तर्गत होगा।
भूल-चूक लेनी- देनी
बैंक : बैंक अफ बड़ौदा, भरवारी - कौशाम्बी
আता सं० - 32870200000341
FSC कोड - BARB0BHARWA
HSN कोड
ट्रांसपोर्ट प्रकार
मात्रा
योग
12130000187
इनवास दिनांक 27.1.0.%.2....
भाड़ा
|डिस्काउण्ट यदि कोई हो
कुल धनराशि
यूनिट
कुल योग
Original-White
Duplicate-Yellow
Triplicate-Pink
क्रम संख्या
11
मि्थी 2्पोर..
दर
धनराशि
(৪c০/33660।
3366o
3366
3366So
वास्ते-मे० सियाराम द्रेडिंग कम्पनी
স9৭০৭
अधिकृत हस्ताक्षर
''';

void main() {
  const service = InvoiceOcrService(nativeEngineAvailable: false);
  const existing = SellerProfileModel(
    id: 's', fullName: 'Existing', email: 'existing@seller.in', role: 'seller', mobile: '9000000000');

  final data = service.extractFromText(_realOcr);
  final m = data.mapToSellerProfile(existing);

  test('firm name from supplier signature populates Full Name, Business Name, Location Name', () {
    expect(data.firmName, 'मे० सियाराम द्रेडिंग कम्पनी'); // OCR read ट as द — seller corrects in review
    expect(m.fullName, data.firmName);
    expect(m.companyName, data.firmName);
    expect(m.businessLocation.name, data.firmName);
  });

  test('GSTIN in GSTIN field only', () {
    expect(m.companyGst, '09EBCPR5003P1Z8');
    expect(m.companyName, isNot(contains('GSTIN')));
  });

  test('supplier contact numbers', () {
    expect(m.mobile, '9696700510');
    final seller = data.phoneCandidates.where((c) => c.isSellerCandidate).map((c) => c.number);
    expect(seller, containsAll(['9696700510', '9919808347']));
  });

  test('HQ and street address = printed supplier address in Devanagari', () {
    expect(m.officeAddress, 'मलिकपुर महेवा, भरवारी, कौशाम्बी');
    expect(m.businessLocation.addressLine, 'मलिकपुर महेवा, भरवारी, कौशाम्बी');
  });

  test('no supplier PIN printed → PIN not fabricated; email preserved', () {
    expect(data.pinCode, isNull);
    expect(m.email, 'existing@seller.in');
  });

  test('bank fields stay in bank fields', () {
    expect(data.bankName, 'बैंक ऑफ बड़ौदा');
    expect(data.ifscCode, 'BARB0BHARWA');
    expect(data.branchName, 'भरवारी - कौशाम्बी');
    expect(data.accountNumber, '32870200000341'); // as OCR read it; flagged for manual review
  });
}
