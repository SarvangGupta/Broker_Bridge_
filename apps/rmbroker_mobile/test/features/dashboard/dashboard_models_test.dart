import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/dashboard/domain/dashboard_models.dart';

void main() {
  group('BrokerDashboardMetrics Domain Tests', () {
    test('fromJson correctly parses authoritative backend payload', () {
      final json = {
        'kpis': {
          'activeDealsCount': 5,
          'openRequirementsCount': 12,
          'partiallyAllocatedCount': 3,
          'availableOffersCount': 8,
          'awaitingConfirmationCount': 2,
          'dispatchDueCount': 4,
          'deliveriesAwaitingConfirmationCount': 1,
          'commissionThisMonth': '₹25,000',
          'openDisputesCount': 0,
        },
      };

      final metrics = BrokerDashboardMetrics.fromJson(json);

      expect(metrics.activeDealsCount, equals(5));
      expect(metrics.openRequirementsCount, equals(12));
      expect(metrics.partiallyAllocatedCount, equals(3));
      expect(metrics.availableOffersCount, equals(8));
      expect(metrics.awaitingConfirmationCount, equals(2));
      expect(metrics.dispatchDueCount, equals(4));
      expect(metrics.deliveriesAwaitingCount, equals(1));
      expect(metrics.commissionThisMonth, equals('₹25,000'));
      expect(metrics.openDisputesCount, equals(0));
      expect(metrics.isAuthoritative, isTrue);

      final cards = metrics.toKpiCards();
      expect(cards.length, equals(8));
      expect(cards[0].title, equals('Active Deals'));
      expect(cards[0].value, equals('5'));
      expect(cards[0].route, equals('/deals?filter=active'));

      expect(cards[1].title, equals('Open Requirements'));
      expect(cards[1].value, equals('12'));
      expect(cards[1].isAvailable, isTrue);
      expect(cards[1].route, equals('/work?tab=0&status=open'));
      expect(cards[2].route, equals('/work?tab=0&status=partially_allocated'));
      expect(cards[3].route, equals('/work?tab=1&status=open'));
      expect(cards[4].route, equals('/deals?filter=signoff'));
      expect(cards[5].route, equals('/deals?filter=dispatch_due'));
      expect(cards[6].route, equals('/commission'));
      expect(cards[7].route, equals('/deals?filter=disputed'));
    });

    test('unavailable factory enforces zero-fabrication contract', () {
      final metrics = BrokerDashboardMetrics.unavailable(
        reason: 'Custom backend pending notice',
      );

      expect(metrics.activeDealsCount, isNull);
      expect(metrics.openRequirementsCount, isNull);
      expect(metrics.availableOffersCount, isNull);
      expect(metrics.isAuthoritative, isFalse);
      expect(metrics.dataSourceNotice, contains('Custom backend pending notice'));

      final cards = metrics.toKpiCards();
      expect(cards.length, equals(8));
      for (final card in cards) {
        expect(card.value, equals('—'));
        expect(card.isAvailable, isFalse);
      }
    });

    test('empty factory sets zeroed authoritative metrics', () {
      final metrics = BrokerDashboardMetrics.empty(notice: 'Verified zero records');

      expect(metrics.activeDealsCount, equals(0));
      expect(metrics.openRequirementsCount, equals(0));
      expect(metrics.commissionThisMonth, equals('₹0'));
      expect(metrics.isAuthoritative, isTrue);

      final cards = metrics.toKpiCards();
      expect(cards[0].value, equals('0'));
      expect(cards[0].isAvailable, isTrue);
    });
  });

  group('BrokerQuickAction & ActivityItem Tests', () {
    test('defaultActions returns 6 actions with implemented and roadmap separation', () {
      final actions = BrokerQuickAction.defaultActions();

      expect(actions.length, equals(6));

      // Core implemented modules
      expect(actions[0].id, equals('action_post_requirement'));
      expect(actions[0].title, equals('Post Requirement'));
      expect(actions[0].isImplemented, isTrue);
      expect(actions[0].route, equals('/work'));

      expect(actions[1].id, equals('action_add_offer'));
      expect(actions[1].title, equals('Add Offer'));
      expect(actions[1].isImplemented, isTrue);
      expect(actions[1].route, equals('/work?tab=1'));

      expect(actions[2].id, equals('action_manage_deals'));
      expect(actions[2].title, equals('Manage Deals'));
      expect(actions[2].isImplemented, isTrue);
      expect(actions[2].route, equals('/deals'));

      // Roadmap logistics module
      expect(actions[3].id, equals('action_track_dispatch'));
      expect(actions[3].title, equals('Track Dispatch'));
      expect(actions[3].isImplemented, isFalse);
      expect(actions[3].badge, equals('Roadmap'));
      expect(actions[3].route, equals('/orders'));

      expect(actions[4].id, equals('action_view_earnings'));
      expect(actions[4].title, equals('View Earnings'));
      expect(actions[4].isImplemented, isTrue);
      expect(actions[4].route, equals('/commission'));

      expect(actions[5].id, equals('action_new_dispute'));
      expect(actions[5].title, equals('New Dispute'));
      expect(actions[5].isImplemented, isTrue);
      expect(actions[5].route, equals('/deals?filter=disputed'));
    });

    test('BrokerActivityItem fromJson parses event properties correctly', () {
      final item = BrokerActivityItem.fromJson({
        'id': 'act-101',
        'title': 'Deal Confirmed: BKG-2026-0042',
        'description': 'Buyer Sharma Agro confirmed 50 MT Mustard Seed',
        'relativeTime': '15 minutes ago',
        'category': 'deals',
        'actionHref': '/deals',
        'eventType': 'deal_update',
      });

      expect(item.id, equals('act-101'));
      expect(item.title, contains('BKG-2026-0042'));
      expect(item.description, contains('50 MT'));
      expect(item.relativeTime, equals('15 minutes ago'));
      expect(item.category, equals('deals'));
      expect(item.route, equals('/deals'));
      expect(item.badge, equals('deal_update'));
    });
  });
}
