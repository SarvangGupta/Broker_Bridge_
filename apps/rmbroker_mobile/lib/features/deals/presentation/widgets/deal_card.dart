import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/deal_model.dart';

class DealCard extends StatelessWidget {
  final DealItem deal;
  final VoidCallback onTap;

  const DealCard({
    super.key,
    required this.deal,
    required this.onTap,
  });

  Color _getStatusColor(DealStatus status) {
    switch (status) {
      case DealStatus.draft:
        return AppColors.textSecondaryLight;
      case DealStatus.negotiation:
        return const Color(0xFFD97706);
      case DealStatus.awaitingBuyerConfirmation:
      case DealStatus.awaitingSellerConfirmation:
        return const Color(0xFF7C3AED);
      case DealStatus.readyToFinalize:
        return AppColors.primary;
      case DealStatus.finalized:
      case DealStatus.inFulfillment:
      case DealStatus.completed:
        return AppColors.success;
      case DealStatus.cancelled:
      case DealStatus.disputed:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(deal.status);
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Ref + Status Chip + Version
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      deal.ref,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      deal.status.displayLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Text(
                      'v${deal.latestVersionNumber}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Commodity & Grade
              Text(
                deal.commodityName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              if (deal.gradeName != null && deal.gradeName!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Grade: ${deal.gradeName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // Counterparties: Buyer -> Seller
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
                            'Buyer',
                            style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            deal.buyerCompanyName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(LucideIcons.arrowRight, size: 14, color: AppColors.textSecondaryLight),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Seller',
                            style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            deal.sellerCompanyName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Commercial Terms: Agreed Qty, Agreed Rate, Total Valuation
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Agreed Volume',
                          style: TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          deal.formattedQuantity,
                          style: const TextStyle(
                            fontSize: 13,
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
                          'Rate / Unit',
                          style: TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${currencyFormat.format(deal.agreedPrice)} / ${deal.unitSymbol}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Total Valuation',
                          style: TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currencyFormat.format(deal.totalValuation),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Party Confirmations Status Row
              Row(
                children: [
                  _buildPartyBadge('Buyer', deal.buyerConfirmed),
                  const SizedBox(width: 8),
                  _buildPartyBadge('Seller', deal.sellerConfirmed),
                  const Spacer(),
                  const Text(
                    'Tap to view details',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartyBadge(String party, bool confirmed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: confirmed
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: confirmed
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.borderLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            confirmed ? LucideIcons.checkCircle2 : LucideIcons.clock,
            size: 11,
            color: confirmed ? AppColors.success : AppColors.textSecondaryLight,
          ),
          const SizedBox(width: 4),
          Text(
            '$party: ${confirmed ? "Confirmed" : "Pending"}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: confirmed ? AppColors.success : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
