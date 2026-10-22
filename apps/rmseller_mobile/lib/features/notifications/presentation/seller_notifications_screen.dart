import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../data/notifications_repository.dart';
import '../domain/notification_model.dart';

class SellerNotificationsScreen extends StatefulWidget {
  const SellerNotificationsScreen({super.key});

  @override
  State<SellerNotificationsScreen> createState() =>
      _SellerNotificationsScreenState();
}

class _SellerNotificationsScreenState extends State<SellerNotificationsScreen> {
  final NotificationsRepository _repository = NotificationsRepository();

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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, hh:mm a');

    var filtered = _notifications;
    if (_selectedFilter == 'Unread') {
      filtered = filtered.where((n) => !n.isRead).toList();
    } else if (_selectedFilter == 'Commission') {
      filtered = filtered.where((n) => n.isCommissionAlert).toList();
    } else if (_selectedFilter == 'Messages') {
      filtered = filtered.where((n) => n.isMessageAlert).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Notifications Center'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoadingIndicator(message: 'Loading Mandi alerts...')
          : Column(
              children: [
                // Filter Chips Row
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              filter == 'ALL' ? 'All Alerts' : filter,
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primaryContainer,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimaryLight,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _selectedFilter = filter);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const Divider(height: 1),

                // Notifications List
                Expanded(
                  child: filtered.isEmpty
                      ? const AppEmptyState(
                          title: 'No Notifications',
                          message: 'You have no notifications matching this category.',
                          icon: LucideIcons.bellOff,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final notif = filtered[index];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AppCard(
                                onTap: () => _onNotificationTap(notif),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: notif.isCommissionAlert
                                          ? AppColors.primaryContainer
                                          : (notif.isMessageAlert
                                                ? Colors.blue.shade50
                                                : Colors.grey.shade100),
                                      child: Icon(
                                        notif.isCommissionAlert
                                            ? LucideIcons.scale
                                            : (notif.isMessageAlert
                                                  ? LucideIcons.messageSquare
                                                  : LucideIcons.bell),
                                        size: 18,
                                        color: notif.isCommissionAlert
                                            ? AppColors.primary
                                            : (notif.isMessageAlert
                                                  ? Colors.blue.shade700
                                                  : AppColors
                                                        .textSecondaryLight),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  notif.title,
                                                  style: TextStyle(
                                                    fontWeight: notif.isRead
                                                        ? FontWeight.w500
                                                        : FontWeight.w700,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              if (!notif.isRead)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color:
                                                            AppColors.primary,
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            notif.message,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppColors.textSecondaryLight,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                dateFormat.format(
                                                  notif.createdAt,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      AppColors.textMutedLight,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    notif.actionLabel,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  const Icon(
                                                    LucideIcons.chevronRight,
                                                    size: 12,
                                                    color: AppColors.primary,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
