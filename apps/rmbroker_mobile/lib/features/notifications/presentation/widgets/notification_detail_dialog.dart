import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/notification_model.dart';

/// Modal dialog providing transparent inspection of notification audit trail and event metadata.
class NotificationDetailDialog extends StatelessWidget {
  final BrokerNotification notification;
  final VoidCallback? onOpenRecord;

  const NotificationDetailDialog({
    super.key,
    required this.notification,
    this.onOpenRecord,
  });

  static Future<void> show(
    BuildContext context, {
    required BrokerNotification notification,
    VoidCallback? onOpenRecord,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => NotificationDetailDialog(
        notification: notification,
        onOpenRecord: onOpenRecord,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = notification.category;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm:ss a');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(category.icon, size: 20, color: category.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.labelEn,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: category.color,
                  ),
                ),
                Text(
                  notification.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Message / Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Text(
                notification.message,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimaryLight,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Context Reason (Why it matters)
            if (notification.contextReason.isNotEmpty &&
                notification.contextReason != notification.message) ...[
              const Text(
                'Operational Context',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                notification.contextReason,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Technical & Audit Metadata
            const Divider(height: 1),
            const SizedBox(height: 10),
            _buildMetaRow('Event Type', notification.eventType),
            _buildMetaRow('Channel', notification.channel),
            _buildMetaRow('Delivery Status', notification.deliveryStatus),
            _buildMetaRow('Received At', dateFormat.format(notification.createdAt)),
            _buildMetaRow(
              'Read Status',
              notification.isRead
                  ? 'Read (${notification.readAt != null ? dateFormat.format(notification.readAt!) : "Yes"})'
                  : 'Unread',
            ),
            if (notification.idempotencyKey != null) ...[
              _buildMetaRow('Deduplication Key', notification.idempotencyKey!),
            ],
            if (notification.payload != null && notification.payload!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Event Payload References',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: notification.payload!.entries.map((e) {
                    return Text(
                      '• ${e.key}: ${e.value}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (notification.isActionable && onOpenRecord != null) ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: category.color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(LucideIcons.externalLink, size: 14),
            label: Text(notification.actionLabel ?? 'Open Record'),
            onPressed: () {
              Navigator.of(context).pop();
              onOpenRecord!();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
