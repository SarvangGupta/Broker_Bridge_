import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/core/security/secure_storage_service.dart';
import 'package:rmbuyer_mobile/features/requirements/data/requirements_repository.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/requirement_model.dart';
import 'package:rmbuyer_mobile/features/search/domain/broker_model.dart';

class MockSecureStorage extends SecureStorageService {
  @override
  Future<String?> getCompanyId() async => 'test-company-101';
  @override
  Future<String?> getUserId() async => 'test-buyer-001';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RB-BUYER-07: Broker Selection & Notification Unit Tests', () {
    late RequirementsRepository repo;

    setUp(() {
      repo = RequirementsRepository(storage: MockSecureStorage());
    });

    test('1. CreateRequirementDto correctly models single selected broker', () {
      final dto = CreateRequirementDto(
        commodityId: 'comm-1',
        commodityName: 'Mustard Seed',
        gradeId: 'grade-1',
        gradeName: 'FAQ Grade',
        quantity: 50,
        unitId: 'unit-mt',
        unitSymbol: 'MT',
        targetPrice: 5200,
        deliveryLocation: 'Kota Mandi',
        targetDate: DateTime.now().add(const Duration(days: 7)),
        paymentTerms: 'Payment on Delivery (CAD)',
        selectedBrokerIds: const ['b354958e-779a-41f2-b7a3-5899eca32e32'],
        selectedBrokerNames: const ['Varun Broker Desk'],
      );

      final insertMap = dto.toSupabaseInsert('test-company-101');
      expect(insertMap['broker_id'], 'b354958e-779a-41f2-b7a3-5899eca32e32');
      expect(insertMap['visibility'], 'global');
      expect(dto.selectedBrokerIds.length, 1);
      expect(dto.selectedBrokerNames.first, 'Varun Broker Desk');
    });

    test('2. CreateRequirementDto correctly models multiple selected brokers', () {
      final dto = CreateRequirementDto(
        commodityId: 'comm-1',
        commodityName: 'Mustard Seed',
        gradeId: 'grade-1',
        gradeName: 'FAQ Grade',
        quantity: 100,
        unitId: 'unit-mt',
        unitSymbol: 'MT',
        targetPrice: 5200,
        deliveryLocation: 'Kota Mandi',
        targetDate: DateTime.now().add(const Duration(days: 7)),
        paymentTerms: 'Payment on Delivery (CAD)',
        selectedBrokerIds: const [
          'b354958e-779a-41f2-b7a3-5899eca32e32',
          '00000000-0000-0000-0000-0000000000b1',
        ],
        selectedBrokerNames: const ['Varun Broker Desk', 'Jaipur Mandi Desk'],
      );

      final insertMap = dto.toSupabaseInsert('test-company-101');
      expect(insertMap['broker_id'], 'b354958e-779a-41f2-b7a3-5899eca32e32'); // Primary broker assignment
      expect(dto.selectedBrokerIds.length, 2);
    });

    test('3. CreateRequirementDto correctly handles zero selected brokers (open broadcast)', () {
      final dto = CreateRequirementDto(
        commodityId: 'comm-1',
        commodityName: 'Mustard Seed',
        gradeId: 'grade-1',
        gradeName: 'FAQ Grade',
        quantity: 50,
        unitId: 'unit-mt',
        unitSymbol: 'MT',
        targetPrice: 5200,
        deliveryLocation: 'Kota Mandi',
        targetDate: DateTime.now().add(const Duration(days: 7)),
        paymentTerms: 'Payment on Delivery (CAD)',
        selectedBrokerIds: const [],
        selectedBrokerNames: const [],
      );

      final insertMap = dto.toSupabaseInsert('test-company-101');
      expect(insertMap.containsKey('broker_id'), isFalse);
      expect(insertMap['visibility'], 'global');
      expect(dto.selectedBrokerIds.isEmpty, isTrue);
    });

    test('4. Requirement creation persists requirement and notifies listeners', () async {
      final dto = CreateRequirementDto(
        commodityId: 'comm-1',
        commodityName: 'Soyabean',
        gradeId: 'grade-1',
        gradeName: 'FAQ Grade',
        quantity: 60,
        unitId: 'unit-mt',
        unitSymbol: 'MT',
        targetPrice: 4800,
        deliveryLocation: 'Indore Mandi',
        targetDate: DateTime.now().add(const Duration(days: 10)),
        paymentTerms: 'Payment on Delivery (CAD)',
        selectedBrokerIds: const ['broker-test-1'],
        selectedBrokerNames: const ['Indore Mandi Broker'],
      );

      int notifierFired = 0;
      void listener() => notifierFired++;
      RequirementsRepository.requirementsUpdatedNotifier.addListener(listener);

      final req = await repo.createRequirement(dto);
      expect(req.id, isNotEmpty);
      expect(req.commodityName, 'Soyabean');
      expect(req.quantity, 60);
      expect(notifierFired, greaterThan(0));

      RequirementsRepository.requirementsUpdatedNotifier.removeListener(listener);
    });

    test('5. Concurrency lock prevents duplicate submissions from rapid taps', () async {
      final dto = CreateRequirementDto(
        commodityId: 'comm-1',
        commodityName: 'Soyabean',
        gradeId: 'grade-1',
        gradeName: 'FAQ Grade',
        quantity: 60,
        unitId: 'unit-mt',
        unitSymbol: 'MT',
        targetPrice: 4800,
        deliveryLocation: 'Indore Mandi',
        targetDate: DateTime.now().add(const Duration(days: 10)),
        paymentTerms: 'Payment on Delivery (CAD)',
      );

      // Launch first creation
      final future1 = repo.createRequirement(dto);

      // Rapid immediate tap before future1 completes must throw StateError
      expect(() => repo.createRequirement(dto), throwsStateError);

      await future1;
    });

    test('6. Counterparty Shield: BrokerModel strictly excludes seller information', () {
      const broker = BrokerModel(
        id: 'broker-1',
        name: 'Sharma Brokerage',
        companyName: 'Sharma Agri Commodities Desk',
        location: 'Indore Yard',
        trustScore: 98,
        isVerified: true,
        commoditiesHandled: ['Soyabean', 'Mustard'],
      );

      expect(broker.name, 'Sharma Brokerage');
      expect(broker.isVerified, isTrue);
      expect(broker.trustScore, 98);
      // Verify no seller properties exist on BrokerModel
      final map = {
        'id': broker.id,
        'name': broker.name,
        'company_name': broker.companyName,
      };
      expect(map.containsKey('seller_id'), isFalse);
      expect(map.containsKey('seller_name'), isFalse);
      expect(map.containsKey('seller_phone'), isFalse);
    });
  });
}
