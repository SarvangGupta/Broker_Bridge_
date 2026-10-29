import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/alert_kind.dart';
import '../../domain/notification_model.dart';

/// Compact alert card (four short rows): type label + time + menu; commodity
/// or activity title; reference · quantity · price; location / status + action.
/// The full message stays in the detail dialog and on the record screen.
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

  /// Primary line: the commodity when the record names one, else the part of
  /// the stored title after "Label: ", else the title itself.
  static String headline(BrokerNotification n) {
    for (final key in const ['commodity', 'commodityName', 'commodity_name']) {
      final v = n.payload?[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    final title = n.title.trim();
    final colon = title.indexOf(': ');
    if (colon > 0 && colon < title.length - 2) return title.substring(colon + 2).trim();
    return title;
  }

  /// "FOR Mill Delivery, Kota Mandi" -> place "Kota Mandi", basis "FOR Mill Delivery".
  static ({String? place, String? basis}) splitLocation(String? location) {
    final value = location?.trim();
    if (value == null || value.isEmpty) return (place: null, basis: null);
    final comma = value.lastIndexOf(',');
    if (comma <= 0 || comma >= value.length - 1) return (place: value, basis: null);
    return (place: value.substring(comma + 1).trim(), basis: value.substring(0, comma).trim());
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final isWarehouse = n.isWarehouseEvent;
    final kind = AlertKind.of(n);
    final isUnread = !n.isRead;
    final details = n.detailFields;

    final kindIcon = isWarehouse ? LucideIcons.warehouse : kind.icon;
    final kindColor = isWarehouse ? const Color(0xFF0D9488) : kind.color;

    final loc = splitLocation(details.location ?? n.warehouseAddress);
    final status = n.isUrgent
        ? 'Action required'
        : (isWarehouse ? (n.warehouseChangeType ?? loc.basis) : loc.basis);

    final facts = <(IconData, String)>[
      if (details.reference != null) (LucideIcons.fileText, details.reference!),
      if (details.quantity != null) (LucideIcons.truck, details.quantity!),
      if (details.price != null) (LucideIcons.indianRupee, details.price!),
      if (isWarehouse && n.warehouseName != null) (LucideIcons.warehouse, n.warehouseName!),
      if (isWarehouse && n.warehouseAddress != null && loc.place == null)
        (LucideIcons.mapPin, n.warehouseAddress!),
    ];

    return Semantics(
      label: '${isUnread ? 'Unread' : 'Read'} ${typeLabel(n)}: ${headline(n)}',
      child: Material(
        color: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isUnread ? kindColor.withValues(alpha: 0.3) : AppColors.borderLight,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(n),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 17),
                  child: Container(
                    key: isUnread ? ValueKey('notif_unread_${n.id}') : null,
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isUnread ? AppColors.primary : AppColors.textDisabled.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kindColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(kindIcon, size: 20, color: kindColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: type label · time · menu
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: kindColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                typeLabel(n),
                                key: ValueKey('notif_type_${n.id}'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: kindColor,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            n.formattedTime,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          SizedBox(
                            width: 30,
                            height: 24,
                            child: PopupMenuButton<String>(
                              key: ValueKey('notif_menu_${n.id}'),
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              tooltip: 'More actions',
                              icon: const Icon(
                                LucideIcons.ellipsisVertical,
                                color: AppColors.textSecondaryLight,
                              ),
                              onSelected: (v) {
                                if (v == 'read') onMarkAsRead?.call(n);
                                if (v == 'details') onShowDetails?.call(n);
                              },
                              itemBuilder: (_) => [
                                if (isUnread && onMarkAsRead != null)
                                  const PopupMenuItem(
                                    value: 'read',
                                    child: Text('Mark as read'),
                                  ),
                                if (onShowDetails != null)
                                  const PopupMenuItem(
                                    value: 'details',
                                    child: Text('Details'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Row 2: commodity / activity / warehouse headline
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          headline(n),
                          key: ValueKey('notif_headline_${n.id}'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ),

                      // Row 3: reference · quantity · price or location fact
                      if (facts.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          key: ValueKey('notif_detail_${n.id}'),
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 4,
                          children: [
                            for (var i = 0; i < facts.length; i++) ...[
                              if (i > 0)
                                Container(
                                  width: 1,
                                  height: 14,
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  color: AppColors.borderLight,
                                ),
                              _fact(facts[i].$1, facts[i].$2),
                            ],
                          ],
                        ),
                      ],

                      // Row 4: location · status · actions (Maps + Details)
                      if (loc.place != null ||
                          status != null ||
                          n.isActionable ||
                          n.googleMapsUrl != null) ...[
                        const SizedBox(height: 6),
                        _locationActionRow(
                          n,
                          kindColor,
                          loc.place,
                          status,
                        ),
                      ],
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

  /// Location / status beside the action; on narrow widths the action drops
  /// below so the location is never squeezed.
  Widget _locationActionRow(
    BrokerNotification n,
    Color accentColor,
    String? place,
    String? status,
  ) {
    final mapsUrl = n.googleMapsUrl;

    final info = (place != null || status != null)
        ? Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (place != null) _fact(LucideIcons.mapPin, place),
              if (status != null)
                Container(
                  key: ValueKey('notif_status_${n.id}'),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: (n.isUrgent ? AppColors.error : accentColor).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: n.isUrgent ? AppColors.error : accentColor,
                    ),
                  ),
                ),
            ],
          )
        : null;

    final actions = <Widget>[
      if (mapsUrl != null)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: TextButton.icon(
            key: ValueKey('notif_maps_${n.id}'),
            icon: const Icon(LucideIcons.mapPin, size: 13),
            label: const Text(
              'View on Google Maps',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.12),
              foregroundColor: const Color(0xFF0D9488),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
          padding: const EdgeInsets.only(right: 4),
          child: TextButton(
            key: ValueKey('notif_action_${n.id}'),
            style: TextButton.styleFrom(
              backgroundColor: accentColor.withValues(alpha: 0.1),
              foregroundColor: accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => (onAction ?? onTap)(n),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  n.actionLabel ?? 'View details',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(LucideIcons.chevronRight, size: 14),
              ],
            ),
          ),
        ),
    ];

    if (actions.isEmpty) return info ?? const SizedBox.shrink();

    final actionsRow = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );

    if (info == null) return Align(alignment: Alignment.centerRight, child: actionsRow);

    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 280
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondaryLight),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }
}
