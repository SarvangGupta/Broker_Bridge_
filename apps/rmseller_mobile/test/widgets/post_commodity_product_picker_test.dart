import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/features/commodities/domain/master_commodity_data.dart';
import 'package:rmseller_mobile/features/commodities/presentation/post_commodity_screen.dart';

import '../support/fake_commodities_repository.dart';

Future<void> pumpScreen(WidgetTester tester, FakeCommoditiesRepository repo, {String? initialCommodityId}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: PostCommodityScreen(commoditiesRepository: repo, initialCommodityId: initialCommodityId),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> searchAndPick(WidgetTester tester, String query, String id) async {
  await tester.ensureVisible(find.byKey(const Key('commodity-picker-field')));
  await tester.tap(find.byKey(const Key('commodity-picker-field')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('commodity-picker-search')), query);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('commodity-option-$id')));
  await tester.pumpAndSettle();
}

List<String> gradeOptions(WidgetTester tester) {
  final dropdown = tester.widget<DropdownButton<MasterGrade>>(
    find.descendant(of: find.byKey(const Key('grade_dropdown')), matching: find.byType(DropdownButton<MasterGrade>)),
  );
  return dropdown.items!.map((i) => i.value!.id).toList();
}

void main() {
  group('RB-PRODUCT-MASTER-07: RMSeller searchable product + category + grades', () {
    testWidgets('loads the shared catalogue and preselects nothing', (tester) async {
      final repo = FakeCommoditiesRepository();
      await pumpScreen(tester, repo);
      expect(repo.commodityLoads, 1);
      expect(find.text('Tap to search products'), findsOneWidget);
    });

    testWidgets('search "DOC" shows Soybean DOC with category; case-insensitive partial match', (tester) async {
      await pumpScreen(tester, FakeCommoditiesRepository());
      await tester.tap(find.byKey(const Key('commodity-picker-field')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('commodity-picker-search')), 'doc');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('commodity-option-$soybeanDocId')), findsOneWidget);
      expect(find.text('Category: Oil Cakes & Oil Meals'), findsOneWidget);
      expect(find.byKey(const Key('commodity-option-$maizeId')), findsNothing);

      await tester.enterText(find.byKey(const Key('commodity-picker-search')), 'BRAN');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('commodity-option-$wheatBranId')), findsOneWidget);
    });

    testWidgets('category label and grades update when the product changes', (tester) async {
      await pumpScreen(tester, FakeCommoditiesRepository());

      await searchAndPick(tester, 'maize', maizeId);
      expect(find.text('Category: Grains & Energy Ingredients'), findsOneWidget);
      expect(gradeOptions(tester), [maizeFeedId, maizeGradeAId]);

      await searchAndPick(tester, 'wheat', wheatBranId);
      expect(find.text('Category: Bran, Polish & Milling By-products'), findsOneWidget);
      expect(find.text('Category: Grains & Energy Ingredients'), findsNothing);
      expect(gradeOptions(tester), [wheatBranFaqId]);
    });

    testWidgets('product without a grade explains and cannot be listed', (tester) async {
      final repo = FakeCommoditiesRepository();
      await pumpScreen(tester, repo);
      await searchAndPick(tester, 'soybean', soybeanDocId);

      expect(find.byKey(const Key('no-grade-notice')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('quantity_field')), '10');
      await tester.enterText(find.byKey(const Key('asking_price_field')), '4500');
      await tester.ensureVisible(find.text('List Commodity on Desk'));
      await tester.tap(find.text('List Commodity on Desk'));
      await tester.pumpAndSettle();

      expect(repo.submitted, isEmpty);
    });

    testWidgets('missing category shows "Category unavailable"', (tester) async {
      await pumpScreen(tester, FakeCommoditiesRepository());
      await searchAndPick(tester, 'uncategorised', uncategorisedId);
      expect(find.text('Category unavailable'), findsOneWidget);
    });

    testWidgets('submission carries the selected product ID and its own grade ID', (tester) async {
      final repo = FakeCommoditiesRepository();
      await pumpScreen(tester, repo);
      await searchAndPick(tester, 'maize', maizeId);
      await searchAndPick(tester, 'wheat bran', wheatBranId);

      await tester.enterText(find.byKey(const Key('quantity_field')), '10');
      await tester.enterText(find.byKey(const Key('asking_price_field')), '4500');
      await tester.ensureVisible(find.text('List Commodity on Desk'));
      await tester.tap(find.text('List Commodity on Desk'));
      await tester.pumpAndSettle();

      expect(repo.submitted, hasLength(1));
      expect(repo.submitted.single.commodityId, wheatBranId);
      expect(repo.submitted.single.gradeId, wheatBranFaqId);
    });

    for (final (label, gradeId) in [('Good', maizeDdgsGoodId), ('Average', maizeDdgsAverageId)]) {
      testWidgets('GRADE-01: Maize DDGS offers Good/Average and lists with "$label"', (tester) async {
        final repo = FakeCommoditiesRepository();
        await pumpScreen(tester, repo);
        await searchAndPick(tester, 'ddgs', maizeDdgsId);

        expect(find.byKey(const Key('no-grade-notice')), findsNothing);
        expect(find.text('Category: Distillery & Fermentation By-products'), findsOneWidget);
        expect(gradeOptions(tester), [maizeDdgsAverageId, maizeDdgsGoodId]);

        await tester.tap(find.descendant(of: find.byKey(const Key('grade_dropdown')), matching: find.byType(DropdownButton<MasterGrade>)));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('quantity_field')), '10');
        await tester.enterText(find.byKey(const Key('asking_price_field')), '4500');
        await tester.ensureVisible(find.text('List Commodity on Desk'));
        await tester.tap(find.text('List Commodity on Desk'));
        await tester.pumpAndSettle();

        expect(repo.submitted, hasLength(1));
        expect(repo.submitted.single.commodityId, maizeDdgsId);
        expect(repo.submitted.single.gradeId, gradeId);
        expect(repo.submitted.single.gradeName, label);
        expect(find.textContaining('No grade is defined'), findsNothing);
      });
    }

    testWidgets('catalogue failure shows error with retry and no stale list', (tester) async {
      final repo = FakeCommoditiesRepository(commodityError: Exception('offline'));
      await pumpScreen(tester, repo);
      expect(find.byKey(const Key('commodity-load-error')), findsOneWidget);
      expect(find.byKey(const Key('commodity-picker-field')), findsNothing);

      repo.commodityError = null;
      await tester.ensureVisible(find.text('Retry').first);
      await tester.tap(find.text('Retry').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('commodity-picker-field')), findsOneWidget);
    });

    testWidgets('an unknown initial product ID selects nothing (no first-item fallback)', (tester) async {
      await pumpScreen(tester, FakeCommoditiesRepository(), initialCommodityId: 'not-in-catalogue');
      expect(find.text('Tap to search products'), findsOneWidget);
    });
  });
}
