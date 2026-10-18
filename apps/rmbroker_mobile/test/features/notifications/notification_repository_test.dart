import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/notifications/data/notification_repository.dart';
import 'package:rmbroker_mobile/features/notifications/domain/notification_category.dart';

void main() {
  late NotificationRepository repository;

  setUp(() {
    repository = NotificationRepository();
  });

  group('NotificationRepository Tests', () {
    test('fetchNotifications returns verified broker events sorted newest-first', () async {
      final notifs = await repository.fetchNotifications();

      expect(notifs, isNotEmpty);
      expect(notifs.length, greaterThanOrEqualTo(5));

      // Verify newest-first sort
      for (int i = 0; i < notifs.length - 1; i++) {
        expect(
          notifs[i].createdAt.isAfter(notifs[i + 1].createdAt) ||
              notifs[i].createdAt.isAtSameMomentAs(notifs[i + 1].createdAt),
          isTrue,
          reason: 'Notification index $i should be newer than index ${i + 1}',
        );
      }
    });

    test('fetchNotifications filters by category accurately', () async {
      final dealNotifs = await repository.fetchNotifications(
        category: NotificationCategory.dealsAndConfirmations,
      );

      expect(dealNotifs, isNotEmpty);
      for (final n in dealNotifs) {
        expect(n.category, NotificationCategory.dealsAndConfirmations);
      }

      final commNotifs = await repository.fetchNotifications(
        category: NotificationCategory.commissionAndInvoices,
      );

      expect(commNotifs, isNotEmpty);
      for (final n in commNotifs) {
        expect(n.category, NotificationCategory.commissionAndInvoices);
      }
    });

    test('fetchNotifications filters by unreadOnly flag', () async {
      final unreadNotifs = await repository.fetchNotifications(unreadOnly: true);

      expect(unreadNotifs, isNotEmpty);
      for (final n in unreadNotifs) {
        expect(n.isRead, isFalse);
      }
    });

    test('markAsRead updates item in-memory and sets read timestamp', () async {
      final before = await repository.fetchNotifications();
      final unreadItem = before.firstWhere((n) => !n.isRead);

      final success = await repository.markAsRead(unreadItem.id);
      expect(success, isTrue);

      final after = await repository.fetchNotifications();
      final updatedItem = after.firstWhere((n) => n.id == unreadItem.id);

      expect(updatedItem.isRead, isTrue);
      expect(updatedItem.readAt, isNotNull);
    });

    test('markAllAsRead sets all unread notifications to read and returns count', () async {
      final beforeUnread = await repository.fetchNotifications(unreadOnly: true);
      expect(beforeUnread, isNotEmpty);
      final countToUpdate = beforeUnread.length;

      final updatedCount = await repository.markAllAsRead();
      expect(updatedCount, countToUpdate);

      final afterUnread = await repository.fetchNotifications(unreadOnly: true);
      expect(afterUnread, isEmpty);
    });
  });
}
