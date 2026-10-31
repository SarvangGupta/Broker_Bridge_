import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../domain/alert_kind.dart';
import '../../domain/notification_category.dart';
import '../../domain/notification_model.dart';
import '../controllers/notification_controller.dart';
import '../widgets/notification_card.dart';
import '../widgets/notification_detail_dialog.dart';

/// Time bucket of an alert, by the local calendar date of its record timestamp.
enum AlertGroup {
  today('Today'),
  yesterday('Yesterday'),
  earlier('Earlier');

  final String label;
  const AlertGroup(this.label);

  static AlertGroup of(DateTime createdAt, DateTime now) {
    final local = createdAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    if (!day.isBefore(today)) return AlertGroup.today;
    if (day == today.subtract(const Duration(days: 1))) return AlertGroup.yesterday;
    return AlertGroup.earlier;
  }
}

/// Alerts: the broker's notification and activity feed.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isNavigating = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleRecordNavigation(BuildContext context, BrokerNotification notification) {
    if (_isNavigating) return;
    _isNavigating = true;

    // 1. Mark as read immediately
    ref.read(notificationControllerProvider.notifier).markAsRead(notification.id);

    final route = notification.resolvedRoute;
    if (route != null && route.isNotEmpty) {
      try {
        final uri = Uri.parse(route);
        // Identify StatefulShellBranch routes that must be switched via go()
        // rather than pushed into the root navigator to prevent page key assertion conflicts.
        final isShellBranch = uri.path == '/deals' ||
            uri.path == '/work' ||
            uri.path == '/dashboard' ||
            uri.path == '/directory' ||
            uri.path == '/more';

        if (isShellBranch) {
          context.go(route);
        } else {
          context.push(route);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to open record: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted) {
            _isNavigating = false;
          }
        });
      }
    } else {
      _isNavigating = false;
      // Show technical detail dialog if no direct route exists
      NotificationDetailDialog.show(
        context,
        notification: notification,
      );
    }
  }

  void _clearFilters(NotificationController controller) {
    _searchController.clear();
    controller.setSearchQuery('');
    controller.selectCategory(NotificationCategory.all);
    controller.selectAlertsFilter();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationControllerProvider);
    final controller = ref.read(notificationControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.primaryNavy,
        elevation: 0,
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alerts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryNavy)),
            Text(
              'Stay updated on your business',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
            ),
          ],
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton.icon(
              key: const ValueKey('alerts_mark_all_read'),
              icon: const Icon(LucideIcons.check, size: 18),
              label: const Text('Mark all read', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
          PopupMenuButton<String>(
            key: const ValueKey('alerts_overflow'),
            icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
            tooltip: 'More',
            onSelected: (_) => controller.refresh(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                key: ValueKey('alerts_refresh'),
                value: 'refresh',
                child: Text('Refresh'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  controller.setSearchQuery(val);
                  setState(() {});
                },
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textSecondaryLight),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 14),
                          onPressed: () {
                            _searchController.clear();
                            controller.setSearchQuery('');
                            setState(() {});
                          },
                        )
                      : null,
                  hintText: 'Search alerts...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textDisabled),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // Filters
          SizedBox(
            height: 40,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _chip(
                  key: 'all',
                  icon: LucideIcons.bell,
                  label: 'All',
                  count: state.allNotifications.length,
                  selected: state.kindFilter == null && !state.unreadOnly,
                  onTap: () => controller.selectAlertsFilter(),
                ),
                _chip(
                  key: 'unread',
                  dotColor: AppColors.primary,
                  label: 'Unread',
                  count: state.unreadCount,
                  selected: state.kindFilter == null && state.unreadOnly,
                  onTap: () => controller.selectAlertsFilter(unreadOnly: true),
                ),
                for (final k in AlertKind.filterable)
                  _chip(
                    key: k.name,
                    icon: k.icon,
                    iconColor: k.color,
                    label: k.filterLabel,
                    count: state.kindCounts[k] ?? 0,
                    selected: state.kindFilter == k,
                    onTap: () => controller.selectAlertsFilter(kind: k),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 6),

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

  Widget _chip({
    required String key,
    IconData? icon,
    Color? iconColor,
    Color? dotColor,
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final fg = selected ? Colors.white : AppColors.textPrimaryLight;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.primary : AppColors.surfaceLight,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.borderLight)),
        child: InkWell(
          key: ValueKey('alerts_filter_$key'),
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: selected ? Colors.white : (iconColor ?? AppColors.textPrimaryLight)),
                  const SizedBox(width: 6),
                ],
                if (dotColor != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: selected ? Colors.white : dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withValues(alpha: 0.2) : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    key: ValueKey('alerts_filter_count_$key'),
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
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
          state.kindFilter != null ||
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
                child: const Icon(LucideIcons.bellOff, size: 28, color: AppColors.textDisabled),
              ),
              const SizedBox(height: 16),
              Text(
                isFiltered ? 'No matching notifications found' : 'All Caught Up!',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
              ),
              const SizedBox(height: 6),
              Text(
                isFiltered
                    ? 'Try adjusting your search or filters.'
                    : 'There are no operational alerts pending on your desk.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight),
              ),
              if (isFiltered) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.rotateCcw, size: 14),
                  label: const Text('Reset All Filters'),
                  onPressed: () => _clearFilters(controller),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Group by local day; filteredNotifications is already newest-first.
    final now = DateTime.now();
    final groups = <AlertGroup, List<BrokerNotification>>{};
    for (final n in state.filteredNotifications) {
      groups.putIfAbsent(AlertGroup.of(n.createdAt, now), () => []).add(n);
    }

    final children = <Widget>[];
    for (final g in AlertGroup.values) {
      final items = groups[g];
      if (items == null || items.isEmpty) continue;
      children.add(
        Padding(
          key: ValueKey('alerts_group_${g.name}'),
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 7),
          child: Row(
            children: [
              Text(g.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryNavy)),
              const Spacer(),
              // Earlier spans several days, so a single date would mislead.
              if (g != AlertGroup.earlier)
                Text(
                  DateFormat('dd MMM yyyy').format(items.first.createdAt.toLocal()),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
            ],
          ),
        ),
      );
      for (final item in items) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: NotificationCard(
            key: ValueKey('notif_card_${item.id}'),
            notification: item,
            onTap: (notif) => _handleRecordNavigation(context, notif),
            onAction: (notif) => _handleRecordNavigation(context, notif),
            onMarkAsRead: (notif) => controller.markAsRead(notif.id),
            onShowDetails: (notif) => NotificationDetailDialog.show(context, notification: notif),
          ),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: children,
    );
  }
}
