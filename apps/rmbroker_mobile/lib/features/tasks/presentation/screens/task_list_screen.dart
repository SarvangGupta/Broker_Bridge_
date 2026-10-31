import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../domain/task_filter.dart';
import '../../domain/task_model.dart';
import '../../domain/task_status.dart';
import '../controllers/task_controller.dart';
import '../widgets/create_task_sheet.dart';
import '../widgets/task_card.dart';

/// Simplified, action-oriented workstation screen for broker tasks and follow-ups.
/// Matches the approved My Tasks UX design concept.
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateTask(BuildContext context) {
    final repository = ref.read(taskRepositoryProvider);
    final controller = ref.read(taskControllerProvider.notifier);

    CreateTaskSheet.show(
      context,
      repository: repository,
      onSubmit: ({
        required String title,
        String description = '',
        required DateTime dueDate,
        required priority,
        required category,
        linkedRecord,
      }) async {
        await controller.createTask(
          title: title,
          description: description,
          dueDate: dueDate,
          priority: priority,
          category: category,
          linkedRecord: linkedRecord,
        );
      },
    );
  }

  void _openEditTask(BuildContext context, BrokerTask task) {
    final repository = ref.read(taskRepositoryProvider);
    final controller = ref.read(taskControllerProvider.notifier);

    CreateTaskSheet.show(
      context,
      repository: repository,
      existingTask: task,
      preselectedLinkedRecord: task.linkedRecord,
      onSubmit: ({
        required String title,
        String description = '',
        required DateTime dueDate,
        required priority,
        required category,
        linkedRecord,
      }) async {
        final updated = task.copyWith(
          title: title,
          description: description,
          dueDate: dueDate,
          priority: priority,
          category: category,
          linkedRecord: linkedRecord,
        );
        await controller.updateTask(updated);
      },
    );
  }

  void _confirmCancelTask(BuildContext context, BrokerTask task) {
    final controller = ref.read(taskControllerProvider.notifier);

    showDialog(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: 'Cancel Task?',
        message: 'Are you sure you want to cancel "${task.title}"? This will close the task.',
        confirmLabel: 'Cancel Task',
        isDestructive: true,
        onConfirm: () async {
          await controller.cancelTask(task.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskControllerProvider);
    final controller = ref.read(taskControllerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(
            LucideIcons.arrowLeft,
            size: 20,
            color: Color(0xFF0F172A),
          ),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text(
          'My Tasks',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              LucideIcons.refreshCw,
              size: 20,
              color: Color(0xFF0F172A),
            ),
            tooltip: 'Refresh tasks',
            onPressed: () => controller.loadTasks(isRefresh: true),
          ),
          const SizedBox(width: 4),
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
              // 1. Intro Banner with + Add task
              _buildIntroBanner(context),
              const SizedBox(height: 12),

              // 2. Simple Tabs (Today, Upcoming, All)
              _buildTabBar(state, controller),
              const SizedBox(height: 12),

              // 3. Three Summary KPI Cards (Overdue, Due today, Done)
              _buildSummaryCards(state, controller),
              const SizedBox(height: 12),

              // 4. Search Field
              _buildSearchBar(controller),
              const SizedBox(height: 14),

              // 5. Task List / Loading / Empty States
              _buildTaskContent(context, state, controller),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact header intro banner with + Add task button
  Widget _buildIntroBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Clipboard Icon Box
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F7F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              LucideIcons.clipboardCheck,
              size: 20,
              color: Color(0xFF0F766E),
            ),
          ),
          const SizedBox(width: 12),

          // Intro Texts
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay on top of your work',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Track and complete your broker tasks and follow-ups',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // + Add task Button
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              key: const ValueKey('add_task_button'),
              onTap: () => _openCreateTask(context),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.plus,
                      size: 15,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Add task',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Segmented capsule tab bar (Today, Upcoming, All)
  Widget _buildTabBar(TaskState state, TaskController controller) {
    final activeTab = state.filterCriteria.activeTab;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabItem(
            label: 'Today',
            isSelected: activeTab == MyTasksTab.today,
            onTap: () => controller.setActiveTab(MyTasksTab.today),
          ),
          _buildTabItem(
            label: 'Upcoming',
            isSelected: activeTab == MyTasksTab.upcoming,
            onTap: () => controller.setActiveTab(MyTasksTab.upcoming),
          ),
          _buildTabItem(
            label: 'All',
            isSelected: activeTab == MyTasksTab.all,
            onTap: () => controller.setActiveTab(MyTasksTab.all),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  /// Three compact KPI summary cards: Overdue, Due today, Done
  Widget _buildSummaryCards(TaskState state, TaskController controller) {
    return Row(
      children: [
        // 1. Overdue (Red)
        Expanded(
          child: _buildKpiCard(
            title: 'Overdue',
            count: state.summary.overdueCount,
            icon: LucideIcons.alertTriangle,
            iconColor: const Color(0xFFEF4444),
            textColor: const Color(0xFF991B1B),
            countColor: const Color(0xFFDC2626),
            backgroundColor: const Color(0xFFFEF2F2),
            borderColor: const Color(0xFFFEE2E2),
            onTap: () => controller.setActiveTab(MyTasksTab.today),
          ),
        ),
        const SizedBox(width: 8),

        // 2. Due today (Amber)
        Expanded(
          child: _buildKpiCard(
            title: 'Due today',
            count: state.summary.dueTodayCount,
            icon: LucideIcons.calendar,
            iconColor: const Color(0xFFF59E0B),
            textColor: const Color(0xFF92400E),
            countColor: const Color(0xFFD97706),
            backgroundColor: const Color(0xFFFFFBEB),
            borderColor: const Color(0xFFFEF3C7),
            onTap: () => controller.setActiveTab(MyTasksTab.today),
          ),
        ),
        const SizedBox(width: 8),

        // 3. Done (Green)
        Expanded(
          child: _buildKpiCard(
            title: 'Done',
            count: state.summary.recentlyCompletedCount,
            icon: LucideIcons.checkCircle2,
            iconColor: const Color(0xFF16A34A),
            textColor: const Color(0xFF166534),
            countColor: const Color(0xFF16A34A),
            backgroundColor: const Color(0xFFF0FDF4),
            borderColor: const Color(0xFFDCFCE7),
            onTap: () => controller.setActiveTab(MyTasksTab.all),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required int count,
    required IconData icon,
    required Color iconColor,
    required Color textColor,
    required Color countColor,
    required Color backgroundColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: iconColor),
                  const SizedBox(width: 5),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: countColor,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Search bar with placeholder matching approved mockup
  Widget _buildSearchBar(TaskController controller) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.search,
            size: 18,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (q) => controller.setSearchQuery(q),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF0F172A),
              ),
              decoration: const InputDecoration(
                hintText: 'Search tasks by title, deal, buyer or notes...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFF64748B)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                _searchController.clear();
                controller.setSearchQuery('');
              },
            ),
        ],
      ),
    );
  }

  /// Task list, loading, error, and empty states
  Widget _buildTaskContent(
    BuildContext context,
    TaskState state,
    TaskController controller,
  ) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: AppLoadingIndicator(
            message: 'Loading tasks...',
          ),
        ),
      );
    }

    if (state.errorMessage != null && state.allTasks.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              LucideIcons.alertCircle,
              size: 32,
              color: AppColors.error,
            ),
            const SizedBox(height: 10),
            const Text(
              'Unable to Load Tasks',
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
      );
    }

    if (state.filteredTasks.isEmpty) {
      return _buildEmptyState(context, state, controller);
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.filteredTasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final task = state.filteredTasks[index];
        return TaskCard(
          task: task,
          onTap: () => context.push('/tasks/${task.id}'),
          onToggleComplete: () async {
            final success = await controller.toggleTaskComplete(task.id);
            if (context.mounted && success) {
              final isNowComplete = task.status != TaskStatus.completed;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isNowComplete
                        ? 'Task completed!'
                        : 'Task reopened!',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          onEdit: () => _openEditTask(context, task),
          onCancel: () => _confirmCancelTask(context, task),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    TaskState state,
    TaskController controller,
  ) {
    final isSearching = state.filterCriteria.searchQuery.isNotEmpty;
    final activeTab = state.filterCriteria.activeTab;

    IconData icon;
    String title;
    String subtitle;

    if (isSearching) {
      icon = LucideIcons.searchX;
      title = 'No Matching Tasks';
      subtitle = 'No tasks match "${state.filterCriteria.searchQuery}". Try different keywords.';
    } else {
      switch (activeTab) {
        case MyTasksTab.today:
          icon = LucideIcons.checkCheck;
          title = 'All Caught Up for Today!';
          subtitle = 'You have no pending or overdue tasks for today.';
          break;
        case MyTasksTab.upcoming:
          icon = LucideIcons.calendarCheck;
          title = 'No Upcoming Tasks Scheduled';
          subtitle = 'You have no tasks scheduled after today.';
          break;
        case MyTasksTab.all:
          icon = LucideIcons.listTodo;
          title = 'No Tasks Found';
          subtitle = 'Your broker workstation has no active or completed tasks.';
          break;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F7F2),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(
              icon,
              size: 26,
              color: const Color(0xFF0F766E),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          if (isSearching)
            SizedBox(
              width: 140,
              child: AppButton(
                label: 'Clear Search',
                onPressed: () {
                  _searchController.clear();
                  controller.setSearchQuery('');
                },
              ),
            )
          else
            SizedBox(
              width: 150,
              child: AppButton(
                label: 'Add Task',
                icon: const Icon(LucideIcons.plus, size: 16, color: Colors.white),
                onPressed: () => _openCreateTask(context),
              ),
            ),
        ],
      ),
    );
  }
}
