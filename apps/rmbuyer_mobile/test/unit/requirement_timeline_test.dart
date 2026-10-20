import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/requirement_model.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/requirement_timeline_event.dart';

void main() {
  group('RB-BUYER-04: RequirementTimelineEvent Domain Tests', () {
    test('Builds verified milestones for Open requirement', () {
      final now = DateTime.now();
      final req = BuyerRequirement(
        id: 'REQ-OPEN-1',
        commodityName: 'Yellow Maize (Corn)',
        gradeName: 'Grade A Milling',
        quantity: 100.0,
        unit: 'MT',
        targetPrice: 2350.0,
        status: 'Open',
        targetDate: now.add(const Duration(days: 14)),
        createdAt: now.subtract(const Duration(days: 2)),
        brokerName: 'Jaipur Grain Broker Desk',
      );

      final events = RequirementTimelineEvent.fromRequirement(req);

      expect(events.length, 3);
      expect(events[0].title, 'Requirement Created');
      expect(events[0].isCurrent, isTrue);
      expect(events[0].isCompleted, isTrue);

      expect(events[1].title, 'Broker Desk Assigned');
      expect(events[1].description, contains('Jaipur Grain Broker Desk'));

      expect(events[2].title, 'Target Delivery Due');
      expect(events[2].isCompleted, isFalse);
    });

    test('Builds verified milestones for In Negotiation requirement', () {
      final now = DateTime.now();
      final req = BuyerRequirement(
        id: 'REQ-NEG-1',
        commodityName: 'Sharbati Wheat',
        gradeName: 'Premium Sharbati',
        quantity: 50.0,
        unit: 'MT',
        targetPrice: 2850.0,
        status: 'In Negotiation',
        targetDate: now.add(const Duration(days: 10)),
        createdAt: now.subtract(const Duration(days: 3)),
        brokerName: 'Kota Agro Brokerage',
      );

      final events = RequirementTimelineEvent.fromRequirement(req);

      expect(events.any((e) => e.title == 'Active Broker Negotiation'), isTrue);
      final activeEvent = events.firstWhere((e) => e.title == 'Active Broker Negotiation');
      expect(activeEvent.isCurrent, isTrue);
      expect(activeEvent.isCompleted, isTrue);
    });

    test('Builds verified milestones for Allocated requirement with partial quantity', () {
      final now = DateTime.now();
      final req = BuyerRequirement(
        id: 'REQ-ALLOC-1',
        commodityName: 'Soybean Seed',
        gradeName: 'Standard FAQ',
        quantity: 100.0,
        unit: 'MT',
        targetPrice: 4800.0,
        status: 'Allocated',
        targetDate: now.add(const Duration(days: 7)),
        fulfilledQuantity: 60.0,
        createdAt: now.subtract(const Duration(days: 4)),
      );

      final events = RequirementTimelineEvent.fromRequirement(req);

      expect(events.any((e) => e.title == 'Counterparty Lots Allocated'), isTrue);
      final allocEvent = events.firstWhere((e) => e.title == 'Counterparty Lots Allocated');
      expect(allocEvent.description, contains('60.0 MT'));
    });

    test('Builds verified milestones for Cancelled requirement with reason', () {
      final req = BuyerRequirement(
        id: 'REQ-CANC-1',
        commodityName: 'Desi Chana',
        gradeName: 'FAQ',
        quantity: 25.0,
        unit: 'MT',
        targetPrice: 5800.0,
        status: 'Cancelled',
        targetDate: DateTime.now().add(const Duration(days: 5)),
        notes: 'Cancelled: Procurement mandate fulfilled by Kota warehouse',
      );

      final events = RequirementTimelineEvent.fromRequirement(req);

      expect(events.any((e) => e.title == 'Requirement Cancelled'), isTrue);
      final cancEvent = events.firstWhere((e) => e.title == 'Requirement Cancelled');
      expect(cancEvent.description, contains('fulfilled by Kota warehouse'));
      // Does not contain future target delivery due event
      expect(events.any((e) => e.title == 'Target Delivery Due'), isFalse);
    });

    test('Counterparty Shield: Timeline events never disclose direct seller identities', () {
      final req = BuyerRequirement(
        id: 'REQ-SECURITY-1',
        commodityName: 'Mustard Seeds',
        gradeName: 'High Oil',
        quantity: 30.0,
        unit: 'MT',
        targetPrice: 5600.0,
        status: 'In Negotiation',
        targetDate: DateTime.now().add(const Duration(days: 6)),
      );

      final events = RequirementTimelineEvent.fromRequirement(req);

      for (final event in events) {
        expect(event.title.toLowerCase().contains('seller'), isFalse);
        expect(event.description.toLowerCase().contains('seller phone'), isFalse);
        expect(event.description.toLowerCase().contains('+91'), isFalse);
      }
    });
  });
}
