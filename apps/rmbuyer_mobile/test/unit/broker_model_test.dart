import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/search/domain/broker_model.dart';

void main() {
  group('RB-BUYER-02: BrokerModel Domain Entity Tests', () {
    test('Constructs BrokerModel with authorized defaults and checks phone availability', () {
      const broker = BrokerModel(
        id: 'broker-1',
        name: 'Rajesh Verma',
        email: 'rajesh@jaipurmandi.com',
        mobile: '+919829012345',
        companyName: 'Jaipur Grain Broker Desk',
        companyGst: '08AAACJ1234A1Z1',
        location: 'Jaipur Mandi, Rajasthan',
        trustScore: 98,
        isVerified: true,
        commoditiesHandled: ['Soybean', 'Chana'],
      );

      expect(broker.id, 'broker-1');
      expect(broker.name, 'Rajesh Verma');
      expect(broker.hasPhone, isTrue);
      expect(broker.hasWhatsApp, isTrue);
      expect(broker.trustScore, 98);
      expect(broker.isVerified, isTrue);
      expect(broker.commoditiesHandled.length, 2);
    });

    test('hasPhone and hasWhatsApp return false when mobile is null or empty', () {
      const brokerNoPhone = BrokerModel(
        id: 'broker-no-phone',
        name: 'Desk Without Direct Contact',
        mobile: null,
      );
      const brokerEmptyPhone = BrokerModel(
        id: 'broker-empty',
        name: 'Desk With Whitespace Phone',
        mobile: '   ',
      );

      expect(brokerNoPhone.hasPhone, isFalse);
      expect(brokerNoPhone.hasWhatsApp, isFalse);
      expect(brokerEmptyPhone.hasPhone, isFalse);
      expect(brokerEmptyPhone.hasWhatsApp, isFalse);
    });

    test('fromMap parses embedded company details and CSV commodities correctly', () {
      final map = {
        'id': 'broker-505',
        'name': 'Nilesh Sharma',
        'mobile': '+919826098765',
        'email': 'nilesh@indoremandi.com',
        'mandi': 'Indore Mandi, Madhya Pradesh',
        'commodities': 'Yellow Soybean, Wheat, Maize',
        'companies': {
          'id': 'comp-505',
          'name': 'Indore Mandi Associates',
          'gst': '23AABCI5678B1Z2',
          'trust_score': 95,
          'is_verified': true,
        },
      };

      final broker = BrokerModel.fromMap(map);

      expect(broker.id, 'broker-505');
      expect(broker.name, 'Nilesh Sharma');
      expect(broker.companyName, 'Indore Mandi Associates');
      expect(broker.companyGst, '23AABCI5678B1Z2');
      expect(broker.location, 'Indore Mandi, Madhya Pradesh');
      expect(broker.trustScore, 95);
      expect(broker.isVerified, isTrue);
      expect(broker.commoditiesHandled, ['Yellow Soybean', 'Wheat', 'Maize']);
    });

    test('Strict Counterparty Isolation: Serialized map contains ZERO seller fields', () {
      const broker = BrokerModel(
        id: 'broker-safe',
        name: 'Mandi Broker Desk',
        mobile: '+919829012345',
        companyName: 'Jaipur Grain Broker Desk',
        location: 'Jaipur Mandi',
        trustScore: 98,
        isVerified: true,
      );

      final map = broker.toMap();

      expect(map.containsKey('seller_id'), isFalse);
      expect(map.containsKey('seller_name'), isFalse);
      expect(map.containsKey('seller_phone'), isFalse);
      expect(map.containsKey('seller_whatsapp'), isFalse);
    });
  });
}
