import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_category.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_filter.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_model.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_priority.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_status.dart';

void main() {
  group('My Tasks Tab & Filter Logic', () {
    final now = DateTime.now();

    final overdueTask = BrokerTask(
      id: 'task-1',
      brokerId: 'broker-1',
      title: 'Call buyer for final sign-off',
      description: 'Buyer requested clarification on moisture deduction before signing.',
      dueDate: now.subtract(const Duration(hours: 3)),
      priority: TaskPriority.urgent,
      status: TaskStatus.open,
      category: TaskCategory.dealFollowUp,
      linkedRecord: const TaskLinkedRecord(
        type: LinkedRecordType.deal,
        id: 'deal-1',
        reference: 'DL-2026-0891',
        title: 'Sharma Agro Mills',
        currentStatus: 'Active',
      ),
      createdAt: now.subtract(const Duration(days: 1)),
    );

    final dueTodayTask = BrokerTask(
      id: 'task-2',
      brokerId: 'broker-1',
      title: 'Confirm truck loading readiness',
      description: 'Coordinate with warehouse and confirm vehicle availability.',
      dueDate: now.add(const Duration(hours: 2)),
      priority: TaskPriority.high,
      status: TaskStatus.inProgress,
      category: TaskCategory.dispatchTracking,
      createdAt: now.subtract(const Duration(hours: 4)),
    );

    final upcomingTask = BrokerTask(
      id: 'task-3',
      brokerId: 'broker-1',
      contactName: 'Rohan Traders',
      title: 'Share updated price with buyer',
      description: 'Send latest maize price and confirm interest for 50 MT.',
      dueDate: now.add(const Duration(days: 1, hours: 2)),
      priority: TaskPriority.normal,
      status: TaskStatus.open,
      category: TaskCategory.dealFollowUp,
      createdAt: now.subtract(const Duration(days: 2)),
    );

    final completedTask = BrokerTask(
      id: 'task-4',
      brokerId: 'broker-1',
      title: 'Completed archive inspection',
      description: 'Stock inspection done yesterday.',
      dueDate: now.subtract(const Duration(days: 1)),
      priority: TaskPriority.low,
      status: TaskStatus.completed,
      category: TaskCategory.offerInspection,
      completedAt: now.subtract(const Duration(hours: 1)),
      createdAt: now.subtract(const Duration(days: 3)),
    );

    final allTasks = [overdueTask, dueTodayTask, upcomingTask, completedTask];

    test('Today tab includes overdue and due today, excludes upcoming and completed', () {
      const criteria = TaskFilterCriteria(activeTab: MyTasksTab.today);

      expect(criteria.matches(overdueTask), isTrue);
      expect(criteria.matches(dueTodayTask), isTrue);
      expect(criteria.matches(upcomingTask), isFalse);
      expect(criteria.matches(completedTask), isFalse);
    });

    test('Upcoming tab includes only incomplete tasks due after today', () {
      const criteria = TaskFilterCriteria(activeTab: MyTasksTab.upcoming);

      expect(criteria.matches(overdueTask), isFalse);
      expect(criteria.matches(dueTodayTask), isFalse);
      expect(criteria.matches(upcomingTask), isTrue);
      expect(criteria.matches(completedTask), isFalse);
    });

    test('All tab includes all tasks, both open and completed', () {
      const criteria = TaskFilterCriteria(activeTab: MyTasksTab.all);

      expect(criteria.matches(overdueTask), isTrue);
      expect(criteria.matches(dueTodayTask), isTrue);
      expect(criteria.matches(upcomingTask), isTrue);
      expect(criteria.matches(completedTask), isTrue);
    });

    test('TaskDashboardSummary calculates correct Overdue, Due today, and Done counts', () {
      final summary = TaskDashboardSummary.fromTasks(allTasks);

      expect(summary.overdueCount, equals(1));
      expect(summary.dueTodayCount, equals(1));
      expect(summary.recentlyCompletedCount, equals(1));
      expect(summary.upcomingCount, equals(1));
    });

    test('Search query matches title, description, contactName, and linkedRecord reference', () {
      // Search by title
      final titleSearch = const TaskFilterCriteria(
        activeTab: MyTasksTab.all,
        searchQuery: 'truck loading',
      );
      expect(titleSearch.matches(dueTodayTask), isTrue);
      expect(titleSearch.matches(overdueTask), isFalse);

      // Search by description notes
      final descSearch = const TaskFilterCriteria(
        activeTab: MyTasksTab.all,
        searchQuery: 'moisture deduction',
      );
      expect(descSearch.matches(overdueTask), isTrue);
      expect(descSearch.matches(dueTodayTask), isFalse);

      // Search by linked record ref
      final refSearch = const TaskFilterCriteria(
        activeTab: MyTasksTab.all,
        searchQuery: 'DL-2026-0891',
      );
      expect(refSearch.matches(overdueTask), isTrue);
      expect(refSearch.matches(dueTodayTask), isFalse);

      // Search by counterparty contact name
      final contactSearch = const TaskFilterCriteria(
        activeTab: MyTasksTab.all,
        searchQuery: 'Rohan Traders',
      );
      expect(contactSearch.matches(upcomingTask), isTrue);
      expect(contactSearch.matches(dueTodayTask), isFalse);
    });

    test('Completing a task moves it out of Today tab', () {
      const todayCriteria = TaskFilterCriteria(activeTab: MyTasksTab.today);

      // Initially active
      expect(todayCriteria.matches(overdueTask), isTrue);

      // Completed
      final markedDone = overdueTask.copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime.now(),
      );

      expect(todayCriteria.matches(markedDone), isFalse);

      // But still in All tab
      const allCriteria = TaskFilterCriteria(activeTab: MyTasksTab.all);
      expect(allCriteria.matches(markedDone), isTrue);
    });
  });
}
