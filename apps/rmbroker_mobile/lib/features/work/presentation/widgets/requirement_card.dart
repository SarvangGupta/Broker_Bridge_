import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/requirement_model.dart';
import '../../domain/unit_utils.dart';

/// Allocation state shown in a requirement card's bottom row, derived only
/// from the requirement's own status and quantities.
enum RequirementAllocationView { notAllocated, partlyAllocated, fullyAllocated, expired, closed }

/// Compact buyer requirement card for the Work Desk list.
class RequirementCard extends StatelessWidget {
  final RequirementItem requirement;
  final VoidCallback onTap;
  final VoidCallback onFindMatches;
  final VoidCallback? onNegotiate;

  /// Set when this broker may allocate a seller (assigned, open, quantity left).
  final VoidCallback? onAllocateSeller;

  const RequirementCard({
    super.key,
    required this.requirement,
    required this.onTap,
    required this.onFindMatches,
    this.onNegotiate,
    this.onAllocateSeller,
  });

  static RequirementAllocationView allocationViewOf(RequirementItem r) {
    if (r.status == RequirementStatus.expired || r.isExpired) return RequirementAllocationView.expired;
    if (r.status == RequirementStatus.cancelled || r.status == RequirementStatus.fulfilled) {
      return RequirementAllocationView.closed;
    }
    if (r.status == RequirementStatus.fullyAllocated || (r.requestedQuantity > 0 && r.remainingQuantity <= 0)) {
      return RequirementAllocationView.fullyAllocated;
    }
    if (r.allocatedQuantity > 0) return RequirementAllocationView.partlyAllocated;
    return RequirementAllocationView.notAllocated;
  }

  static Color _statusColor(RequirementStatus status) {
    switch (status) {
      case RequirementStatus.open:
        return AppColors.primary;
      case RequirementStatus.matching:
        return const Color(0xFF7C3AED);
      case RequirementStatus.partiallyAllocated:
        return const Color(0xFF1D4ED8);
      case RequirementStatus.fullyAllocated:
      case RequirementStatus.fulfilled:
        return AppColors.success;
      case RequirementStatus.expired:
        return AppColors.textSecondaryLight;
      case RequirementStatus.cancelled:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = requirement;
    final statusColor = _statusColor(r.status);
    final price = NumberFormat.decimalPattern('en_IN');
    final delivery = r.deliveryTerms.trim().isEmpty ? 'Not specified' : r.deliveryTerms;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      color: AppColors.surfaceLight,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: status badge · Req ID · menu · chevron
              Row(
                children: [
                  Flexible(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.status.displayLabel.toUpperCase(),
                        key: const Key('requirement_status_badge'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 0.3),
                      ),
                    ),
                  ),
                  if (r.isUrgent) ...[
                    const SizedBox(width: 6),
                    const Icon(LucideIcons.clock, size: 13, color: AppColors.error),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Flexible(
                          child: Text(
                            'Req ID: ',
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
                          ),
                        ),
                        Flexible(
                          flex: 2,
                          child: Text(
                            r.ref,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _moreMenu(),
                  const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textSecondaryLight),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.commodityName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(LucideIcons.building2, size: 13, color: AppColors.textSecondaryLight),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            r.buyerCompanyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight),
                          ),
                        ),
                        if (r.isBuyerVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 13, color: AppColors.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _metric(LucideIcons.package, 'Quantity', r.formattedRequestedQuantity)),
                        Expanded(
                          child: _metric(
                            LucideIcons.coins,
                            'Target Price',
                            '₹${price.format(r.targetPrice.round())} / ${r.unitSymbol}',
                          ),
                        ),
                        Expanded(child: _metric(LucideIcons.mapPin, 'Delivery', delivery)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _metric(LucideIcons.calendar, 'Required By', r.targetDateFormatted),
                    const SizedBox(height: 10),
                    _allocationRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moreMenu() {
    final canNegotiate = onNegotiate != null && requirement.status != RequirementStatus.cancelled;
    if (!canNegotiate && !requirement.canBeMatched) return const SizedBox(width: 4);
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        key: const Key('requirement_card_menu'),
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: const Icon(LucideIcons.moreHorizontal, color: AppColors.textSecondaryLight),
        onSelected: (v) => v == 'negotiate' ? onNegotiate?.call() : onFindMatches(),
        itemBuilder: (_) => [
          if (canNegotiate)
            PopupMenuItem(
              value: 'negotiate',
              child: Text(requirement.isProposed ? 'Proposal' : 'Negotiate'),
            ),
          if (requirement.canBeMatched) const PopupMenuItem(value: 'matches', child: Text('Find Matches')),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondaryLight),
        const SizedBox(width: 5),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight)),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _allocationRow() {
    final r = requirement;
    final view = allocationViewOf(r);
    late final String label;
    late final IconData icon;
    late final Color color;
    switch (view) {
      case RequirementAllocationView.notAllocated:
        label = 'Seller not allocated';
        icon = LucideIcons.users;
        color = const Color(0xFFEA580C);
      case RequirementAllocationView.partlyAllocated:
        label = '${UnitUtils.format(r.allocatedQuantity, r.unitSymbol)} of ${r.formattedRequestedQuantity} allocated';
        icon = LucideIcons.truck;
        color = const Color(0xFF1D4ED8);
      case RequirementAllocationView.fullyAllocated:
        label = 'Fully allocated';
        icon = LucideIcons.checkCircle2;
        color = AppColors.success;
      case RequirementAllocationView.expired:
        label = 'Expired — allocation closed';
        icon = LucideIcons.clock;
        color = AppColors.textSecondaryLight;
      case RequirementAllocationView.closed:
        label = r.status.displayLabel;
        icon = LucideIcons.lock;
        color = AppColors.textSecondaryLight;
    }

    final allocate = view == RequirementAllocationView.notAllocated ? onAllocateSeller : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryNarrow = constraints.maxWidth < 240;

        final statusWidget = Container(
          key: const Key('requirement_allocation_status'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          constraints: const BoxConstraints(minHeight: 38),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        );

        final buttonWidget = OutlinedButton.icon(
          key: Key(allocate != null ? 'requirement_allocate_seller' : 'requirement_view_details'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 38),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: Icon(
            allocate != null ? LucideIcons.userPlus : LucideIcons.fileText,
            size: 15,
            color: AppColors.primary,
          ),
          label: Text(
            allocate != null ? 'Allocate Seller' : 'View Details',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          onPressed: allocate ?? onTap,
        );

        if (isVeryNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              statusWidget,
              const SizedBox(height: 8),
              buttonWidget,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: statusWidget),
            const SizedBox(width: 8),
            buttonWidget,
          ],
        );
      },
    );
  }
}
