import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/desk_card_parts.dart';
import '../../domain/offer_model.dart';

/// Compact seller lot card for the Work Desk, in the Requirements card style.
class OfferCard extends StatelessWidget {
  final OfferItem offer;
  final VoidCallback onTap;

  const OfferCard({
    super.key,
    required this.offer,
    required this.onTap,
  });

  Color _getStatusColor(OfferStatus status) {
    switch (status) {
      case OfferStatus.open:
        return AppColors.success;
      case OfferStatus.partiallyAvailable:
        return const Color(0xFFD97706);
      case OfferStatus.reserved:
        return AppColors.info;
      case OfferStatus.unavailable:
      case OfferStatus.cancelled:
        return AppColors.error;
      case OfferStatus.expired:
        return AppColors.textDisabled;
    }
  }

  Color _getLoadingStatusColor(LoadingReadiness status) {
    switch (status) {
      case LoadingReadiness.readyToLoad:
        return AppColors.success;
      case LoadingReadiness.loadingInProgress:
        return AppColors.info;
      case LoadingReadiness.delayed:
      case LoadingReadiness.blocked:
        return AppColors.error;
      case LoadingReadiness.notReady:
        return AppColors.textSecondaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern('en_IN');
    final location = [offer.districtName, offer.stateName].where((s) => s.trim().isNotEmpty).join(', ');

    return DeskCardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: status · lot · ref · chevron
          Row(
            children: [
              Flexible(flex: 3, child: DeskStatusBadge(label: offer.status.displayLabel, color: _getStatusColor(offer.status))),
              const SizedBox(width: 6),
              Flexible(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    offer.lotNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: Text(
                  offer.ref,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textSecondaryLight),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.commodityName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
                ),
                Text(
                  offer.gradeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(LucideIcons.store, size: 13, color: AppColors.textSecondaryLight),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        offer.sellerCompanyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight),
                      ),
                    ),
                    if (offer.isSellerVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 13, color: AppColors.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Inventory: available · total lot · reserved
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DeskMetric(
                        icon: LucideIcons.package,
                        label: 'Available',
                        value: offer.formattedAvailableQuantity,
                        valueColor: AppColors.success,
                      ),
                    ),
                    Expanded(
                      child: DeskMetric(
                        icon: LucideIcons.boxes,
                        label: 'Total Lot',
                        value: offer.formattedOfferedQuantity,
                      ),
                    ),
                    Expanded(
                      child: DeskMetric(
                        icon: LucideIcons.lock,
                        label: 'Reserved',
                        value: offer.formattedReservedQuantity,
                        valueColor: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Commercial: asking price · floor (when set) · location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DeskMetric(
                        icon: LucideIcons.coins,
                        label: 'Asking Price',
                        value: '₹${money.format(offer.askingPrice.round())} / ${offer.unitSymbol}',
                      ),
                    ),
                    if (offer.confidentialMinimumPrice != null)
                      Expanded(
                        child: DeskMetric(
                          icon: LucideIcons.shieldCheck,
                          label: 'Floor',
                          value: '₹${money.format(offer.confidentialMinimumPrice!.round())} / ${offer.unitSymbol}',
                          valueColor: AppColors.goldDark,
                        ),
                      ),
                    Expanded(
                      child: DeskMetric(
                        icon: LucideIcons.mapPin,
                        label: 'Location',
                        value: location.isEmpty ? 'Not specified' : location,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Bottom row: readiness · validity
                Row(
                  children: [
                    Flexible(
                      child: DeskStatusPill(
                        icon: LucideIcons.truck,
                        label: offer.loadingStatus.displayLabel,
                        color: _getLoadingStatusColor(offer.loadingStatus),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: DeskStatusPill(
                        icon: LucideIcons.calendar,
                        label: 'Valid: ${offer.validUntilFormatted}',
                        color: offer.isExpired ? AppColors.error : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
