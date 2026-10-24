import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/requirements/data/requirements_repository.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/requirement_model.dart';

import '../support/fake_requirements_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RB-BUYER-03: RequirementsRepository Unit Tests', () {
    test('getMasterCommodities fails loudly without a backend (no stale fallback list)', () async {
      final repo = RequirementsRepository();
      await expectLater(repo.getMasterCommodities(), throwsStateError);
    });

    test('parseActiveCommodities keeps active rows with IDs and tolerates missing optional fields', () {
      final parsed = RequirementsRepository.parseActiveCommodities(
        productMasterRows,
        categoryNames: productMasterCategories,
      );

      expect(parsed.map((c) => c.id), [dalId, riceId, wheatId, soybeanId, maizeId, soybeanDocId, maizeDdgsId]);
      expect(parsed.firstWhere((c) => c.id == dalId).code, isEmpty);
      expect(parsed.firstWhere((c) => c.id == soybeanDocId).categoryName, 'Oil Cakes & Oil Meals');
      // Without category data the name is never guessed.
      expect(
        RequirementsRepository.parseActiveCommodities(productMasterRows).first.categoryName,
        isNull,
      );
      expect(
        RequirementsRepository.parseActiveCommodities([
          {'id': '', 'name': 'No ID', 'status': true},
          {'id': 'x', 'name': 'Inactive', 'status': false},
        ]),
        isEmpty,
      );
    });

    test('getMasterGrades never invents a grade without a backend', () async {
      final repo = RequirementsRepository();
      await expectLater(repo.getMasterGrades(maizeId), throwsStateError);
    });

    test('getMasterUnits returns verified measurement units (MT, Qtl)', () async {
      final repo = RequirementsRepository();
      final units = await repo.getMasterUnits();

      expect(units, isNotEmpty);
      expect(units.any((u) => u.symbol == 'MT'), isTrue);
    });

    test('getSavedDeliveryLocations and getPaymentTermsOptions return valid business options', () async {
      final repo = RequirementsRepository();
      final locations = await repo.getSavedDeliveryLocations();
      final payments = await repo.getPaymentTermsOptions();

      expect(locations, isNotEmpty);
      expect(payments, isNotEmpty);
      expect(payments, contains('Payment on Delivery (CAD)'));
      expect(payments, contains('Advance Payment (100%)'));
    });

    test('createRequirement enforces positive quantity validation', () async {
      final repo = RequirementsRepository();
      final invalidDto = CreateRequirementDto(
        commodityId: 'comm-1',
        commodityName: 'Yellow Maize',
        gradeId: 'grade-1',
        gradeName: 'A',
        quantity: -5.0, // Invalid negative quantity
        unitId: 'unit-1',
        unitSymbol: 'MT',
        targetPrice: 2400.0,
        deliveryLocation: 'FOR Kota',
        targetDate: DateTime.now().add(const Duration(days: 10)),
        paymentTerms: 'Payment on Delivery (CAD)',
      );

      expect(() => repo.createRequirement(invalidDto), throwsArgumentError);
    });

    test('createRequirement enforces commodity selection and delivery location validation', () async {
      final repo = RequirementsRepository();
      final missingCommDto = CreateRequirementDto(
        commodityId: '   ', // Blank
        commodityName: '',
        gradeId: 'grade-1',
        gradeName: 'A',
        quantity: 50.0,
        unitId: 'unit-1',
        unitSymbol: 'MT',
        targetPrice: 2400.0,
        deliveryLocation: 'FOR Kota',
        targetDate: DateTime.now().add(const Duration(days: 10)),
        paymentTerms: 'Payment on Delivery (CAD)',
      );

      final missingLocDto = CreateRequirementDto(
        commodityId: 'comm-1',
        commodityName: 'Maize',
        gradeId: 'grade-1',
        gradeName: 'A',
        quantity: 50.0,
        unitId: 'unit-1',
        unitSymbol: 'MT',
        targetPrice: 2400.0,
        deliveryLocation: '   ', // Blank
        targetDate: DateTime.now().add(const Duration(days: 10)),
        paymentTerms: 'Payment on Delivery (CAD)',
      );

      expect(() => repo.createRequirement(missingCommDto), throwsArgumentError);
      expect(() => repo.createRequirement(missingLocDto), throwsArgumentError);
    });

    test('createRequirement creates authoritative requirement and adds to session listing', () async {
      final repo = RequirementsRepository();
      final dto = CreateRequirementDto(
        commodityId: '20000000-0000-0000-0000-000000000001',
        commodityName: 'Yellow Maize (Corn)',
        gradeId: '21000000-0000-0000-0000-000000000001',
        gradeName: 'Grade A Milling',
        quantity: 75.0,
        unitId: '22000000-0000-0000-0000-000000000001',
        unitSymbol: 'MT',
        targetPrice: 2320.0,
        deliveryLocation: 'FOR Mill Delivery, Kota Mandi',
        targetDate: DateTime.now().add(const Duration(days: 14)),
        paymentTerms: 'Payment on Delivery (CAD)',
        brokerId: 'b354958e-779a-41f2-b7a3-5899eca32e32',
        brokerName: 'Jaipur Grain Broker Desk',
      );

      final created = await repo.createRequirement(dto);

      expect(created, isNotNull);
      expect(created.id, isNotEmpty);
      expect(created.commodityName, 'Yellow Maize (Corn)');
      expect(created.quantity, 75.0);
      expect(created.unit, 'MT');
      expect(created.status, 'Open');
      expect(created.canCancel, isTrue);
      expect(created.brokerName, 'Jaipur Grain Broker Desk');

      // Verify immediate reflection in getRequirements
      final all = await repo.getRequirements();
      expect(all.any((r) => r.id == created.id), isTrue);

      // Verify retrieval by id
      final fetched = await repo.getRequirementById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.id, created.id);
    });

    test('cancelRequirement cancels open requirement but rejects short reason', () async {
      final repo = RequirementsRepository();
      final dto = CreateRequirementDto(
        commodityId: '20000000-0000-0000-0000-000000000002',
        commodityName: 'Sharbati Wheat',
        gradeId: '21000000-0000-0000-0000-000000000003',
        gradeName: 'Premium Sharbati',
        quantity: 100.0,
        unitId: '22000000-0000-0000-0000-000000000001',
        unitSymbol: 'MT',
        targetPrice: 2800.0,
        deliveryLocation: 'Ex-Warehouse Jaipur Central Depot',
        targetDate: DateTime.now().add(const Duration(days: 10)),
        paymentTerms: '15 Days Net Credit',
      );

      final created = await repo.createRequirement(dto);

      // Reject empty or short reason
      expect(() => repo.cancelRequirement(created.id, reason: 'no'), throwsArgumentError);

      // Successful cancellation with valid reason
      final success = await repo.cancelRequirement(
        created.id,
        reason: 'Procurement demand fulfilled through Kota Mandi',
      );
      expect(success, isTrue);

      final cancelled = await repo.getRequirementById(created.id);
      expect(cancelled!.status, 'Cancelled');
      expect(cancelled.canCancel, isFalse);
    });

    test('getRequirements filters accurately by status', () async {
      final repo = RequirementsRepository();

      final openList = await repo.getRequirements(statusFilter: 'Open');
      final fulfilledList = await repo.getRequirements(statusFilter: 'Fulfilled');

      for (final r in openList) {
        expect(r.status.toLowerCase(), 'open');
      }
      for (final r in fulfilledList) {
        expect(r.status.toLowerCase(), 'fulfilled');
      }
    });

    test('notifyRequirementBrokers rejects invalid non-UUID identifiers safely', () async {
      final repo = RequirementsRepository();

      // Passing invalid IDs (like broker-101) must be rejected and return 0
      final notifiedCount = await repo.notifyRequirementBrokers(
        requirementId: 'REQ-12345678',
        brokerIds: ['broker-101', 'invalid-id', ''],
      );

      expect(notifiedCount, 0);
    });

    test('notifyRequirementBrokers handles empty broker selection cleanly', () async {
      final repo = RequirementsRepository();

      final notifiedCount = await repo.notifyRequirementBrokers(
        requirementId: 'REQ-12345678',
        brokerIds: [],
      );

      expect(notifiedCount, 0);
    });
  });
}
