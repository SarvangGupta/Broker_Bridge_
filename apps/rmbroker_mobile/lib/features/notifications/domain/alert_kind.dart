import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'notification_category.dart';
import 'notification_model.dart';

/// Alerts filter chips. Display-only grouping of existing notifications by the
/// record they concern; it does not change [NotificationCategory] or routing.
enum AlertKind {
  requirement(
    'Buyers',
    'Requirement',
    LucideIcons.layers,
    Color(0xFF0F766E),
  ),
  offer('Sellers', 'Offer', LucideIcons.tag, Color(0xFF7C3AED)),
  deal('Deals', 'Deal', Icons.handshake_outlined, Color(0xFFEA580C)),
  task('Tasks', 'Task', LucideIcons.squareCheck, Color(0xFF2563EB)),
  other('Other', 'Update', LucideIcons.info, Color(0xFF64748B));

  final String filterLabel;
  final String label;
  final IconData icon;
  final Color color;

  const AlertKind(this.filterLabel, this.label, this.icon, this.color);

  /// Chips shown in the filter row (tasks and other updates appear under All).
  static const filterable = [requirement, offer, deal];

  static AlertKind of(BrokerNotification n) {
    final type = n.eventType.toUpperCase();
    final url = (n.actionUrl ?? '').toLowerCase();
    if (type.contains('TASK') ||
        n.payload?['taskId'] != null ||
        n.payload?['task_id'] != null ||
        url.contains('/task')) {
      return task;
    }
    if (n.dealId != null ||
        n.category == NotificationCategory.dealsAndConfirmations) {
      return deal;
    }
    if (n.offerId != null ||
        type.contains('OFFER') ||
        type.contains('AVAILABILITY')) {
      return offer;
    }
    // Chat is buyer-to-broker only (migration 0043), so it counts under Buyers.
    if (type == 'CHAT_MESSAGE' ||
        n.requirementId != null ||
        type.contains('REQUIREMENT') ||
        type.contains('BROKER_REQUEST') ||
        type.contains('MATCH') ||
        n.category == NotificationCategory.requirementsAndOffers) {
      return requirement;
    }
    return other;
  }
}
