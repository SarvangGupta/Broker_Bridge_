import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/tasks/data/task_repository.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_category.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_model.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_priority.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_status.dart';

void main() {
  group('TaskRepository Operations & Data Integrity Tests (Sprint RB-FL-14)', () {
    late TaskRepository repository;

    setUp(() {
      repository = TaskRepository();
    });

    test('fetchTasks returns seeded authorized broker tasks with business links', () async {
      final tasks = await repository.fetchTasks();

      expect(tasks, isNotEmpty);
      expect(tasks.length, greaterThanOrEqualTo(5));

      // Verify at least one task is overdue and one is due today
      final overdueCount = tasks.where((t) => t.isOverdue).length;
      final dueTodayCount = tasks.where((t) => t.isDueToday).length;

      expect(overdueCount, greaterThan(0));
      expect(dueTodayCount, greaterThan(0));

      // Verify presence of linked business records
      final tasksWithLinks = tasks.where((t) => t.linkedRecord != null);
      expect(tasksWithLinks.length, greaterThan(0));
    });

    test('createTask saves new task with audit trail history', () async {
      final now = DateTime.now();
      final newTask = BrokerTask(
        id: 'tsk-custom-999',
        brokerId: 'broker-demo-user',
        title: 'Check laboratory aflatoxin report for Mustard Seed lot',
        description: 'Ensure lab report is uploaded before generating formal contract.',
        dueDate: now.add(const Duration(hours: 4)),
        priority: TaskPriority.high,
        category: TaskCategory.dealFollowUp,
        linkedRecord: const TaskLinkedRecord(
          type: LinkedRecordType.deal,
          id: 'deal-bkg-0042',
          reference: 'DL-2026-0891',
          title: '50 MT Mustard Seed',
          currentStatus: 'Awaiting Confirmation',
          isAccessible: true,
        ),
        createdAt: now,
      );

      final created = await repository.createTask(newTask);

      expect(created.id, 'tsk-custom-999');
      expect(created.title, contains('laboratory aflatoxin'));
      expect(created.history, isNotEmpty);
      expect(created.history.first.action, 'created');

      // Verify retrieval
      final fetched = await repository.getTaskById('tsk-custom-999');
      expect(fetched, isNotNull);
      expect(fetched!.title, created.title);
    });

    test('Duplicate task submission within debounce window throws DuplicateTaskSubmissionException', () async {
      final now = DateTime.now();
      final task = BrokerTask(
        id: 'tsk-dup-1',
        brokerId: 'broker-demo-user',
        title: 'Double-click duplicate test task',
        dueDate: now.add(const Duration(hours: 8)),
        createdAt: now,
      );

      // First creation succeeds
      await repository.createTask(task);

      // Second immediate creation with same key throws
      expect(
        () => repository.createTask(task),
        throwsA(isA<DuplicateTaskSubmissionException>()),
      );
    });

    test('Status transitions: markComplete, reopenTask, cancelTask with audit logging', () async {
      final tasks = await repository.fetchTasks();
      final openTask = tasks.firstWhere((t) => t.status == TaskStatus.open);

      // 1. Mark complete
      final completed = await repository.markTaskComplete(openTask.id);
      expect(completed.status, TaskStatus.completed);
      expect(completed.completedAt, isNotNull);
      expect(completed.history.first.action, 'completed');
      expect(completed.isOverdue, isFalse);

      // 2. Reopen
      final reopened = await repository.reopenTask(openTask.id);
      expect(reopened.status, TaskStatus.open);
      expect(reopened.completedAt, isNull);
      expect(reopened.history.first.action, 'reopened');

      // 3. Cancel
      final cancelled = await repository.cancelTask(openTask.id);
      expect(cancelled.status, TaskStatus.cancelled);
      expect(cancelled.history.first.action, 'cancelled');
    });

    test('DATA INTEGRITY: Completing task DOES NOT change linked deal or financial record state', () async {
      final tasks = await repository.fetchTasks();
      final dealTask = tasks.firstWhere(
        (t) => t.linkedRecord != null && t.linkedRecord!.type == LinkedRecordType.deal,
      );

      final originalRecordStatus = dealTask.linkedRecord!.currentStatus;

      // Complete the task
      final completedTask = await repository.markTaskComplete(dealTask.id);

      // Task status updated
      expect(completedTask.status, TaskStatus.completed);

      // Linked business record state remains strictly preserved and unchanged
      expect(completedTask.linkedRecord!.currentStatus, originalRecordStatus);
      expect(
        completedTask.history.first.description,
        contains('No deal or financial state mutated'),
      );
    });

    test('Scheduled push reminders capability is honestly reported as unsupported', () {
      expect(repository.scheduledPushRemindersSupported, isFalse);
      expect(
        repository.reminderCapabilityNotice,
        contains('Scheduled push notifications are unsupported by the backend infrastructure'),
      );
      expect(
        repository.reminderCapabilityNotice,
        contains('calculated in-app'),
      );
    });

    test('getAvailableLinkedRecords returns verified desk business records', () {
      final records = repository.getAvailableLinkedRecords();
      expect(records, isNotEmpty);

      // Check various record types are supported
      final types = records.map((r) => r.type).toSet();
      expect(types, contains(LinkedRecordType.deal));
      expect(types, contains(LinkedRecordType.counterparty));
      expect(types, contains(LinkedRecordType.requirement));
      expect(types, contains(LinkedRecordType.offer));
      expect(types, contains(LinkedRecordType.invoice));
      expect(types, contains(LinkedRecordType.dispute));
    });
  });
}
