import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/deals/domain/deal_model.dart';

void main() {
  group('Deal Domain Model Tests (Sprint RB-FL-08)', () {
    test('DealStatus parses all backend lifecycle states correctly', () {
      expect(DealStatus.fromString('Draft'), DealStatus.draft);
      expect(DealStatus.fromString('Negotiation'), DealStatus.negotiation);
      expect(
        DealStatus.fromString('Awaiting Buyer Confirmation'),
        DealStatus.awaitingBuyerConfirmation,
      );
      expect(
        DealStatus.fromString('Awaiting Seller Confirmation'),
        DealStatus.awaitingSellerConfirmation,
      );
      expect(DealStatus.fromString('Ready to Finalize'), DealStatus.readyToFinalize);
      expect(DealStatus.fromString('Finalized'), DealStatus.finalized);
      expect(DealStatus.fromString('In Fulfillment'), DealStatus.inFulfillment);
      expect(DealStatus.fromString('Dispatch Pending'), DealStatus.inFulfillment);
      expect(DealStatus.fromString('Completed'), DealStatus.completed);
      expect(DealStatus.fromString('Cancelled'), DealStatus.cancelled);
      expect(DealStatus.fromString('Disputed'), DealStatus.disputed);
      expect(DealStatus.fromString(null), DealStatus.draft);
    });

    test('DealConfirmationState enforces dual-party confirmation before finalization', () {
      // 1. Neither confirmed
      const unconfirmed = DealConfirmationState(
        latestVersionNumber: 1,
        buyerConfirmed: false,
        sellerConfirmed: false,
        canFinalize: false,
      );
      expect(unconfirmed.canFinalize, isFalse);

      // 2. Only buyer confirmed -> CANNOT finalize
      const buyerOnly = DealConfirmationState(
        latestVersionNumber: 1,
        buyerConfirmed: true,
        sellerConfirmed: false,
        canFinalize: false,
      );
      expect(buyerOnly.canFinalize, isFalse);

      // 3. Only seller confirmed -> CANNOT finalize
      const sellerOnly = DealConfirmationState(
        latestVersionNumber: 1,
        buyerConfirmed: false,
        sellerConfirmed: true,
        canFinalize: false,
      );
      expect(sellerOnly.canFinalize, isFalse);

      // 4. BOTH confirmed -> CAN finalize
      const bothConfirmed = DealConfirmationState(
        latestVersionNumber: 1,
        buyerConfirmed: true,
        sellerConfirmed: true,
        canFinalize: true,
      );
      expect(bothConfirmed.canFinalize, isTrue);
    });

    test('DealItem parses from backend JSON correctly', () {
      final json = {
        'id': 'deal-uuid-001',
        'bookingReference': 'DL-2026-089',
        'quotationId': 'quote-001',
        'requirementId': 'req-001',
        'allocationId': 'alloc-001',
        'allocationReference': 'ALC-2026-0042',
        'commodityName': 'Mustard Seed Premium',
        'gradeName': 'Grade 1 (42% Oil Content)',
        'buyerCompanyId': 'buyer-co-1',
        'buyerCompanyName': 'Patanjali Agro Industries',
        'sellerCompanyId': 'seller-co-2',
        'sellerCompanyName': 'Bharat Mandi Aggregators',
        'agreedQuantity': 50.0,
        'unitSymbol': 'MT',
        'agreedPrice': 54000.0,
        'totalValuation': 2700000.0,
        'priceBasis': 'FOR_DESTINATION',
        'deliveryLocation': 'Alwar Warehouse, Rajasthan',
        'deliveryDate': '2026-10-25',
        'status': 'Negotiation',
        'latestVersionNumber': 2,
        'buyerConfirmed': true,
        'sellerConfirmed': false,
        'createdAt': '2026-10-17T10:00:00Z',
      };

      final deal = DealItem.fromJson(json);

      expect(deal.id, 'deal-uuid-001');
      expect(deal.ref, 'DL-2026-089');
      expect(deal.commodityName, 'Mustard Seed Premium');
      expect(deal.gradeName, 'Grade 1 (42% Oil Content)');
      expect(deal.buyerCompanyName, 'Patanjali Agro Industries');
      expect(deal.sellerCompanyName, 'Bharat Mandi Aggregators');
      expect(deal.agreedQuantity, 50.0);
      expect(deal.formattedQuantity, '50 MT');
      expect(deal.agreedPrice, 54000.0);
      expect(deal.totalValuation, 2700000.0);
      expect(deal.status, DealStatus.negotiation);
      expect(deal.latestVersionNumber, 2);
      expect(deal.buyerConfirmed, isTrue);
      expect(deal.sellerConfirmed, isFalse);
    });

    test('DealDetailItem parses with contract terms and confirmation audit', () {
      final json = {
        'summary': {
          'id': 'deal-uuid-002',
          'bookingReference': 'DL-2026-090',
          'quotationId': 'quote-002',
          'requirementId': 'req-002',
          'commodityName': 'Soybean Bold',
          'buyerCompanyId': 'buyer-02',
          'buyerCompanyName': 'Ruchi Soya Enterprises',
          'sellerCompanyId': 'seller-02',
          'sellerCompanyName': 'Indore Grain Logistics',
          'agreedQuantity': 100.0,
          'unitSymbol': 'MT',
          'agreedPrice': 46500.0,
          'totalValuation': 4650000.0,
          'priceBasis': 'FOR_DESTINATION',
          'status': 'Ready to Finalize',
          'createdAt': '2026-10-17T11:00:00Z',
        },
        'confirmations': {
          'latestVersionNumber': 1,
          'buyerConfirmed': true,
          'buyerConfirmedAt': '2026-10-17T11:30:00Z',
          'sellerConfirmed': true,
          'sellerConfirmedAt': '2026-10-17T11:45:00Z',
          'canFinalize': true,
        },
        'deliveryTerms': 'FOR Destination Mandi Silo',
        'paymentTerms': '100% Advance against Lorry Receipt & Weight Slip',
        'packagingType': '50kg Standard HDPE Bags',
        'brokerCommissionRate': 50.0,
        'commissionBasis': '₹/MT',
        'notes': 'Quality inspection at destination weighbridge',
      };

      final detail = DealDetailItem.fromJson(json);

      expect(detail.deal.ref, 'DL-2026-090');
      expect(detail.deal.commodityName, 'Soybean Bold');
      expect(detail.confirmations.buyerConfirmed, isTrue);
      expect(detail.confirmations.sellerConfirmed, isTrue);
      expect(detail.confirmations.canFinalize, isTrue);
      expect(detail.deliveryTerms, 'FOR Destination Mandi Silo');
      expect(detail.paymentTerms, '100% Advance against Lorry Receipt & Weight Slip');
      expect(detail.brokerCommissionRate, 50.0);
    });

    test('CreateDealDto validates required contract fields', () {
      final validDto = CreateDealDto(
        allocationId: 'alloc-001',
        agreedPrice: 50000.0,
        agreedQuantity: 30.0,
        deliveryLocation: 'Kota Mandi, Rajasthan',
        deliveryDate: DateTime.now().add(const Duration(days: 5)),
      );
      expect(validDto.validate(), isNull);

      final missingAllocDto = CreateDealDto(
        allocationId: '',
        agreedPrice: 50000.0,
        agreedQuantity: 30.0,
        deliveryLocation: 'Kota Mandi, Rajasthan',
        deliveryDate: DateTime.now().add(const Duration(days: 5)),
      );
      expect(missingAllocDto.validate(), contains('allocation reference is required'));

      final invalidPriceDto = CreateDealDto(
        allocationId: 'alloc-001',
        agreedPrice: 0.0,
        agreedQuantity: 30.0,
        deliveryLocation: 'Kota Mandi, Rajasthan',
        deliveryDate: DateTime.now().add(const Duration(days: 5)),
      );
      expect(invalidPriceDto.validate(), contains('Agreed price must be greater than zero'));
    });
  });
}
