import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/seller_deals_repository.dart';
import '../domain/seller_deal_model.dart';

class SellerDealsScreen extends StatefulWidget {
  const SellerDealsScreen({super.key});

  @override
  State<SellerDealsScreen> createState() => _SellerDealsScreenState();
}

class _SellerDealsScreenState extends State<SellerDealsScreen> {
  final SellerDealsRepository _repository = SellerDealsRepository();
  String _selectedFilter = 'ALL';
  bool _isLoading = true;
  String? _errorMessage;
  List<SellerDealModel> _deals = [];

  final List<String> _filters = [
    'ALL',
    'Dispatch Pending',
    'Ready to Finalize',
    'Dispatched',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDeals();
  }

  Future<void> _fetchDeals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.getDeals(
        statusFilter: _selectedFilter == 'ALL' ? null : _selectedFilter,
      );
      if (!mounted) return;
      setState(() {
        _deals = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load deal contracts: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Deals & Contracts'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: 'Refresh Deals',
            onPressed: _fetchDeals,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter == 'ALL' ? 'All Contracts' : filter),
                      selected: isSelected,
                      selectedColor: AppColors.primaryContainer,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimaryLight,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedFilter = filter);
                          _fetchDeals();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const AppLoadingIndicator(
                    message: 'Loading verified deal contracts...',
                  )
                : _errorMessage != null
                ? AppErrorState(message: _errorMessage!, onRetry: _fetchDeals)
                : _deals.isEmpty
                ? AppEmptyState(
                    title: 'No Contracts Found',
                    message:
                        'No commercial deals matching "$_selectedFilter" under your seller enterprise.',
                  )
                : RefreshIndicator(
                    onRefresh: _fetchDeals,
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _deals.length,
                      itemBuilder: (context, index) {
                        final deal = _deals[index];
                        return _buildDealCard(context, deal);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDealCard(BuildContext context, SellerDealModel deal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => context.push('/deals/${deal.id}', extra: deal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (deal.bookingReference != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                deal.bookingReference!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.secondaryDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              deal.commodityName,
                              style: AppTypography.titleSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        deal.gradeName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: deal.status),
              ],
            ),
            const Divider(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Agreed Volume',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMutedLight,
                      ),
                    ),
                    Text(
                      '${deal.agreedQuantity} ${deal.unit}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Agreed Rate',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMutedLight,
                      ),
                    ),
                    Text(
                      '₹${deal.agreedPrice.toStringAsFixed(0)} / ${deal.unit}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Total Value',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMutedLight,
                      ),
                    ),
                    Text(
                      '₹${deal.totalDealValue.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Invoices & Commission indicators
            Row(
              children: [
                if (deal.invoiceNo != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.receipt,
                          size: 10,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          deal.invoiceNo!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (deal.commissionAmount != null &&
                    deal.commissionAmount! > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Text(
                      'Comm: ₹${deal.commissionAmount!.toStringAsFixed(0)} (${deal.commissionPaid >= deal.commissionAmount! ? "Paid" : "Pending"})',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(
                  LucideIcons.briefcase,
                  size: 14,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    deal.brokerDeskName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: AppColors.textMutedLight,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
