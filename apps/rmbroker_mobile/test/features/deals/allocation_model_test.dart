import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/deals/domain/allocation_model.dart';

void main() {
  group('Allocation Model & Concurrency Validation Tests (RB-FL-08)', () {
    test('AllocationStatus parses all backend lifecycle states correctly', () {
      expect(AllocationStatus.fromString('PROPOSED'), AllocationStatus.proposed);
      expect(AllocationStatus.fromString('CONFIRMED'), AllocationStatus.confirmed);
      expect(AllocationStatus.fromString('COMMITTED_TO_DEAL'), AllocationStatus.committedToDeal);
      expect(AllocationStatus.fromString('COMMITTED'), AllocationStatus.committedToDeal);
      expect(AllocationStatus.fromString('RELEASED'), AllocationStatus.released);
      expect(AllocationStatus.fromString('CANCELLED'), AllocationStatus.cancelled);
      expect(AllocationStatus.fromString(null), AllocationStatus.proposed);
      expect(AllocationStatus.fromString('unknown_state'), AllocationStatus.proposed);
    });

    test('AllocationItem parses from authoritative backend JSON', () {
      final json = {
        'id': 'alc-uuid-001',
        'allocation_reference': 'ALC-20261017-0042',
        'requirement_id': 'req-uuid-001',
        'availability_id': 'avail-uuid-001',
        'lot_number': 'LOT-WHEAT-77',
        'seller_company_id': 'seller-co-01',
        'seller_company_name': 'Kisan Samriddhi Producer Co.',
        'seller_company_verified': true,
        'broker_id': 'broker-uuid-001',
        'deal_id': null,
        'allocated_quantity': 45.0,
        'unit_id': 'unit-mt-01',
        'unit_name': 'Metric Tonne',
        'unit_symbol': 'MT',
        'price_basis': 'FOR_DESTINATION',
        'allocated_price': 27500.0,
        'status': 'CONFIRMED',
        'notes': 'Split allocation across Mandi rail siding',
        'version': 1,
        'allocated_at': '2026-10-17T12:00:00Z',
        'confirmed_at': '2026-10-17T12:05:00Z',
      };

      final item = AllocationItem.fromJson(json);

      expect(item.id, 'alc-uuid-001');
      expect(item.reference, 'ALC-20261017-0042');
      expect(item.lotNumber, 'LOT-WHEAT-77');
      expect(item.sellerCompanyName, 'Kisan Samriddhi Producer Co.');
      expect(item.sellerCompanyVerified, isTrue);
      expect(item.allocatedQuantity, 45.0);
      expect(item.unitSymbol, 'MT');
      expect(item.formattedQuantity, '45 MT');
      expect(item.status, AllocationStatus.confirmed);
      expect(item.canCreateDeal, isTrue);
      expect(item.isAlreadyCommitted, isFalse);
      expect(item.version, 1);
    });

    test('CreateAllocationDto enforces strict double-safety quantity bounds', () {
      // 1. Valid allocation within requirement and offer availability
      const validDto = CreateAllocationDto(
        requirementId: 'req-01',
        availabilityId: 'avail-01',
        proposedQuantity: 25.0,
        unitSymbol: 'MT',
        remainingRequirementQuantity: 50.0,
        availableOfferQuantity: 30.0,
        agreedPrice: 28000.0,
      );
      expect(validDto.validate(), isNull);

      // 2. Fails when quantity is zero or negative
      const zeroQtyDto = CreateAllocationDto(
        requirementId: 'req-01',
        availabilityId: 'avail-01',
        proposedQuantity: 0.0,
        unitSymbol: 'MT',
        remainingRequirementQuantity: 50.0,
        availableOfferQuantity: 30.0,
        agreedPrice: 28000.0,
      );
      expect(zeroQtyDto.validate(), contains('greater than zero'));

      // 3. Fails when quantity exceeds remaining requirement balance
      const exceedsReqDto = CreateAllocationDto(
        requirementId: 'req-01',
        availabilityId: 'avail-01',
        proposedQuantity: 55.0,
        unitSymbol: 'MT',
        remainingRequirementQuantity: 50.0,
        availableOfferQuantity: 100.0,
        agreedPrice: 28000.0,
      );
      expect(exceedsReqDto.validate(), contains('exceeds remaining requirement'));

      // 4. Fails when quantity exceeds available seller offer stock
      const exceedsOfferDto = CreateAllocationDto(
        requirementId: 'req-01',
        availabilityId: 'avail-01',
        proposedQuantity: 35.0,
        unitSymbol: 'MT',
        remainingRequirementQuantity: 50.0,
        availableOfferQuantity: 30.0,
        agreedPrice: 28000.0,
      );
      expect(exceedsOfferDto.validate(), contains('exceeds seller availability'));

      // 5. Fails when price is invalid
      const invalidPriceDto = CreateAllocationDto(
        requirementId: 'req-01',
        availabilityId: 'avail-01',
        proposedQuantity: 20.0,
        unitSymbol: 'MT',
        remainingRequirementQuantity: 50.0,
        availableOfferQuantity: 30.0,
        agreedPrice: 0.0,
      );
      expect(invalidPriceDto.validate(), contains('Agreed price must be greater than zero'));
    });
  });
}
