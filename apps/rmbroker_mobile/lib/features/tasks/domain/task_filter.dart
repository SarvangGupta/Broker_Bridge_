import 'task_category.dart';
import 'task_model.dart';
import 'task_priority.dart';
import 'task_status.dart';

/// Due date time-window filters for tasks.
enum TaskDateFilter {
  all('All Dates'),
  today('Due Today'),
  overdue('Overdue'),
  upcoming('Upcoming');

  final String label;
  const TaskDateFilter(this.label);
}

/// Filter criteria applied to the broker task list.
class TaskFilterCriteria {
  final String searchQuery;
  final TaskStatus? statusFilter;
  final TaskPriority? priorityFilter;
  final TaskCategory? categoryFilter;
  final TaskDateFilter dateFilter;

  const TaskFilterCriteria({
    this.searchQuery = '',
    this.statusFilter,
    this.priorityFilter,
    this.categoryFilter,
    this.dateFilter = TaskDateFilter.all,
  });

  bool get isDefault =>
      searchQuery.isEmpty &&
      statusFilter == null &&
      priorityFilter == null &&
      (categoryFilter == null || categoryFilter == TaskCategory.all) &&
      dateFilter == TaskDateFilter.all;

  TaskFilterCriteria copyWith({
    String? searchQuery,
    TaskStatus? Function()? statusFilter,
    TaskPriority? Function()? priorityFilter,
    TaskCategory? Function()? categoryFilter,
    TaskDateFilter? dateFilter,
  }) {
    return TaskFilterCriteria(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter != null ? statusFilter() : this.statusFilter,
      priorityFilter:
          priorityFilter != null ? priorityFilter() : this.priorityFilter,
      categoryFilter:
          categoryFilter != null ? categoryFilter() : this.categoryFilter,
      dateFilter: dateFilter ?? this.dateFilter,
    );
  }

  /// Evaluates whether a [BrokerTask] satisfies this filter.
  bool matches(BrokerTask task) {
    // 1. Text search on title, description, and contact/record reference
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      final titleMatch = task.title.toLowerCase().contains(q);
      final descMatch = task.description.toLowerCase().contains(q);
      final contactMatch = task.contactName?.toLowerCase().contains(q) ?? false;
      final refMatch =
          task.linkedRecord?.reference.toLowerCase().contains(q) ?? false;
      final recordTitleMatch =
          task.linkedRecord?.title.toLowerCase().contains(q) ?? false;

      if (!titleMatch &&
          !descMatch &&
          !contactMatch &&
          !refMatch &&
          !recordTitleMatch) {
        return false;
      }
    }

    // 2. Status filter
    if (statusFilter != null && task.status != statusFilter) {
      return false;
    }

    // 3. Priority filter
    if (priorityFilter != null && task.priority != priorityFilter) {
      return false;
    }

    // 4. Category filter
    if (categoryFilter != null &&
        categoryFilter != TaskCategory.all &&
        task.category != categoryFilter) {
      return false;
    }

    // 5. Date filter
    switch (dateFilter) {
      case TaskDateFilter.all:
        break;
      case TaskDateFilter.today:
        if (!task.isDueToday || task.status.isClosed) return false;
        break;
      case TaskDateFilter.overdue:
        if (!task.isOverdue || task.status.isClosed) return false;
        break;
      case TaskDateFilter.upcoming:
        if (!task.isUpcoming || task.status.isClosed) return false;
        break;
    }

    return true;
  }
}

/// Dynamic statistical dashboard summarizing authorized tasks.
class TaskDashboardSummary {
  final int totalCount;
  final int dueTodayCount;
  final int overdueCount;
  final int upcomingCount;
  final int highPriorityOpenCount;
  final int recentlyCompletedCount;

  const TaskDashboardSummary({
    required this.totalCount,
    required this.dueTodayCount,
    required this.overdueCount,
    required this.upcomingCount,
    required this.highPriorityOpenCount,
    required this.recentlyCompletedCount,
  });

  factory TaskDashboardSummary.fromTasks(List<BrokerTask> tasks) {
    int dueToday = 0;
    int overdue = 0;
    int upcoming = 0;
    int highPriorityOpen = 0;
    int completed = 0;

    for (final task in tasks) {
      if (task.status == TaskStatus.completed) {
        completed++;
        continue;
      }
      if (task.status == TaskStatus.cancelled) {
        continue;
      }

      if (task.isOverdue) {
        overdue++;
      } else if (task.isDueToday) {
        dueToday++;
      } else if (task.isUpcoming) {
        upcoming++;
      }

      if (task.priority == TaskPriority.high ||
          task.priority == TaskPriority.urgent) {
        highPriorityOpen++;
      }
    }

    return TaskDashboardSummary(
      totalCount: tasks.length,
      dueTodayCount: dueToday,
      overdueCount: overdue,
      upcomingCount: upcoming,
      highPriorityOpenCount: highPriorityOpen,
      recentlyCompletedCount: completed,
    );
  }
}
