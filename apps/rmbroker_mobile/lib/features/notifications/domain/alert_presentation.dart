import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'alert_kind.dart';
import 'notification_model.dart';

/// Card style of an alert: badge text, accent colour and icon.
enum AlertStyle {
  buy('BUY', Color(0xFF15803D), LucideIcons.shoppingCart),
  sell('SELL', Color(0xFF7C3AED), LucideIcons.store),
  message('MESSAGE', Color(0xFFD97706), LucideIcons.messageSquareText),
  match('MATCH', Color(0xFF2563EB), LucideIcons.gitCompareArrows),
  deal('DEAL', Color(0xFFEA580C), Icons.handshake_outlined),
  update('UPDATE', Color(0xFF64748B), LucideIcons.info);

  final String badge;
  final Color color;
  final IconData icon;
  const AlertStyle(this.badge, this.color, this.icon);
}

/// How one notification reads on its card, in plain language.
class AlertPresentation {
  final AlertStyle style;

  /// Prominent part of the heading, usually the counterparty.
  final String subject;

  /// Coloured remainder of the heading, e.g. "wants to buy".
  final String? verb;
  final String actionLabel;

  const AlertPresentation({
    required this.style,
    required this.subject,
    this.verb,
    required this.actionLabel,
  });

  static final RegExp _chatTitle = RegExp(r'^new message from\s+', caseSensitive: false);

  /// Name of the other party, resolved from the related record or the event title.
  static String? counterparty(BrokerNotification n) {
    final resolved = n.counterpartyName?.trim();
    if (resolved != null && resolved.isNotEmpty) return resolved;
    final title = n.title.trim();
    if (n.eventType.toUpperCase() == 'CHAT_MESSAGE' && _chatTitle.hasMatch(title)) {
      final name = title.replaceFirst(_chatTitle, '').trim();
      return name.isEmpty || name.toLowerCase() == 'your contact' ? null : name;
    }
    if (n.isWarehouseEvent) {
      final colon = title.indexOf(': ');
      if (colon > 0 && colon < title.length - 2) return title.substring(colon + 2).trim();
    }
    return null;
  }

  static AlertPresentation of(BrokerNotification n) {
    final type = n.eventType.toUpperCase();
    final name = counterparty(n);
    final fallbackAction = n.actionLabel ?? 'View details';

    if (type == 'CHAT_MESSAGE' || n.conversationId != null) {
      return AlertPresentation(
        style: AlertStyle.message,
        subject: name ?? 'A contact',
        verb: 'sent a message',
        actionLabel: 'Open Chat',
      );
    }
    if (n.isWarehouseEvent) {
      return AlertPresentation(
        style: AlertStyle.update,
        subject: name ?? 'A counterparty',
        verb: 'updated warehouse',
        actionLabel: 'View Directory',
      );
    }
    if (type.contains('MATCH')) {
      return const AlertPresentation(
        style: AlertStyle.match,
        subject: 'Your requirement',
        verb: 'has a match',
        actionLabel: 'View Matches',
      );
    }
    if (type == 'REQUIREMENT_CREATED' || type == 'NEW_BROKER_REQUEST') {
      return AlertPresentation(
        style: AlertStyle.buy,
        subject: name ?? 'A buyer',
        verb: 'wants to buy',
        actionLabel: 'View in Work Desk',
      );
    }
    if (type == 'OFFER_CREATED') {
      return AlertPresentation(
        style: AlertStyle.sell,
        subject: name ?? 'A seller',
        verb: 'wants to sell',
        actionLabel: 'View in Work Desk',
      );
    }
    final kind = AlertKind.of(n);
    if (type == 'DEAL_VERSION_UPDATE' || type == 'DEAL_UPDATED') {
      return AlertPresentation(
        style: AlertStyle.deal,
        subject: name == null ? 'Deal updated' : 'Deal updated · $name',
        // An update tied only to a requirement opens that requirement, not a deal.
        actionLabel: n.dealId != null ? 'View Deal' : 'View Requirement',
      );
    }
    if (kind == AlertKind.deal) {
      return AlertPresentation(
        style: AlertStyle.deal,
        subject: n.title,
        actionLabel: n.dealId != null ? 'View Deal' : fallbackAction,
      );
    }
    if (kind == AlertKind.offer) {
      return AlertPresentation(style: AlertStyle.sell, subject: n.title, actionLabel: 'View in Work Desk');
    }
    if (kind == AlertKind.requirement) {
      return AlertPresentation(style: AlertStyle.buy, subject: n.title, actionLabel: 'View in Work Desk');
    }
    return AlertPresentation(style: AlertStyle.update, subject: n.title, actionLabel: fallbackAction);
  }

  /// Up to two initials for the avatar, or null when no name is known.
  static String? initials(String? name) {
    final words = (name ?? '').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return null;
    final first = words.first.substring(0, 1);
    final second = words.length > 1 ? words[1].substring(0, 1) : '';
    return '$first$second'.toUpperCase();
  }
}
