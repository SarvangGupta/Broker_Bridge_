import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/network/api_client.dart';
import 'package:rmbroker_mobile/features/notifications/data/notification_repository.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_category.dart';

import '../directory/directory_repository_test.dart' show MockSecureStorageService;

/// Rows shaped like live `notifications` rows (REQUIREMENT_CREATED from the
/// notify_requirement_brokers RPC, plus deal and commission events).
List<Map<String, dynamic>> _rows() => [
  {
    'id': 'n-req',
    'user_id': 'broker-1',
    'event_type': 'REQUIREMENT_CREATED',
    'title': 'New Procurement Requirement: Maize DDGS',
    'message': 'Buyer posted requirement for 35 MT of Maize DDGS.',
    'context_reason': 'Direct mandate notification from verified buyer',
    'action_url': '/work?tab=0',
    'is_read': false,
    'created_at': '2026-10-25T08:01:09.117Z',
    'payload': {'requirementId': '107df7a3-8693-42b2-9893-6a4610abad14'},
  },
  {
    'id': 'n-deal',
    'user_id': 'broker-1',
    'event_type': 'DEAL_VERSION_UPDATE',
    'title': 'Deal terms revised',
    'message': 'Deal terms moved to v2.',
    'context_reason': '',
    'action_url': '/broker/deals/90000000-0000-0000-0000-000000000002',
    'is_read': false,
    'created_at': '2026-10-24T08:00:00.000Z',
    'payload': {'dealId': '90000000-0000-0000-0000-000000000002'},
  },
  {
    'id': 'n-pay',
    'user_id': 'broker-1',
    'event_type': 'PAYMENT_RECORDED',
    'title': 'Commission Payment Recorded',
    'message': 'Payment received.',
    'context_reason': '',
    'action_url': '/invoices/inv-1',
    'is_read': true,
    'read_at': '2026-10-23T09:00:00.000Z',
    'created_at': '2026-10-23T08:00:00.000Z',
  },
];

/// ApiClient whose GET /broker/notifications returns [rows] (only on the first
/// call when [once] is set, so later reads show the cached state); writes succeed.
ApiClient _api(List<Map<String, dynamic>> rows, {bool once = false}) {
  var gets = 0;
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          final served = once && gets++ > 0 ? const <Map<String, dynamic>>[] : rows;
          final body = o.method == 'GET'
              ? {
                  'success': true,
                  'data': {'notifications': served},
                }
              : {'success': true};
          h.resolve(Response(requestOptions: o, statusCode: 200, data: body));
        },
      ),
    );
  return ApiClient(storage: MockSecureStorageService(), customDio: dio);
}

void main() {
  group('NotificationRepository (real rows only)', () {
    test('returns backend rows newest-first, with no sample data', () async {
      final repository = NotificationRepository(apiClient: _api(_rows()), storage: MockSecureStorageService());
      final notifs = await repository.fetchNotifications();

      expect(notifs.map((n) => n.id), ['n-req', 'n-deal', 'n-pay']);
      for (int i = 0; i < notifs.length - 1; i++) {
        expect(notifs[i].createdAt.isBefore(notifs[i + 1].createdAt), isFalse);
      }
    });

    test('an empty backend feed stays empty (no fabricated alerts)', () async {
      final repository = NotificationRepository(apiClient: _api(const []), storage: MockSecureStorageService());
      expect(await repository.fetchNotifications(), isEmpty);
    });

    test('filters by category and unread flag', () async {
      final repository = NotificationRepository(apiClient: _api(_rows()), storage: MockSecureStorageService());

      final reqs = await repository.fetchNotifications(category: NotificationCategory.requirementsAndOffers);
      expect(reqs.map((n) => n.id), ['n-req']);

      final unread = await repository.fetchNotifications(unreadOnly: true);
      expect(unread.map((n) => n.id), unorderedEquals(['n-req', 'n-deal']));
    });

    test('markAsRead and markAllAsRead update the cached rows', () async {
      final repository = NotificationRepository(
        apiClient: _api(_rows(), once: true),
        storage: MockSecureStorageService(),
      );
      await repository.fetchNotifications();

      expect(await repository.markAsRead('n-req'), isTrue);
      final afterOne = await repository.fetchNotifications(unreadOnly: true);
      expect(afterOne.map((n) => n.id), ['n-deal']);

      expect(await repository.markAllAsRead(), 1);
      expect(await repository.fetchNotifications(unreadOnly: true), isEmpty);
    });
  });
}
