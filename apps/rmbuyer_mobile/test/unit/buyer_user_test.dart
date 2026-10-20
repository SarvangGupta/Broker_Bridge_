import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/authentication/domain/buyer_user.dart';

void main() {
  group('BuyerUser Domain Entity Tests', () {
    test('isBuyerOrAdmin identifies authorized roles correctly and rejects sellers/brokers', () {
      const buyer = BuyerUser(
        id: 'usr-1',
        email: 'buyer@apexprocurement.com',
        fullName: 'Rajesh Singhal',
        role: 'buyer',
      );
      const admin = BuyerUser(
        id: 'usr-2',
        email: 'admin@brokerbridge.com',
        fullName: 'System Administrator',
        role: 'Admin',
      );
      const broker = BuyerUser(
        id: 'usr-3',
        email: 'broker@jaipurmandi.com',
        fullName: 'Nilesh Sharma',
        role: 'broker',
      );
      const seller = BuyerUser(
        id: 'usr-4',
        email: 'seller@agrofarms.com',
        fullName: 'Suresh Patel',
        role: 'seller',
      );
      const unassigned = BuyerUser(
        id: 'usr-5',
        email: 'user@unknown.com',
        fullName: 'Unassigned User',
        role: '',
      );

      expect(buyer.isBuyerOrAdmin, isTrue);
      expect(admin.isBuyerOrAdmin, isTrue);
      expect(broker.isBuyerOrAdmin, isFalse);
      expect(seller.isBuyerOrAdmin, isFalse);
      expect(unassigned.isBuyerOrAdmin, isFalse);
    });

    test('fromMap and toMap serialize and deserialize cleanly', () {
      final map = {
        'id': 'usr-100',
        'email': 'procurement@apexgrain.com',
        'full_name': 'Rajesh Singhal',
        'role': 'buyer',
        'company_id': 'comp-50',
        'company_name': 'Apex Grain Processors Pvt Ltd',
        'gst': '08AABCA1234F1Z8',
      };

      final user = BuyerUser.fromMap(map);
      expect(user.id, 'usr-100');
      expect(user.email, 'procurement@apexgrain.com');
      expect(user.fullName, 'Rajesh Singhal');
      expect(user.role, 'buyer');
      expect(user.companyId, 'comp-50');
      expect(user.companyName, 'Apex Grain Processors Pvt Ltd');
      expect(user.companyGst, '08AABCA1234F1Z8');

      final serialized = user.toMap();
      expect(serialized['role'], 'buyer');
      expect(serialized['id'], 'usr-100');
    });
  });
}
