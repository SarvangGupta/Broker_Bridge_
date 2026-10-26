import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/seller_deal_model.dart';

/// Full broker commission breakdown for one deal, opened from Deal Details.
/// Displays the values already on [SellerDealModel]; nothing is recalculated.
class DealCommissionDetailsScreen extends StatelessWidget {
  final SellerDealModel deal;

  const DealCommissionDetailsScreen({super.key, required this.deal});

  @override
  Widget build(BuildContext context) {
    final hasTerms = deal.commissionRate != null && deal.commissionRate! > 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Broker Commission')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Commission Breakdown',
                        style: AppTypography.titleSmall,
                      ),
                    ),
                    StatusBadge(status: deal.commissionStatus),
                  ],
                ),
                const Divider(height: 20),
                if (hasTerms) ...[
                  _detailRow(
                    'Agreed Commission Rate',
                    '₹${deal.commissionRate!.toStringAsFixed(0)} (${deal.commissionBasis})',
                  ),
                  _detailRow(
                    'Total Commission Payable',
                    '₹${(deal.commissionAmount ?? 0).toStringAsFixed(0)}',
                  ),
                  _detailRow(
                    'Commission Paid',
                    '₹${deal.commissionPaid.toStringAsFixed(0)}',
                    color: AppColors.success,
                  ),
                  const Divider(height: 16),
                  _detailRow(
                    'Outstanding Commission',
                    '₹${deal.commissionOutstanding.toStringAsFixed(0)}',
                    color: deal.commissionOutstanding > 0
                        ? AppColors.error
                        : AppColors.textPrimaryLight,
                  ),
                ] else
                  const Text(
                    'No commission terms recorded for this contract.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deal Reference', style: AppTypography.titleSmall),
                const Divider(height: 20),
                _detailRow('Booking ID', deal.bookingReference ?? deal.id),
                _detailRow(
                  'Commodity',
                  '${deal.commodityName} • ${deal.gradeName}',
                ),
                _detailRow(
                  'Agreed Quantity',
                  '${deal.agreedQuantity} ${deal.unit}',
                ),
                _detailRow(
                  'Total Gross Value',
                  '₹${deal.totalDealValue.toStringAsFixed(0)}',
                ),
                _detailRow('Broker Desk', deal.brokerDeskName),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Logistics and vehicle entry for one deal, opened from Deal Details.
class DealLogisticsDetailsScreen extends StatelessWidget {
  final SellerDealModel deal;

  const DealLogisticsDetailsScreen({super.key, required this.deal});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Logistics & Vehicle Entry')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.truck,
                      size: 18,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dispatch Record',
                        style: AppTypography.titleSmall,
                      ),
                    ),
                    StatusBadge(status: deal.status),
                  ],
                ),
                const Divider(height: 20),
                _detailRow(
                  'Vehicle Registration',
                  deal.vehicleNumber ?? 'Not recorded',
                ),
                _detailRow(
                  'Dispatch Timestamp',
                  deal.dispatchDate != null
                      ? dateFormat.format(deal.dispatchDate!)
                      : 'Not recorded',
                ),
                _detailRow('Booking ID', deal.bookingReference ?? deal.id),
                _detailRow(
                  'Dispatched Quantity',
                  '${deal.agreedQuantity} ${deal.unit}',
                ),
                _detailRow('Broker Desk', deal.brokerDeskName),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _detailRow(String label, String value, {Color? color}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    ),
  );
}
