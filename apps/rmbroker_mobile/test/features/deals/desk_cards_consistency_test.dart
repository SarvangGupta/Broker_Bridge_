import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/deals/data/deal_repository.dart';
import 'package:rmbroker_mobile/features/deals/domain/deal_model.dart';
import 'package:rmbroker_mobile/features/deals/presentation/widgets/deal_card.dart';
import 'package:rmbroker_mobile/features/work/domain/offer_model.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/offer_card.dart';

// RB-UI-CONSISTENCY-01: offer and deal cards. Fakes only.

DealItem allocatedDeal({String buyer = 'Rohan Gupta Pvt. Ltd.', String seller = 'Hadoti Grain Producers Co'}) =>
    DealItem.fromJson({
      'id': 'deal-1',
      'requirement_id': 'req-1',
      'quotation_id': 'q-1',
      'commodity_name': 'Yellow Maize (Corn)',
      'grade_name': 'Grade A Milling',
      'buyer_id': 'b',
      'buyer_company_name': buyer,
      'seller_id': 's',
      'seller_company_name': seller,
      'agreed_price': 22700,
      'agreed_quantity': 40,
      'status': 'Negotiation',
      'latestVersionNumber': 2,
      'buyerConfirmed': true,
      'created_at': '2026-10-19T02:47:00.000',
    });

DealItem unallocatedNegotiation() => DealRepository.requirementNegotiationItem({
      'id': '43728b98-5f80-4010-bf18-51cd06439c06',
      'company_id': 'rohan-co',
      'quantity': 100,
      'target_price': 21000,
      'created_at': '2026-10-25T01:22:00.000',
      'companies': {'name': 'Rohan Gupta Pvt. Ltd.'},
      'master_commodities': {'name': 'De-oiled Rice Bran (DORB)'},
    }, null);

OfferItem offer({double? floor, String seller = 'Hadoti Grain Producers Co'}) => OfferItem.fromJson({
      'id': 'off-1',
      'lot_number': 'LOT-2026-0155',
      'seller_company_name': seller,
      'seller_company_verified': true,
      'commodity_name': 'Sharbati Wheat',
      'grade_name': 'Grade A Milling',
      'unit_symbol': 'MT',
      'total_quantity': 70,
      'available_quantity': 50,
      'reserved_quantity': 20,
      'asking_price': 27500,
      'confidential_minimum_price': ?floor,
      'district_name': 'Kota',
      'state_name': 'Rajasthan',
      'loading_status': 'Ready to Load',
      'available_from': '2026-10-20T00:00:00.000',
      'valid_until': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
      'status': 'Open',
      'created_at': '2026-10-20T00:00:00.000',
    });

Future<bool> pumpCard(WidgetTester tester, Widget card, {Size size = const Size(1080, 1600), double dpr = 2.75}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  var tapped = false;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ListView(children: [
        GestureDetector(onTap: () => tapped = true, child: card),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
  return tapped;
}

void main() {
  testWidgets('deal card: allocated seller, metrics, single confirmation chips, tap opens', (tester) async {
    var opened = false;
    await pumpCard(tester, DealCard(deal: allocatedDeal(), onTap: () => opened = true));
    expect(find.text('NEGOTIATING'), findsOneWidget);
    expect(find.text('v2'), findsOneWidget);
    expect(find.text('Yellow Maize (Corn)'), findsOneWidget);
    expect(find.text('Grade: Grade A Milling'), findsOneWidget);
    expect(find.text('Rohan Gupta Pvt. Ltd.'), findsOneWidget);
    expect(find.text('Hadoti Grain Producers Co'), findsOneWidget);
    expect(find.text('40 MT'), findsOneWidget);
    expect(find.text('₹22,700 / MT'), findsOneWidget);
    expect(find.text('₹9,08,000'), findsOneWidget);
    expect(find.text('Buyer: Confirmed'), findsOneWidget);
    expect(find.text('Seller: Pending'), findsOneWidget);
    await tester.tap(find.text('Tap to view details'));
    expect(opened, isTrue);
  });

  testWidgets('deal card: unallocated seller shows the existing "Seller not allocated" state', (tester) async {
    await pumpCard(tester, DealCard(deal: unallocatedNegotiation(), onTap: () {}));
    final seller = find.byKey(const Key('deal_card_seller'));
    expect(find.descendant(of: seller, matching: find.text('Seller not allocated')), findsOneWidget);
    final text = tester.widget<Text>(find.descendant(of: seller, matching: find.text('Seller not allocated')));
    expect(text.style?.color, const Color(0xFFEA580C), reason: 'highlighted, not shown as a company');
    expect(find.text('Rohan Gupta Pvt. Ltd.'), findsOneWidget);
  });

  testWidgets('offer card: lot, seller, inventory, price, floor only when set, location, readiness', (tester) async {
    var opened = false;
    await pumpCard(tester, OfferCard(offer: offer(floor: 26000), onTap: () => opened = true));
    expect(find.text(offer().status.displayLabel.toUpperCase()), findsOneWidget);
    expect(find.text('LOT-2026-0155'), findsOneWidget);
    expect(find.text('Sharbati Wheat'), findsOneWidget);
    expect(find.text('Hadoti Grain Producers Co'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
    expect(find.text('50 MT'), findsOneWidget);
    expect(find.text('70 MT'), findsOneWidget);
    expect(find.text('20 MT'), findsOneWidget);
    expect(find.text('₹27,500 / MT'), findsOneWidget);
    expect(find.text('₹26,000 / MT'), findsOneWidget);
    expect(find.text('Kota, Rajasthan'), findsOneWidget);
    expect(find.textContaining('Valid: '), findsOneWidget);
    await tester.tap(find.text('Sharbati Wheat'));
    expect(opened, isTrue);

    await pumpCard(tester, OfferCard(offer: offer(), onTap: () {}));
    expect(find.text('Floor'), findsNothing, reason: 'floor only where present');
  });

  testWidgets('narrow 320dp screen with long names: no overflow on either card', (tester) async {
    const long = 'RBTEST Very Long Integrated Agro Commodities Processing & Trading Private Limited';
    await pumpCard(
      tester,
      Column(children: [
        DealCard(deal: allocatedDeal(buyer: long, seller: long), onTap: () {}),
        DealCard(deal: unallocatedNegotiation(), onTap: () {}),
        OfferCard(offer: offer(floor: 26000, seller: long), onTap: () {}),
      ]),
      size: const Size(640, 2400),
      dpr: 2.0,
    );
    expect(tester.takeException(), isNull);
  });
}
