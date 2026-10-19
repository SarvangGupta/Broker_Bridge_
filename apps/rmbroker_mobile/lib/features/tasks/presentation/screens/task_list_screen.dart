import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../controllers/task_controller.dart';
import '../widgets/create_task_sheet.dart';
import '../widgets/task_card.dart';
import '../widgets/task_dashboard_summary.dart';
import '../widgets/task_filter_bar.dart';

/// Central workstation screen for managing broker tasks, follow-ups, and business record actions.
class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskControllerProvider);
    final controller = ref.read(taskControllerProvider.notifier);
    final repository = ref.read(taskRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Broker Tasks & Follow-ups'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            tooltip: 'Refresh tasks',
            onPressed: () => controller.loadTasks(isRefresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.loadTasks(isRefresh: true),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.search,
                      size: 18,
                      color: AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (q) => controller.setSearchQuery(q),
                        decoration: const InputDecoration(
                          hintText: 'Search tasks by title, counterparty, reference...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: AppColors.textDisabled,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (state.filterCriteria.searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () => controller.setSearchQuery(''),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Action Item Dashboard Summary (5 live KPI metric cards)
              TaskDashboardSummaryWidget(
                summary: state.summary,
                selectedDateFilter: state.filterCriteria.dateFilter,
                onSelectFilter: (filter) => controller.setDateFilter(filter),
              ),
              const SizedBox(height: 12),

              // Filter Bar
              TaskFilterBar(
                criteria: state.filterCriteria,
                onCriteriaChanged: (crit) => controller.updateFilter(crit),
              ),
              const SizedBox(height: 12),

              // Scheduled Reminders Transparency Notice
              if (state.notice != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.infoBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.bellOff,
                        size: 13,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Push reminders unsupported on backend. Visual in-app due dates & overdue alerts are active.',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Task List Content
              if (state.isLoading) ...[
                const SizedBox(height: 40),
                const Center(
                  child: AppLoadingIndicator(
                    message: 'Synchronizing Desk Follow-up Tasks...',
                  ),
                ),
                const SizedBox(height: 40),
              ] else if (state.errorMessage != null && state.allTasks.isEmpty) ...[
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        LucideIcons.alertCircle,
                        size: 32,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Unable to Load Broker Tasks',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 140,
                        child: AppButton(
                          label: 'Retry',
                          onPressed: () => controller.loadTasks(),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (state.filteredTasks.isEmpty) ...[
                AppCard(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Icon(
                        state.filterCriteria.isDefault
                            ? LucideIcons.checkCheck
                            : LucideIcons.searchX,
                        size: 36,
                        color: AppColors.primary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.filterCriteria.isDefault
                            ? 'All Action Items Complete'
                            : 'No Tasks Match Current Filters',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.filterCriteria.isDefault
                            ? 'Your broker desk has no outstanding follow-up tasks at this time.'
                            : 'Try adjusting the status, priority, or category filters above.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (!state.filterCriteria.isDefault)
                        SizedBox(
                          width: 150,
                          child: AppButton(
                            label: 'Clear Filters',
                            onPressed: () => controller.resetFilters(),
                          ),
                        )
                      else
                        SizedBox(
                          width: 170,
                          child: AppButton(
                            label: 'Create New Task',
                            icon: const Icon(
                              LucideIcons.plus,
                              size: 16,
                              color: Colors.white,
                            ),
                            onPressed: () => CreateTaskSheet.show(
                              context,
                              repository: repository,
                              onSubmit: controller.createTask,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.filteredTasks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final task = state.filteredTasks[index];
                    return TaskCard(
                      task: task,
                      onTap: () => context.push('/tasks/${task.id}'),
                      onToggleComplete: () => controller.toggleTaskComplete(task.id),
                    );
                  },
                ),
              ],

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CreateTaskSheet.show(
          context,
          repository: repository,
          onSubmit: controller.createTask,
        ),
        backgroundColor: AppColors.primary,
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text(
          'New Task',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
