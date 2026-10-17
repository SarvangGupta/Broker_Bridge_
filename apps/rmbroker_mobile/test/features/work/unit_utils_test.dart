import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/work/domain/unit_utils.dart';

void main() {
  group('CommodityUnit and UnitUtils Tests (Sprint RB-FL-07)', () {
    test('Standard commodity unit identification', () {
      expect(CommodityUnit.fromString('MT'), CommodityUnit.metricTonne);
      expect(CommodityUnit.fromString('ton'), CommodityUnit.metricTonne);
      expect(CommodityUnit.fromString('TONS'), CommodityUnit.metricTonne);
      expect(CommodityUnit.fromString('Qtl'), CommodityUnit.quintal);
      expect(CommodityUnit.fromString('quintal'), CommodityUnit.quintal);
      expect(CommodityUnit.fromString('Kg'), CommodityUnit.kilogram);
      expect(CommodityUnit.fromString('KG'), CommodityUnit.kilogram);
      expect(CommodityUnit.fromString('unknown'), CommodityUnit.metricTonne);
      expect(CommodityUnit.fromString(null), CommodityUnit.metricTonne);
    });

    test('Exact verified conversion: 1 MT = 10 quintals', () {
      // 1 MT to Quintal
      final qtlFromMt = UnitUtils.convert(
        quantity: 1.0,
        from: CommodityUnit.metricTonne,
        to: CommodityUnit.quintal,
      );
      expect(qtlFromMt, closeTo(10.0, 0.0001));

      // 10 Quintal to MT
      final mtFromQtl = UnitUtils.convert(
        quantity: 10.0,
        from: CommodityUnit.quintal,
        to: CommodityUnit.metricTonne,
      );
      expect(mtFromQtl, closeTo(1.0, 0.0001));

      // 25 MT = 250 Quintals
      expect(
        UnitUtils.convert(
          quantity: 25.0,
          from: CommodityUnit.metricTonne,
          to: CommodityUnit.quintal,
        ),
        closeTo(250.0, 0.0001),
      );
    });

    test('Exact verified conversion: 1 MT = 1,000 Kg and 1 Qtl = 100 Kg', () {
      // 1 MT to Kg
      expect(
        UnitUtils.convert(
          quantity: 1.0,
          from: CommodityUnit.metricTonne,
          to: CommodityUnit.kilogram,
        ),
        closeTo(1000.0, 0.0001),
      );

      // 1 Quintal to Kg
      expect(
        UnitUtils.convert(
          quantity: 1.0,
          from: CommodityUnit.quintal,
          to: CommodityUnit.kilogram,
        ),
        closeTo(100.0, 0.0001),
      );

      // 500 Kg to Quintals
      expect(
        UnitUtils.convert(
          quantity: 500.0,
          from: CommodityUnit.kilogram,
          to: CommodityUnit.quintal,
        ),
        closeTo(5.0, 0.0001),
      );

      // 2500 Kg to MT
      expect(
        UnitUtils.convert(
          quantity: 2500.0,
          from: CommodityUnit.kilogram,
          to: CommodityUnit.metricTonne,
        ),
        closeTo(2.5, 0.0001),
      );
    });

    test('Normalization to MT and Quintals via helpers', () {
      expect(UnitUtils.toMT(10.0, 'MT'), closeTo(10.0, 0.0001));
      expect(UnitUtils.toMT(100.0, 'Qtl'), closeTo(10.0, 0.0001));
      expect(UnitUtils.toMT(10000.0, 'Kg'), closeTo(10.0, 0.0001));

      expect(UnitUtils.toQuintals(5.0, 'MT'), closeTo(50.0, 0.0001));
      expect(UnitUtils.toQuintals(50.0, 'Qtl'), closeTo(50.0, 0.0001));
      expect(UnitUtils.toQuintals(500.0, 'Kg'), closeTo(5.0, 0.0001));
    });

    test('Quantity comparison across compatible units', () {
      // 5 MT vs 50 Quintals (Equal)
      expect(
        UnitUtils.compareQuantities(q1: 5.0, unit1: 'MT', q2: 50.0, unit2: 'Qtl'),
        0,
      );

      // 5 MT vs 40 Quintals (5 MT is greater)
      expect(
        UnitUtils.compareQuantities(q1: 5.0, unit1: 'MT', q2: 40.0, unit2: 'Qtl'),
        1,
      );

      // 5 MT vs 60 Quintals (5 MT is lesser)
      expect(
        UnitUtils.compareQuantities(q1: 5.0, unit1: 'MT', q2: 60.0, unit2: 'Qtl'),
        -1,
      );
    });

    test('Format quantity displays precision without floating point noise', () {
      expect(UnitUtils.format(25.0, 'MT'), '25 MT');
      expect(UnitUtils.format(25.5, 'MT'), '25.50 MT');
      expect(UnitUtils.format(25.125, 'MT'), '25.13 MT');
    });
  });
}
