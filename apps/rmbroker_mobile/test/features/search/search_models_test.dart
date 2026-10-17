import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/search/domain/search_result.dart';

void main() {
  group('Search Domain Models & Entities Tests', () {
    test('SearchEntityType parses strings and labels correctly', () {
      expect(SearchEntityType.fromString('all'), SearchEntityType.all);
      expect(SearchEntityType.fromString('contacts'), SearchEntityType.contacts);
      expect(SearchEntityType.fromString('materials'), SearchEntityType.materials);
      expect(SearchEntityType.fromString('requirements'), SearchEntityType.requirements);
      expect(SearchEntityType.fromString('offers'), SearchEntityType.offers);
      expect(SearchEntityType.fromString('deals'), SearchEntityType.deals);
      expect(SearchEntityType.fromString('unknown'), SearchEntityType.all);
      expect(SearchEntityType.fromString(null), SearchEntityType.all);
    });

    test('SearchContactItem parses JSON and generates valid E.164 phone and URIs', () {
      final json = {
        'id': 'contact-001',
        'userId': 'user-101',
        'name': 'Ramesh Kumar Agarwal',
        'companyName': 'Agarwal Oil Mills Pvt Ltd',
        'role': 'Buyer',
        'mobile': '9829012345',
        'city': 'Jaipur Mandi',
        'status': true,
        'isVerified': true,
        'url': '/directory?contactId=contact-001',
      };

      final contact = SearchContactItem.fromJson(json);

      expect(contact.id, 'contact-001');
      expect(contact.name, 'Ramesh Kumar Agarwal');
      expect(contact.companyName, 'Agarwal Oil Mills Pvt Ltd');
      expect(contact.isBuyer, isTrue);
      expect(contact.isSeller, isFalse);
      expect(contact.mobile, '+919829012345');
      expect(contact.formattedMobile, '+91 98290 12345');
      expect(contact.telUri, 'tel:+919829012345');
      expect(contact.whatsappUri, 'https://wa.me/919829012345');
      expect(contact.isVerified, isTrue);
    });

    test('SearchMaterialItem, Requirement, Offer, and Deal parse JSON accurately', () {
      final matJson = {
        'id': 'mat-001',
        'name': 'Soyabean Seed',
        'code': 'SOYA-01',
        'categoryName': 'Oilseeds',
        'grades': ['FAQ', 'Grade 1', 'Premium Yellow'],
      };
      final mat = SearchMaterialItem.fromJson(matJson);
      expect(mat.name, 'Soyabean Seed');
      expect(mat.code, 'SOYA-01');
      expect(mat.grades.length, 3);

      final reqJson = {
        'id': 'req-001',
        'commodityName': 'Mustard Seed',
        'quantity': 100.0,
        'unitSymbol': 'MT',
        'targetPrice': 5450.0,
        'buyerCompanyName': 'Marwar Agro Mills',
        'status': 'OPEN',
      };
      final req = SearchRequirementItem.fromJson(reqJson);
      expect(req.commodityName, 'Mustard Seed');
      expect(req.quantity, 100.0);
      expect(req.targetPrice, 5450.0);

      final offerJson = {
        'id': 'offer-001',
        'lotNumber': 'LOT-782',
        'commodityName': 'Yellow Peas',
        'availableQuantity': 50.0,
        'unitSymbol': 'MT',
        'askingPrice': 3800.0,
        'sellerCompanyName': 'Kota Farmer FPO',
        'status': 'ACTIVE',
      };
      final offer = SearchOfferItem.fromJson(offerJson);
      expect(offer.lotNumber, 'LOT-782');
      expect(offer.askingPrice, 3800.0);

      final dealJson = {
        'id': 'deal-001',
        'dealRef': 'DEAL-9988',
        'commodityName': 'Milling Wheat',
        'agreedQuantity': 200.0,
        'agreedPrice': 2400.0,
        'buyerName': 'Delhi Flour Mills',
        'sellerName': 'Punjab Grain Logistics',
        'status': 'CONFIRMED',
        'createdAt': '2026-10-17T12:00:00Z',
      };
      final deal = SearchDealItem.fromJson(dealJson);
      expect(deal.dealRef, 'DEAL-9988');
      expect(deal.status, 'CONFIRMED');
    });

    test('GlobalSearchResults aggregates and calculates counts correctly', () {
      final results = GlobalSearchResults(
        contacts: [
          SearchContactItem(
            id: 'c1',
            userId: 'u1',
            name: 'Buyer One',
            companyName: 'Firm A',
            role: 'Buyer',
            mobile: '+919876543210',
            formattedMobile: '+91 98765 43210',
          ),
        ],
        materials: [
          SearchMaterialItem(id: 'm1', name: 'Mustard Seed'),
          SearchMaterialItem(id: 'm2', name: 'Soyabean'),
        ],
        requirements: [
          SearchRequirementItem(
            id: 'r1',
            commodityName: 'Mustard',
            quantity: 50,
            unitSymbol: 'MT',
            targetPrice: 5000,
            buyerCompanyName: 'Firm A',
            status: 'OPEN',
          ),
        ],
        offers: [],
        deals: [
          SearchDealItem(
            id: 'd1',
            dealRef: 'DEAL-01',
            commodityName: 'Mustard',
            agreedQuantity: 50,
            agreedPrice: 5000,
            buyerName: 'Buyer One',
            sellerName: 'Seller One',
            status: 'DONE',
            createdAt: '2026-10-17',
          ),
        ],
        totalCount: 5,
      );

      final counts = SearchCounts.fromResults(results);
      expect(counts.all, 5);
      expect(counts.contacts, 1);
      expect(counts.materials, 2);
      expect(counts.requirements, 1);
      expect(counts.offers, 0);
      expect(counts.deals, 1);
    });

    test('QuickDialContactItem parses and normalizes contact details', () {
      final json = {
        'id': 'qd-1',
        'name': 'Sunil Mittal',
        'companyName': 'Mittal Agro Jaipur',
        'role': 'Seller',
        'mobile': '09829123456',
        'isVerified': true,
      };

      final qd = QuickDialContactItem.fromJson(json);
      expect(qd.isSeller, isTrue);
      expect(qd.mobile, '+919829123456');
      expect(qd.telUri, 'tel:+919829123456');
      expect(qd.whatsappUri, 'https://wa.me/919829123456');
      expect(qd.isVerified, isTrue);
    });
  });
}
