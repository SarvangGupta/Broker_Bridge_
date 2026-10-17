import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/offer_model.dart';

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
    final statusColor = _getStatusColor(offer.status);
    final loadingColor = _getLoadingStatusColor(offer.loadingStatus);

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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Ref, Lot Number, Status Badge
              Row(
                children: [
                  Text(
                    offer.ref,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      offer.lotNumber,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      offer.status.displayLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Commodity & Grade
              Text(
                offer.commodityName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                offer.gradeName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 10),

              // Seller Company
              Row(
                children: [
                  const Icon(LucideIcons.store, size: 13, color: AppColors.textSecondaryLight),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      offer.sellerCompanyName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (offer.isSellerVerified)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.verified, size: 13, color: AppColors.primary),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Separated Inventory Quantities Box (Zero ambiguous mixing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Available',
                            style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            offer.formattedAvailableQuantity,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Lot',
                            style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            offer.formattedOfferedQuantity,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reserved',
                            style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            offer.formattedReservedQuantity,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Pricing & Location
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.indianRupee, size: 13, color: AppColors.textSecondaryLight),
                            const SizedBox(width: 4),
                            Text(
                              '₹${offer.askingPrice.toInt()} / ${offer.unitSymbol}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                        if (offer.confidentialMinimumPrice != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(LucideIcons.lock, size: 10, color: AppColors.goldDark),
                              const SizedBox(width: 3),
                              Text(
                                'Floor: ₹${offer.confidentialMinimumPrice!.toInt()} / ${offer.unitSymbol}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.goldDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.mapPin, size: 13, color: AppColors.textSecondaryLight),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${offer.districtName}, ${offer.stateName}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondaryLight,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bottom Row: Loading Readiness & Validity Expiration
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: loadingColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.truck, size: 11, color: loadingColor),
                        const SizedBox(width: 4),
                        Text(
                          offer.loadingStatus.displayLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: loadingColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.calendar, size: 11, color: AppColors.textSecondaryLight),
                      const SizedBox(width: 4),
                      Text(
                        'Valid: ${offer.validUntilFormatted}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: offer.isExpired ? AppColors.error : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
