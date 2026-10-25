import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/nutrition/presentation/nutrition_guide_screen.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/master_requirement_data.dart';

import '../support/fake_requirements_repository.dart';

const _mineralsId = '0acda1d0-c712-5f96-8fdd-8be53bd76c64';

/// Pumps the guide at phone width; returns the list that collects `extra`
/// values pushed to the post-requirement route.
Future<List<Object?>> _pump(
  WidgetTester tester,
  FakeRequirementsRepository repo, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(360, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final pushedExtras = <Object?>[];
  final router = GoRouter(
    initialLocation: '/nutrition',
    routes: [
      GoRoute(
        path: '/nutrition',
        builder: (_, _) => NutritionGuideScreen(repository: repo),
      ),
      GoRoute(
        path: '/requirements/new',
        builder: (_, state) {
          pushedExtras.add(state.extra);
          return const Scaffold(body: Text('post-requirement-stub'));
        },
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
  );
  if (settle) await tester.pumpAndSettle();
  return pushedExtras;
}

Finder _field(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(_field(key), text);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'home shows the search field first, then live categories with active counts',
    (tester) async {
      await _pump(tester, FakeRequirementsRepository());

      expect(
        find.text('Search raw material name or product code...'),
        findsOneWidget,
      );
      final searchTop = tester
          .getTopLeft(find.byKey(const Key('nutrition-search')))
          .dy;
      final firstCardTop = tester
          .getTopLeft(
            find.byKey(const Key('nutrition-category-$distilleryCategoryId')),
          )
          .dy;
      expect(searchTop, lessThan(firstCardTop));

      // Active rows only: the two deactivated grains are not counted.
      final grains = find.byKey(
        const Key('nutrition-category-$grainsCategoryId'),
      );
      expect(
        find.descendant(
          of: grains,
          matching: find.text('Grains & Energy Ingredients'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: grains, matching: find.text('4 active products')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('nutrition-category-$oilCakesCategoryId')),
          matching: find.text('1 active product'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Cost-Effective Options:'), findsOneWidget);
      expect(find.textContaining('Calcium Source:'), findsOneWidget);
      expect(find.textContaining('Milk Production Support:'), findsOneWidget);
    },
  );

  testWidgets(
    'global search by name and by code works without choosing a category',
    (tester) async {
      await _pump(tester, FakeRequirementsRepository());

      await _type(tester, 'nutrition-search', 'ddgs');
      expect(
        find.byKey(const Key('nutrition-material-$maizeDdgsId')),
        findsOneWidget,
      );
      expect(
        find.text('Category: Distillery & Fermentation By-products'),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('nutrition-category-$grainsCategoryId')),
        findsNothing,
      );

      await _type(tester, 'nutrition-search', 'SOY-01');
      expect(find.text('Soybean Seed'), findsOneWidget);
      expect(find.text('Code: SOY-01'), findsOneWidget);
      expect(
        find.text(
          'Category: Whole Oilseeds, Pulses & Other Agricultural Feed Commodities',
        ),
        findsOneWidget,
      );

      await _type(tester, 'nutrition-search', 'zzz');
      expect(find.text('No raw material matches "zzz".'), findsOneWidget);
    },
  );

  testWidgets(
    'category browsing lists only linked active products, with in-category search',
    (tester) async {
      await _pump(tester, FakeRequirementsRepository());

      await tester.tap(
        find.byKey(const Key('nutrition-category-$grainsCategoryId')),
      );
      await tester.pumpAndSettle();

      for (final id in [dalId, riceId, wheatId, maizeId]) {
        expect(find.byKey(Key('nutrition-material-$id')), findsOneWidget);
      }
      expect(
        find.byKey(const Key('nutrition-material-$soybeanDocId')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('nutrition-material-$inactiveWheatId')),
        findsNothing,
      );

      await _type(tester, 'nutrition-category-search', 'WHEAT-01');
      expect(
        find.byKey(const Key('nutrition-material-$wheatId')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('nutrition-material-$riceId')), findsNothing);

      await _type(tester, 'nutrition-category-search', 'soybean');
      expect(find.text('No raw material matches "soybean".'), findsOneWidget);

      await tester.tap(find.byKey(const Key('nutrition-category-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nutrition-search')), findsOneWidget);
    },
  );

  testWidgets(
    'an approved category with no active product shows an honest empty state',
    (tester) async {
      final repo = FakeRequirementsRepository()
        ..categories = const [
          MasterCategory(id: _mineralsId, name: 'Minerals & Feed-grade Salts'),
        ];
      await _pump(tester, repo);

      expect(find.text('No active products yet'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('nutrition-category-$_mineralsId')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No active raw materials in this category yet.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'details show grade specifications and prefill only the material',
    (tester) async {
      final pushedExtras = await _pump(tester, FakeRequirementsRepository());

      await tester.tap(
        find.byKey(const Key('nutrition-category-$distilleryCategoryId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('nutrition-material-$maizeDdgsId')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Maize DDGS'), findsWidgets);
      expect(
        find.text('Category: Distillery & Fermentation By-products'),
        findsWidgets,
      );
      expect(find.text('Product code: not recorded'), findsOneWidget);
      expect(find.text('Grade Specifications'), findsOneWidget);
      expect(find.text('Average'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(
        find.textContaining('Not recorded in the product master'),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('nutrition-post-requirement')),
      );
      await tester.tap(find.byKey(const Key('nutrition-post-requirement')));
      await tester.pumpAndSettle();

      expect(find.text('post-requirement-stub'), findsOneWidget);
      expect(pushedExtras.single, {
        'commodity': 'Maize DDGS',
        'blankCommercialTerms': true,
      });
    },
  );

  testWidgets('loading, catalogue failure and retry; never a fallback list', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repo = FakeRequirementsRepository()..commodityGate = gate.future;
    await _pump(tester, repo, settle: false);
    await tester.pump();
    expect(find.text('Loading raw materials...'), findsOneWidget);

    repo.commodityError = Exception('offline');
    gate.complete();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not load the raw-material catalogue'),
      findsOneWidget,
    );
    expect(find.text('Dal'), findsNothing);

    repo
      ..commodityGate = null
      ..commodityError = null;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('nutrition-category-$grainsCategoryId')),
      findsOneWidget,
    );
  });

  testWidgets('category failure keeps global search working and offers retry', (
    tester,
  ) async {
    final repo = FakeRequirementsRepository()
      ..categoryError = Exception('denied');
    await _pump(tester, repo);

    expect(find.text('Could not load categories.'), findsOneWidget);
    await _type(tester, 'nutrition-search', 'rice');
    expect(find.byKey(const Key('nutrition-material-$riceId')), findsOneWidget);

    await _type(tester, 'nutrition-search', '');
    repo.categoryError = null;
    await tester.tap(find.byKey(const Key('nutrition-categories-retry')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('nutrition-category-$grainsCategoryId')),
      findsOneWidget,
    );
  });
}
