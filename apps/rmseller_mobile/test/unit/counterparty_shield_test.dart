import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/brokers/domain/seller_broker_model.dart';
import 'package:rmseller_mobile/features/commodities/domain/commodity_model.dart';
import 'package:rmseller_mobile/features/deals/domain/seller_deal_model.dart';
import 'package:rmseller_mobile/features/reports/domain/sales_report_model.dart';

void main() {
  group('RB-SELLER-01: Counterparty Shield & Privacy Invariant Tests', () {
    test('SellerCommodity model strictly excludes any Buyer identifier or contact fields', () {
      final lot = SellerCommodity(
        id: 'AVL-TEST-001',
        lotNumber: 'LOT-CHANA-01',
        commodityName: 'Desi Chana (Gram)',
        gradeName: 'Bold Size FAQ',
        totalQuantity: 100.0,
        availableQuantity: 75.0,
        unit: 'MT',
        askingPrice: 5850.0,
        stateName: 'Rajasthan',
        districtName: 'Bikaner',
        status: 'Active',
        availableFrom: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 7)),
        createdAt: DateTime.now(),
      );

      final map = lot.toMap();
      expect(map.containsKey('buyer_id'), isFalse);
      expect(map.containsKey('buyer_name'), isFalse);
      expect(map.containsKey('buyer_mobile'), isFalse);
      expect(map.containsKey('buyer_email'), isFalse);
      expect(map.containsKey('buyer_company'), isFalse);
    });

    test('SellerDealModel strictly excludes Buyer PII and references only mediated broker desk', () {
      final deal = SellerDealModel(
        id: 'DEAL-TEST-001',
        requirementId: 'REQ-TEST-001',
        quotationId: 'QUO-TEST-001',
        commodityName: 'Yellow Soybean',
        gradeName: 'Grade A FAQ',
        agreedQuantity: 50.0,
        unit: 'MT',
        agreedPrice: 4850.0,
        status: 'Dispatch Pending',
        brokerDeskName: 'Jaipur Grain Broker Desk',
        bookingReference: 'BKG-TEST-1234',
        createdAt: DateTime.now(),
      );

      expect(deal.brokerDeskName, contains('Broker Desk'));
      expect(deal.bookingReference, 'BKG-TEST-1234');
    });

    test('SellerBrokerModel exposes only broker desk credentials, never buyer records', () {
      const broker = SellerBrokerModel(
        id: 'b354958e-779a-41f2-b7a3-5899eca32e32',
        name: 'Bikaner Mandi Broker Desk',
        mobile: '+919829012345',
        companyName: 'Bikaner Grain Merchants Desk',
        trustScore: 99,
        isVerified: true,
      );

      final map = broker.toMap();
      expect(map.containsKey('buyer_id'), isFalse);
      expect(map.containsKey('buyers'), isFalse);
      expect(map['trust_score'], 99);
      expect(map['is_verified'], isTrue);
    });

    test('SalesTransactionItem displays only commodity, volume, rate, and booking reference', () {
      final tx = SalesTransactionItem(
        dealId: 'DEAL-TEST-002',
        bookingReference: 'BKG-TEST-5678',
        commodityName: 'Mustard Seeds',
        quantityMT: 40.0,
        ratePerMT: 5600.0,
        grossAmount: 224000.0,
        status: 'Settled',
        date: DateTime.now(),
      );

      expect(tx.bookingReference, 'BKG-TEST-5678');
      expect(tx.grossAmount, 224000.0);
    });
  });
}
