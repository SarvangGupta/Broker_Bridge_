import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/profile/domain/company_warehouse.dart';

/// Simulates the database trigger logic from `trg_notify_warehouse_change()`
/// to verify notification generation rules, relationship filters, tenant isolation,
/// Google Maps URL generation, and idempotency.
class MockBrokerUser {
  final String id;
  final String companyId;
  final bool status; // active/inactive
  const MockBrokerUser({
    required this.id,
    required this.companyId,
    this.status = true,
  });
}

class MockCrmContact {
  final String brokerId;
  final String companyId;
  const MockCrmContact({required this.brokerId, required this.companyId});
}

class MockDeal {
  final String brokerId;
  final String buyerUserId;
  final String buyerCompanyId;
  const MockDeal({
    required this.brokerId,
    required this.buyerUserId,
    required this.buyerCompanyId,
  });
}

class DispatchedNotification {
  final String userId;
  final String companyId;
  final String channel;
  final String eventType;
  final String title;
  final String message;
  final String idempotencyKey;
  final Map<String, dynamic> payload;

  const DispatchedNotification({
    required this.userId,
    required this.companyId,
    required this.channel,
    required this.eventType,
    required this.title,
    required this.message,
    required this.idempotencyKey,
    required this.payload,
  });
}

class WarehouseTriggerSimulator {
  final List<MockBrokerUser> brokers;
  final List<MockCrmContact> crmContacts;
  final List<MockDeal> deals;
  final Map<String, String> companyNames;

  WarehouseTriggerSimulator({
    required this.brokers,
    required this.crmContacts,
    required this.deals,
    required this.companyNames,
  });

  List<DispatchedNotification> onWarehouseChange({
    CompanyWarehouse? oldRecord,
    required CompanyWarehouse newRecord,
  }) {
    String changeType;
    if (oldRecord == null) {
      changeType = 'CREATED';
    } else if (oldRecord.isActive && !newRecord.isActive) {
      changeType = 'DEACTIVATED';
    } else if (!oldRecord.isActive && newRecord.isActive) {
      changeType = 'ACTIVATED';
    } else if (oldRecord.name == newRecord.name &&
        oldRecord.addressLine == newRecord.addressLine &&
        oldRecord.pinCode == newRecord.pinCode &&
        oldRecord.unloadingNotes == newRecord.unloadingNotes &&
        oldRecord.contactPerson == newRecord.contactPerson &&
        oldRecord.contactPhone == newRecord.contactPhone &&
        oldRecord.latitude == newRecord.latitude &&
        oldRecord.longitude == newRecord.longitude) {
      return []; // No-op update
    } else if (oldRecord.name == newRecord.name &&
        oldRecord.addressLine == newRecord.addressLine &&
        oldRecord.pinCode == newRecord.pinCode &&
        (oldRecord.latitude != newRecord.latitude ||
            oldRecord.longitude != newRecord.longitude)) {
      changeType = 'LOCATION_UPDATED';
    } else if ((oldRecord.name != newRecord.name ||
            oldRecord.addressLine != newRecord.addressLine ||
            oldRecord.pinCode != newRecord.pinCode) &&
        oldRecord.latitude == newRecord.latitude &&
        oldRecord.longitude == newRecord.longitude) {
      changeType = 'ADDRESS_UPDATED';
    } else {
      changeType = 'UPDATED';
    }

    final companyName = companyNames[newRecord.companyId] ?? 'Buyer';
    final title = 'Warehouse Update: $companyName';
    final String message;
    if (changeType == 'CREATED') {
      message = '$companyName added a new warehouse/unloading location: ${newRecord.name} (${newRecord.addressLine}).';
    } else if (changeType == 'DEACTIVATED') {
      message = '$companyName deactivated unloading location: ${newRecord.name}.';
    } else if (changeType == 'LOCATION_UPDATED') {
      message = '$companyName updated GPS unloading coordinates for: ${newRecord.name} (${newRecord.addressLine}). Google Maps link attached.';
    } else if (changeType == 'ADDRESS_UPDATED') {
      message = '$companyName updated unloading address for: ${newRecord.name} (${newRecord.addressLine}).';
    } else {
      message = '$companyName updated unloading location: ${newRecord.name} (${newRecord.addressLine}).';
    }

    // Generate Google Maps URL only from authoritative saved coordinates
    final String? mapsUrl = (newRecord.latitude != null && newRecord.longitude != null)
        ? 'https://www.google.com/maps/search/?api=1&query=${newRecord.latitude}%2C${newRecord.longitude}'
        : null;

    // Filter target brokers: role broker, active status, and relationship via CRM or Deal
    final eligibleBrokers = brokers.where((b) {
      if (!b.status) return false;
      final hasCrm = crmContacts.any(
        (c) => c.brokerId == b.id && c.companyId == newRecord.companyId,
      );
      final hasDeal = deals.any(
        (d) => d.brokerId == b.id && d.buyerCompanyId == newRecord.companyId,
      );
      return hasCrm || hasDeal;
    }).toList();

    final notifications = <DispatchedNotification>[];
    for (final b in eligibleBrokers) {
      final idem =
          'wh-${newRecord.id}-$changeType-${newRecord.updatedAt.millisecondsSinceEpoch ~/ 1000}-${b.id}';
      notifications.add(
        DispatchedNotification(
          userId: b.id,
          companyId: b.companyId,
          channel: 'IN_APP',
          eventType: 'WAREHOUSE_UPDATED',
          title: title,
          message: message,
          idempotencyKey: idem,
          payload: {
            'companyId': newRecord.companyId,
            'warehouseId': newRecord.id,
            'warehouseName': newRecord.name,
            'address': newRecord.addressLine,
            'pinCode': newRecord.pinCode,
            'latitude': newRecord.latitude,
            'longitude': newRecord.longitude,
            'gpsAccuracy': newRecord.gpsAccuracy,
            'googleMapsUrl': mapsUrl,
            'changeType': changeType,
            'updatedAt': newRecord.updatedAt.toIso8601String(),
          },
        ),
      );
    }
    return notifications;
  }
}

void main() {
  group('Warehouse Broker Notification Trigger Logic', () {
    const buyerCompanyId = 'company-buyer-101';
    const unrelatedCompanyId = 'company-buyer-999';

    final broker1 = const MockBrokerUser(id: 'broker-1', companyId: 'brokerage-1', status: true);
    final broker2 = const MockBrokerUser(id: 'broker-2', companyId: 'brokerage-2', status: true);
    final brokerInactive = const MockBrokerUser(id: 'broker-3', companyId: 'brokerage-3', status: false);
    final brokerUnrelated = const MockBrokerUser(id: 'broker-4', companyId: 'brokerage-4', status: true);

    final simulator = WarehouseTriggerSimulator(
      brokers: [broker1, broker2, brokerInactive, brokerUnrelated],
      crmContacts: [
        const MockCrmContact(brokerId: 'broker-1', companyId: buyerCompanyId),
      ],
      deals: [
        const MockDeal(
          brokerId: 'broker-2',
          buyerUserId: 'buyer-user-1',
          buyerCompanyId: buyerCompanyId,
        ),
        const MockDeal(
          brokerId: 'broker-3',
          buyerUserId: 'buyer-user-1',
          buyerCompanyId: buyerCompanyId,
        ),
        const MockDeal(
          brokerId: 'broker-4',
          buyerUserId: 'other-user',
          buyerCompanyId: unrelatedCompanyId,
        ),
      ],
      companyNames: {
        buyerCompanyId: 'Apex Commodities Ltd',
      },
    );

    test('10. notifies only authorized brokers with verified active relationships', () {
      final now = DateTime.now();
      final wh = CompanyWarehouse(
        id: 'wh-abc-123',
        companyId: buyerCompanyId,
        createdBy: 'buyer-user-1',
        name: 'Mandi Gate Silo',
        addressLine: 'Plot 5, New Mandi Area',
        latitude: 25.1825,
        longitude: 75.8398,
        createdAt: now,
        updatedAt: now,
      );

      final notifs = simulator.onWarehouseChange(newRecord: wh);

      // broker1 (CRM) and broker2 (Deal) should be notified
      // brokerInactive (inactive) and brokerUnrelated (different company) MUST NOT be notified
      expect(notifs.length, 2);
      final recipientIds = notifs.map((n) => n.userId).toList();
      expect(recipientIds, containsAll(['broker-1', 'broker-2']));
      expect(recipientIds, isNot(contains('broker-3')));
      expect(recipientIds, isNot(contains('broker-4')));
    });

    test('11. includes the current saved Google Maps URL when coordinates are present', () {
      final now = DateTime.now();
      final wh = CompanyWarehouse(
        id: 'wh-abc-123',
        companyId: buyerCompanyId,
        createdBy: 'buyer-user-1',
        name: 'Mandi Gate Silo',
        addressLine: 'Plot 5, New Mandi Area',
        latitude: 25.1825,
        longitude: 75.8398,
        gpsAccuracy: 4.5,
        createdAt: now,
        updatedAt: now,
      );

      final notifs = simulator.onWarehouseChange(newRecord: wh);
      expect(notifs.first.payload['googleMapsUrl'],
          'https://www.google.com/maps/search/?api=1&query=25.1825%2C75.8398');
      expect(notifs.first.payload['latitude'], 25.1825);
      expect(notifs.first.payload['longitude'], 75.8398);
      expect(notifs.first.payload['gpsAccuracy'], 4.5);
    });

    test('9. missing coordinates never produce a fabricated map link', () {
      final now = DateTime.now();
      final wh = CompanyWarehouse(
        id: 'wh-abc-123',
        companyId: buyerCompanyId,
        createdBy: 'buyer-user-1',
        name: 'Address Only Godown',
        addressLine: 'Rural Bypass, No GPS',
        createdAt: now,
        updatedAt: now,
      );

      final notifs = simulator.onWarehouseChange(newRecord: wh);
      expect(notifs.first.payload['googleMapsUrl'], isNull);
      expect(notifs.first.payload['latitude'], isNull);
      expect(notifs.first.payload['address'], 'Rural Bypass, No GPS');
    });

    test('distinguishes LOCATION_UPDATED when only coordinates change', () {
      final now = DateTime.now();
      final oldWh = CompanyWarehouse(
        id: 'wh-abc-123',
        companyId: buyerCompanyId,
        createdBy: 'buyer-user-1',
        name: 'Mandi Gate Silo',
        addressLine: 'Plot 5, New Mandi Area',
        latitude: null,
        longitude: null,
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      );

      final newWh = oldWh.copyWith(
        latitude: 25.1825,
        longitude: 75.8398,
        updatedAt: now,
      );

      final notifs = simulator.onWarehouseChange(oldRecord: oldWh, newRecord: newWh);
      expect(notifs.length, 2);
      expect(notifs.first.payload['changeType'], 'LOCATION_UPDATED');
      expect(notifs.first.message, contains('updated GPS unloading coordinates for: Mandi Gate Silo'));
      expect(notifs.first.message, contains('Google Maps link attached'));
      expect(notifs.first.payload['googleMapsUrl'], isNotNull);
    });

    test('12. failed warehouse updates or no-op modifications create no notification', () {
      final now = DateTime.now();
      final wh = CompanyWarehouse(
        id: 'wh-abc-123',
        companyId: buyerCompanyId,
        createdBy: 'buyer-user-1',
        name: 'Mandi Gate Silo',
        addressLine: 'Plot 5, New Mandi Area',
        latitude: 25.1825,
        longitude: 75.8398,
        createdAt: now,
        updatedAt: now,
      );

      // Same data unchanged: no-op
      final notifs = simulator.onWarehouseChange(oldRecord: wh, newRecord: wh);
      expect(notifs, isEmpty);
    });

    test('13. notification retries do not create duplicate alerts (idempotency key match)', () {
      final now = DateTime.utc(2026, 10, 29, 14, 0, 0);
      final wh = CompanyWarehouse(
        id: 'wh-abc-123',
        companyId: buyerCompanyId,
        createdBy: 'buyer-user-1',
        name: 'Mandi Gate Silo',
        addressLine: 'Plot 5, New Mandi Area',
        createdAt: now,
        updatedAt: now,
      );

      final dispatch1 = simulator.onWarehouseChange(newRecord: wh);
      final dispatch2 = simulator.onWarehouseChange(newRecord: wh);

      expect(dispatch1.first.idempotencyKey, dispatch2.first.idempotencyKey);
      expect(dispatch1.last.idempotencyKey, dispatch2.last.idempotencyKey);
    });
  });
}
