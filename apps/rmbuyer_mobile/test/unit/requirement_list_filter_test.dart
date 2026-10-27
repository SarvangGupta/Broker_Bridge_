import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/requirement_list_filter.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/requirement_model.dart';

BuyerRequirement _req(
  String id, {
  String commodity = 'Wheat',
  String status = 'Open',
  DateTime? date,
  bool hasDate = true,
  DateTime? createdAt,
}) {
  return BuyerRequirement(
    id: id,
    commodityName: commodity,
    gradeName: 'Std',
    quantity: 10,
    unit: 'MT',
    targetPrice: 1000,
    status: status,
    targetDate: date ?? DateTime(2026, 10, 26),
    hasTargetDate: hasDate,
    createdAt: createdAt,
  );
}

void main() {
  final today = DateTime(2026, 10, 26, 15, 30);

  group('statusBucketOf', () {
    test('maps backend statuses without double counting', () {
      expect(statusBucketOf('Open'), RequirementStatusBucket.open);
      expect(statusBucketOf('Matching'), RequirementStatusBucket.open);
      expect(statusBucketOf('In Negotiation'), RequirementStatusBucket.inNegotiation);
      expect(statusBucketOf('Allocated'), RequirementStatusBucket.confirmed);
      expect(statusBucketOf('Partially Fulfilled'), RequirementStatusBucket.confirmed);
      expect(statusBucketOf('Fulfilled'), RequirementStatusBucket.completed);
      expect(statusBucketOf('Cancelled'), isNull);
    });

    test('bucketCounts totals never exceed record count', () {
      final all = [
        _req('a'),
        _req('b', status: 'Fulfilled'),
        _req('c', status: 'Cancelled'),
      ];
      final counts = bucketCounts(all);
      expect(counts[RequirementStatusBucket.open], 1);
      expect(counts[RequirementStatusBucket.completed], 1);
      expect(counts.values.reduce((a, b) => a + b), lessThanOrEqualTo(all.length));
    });
  });

  group('deliveryGroupOf', () {
    test('overdue, due soon, upcoming and date-not-set', () {
      expect(deliveryGroupOf(_req('o', date: DateTime(2026, 10, 23)), today), DeliveryGroup.overdue);
      expect(deliveryGroupOf(_req('t', date: DateTime(2026, 10, 26)), today), DeliveryGroup.dueSoon);
      expect(deliveryGroupOf(_req('s', date: DateTime(2026, 11, 2)), today), DeliveryGroup.dueSoon);
      expect(deliveryGroupOf(_req('u', date: DateTime(2026, 11, 3)), today), DeliveryGroup.upcoming);
      expect(deliveryGroupOf(_req('n', hasDate: false), today), DeliveryGroup.dateNotSet);
    });

    test('completed or cancelled past deadlines are not overdue', () {
      final past = DateTime(2026, 10, 1);
      expect(deliveryGroupOf(_req('f', status: 'Fulfilled', date: past), today), isNot(DeliveryGroup.overdue));
      expect(deliveryGroupOf(_req('c', status: 'Cancelled', date: past), today), isNot(DeliveryGroup.overdue));
    });

    test('days are counted by local calendar day', () {
      expect(daysUntilDelivery(_req('x', date: DateTime(2026, 10, 23, 23, 59)), today), -3);
    });
  });

  group('applyRequirementQuery', () {
    final all = [
      _req('REQ-1', commodity: 'Wheat', date: DateTime(2026, 11, 20), createdAt: DateTime(2026, 10, 1)),
      _req('REQ-2', commodity: 'Soybean', status: 'In Negotiation', date: DateTime(2026, 10, 28), createdAt: DateTime(2026, 10, 20)),
      _req('REQ-3', commodity: 'Mustard', date: DateTime(2026, 10, 20), createdAt: DateTime(2026, 9, 1)),
      _req('REQ-4', commodity: 'Maize', hasDate: false),
    ];

    test('search by commodity and by requirement id', () {
      expect(applyRequirementQuery(all, const RequirementListQuery(search: 'soy'), today).map((r) => r.id), ['REQ-2']);
      expect(applyRequirementQuery(all, const RequirementListQuery(search: 'req-3'), today).map((r) => r.id), ['REQ-3']);
    });

    test('earliest and latest delivery sorting keep undated last', () {
      final asc = applyRequirementQuery(all, const RequirementListQuery(), today).map((r) => r.id);
      expect(asc, ['REQ-3', 'REQ-2', 'REQ-1', 'REQ-4']);
      final desc = applyRequirementQuery(
        all, const RequirementListQuery(sort: RequirementSort.latestDelivery), today,
      ).map((r) => r.id);
      expect(desc, ['REQ-1', 'REQ-2', 'REQ-3', 'REQ-4']);
    });

    test('newest posted first', () {
      final ids = applyRequirementQuery(
        all, const RequirementListQuery(sort: RequirementSort.newestPosted), today,
      ).map((r) => r.id);
      expect(ids.first, 'REQ-2');
    });

    test('status and date filters combine', () {
      final open7 = applyRequirementQuery(
        all,
        const RequirementListQuery(
          status: RequirementStatusBucket.open,
          dateFilter: DeliveryDateFilter.due7,
        ),
        today,
      );
      expect(open7, isEmpty);

      final overdue = applyRequirementQuery(
        all, const RequirementListQuery(dateFilter: DeliveryDateFilter.overdue), today,
      ).map((r) => r.id);
      expect(overdue, ['REQ-3']);

      final due30 = applyRequirementQuery(
        all, const RequirementListQuery(dateFilter: DeliveryDateFilter.due30), today,
      ).map((r) => r.id);
      expect(due30, ['REQ-2', 'REQ-1']);
    });

    test('custom range is inclusive by day', () {
      final ids = applyRequirementQuery(
        all,
        RequirementListQuery(
          dateFilter: DeliveryDateFilter.custom,
          customStart: DateTime(2026, 10, 20),
          customEnd: DateTime(2026, 10, 28),
        ),
        today,
      ).map((r) => r.id);
      expect(ids, ['REQ-3', 'REQ-2']);
    });

    test('groupByDelivery keeps undated requirements visible', () {
      final groups = groupByDelivery(applyRequirementQuery(all, const RequirementListQuery(), today), today);
      expect(groups[DeliveryGroup.dateNotSet]!.map((r) => r.id), ['REQ-4']);
      expect(groups.values.expand((g) => g).length, all.length);
    });
  });
}
