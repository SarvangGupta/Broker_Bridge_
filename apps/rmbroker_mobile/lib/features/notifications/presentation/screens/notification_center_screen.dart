import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../domain/notification_category.dart';
import '../../domain/notification_model.dart';
import '../controllers/notification_controller.dart';
import '../widgets/notification_card.dart';
import '../widgets/notification_detail_dialog.dart';
import '../widgets/notification_filter_bar.dart';

/// Central Notification & Trading Desk Activity Center for authorized brokers.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleRecordNavigation(BuildContext context, BrokerNotification notification) {
    // 1. Mark as read immediately
    ref.read(notificationControllerProvider.notifier).markAsRead(notification.id);

    final route = notification.resolvedRoute;
    if (route != null && route.isNotEmpty) {
      try {
        context.push(route);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open record: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } else {
      // Show technical detail dialog if no direct route exists
      NotificationDetailDialog.show(
        context,
        notification: notification,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationControllerProvider);
    final controller = ref.read(notificationControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications & Activity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              'सूचना व गतिविधि केंद्र',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
            ),
          ],
        ),
        actions: [
          // Mark all as read action
          if (state.unreadCount > 0)
            IconButton(
              icon: const Icon(LucideIcons.checkCheck, size: 20),
              tooltip: 'Mark All Read',
              onPressed: () async {
                await controller.markAllAsRead();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),

          // Refresh button
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            tooltip: 'Refresh Feed',
            onPressed: () => controller.refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => controller.setSearchQuery(val),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  prefixIcon: const Icon(LucideIcons.search, size: 16, color: AppColors.textSecondaryLight),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 14),
                          onPressed: () {
                            _searchController.clear();
                            controller.setSearchQuery('');
                          },
                        )
                      : null,
                  hintText: 'Search notifications by commodity, deal, party...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textDisabled),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Category Filters & Unread Toggle
          NotificationFilterBar(
            selectedCategory: state.selectedCategory,
            unreadOnly: state.unreadOnly,
            categoryCounts: state.categoryCounts,
            onCategorySelected: (cat) => controller.selectCategory(cat),
            onToggleUnreadOnly: () => controller.toggleUnreadOnly(),
          ),
          const SizedBox(height: 8),

          // Notification List / Body
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => controller.refresh(),
              color: AppColors.primary,
              child: _buildListBody(context, state, controller),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListBody(
    BuildContext context,
    NotificationState state,
    NotificationController controller,
  ) {
    if (state.isLoading && state.allNotifications.isEmpty) {
      return const Center(
        child: AppLoadingIndicator(
          message: 'Synchronizing trading desk notifications...',
        ),
      );
    }

    if (state.errorMessage != null && state.allNotifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertCircle, size: 40, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryLight),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Retry Synchronization',
                onPressed: () => controller.refresh(),
                variant: AppButtonVariant.primary,
              ),
            ],
          ),
        ),
      );
    }

    if (state.filteredNotifications.isEmpty) {
      final isFiltered = state.selectedCategory != NotificationCategory.all ||
          state.unreadOnly ||
          state.searchQuery.isNotEmpty;

      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Icon(
                  LucideIcons.bellOff,
                  size: 28,
                  color: AppColors.textDisabled,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isFiltered
                    ? 'No matching notifications found'
                    : 'All Caught Up!',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isFiltered
                    ? 'Try adjusting your category or unread filters.'
                    : 'There are no operational alerts pending on your desk.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              if (isFiltered) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.rotateCcw, size: 14),
                  label: const Text('Reset All Filters'),
                  onPressed: () {
                    _searchController.clear();
                    controller.setSearchQuery('');
                    controller.selectCategory(NotificationCategory.all);
                    if (state.unreadOnly) controller.toggleUnreadOnly();
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: state.filteredNotifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = state.filteredNotifications[index];
        return NotificationCard(
          notification: item,
          onTap: (notif) => _handleRecordNavigation(context, notif),
          onAction: (notif) => _handleRecordNavigation(context, notif),
          onMarkAsRead: (notif) => controller.markAsRead(notif.id),
        );
      },
    );
  }
}
