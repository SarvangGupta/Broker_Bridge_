import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/commodities_repository.dart';
import '../domain/commodity_model.dart';

class MyCommoditiesScreen extends StatefulWidget {
  const MyCommoditiesScreen({super.key});

  @override
  State<MyCommoditiesScreen> createState() => _MyCommoditiesScreenState();
}

class _MyCommoditiesScreenState extends State<MyCommoditiesScreen> {
  final CommoditiesRepository _repository = CommoditiesRepository();
  String _selectedFilter = 'ALL';
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;
  List<SellerCommodity> _commodities = [];

  final List<String> _filters = [
    'ALL',
    'Open',
    'Active',
    'Reserved',
    'Fulfilled',
    'Cancelled',
    'Expired',
  ];

  @override
  void initState() {
    super.initState();
    _fetchCommodities();
    CommoditiesRepository.commoditiesUpdatedNotifier.addListener(
      _onListUpdated,
    );
  }

  @override
  void dispose() {
    CommoditiesRepository.commoditiesUpdatedNotifier.removeListener(
      _onListUpdated,
    );
    super.dispose();
  }

  void _onListUpdated() {
    if (mounted) _fetchCommodities();
  }

  Future<void> _fetchCommodities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.getCommodities(
        statusFilter: _selectedFilter == 'ALL' ? null : _selectedFilter,
      );

      if (!mounted) return;

      setState(() {
        _commodities = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load commodity inventory. $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var filtered = _commodities;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filtered = filtered
          .where(
            (c) =>
                c.commodityName.toLowerCase().contains(q) ||
                c.lotNumber.toLowerCase().contains(q) ||
                c.gradeName.toLowerCase().contains(q) ||
                c.districtName.toLowerCase().contains(q),
          )
          .toList();
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('My Commodities'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'Post Commodity',
            onPressed: () => context.push('/commodities/new'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/commodities/new'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Post Commodity'),
      ),
      body: Column(
        children: [
          // Filter Chips Row
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
                    child: ChoiceChip(
                      label: Text(filter == 'ALL' ? 'All Supply' : filter),
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
                          setState(() {
                            _selectedFilter = filter;
                          });
                          _fetchCommodities();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // Main Listing Content
          Expanded(
            child: _isLoading
                ? const AppLoadingIndicator(
                    message: 'Loading commodity listings...',
                  )
                : _errorMessage != null
                ? AppErrorState(
                    title: _errorMessage!.contains('session has expired')
                        ? 'Session Expired'
                        : 'Something went wrong',
                    message: _errorMessage!,
                    retryLabel: _errorMessage!.contains('session has expired')
                        ? 'Sign In'
                        : 'Try Again',
                    onRetry: _errorMessage!.contains('session has expired')
                        ? () => AppRouter.authNotifier.setUnauthenticated()
                        : _fetchCommodities,
                  )
                : filtered.isEmpty
                ? AppEmptyState(
                    title: 'No Commodities Listed',
                    message:
                        'You have not listed any lots under "$_selectedFilter". Post a new commodity lot to make it discoverable by licensed brokers.',
                    actionLabel: '+ Post Commodity',
                    onAction: () => context.push('/commodities/new'),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchCommodities,
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final lot = filtered[index];
                        return _buildLotCard(context, lot);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLotCard(BuildContext context, SellerCommodity lot) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => context.push('/commodities/${lot.id}', extra: lot),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              lot.lotNumber,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            lot.commodityName,
                            style: AppTypography.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lot.gradeName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: lot.status),
              ],
            ),
            const Divider(height: 20),

            // Quantities Breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available / Total',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMutedLight,
                      ),
                    ),
                    Text(
                      '${lot.availableQuantity} / ${lot.totalQuantity} ${lot.unit}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (lot.reservedQuantity > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Reserved',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedLight,
                        ),
                      ),
                      Text(
                        '${lot.reservedQuantity} ${lot.unit}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Asking Price',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMutedLight,
                      ),
                    ),
                    Text(
                      '₹${lot.askingPrice.toStringAsFixed(0)} / ${lot.unit}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location, Loading & Broker Footer
            Row(
              children: [
                const Icon(
                  LucideIcons.mapPin,
                  size: 14,
                  color: AppColors.textMutedLight,
                ),
                const SizedBox(width: 4),
                Text(
                  '${lot.districtName}, ${lot.stateName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: lot.loadingStatus == 'Ready to Load'
                        ? AppColors.successBackground
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    lot.loadingStatus,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: lot.loadingStatus == 'Ready to Load'
                          ? AppColors.success
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
            if (lot.brokerName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    LucideIcons.briefcase,
                    size: 13,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Assigned: ${lot.brokerName}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryDark,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
