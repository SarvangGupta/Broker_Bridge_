import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/requirement_model.dart';

void main() {
  group('RB-BUYER-03: BuyerRequirement Domain Entity Tests', () {
    test('Constructs and parses BuyerRequirement from backend response', () {
      final map = {
        'id': 'REQ-2026-901',
        'commodity_name': 'Yellow Maize (Corn)',
        'grade_name': 'Grade A Milling',
        'quantity': 120.0,
        'unit': 'MT',
        'target_price': 2350.0,
        'status': 'Open',
        'target_date': '2026-11-15T00:00:00.000Z',
        'delivery_terms_id': 'FOR Mill Delivery, Kota Mandi',
        'broker_name': 'Jaipur Grain Broker Desk',
        'commodity_id': '20000000-0000-0000-0000-000000000001',
        'payment_terms': 'Payment on Delivery (CAD)',
      };

      final req = BuyerRequirement.fromMap(map);

      expect(req.id, 'REQ-2026-901');
      expect(req.commodityName, 'Yellow Maize (Corn)');
      expect(req.quantity, 120.0);
      expect(req.unit, 'MT');
      expect(req.targetPrice, 2350.0);
      expect(req.totalEstimatedValue, 120.0 * 2350.0);
      expect(req.status, 'Open');
      expect(req.canCancel, isTrue);
      expect(req.deliveryTerms, 'FOR Mill Delivery, Kota Mandi');
      expect(req.brokerName, 'Jaipur Grain Broker Desk');
      expect(req.paymentTerms, 'Payment on Delivery (CAD)');
    });

    test('canCancel is true ONLY for Open status, false for In Negotiation or Fulfilled', () {
      final openReq = BuyerRequirement(
        id: '1',
        commodityName: 'Maize',
        gradeName: 'A',
        quantity: 10,
        unit: 'MT',
        targetPrice: 2000,
        status: 'Open',
        targetDate: DateTime.now(),
      );
      final negotiatingReq = BuyerRequirement(
        id: '2',
        commodityName: 'Maize',
        gradeName: 'A',
        quantity: 10,
        unit: 'MT',
        targetPrice: 2000,
        status: 'In Negotiation',
        targetDate: DateTime.now(),
      );
      final fulfilledReq = BuyerRequirement(
        id: '3',
        commodityName: 'Maize',
        gradeName: 'A',
        quantity: 10,
        unit: 'MT',
        targetPrice: 2000,
        status: 'Fulfilled',
        targetDate: DateTime.now(),
      );

      expect(openReq.canCancel, isTrue);
      expect(negotiatingReq.canCancel, isFalse);
      expect(fulfilledReq.canCancel, isFalse);
    });

    test('Counterparty Shield: BuyerRequirement serialization strictly excludes seller contacts', () {
      final untrustedMap = {
        'id': 'REQ-COUNTERPARTY-TEST',
        'commodity_name': 'Soybean Seed',
        'grade_name': 'Standard FAQ',
        'quantity': 50.0,
        'unit': 'MT',
        'target_price': 4800.0,
        'status': 'Open',
        'target_date': '2026-11-20T00:00:00Z',
        // Injected unauthorized seller fields
        'seller_id': 'seller-vuln-01',
        'seller_mobile': '+91-9876543210',
        'seller_name': 'Leaked Seller Identity',
      };

      final req = BuyerRequirement.fromMap(untrustedMap);
      final serialized = req.toMap();

      expect(serialized.containsKey('seller_id'), isFalse);
      expect(serialized.containsKey('seller_mobile'), isFalse);
      expect(serialized.containsKey('seller_name'), isFalse);
    });

    test('CreateRequirementDto generates exact Supabase insert payload with authoritative UUID', () {
      final now = DateTime.now();
      const validBrokerUuid = 'b354958e-779a-41f2-b7a3-5899eca32e32';
      final dto = CreateRequirementDto(
        commodityId: 'comm-1',
        commodityName: 'Sharbati Wheat',
        gradeId: 'grade-1',
        gradeName: 'Premium Sharbati',
        quantity: 250.0,
        unitId: 'unit-1',
        unitSymbol: 'MT',
        targetPrice: 2850.0,
        deliveryLocation: 'FOR Factory Depot, Indore',
        targetDate: now,
        paymentTerms: '7 Days Net Credit',
        visibility: 'restricted',
        brokerId: validBrokerUuid,
      );

      final insertMap = dto.toSupabaseInsert('company-test-101');

      expect(insertMap['company_id'], 'company-test-101');
      expect(insertMap['commodity_id'], 'comm-1');
      expect(insertMap['grade_id'], 'grade-1');
      expect(insertMap['quantity'], 250.0);
      expect(insertMap['unit_id'], 'unit-1');
      expect(insertMap['target_price'], 2850.0);
      expect(insertMap['delivery_terms_id'], 'FOR Factory Depot, Indore');
      expect(insertMap['status'], 'Open');
      expect(insertMap['fulfilled_quantity'], 0);
      expect(insertMap['visibility'], 'restricted');
      expect(insertMap['broker_id'], validBrokerUuid);
    });

    test('CreateRequirementDto safely omits non-UUID demo/fallback IDs (prevents PostgreSQL 22P02)', () {
      final now = DateTime.now();
      final dto = CreateRequirementDto(
        commodityId: 'comm-1',
        commodityName: 'Sharbati Wheat',
        gradeId: 'grade-1',
        gradeName: 'Premium Sharbati',
        quantity: 100.0,
        unitId: 'unit-1',
        unitSymbol: 'MT',
        targetPrice: 2500.0,
        deliveryLocation: 'Jaipur Processing Mill',
        targetDate: now,
        paymentTerms: 'CAD',
        brokerId: 'broker-101', // Invalid non-UUID format
        selectedBrokerIds: ['broker-101'],
      );

      final insertMap = dto.toSupabaseInsert('company-test-101');

      // The non-UUID identifier must NOT be sent to PostgreSQL's UUID column
      expect(insertMap.containsKey('broker_id'), isFalse);
    });

    test('CreateRequirementDto.isValidUuid correctly validates RFC-4122 UUIDs', () {
      expect(CreateRequirementDto.isValidUuid('b354958e-779a-41f2-b7a3-5899eca32e32'), isTrue);
      expect(CreateRequirementDto.isValidUuid('00000000-0000-0000-0000-0000000000b1'), isTrue);
      expect(CreateRequirementDto.isValidUuid('broker-101'), isFalse);
      expect(CreateRequirementDto.isValidUuid(''), isFalse);
      expect(CreateRequirementDto.isValidUuid(null), isFalse);
    });
  });
}
