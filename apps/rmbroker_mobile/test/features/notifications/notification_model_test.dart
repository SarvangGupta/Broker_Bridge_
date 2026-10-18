import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_category.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_model.dart';

void main() {
  group('NotificationCategory Mapping Tests', () {
    test('maps all Requirements & Offers event types', () {
      expect(
        NotificationCategory.fromEventType('NEW_BROKER_REQUEST'),
        NotificationCategory.requirementsAndOffers,
      );
      expect(
        NotificationCategory.fromEventType('AVAILABILITY_APPROVED'),
        NotificationCategory.requirementsAndOffers,
      );
      expect(
        NotificationCategory.fromEventType('AVAILABILITY_REJECTED'),
        NotificationCategory.requirementsAndOffers,
      );
      expect(
        NotificationCategory.fromEventType('AVAILABILITY_EXPIRING'),
        NotificationCategory.requirementsAndOffers,
      );
      expect(
        NotificationCategory.fromEventType('MATCH_CREATED'),
        NotificationCategory.requirementsAndOffers,
      );
      expect(
        NotificationCategory.fromEventType('MATCH_UPDATED'),
        NotificationCategory.requirementsAndOffers,
      );
    });

    test('maps all Deals & Confirmations event types', () {
      expect(
        NotificationCategory.fromEventType('DEAL_CREATED'),
        NotificationCategory.dealsAndConfirmations,
      );
      expect(
        NotificationCategory.fromEventType('DEAL_UPDATED'),
        NotificationCategory.dealsAndConfirmations,
      );
      expect(
        NotificationCategory.fromEventType('BROKER_COUNTER'),
        NotificationCategory.dealsAndConfirmations,
      );
      expect(
        NotificationCategory.fromEventType('DEAL_VERSION_UPDATE'),
        NotificationCategory.dealsAndConfirmations,
      );
      expect(
        NotificationCategory.fromEventType('FINAL_CONFIRMATION_REQUIRED'),
        NotificationCategory.dealsAndConfirmations,
      );
      expect(
        NotificationCategory.fromEventType('CONFIRMATION_OUTCOME'),
        NotificationCategory.dealsAndConfirmations,
      );
      expect(
        NotificationCategory.fromEventType('BOOKING_CREATED'),
        NotificationCategory.dealsAndConfirmations,
      );
    });

    test('maps all Dispatch & Delivery event types', () {
      expect(
        NotificationCategory.fromEventType('LOADING_REMINDER'),
        NotificationCategory.dispatchAndDelivery,
      );
      expect(
        NotificationCategory.fromEventType('DISPATCH_REMINDER'),
        NotificationCategory.dispatchAndDelivery,
      );
      expect(
        NotificationCategory.fromEventType('DOCUMENT_ISSUE'),
        NotificationCategory.dispatchAndDelivery,
      );
      expect(
        NotificationCategory.fromEventType('DELIVERY_UPDATE'),
        NotificationCategory.dispatchAndDelivery,
      );
      expect(
        NotificationCategory.fromEventType('DELIVERY_RECORDED'),
        NotificationCategory.dispatchAndDelivery,
      );
    });

    test('maps all Commission & Invoices event types', () {
      expect(
        NotificationCategory.fromEventType('COMMISSION_ELIGIBLE'),
        NotificationCategory.commissionAndInvoices,
      );
      expect(
        NotificationCategory.fromEventType('INVOICE_GENERATED'),
        NotificationCategory.commissionAndInvoices,
      );
      expect(
        NotificationCategory.fromEventType('INVOICE_STATUS_CHANGED'),
        NotificationCategory.commissionAndInvoices,
      );
      expect(
        NotificationCategory.fromEventType('PAYMENT_UPDATE'),
        NotificationCategory.commissionAndInvoices,
      );
      expect(
        NotificationCategory.fromEventType('PAYMENT_RECORDED'),
        NotificationCategory.commissionAndInvoices,
      );
    });

    test('maps all Disputes & Exceptions event types', () {
      expect(
        NotificationCategory.fromEventType('QUALITY_REVIEW'),
        NotificationCategory.disputesAndExceptions,
      );
      expect(
        NotificationCategory.fromEventType('LAB_UPDATE'),
        NotificationCategory.disputesAndExceptions,
      );
      expect(
        NotificationCategory.fromEventType('DISPUTE_RAISED'),
        NotificationCategory.disputesAndExceptions,
      );
      expect(
        NotificationCategory.fromEventType('RECONCILIATION_EXCEPTION'),
        NotificationCategory.disputesAndExceptions,
      );
    });

    test('maps system and unknown event types to System', () {
      expect(
        NotificationCategory.fromEventType('KYC_STATUS'),
        NotificationCategory.system,
      );
      expect(
        NotificationCategory.fromEventType('SYSTEM'),
        NotificationCategory.system,
      );
      expect(
        NotificationCategory.fromEventType('UNKNOWN_EVENT_TYPE'),
        NotificationCategory.system,
      );
      expect(
        NotificationCategory.fromEventType(null),
        NotificationCategory.system,
      );
    });

    test('fromCode parses valid category codes and defaults to all', () {
      expect(
        NotificationCategory.fromCode('deals_confirmations'),
        NotificationCategory.dealsAndConfirmations,
      );
      expect(
        NotificationCategory.fromCode('requirements_offers'),
        NotificationCategory.requirementsAndOffers,
      );
      expect(
        NotificationCategory.fromCode('invalid_code'),
        NotificationCategory.all,
      );
      expect(
        NotificationCategory.fromCode(null),
        NotificationCategory.all,
      );
    });
  });

  group('BrokerNotification Model Tests', () {
    test('fromJson parses full backend payload accurately', () {
      final json = {
        'id': 'notif-101',
        'user_id': 'user-100',
        'company_id': 'comp-100',
        'channel': 'IN_APP',
        'event_type': 'FINAL_CONFIRMATION_REQUIRED',
        'title': 'Deal Confirmation Required',
        'message': 'Deal DL-2026-0891 awaits confirmation',
        'context_reason': 'Buyer confirmed terms. Awaiting seller signature.',
        'action_label': 'Review Deal',
        'action_url': '/deals/deal-bkg-0042',
        'idempotency_key': 'idemp-0891-v1',
        'delivery_status': 'Sent',
        'is_read': false,
        'read_at': null,
        'created_at': '2026-03-01T10:00:00.000Z',
        'payload': {
          'dealId': 'deal-bkg-0042',
          'commodity': 'Mustard Seed',
        },
      };

      final notif = BrokerNotification.fromJson(json);

      expect(notif.id, 'notif-101');
      expect(notif.userId, 'user-100');
      expect(notif.companyId, 'comp-100');
      expect(notif.channel, 'IN_APP');
      expect(notif.eventType, 'FINAL_CONFIRMATION_REQUIRED');
      expect(notif.category, NotificationCategory.dealsAndConfirmations);
      expect(notif.title, 'Deal Confirmation Required');
      expect(notif.message, 'Deal DL-2026-0891 awaits confirmation');
      expect(notif.contextReason, 'Buyer confirmed terms. Awaiting seller signature.');
      expect(notif.actionLabel, 'Review Deal');
      expect(notif.actionUrl, '/deals/deal-bkg-0042');
      expect(notif.idempotencyKey, 'idemp-0891-v1');
      expect(notif.deliveryStatus, 'Sent');
      expect(notif.isRead, isFalse);
      expect(notif.readAt, isNull);
      expect(notif.isActionable, isTrue);
      expect(notif.resolvedRoute, '/deals/deal-bkg-0042');
      expect(notif.isUrgent, isTrue);
    });

    test('toJson produces valid serializable map matching DB schema', () {
      final notif = BrokerNotification(
        id: 'notif-102',
        userId: 'user-100',
        eventType: 'INVOICE_GENERATED',
        category: NotificationCategory.commissionAndInvoices,
        title: 'Invoice Issued',
        message: 'Invoice INV-2026-0042 issued',
        contextReason: 'Brokerage commission invoice ready',
        actionLabel: 'View Invoice',
        actionUrl: '/invoices/inv-2026-0042',
        idempotencyKey: 'idemp-inv-0042',
        createdAt: DateTime(2026, 3, 1, 10, 0),
        isRead: true,
        readAt: DateTime(2026, 3, 1, 11, 0),
      );

      final json = notif.toJson();
      expect(json['id'], 'notif-102');
      expect(json['user_id'], 'user-100');
      expect(json['event_type'], 'INVOICE_GENERATED');
      expect(json['is_read'], isTrue);
      expect(json['action_url'], '/invoices/inv-2026-0042');
    });

    test('resolvedRoute falls back to payload IDs when actionUrl is missing', () {
      final notifWithDeal = BrokerNotification(
        id: 'n1',
        userId: 'u1',
        eventType: 'DEAL_UPDATED',
        category: NotificationCategory.dealsAndConfirmations,
        title: 'Deal Update',
        message: 'Updated',
        contextReason: 'Terms updated',
        createdAt: DateTime.now(),
        payload: {'dealId': 'deal-999'},
      );
      expect(notifWithDeal.resolvedRoute, '/deals/deal-999');

      final notifWithInvoice = BrokerNotification(
        id: 'n2',
        userId: 'u1',
        eventType: 'PAYMENT_UPDATE',
        category: NotificationCategory.commissionAndInvoices,
        title: 'Payment Update',
        message: 'Paid',
        contextReason: 'Payment verified',
        createdAt: DateTime.now(),
        payload: {'invoiceId': 'inv-888'},
      );
      expect(notifWithInvoice.resolvedRoute, '/invoices/inv-888');

      final notifWithDispute = BrokerNotification(
        id: 'n3',
        userId: 'u1',
        eventType: 'DISPUTE_RAISED',
        category: NotificationCategory.disputesAndExceptions,
        title: 'Dispute',
        message: 'Claim',
        contextReason: 'Under review',
        createdAt: DateTime.now(),
        payload: {'disputeId': 'disp-777'},
      );
      expect(notifWithDispute.resolvedRoute, '/disputes');
    });

    test('formattedTime handles relative times appropriately', () {
      final now = DateTime.now();

      final justNow = BrokerNotification(
        id: 'n-time-1',
        userId: 'u1',
        eventType: 'SYSTEM',
        category: NotificationCategory.system,
        title: 'Title',
        message: 'Msg',
        contextReason: 'Reason',
        createdAt: now.subtract(const Duration(seconds: 30)),
      );
      expect(justNow.formattedTime, 'Just now');

      final minutesAgo = BrokerNotification(
        id: 'n-time-2',
        userId: 'u1',
        eventType: 'SYSTEM',
        category: NotificationCategory.system,
        title: 'Title',
        message: 'Msg',
        contextReason: 'Reason',
        createdAt: now.subtract(const Duration(minutes: 25)),
      );
      expect(minutesAgo.formattedTime, '25m ago');

      final hoursAgo = BrokerNotification(
        id: 'n-time-3',
        userId: 'u1',
        eventType: 'SYSTEM',
        category: NotificationCategory.system,
        title: 'Title',
        message: 'Msg',
        contextReason: 'Reason',
        createdAt: now.subtract(const Duration(hours: 5)),
      );
      expect(hoursAgo.formattedTime, '5h ago');

      final daysAgo = BrokerNotification(
        id: 'n-time-4',
        userId: 'u1',
        eventType: 'SYSTEM',
        category: NotificationCategory.system,
        title: 'Title',
        message: 'Msg',
        contextReason: 'Reason',
        createdAt: now.subtract(const Duration(days: 3)),
      );
      expect(daysAgo.formattedTime, '3d ago');
    });

    test('copyWith produces modified copy without mutating original', () {
      final original = BrokerNotification(
        id: 'n-copy',
        userId: 'u1',
        eventType: 'SYSTEM',
        category: NotificationCategory.system,
        title: 'Original Title',
        message: 'Msg',
        contextReason: 'Reason',
        createdAt: DateTime(2026, 1, 1),
        isRead: false,
      );

      final modified = original.copyWith(isRead: true, readAt: DateTime(2026, 1, 2));

      expect(original.isRead, isFalse);
      expect(modified.isRead, isTrue);
      expect(modified.id, 'n-copy');
      expect(modified.title, 'Original Title');
    });
  });
}
