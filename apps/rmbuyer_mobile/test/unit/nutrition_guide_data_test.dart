import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/nutrition/domain/nutrition_guide_data.dart';
import 'package:rmbuyer_mobile/features/nutrition/presentation/raw_material_details_sheet.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/master_requirement_data.dart';

const _protein = 'cat-protein';
const _oilCakes = 'cat-oilcakes';

const _catalogue = [
  MasterCommodity(id: 'p1', name: 'Guar Meal', code: '', categoryId: _protein),
  MasterCommodity(
    id: 'o1',
    name: 'Soybean DOC',
    code: 'SOY-DOC',
    categoryId: _oilCakes,
  ),
  // Name says "protein" but the approved link is Oil Cakes: the link wins.
  MasterCommodity(
    id: 'o2',
    name: 'High Protein Cake',
    code: '',
    categoryId: _oilCakes,
  ),
  MasterCommodity(id: 'x1', name: 'Uncategorised', code: ''),
];

void main() {
  test('global search matches name or code across every category', () {
    expect(
      NutritionGuideData.search(_catalogue, query: 'guar').map((c) => c.id),
      ['p1'],
    );
    expect(
      NutritionGuideData.search(_catalogue, query: 'soy-doc').map((c) => c.id),
      ['o1'],
    );
    expect(NutritionGuideData.search(_catalogue), hasLength(_catalogue.length));
    expect(NutritionGuideData.search(_catalogue, query: 'zzz'), isEmpty);
  });

  test(
    'category browsing uses the approved category link, never the product name',
    () {
      expect(
        NutritionGuideData.search(
          _catalogue,
          categoryId: _protein,
        ).map((c) => c.id),
        ['p1'],
      );
      expect(
        NutritionGuideData.search(
          _catalogue,
          categoryId: _oilCakes,
        ).map((c) => c.id),
        ['o1', 'o2'],
      );
      expect(
        NutritionGuideData.search(
          _catalogue,
          categoryId: _oilCakes,
          query: 'protein',
        ).map((c) => c.id),
        ['o2'],
      );
    },
  );

  test('counts come from the loaded catalogue; products without a category are not counted', () {
    expect(NutritionGuideData.countsByCategory(_catalogue), {
      _protein: 1,
      _oilCakes: 2,
    });
  });

  test('category id is read from the Product Master row', () {
    final c = MasterCommodity.fromMap({
      'id': 'a',
      'name': 'Rye',
      'status': true,
      'category_id': 'cat-1',
    });
    expect(c.categoryId, 'cat-1');
    expect(
      MasterCommodity.fromMap({'id': 'b', 'name': 'X'}).categoryId,
      isNull,
    );
  });

  test('unsupported views stay declared as unavailable, with reasons', () {
    expect(NutritionGuideData.unavailableGoals.map((u) => u.title), [
      'Calcium Source',
      'Milk Production Support',
      'Cost-Effective Options',
    ]);
    expect(
      NutritionGuideData.unavailableGoals.every((u) => u.reason.isNotEmpty),
      isTrue,
    );
  });

  test('grade parameter keys are labelled without inventing units', () {
    expect(
      RawMaterialDetailsSheet.parameterLabel('protein_min'),
      'Protein (min)',
    );
    expect(
      RawMaterialDetailsSheet.parameterLabel('foreign_matter_max'),
      'Foreign matter (max)',
    );
    expect(RawMaterialDetailsSheet.parameterLabel('moisture'), 'Moisture');
  });
}
