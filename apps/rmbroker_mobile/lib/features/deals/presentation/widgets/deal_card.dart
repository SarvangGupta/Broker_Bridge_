import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/desk_card_parts.dart';
import '../../domain/deal_model.dart';

/// Compact deal / negotiation card, in the Requirements card style.
class DealCard extends StatelessWidget {
  final DealItem deal;
  final VoidCallback onTap;

  const DealCard({
    super.key,
    required this.deal,
    required this.onTap,
  });

  static const Color _pending = Color(0xFFEA580C);

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

  /// No seller company linked yet (requirement negotiation before allocation).
  bool get _sellerUnallocated => deal.sellerCompanyId.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return DeskCardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: status · version · ref · chevron
          Row(
            children: [
              Flexible(flex: 3, child: DeskStatusBadge(label: deal.status.displayLabel, color: _getStatusColor(deal.status))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  'v${deal.latestVersionNumber}',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: Text(
                  deal.ref,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
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
                  deal.commodityName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
                ),
                if (deal.gradeName != null && deal.gradeName!.isNotEmpty)
                  Text(
                    'Grade: ${deal.gradeName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                const SizedBox(height: 8),

                // Buyer | Seller
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _party(LucideIcons.building2, 'Buyer', deal.buyerCompanyName, AppColors.textPrimaryLight),
                      ),
                      const VerticalDivider(width: 16, color: AppColors.borderLight),
                      Expanded(
                        child: _party(
                          LucideIcons.store,
                          'Seller',
                          deal.sellerCompanyName,
                          _sellerUnallocated ? _pending : AppColors.textPrimaryLight,
                          key: const Key('deal_card_seller'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Agreed volume · rate · total valuation
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DeskMetric(icon: LucideIcons.package, label: 'Agreed Volume', value: deal.formattedQuantity),
                    ),
                    Expanded(
                      child: DeskMetric(
                        icon: LucideIcons.coins,
                        label: 'Rate / Unit',
                        value: '${currencyFormat.format(deal.agreedPrice)} / ${deal.unitSymbol}',
                      ),
                    ),
                    Expanded(
                      child: DeskMetric(
                        icon: LucideIcons.calculator,
                        label: 'Total Valuation',
                        value: currencyFormat.format(deal.totalValuation),
                        valueColor: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Confirmations (once each) · details affordance
                Row(
                  children: [
                    Flexible(child: _confirmation('Buyer', deal.buyerConfirmed)),
                    const SizedBox(width: 6),
                    Flexible(child: _confirmation('Seller', deal.sellerConfirmed)),
                    const SizedBox(width: 6),
                    const Spacer(),
                    const Text(
                      'Tap to view details',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
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

  Widget _party(IconData icon, String role, String name, Color nameColor, {Key? key}) {
    return Row(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondaryLight),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight)),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: nameColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _confirmation(String party, bool confirmed) {
    return DeskStatusPill(
      icon: confirmed ? LucideIcons.checkCircle2 : LucideIcons.clock,
      label: '$party: ${confirmed ? "Confirmed" : "Pending"}',
      color: confirmed ? AppColors.success : AppColors.textSecondaryLight,
    );
  }
}
