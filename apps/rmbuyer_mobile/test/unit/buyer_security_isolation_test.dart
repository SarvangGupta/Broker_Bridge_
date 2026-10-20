import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/core/config/app_config.dart';
import 'package:rmbuyer_mobile/features/deals/domain/buyer_deal_model.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/requirement_model.dart';
import 'package:rmbuyer_mobile/features/search/data/search_repository.dart';
import 'package:rmbuyer_mobile/features/search/domain/search_model.dart';

void main() {
  group('RB-BUYER-01: Counterparty Shield & Security Isolation Tests', () {
    test('Scenario 10a: BuyerDeal domain entity contains ZERO seller contact fields', () {
      final dealMap = {
        'id': 'deal-801',
        'requirement_id': 'req-201',
        'commodity_name': 'Soybean',
        'grade_name': 'Yellow Grade A',
        'agreed_quantity': 500.0,
        'unit': 'MT',
        'agreed_price': 4850.0,
        'status': 'Dispatch Pending',
        'broker_name': 'Kota Agro Brokerage',
        'created_at': '2026-10-18T10:00:00Z',
        // Attempted leakage injection
        'seller_id': 'seller-secret-999',
        'seller_phone': '+91-9876543210',
        'seller_whatsapp': '+91-9876543210',
        'seller_name': 'Confidential Farm Aggregator',
      };

      final deal = BuyerDeal.fromMap(dealMap);
      final serialized = deal.toMap();

      // Serialized buyer map must NEVER contain seller details
      expect(serialized.containsKey('seller_id'), isFalse);
      expect(serialized.containsKey('seller_phone'), isFalse);
      expect(serialized.containsKey('seller_whatsapp'), isFalse);
      expect(serialized.containsKey('seller_name'), isFalse);
      expect(serialized['broker_name'], 'Kota Agro Brokerage');
    });

    test('Scenario 10b: BuyerRequirement domain entity contains ZERO seller contact fields', () {
      final reqMap = {
        'id': 'req-501',
        'commodity_name': 'Mustard Seeds',
        'grade_name': 'High Oil 42%',
        'quantity': 250.0,
        'unit': 'MT',
        'target_price': 5400.0,
        'status': 'Open',
        'target_date': '2026-11-01T00:00:00Z',
        'broker_name': 'Jaipur Mandi Broker Desk',
        // Attempted seller injection
        'seller_id': 'seller-blocked',
        'seller_mobile': '+91-9123456780',
      };

      final req = BuyerRequirement.fromMap(reqMap);
      final serialized = req.toMap();

      expect(serialized.containsKey('seller_id'), isFalse);
      expect(serialized.containsKey('seller_mobile'), isFalse);
      expect(serialized['broker_name'], 'Jaipur Mandi Broker Desk');
    });

    test('Scenario 10c: SearchRepository filters out seller queries and categories', () async {
      final repo = SearchRepository();
      final results = await repo.search(query: 'seller');

      for (final item in results) {
        expect(
          item.category == SearchCategory.commodities ||
              item.category == SearchCategory.brokers,
          isTrue,
        );
        expect(item.title.toLowerCase().contains('seller'), isFalse);
      }
    });

    test('Scenario 11: No secrets, service-role keys, private keys, or DB passwords in AppConfig', () {
      // Supabase Anon Key is the public anon token designed for client bundles
      expect(AppConfig.supabaseUrl, isNotEmpty);
      expect(AppConfig.supabaseAnonKey, isNotEmpty);

      // Verify that service_role key is NOT present
      final anon = AppConfig.supabaseAnonKey.toLowerCase();
      expect(anon.contains('service_role'), isFalse);

      // Verify no hardcoded database connection strings (e.g. postgresql://...)
      expect(AppConfig.supabaseUrl.startsWith('https://'), isTrue);
      expect(AppConfig.supabaseUrl.contains('postgres'), isFalse);
      expect(AppConfig.supabaseUrl.contains('password'), isFalse);
    });

    test('Scenario 11b: Static repository audit confirms absence of sensitive secret patterns', () {
      final currentDir = Directory.current.path;
      final libDir = Directory('$currentDir/lib');

      if (libDir.existsSync()) {
        final dartFiles = libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));

        final prohibitedKeywords = [
          'service_role',
          'serviceRole',
          'SERVICE_ROLE_KEY',
          'SUPABASE_SERVICE_KEY',
          'BEGIN PRIVATE KEY',
          'BEGIN RSA PRIVATE KEY',
          'postgres://',
          'postgresql://',
        ];

        for (final file in dartFiles) {
          final content = file.readAsStringSync();
          for (final keyword in prohibitedKeywords) {
            expect(
              content.contains(keyword),
              isFalse,
              reason: 'File ${file.path} contains forbidden secret token: $keyword',
            );
          }
        }
      }
    });
  });
}
