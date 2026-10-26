import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../data/notifications_repository.dart';
import '../domain/notification_model.dart';

class SellerNotificationsScreen extends StatefulWidget {
  final NotificationsRepository? repository;

  const SellerNotificationsScreen({super.key, this.repository});

  @override
  State<SellerNotificationsScreen> createState() =>
      _SellerNotificationsScreenState();
}

class _SellerNotificationsScreenState extends State<SellerNotificationsScreen> {
  late final NotificationsRepository _repository =
      widget.repository ?? NotificationsRepository();

  bool _isLoading = true;
  String _selectedFilter = 'ALL';
  List<SellerNotification> _notifications = [];

  final List<String> _filters = ['ALL', 'Unread', 'Commission', 'Messages'];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final data = await _repository.getNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = data;
      _isLoading = false;
    });
  }

  Future<void> _onNotificationTap(SellerNotification notif) async {
    await _repository.markAsRead(notif.id);
    if (!mounted) return;
    _loadNotifications();

    if (notif.actionUrl.isNotEmpty) {
      context.push(notif.actionUrl);
    }
  }

  List<SellerNotification> _applyFilter(String filter) {
    switch (filter) {
      case 'Unread':
        return _notifications.where((n) => !n.isRead).toList();
      case 'Commission':
        return _notifications.where((n) => n.isCommissionAlert).toList();
      case 'Messages':
        return _notifications.where((n) => n.isMessageAlert).toList();
      default:
        return _notifications;
    }
  }

  /// Section label for a notification, relative to today.
  String _groupLabel(DateTime createdAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This Week';
    return 'Earlier';
  }

  ({IconData icon, Color color}) _categoryStyle(SellerNotification n) {
    final type = n.eventType.toUpperCase();
    if (n.isCommissionAlert) {
      return (icon: LucideIcons.scale, color: AppColors.primary);
    }
    if (n.isMessageAlert) {
      return (icon: LucideIcons.messageSquare, color: Colors.blue.shade700);
    }
    if (type.contains('DISPATCH') || type.contains('VEHICLE')) {
      return (icon: LucideIcons.truck, color: Colors.purple.shade600);
    }
    if (type.contains('INVOICE')) {
      return (icon: LucideIcons.receipt, color: AppColors.success);
    }
    if (type.contains('LAB') || type.contains('QUALITY')) {
      return (icon: LucideIcons.flaskConical, color: Colors.amber.shade800);
    }
    if (type.contains('DEAL') || type.contains('BOOKING')) {
      return (icon: LucideIcons.fileText, color: AppColors.success);
    }
    return (icon: LucideIcons.info, color: AppColors.textSecondaryLight);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilter(_selectedFilter);

    // Flatten into headers + cards, keeping the repository's order.
    final rows = <Object>[];
    String? currentGroup;
    for (final n in filtered) {
      final label = _groupLabel(n.createdAt);
      if (label != currentGroup) {
        rows.add(label);
        currentGroup = label;
      }
      rows.add(n);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: 'Refresh',
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoadingIndicator(message: 'Loading Mandi alerts...')
          : Column(
              children: [
                // Filter chips with counts
                SizedBox(
                  height: 52,
                  child: ListView(
                    key: const Key('notification_filters'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    children: _filters
                        .map((filter) => _buildFilterChip(filter))
                        .toList(),
                  ),
                ),

                Expanded(
                  child: filtered.isEmpty
                      ? const AppEmptyState(
                          title: 'No Notifications',
                          message: 'You have no notifications matching this category.',
                          icon: LucideIcons.bellOff,
                        )
                      : RefreshIndicator(
                          onRefresh: _loadNotifications,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                            itemCount: rows.length,
                            itemBuilder: (context, index) {
                              final row = rows[index];
                              if (row is String) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    4,
                                    10,
                                    4,
                                    6,
                                  ),
                                  child: Text(
                                    row,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                );
                              }
                              return _buildNotificationCard(
                                row as SellerNotification,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = _selectedFilter == filter;
    final count = _applyFilter(filter).length;
    final icon = switch (filter) {
      'Unread' => LucideIcons.mail,
      'Commission' => LucideIcons.scale,
      'Messages' => LucideIcons.messageSquare,
      _ => LucideIcons.bell,
    };
    final label = filter == 'ALL' ? 'All' : filter;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: Key('notification_filter_$filter'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedFilter = filter),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.borderLight,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimaryLight,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(SellerNotification notif) {
    final style = _categoryStyle(notif);
    final group = _groupLabel(notif.createdAt);
    final isRecent = group == 'Today' || group == 'Yesterday';
    final time = DateFormat(
      isRecent ? 'hh:mm a' : 'dd MMM, hh:mm a',
    ).format(notif.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        key: Key('notification_card_${notif.id}'),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        onTap: () => _onNotificationTap(notif),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: style.color.withValues(alpha: 0.1),
              child: Icon(style.icon, size: 19, color: style.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: notif.isRead
                          ? FontWeight.w600
                          : FontWeight.w800,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notif.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMutedLight,
              ),
            ),
            const SizedBox(width: 6),
            if (!notif.isRead)
              Container(
                key: Key('notification_unread_${notif.id}'),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: AppColors.textSecondaryLight,
            ),
          ],
        ),
      ),
    );
  }
}
