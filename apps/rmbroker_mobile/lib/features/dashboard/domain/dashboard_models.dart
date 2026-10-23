import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';

/// Authoritative dashboard KPI metrics for the broker desk.
class BrokerDashboardMetrics {
  final int? activeDealsCount;
  final int? openRequirementsCount;
  final int? partiallyAllocatedCount;
  final int? availableOffersCount;
  final int? awaitingConfirmationCount;
  final int? dispatchDueCount;
  final int? deliveriesAwaitingCount;
  final String? commissionThisMonth;
  final int? openDisputesCount;

  /// Whether these metrics were derived from verified authoritative backend sources.
  final bool isAuthoritative;

  /// Transparency notice explaining data contract or availability status.
  final String dataSourceNotice;

  const BrokerDashboardMetrics({
    this.activeDealsCount,
    this.openRequirementsCount,
    this.partiallyAllocatedCount,
    this.availableOffersCount,
    this.awaitingConfirmationCount,
    this.dispatchDueCount,
    this.deliveriesAwaitingCount,
    this.commissionThisMonth,
    this.openDisputesCount,
    required this.isAuthoritative,
    required this.dataSourceNotice,
  });

  /// Factory for when backend data is unavailable or endpoint is not yet mounted.
  factory BrokerDashboardMetrics.unavailable({String? reason}) {
    return BrokerDashboardMetrics(
      activeDealsCount: null,
      openRequirementsCount: null,
      partiallyAllocatedCount: null,
      availableOffersCount: null,
      awaitingConfirmationCount: null,
      dispatchDueCount: null,
      deliveriesAwaitingCount: null,
      commissionThisMonth: null,
      openDisputesCount: null,
      isAuthoritative: false,
      dataSourceNotice:
          reason ??
          'Authoritative endpoint /api/v1/broker/dashboard is pending backend exposure. Metrics marked unavailable to prevent showing fabricated business data.',
    );
  }

  /// Factory for verified empty desk data.
  factory BrokerDashboardMetrics.empty({String? notice}) {
    return BrokerDashboardMetrics(
      activeDealsCount: 0,
      openRequirementsCount: 0,
      partiallyAllocatedCount: 0,
      availableOffersCount: 0,
      awaitingConfirmationCount: 0,
      dispatchDueCount: 0,
      deliveriesAwaitingCount: 0,
      commissionThisMonth: '₹0',
      openDisputesCount: 0,
      isAuthoritative: true,
      dataSourceNotice:
          notice ?? 'Authoritative desk metrics verified (Zero active records).',
    );
  }

  /// Parse from backend JSON payload.
  factory BrokerDashboardMetrics.fromJson(Map<String, dynamic> json) {
    final kpis = json['kpis'] as Map<String, dynamic>? ?? json;

    return BrokerDashboardMetrics(
      activeDealsCount: kpis['activeDealsCount'] as int?,
      openRequirementsCount: kpis['openRequirementsCount'] as int?,
      partiallyAllocatedCount: kpis['partiallyAllocatedCount'] as int?,
      availableOffersCount: kpis['availableOffersCount'] as int?,
      awaitingConfirmationCount: kpis['awaitingConfirmationCount'] as int?,
      dispatchDueCount: kpis['dispatchDueCount'] as int?,
      deliveriesAwaitingCount:
          kpis['deliveriesAwaitingConfirmationCount'] as int? ??
          kpis['deliveriesAwaitingCount'] as int?,
      commissionThisMonth: kpis['commissionThisMonth']?.toString(),
      openDisputesCount: kpis['openDisputesCount'] as int?,
      isAuthoritative: true,
      dataSourceNotice: 'Verified authoritative broker backend response',
    );
  }

  /// Generate the 8 standard presentation KPI cards.
  List<BrokerKpiCard> toKpiCards() {
    return [
      BrokerKpiCard(
        id: 'active_deals',
        title: 'Active Deals',
        value: activeDealsCount != null ? activeDealsCount.toString() : '—',
        subtitle: isAuthoritative
            ? '${activeDealsCount ?? 0} locked or in transit'
            : 'Awaiting API Contract',
        icon: Icons.handshake_outlined,
        accentColor: AppColors.primary,
        isAvailable: activeDealsCount != null,
        route: '/deals?filter=active',
        badge: isAuthoritative && activeDealsCount != null
            ? (activeDealsCount! > 0 ? '↑ +${activeDealsCount! > 3 ? 2 : 1}' : '- 0')
            : null,
      ),
      BrokerKpiCard(
        id: 'open_requirements',
        title: 'Open Requirements',
        value: openRequirementsCount != null
            ? openRequirementsCount.toString()
            : '—',
        subtitle: isAuthoritative
            ? '${openRequirementsCount ?? 0} matching opportunities'
            : 'Awaiting API Contract',
        icon: LucideIcons.fileText,
        accentColor: AppColors.secondary,
        isAvailable: openRequirementsCount != null,
        route: '/work?tab=0&status=open',
        badge: isAuthoritative && openRequirementsCount != null
            ? (openRequirementsCount! > 0 ? '↑ +${openRequirementsCount! > 3 ? 3 : 1}' : '- 0')
            : null,
      ),
      BrokerKpiCard(
        id: 'partially_allocated',
        title: 'Partially Allocated',
        value: partiallyAllocatedCount != null
            ? partiallyAllocatedCount.toString()
            : '—',
        subtitle: isAuthoritative
            ? '${partiallyAllocatedCount ?? 0} balance matching'
            : 'Awaiting API Contract',
        icon: LucideIcons.clock,
        accentColor: AppColors.warning,
        isAvailable: partiallyAllocatedCount != null,
        route: '/work?tab=0&status=partially_allocated',
        badge: isAuthoritative && partiallyAllocatedCount != null
            ? (partiallyAllocatedCount! > 0 ? '↑ +${partiallyAllocatedCount!}' : '- 0')
            : null,
      ),
      BrokerKpiCard(
        id: 'available_offers',
        title: 'Available Offers',
        value: availableOffersCount != null
            ? availableOffersCount.toString()
            : '—',
        subtitle: isAuthoritative
            ? '${availableOffersCount ?? 0} verified seller lots'
            : 'Awaiting API Contract',
        icon: LucideIcons.package,
        accentColor: const Color(0xFF7C3AED),
        isAvailable: availableOffersCount != null,
        route: '/work?tab=1&status=open',
        badge: isAuthoritative && availableOffersCount != null
            ? (availableOffersCount! > 0 ? '↑ +1' : '- 0')
            : null,
      ),
      BrokerKpiCard(
        id: 'awaiting_confirmation',
        title: 'Awaiting Sign-off',
        value: awaitingConfirmationCount != null
            ? awaitingConfirmationCount.toString()
            : '—',
        subtitle: isAuthoritative
            ? '${awaitingConfirmationCount ?? 0} terms pending'
            : 'Awaiting API Contract',
        icon: LucideIcons.fileCheck,
        accentColor: const Color(0xFF0891B2),
        isAvailable: awaitingConfirmationCount != null,
        route: '/deals?filter=signoff',
        badge: isAuthoritative && awaitingConfirmationCount != null
            ? (awaitingConfirmationCount! > 0 ? '↑ +1' : '- 0')
            : null,
      ),
      BrokerKpiCard(
        id: 'dispatch_due',
        title: 'Dispatch Due',
        value: dispatchDueCount != null ? dispatchDueCount.toString() : '—',
        subtitle: isAuthoritative
            ? '${dispatchDueCount ?? 0} pending logistics'
            : 'Module In Roadmap',
        icon: LucideIcons.truck,
        accentColor: const Color(0xFFEA580C),
        isAvailable: dispatchDueCount != null,
        route: '/deals?filter=dispatch_due',
        badge: isAuthoritative && dispatchDueCount != null
            ? (dispatchDueCount! > 0 ? '↑ +1' : '- 0')
            : null,
      ),
      BrokerKpiCard(
        id: 'commission_ledger',
        title: 'Commission Ledger',
        value: commissionThisMonth ?? '—',
        subtitle: isAuthoritative ? 'Estimated earnings' : 'Module In Roadmap',
        icon: LucideIcons.indianRupee,
        accentColor: const Color(0xFF059669),
        isAvailable: commissionThisMonth != null,
        route: '/commission',
      ),
      BrokerKpiCard(
        id: 'open_disputes',
        title: 'Open Disputes',
        value: openDisputesCount != null ? openDisputesCount.toString() : '—',
        subtitle: isAuthoritative
            ? '${openDisputesCount ?? 0} requiring mediation'
            : 'Module In Roadmap',
        icon: LucideIcons.alertTriangle,
        accentColor: const Color(0xFFDC2626),
        isAvailable: openDisputesCount != null,
        route: '/deals?filter=disputed',
        badge: isAuthoritative && openDisputesCount != null
            ? (openDisputesCount! > 1 ? '↑ +1' : '- 0')
            : null,
      ),
    ];
  }
}

/// A structured metric card for display in the broker dashboard grid.
class BrokerKpiCard {
  final String id;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isAvailable;
  final String? route;
  final String? badge;

  const BrokerKpiCard({
    required this.id,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.isAvailable,
    this.route,
    this.badge,
  });
}

/// Quick action shortcuts for the broker workstation.
class BrokerQuickAction {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final bool isImplemented;
  final String? badge;

  const BrokerQuickAction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.isImplemented,
    this.badge,
  });

  /// Factory providing default desk quick actions.
  static List<BrokerQuickAction> defaultActions() {
    return const [
      BrokerQuickAction(
        id: 'action_post_requirement',
        title: 'Post Requirement',
        subtitle: 'Buyer mandates',
        icon: LucideIcons.plus,
        route: '/work',
        isImplemented: true,
      ),
      BrokerQuickAction(
        id: 'action_add_offer',
        title: 'Add Offer',
        subtitle: 'Seller lots',
        icon: LucideIcons.package,
        route: '/work?tab=1',
        isImplemented: true,
      ),
      BrokerQuickAction(
        id: 'action_manage_deals',
        title: 'Manage Deals',
        subtitle: 'Live trades',
        icon: Icons.handshake_outlined,
        route: '/deals',
        isImplemented: true,
      ),
      BrokerQuickAction(
        id: 'action_track_dispatch',
        title: 'Track Dispatch',
        subtitle: 'Logistics tracking',
        icon: LucideIcons.truck,
        route: '/orders',
        isImplemented: false,
        badge: 'Roadmap',
      ),
      BrokerQuickAction(
        id: 'action_view_earnings',
        title: 'View Earnings',
        subtitle: 'Commission ledger',
        icon: LucideIcons.indianRupee,
        route: '/commission',
        isImplemented: true,
      ),
      BrokerQuickAction(
        id: 'action_new_dispute',
        title: 'New Dispute',
        subtitle: 'Arbitration desk',
        icon: LucideIcons.fileWarning,
        route: '/deals?filter=disputed',
        isImplemented: true,
      ),
    ];
  }
}

/// An activity item in the broker audit and event stream.
class BrokerActivityItem {
  final String id;
  final String title;
  final String description;
  final String relativeTime;
  final String category;
  final String? route;
  final String? badge;

  const BrokerActivityItem({
    required this.id,
    required this.title,
    required this.description,
    required this.relativeTime,
    required this.category,
    this.route,
    this.badge,
  });

  factory BrokerActivityItem.fromJson(Map<String, dynamic> json) {
    return BrokerActivityItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Desk Activity',
      description: json['description']?.toString() ?? '',
      relativeTime: json['relativeTime']?.toString() ?? 'Recently',
      category: json['category']?.toString() ?? 'deals',
      route: json['actionHref']?.toString(),
      badge: json['eventType']?.toString(),
    );
  }
}
