import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../domain/task_model.dart';
import '../../domain/task_status.dart';
import '../controllers/task_controller.dart';
import '../controllers/task_detail_controller.dart';
import '../widgets/create_task_sheet.dart';
import '../widgets/linked_record_card.dart';

/// Screen displaying complete details, audit history, linked business record, and actions for a task.
class TaskDetailScreen extends ConsumerWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  void _showEditSheet(
    BuildContext context,
    BrokerTask task,
    TaskDetailNotifier controller,
    WidgetRef ref,
  ) {
    final repository = ref.read(taskRepositoryProvider);
    CreateTaskSheet.show(
      context,
      repository: repository,
      preselectedLinkedRecord: task.linkedRecord,
      onSubmit: ({
        required String title,
        String description = '',
        required DateTime dueDate,
        required priority,
        required category,
        linkedRecord,
      }) async {
        await controller.updateTaskFields(
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskDetailControllerProvider(taskId));
    final controller = ref.read(taskDetailControllerProvider(taskId).notifier);

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
              context.go('/tasks');
            }
          },
        ),
        title: const Text('Task & Follow-up Details'),
        actions: [
          if (state.task != null && state.task!.status != TaskStatus.cancelled)
            IconButton(
              icon: const Icon(LucideIcons.pencil, size: 18),
              tooltip: 'Edit task fields',
              onPressed: () => _showEditSheet(context, state.task!, controller, ref),
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.isLoading) {
            return const Center(
              child: AppLoadingIndicator(
                message: 'Loading action item details...',
              ),
            );
          }

          if (state.errorMessage != null && state.task == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.alertCircle,
                        size: 36,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Task Unavailable',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final task = state.task!;
          final isCompleted = task.status == TaskStatus.completed;
          final isCancelled = task.status == TaskStatus.cancelled;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Success Toast/Notice
                if (state.successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.successBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.checkCircle2,
                          size: 16,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.successMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Main Task Header Card
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status & Priority Chips
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: task.status.backgroundColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  task.status.icon,
                                  size: 13,
                                  color: task.status.color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  task.status.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: task.status.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: task.priority.backgroundColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: task.priority.color.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              '${task.priority.label} Priority',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: task.priority.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Task Title
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isCompleted
                              ? AppColors.textSecondaryLight
                              : AppColors.textPrimaryLight,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),

                      if (task.contactName != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.building2,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              task.contactName!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        const Text(
                          'Instructions / Notes',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Due Date & Time Card
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: task.isOverdue
                              ? AppColors.errorBackground
                              : AppColors.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          task.isOverdue
                              ? LucideIcons.alertTriangle
                              : LucideIcons.calendarClock,
                          size: 20,
                          color: task.isOverdue
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.timeLabel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: task.isOverdue
                                    ? AppColors.error
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Target: ${DateFormat('EEE, dd MMM yyyy, hh:mm a').format(task.dueDate.toLocal())}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Reminder Notice Alert Box
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.infoBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        LucideIcons.bellOff,
                        size: 15,
                        color: AppColors.info,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Scheduled push reminders are unsupported on backend. Visual in-app due dates & overdue highlights are computed from broker desk clock.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Linked Business Record (if any)
                if (task.linkedRecord != null) ...[
                  LinkedRecordCard(linkedRecord: task.linkedRecord!),
                  const SizedBox(height: 14),
                ],

                // Non-alteration Disclosure Notice
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        LucideIcons.shieldCheck,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Data Isolation Gate: Completing this follow-up does not automatically confirm deals, allocate quantity, accept deliveries, or execute financial transactions.',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                if (!isCancelled) ...[
                  if (!isCompleted)
                    AppButton(
                      label: 'Mark Task Completed',
                      icon: const Icon(
                        LucideIcons.checkCheck,
                        size: 18,
                        color: Colors.white,
                      ),
                      isLoading: state.isSaving,
                      onPressed: () => controller.markComplete(),
                    )
                  else
                    AppButton(
                      label: 'Reopen Task',
                      icon: const Icon(
                        LucideIcons.rotateCcw,
                        size: 18,
                        color: Colors.white,
                      ),
                      isLoading: state.isSaving,
                      variant: AppButtonVariant.outline,
                      onPressed: () => controller.reopenTask(),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(LucideIcons.pencil, size: 16),
                          label: const Text('Edit Fields'),
                          onPressed: () => _showEditSheet(
                            context,
                            task,
                            controller,
                            ref,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            LucideIcons.xCircle,
                            size: 16,
                            color: AppColors.error,
                          ),
                          label: const Text(
                            'Cancel Task',
                            style: TextStyle(color: AppColors.error),
                          ),
                          onPressed: () async {
                            final confirmed = await ConfirmationDialog.show(
                              context,
                              title: 'Cancel Follow-up Task',
                              message:
                                  'Are you sure you want to cancel this follow-up action?',
                              confirmLabel: 'Cancel Task',
                              isDestructive: true,
                            );
                            if (confirmed == true) {
                              controller.cancelTask();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: Text(
                        'This task was cancelled on ${DateFormat('dd MMM yyyy').format(task.updatedAt ?? DateTime.now())}.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Audit History Timeline
                const Text(
                  'Task History & Audit Log',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                if (task.history.isEmpty)
                  const Text(
                    'No prior revisions recorded.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: task.history.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = task.history[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                LucideIcons.gitCommitVertical,
                                size: 14,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.description,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.actor} • ${DateFormat('dd MMM yyyy, hh:mm a').format(item.timestamp)}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}
