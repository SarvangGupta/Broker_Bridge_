import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task_repository.dart';
import '../../domain/task_category.dart';
import '../../domain/task_model.dart';
import '../../domain/task_priority.dart';
import 'task_controller.dart';

/// State of the Task Detail screen.
class TaskDetailState {
  final bool isLoading;
  final bool isSaving;
  final BrokerTask? task;
  final String? errorMessage;
  final String? successMessage;

  const TaskDetailState({
    required this.isLoading,
    this.isSaving = false,
    this.task,
    this.errorMessage,
    this.successMessage,
  });

  factory TaskDetailState.initial() {
    return const TaskDetailState(isLoading: true);
  }

  TaskDetailState copyWith({
    bool? isLoading,
    bool? isSaving,
    BrokerTask? task,
    String? errorMessage,
    String? successMessage,
  }) {
    return TaskDetailState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      task: task ?? this.task,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

/// Controller managing individual task details, inspection, and status transitions.
class TaskDetailNotifier extends Notifier<TaskDetailState> {
  final String taskId;

  TaskDetailNotifier(this.taskId);

  TaskRepository get _repository => ref.read(taskRepositoryProvider);

  @override
  TaskDetailState build() {
    Future.microtask(() => loadTask());
    return TaskDetailState.initial();
  }

  Future<void> loadTask() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final task = await _repository.getTaskById(taskId);
      if (task != null) {
        state = state.copyWith(isLoading: false, task: task);
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Task not found or access restricted.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load task details: $e',
      );
    }
  }

  Future<bool> markComplete() async {
    final current = state.task;
    if (current == null) return false;

    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final updated = await _repository.markTaskComplete(current.id);
      state = state.copyWith(
        isSaving: false,
        task: updated,
        successMessage: 'Task marked as completed',
      );
      ref.read(taskControllerProvider.notifier).loadTasks(isRefresh: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to mark task complete: $e',
      );
      return false;
    }
  }

  Future<bool> reopenTask() async {
    final current = state.task;
    if (current == null) return false;

    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final updated = await _repository.reopenTask(current.id);
      state = state.copyWith(
        isSaving: false,
        task: updated,
        successMessage: 'Task reopened successfully',
      );
      ref.read(taskControllerProvider.notifier).loadTasks(isRefresh: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to reopen task: $e',
      );
      return false;
    }
  }

  Future<bool> cancelTask() async {
    final current = state.task;
    if (current == null) return false;

    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final updated = await _repository.cancelTask(current.id);
      state = state.copyWith(
        isSaving: false,
        task: updated,
        successMessage: 'Task cancelled',
      );
      ref.read(taskControllerProvider.notifier).loadTasks(isRefresh: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to cancel task: $e',
      );
      return false;
    }
  }

  Future<bool> updateTaskFields({
    required String title,
    required String description,
    required DateTime dueDate,
    required TaskPriority priority,
    required TaskCategory category,
    TaskLinkedRecord? linkedRecord,
  }) async {
    final current = state.task;
    if (current == null) return false;

    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final updated = await _repository.updateTask(
        current.copyWith(
          title: title.trim(),
          description: description.trim(),
          dueDate: dueDate,
          priority: priority,
          category: category,
          linkedRecord: linkedRecord,
        ),
      );

      state = state.copyWith(
        isSaving: false,
        task: updated,
        successMessage: 'Task updated successfully',
      );
      ref.read(taskControllerProvider.notifier).loadTasks(isRefresh: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to update task: $e',
      );
      return false;
    }
  }
}

/// Family provider for TaskDetailNotifier keyed by taskId.
final taskDetailControllerProvider =
    NotifierProvider.family<TaskDetailNotifier, TaskDetailState, String>(
  TaskDetailNotifier.new,
);
