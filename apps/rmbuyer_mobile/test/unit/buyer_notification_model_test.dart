import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/notifications/data/buyer_notifications_repository.dart';
import 'package:rmbuyer_mobile/features/notifications/domain/buyer_notification_model.dart';
import 'package:rmbuyer_mobile/features/notifications/presentation/buyer_notifications_screen.dart';
import 'package:rmbuyer_mobile/l10n/app_localizations.dart';

import '../support/fake_notifications_repository.dart';

BuyerNotification n(Map<String, dynamic> extra) => BuyerNotification.fromMap({
  'id': 'x',
  'title': 't',
  'event_type': 'SYSTEM',
  ...extra,
});

void main() {
  group('BuyerNotification.fromMap', () {
    test('maps stored values without inventing any', () {
      final m = BuyerNotification.fromMap({
        'id': 'a',
        'title': null,
        'message': null,
        'event_type': 'booking_created',
      });
      expect(m.title, '');
      expect(m.message, '');
      expect(m.createdAt, isNull);
      expect(m.isRead, isFalse);
      expect(m.eventType, 'BOOKING_CREATED');
      expect(m.payload, isEmpty);
    });

    test(
      'read when either is_read or read_at is set (web Action Center rule)',
      () {
        expect(n({'is_read': true}).isRead, isTrue);
        expect(
          n({'is_read': false, 'read_at': '2026-10-25T00:00:00Z'}).isRead,
          isTrue,
        );
        expect(n({'is_read': false}).isRead, isFalse);
      },
    );
  });

  group('NotificationTarget.resolve', () {
    test(
      'requirement from list URL + payload, or explicit requirement URL',
      () {
        final a = NotificationTarget.resolve(
          n({
            'action_url': '/buyer/requirements',
            'payload': {'requirementId': reqId},
          }),
        );
        expect((a.kind, a.id), (NotificationTargetKind.requirement, reqId));
        final b = NotificationTarget.resolve(
          n({'action_url': '/buyer/requirements/$reqId'}),
        );
        expect((b.kind, b.id), (NotificationTargetKind.requirement, reqId));
        expect(
          NotificationTarget.resolve(n({'action_url': '/buyer/requirements'}))
              .kind,
          NotificationTargetKind.requirementsList,
        );
      },
    );

    test(
      'deal and contract-confirmation targets are recognised but not openable',
      () {
        final deal = NotificationTarget.resolve(
          n({'action_url': '/broker/deals/$dealId'}),
        );
        expect(
          (deal.kind, deal.id, deal.canOpen),
          (NotificationTargetKind.deal, dealId, false),
        );
        final offer = NotificationTarget.resolve(
          n({'action_url': '/buyer/confirmations?requestId=$quoteId'}),
        );
        expect(
          (offer.kind, offer.id, offer.canOpen),
          (NotificationTargetKind.offer, quoteId, false),
        );
      },
    );

    test('malformed, foreign or text-only references resolve to no target', () {
      for (final row in [
        {'action_url': '/buyer/requirements/not-a-uuid'},
        {'action_url': '/seller/requests?requestId=$quoteId'},
        {'action_url': '/broker/deals/12345'},
        {'action_url': 'work?tab=0'},
        {'action_url': '', 'message': 'Open requirement $reqId now'},
        {'action_url': '/buyer/requirements/$reqId/../../admin'},
      ]) {
        expect(
          NotificationTarget.resolve(n(row)).kind,
          NotificationTargetKind.none,
          reason: '$row',
        );
      }
    });
  });

  test('dedupe keeps the first row per ID and drops rows without an ID', () {
    final list = BuyerNotificationsRepository.dedupe([
      n({'id': 'a', 'title': 'first'}),
      n({'id': 'b'}),
      n({'id': 'a', 'title': 'duplicate'}),
      n({'id': ''}),
    ]);
    expect(list.map((e) => e.id), ['a', 'b']);
    expect(list.first.title, 'first');
  });

  test('known event types get a category label; unknown types are a generic update', () {
    expect(
      BuyerNotificationsScreen.eventLabel('FINAL_CONFIRMATION_REQUIRED'),
      Tr.evtConfirmation,
    );
    expect(BuyerNotificationsScreen.eventLabel('BOOKING_CREATED'), Tr.evtDeal);
    expect(
      BuyerNotificationsScreen.eventLabel('PAYMENT_UPDATE'),
      Tr.evtPayment,
    );
    expect(BuyerNotificationsScreen.eventLabel('SOMETHING_NEW'), Tr.evtUpdate);
  });
}
