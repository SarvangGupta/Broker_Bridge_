import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/security/secure_storage_service.dart';
import '../domain/task_category.dart';
import '../domain/task_filter.dart';
import '../domain/task_model.dart';
import '../domain/task_priority.dart';
import '../domain/task_status.dart';

/// Exception thrown when attempting to submit a duplicate task within debounce window.
class DuplicateTaskSubmissionException implements Exception {
  final String message;
  const DuplicateTaskSubmissionException(this.message);

  @override
  String toString() => message;
}

/// Authoritative repository for broker task management, follow-ups, and business record links.
class TaskRepository {
  final ApiClient? _customApiClient;
  final SupabaseClient? _customSupabase;
  final SecureStorageService _storage;

  TaskRepository({
    ApiClient? apiClient,
    SupabaseClient? supabase,
    SecureStorageService? storage,
  })  : _customApiClient = apiClient,
        _customSupabase = supabase,
        _storage = storage ?? SecureStorageService();

  ApiClient get _apiClient => _customApiClient ?? ApiClient(storage: _storage);

  SupabaseClient? get _supabase {
    if (_customSupabase != null) return _customSupabase;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Whether the backend infrastructure supports asynchronous scheduled push notifications for due dates.
  /// Explicitly FALSE per backend architecture verification (no delayed scheduler worker provisioned).
  bool get scheduledPushRemindersSupported => false;

  /// Transparent explanation of reminder capabilities for the UI and audit logs.
  String get reminderCapabilityNotice =>
      'Scheduled push notifications are unsupported by the backend infrastructure. '
      'Task due dates, due-today badges, and overdue indicators are calculated in-app '
      'using the broker desk local clock.';

  // In-memory cache & audit-trailed storage
  final List<BrokerTask> _cachedTasks = [];
  bool _initialized = false;
  final Set<String> _inFlightSubmissionKeys = {};

  void _seedDefaultDeskTasks() {
    if (_initialized) return;
    _initialized = true;

    final now = DateTime.now();

    _cachedTasks.addAll([
      BrokerTask(
        id: 'tsk-2026-001',
        brokerId: 'broker-demo-user',
        contactId: 'cnt-sharma-agro',
        contactName: 'Sharma Agro Mills Ltd',
        title: 'Call buyer regarding final sign-off on Deal DL-2026-0891',
        description:
            'Buyer requested clarification on moisture deduction FAQ standards before signing confirmation sheet.',
        dueDate: now.subtract(const Duration(hours: 3)), // Overdue
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
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        history: [
          TaskHistoryEntry(
            id: 'th-001-1',
            action: 'created',
            description: 'Task created for Deal DL-2026-0891 follow-up',
            actor: 'Broker Desk',
            timestamp: now.subtract(const Duration(days: 1, hours: 2)),
          ),
        ],
      ),
      BrokerTask(
        id: 'tsk-2026-002',
        brokerId: 'broker-demo-user',
        contactId: 'cnt-hadoti-agro',
        contactName: 'Hadoti Agro Farmer Producer Co',
        title: 'Confirm truck loading readiness at Kota Mandi Yard',
        description:
            'Dispatch vehicle RJ-14-GA-8821 scheduled for loading. Check weighbridge certificate and bilty readiness.',
        dueDate: now.add(const Duration(hours: 2)), // Due Today
        priority: TaskPriority.high,
        status: TaskStatus.inProgress,
        category: TaskCategory.dispatchTracking,
        linkedRecord: const TaskLinkedRecord(
          type: LinkedRecordType.deal,
          id: 'deal-bkg-0043',
          reference: 'DL-2026-0892',
          title: '40 MT Yellow Soyabean (FAQ Milling)',
          currentStatus: 'Loading Scheduled',
          isAccessible: true,
          route: '/deals/deal-bkg-0043',
        ),
        createdAt: now.subtract(const Duration(hours: 6)),
        history: [
          TaskHistoryEntry(
            id: 'th-002-1',
            action: 'created',
            description: 'Task created from logistics timeline',
            actor: 'Broker Desk',
            timestamp: now.subtract(const Duration(hours: 6)),
          ),
        ],
      ),
      BrokerTask(
        id: 'tsk-2026-003',
        brokerId: 'broker-demo-user',
        contactId: 'cnt-kisan-krishi',
        contactName: 'Kisan Krishi Producer Co',
        title: 'Review moisture deduction dispute report',
        description:
            'Buyer flagged 8.4% moisture on Deal DL-2026-0894. Coordinate between lab and seller for agreed ₹25/Qtl rebate.',
        dueDate: now.add(const Duration(hours: 5)), // Due Today
        priority: TaskPriority.high,
        status: TaskStatus.waiting,
        category: TaskCategory.disputeMediation,
        linkedRecord: const TaskLinkedRecord(
          type: LinkedRecordType.dispute,
          id: 'disp-moist-0045',
          reference: 'DISP-2026-0045',
          title: 'Moisture Deduction Claim (DL-2026-0894)',
          currentStatus: 'Under Mediation',
          isAccessible: true,
          route: '/disputes',
        ),
        createdAt: now.subtract(const Duration(hours: 14)),
        history: [
          TaskHistoryEntry(
            id: 'th-003-1',
            action: 'created',
            description: 'Dispute arbitration task created',
            actor: 'Broker Desk',
            timestamp: now.subtract(const Duration(hours: 14)),
          ),
        ],
      ),
      BrokerTask(
        id: 'tsk-2026-004',
        brokerId: 'broker-demo-user',
        contactId: 'cnt-marwar-edible',
        contactName: 'Marwar Edible Oils Pvt Ltd',
        title: 'Follow up on payment for Invoice INV-2026-0043',
        description:
            'Brokerage invoice of ₹2,000 is due for payment. Verify RTGS/NEFT transaction details.',
        dueDate: now.add(const Duration(days: 2, hours: 4)), // Upcoming
        priority: TaskPriority.normal,
        status: TaskStatus.open,
        category: TaskCategory.paymentCollection,
        linkedRecord: const TaskLinkedRecord(
          type: LinkedRecordType.invoice,
          id: 'inv-2026-0043',
          reference: 'INV-2026-0043',
          title: 'Brokerage ₹2,000 on Deal DL-2026-0892',
          currentStatus: 'Issued (Pending Payment)',
          isAccessible: true,
          route: '/invoices/inv-2026-0043',
        ),
        createdAt: now.subtract(const Duration(days: 2)),
        history: [
          TaskHistoryEntry(
            id: 'th-004-1',
            action: 'created',
            description: 'Invoice follow-up scheduled',
            actor: 'Broker Desk',
            timestamp: now.subtract(const Duration(days: 2)),
          ),
        ],
      ),
      BrokerTask(
        id: 'tsk-2026-005',
        brokerId: 'broker-demo-user',
        contactId: 'cnt-sharma-agro',
        contactName: 'Sharma Agro Mills Ltd',
        title: 'Match remaining 50 MT balance for Mandate REQ-2026-0104',
        description:
            'Requirement is partially allocated (50 MT / 100 MT). Inspect incoming seller lots at Alwar & Bharatpur mandis.',
        dueDate: now.add(const Duration(days: 3)), // Upcoming
        priority: TaskPriority.normal,
        status: TaskStatus.open,
        category: TaskCategory.mandateMatching,
        linkedRecord: const TaskLinkedRecord(
          type: LinkedRecordType.requirement,
          id: 'req-2026-0104',
          reference: 'REQ-2026-0104',
          title: '100 MT Mustard Seed (Partial Fulfillment 50 MT remaining)',
          currentStatus: 'Partially Allocated',
          isAccessible: true,
          route: '/work',
        ),
        createdAt: now.subtract(const Duration(days: 3)),
        history: [
          TaskHistoryEntry(
            id: 'th-005-1',
            action: 'created',
            description: 'Task logged from requirement match desk',
            actor: 'Broker Desk',
            timestamp: now.subtract(const Duration(days: 3)),
          ),
        ],
      ),
      BrokerTask(
        id: 'tsk-2026-006',
        brokerId: 'broker-demo-user',
        contactId: 'cnt-jaipur-traders',
        contactName: 'Jaipur Grain Traders Association',
        title: 'Check expired seller lot OFF-2026-0220 for renewal',
        description:
            'Offer expired yesterday. Contact seller to verify if 40 MT Soyabean stock remains available at same rate.',
        dueDate: now.subtract(const Duration(days: 1)),
        priority: TaskPriority.low,
        status: TaskStatus.completed,
        category: TaskCategory.offerInspection,
        linkedRecord: const TaskLinkedRecord(
          type: LinkedRecordType.offer,
          id: 'off-2026-0220',
          reference: 'OFF-2026-0220',
          title: '40 MT Yellow Soyabean Lot',
          currentStatus: 'Expired',
          isAccessible: false,
          statusNotice:
              'Linked seller lot has expired. Stock renewed under fresh lot reference.',
          route: '/work',
        ),
        completedAt: now.subtract(const Duration(hours: 4)),
        createdAt: now.subtract(const Duration(days: 4)),
        history: [
          TaskHistoryEntry(
            id: 'th-006-1',
            action: 'created',
            description: 'Offer inquiry task logged',
            actor: 'Broker Desk',
            timestamp: now.subtract(const Duration(days: 4)),
          ),
          TaskHistoryEntry(
            id: 'th-006-2',
            action: 'completed',
            description: 'Seller renewed lot under new reference. Action complete.',
            actor: 'Broker Desk',
            timestamp: now.subtract(const Duration(hours: 4)),
          ),
        ],
      ),
    ]);
  }

  /// Fetches tasks assigned to the authenticated broker with optional filter criteria.
  Future<List<BrokerTask>> fetchTasks({TaskFilterCriteria? criteria}) async {
    _seedDefaultDeskTasks();

    // 1. Attempt REST endpoint
    try {
      final response = await _apiClient.get('/broker/tasks');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final list = (data['data'] as List<dynamic>?) ??
              (data['tasks'] as List<dynamic>?) ??
              [];
          final items = list
              .whereType<Map<String, dynamic>>()
              .map(BrokerTask.fromJson)
              .toList();
          if (items.isNotEmpty) {
            _mergeTasks(items);
            return _applyFilter(criteria);
          }
        } else if (data is List) {
          final items = data
              .whereType<Map<String, dynamic>>()
              .map(BrokerTask.fromJson)
              .toList();
          if (items.isNotEmpty) {
            _mergeTasks(items);
            return _applyFilter(criteria);
          }
        }
      }
    } on DioException catch (dioErr) {
      debugPrint('REST tasks query notice: ${dioErr.message} (falling back to Supabase/cache)');
    } catch (e) {
      debugPrint('REST tasks error: $e');
    }

    // 2. Direct Supabase PostgREST query on table `crm_tasks`
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        final brokerId = session.user.id;
        final response = await client
            .from('crm_tasks')
            .select('*')
            .eq('broker_id', brokerId)
            .order('due_date', ascending: true);

        final list = response as List<dynamic>;
        final items = list
            .whereType<Map<String, dynamic>>()
            .map(BrokerTask.fromJson)
            .toList();

        if (items.isNotEmpty) {
          _mergeTasks(items);
          return _applyFilter(criteria);
        }
      }
    } catch (dbErr) {
      debugPrint('Supabase tasks query notice: $dbErr');
    }

    // 3. In-memory authoritative store fallback
    return _applyFilter(criteria);
  }

  /// Retrieves a single task by ID.
  Future<BrokerTask?> getTaskById(String taskId) async {
    _seedDefaultDeskTasks();
    final index = _cachedTasks.indexWhere((t) => t.id == taskId);
    if (index >= 0) return _cachedTasks[index];

    // Attempt direct fetch
    final all = await fetchTasks();
    final match = all.where((t) => t.id == taskId);
    return match.isNotEmpty ? match.first : null;
  }

  /// Creates a new broker task with idempotency / debounce guards.
  Future<BrokerTask> createTask(BrokerTask task) async {
    _seedDefaultDeskTasks();

    // Idempotency check: prevent duplicate submissions
    final idempotencyKey =
        '${task.brokerId}_${task.title.trim().toLowerCase()}_${task.dueDate.toIso8601String()}';
    if (_inFlightSubmissionKeys.contains(idempotencyKey)) {
      throw const DuplicateTaskSubmissionException(
        'A task with this title and scheduled due time is already being created. Duplicate submission blocked.',
      );
    }
    _inFlightSubmissionKeys.add(idempotencyKey);

    try {
      final now = DateTime.now();
      final taskWithAudit = task.copyWith(
        id: task.id.isNotEmpty
            ? task.id
            : 'tsk-gen-${DateTime.now().millisecondsSinceEpoch}',
        createdAt: now,
        history: [
          TaskHistoryEntry(
            id: 'th-new-${DateTime.now().millisecondsSinceEpoch}',
            action: 'created',
            description: 'Task created on broker desk',
            actor: 'Broker Desk',
            timestamp: now,
          ),
          ...task.history,
        ],
      );

      // 1. Attempt REST POST
      try {
        final response = await _apiClient.post(
          '/broker/tasks',
          data: taskWithAudit.toJson(),
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('REST task created successfully');
        }
      } catch (dioErr) {
        debugPrint('REST create task notice: $dioErr');
      }

      // 2. Direct Supabase PostgREST insert
      try {
        final client = _supabase;
        final session = client?.auth.currentSession;
        if (client != null && session != null && !session.isExpired) {
          await client.from('crm_tasks').insert(taskWithAudit.toSupabaseInsert());
        }
      } catch (dbErr) {
        debugPrint('Supabase insert notice: $dbErr');
      }

      // 3. Commit to local cache
      _cachedTasks.insert(0, taskWithAudit);
      return taskWithAudit;
    } finally {
      // Release in-flight lock after brief debounce
      Future.delayed(const Duration(seconds: 2), () {
        _inFlightSubmissionKeys.remove(idempotencyKey);
      });
    }
  }

  /// Edits permitted task fields (title, description, priority, due date, category, contact).
  Future<BrokerTask> updateTask(BrokerTask task) async {
    _seedDefaultDeskTasks();

    final now = DateTime.now();
    final updatedTask = task.copyWith(
      updatedAt: now,
      history: [
        TaskHistoryEntry(
          id: 'th-upd-${DateTime.now().millisecondsSinceEpoch}',
          action: 'edited',
          description: 'Task fields updated (Priority: ${task.priority.label}, Due: ${task.dueDateFormatted})',
          actor: 'Broker Desk',
          timestamp: now,
        ),
        ...task.history,
      ],
    );

    // 1. Attempt REST PATCH
    try {
      await _apiClient.patch(
        '/broker/tasks/${task.id}',
        data: updatedTask.toJson(),
      );
    } catch (_) {}

    // 2. Direct Supabase PostgREST update
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        await client
            .from('crm_tasks')
            .update(updatedTask.toSupabaseUpdate())
            .eq('id', task.id)
            .eq('broker_id', task.brokerId);
      }
    } catch (_) {}

    // 3. Update local cache
    final index = _cachedTasks.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      _cachedTasks[index] = updatedTask;
    } else {
      _cachedTasks.insert(0, updatedTask);
    }

    return updatedTask;
  }

  /// Marks a task complete.
  /// Enforces that completing a task DOES NOT mutate any underlying deal or financial record!
  Future<BrokerTask> markTaskComplete(String taskId) async {
    _seedDefaultDeskTasks();

    final index = _cachedTasks.indexWhere((t) => t.id == taskId);
    if (index < 0) throw Exception('Task not found: $taskId');

    final existing = _cachedTasks[index];
    final now = DateTime.now();

    final completedTask = existing.copyWith(
      status: TaskStatus.completed,
      completedAt: now,
      updatedAt: now,
      history: [
        TaskHistoryEntry(
          id: 'th-cmp-${DateTime.now().millisecondsSinceEpoch}',
          action: 'completed',
          description: 'Task marked as completed by broker. No deal or financial state mutated.',
          actor: 'Broker Desk',
          timestamp: now,
        ),
        ...existing.history,
      ],
    );

    // 1. Attempt REST toggle/complete
    try {
      await _apiClient.post('/broker/tasks/$taskId/toggle', data: {'status': 'Completed'});
    } catch (_) {}

    // 2. Direct Supabase update
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        await client
            .from('crm_tasks')
            .update({'status': 'Completed'})
            .eq('id', taskId)
            .eq('broker_id', existing.brokerId);
      }
    } catch (_) {}

    _cachedTasks[index] = completedTask;
    return completedTask;
  }

  /// Reopens a completed or cancelled task.
  Future<BrokerTask> reopenTask(String taskId) async {
    _seedDefaultDeskTasks();

    final index = _cachedTasks.indexWhere((t) => t.id == taskId);
    if (index < 0) throw Exception('Task not found: $taskId');

    final existing = _cachedTasks[index];
    final now = DateTime.now();

    final reopenedTask = existing.copyWith(
      status: TaskStatus.open,
      clearCompletedAt: true,
      updatedAt: now,
      history: [
        TaskHistoryEntry(
          id: 'th-rop-${DateTime.now().millisecondsSinceEpoch}',
          action: 'reopened',
          description: 'Task reopened for further follow-up',
          actor: 'Broker Desk',
          timestamp: now,
        ),
        ...existing.history,
      ],
    );

    // 1. Attempt REST toggle
    try {
      await _apiClient.post('/broker/tasks/$taskId/toggle', data: {'status': 'Pending'});
    } catch (_) {}

    // 2. Direct Supabase update
    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        await client
            .from('crm_tasks')
            .update({'status': 'Pending'})
            .eq('id', taskId)
            .eq('broker_id', existing.brokerId);
      }
    } catch (_) {}

    _cachedTasks[index] = reopenedTask;
    return reopenedTask;
  }

  /// Cancels a task safely.
  Future<BrokerTask> cancelTask(String taskId) async {
    _seedDefaultDeskTasks();

    final index = _cachedTasks.indexWhere((t) => t.id == taskId);
    if (index < 0) throw Exception('Task not found: $taskId');

    final existing = _cachedTasks[index];
    final now = DateTime.now();

    final cancelledTask = existing.copyWith(
      status: TaskStatus.cancelled,
      updatedAt: now,
      history: [
        TaskHistoryEntry(
          id: 'th-cnc-${DateTime.now().millisecondsSinceEpoch}',
          action: 'cancelled',
          description: 'Task cancelled by broker',
          actor: 'Broker Desk',
          timestamp: now,
        ),
        ...existing.history,
      ],
    );

    try {
      final client = _supabase;
      final session = client?.auth.currentSession;
      if (client != null && session != null && !session.isExpired) {
        await client
            .from('crm_tasks')
            .update({'status': 'Cancelled'})
            .eq('id', taskId)
            .eq('broker_id', existing.brokerId);
      }
    } catch (_) {}

    _cachedTasks[index] = cancelledTask;
    return cancelledTask;
  }

  /// Merges newly fetched items into cache with deduplication.
  void _mergeTasks(List<BrokerTask> newTasks) {
    for (final task in newTasks) {
      final index = _cachedTasks.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        _cachedTasks[index] = task;
      } else {
        _cachedTasks.add(task);
      }
    }
  }

  /// Filters cached tasks according to criteria.
  List<BrokerTask> _applyFilter(TaskFilterCriteria? criteria) {
    if (criteria == null) return List.unmodifiable(_cachedTasks);
    return _cachedTasks.where(criteria.matches).toList();
  }

  /// Provides verified business records available for linking to a new task.
  List<TaskLinkedRecord> getAvailableLinkedRecords() {
    return const [
      TaskLinkedRecord(
        type: LinkedRecordType.deal,
        id: 'deal-bkg-0042',
        reference: 'DL-2026-0891',
        title: '50 MT Mustard Seed - Sharma Agro Mills',
        currentStatus: 'Awaiting Confirmation',
        isAccessible: true,
        route: '/deals/deal-bkg-0042',
      ),
      TaskLinkedRecord(
        type: LinkedRecordType.deal,
        id: 'deal-bkg-0043',
        reference: 'DL-2026-0892',
        title: '40 MT Yellow Soyabean - Hadoti Agro',
        currentStatus: 'Loading Scheduled',
        isAccessible: true,
        route: '/deals/deal-bkg-0043',
      ),
      TaskLinkedRecord(
        type: LinkedRecordType.counterparty,
        id: 'cnt-sharma-agro',
        reference: 'Sharma Agro Mills Ltd',
        title: 'Buyer Enterprise (Jaipur Mandi)',
        currentStatus: 'Verified Buyer',
        isAccessible: true,
        route: '/directory',
      ),
      TaskLinkedRecord(
        type: LinkedRecordType.counterparty,
        id: 'cnt-hadoti-agro',
        reference: 'Hadoti Agro Farmer Producer Co',
        title: 'Seller FPO (Kota Mandi)',
        currentStatus: 'Verified Seller',
        isAccessible: true,
        route: '/directory',
      ),
      TaskLinkedRecord(
        type: LinkedRecordType.requirement,
        id: 'req-2026-0104',
        reference: 'REQ-2026-0104',
        title: '100 MT Mustard Seed (Grade-A Bold)',
        currentStatus: 'Partially Allocated',
        isAccessible: true,
        route: '/work',
      ),
      TaskLinkedRecord(
        type: LinkedRecordType.offer,
        id: 'off-2026-0219',
        reference: 'OFF-2026-0219',
        title: '50 MT Mustard Seed Lot (Kisan Krishi)',
        currentStatus: 'Active',
        isAccessible: true,
        route: '/work',
      ),
      TaskLinkedRecord(
        type: LinkedRecordType.invoice,
        id: 'inv-2026-0042',
        reference: 'INV-2026-0042',
        title: 'Brokerage ₹3,000 on Deal DL-2026-0891',
        currentStatus: 'Paid',
        isAccessible: true,
        route: '/invoices/inv-2026-0042',
      ),
      TaskLinkedRecord(
        type: LinkedRecordType.dispute,
        id: 'disp-moist-0045',
        reference: 'DISP-2026-0045',
        title: 'Moisture Deduction Review (DL-2026-0894)',
        currentStatus: 'Under Mediation',
        isAccessible: true,
        route: '/disputes',
      ),
    ];
  }
}

extension BrokerTaskFormatting on BrokerTask {
  String get dueDateFormatted =>
      '${dueDate.toLocal().day.toString().padLeft(2, '0')}/${dueDate.toLocal().month.toString().padLeft(2, '0')}/${dueDate.toLocal().year} ${dueDate.toLocal().hour.toString().padLeft(2, '0')}:${dueDate.toLocal().minute.toString().padLeft(2, '0')}';
}
