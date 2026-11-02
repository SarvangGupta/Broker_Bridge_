import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/notifications/domain/alert_kind.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_category.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_model.dart';

/// Rows shaped exactly like the ones proposed migration 0065's trigger writes
/// (RB-SELLER-COMMODITY-BROKER-NOTIFY-01).
void main() {
  const lotId = '6f1c2a90-1b2c-4d3e-8f90-1234567890ab';

  Map<String, dynamic> row(String eventType, {bool removed = false}) => {
        'id': 'n1',
        'user_id': 'broker-1',
        'company_id': 'broker-firm',
        'channel': 'IN_APP',
        'event_type': eventType,
        'title': 'Commodity price updated',
        'message': 'Shree Ganesh Traders updated the price for Yellow Maize — LOT-123 to ₹6100/MT.',
        'context_reason': 'Seller update on a listing assigned to you',
        'action_label': removed ? 'View Offers' : 'Open Listing',
        'action_url': '/work?tab=1&offerId=$lotId',
        'delivery_status': 'Sent',
        'is_read': false,
        'created_at': '2026-11-02T10:00:00Z',
        'payload': {
          'availabilityId': lotId,
          'lotNumber': 'LOT-123',
          'commodity': 'Yellow Maize',
          'sellerName': 'Shree Ganesh Traders',
          'quantity': 80,
          'unit': 'MT',
          'price': 6100,
          'status': removed ? 'Cancelled' : 'Open',
          'changeType': eventType,
          'changedFields': ['asking_price', 'price'],
          'listingRemoved': removed,
        },
      };

  const events = [
    'AVAILABILITY_CREATED',
    'AVAILABILITY_ASSIGNED',
    'AVAILABILITY_UPDATED',
    'AVAILABILITY_PRICE_UPDATED',
    'AVAILABILITY_QUANTITY_UPDATED',
    'AVAILABILITY_LOCATION_UPDATED',
    'AVAILABILITY_PAYMENT_TERMS_UPDATED',
    'AVAILABILITY_QUALITY_UPDATED',
    'AVAILABILITY_STATUS_CHANGED',
    'AVAILABILITY_REMOVED',
  ];

  for (final event in events) {
    test('$event opens the seller listing under Sellers alerts', () {
      final n = BrokerNotification.fromJson(
        row(event, removed: event == 'AVAILABILITY_REMOVED'),
      );
      expect(n.category, NotificationCategory.requirementsAndOffers);
      expect(AlertKind.of(n), AlertKind.offer);
      expect(n.isActionable, isTrue);
      expect(n.isWarehouseEvent, isFalse);
      expect(n.resolvedRoute, '/work?tab=1&offerId=$lotId');
    });
  }

  test('detail line shows lot, quantity and price from the payload', () {
    final n = BrokerNotification.fromJson(row('AVAILABILITY_PRICE_UPDATED'));
    expect(n.recordReference, 'LOT-123');
    expect(n.detailLine, 'LOT-123 · 80 MT · ₹6,100/MT');
  });
}
