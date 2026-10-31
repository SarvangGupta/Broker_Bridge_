import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/notifications/data/notification_repository.dart';
import 'package:rmbroker_mobile/features/notifications/domain/alert_kind.dart';
import 'package:rmbroker_mobile/features/notifications/domain/alert_presentation.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_model.dart';
import 'package:rmbroker_mobile/features/notifications/presentation/widgets/notification_card.dart';

import '../../support/fake_postgrest.dart';

BrokerNotification alert(String type, {String title = 'Alert', Map<String, dynamic>? payload, String? name}) {
  final n = BrokerNotification.fromJson({
    'id': 'n1',
    'user_id': 'broker',
    'event_type': type,
    'title': title,
    'message': '',
    'created_at': DateTime.now().toIso8601String(),
    'payload': ?payload,
  });
  return name == null ? n : n.copyWith(counterpartyName: name);
}

void main() {
  group('card wording per notification type', () {
    void check(BrokerNotification n, AlertStyle style, String heading, String action) {
      final look = AlertPresentation.of(n);
      expect(look.style, style);
      expect([look.subject, ?look.verb].join(' '), heading);
      expect(look.actionLabel, action);
    }

    test('BUY, SELL, MESSAGE, MATCH, warehouse and deal', () {
      check(alert('REQUIREMENT_CREATED', payload: {'requirementId': 'r'}, name: 'Rohan Gupta'), AlertStyle.buy,
          'Rohan Gupta wants to buy', 'View in Work Desk');
      check(alert('OFFER_CREATED', payload: {'offerId': 'o'}, name: 'Parth Ltd.'), AlertStyle.sell,
          'Parth Ltd. wants to sell', 'View in Work Desk');
      check(alert('CHAT_MESSAGE', title: 'New message from Rohan Gupta', payload: {'conversationId': 'c'}),
          AlertStyle.message, 'Rohan Gupta sent a message', 'Open Chat');
      check(alert('MATCH_CREATED', payload: {'requirementId': 'r'}), AlertStyle.match,
          'Your requirement has a match', 'View Matches');
      check(alert('WAREHOUSE_UPDATED', title: 'Warehouse Update: Rohan Gupta', payload: {'warehouseId': 'w'}),
          AlertStyle.update, 'Rohan Gupta updated warehouse', 'View Directory');
      check(alert('DEAL_UPDATED', payload: {'dealId': 'd'}, name: 'Rohan Gupta'), AlertStyle.deal,
          'Deal updated · Rohan Gupta', 'View Deal');
    });

    test('an unresolved name stays neutral and is never invented', () {
      check(alert('REQUIREMENT_CREATED', payload: {'requirementId': 'r'}), AlertStyle.buy, 'A buyer wants to buy',
          'View in Work Desk');
      check(alert('CHAT_MESSAGE', title: 'New message from your contact', payload: {'conversationId': 'c'}),
          AlertStyle.message, 'A contact sent a message', 'Open Chat');
    });

    test('a deal update tied only to a requirement does not promise a deal', () {
      final n = alert('DEAL_VERSION_UPDATE', payload: {'requirementId': 'r'});
      expect(AlertPresentation.of(n).actionLabel, 'View Requirement');
      expect(n.resolvedRoute, '/requirements/r');
    });

    test('each type routes to its own record', () {
      expect(alert('REQUIREMENT_CREATED', payload: {'requirementId': 'r'}).resolvedRoute, '/requirements/r');
      expect(alert('OFFER_CREATED', payload: {'offerId': 'o'}).resolvedRoute, '/work?tab=1&offerId=o');
      expect(alert('CHAT_MESSAGE', payload: {'conversationId': 'c'}).resolvedRoute, '/chats/c');
      expect(alert('DEAL_UPDATED', payload: {'dealId': 'd'}).resolvedRoute, '/deals/d');
    });

    test('filters: chat counts under Buyers, warehouse only under All', () {
      expect(AlertKind.of(alert('CHAT_MESSAGE', payload: {'conversationId': 'c'})), AlertKind.requirement);
      expect(AlertKind.of(alert('WAREHOUSE_UPDATED', payload: {'warehouseId': 'w'})), AlertKind.other);
    });

    test('initials and place', () {
      expect(AlertPresentation.initials('Rohan Gupta'), 'RG');
      expect(AlertPresentation.initials('Parth'), 'P');
      expect(AlertPresentation.initials(null), isNull);
      expect(NotificationCard.placeOf('FOR Mill Delivery, Kota Mandi'), 'Kota Mandi');
      expect(NotificationCard.placeOf('Yard, Road - 324005, Kota, Rajasthan'), 'Kota');
      expect(NotificationCard.placeOf(null), isNull);
    });
  });

  group('resolveRelated', () {
    test('reads names and facts from the related records', () async {
      final fake = await FakePostgrest.start({
        'requirements': [
          {
            'id': 'r1',
            'quantity': 100,
            'delivery_terms_id': 'Jaipur',
            'companies': {'name': 'Rohan Gupta'},
            'master_commodities': {'name': 'DORB'},
            'master_units': {'symbol': 'MT'},
          },
        ],
        'availabilities': [
          {
            'id': 'o1',
            'quantity': 50,
            'companies': {'name': 'Parth Ltd.'},
            'master_commodities': {'name': 'Maize DDGS'},
            'master_units': {'symbol': 'MT'},
            'master_districts': {'name': 'Banswara'},
          },
        ],
        'deals': [
          {'id': 'd1', 'buyer': {'name': 'Deal Buyer'}},
        ],
        'companies': [
          {'id': 'c1', 'name': 'Warehouse Co'},
        ],
      });
      addTearDown(fake.close);
      final res = await NotificationRepository(supabase: fake.client).resolveRelated([
        alert('REQUIREMENT_CREATED', payload: {'requirementId': 'r1'}),
        alert('OFFER_CREATED', payload: {'offerId': 'o1'}),
        alert('DEAL_UPDATED', payload: {'dealId': 'd1'}),
        alert('WAREHOUSE_UPDATED', payload: {'warehouseId': 'w', 'companyId': 'c1'}),
      ]);
      expect(res[0].counterpartyName, 'Rohan Gupta');
      expect(res[0].commodityLabel, 'DORB');
      expect(res[0].resolvedQuantity, '100 MT');
      expect(res[0].resolvedLocation, 'Jaipur');
      expect(res[1].counterpartyName, 'Parth Ltd.');
      expect(res[1].resolvedLocation, 'Banswara');
      expect(res[2].counterpartyName, 'Deal Buyer');
      expect(res[3].counterpartyName, 'Warehouse Co');
      expect(fake.writes(), isEmpty);
    });

    test('a hidden or deleted record, or a failed read, keeps the alert and its route', () async {
      final fake = await FakePostgrest.start({'requirements': []});
      addTearDown(fake.close);
      final repo = NotificationRepository(supabase: fake.client);
      final item = alert('REQUIREMENT_CREATED', payload: {'requirementId': 'gone'});

      var res = await repo.resolveRelated([item]);
      expect(res.single.counterpartyName, isNull);
      expect(res.single.resolvedRoute, '/requirements/gone');

      fake.failWith = (_) => (500, {'message': 'boom'});
      res = await repo.resolveRelated([item]);
      expect(res.single.id, 'n1');
      expect(AlertPresentation.of(res.single).subject, 'A buyer');
    });
  });
}
