import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/work/domain/offer_model.dart';

void main() {
  group('Offer Domain Models & Inventory Tests (Sprint RB-FL-07)', () {
    test('OfferStatus parsing and display labels', () {
      expect(OfferStatus.fromString('open'), OfferStatus.open);
      expect(OfferStatus.fromString('active'), OfferStatus.open);
      expect(OfferStatus.fromString('partially available'), OfferStatus.partiallyAvailable);
      expect(OfferStatus.fromString('reserved'), OfferStatus.reserved);
      expect(OfferStatus.fromString('unavailable'), OfferStatus.unavailable);
      expect(OfferStatus.fromString('expired'), OfferStatus.expired);
      expect(OfferStatus.fromString('cancelled'), OfferStatus.cancelled);
      expect(OfferStatus.fromString('invalid'), OfferStatus.open);
    });

    test('Inventory quantities parsing and readiness states', () {
      final json = {
        'id': 'off-201',
        'offer_ref': 'OFF-2026-0089',
        'lot_number': 'LOT-2026-0089',
        'company_id': 'seller-1',
        'seller_company_name': 'Shekhawati Agro Traders',
        'seller_company_verified': true,
        'seller_trust_score': 92,
        'commodity_id': 'comm-wheat',
        'commodity_name': 'Sharbati Wheat',
        'grade_id': 'grade-a',
        'grade_name': 'Grade A Milling',
        'total_quantity': 80.0,
        'available_quantity': 50.0,
        'reserved_quantity': 20.0,
        'sold_quantity': 10.0,
        'unit_symbol': 'MT',
        'asking_price': 2750.0,
        'confidential_minimum_price': 2680.0,
        'district_name': 'Bikaner Mandi Yard',
        'state_name': 'Rajasthan',
        'loading_status': 'Ready to Load',
        'lab_report_url': 'https://storage.brokerbridge.in/reports/lab-891.pdf',
        'status': 'Open',
        'valid_until': DateTime.now().add(const Duration(days: 14)).toIso8601String(),
        'available_from': DateTime.now().toIso8601String(),
        'created_at': '2026-10-16T12:00:00.000Z',
      };

      final offer = OfferItem.fromJson(json);

      expect(offer.id, 'off-201');
      expect(offer.ref, 'OFF-2026-0089');
      expect(offer.lotNumber, 'LOT-2026-0089');
      expect(offer.sellerCompanyName, 'Shekhawati Agro Traders');
      expect(offer.commodityName, 'Sharbati Wheat');
      expect(offer.gradeName, 'Grade A Milling');

      // Separated inventory breakdown
      expect(offer.offeredQuantity, 80.0);
      expect(offer.availableQuantity, 50.0);
      expect(offer.reservedQuantity, 20.0);
      expect(offer.soldQuantity, 10.0);

      // Price & Floor
      expect(offer.askingPrice, 2750.0);
      expect(offer.confidentialMinimumPrice, 2680.0);
      expect(offer.districtName, 'Bikaner Mandi Yard');
      expect(offer.loadingStatus, LoadingReadiness.readyToLoad);

      // MANDATORY POLICY: Lab report is never labeled independently verified
      expect(offer.labReportUrl, isNotNull);
      expect(
        offer.labReportDisclaimer,
        'Seller Declared / Pending Verification',
      );
    });

    test('CreateOfferDto validation enforces positive price and valid bounds', () {
      final validDto = CreateOfferDto(
        companyId: 'seller-001',
        commodityId: 'comm-001',
        gradeId: 'grade-001',
        quantity: 40.0,
        unitId: 'unit-mt',
        askingPrice: 2800.0,
        confidentialMinimumPrice: 2700.0,
        districtId: 'dist-kota',
        stateId: 'state-rj',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 10)),
      );
      expect(validDto.validate(), isNull);

      // Floor price cannot be strictly greater than asking price
      final invalidFloorDto = CreateOfferDto(
        companyId: 'seller-001',
        commodityId: 'comm-001',
        gradeId: 'grade-001',
        quantity: 40.0,
        unitId: 'unit-mt',
        askingPrice: 2500.0,
        confidentialMinimumPrice: 2800.0,
        districtId: 'dist-kota',
        stateId: 'state-rj',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 10)),
      );
      expect(invalidFloorDto.validate(), contains('cannot exceed asking price'));

      // Empty districtId
      final noLocationDto = CreateOfferDto(
        companyId: 'seller-001',
        commodityId: 'comm-001',
        gradeId: 'grade-001',
        quantity: 40.0,
        unitId: 'unit-mt',
        askingPrice: 2500.0,
        confidentialMinimumPrice: 2400.0,
        districtId: '   ',
        stateId: 'state-rj',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 10)),
      );
      expect(noLocationDto.validate(), contains('district location is required'));
    });
  });
}
