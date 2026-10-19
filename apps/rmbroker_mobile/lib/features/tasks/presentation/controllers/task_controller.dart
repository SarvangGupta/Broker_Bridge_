import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmbroker_mobile/features/authentication/data/auth_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/task_category.dart';
import '../../domain/task_filter.dart';
import '../../domain/task_model.dart';
import '../../domain/task_priority.dart';
import '../../domain/task_status.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// State of the broker tasks workstation.
class TaskState {
  final bool isLoading;
  final bool isSubmitting;
  final List<BrokerTask> allTasks;
  final List<BrokerTask> filteredTasks;
  final TaskFilterCriteria filterCriteria;
  final TaskDashboardSummary summary;
  final String? errorMessage;
  final DateTime? lastRefreshed;
  final String? notice;

  const TaskState({
    required this.isLoading,
    this.isSubmitting = false,
    required this.allTasks,
    required this.filteredTasks,
    required this.filterCriteria,
    required this.summary,
    this.errorMessage,
    this.lastRefreshed,
    this.notice,
  });

  factory TaskState.initial() {
    return TaskState(
      isLoading: true,
      allTasks: const [],
      filteredTasks: const [],
      filterCriteria: const TaskFilterCriteria(),
      summary: const TaskDashboardSummary(
        totalCount: 0,
        dueTodayCount: 0,
        overdueCount: 0,
        upcomingCount: 0,
        highPriorityOpenCount: 0,
        recentlyCompletedCount: 0,
      ),
    );
  }

  TaskState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<BrokerTask>? allTasks,
    List<BrokerTask>? filteredTasks,
    TaskFilterCriteria? filterCriteria,
    TaskDashboardSummary? summary,
    String? errorMessage,
    DateTime? lastRefreshed,
    String? notice,
  }) {
    return TaskState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      allTasks: allTasks ?? this.allTasks,
      filteredTasks: filteredTasks ?? this.filteredTasks,
      filterCriteria: filterCriteria ?? this.filterCriteria,
      summary: summary ?? this.summary,
      errorMessage: errorMessage,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
      notice: notice ?? this.notice,
    );
  }
}

/// Provider for TaskRepository
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

/// Provider for TaskController
final taskControllerProvider =
    NotifierProvider<TaskController, TaskState>(TaskController.new);

/// Controller managing tasks workstation operational state.
class TaskController extends Notifier<TaskState> {
  TaskRepository get _repository => ref.read(taskRepositoryProvider);
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  @override
  TaskState build() {
    Future.microtask(() => loadTasks());
    return TaskState.initial();
  }

  /// Initial load or pull-to-refresh of desk tasks.
  Future<void> loadTasks({bool isRefresh = false}) async {
    if (!isRefresh) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      final tasks = await _repository.fetchTasks();
      final summary = TaskDashboardSummary.fromTasks(tasks);
      final filtered = tasks.where(state.filterCriteria.matches).toList();

      state = state.copyWith(
        isLoading: false,
        allTasks: tasks,
        filteredTasks: filtered,
        summary: summary,
        errorMessage: null,
        lastRefreshed: DateTime.now(),
        notice: _repository.reminderCapabilityNotice,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
        lastRefreshed: DateTime.now(),
      );
    }
  }

  /// Updates filter criteria and reapplies to current tasks.
  void updateFilter(TaskFilterCriteria criteria) {
    final filtered = state.allTasks.where(criteria.matches).toList();
    state = state.copyWith(
      filterCriteria: criteria,
      filteredTasks: filtered,
    );
  }

  /// Sets text search query.
  void setSearchQuery(String query) {
    updateFilter(state.filterCriteria.copyWith(searchQuery: query));
  }

  /// Sets status filter.
  void setStatusFilter(TaskStatus? status) {
    updateFilter(state.filterCriteria.copyWith(statusFilter: () => status));
  }

  /// Sets priority filter.
  void setPriorityFilter(TaskPriority? priority) {
    updateFilter(state.filterCriteria.copyWith(priorityFilter: () => priority));
  }

  /// Sets category filter.
  void setCategoryFilter(TaskCategory? category) {
    updateFilter(state.filterCriteria.copyWith(categoryFilter: () => category));
  }

  /// Sets date filter.
  void setDateFilter(TaskDateFilter dateFilter) {
    updateFilter(state.filterCriteria.copyWith(dateFilter: dateFilter));
  }

  /// Resets all filters to default.
  void resetFilters() {
    updateFilter(const TaskFilterCriteria());
  }

  /// Quickly toggles task status between open and completed.
  Future<bool> toggleTaskComplete(String taskId) async {
    final taskIndex = state.allTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex < 0) return false;

    final existing = state.allTasks[taskIndex];
    try {
      BrokerTask updated;
      if (existing.status == TaskStatus.completed) {
        updated = await _repository.reopenTask(taskId);
      } else {
        updated = await _repository.markTaskComplete(taskId);
      }

      final updatedAll = List<BrokerTask>.from(state.allTasks);
      updatedAll[taskIndex] = updated;
      final summary = TaskDashboardSummary.fromTasks(updatedAll);
      final filtered = updatedAll.where(state.filterCriteria.matches).toList();

      state = state.copyWith(
        allTasks: updatedAll,
        filteredTasks: filtered,
        summary: summary,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to update task: $e');
      return false;
    }
  }

  /// Creates a new task.
  Future<BrokerTask?> createTask({
    required String title,
    String description = '',
    required DateTime dueDate,
    required TaskPriority priority,
    required TaskCategory category,
    TaskLinkedRecord? linkedRecord,
    String? contactId,
    String? contactName,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final user = await _authRepository.getCurrentBroker();
      final brokerId = user?.id ?? 'broker-demo-user';

      final newTask = BrokerTask(
        id: '',
        brokerId: brokerId,
        contactId: contactId ?? (linkedRecord?.type == LinkedRecordType.counterparty ? linkedRecord?.id : null),
        contactName: contactName ?? (linkedRecord?.type == LinkedRecordType.counterparty ? linkedRecord?.reference : null),
        title: title.trim(),
        description: description.trim(),
        dueDate: dueDate,
        priority: priority,
        status: TaskStatus.open,
        category: category,
        linkedRecord: linkedRecord,
        createdAt: DateTime.now(),
      );

      final created = await _repository.createTask(newTask);

      final updatedAll = [created, ...state.allTasks];
      final summary = TaskDashboardSummary.fromTasks(updatedAll);
      final filtered = updatedAll.where(state.filterCriteria.matches).toList();

      state = state.copyWith(
        isSubmitting: false,
        allTasks: updatedAll,
        filteredTasks: filtered,
        summary: summary,
      );
      return created;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Cancels a task.
  Future<bool> cancelTask(String taskId) async {
    final taskIndex = state.allTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex < 0) return false;

    try {
      final cancelled = await _repository.cancelTask(taskId);

      final updatedAll = List<BrokerTask>.from(state.allTasks);
      updatedAll[taskIndex] = cancelled;
      final summary = TaskDashboardSummary.fromTasks(updatedAll);
      final filtered = updatedAll.where(state.filterCriteria.matches).toList();

      state = state.copyWith(
        allTasks: updatedAll,
        filteredTasks: filtered,
        summary: summary,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to cancel task: $e');
      return false;
    }
  }
}
