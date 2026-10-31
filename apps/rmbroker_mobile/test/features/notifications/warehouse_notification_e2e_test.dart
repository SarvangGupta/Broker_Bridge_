import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/notifications/domain/alert_presentation.dart';
import 'package:rmbroker_mobile/features/notifications/data/notification_repository.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_category.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_model.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/widgets/notification_card.dart';

class _MockNotificationRepository extends NotificationRepository {
  final List<BrokerNotification> items;

  _MockNotificationRepository(this.items);

  @override
  Future<List<BrokerNotification>> fetchNotifications({
    NotificationCategory? category,
    bool? unreadOnly,
  }) async {
    var result = List<BrokerNotification>.from(items);
    if (category != null && category != NotificationCategory.all) {
      result = result.where((n) => n.category == category).toList();
    }
    if (unreadOnly == true) {
      result = result.where((n) => !n.isRead).toList();
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    final idx = items.indexWhere((n) => n.id == notificationId);
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(isRead: true, readAt: DateTime.now());
    }
    return true;
  }
}

void main() {
  group('Warehouse Notification E2E & UI Integration', () {
    test('parses WAREHOUSE_UPDATED notification and maps to dispatchAndDelivery category', () {
      final json = {
        'id': 'notif-wh-01',
        'user_id': 'broker-100',
        'company_id': 'brokerage-5',
        'channel': 'IN_APP',
        'event_type': 'WAREHOUSE_UPDATED',
        'title': 'Warehouse Update: Apex Commodities Ltd',
        'message':
            'Apex Commodities Ltd added a new warehouse/unloading location: Kota Terminal Godown (Plot 10, Mandi Industrial Area).',
        'context_reason': 'Operational unloading location update from counterparty',
        'action_label': 'View Directory',
        'action_url': '/directory',
        'delivery_status': 'Sent',
        'is_read': false,
        'created_at': DateTime(2026, 10, 29, 10, 30).toIso8601String(),
        'payload': {
          'companyId': 'comp-buyer-101',
          'warehouseId': 'wh-001',
          'warehouseName': 'Kota Terminal Godown',
          'address': 'Plot 10, Mandi Industrial Area',
          'pinCode': '324005',
          'changeType': 'CREATED',
        },
      };

      final notif = BrokerNotification.fromJson(json);

      expect(notif.id, 'notif-wh-01');
      expect(notif.eventType, 'WAREHOUSE_UPDATED');
      expect(notif.category, NotificationCategory.dispatchAndDelivery);
      expect(NotificationCard.typeLabel(notif), 'Warehouse update');
      expect(AlertPresentation.counterparty(notif), 'Apex Commodities Ltd');
      expect(notif.actionUrl, '/directory');
      expect(notif.payload?['warehouseName'], 'Kota Terminal Godown');
      expect(notif.payload?['changeType'], 'CREATED');
    });

    test('parses WAREHOUSE_DEACTIVATED event type and labels correctly', () {
      final json = {
        'id': 'notif-wh-02',
        'user_id': 'broker-100',
        'event_type': 'WAREHOUSE_DEACTIVATED',
        'title': 'Warehouse Update: Apex Commodities Ltd',
        'message': 'Apex Commodities Ltd deactivated unloading location: Kota Terminal Godown.',
        'action_label': 'View Directory',
        'action_url': '/directory',
        'created_at': DateTime(2026, 10, 29, 11, 0).toIso8601String(),
      };

      final notif = BrokerNotification.fromJson(json);
      expect(notif.category, NotificationCategory.dispatchAndDelivery);
      expect(NotificationCard.typeLabel(notif), 'Warehouse deactivated');
    });

    testWidgets('NotificationCard renders warehouse update with headline and type label', (
      tester,
    ) async {
      final notif = BrokerNotification(
        id: 'notif-wh-01',
        userId: 'broker-100',
        eventType: 'WAREHOUSE_UPDATED',
        category: NotificationCategory.dispatchAndDelivery,
        title: 'Warehouse Update: Apex Commodities Ltd',
        message: 'Apex Commodities Ltd updated unloading location: Kota Terminal Godown.',
        contextReason: 'Counterparty facility change',
        actionLabel: 'View Directory',
        actionUrl: '/directory',
        deliveryStatus: 'Sent',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        payload: {
          'warehouseName': 'Kota Terminal Godown',
          'changeType': 'UPDATED',
        },
      );

      BrokerNotification? tappedNotif;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationCard(
              notification: notif,
              onTap: (n) => tappedNotif = n,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Warehouse update'), findsOneWidget);
      expect(find.text('Apex Commodities Ltd updated warehouse'), findsOneWidget);

      await tester.tap(find.byType(NotificationCard));
      await tester.pumpAndSettle();

      expect(tappedNotif, isNotNull);
      expect(tappedNotif!.actionUrl, '/directory');
    });

    testWidgets('NotificationCenterScreen renders warehouse notification and supports search', (
      tester,
    ) async {
      final whNotif = BrokerNotification(
        id: 'notif-wh-01',
        userId: 'broker-100',
        eventType: 'WAREHOUSE_UPDATED',
        category: NotificationCategory.dispatchAndDelivery,
        title: 'Warehouse Update: Apex Commodities Ltd',
        message: 'Apex Commodities Ltd added a new warehouse/unloading location: Kota Terminal Godown.',
        contextReason: 'Counterparty facility change',
        actionLabel: 'View Directory',
        actionUrl: '/directory',
        deliveryStatus: 'Sent',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      final mockRepo = _MockNotificationRepository([whNotif]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: NotificationCenterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In notification list, warehouse update and company name are rendered
      expect(find.text('Warehouse update'), findsOneWidget);
      expect(find.text('Apex Commodities Ltd updated warehouse'), findsOneWidget);

      // Search by company name
      await tester.enterText(find.byType(TextField), 'Apex Commodities');
      await tester.pumpAndSettle();
      expect(find.text('Warehouse update'), findsOneWidget);

      // Search non-matching text
      await tester.enterText(find.byType(TextField), 'NonExistentParty');
      await tester.pumpAndSettle();
      expect(find.text('Warehouse update'), findsNothing);
    });

    testWidgets('14. NotificationCard displays View on Google Maps when valid coordinates are present', (
      tester,
    ) async {
      final notifWithGps = BrokerNotification(
        id: 'notif-wh-gps',
        userId: 'broker-100',
        eventType: 'WAREHOUSE_UPDATED',
        category: NotificationCategory.dispatchAndDelivery,
        title: 'Warehouse Update: Apex Commodities Ltd',
        message: 'Apex Commodities Ltd updated GPS coordinates.',
        contextReason: 'Location update',
        actionLabel: 'View Directory',
        actionUrl: '/directory',
        createdAt: DateTime.now(),
        payload: {
          'warehouseName': 'Kota Terminal Godown',
          'latitude': 25.1825,
          'longitude': 75.8398,
          'googleMapsUrl': 'https://www.google.com/maps/search/?api=1&query=25.1825%2C75.8398',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationCard(
              notification: notifWithGps,
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('notif_maps_notif-wh-gps')), findsOneWidget);
      expect(find.text('View on Google Maps'), findsOneWidget);
      expect(notifWithGps.googleMapsUrl,
          'https://www.google.com/maps/search/?api=1&query=25.1825%2C75.8398');
    });

    testWidgets('9. NotificationCard does not display View on Google Maps when coordinates are absent', (
      tester,
    ) async {
      final notifNoGps = BrokerNotification(
        id: 'notif-wh-nogps',
        userId: 'broker-100',
        eventType: 'WAREHOUSE_UPDATED',
        category: NotificationCategory.dispatchAndDelivery,
        title: 'Warehouse Update: Apex Commodities Ltd',
        message: 'Apex Commodities Ltd updated address.',
        contextReason: 'Address update',
        actionLabel: 'View Directory',
        actionUrl: '/directory',
        createdAt: DateTime.now(),
        payload: {
          'warehouseName': 'Rural Godown',
          'address': 'Kisan Mandi Yard',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationCard(
              notification: notifNoGps,
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('notif_maps_notif-wh-nogps')), findsNothing);
      expect(find.text('View on Google Maps'), findsNothing);
      expect(notifNoGps.googleMapsUrl, isNull);
    });
  });
}
