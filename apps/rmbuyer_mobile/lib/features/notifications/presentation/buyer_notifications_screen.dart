import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../data/buyer_notifications_repository.dart';
import '../domain/buyer_notification_model.dart';
import '../../../l10n/app_localizations.dart';

/// Notification Center: the signed-in Buyer's own notifications from
/// `public.notifications`, with read state persisted to the backend.
class BuyerNotificationsScreen extends StatefulWidget {
  final BuyerNotificationsRepository? repository;

  const BuyerNotificationsScreen({super.key, this.repository});

  /// Interface label for an event type; unknown types are a generic "Update".
  static Tr eventLabel(String eventType) => switch (eventType) {
    'DEAL_VERSION_UPDATE' ||
    'BROKER_COUNTER' ||
    'NEW_BROKER_REQUEST' ||
    'NEGOTIATION_RECEIVED' => Tr.evtProposal,
    'FINAL_CONFIRMATION_REQUIRED' ||
    'CONFIRMATION_OUTCOME' => Tr.evtConfirmation,
    'DEAL_CREATED' ||
    'DEAL_UPDATED' ||
    'BOOKING_CREATED' ||
    'NEGOTIATION_ACCEPTED' => Tr.evtDeal,
    'DISPATCH_REMINDER' ||
    'DELIVERY_UPDATE' ||
    'LOADING_REMINDER' => Tr.evtFulfilment,
    'DOCUMENT_ISSUE' => Tr.evtDocument,
    'PAYMENT_UPDATE' => Tr.evtPayment,
    'REQUIREMENT_CREATED' ||
    'MATCH_CREATED' ||
    'MATCH_UPDATED' => Tr.evtRequirement,
    _ => Tr.evtUpdate,
  };

  @override
  State<BuyerNotificationsScreen> createState() =>
      _BuyerNotificationsScreenState();
}

class _BuyerNotificationsScreenState extends State<BuyerNotificationsScreen> {
  late final BuyerNotificationsRepository _repo;
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _unreadOnly = false;
  bool _markingAll = false;
  final Set<String> _busy = {};
  List<BuyerNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? BuyerNotificationsRepository();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }
    try {
      final list = await _repo.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _isLoading = false;
        _loadFailed = false;
      });
    } catch (e) {
      debugPrint('Notifications load failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // On a failed pull-to-refresh, keep the rows already shown.
        _loadFailed = showSpinner || _notifications.isEmpty;
      });
      if (!showSpinner && _notifications.isNotEmpty) {
        _snack(context.tr(Tr.notifError));
      }
    }
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _replace(
    String id,
    BuyerNotification Function(BuyerNotification) change,
  ) {
    setState(() {
      _notifications = [
        for (final n in _notifications) n.id == id ? change(n) : n,
      ];
    });
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      final updated = await _repo.markAllAsRead();
      if (!mounted) return;
      setState(() {
        _notifications = [
          for (final n in _notifications)
            updated.contains(n.id) ? n.asRead() : n,
        ];
      });
    } catch (e) {
      debugPrint('Mark all read failed: $e');
      if (mounted) _snack(context.tr(Tr.notifMarkReadFailed));
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _onTap(BuyerNotification n) async {
    if (_busy.contains(n.id)) return;
    final target = NotificationTarget.resolve(n);
    bool? ownRequirement;
    // Busy only while talking to the server (read state, ownership check).
    setState(() => _busy.add(n.id));
    try {
      if (!n.isRead) {
        try {
          await _repo.markAsRead(n.id);
          if (mounted) _replace(n.id, (x) => x.asRead());
        } catch (e) {
          debugPrint('Mark read failed: $e');
          if (mounted) _snack(context.tr(Tr.notifMarkReadFailed));
        }
      }
      if (target.kind == NotificationTargetKind.requirement) {
        try {
          ownRequirement = await _repo.isOwnRequirement(target.id!);
        } catch (e) {
          debugPrint('Requirement access check failed: $e');
          if (mounted) _snack(context.tr(Tr.notifOpenFailed));
          return;
        }
      }
    } finally {
      if (mounted) setState(() => _busy.remove(n.id));
    }
    if (mounted) await _open(n, target, ownRequirement: ownRequirement);
  }

  Future<void> _open(
    BuyerNotification n,
    NotificationTarget target, {
    bool? ownRequirement,
  }) async {
    switch (target.kind) {
      case NotificationTargetKind.requirement:
        if (ownRequirement == true) {
          await context.push('/requirements/${target.id}');
        } else {
          await _showDetail(n, note: context.tr(Tr.notifTargetUnavailable));
        }
      case NotificationTargetKind.requirementsList:
        context.go('/requirements');
      case NotificationTargetKind.deal:
      case NotificationTargetKind.offer:
        // Buyers have no read access to deals/quotations yet; never open a screen
        // that would fall back to sample data.
        await _showDetail(n, note: context.tr(Tr.notifTargetNotSupported));
      case NotificationTargetKind.none:
        await _showDetail(n);
    }
  }

  Future<void> _showDetail(BuyerNotification n, {String? note}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          key: const Key('notification-detail'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ctx.tr(Tr.notifDetailTitle),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMutedLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _title(ctx, n),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                _EventChip(
                  label: ctx.tr(
                    BuyerNotificationsScreen.eventLabel(n.eventType),
                  ),
                ),
                if (n.message.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    n.message,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
                if (n.contextReason.isNotEmpty &&
                    n.contextReason != n.message) ...[
                  const SizedBox(height: 8),
                  Text(
                    n.contextReason,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryLight,
                      height: 1.4,
                    ),
                  ),
                ],
                if (n.createdAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _timestamp(n.createdAt!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMutedLight,
                    ),
                  ),
                ],
                if (note != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    key: const Key('notification-target-note'),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          LucideIcons.info,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            note,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(ctx.tr(Tr.commonClose)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _title(BuildContext context, BuyerNotification n) =>
      n.title.isNotEmpty
      ? n.title
      : context.tr(BuyerNotificationsScreen.eventLabel(n.eventType));

  static String _timestamp(DateTime t) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(t.toLocal());

  @override
  Widget build(BuildContext context) {
    final unread = _unreadCount;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(Tr.titleNotifications)),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!_isLoading && !_loadFailed && unread > 0)
            TextButton(
              key: const Key('notifications-mark-all'),
              onPressed: _markingAll ? null : _markAllRead,
              child: Text(context.tr(Tr.notifMarkAllRead)),
            ),
        ],
      ),
      body: SafeArea(child: _buildBody(unread)),
    );
  }

  Widget _buildBody(int unread) {
    if (_isLoading) {
      return AppLoadingIndicator(message: context.tr(Tr.notifLoading));
    }
    if (_loadFailed) {
      return AppErrorState(
        message: context.tr(Tr.notifError),
        onRetry: _loadNotifications,
      );
    }

    final visible = _unreadOnly
        ? _notifications.where((n) => !n.isRead).toList()
        : _notifications;
    final truncated =
        _notifications.length >= BuyerNotificationsRepository.pageSize;

    return RefreshIndicator(
      onRefresh: () => _loadNotifications(showSpinner: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (_notifications.isNotEmpty) ...[
            Row(
              children: [
                ChoiceChip(
                  key: const Key('notifications-filter-all'),
                  label: Text(context.tr(Tr.notifFilterAll)),
                  selected: !_unreadOnly,
                  onSelected: (_) => setState(() => _unreadOnly = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const Key('notifications-filter-unread'),
                  label: Text(context.tr(Tr.notifFilterUnread)),
                  selected: _unreadOnly,
                  onSelected: (_) => setState(() => _unreadOnly = true),
                ),
                const Spacer(),
                Text(
                  context.trN(Tr.notifUnreadCount, unread),
                  key: const Key('notifications-unread-count'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            if (truncated)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  context.trN(
                    Tr.notifLatestNote,
                    BuyerNotificationsRepository.pageSize,
                  ),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMutedLight,
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
          if (_notifications.isEmpty)
            AppEmptyState(
              title: context.tr(Tr.notifEmptyTitle),
              description: context.tr(Tr.notifEmptyBody),
              icon: LucideIcons.bellOff,
            )
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                context.tr(Tr.notifUnreadEmpty),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondaryLight),
              ),
            )
          else
            for (final n in visible) ...[
              _NotificationTile(
                notification: n,
                title: _title(context, n),
                timestamp: n.createdAt == null
                    ? null
                    : _timestamp(n.createdAt!),
                eventLabel: context.tr(
                  BuyerNotificationsScreen.eventLabel(n.eventType),
                ),
                canOpen: NotificationTarget.resolve(n).canOpen,
                busy: _busy.contains(n.id),
                onTap: () => _onTap(n),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final BuyerNotification notification;
  final String title;
  final String? timestamp;
  final String eventLabel;
  final bool canOpen;
  final bool busy;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.title,
    required this.timestamp,
    required this.eventLabel,
    required this.canOpen,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final unread = !n.isRead;
    return Material(
      key: Key('notification-${n.id}'),
      color: unread
          ? AppColors.primaryContainer.withValues(alpha: 0.35)
          : AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : AppColors.borderLight,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 10),
                child: Container(
                  key: unread ? Key('notification-unread-${n.id}') : null,
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: unread ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _EventChip(label: eventLabel),
                        const Spacer(),
                        if (timestamp != null)
                          Flexible(
                            child: Text(
                              timestamp!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMutedLight,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    if (n.message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        n.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (canOpen) ...[
                      const SizedBox(height: 6),
                      Text(
                        context.tr(Tr.notifOpen),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 4),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  final String label;

  const _EventChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.secondaryDark,
        ),
      ),
    );
  }
}
