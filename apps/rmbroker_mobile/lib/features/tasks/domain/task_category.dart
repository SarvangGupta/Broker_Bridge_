import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Categories of broker action items and business follow-ups.
enum TaskCategory {
  all('All Categories', LucideIcons.layoutGrid),
  dealFollowUp('Deal Follow-up', Icons.handshake_outlined),
  mandateMatching('Buyer Mandate', LucideIcons.layers),
  offerInspection('Seller Offer', LucideIcons.package),
  dispatchTracking('Dispatch & Delivery', LucideIcons.truck),
  paymentCollection('Commission & Invoice', LucideIcons.indianRupee),
  disputeMediation('Dispute & Exception', LucideIcons.alertTriangle),
  counterpartyCall('Counterparty Coordination', LucideIcons.phoneCall),
  general('General Operational', LucideIcons.checkSquare);

  final String label;
  final IconData icon;

  const TaskCategory(this.label, this.icon);

  static TaskCategory fromString(String? value) {
    if (value == null) return TaskCategory.general;
    switch (value.trim().toLowerCase()) {
      case 'deal_follow_up':
      case 'dealfollowup':
      case 'deal':
        return TaskCategory.dealFollowUp;
      case 'mandate_matching':
      case 'mandatematching':
      case 'requirement':
      case 'mandate':
        return TaskCategory.mandateMatching;
      case 'offer_inspection':
      case 'offerinspection':
      case 'offer':
        return TaskCategory.offerInspection;
      case 'dispatch_tracking':
      case 'dispatchtracking':
      case 'dispatch':
      case 'delivery':
        return TaskCategory.dispatchTracking;
      case 'payment_collection':
      case 'paymentcollection':
      case 'payment':
      case 'invoice':
      case 'commission':
        return TaskCategory.paymentCollection;
      case 'dispute_mediation':
      case 'disputemediation':
      case 'dispute':
        return TaskCategory.disputeMediation;
      case 'counterparty_call':
      case 'counterpartycall':
      case 'counterparty':
      case 'contact':
        return TaskCategory.counterpartyCall;
      default:
        return TaskCategory.general;
    }
  }

  String toBackendString() {
    switch (this) {
      case TaskCategory.all:
        return 'all';
      case TaskCategory.dealFollowUp:
        return 'deal_follow_up';
      case TaskCategory.mandateMatching:
        return 'mandate_matching';
      case TaskCategory.offerInspection:
        return 'offer_inspection';
      case TaskCategory.dispatchTracking:
        return 'dispatch_tracking';
      case TaskCategory.paymentCollection:
        return 'payment_collection';
      case TaskCategory.disputeMediation:
        return 'dispute_mediation';
      case TaskCategory.counterpartyCall:
        return 'counterparty_call';
      case TaskCategory.general:
        return 'general';
    }
  }
}
