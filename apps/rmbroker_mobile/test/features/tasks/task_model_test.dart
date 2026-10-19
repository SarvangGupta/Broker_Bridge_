import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_category.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_filter.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_model.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_priority.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_status.dart';

void main() {
  group('BrokerTask Domain Model & Due Date Tests (Sprint RB-FL-14)', () {
    final now = DateTime.now();

    test('Overdue logic: active task in past is overdue; completed task is NEVER overdue', () {
      final pastDate = now.subtract(const Duration(hours: 5));

      final activePastTask = BrokerTask(
        id: 't-1',
        brokerId: 'b-1',
        title: 'Call buyer on dispatch delay',
        dueDate: pastDate,
        status: TaskStatus.open,
        createdAt: now.subtract(const Duration(days: 1)),
      );

      final completedPastTask = BrokerTask(
        id: 't-2',
        brokerId: 'b-1',
        title: 'Review moisture report',
        dueDate: pastDate,
        status: TaskStatus.completed,
        completedAt: now.subtract(const Duration(hours: 1)),
        createdAt: now.subtract(const Duration(days: 1)),
      );

      final cancelledPastTask = BrokerTask(
        id: 't-3',
        brokerId: 'b-1',
        title: 'Old inquiry',
        dueDate: pastDate,
        status: TaskStatus.cancelled,
        createdAt: now.subtract(const Duration(days: 1)),
      );

      expect(activePastTask.isOverdue, isTrue);
      expect(activePastTask.isUpcoming, isFalse);

      // CRITICAL: Completed & cancelled tasks must NEVER be marked overdue
      expect(completedPastTask.isOverdue, isFalse);
      expect(cancelledPastTask.isOverdue, isFalse);
    });

    test('Due today and upcoming calculation', () {
      final dueTodayTime = DateTime(now.year, now.month, now.day, 23, 0);
      final dueNextWeek = now.add(const Duration(days: 7));

      final todayTask = BrokerTask(
        id: 't-today',
        brokerId: 'b-1',
        title: 'Confirm booking contract',
        dueDate: dueTodayTime,
        status: TaskStatus.inProgress,
        createdAt: now,
      );

      final upcomingTask = BrokerTask(
        id: 't-upcoming',
        brokerId: 'b-1',
        title: 'Check renewal lot',
        dueDate: dueNextWeek,
        status: TaskStatus.open,
        createdAt: now,
      );

      expect(todayTask.isDueToday, isTrue);
      expect(upcomingTask.isDueToday, isFalse);
      expect(upcomingTask.isUpcoming, isTrue);
      expect(upcomingTask.isOverdue, isFalse);
    });

    test('TaskPriority parsing and backend serialization', () {
      expect(TaskPriority.fromString('low'), TaskPriority.low);
      expect(TaskPriority.fromString('normal'), TaskPriority.normal);
      expect(TaskPriority.fromString('medium'), TaskPriority.normal);
      expect(TaskPriority.fromString('high'), TaskPriority.high);
      expect(TaskPriority.fromString('urgent'), TaskPriority.urgent);
      expect(TaskPriority.fromString('critical'), TaskPriority.urgent);
      expect(TaskPriority.fromString(null), TaskPriority.normal);

      expect(TaskPriority.low.toBackendString(), 'Low');
      expect(TaskPriority.normal.toBackendString(), 'Normal');
      expect(TaskPriority.high.toBackendString(), 'High');
      expect(TaskPriority.urgent.toBackendString(), 'Urgent');
    });

    test('TaskStatus transitions and backend serialization', () {
      expect(TaskStatus.fromString('open'), TaskStatus.open);
      expect(TaskStatus.fromString('pending'), TaskStatus.open);
      expect(TaskStatus.fromString('in_progress'), TaskStatus.inProgress);
      expect(TaskStatus.fromString('waiting'), TaskStatus.waiting);
      expect(TaskStatus.fromString('completed'), TaskStatus.completed);
      expect(TaskStatus.fromString('cancelled'), TaskStatus.cancelled);

      expect(TaskStatus.open.isActive, isTrue);
      expect(TaskStatus.inProgress.isActive, isTrue);
      expect(TaskStatus.waiting.isActive, isTrue);
      expect(TaskStatus.completed.isActive, isFalse);
      expect(TaskStatus.completed.isClosed, isTrue);
      expect(TaskStatus.cancelled.isClosed, isTrue);

      expect(TaskStatus.open.toBackendString(), 'Pending');
      expect(TaskStatus.inProgress.toBackendString(), 'In Progress');
      expect(TaskStatus.waiting.toBackendString(), 'Waiting');
      expect(TaskStatus.completed.toBackendString(), 'Completed');
      expect(TaskStatus.cancelled.toBackendString(), 'Cancelled');
    });

    test('TaskCategory parsing and labels', () {
      expect(TaskCategory.fromString('deal'), TaskCategory.dealFollowUp);
      expect(TaskCategory.fromString('mandate'), TaskCategory.mandateMatching);
      expect(TaskCategory.fromString('offer'), TaskCategory.offerInspection);
      expect(TaskCategory.fromString('dispatch'), TaskCategory.dispatchTracking);
      expect(TaskCategory.fromString('invoice'), TaskCategory.paymentCollection);
      expect(TaskCategory.fromString('dispute'), TaskCategory.disputeMediation);
      expect(TaskCategory.fromString('counterparty'), TaskCategory.counterpartyCall);
      expect(TaskCategory.fromString('general'), TaskCategory.general);
    });

    test('BrokerTask full serialization to/from JSON and PostgreSQL columns', () {
      final dueDate = DateTime.utc(2026, 10, 20, 10, 30);
      final createdAt = DateTime.utc(2026, 10, 18, 14, 0);

      final task = BrokerTask(
        id: 'tsk-test-101',
        brokerId: 'broker-uuid-1',
        contactId: 'cnt-uuid-2',
        contactName: 'Sharma Agro Mills Ltd',
        title: 'Review E-Way Bill and Dispatch Bilties',
        description: 'Verify tare weight matches mandi gate record.',
        dueDate: dueDate,
        priority: TaskPriority.high,
        status: TaskStatus.open,
        category: TaskCategory.dispatchTracking,
        linkedRecord: const TaskLinkedRecord(
          type: LinkedRecordType.deal,
          id: 'deal-001',
          reference: 'DL-2026-0891',
          title: '50 MT Mustard Seed',
          currentStatus: 'In Transit',
          isAccessible: true,
          route: '/deals/deal-001',
        ),
        createdAt: createdAt,
        history: [
          TaskHistoryEntry(
            id: 'h-1',
            action: 'created',
            description: 'Task logged for logistics',
            actor: 'Broker Desk',
            timestamp: createdAt,
          ),
        ],
      );

      final json = task.toJson();
      expect(json['id'], 'tsk-test-101');
      expect(json['brokerId'], 'broker-uuid-1');
      expect(json['priority'], 'High');
      expect(json['status'], 'Pending');
      expect(json['linkedRecord']['reference'], 'DL-2026-0891');

      // Reconstruct
      final parsed = BrokerTask.fromJson(json);
      expect(parsed.id, task.id);
      expect(parsed.brokerId, task.brokerId);
      expect(parsed.contactName, 'Sharma Agro Mills Ltd');
      expect(parsed.title, task.title);
      expect(parsed.description, task.description);
      expect(parsed.priority, TaskPriority.high);
      expect(parsed.status, TaskStatus.open);
      expect(parsed.linkedRecord?.reference, 'DL-2026-0891');
      expect(parsed.linkedRecord?.currentStatus, 'In Transit');
      expect(parsed.history.length, 1);

      // Postgres columns insert map
      final pgMap = task.toSupabaseInsert();
      expect(pgMap['broker_id'], 'broker-uuid-1');
      expect(pgMap['contact_id'], 'cnt-uuid-2');
      expect(pgMap['status'], 'Pending');
      expect(pgMap['title'], contains('Review E-Way Bill'));
      expect(pgMap['title'], contains('Verify tare weight'));
    });

    test('TaskFilterCriteria accurately filters tasks by text, status, priority, and date', () {
      final pastDate = now.subtract(const Duration(days: 2));
      final todayTime = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final futureDate = now.add(const Duration(days: 3));

      final task1 = BrokerTask(
        id: '1',
        brokerId: 'b',
        title: 'Sharma Agro invoice payment',
        dueDate: pastDate,
        priority: TaskPriority.urgent,
        status: TaskStatus.open,
        category: TaskCategory.paymentCollection,
        createdAt: now,
      );

      final task2 = BrokerTask(
        id: '2',
        brokerId: 'b',
        title: 'Kota Mandi loading inspection',
        dueDate: todayTime,
        priority: TaskPriority.normal,
        status: TaskStatus.inProgress,
        category: TaskCategory.dispatchTracking,
        createdAt: now,
      );

      final task3 = BrokerTask(
        id: '3',
        brokerId: 'b',
        title: 'Hadoti Agro renewed lot',
        dueDate: futureDate,
        priority: TaskPriority.low,
        status: TaskStatus.completed,
        category: TaskCategory.offerInspection,
        createdAt: now,
      );

      final list = [task1, task2, task3];

      // Filter by search query
      final filterSharma = const TaskFilterCriteria(searchQuery: 'Sharma');
      expect(list.where(filterSharma.matches).length, 1);
      expect(list.where(filterSharma.matches).first.id, '1');

      // Filter by priority
      final filterUrgent = const TaskFilterCriteria(priorityFilter: TaskPriority.urgent);
      expect(list.where(filterUrgent.matches).length, 1);
      expect(list.where(filterUrgent.matches).first.id, '1');

      // Filter by status
      final filterCompleted = const TaskFilterCriteria(statusFilter: TaskStatus.completed);
      expect(list.where(filterCompleted.matches).length, 1);
      expect(list.where(filterCompleted.matches).first.id, '3');

      // Filter by date: Overdue
      final filterOverdue = const TaskFilterCriteria(dateFilter: TaskDateFilter.overdue);
      expect(list.where(filterOverdue.matches).length, 1);
      expect(list.where(filterOverdue.matches).first.id, '1');

      // Filter by date: Due Today
      final filterToday = const TaskFilterCriteria(dateFilter: TaskDateFilter.today);
      expect(list.where(filterToday.matches).length, 1);
      expect(list.where(filterToday.matches).first.id, '2');

      // Filter by date: Upcoming (completed items excluded from upcoming)
      final filterUpcoming = const TaskFilterCriteria(dateFilter: TaskDateFilter.upcoming);
      expect(list.where(filterUpcoming.matches).length, 0);
    });

    test('TaskDashboardSummary accurately calculates 5 KPI counts matching authorized records', () {
      final pastDate = now.subtract(const Duration(days: 2));
      final todayTime = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final futureDate = now.add(const Duration(days: 3));

      final tasks = [
        BrokerTask(
          id: '1',
          brokerId: 'b',
          title: 'Task 1 Overdue Urgent',
          dueDate: pastDate,
          priority: TaskPriority.urgent,
          status: TaskStatus.open,
          createdAt: now,
        ),
        BrokerTask(
          id: '2',
          brokerId: 'b',
          title: 'Task 2 Due Today High',
          dueDate: todayTime,
          priority: TaskPriority.high,
          status: TaskStatus.inProgress,
          createdAt: now,
        ),
        BrokerTask(
          id: '3',
          brokerId: 'b',
          title: 'Task 3 Upcoming Normal',
          dueDate: futureDate,
          priority: TaskPriority.normal,
          status: TaskStatus.open,
          createdAt: now,
        ),
        BrokerTask(
          id: '4',
          brokerId: 'b',
          title: 'Task 4 Completed',
          dueDate: pastDate,
          priority: TaskPriority.low,
          status: TaskStatus.completed,
          createdAt: now,
        ),
      ];

      final summary = TaskDashboardSummary.fromTasks(tasks);

      expect(summary.totalCount, 4);
      expect(summary.overdueCount, 1); // task 1
      expect(summary.dueTodayCount, 1); // task 2
      expect(summary.upcomingCount, 1); // task 3
      expect(summary.highPriorityOpenCount, 2); // task 1 (urgent) + task 2 (high)
      expect(summary.recentlyCompletedCount, 1); // task 4
    });
  });
}
