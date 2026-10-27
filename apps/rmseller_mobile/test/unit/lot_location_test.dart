import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/commodities/domain/lot_location.dart';
import 'package:rmseller_mobile/features/commodities/domain/master_commodity_data.dart';

void main() {
  const rj = MasterState(id: 'S-RJ', name: 'Rajasthan', code: 'RJ');
  const mp = MasterState(id: 'S-MP', name: 'Madhya Pradesh', code: 'MP');
  const states = [rj, mp];

  group('RB-SELLER-LOCATION-UX-01: LotLocation codec', () {
    test('shared loading keeps gate details and round-trips', () {
      const loc = LotLocation(
        warehouse: LotAddress(
          label: 'Main Warehouse',
          address: 'Plot 12, Ring Road',
          pinCode: '334001',
        ),
        loadingPoint: 'Gate 2, Shed 4',
      );
      expect(loc.warehouseText, 'Main Warehouse · Plot 12, Ring Road · PIN 334001');
      expect(loc.loadingRemarksText, 'Same as registered warehouse · Gate 2, Shed 4');
      expect(loc.officeText, LotLocation.sameAsWarehouseMarker);

      final back = LotLocation.decode(
        warehouseText: loc.warehouseText,
        loadingText: loc.loadingRemarksText,
        officeText: loc.officeText,
        states: states,
      );
      expect(back.warehouse.label, 'Main Warehouse');
      expect(back.warehouse.address, 'Plot 12, Ring Road');
      expect(back.warehouse.pinCode, '334001');
      expect(back.loadingSameAsWarehouse, isTrue);
      expect(back.loadingPoint, 'Gate 2, Shed 4');
      expect(back.officeSameAsWarehouse, isTrue);
    });

    test('separate loading and office addresses round-trip with region', () {
      const loc = LotLocation(
        warehouse: LotAddress(address: 'Godown A'),
        loadingSameAsWarehouse: false,
        loadingPoint: 'Platform 3',
        loading: LotAddress(
          address: 'Yard Road',
          stateName: 'Madhya Pradesh',
          districtName: 'Indore',
          pinCode: '452014',
        ),
        officeSameAsWarehouse: false,
        office: LotAddress(
          address: 'MG Road',
          stateName: 'Rajasthan',
          districtName: 'Jaipur',
        ),
      );
      final back = LotLocation.decode(
        warehouseText: loc.warehouseText,
        loadingText: loc.loadingRemarksText,
        officeText: loc.officeText,
        states: states,
      );
      expect(back.loadingSameAsWarehouse, isFalse);
      expect(back.loadingPoint, 'Platform 3');
      expect(back.loading.address, 'Yard Road');
      expect(back.loading.stateId, 'S-MP');
      expect(back.loading.districtName, 'Indore');
      expect(back.loading.pinCode, '452014');
      expect(back.officeSameAsWarehouse, isFalse);
      expect(back.office.address, 'MG Road');
      expect(back.office.stateId, 'S-RJ');
      expect(back.office.districtName, 'Jaipur');
    });

    test('legacy identical warehouse/loading text reads as shared', () {
      final back = LotLocation.decode(
        warehouseText: 'Krishi Upaj Mandi Yard Warehouse A-4',
        loadingText: 'Krishi Upaj Mandi Yard Warehouse A-4',
        officeText: 'Bikaner Commercial Head Office',
        states: states,
      );
      expect(back.loadingSameAsWarehouse, isTrue);
      // A distinct legacy office is kept as a separate address, not discarded.
      expect(back.officeSameAsWarehouse, isFalse);
      expect(back.office.address, 'Bikaner Commercial Head Office');
    });

    test('unparseable legacy loading text is kept as separate address', () {
      final back = LotLocation.decode(
        warehouseText: 'Godown A',
        loadingText: 'Gate 4, Krishi Upaj Mandi, Bikaner',
        officeText: null,
      );
      expect(back.loadingSameAsWarehouse, isFalse);
      expect(back.loading.address, 'Gate 4, Krishi Upaj Mandi, Bikaner');
    });
  });
}
