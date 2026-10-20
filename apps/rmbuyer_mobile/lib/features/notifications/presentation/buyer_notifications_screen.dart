import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../data/buyer_notifications_repository.dart';
import '../domain/buyer_notification_model.dart';

/// Screen displaying user's procurement and transaction notifications.
class BuyerNotificationsScreen extends StatefulWidget {
  final BuyerNotificationsRepository? repository;

  const BuyerNotificationsScreen({super.key, this.repository});

  @override
  State<BuyerNotificationsScreen> createState() => _BuyerNotificationsScreenState();
}

class _BuyerNotificationsScreenState extends State<BuyerNotificationsScreen> {
  late final BuyerNotificationsRepository _repo;
  bool _isLoading = true;
  String? _errorMessage;
  List<BuyerNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? BuyerNotificationsRepository();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repo.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load notifications.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingIndicator(message: 'Loading procurement alerts...');
    }

    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage!,
        onRetry: _loadNotifications,
      );
    }

    if (_notifications.isEmpty) {
      return const AppEmptyState(
        title: 'No Notifications',
        description: 'You are all caught up with your procurement alerts and quotes.',
        icon: LucideIcons.bellOff,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final n = _notifications[index];
        return AppCard(
          padding: const EdgeInsets.all(16),
          color: n.isRead ? AppColors.surfaceLight : AppColors.primaryContainer.withValues(alpha: 0.3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: n.isRead ? AppColors.backgroundLight : AppColors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.bell,
                  size: 18,
                  color: n.isRead ? AppColors.textSecondaryLight : AppColors.secondaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('dd MMM, hh:mm a').format(n.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
