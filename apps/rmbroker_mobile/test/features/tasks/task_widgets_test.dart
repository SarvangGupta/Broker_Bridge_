import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/tasks/data/task_repository.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_category.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_filter.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_model.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_priority.dart';
import 'package:rmbroker_mobile/features/tasks/domain/task_status.dart';
import 'package:rmbroker_mobile/features/tasks/presentation/controllers/task_controller.dart';
import 'package:rmbroker_mobile/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:rmbroker_mobile/features/tasks/presentation/screens/task_list_screen.dart';
import 'package:rmbroker_mobile/features/tasks/presentation/widgets/create_task_sheet.dart';
import 'package:rmbroker_mobile/features/tasks/presentation/widgets/linked_record_card.dart';
import 'package:rmbroker_mobile/features/tasks/presentation/widgets/task_card.dart';

class MockTaskRepository extends TaskRepository {
  final List<BrokerTask> items;

  MockTaskRepository({required this.items});

  @override
  Future<List<BrokerTask>> fetchTasks({TaskFilterCriteria? criteria}) async {
    if (criteria == null) return List.unmodifiable(items);
    return items.where(criteria.matches).toList();
  }

  @override
  Future<BrokerTask?> getTaskById(String taskId) async {
    final match = items.where((t) => t.id == taskId);
    return match.isNotEmpty ? match.first : null;
  }

  @override
  Future<BrokerTask> markTaskComplete(String taskId) async {
    final idx = items.indexWhere((t) => t.id == taskId);
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime.now(),
      );
      return items[idx];
    }
    throw Exception('Task not found');
  }

  @override
  Future<BrokerTask> reopenTask(String taskId) async {
    final idx = items.indexWhere((t) => t.id == taskId);
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(
        status: TaskStatus.open,
        clearCompletedAt: true,
      );
      return items[idx];
    }
    throw Exception('Task not found');
  }

  @override
  Future<BrokerTask> cancelTask(String taskId) async {
    final idx = items.indexWhere((t) => t.id == taskId);
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(status: TaskStatus.cancelled);
      return items[idx];
    }
    throw Exception('Task not found');
  }

  @override
  Future<BrokerTask> createTask(BrokerTask task) async {
    final created = task.copyWith(
      id: 'mock-created-${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
    );
    items.insert(0, created);
    return created;
  }
}

void main() {
  final now = DateTime.now();

  List<BrokerTask> generateTestTasks() {
    return [
      BrokerTask(
        id: 'tsk-2026-001',
        brokerId: 'broker-1',
        contactId: 'cnt-1',
        contactName: 'Sharma Agro Mills Ltd',
        title: 'Call buyer regarding final sign-off on Deal DL-2026-0891',
        description: 'Buyer requested clarification on moisture deduction FAQ standards.',
        dueDate: now.subtract(const Duration(days: 1)), // Overdue
        priority: TaskPriority.urgent,
        status: TaskStatus.open,
        category: TaskCategory.dealFollowUp,
        linkedRecord: const TaskLinkedRecord(
          type: LinkedRecordType.deal,
          id: 'deal-bkg-0042',
          reference: 'DL-2026-0891',
          title: '50 MT Mustard Seed (Grade-A Bold)',
          currentStatus: 'Awaiting Confirmation',
          isAccessible: true,
          route: '/deals/deal-bkg-0042',
        ),
        createdAt: now.subtract(const Duration(days: 2)),
        history: [
          TaskHistoryEntry(
            id: 'h-1',
            action: 'created',
            description: 'Task created for Deal DL-2026-0891',
            actor: 'Broker Desk',
            timestamp: now.subtract(const Duration(days: 2)),
          ),
        ],
      ),
      BrokerTask(
        id: 'tsk-2026-002',
        brokerId: 'broker-1',
        contactId: 'cnt-2',
        contactName: 'Hadoti Agro Farmer Producer Co',
        title: 'Confirm truck loading readiness at Kota Mandi',
        description: 'Vehicle RJ-14-GA-8821 scheduled for loading.',
        dueDate: DateTime(now.year, now.month, now.day, 23, 59, 59), // Due today
        priority: TaskPriority.high,
        status: TaskStatus.inProgress,
        category: TaskCategory.dispatchTracking,
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      BrokerTask(
        id: 'tsk-2026-003',
        brokerId: 'broker-1',
        contactId: 'cnt-3',
        contactName: 'Marwar Edible Oils Pvt Ltd',
        title: 'Follow up on payment for Invoice INV-2026-0043',
        description: 'Brokerage invoice of ₹2,000 due.',
        dueDate: now.add(const Duration(days: 4)), // Upcoming
        priority: TaskPriority.normal,
        status: TaskStatus.open,
        category: TaskCategory.paymentCollection,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  Widget createTestWidget({required Widget child, TaskRepository? repository}) {
    final repo = repository ?? MockTaskRepository(items: generateTestTasks());
    return ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Task UI & Widget Tests (Sprint RB-FL-14)', () {
    testWidgets('TaskListScreen renders header, KPI dashboard, filter bar, and task cards', (tester) async {
      await tester.pumpWidget(
        createTestWidget(child: const TaskListScreen()),
      );
      await tester.pumpAndSettle();

      // Verify AppBar title
      expect(find.text('Broker Tasks & Follow-ups'), findsOneWidget);

      // Verify Action Item Summary section
      expect(find.text('Action Item Summary'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Due Today'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('High / Urgent Priority'), findsOneWidget);
      expect(find.text('Concluded Actions'), findsOneWidget);

      // Verify filter bar
      expect(find.text('All Statuses'), findsOneWidget);
      expect(find.text('All Categories'), findsOneWidget);
      expect(find.text('All Priorities'), findsOneWidget);

      // Verify transparency notice
      expect(find.textContaining('Push reminders unsupported on backend'), findsOneWidget);

      // Verify task cards
      expect(find.byType(TaskCard), findsWidgets);
      expect(find.text('New Task'), findsOneWidget);
    });

    testWidgets('Tapping quick-toggle complete on TaskCard updates task visual status', (tester) async {
      final mockRepo = MockTaskRepository(items: generateTestTasks());
      await tester.pumpWidget(
        createTestWidget(
          child: const TaskListScreen(),
          repository: mockRepo,
        ),
      );
      await tester.pumpAndSettle();

      final firstTask = mockRepo.items.first;
      expect(firstTask.status, TaskStatus.open);

      final toggleFinder = find.byKey(ValueKey('task_toggle_${firstTask.id}'));
      expect(toggleFinder, findsOneWidget);

      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Verify mockRepo status was updated to completed
      expect(mockRepo.items.first.status, TaskStatus.completed);
    });

    testWidgets('CreateTaskSheet validates required title and shows reminder disclosure', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockTaskRepository(items: []);
      bool submitted = false;

      await tester.pumpWidget(
        createTestWidget(
          child: Scaffold(
            body: CreateTaskSheet(
              repository: repository,
              onSubmit: ({
                required String title,
                String description = '',
                required DateTime dueDate,
                required TaskPriority priority,
                required TaskCategory category,
                TaskLinkedRecord? linkedRecord,
              }) async {
                submitted = true;
              },
            ),
          ),
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Schedule Follow-up Action'), findsOneWidget);
      expect(find.text('Task Title / Action Required *'), findsOneWidget);
      expect(find.text('Priority Level'), findsOneWidget);
      expect(find.textContaining('Scheduled push notifications are unsupported'), findsOneWidget);

      // Attempt to submit with empty title
      final submitButton = find.text('Save Follow-up Task');
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Form validation error appears
      expect(find.text('Task title must be at least 2 characters'), findsOneWidget);
      expect(submitted, isFalse);

      // Enter valid title
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, 'Call seller on truck dispatch');
      await tester.pumpAndSettle();

      // Submit again
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      expect(submitted, isTrue);
    });

    testWidgets('LinkedRecordCard renders reference, status, and expired warnings', (tester) async {
      const activeRecord = TaskLinkedRecord(
        type: LinkedRecordType.deal,
        id: 'deal-1',
        reference: 'DL-2026-0891',
        title: '50 MT Mustard Seed',
        currentStatus: 'Awaiting Confirmation',
        isAccessible: true,
      );

      const expiredRecord = TaskLinkedRecord(
        type: LinkedRecordType.offer,
        id: 'off-1',
        reference: 'OFF-2026-0220',
        title: '40 MT Yellow Soyabean',
        currentStatus: 'Expired',
        isAccessible: false,
        statusNotice: 'Seller lot expired yesterday.',
      );

      await tester.pumpWidget(
        createTestWidget(
          child: const Scaffold(
            body: Column(
              children: [
                LinkedRecordCard(linkedRecord: activeRecord),
                LinkedRecordCard(linkedRecord: expiredRecord),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DL-2026-0891'), findsOneWidget);
      expect(find.text('Awaiting Confirmation'), findsOneWidget);
      expect(find.text('OFF-2026-0220'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Seller lot expired yesterday.'), findsOneWidget);
    });

    testWidgets('TaskDetailScreen renders task overview, data isolation notice, and actions', (tester) async {
      final mockRepo = MockTaskRepository(items: generateTestTasks());

      await tester.pumpWidget(
        createTestWidget(
          child: const TaskDetailScreen(taskId: 'tsk-2026-001'),
          repository: mockRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Task & Follow-up Details'), findsOneWidget);
      expect(find.textContaining('Call buyer regarding final sign-off'), findsOneWidget);
      expect(find.text('Instructions / Notes'), findsOneWidget);
      expect(find.textContaining('Data Isolation Gate'), findsOneWidget);
      expect(find.text('Mark Task Completed'), findsOneWidget);
      expect(find.text('Edit Fields'), findsOneWidget);
      expect(find.text('Cancel Task'), findsOneWidget);
      expect(find.text('Task History & Audit Log'), findsOneWidget);
    });
  });
}
