import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/alert_kind.dart';
import '../../domain/alert_presentation.dart';
import '../../domain/notification_model.dart';

/// Compact alert card: badge, event and time; who did what; commodity; quantity
/// and location beside one action. Full details stay on the record screen.
class NotificationCard extends StatelessWidget {
  final BrokerNotification notification;
  final ValueChanged<BrokerNotification> onTap;
  final ValueChanged<BrokerNotification>? onAction;
  final ValueChanged<BrokerNotification>? onMarkAsRead;

  /// Opens the existing technical detail dialog (⋮ > Details).
  final ValueChanged<BrokerNotification>? onShowDetails;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    this.onAction,
    this.onMarkAsRead,
    this.onShowDetails,
  });

  static const Map<String, String> _typeLabels = {
    'REQUIREMENT_CREATED': 'New requirement',
    'NEW_BROKER_REQUEST': 'New requirement',
    'REQUIREMENT_UPDATED': 'Requirement updated',
    'MATCH_CREATED': 'New match',
    'MATCH_UPDATED': 'Match updated',
    'OFFER_CREATED': 'New offer',
    'OFFER_UPDATED': 'Offer updated',
    'OFFER_PRICE_CHANGED': 'Offer price changed',
    'AVAILABILITY_APPROVED': 'Offer approved',
    'AVAILABILITY_REJECTED': 'Offer rejected',
    'AVAILABILITY_EXPIRING': 'Offer expiring',
    'AVAILABILITY_EXPIRED': 'Offer expired',
    'NEGOTIATION_RECEIVED': 'Counter offer',
    'NEGOTIATION_ACCEPTED': 'Offer accepted',
    'BROKER_COUNTER': 'Counter offer',
    'DEAL_CREATED': 'New deal',
    'DEAL_UPDATED': 'Deal update',
    'DEAL_TERMS_CHANGED': 'Terms changed',
    'DEAL_VERSION_UPDATE': 'Deal update',
    'FINAL_CONFIRMATION_REQUIRED': 'Confirmation required',
    'CONFIRMATION_RECEIVED': 'Confirmation received',
    'CONFIRMATION_OUTCOME': 'Confirmation update',
    'DEAL_FINALIZED': 'Deal finalized',
    'DEAL_CANCELLED': 'Deal cancelled',
    'BOOKING_CREATED': 'Booking created',
    'WAREHOUSE_UPDATED': 'Warehouse update',
    'WAREHOUSE_CREATED': 'New warehouse',
    'WAREHOUSE_DEACTIVATED': 'Warehouse deactivated',
    'CHAT_MESSAGE': 'New message',
  };

  /// Short type label from the event type (never the full title).
  static String typeLabel(BrokerNotification n) {
    final type = n.eventType.toUpperCase();
    final known = _typeLabels[type];
    if (known != null) return known;
    final kind = AlertKind.of(n);
    if (kind == AlertKind.task) return type.contains('ASSIGN') ? 'Task assigned' : 'Task update';
    if (kind != AlertKind.other) return '${kind.label} update';
    final words = type.toLowerCase().split('_').where((w) => w.isNotEmpty).join(' ');
    return words.isEmpty ? 'Update' : '${words[0].toUpperCase()}${words.substring(1)}';
  }

  /// Town from stored delivery text. "FOR Mill, Kota Mandi" gives "Kota Mandi";
  /// a saved-location snapshot "Yard, Road, Kota, Rajasthan" gives "Kota".
  static String? placeOf(String? location) {
    final parts = (location ?? '').split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.length >= 4 ? parts[parts.length - 2] : parts.last;
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final look = AlertPresentation.of(n);
    final accent = look.style.color;
    final isUnread = !n.isRead;
    final name = AlertPresentation.counterparty(n);
    final initials = AlertPresentation.initials(name);
    final details = n.detailFields;
    final commodity = n.isWarehouseEvent ? n.warehouseName : n.commodityLabel;
    final quantity = details.quantity ?? n.resolvedQuantity;
    final place = placeOf(details.location ?? n.resolvedLocation ?? (n.isWarehouseEvent ? n.warehouseAddress : null));

    return Semantics(
      label: '${isUnread ? 'Unread' : 'Read'} ${typeLabel(n)}: ${look.subject} ${look.verb ?? ''}',
      child: Material(
        color: Color.alphaBlend(accent.withValues(alpha: isUnread ? 0.035 : 0.012), AppColors.surfaceLight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: isUnread ? accent.withValues(alpha: 0.25) : AppColors.borderLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(n),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 2, 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    key: isUnread ? ValueKey('notif_unread_${n.id}') : null,
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isUnread ? accent : AppColors.textDisabled.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: initials != null
                      ? Text(
                          initials,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: accent),
                        )
                      : Icon(look.style.icon, size: 20, color: accent),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _topRow(n, look, accent, isUnread),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text.rich(
                          TextSpan(
                            text: look.subject,
                            style: TextStyle(
                              fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                              color: AppColors.primaryNavy,
                            ),
                            children: [
                              if (look.verb != null)
                                TextSpan(
                                  text: ' ${look.verb}',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: accent),
                                ),
                            ],
                          ),
                          key: ValueKey('notif_headline_${n.id}'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14.5),
                        ),
                      ),
                      if (commodity != null && commodity.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Row(
                            children: [
                              Icon(
                                n.isWarehouseEvent ? LucideIcons.warehouse : LucideIcons.package,
                                size: 14,
                                color: AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  commodity,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimaryLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      _metaActionRow(n, look, accent, quantity, place),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topRow(BrokerNotification n, AlertPresentation look, Color accent, bool isUnread) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
          child: Text(
            look.style.badge,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: accent),
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            typeLabel(n),
            key: ValueKey('notif_type_${n.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
          ),
        ),
        const Text(' · ', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
        Text(n.formattedTime, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
        const Spacer(),
        if (isUnread && onMarkAsRead != null || onShowDetails != null)
          SizedBox(
            width: 30,
            height: 24,
            child: PopupMenuButton<String>(
              key: ValueKey('notif_menu_${n.id}'),
              padding: EdgeInsets.zero,
              iconSize: 18,
              tooltip: 'More actions',
              icon: const Icon(LucideIcons.ellipsisVertical, color: AppColors.textSecondaryLight),
              onSelected: (v) {
                if (v == 'read') onMarkAsRead?.call(n);
                if (v == 'details') onShowDetails?.call(n);
              },
              itemBuilder: (_) => [
                if (isUnread && onMarkAsRead != null)
                  const PopupMenuItem(value: 'read', child: Text('Mark as read')),
                if (onShowDetails != null) const PopupMenuItem(value: 'details', child: Text('Details')),
              ],
            ),
          ),
      ],
    );
  }

  /// Quantity and location beside the action; on narrow widths the action drops below.
  Widget _metaActionRow(
    BrokerNotification n,
    AlertPresentation look,
    Color accent,
    String? quantity,
    String? place,
  ) {
    final mapsUrl = n.googleMapsUrl;
    final facts = <Widget>[
      if (quantity != null) _fact(LucideIcons.truck, quantity),
      if (place != null) _fact(LucideIcons.mapPin, place),
      if (n.isUrgent)
        Text(
          'Action required',
          key: ValueKey('notif_status_${n.id}'),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.error),
        ),
    ];
    final info = facts.isEmpty
        ? null
        : Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: facts);

    final actions = <Widget>[
      if (mapsUrl != null)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: _ActionButton(
            buttonKey: ValueKey('notif_maps_${n.id}'),
            label: 'View on Google Maps',
            color: const Color(0xFF0D9488),
            onPressed: () async {
              final uri = Uri.tryParse(mapsUrl);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      if (n.isActionable)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: _ActionButton(
            buttonKey: ValueKey('notif_action_${n.id}'),
            label: look.actionLabel,
            color: accent,
            onPressed: () => (onAction ?? onTap)(n),
          ),
        ),
    ];
    if (actions.isEmpty) return info ?? const SizedBox.shrink();

    final actionsRow = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: actions,
    );
    if (info == null) return Align(alignment: Alignment.centerRight, child: actionsRow);

    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 300 && mapsUrl == null
          ? Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 6),
                actionsRow,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: actionsRow),
              ],
            ),
    );
  }

  Widget _fact(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondaryLight),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimaryLight),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Key buttonKey;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({required this.buttonKey, required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: buttonKey,
      style: TextButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 2),
          const Icon(LucideIcons.chevronRight, size: 14),
        ],
      ),
    );
  }
}
