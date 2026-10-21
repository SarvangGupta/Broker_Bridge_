import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/services/contact_launcher_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/seller_deals_repository.dart';
import '../domain/seller_deal_model.dart';

class DealDetailsScreen extends StatefulWidget {
  final String dealId;
  final SellerDealModel? initialDeal;

  const DealDetailsScreen({
    super.key,
    required this.dealId,
    this.initialDeal,
  });

  @override
  State<DealDetailsScreen> createState() => _DealDetailsScreenState();
}

class _DealDetailsScreenState extends State<DealDetailsScreen> {
  final SellerDealsRepository _repository = SellerDealsRepository();
  final ContactLauncherService _contactLauncher = const ContactLauncherService();

  SellerDealModel? _deal;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialDeal != null) {
      _deal = widget.initialDeal;
      _isLoading = false;
    } else {
      _loadDeal();
    }
  }

  Future<void> _loadDeal() async {
    setState(() => _isLoading = true);
    final item = await _repository.getDealById(widget.dealId);
    if (!mounted) return;
    setState(() {
      _deal = item;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppLoadingIndicator(message: 'Loading deal contract & invoices...'),
      );
    }

    if (_deal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Deal Details')),
        body: const Center(child: Text('Deal not found or inaccessible.')),
      );
    }

    final deal = _deal!;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(deal.bookingReference ?? deal.id),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Commercial Summary Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(deal.commodityName, style: AppTypography.titleLarge),
                    ),
                    StatusBadge(status: deal.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(deal.gradeName, style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
                const Divider(height: 24),

                _buildInfoRow('Agreed Quantity:', '${deal.agreedQuantity} ${deal.unit}'),
                const SizedBox(height: 8),
                _buildInfoRow('Agreed Rate:', '₹${deal.agreedPrice.toStringAsFixed(0)} / ${deal.unit}'),
                const SizedBox(height: 8),
                _buildInfoRow('Total Gross Value:', '₹${deal.totalDealValue.toStringAsFixed(0)}'),
                if (deal.bookingReference != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow('System Booking ID:', deal.bookingReference!),
                ],
                const SizedBox(height: 8),
                _buildInfoRow('Contract Date:', dateFormat.format(deal.createdAt)),
                if (deal.closedAt != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow('Settled Date:', dateFormat.format(deal.closedAt!)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Invoices & Financial Documents Section
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Invoices & Tax Statements', style: AppTypography.titleMedium),
                    if (deal.invoiceStatus != null)
                      StatusBadge(status: deal.invoiceStatus!),
                  ],
                ),
                const SizedBox(height: 12),
                if (deal.invoiceNo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.receipt, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  deal.invoiceNo!,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ],
                            ),
                            Text(
                              '₹${(deal.invoiceAmount ?? deal.totalDealValue).toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  context.push('/invoices/${deal.invoiceId ?? deal.invoiceNo!}');
                                },
                                icon: const Icon(LucideIcons.fileText, size: 14),
                                label: const Text('View Full Tax Invoice', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'No invoice generated yet for this deal. Invoices are issued by the mediating broker upon vehicle dispatch.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Commodity Commission Terms & Settlement Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Broker Commission Breakdown', style: AppTypography.titleMedium),
                    StatusBadge(status: deal.commissionStatus),
                  ],
                ),
                const SizedBox(height: 12),
                if (deal.commissionRate != null && deal.commissionRate! > 0) ...[
                  _buildInfoRow(
                    'Agreed Commission Rate:',
                    '₹${deal.commissionRate!.toStringAsFixed(0)} (${deal.commissionBasis})',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Total Commission Payable:',
                    '₹${(deal.commissionAmount ?? 0).toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Commission Paid:',
                    '₹${deal.commissionPaid.toStringAsFixed(0)}',
                  ),
                  const Divider(height: 18),
                  _buildInfoRow(
                    'Outstanding Commission:',
                    '₹${deal.commissionOutstanding.toStringAsFixed(0)}',
                  ),
                ] else ...[
                  const Text(
                    'No commission terms recorded for this contract.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                ],
                const SizedBox(height: 12),
                AppButton(
                  label: 'Broker Chat & Commission Desk',
                  icon: LucideIcons.messageSquare,
                  variant: ButtonVariant.outline,
                  onPressed: () {
                    final brokerId = deal.brokerId ?? 'BRK-DEFAULT';
                    context.push('/communication/broker/$brokerId');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Mediating Mandi Broker Card & Counterparty Shield
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mediating Broker Desk', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                Text(deal.brokerDeskName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.shieldCheck, size: 16, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Counterparty Shield: Direct buyer contact and identification are shielded. All trade actions are broker-mediated.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _contactLauncher.launchPhone('+919829012345'),
                        icon: const Icon(LucideIcons.phone, size: 16),
                        label: const Text('Call Broker'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _contactLauncher.launchWhatsApp('+919829012345'),
                        icon: const Icon(LucideIcons.messageCircle, size: 16),
                        label: const Text('WhatsApp'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final brokerId = deal.brokerId ?? 'b354958e-779a-41f2-b7a3-5899eca32e32';
                      context.push(
                        '/brokers/$brokerId/rate',
                        extra: {
                          'brokerName': deal.brokerDeskName,
                          'dealId': deal.id,
                          'dealReference': deal.bookingReference,
                        },
                      );
                    },
                    icon: const Icon(LucideIcons.star, size: 15, color: AppColors.secondaryDark),
                    label: const Text(
                      'Rate Mandi Broker Desk',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondaryDark),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.amber.shade50,
                      side: BorderSide(color: Colors.amber.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Logistics & Dispatch Information (if available)
          if (deal.vehicleNumber != null) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Logistics & Vehicle Entry', style: AppTypography.titleMedium),
                  const SizedBox(height: 12),
                  _buildInfoRow('Vehicle Registration:', deal.vehicleNumber!),
                  if (deal.dispatchDate != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow('Dispatch Timestamp:', dateFormat.format(deal.dispatchDate!)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }
}
