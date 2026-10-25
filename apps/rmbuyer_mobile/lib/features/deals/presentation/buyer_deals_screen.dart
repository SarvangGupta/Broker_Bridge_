import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/buyer_deals_repository.dart';
import '../domain/buyer_deal_model.dart';
import 'package:go_router/go_router.dart';
import 'final_deal_review_screen.dart';
import '../../../l10n/app_localizations.dart';

/// Screen displaying buyer's executed deals and shipment tracking status.
class BuyerDealsScreen extends StatefulWidget {
  final BuyerDealsRepository? repository;

  const BuyerDealsScreen({super.key, this.repository});

  @override
  State<BuyerDealsScreen> createState() => _BuyerDealsScreenState();
}

class _BuyerDealsScreenState extends State<BuyerDealsScreen> {
  late final BuyerDealsRepository _repo;
  String _selectedStatus = 'ALL';
  bool _isLoading = true;
  String? _errorMessage;
  List<BuyerDeal> _deals = [];

  final List<String> _statusFilters = [
    'ALL',
    'In Transit',
    'Delivered',
    'Closed',
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? BuyerDealsRepository();
    _loadDeals();
  }

  Future<void> _loadDeals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repo.getDeals(statusFilter: _selectedStatus);
      if (!mounted) return;
      setState(() {
        _deals = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load deals. Please verify your connection.';
        _isLoading = false;
      });
    }
  }

  void _openDealDetails(BuildContext context, String dealId) {
    try {
      context.push('/deals/$dealId');
    } catch (_) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FinalDealReviewScreen(
            dealId: dealId,
            repository: _repo,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(Tr.titleDeals)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCw),
            tooltip: 'Refresh',
            onPressed: _loadDeals,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Counterparty mediation banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.primaryContainer.withValues(alpha: 0.6),
              child: const Row(
                children: [
                  Icon(LucideIcons.shieldCheck, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Counterparty Shield: All trade agreements are finalized through your licensed broker desk.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Status Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceLight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _statusFilters.map((s) {
                    final isSelected = _selectedStatus == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s == 'ALL' ? 'All Deals' : s),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedStatus = s;
                            });
                            _loadDeals();
                          }
                        },
                        selectedColor: AppColors.primaryContainer,
                        backgroundColor: AppColors.surfaceLight,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.borderLight,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(),

            // Deals List View
            Expanded(
              child: _buildDealsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealsList() {
    if (_isLoading) {
      return const AppLoadingIndicator(
        message: 'Loading your procurement deals and shipment statuses...',
      );
    }

    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage!,
        onRetry: _loadDeals,
      );
    }

    if (_deals.isEmpty) {
      return AppEmptyState(
        title: 'No Deals Found',
        description: _selectedStatus == 'ALL'
            ? 'You do not have any active or historical deals recorded under your buyer account.'
            : 'No deals currently matching "$_selectedStatus" status.',
        icon: LucideIcons.handshake,
      );
    }

    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _deals.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final deal = _deals[index];
        final totalValue = deal.agreedPrice * deal.agreedQuantity;

        return InkWell(
          onTap: () => _openDealDetails(context, deal.id),
          borderRadius: BorderRadius.circular(12),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deal.commodityName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
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
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetric('Agreed Qty', '${deal.agreedQuantity} ${deal.unit}'),
                    _buildMetric(
                      'Rate',
                      '${currencyFormat.format(deal.agreedPrice)}/${deal.unit}',
                    ),
                    _buildMetric(
                      'Total Contract Value',
                      currencyFormat.format(totalValue),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.briefcase,
                        size: 13,
                        color: AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Broker Desk: ${deal.brokerDeskName}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy').format(deal.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMutedLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }
}
