import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';

/// Notification categories supported by RMBroker business events.
enum NotificationCategory {
  all(
    code: 'all',
    labelEn: 'All',
    labelHi: 'सभी',
    icon: LucideIcons.bell,
    color: AppColors.primary,
  ),
  requirementsAndOffers(
    code: 'requirements_offers',
    labelEn: 'Requirements & Offers',
    labelHi: 'मांग व ऑफर',
    icon: LucideIcons.layers,
    color: AppColors.secondary,
  ),
  dealsAndConfirmations(
    code: 'deals_confirmations',
    labelEn: 'Deals & Confirmations',
    labelHi: 'सौदा व पुष्टि',
    icon: Icons.handshake_outlined,
    color: AppColors.primaryDark,
  ),
  dispatchAndDelivery(
    code: 'dispatch_delivery',
    labelEn: 'Dispatch & Delivery',
    labelHi: 'प्रेषण व वितरण',
    icon: LucideIcons.truck,
    color: AppColors.warning,
  ),
  commissionAndInvoices(
    code: 'commission_invoices',
    labelEn: 'Commission & Invoices',
    labelHi: 'दलाली व बिल',
    icon: LucideIcons.indianRupee,
    color: AppColors.success,
  ),
  disputesAndExceptions(
    code: 'disputes_exceptions',
    labelEn: 'Disputes & Exceptions',
    labelHi: 'विवाद व अपवाद',
    icon: LucideIcons.alertTriangle,
    color: AppColors.error,
  ),
  system(
    code: 'system',
    labelEn: 'System',
    labelHi: 'सिस्टम',
    icon: LucideIcons.info,
    color: AppColors.info,
  );

  final String code;
  final String labelEn;
  final String labelHi;
  final IconData icon;
  final Color color;

  const NotificationCategory({
    required this.code,
    required this.labelEn,
    required this.labelHi,
    required this.icon,
    required this.color,
  });

  /// Maps backend `event_type` strings to the appropriate `NotificationCategory`.
  static NotificationCategory fromEventType(String? eventType) {
    if (eventType == null) return NotificationCategory.system;

    final normalized = eventType.trim().toUpperCase();

    switch (normalized) {
      // Requirements & Offers
      case 'NEW_BROKER_REQUEST':
      case 'AVAILABILITY_APPROVED':
      case 'AVAILABILITY_REJECTED':
      case 'AVAILABILITY_EXPIRING':
      case 'AVAILABILITY_EXPIRED':
      case 'MATCH_CREATED':
      case 'MATCH_UPDATED':
      case 'REQUIREMENT_CREATED':
      case 'REQUIREMENT_UPDATED':
      case 'OFFER_CREATED':
      case 'OFFER_UPDATED':
      case 'OFFER_PRICE_CHANGED':
        return NotificationCategory.requirementsAndOffers;

      // Deals & Confirmations
      case 'DEAL_CREATED':
      case 'DEAL_UPDATED':
      case 'DEAL_TERMS_CHANGED':
      case 'BROKER_COUNTER':
      case 'DEAL_VERSION_UPDATE':
      case 'FINAL_CONFIRMATION_REQUIRED':
      case 'CONFIRMATION_OUTCOME':
      case 'CONFIRMATION_RECEIVED':
      case 'DEAL_FINALIZED':
      case 'DEAL_CANCELLED':
      case 'BOOKING_CREATED':
      case 'NEGOTIATION_RECEIVED':
      case 'NEGOTIATION_ACCEPTED':
        return NotificationCategory.dealsAndConfirmations;

      // Dispatch & Delivery
      case 'LOADING_REMINDER':
      case 'DISPATCH_REMINDER':
      case 'DISPATCH_RECORDED':
      case 'DOCUMENT_ISSUE':
      case 'DELIVERY_UPDATE':
      case 'DELIVERY_RECORDED':
      case 'DELIVERY_ACKNOWLEDGED':
        return NotificationCategory.dispatchAndDelivery;

      // Commission & Invoices
      case 'COMMISSION_ELIGIBLE':
      case 'INVOICE_GENERATED':
      case 'INVOICE_STATUS_CHANGED':
      case 'INVOICE_PAID':
      case 'PAYMENT_UPDATE':
      case 'PAYMENT_RECORDED':
      case 'STATEMENT_READY':
        return NotificationCategory.commissionAndInvoices;

      // Disputes & Exceptions
      case 'QUALITY_REVIEW':
      case 'LAB_UPDATE':
      case 'DISPUTE_RAISED':
      case 'DISPUTE_STATUS_CHANGED':
      case 'DISPUTE_SETTLED':
      case 'REJECTION_RECORDED':
      case 'RECONCILIATION_EXCEPTION':
        return NotificationCategory.disputesAndExceptions;

      // System & KYC
      case 'KYC_STATUS':
      case 'SYSTEM':
      case 'SECURITY_ALERT':
      case 'ACCOUNT_NOTICE':
      default:
        return NotificationCategory.system;
    }
  }

  /// Parses from stored code string.
  static NotificationCategory fromCode(String? code) {
    if (code == null) return NotificationCategory.all;
    return NotificationCategory.values.firstWhere(
      (c) => c.code == code.toLowerCase().trim(),
      orElse: () => NotificationCategory.all,
    );
  }
}
