import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/offer_model.dart';

class OfferDetailSheet extends StatelessWidget {
  final OfferItem offer;

  const OfferDetailSheet({
    super.key,
    required this.offer,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required OfferItem offer,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => OfferDetailSheet(offer: offer),
    );
  }

  Widget _buildQuantityRow(String label, double qty, String unit, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$qty $unit',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar
            Row(
              children: [
                Text(
                  offer.ref,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    offer.lotNumber,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Commodity & Seller
            Text(
              offer.commodityName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Grade: ${offer.gradeName}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(LucideIcons.store, size: 14, color: AppColors.textSecondaryLight),
                const SizedBox(width: 5),
                Text(
                  offer.sellerCompanyName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (offer.isSellerVerified)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.verified, size: 14, color: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Inventory Quantities Breakdown
            const Text(
              'Seller Lot Inventory Breakdown',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  _buildQuantityRow(
                    'Available for Match',
                    offer.availableQuantity,
                    offer.unitSymbol,
                    AppColors.success,
                  ),
                  const Divider(height: 10),
                  _buildQuantityRow(
                    'Total Offered Lot',
                    offer.offeredQuantity,
                    offer.unitSymbol,
                    AppColors.textPrimaryLight,
                  ),
                  _buildQuantityRow(
                    'Reserved (Pending Allocation)',
                    offer.reservedQuantity,
                    offer.unitSymbol,
                    const Color(0xFFD97706),
                  ),
                  _buildQuantityRow(
                    'Sold / Contracted',
                    offer.soldQuantity,
                    offer.unitSymbol,
                    AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pricing & Broker Floor
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Asking Price', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                      const SizedBox(height: 2),
                      Text(
                        '₹${offer.askingPrice.toInt()} / ${offer.unitSymbol}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                if (offer.confidentialMinimumPrice != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Confidential Floor (Broker Only)',
                          style: TextStyle(fontSize: 11, color: AppColors.goldDark, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${offer.confidentialMinimumPrice!.toInt()} / ${offer.unitSymbol}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.goldDark),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Location & Loading Readiness
            Text(
              'Dispatch Location: ${offer.districtName}, ${offer.stateName}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimaryLight),
            ),
            const SizedBox(height: 4),
            Text(
              'Loading Readiness: ${offer.loadingStatus.displayLabel}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight),
            ),
            if (offer.loadingRemarks != null) ...[
              const SizedBox(height: 4),
              Text(
                'Remarks: ${offer.loadingRemarks}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
              ),
            ],
            const SizedBox(height: 16),

            // Lab Report Policy Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.flaskConical, size: 16, color: AppColors.textSecondaryLight),
                      const SizedBox(width: 8),
                      Text(
                        offer.labReportUrl != null ? 'Lab Report Attached' : 'No Lab Report Attached',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${offer.labReportDisclaimer}. Lab reports are optional and remain seller-declared per platform policy.',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
