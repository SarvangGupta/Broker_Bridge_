import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/features/authentication/domain/seller_user.dart';

void main() {
  group('RB-SELLER-01: SellerUser Domain Entity Tests', () {
    test('SellerUser instantiates properly and computes admin privileges correctly', () {
      const seller = SellerUser(
        id: '20000000-0000-0000-0000-000000000001',
        email: 'lead@bikaneragro.in',
        fullName: 'Bikaner Agro Lead',
        role: 'seller',
        companyId: '20000000-0000-0000-0000-000000000101',
        companyName: 'Bikaner Agro Traders Ltd',
        trustScore: 98,
        isVerified: true,
      );

      expect(seller.id, '20000000-0000-0000-0000-000000000001');
      expect(seller.isSellerAdmin, isFalse);
      expect(seller.hasVerifiedCompany, isTrue);

      const adminUser = SellerUser(
        id: '99999999-0000-0000-0000-000000000001',
        email: 'admin@brokerbridge.in',
        fullName: 'Platform Super Admin',
        role: 'admin',
      );
      expect(adminUser.isSellerAdmin, isTrue);
    });

    test('SellerUser serializes to and from Map without data loss', () {
      final map = {
        'id': '20000000-0000-0000-0000-000000000002',
        'email': 'seller2@mandi.in',
        'name': 'Malwa Agro Lead',
        'role': 'seller',
        'company_id': '20000000-0000-0000-0000-000000000102',
        'company_name': 'Malwa Agro Corp',
        'company_gst': '23AAAAA1234A1Z9',
        'trust_score': 95,
        'is_verified': true,
      };

      final user = SellerUser.fromMap(map);
      expect(user.fullName, 'Malwa Agro Lead');
      expect(user.companyGst, '23AAAAA1234A1Z9');
      expect(user.trustScore, 95);

      final serialized = user.toMap();
      expect(serialized['company_name'], 'Malwa Agro Corp');
      expect(serialized['trust_score'], 95);
    });
  });
}
