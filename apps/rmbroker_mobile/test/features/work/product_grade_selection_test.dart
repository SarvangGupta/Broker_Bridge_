import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/work/domain/trade_master_data.dart';
import 'package:rmbroker_mobile/features/work/presentation/controllers/master_data_controller.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/create_offer_sheet.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/create_requirement_sheet.dart';

// RB-PRODUCT-MASTER-07 fixture: IDs and category names as in the live Product Master.
const soyDoc = 'aa000000-0000-0000-0000-000000000001';
const maize = '20000000-0000-0000-0000-000000000001';
const wheatBran = '8f58c547-e988-5843-954a-6e0e57ae6b44';
const uncategorised = 'aa000000-0000-0000-0000-000000000009';
const maizeGradeA = '21000000-0000-0000-0000-000000000001';
const maizeFeed = '21000000-0000-0000-0000-000000000002';
const wheatBranFaq = '5dcb586c-632a-50c0-b097-a33efae04a20';
const otherFaq = 'add32e4f-14b2-528e-be9b-8bed0516c554';

const master = TradeMasterData(
  buyerCompanies: [MasterDropdownItem(id: 'b1', name: 'Test Buyer')],
  sellerCompanies: [MasterDropdownItem(id: 's1', name: 'Test Seller')],
  commodities: [
    MasterDropdownItem(id: soyDoc, name: 'Soybean DOC', categoryName: 'Oil Cakes & Oil Meals'),
    MasterDropdownItem(id: uncategorised, name: 'Uncategorised Product'),
    MasterDropdownItem(id: wheatBran, name: 'Wheat Bran', categoryName: 'Bran, Polish & Milling By-products'),
    MasterDropdownItem(id: maize, name: 'Yellow Maize (Corn)', categoryName: 'Grains & Energy Ingredients'),
  ],
  grades: [
    MasterDropdownItem(id: maizeFeed, name: 'Feed Grade Premium', parentId: maize),
    MasterDropdownItem(id: wheatBranFaq, name: 'FAQ (Fair Average Quality)', parentId: wheatBran),
    MasterDropdownItem(id: otherFaq, name: 'FAQ (Fair Average Quality)', parentId: 'some-other-product'),
    MasterDropdownItem(id: maizeGradeA, name: 'Grade A Milling', parentId: maize),
  ],
  units: [],
  states: [],
  districts: [],
);

Future<void> pumpSheet(WidgetTester tester, Widget sheet) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [masterDataProvider.overrideWith((ref) async => master)],
      child: MaterialApp(home: Scaffold(body: sheet)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> searchAndPick(WidgetTester tester, String query, String id) async {
  await tester.tap(find.byKey(const Key('commodity-picker-field')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('commodity-picker-search')), query);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('commodity-option-$id')));
  await tester.pumpAndSettle();
}

List<String> gradeOptions(WidgetTester tester) {
  final field = find.byWidgetPredicate(
    (w) => w is DropdownButtonFormField<String> && w.key.toString().contains('grade-dropdown'),
  );
  final dropdown = tester.widget<DropdownButton<String>>(
    find.descendant(of: field, matching: find.byType(DropdownButton<String>)),
  );
  return dropdown.items!.map((i) => i.value!).toList();
}

void main() {
  group('TradeMasterData product-grade rules (KI-43)', () {
    test('gradesFor returns only the product\'s own grades', () {
      expect(master.gradesFor(maize).map((g) => g.id), [maizeFeed, maizeGradeA]);
      expect(master.gradesFor(wheatBran).map((g) => g.id), [wheatBranFaq]);
      expect(master.gradesFor(soyDoc), isEmpty);
      expect(master.gradesFor(null), isEmpty);
    });

    test('isValidProductGrade rejects another product\'s grade', () {
      expect(master.isValidProductGrade(maize, maizeGradeA), isTrue);
      expect(master.isValidProductGrade(maize, wheatBranFaq), isFalse);
      expect(master.isValidProductGrade(wheatBran, otherFaq), isFalse);
      expect(master.isValidProductGrade(wheatBran, null), isFalse);
    });
  });

  group('Broker requirement sheet: searchable product + category + grades', () {
    testWidgets('search "doc" finds Soybean DOC with its category label', (tester) async {
      await pumpSheet(tester, const CreateRequirementSheet());
      await tester.tap(find.byKey(const Key('commodity-picker-field')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('commodity-picker-search')), 'DOC');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('commodity-option-$soyDoc')), findsOneWidget);
      expect(find.byKey(const Key('commodity-option-$maize')), findsNothing);
      expect(find.text('Category: Oil Cakes & Oil Meals'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('commodity-picker-search')), 'mAiZe');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('commodity-option-$maize')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('commodity-picker-search')), 'xyz');
      await tester.pumpAndSettle();
      expect(find.text('No product matches "xyz".'), findsOneWidget);
    });

    testWidgets('nothing is preselected; label updates when the product changes', (tester) async {
      await pumpSheet(tester, const CreateRequirementSheet());
      expect(find.text('Search products'), findsOneWidget);

      await searchAndPick(tester, 'bran', wheatBran);
      expect(find.text('Category: Bran, Polish & Milling By-products'), findsOneWidget);
      expect(gradeOptions(tester), [wheatBranFaq]);

      await searchAndPick(tester, 'maize', maize);
      expect(find.text('Category: Grains & Energy Ingredients'), findsOneWidget);
      expect(find.text('Category: Bran, Polish & Milling By-products'), findsNothing);
      expect(gradeOptions(tester), [maizeFeed, maizeGradeA]);
    });

    testWidgets('product without grades explains and blocks submission', (tester) async {
      await pumpSheet(tester, const CreateRequirementSheet());
      await searchAndPick(tester, 'soybean', soyDoc);
      expect(find.byKey(const Key('no-grade-notice')), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>).first); // buyer
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Buyer').last);
      await tester.pumpAndSettle();
      final saveBtn = find.text('Save Requirement');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('No grade is defined for Soybean DOC'), findsWidgets);
    });

    testWidgets('missing category shows "Category unavailable"', (tester) async {
      await pumpSheet(tester, const CreateRequirementSheet());
      await searchAndPick(tester, 'uncategorised', uncategorised);
      expect(find.text('Category unavailable'), findsOneWidget);
    });
  });

  group('Broker offer sheet', () {
    testWidgets('uses the same product picker and product-filtered grades', (tester) async {
      await pumpSheet(tester, const CreateOfferSheet());
      await searchAndPick(tester, 'wheat', wheatBran);
      expect(find.text('Category: Bran, Polish & Milling By-products'), findsOneWidget);
      expect(gradeOptions(tester), [wheatBranFaq]);
    });
  });
}
