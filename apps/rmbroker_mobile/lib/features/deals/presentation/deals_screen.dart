import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../domain/deal_model.dart';
import 'controllers/deals_controller.dart';
import 'widgets/deal_card.dart';

/// Deals & Contract Negotiations Desk.
class DealsScreen extends ConsumerStatefulWidget {
  final String? initialFilter;

  const DealsScreen({super.key, this.initialFilter});

  @override
  ConsumerState<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends ConsumerState<DealsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _applyInitialFilter(widget.initialFilter);
  }

  @override
  void didUpdateWidget(covariant DealsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != oldWidget.initialFilter && widget.initialFilter != null) {
      _applyInitialFilter(widget.initialFilter);
    }
  }

  void _applyInitialFilter(String? filter) {
    if (filter != null && filter.isNotEmpty) {
      Future.microtask(() {
        final f = filter.toLowerCase().trim();
        if (f == 'active' || f == 'signoff' || f == 'dispatch_due' || f == 'disputed') {
          ref.read(dealsProvider.notifier).setPresetFilter(f);
        } else {
          final status = DealStatus.fromString(f);
          ref.read(dealsProvider.notifier).setStatusFilter(status);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildFilterChip<T>({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textPrimaryLight,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: AppColors.surfaceLight,
        selectedColor: AppColors.primaryContainer.withValues(alpha: 0.35),
        checkmarkColor: AppColors.primary,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.borderLight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dealsProvider);
    final currencyFormat = NumberFormat.compactCurrency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 1,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Deals & Negotiations'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            onPressed: () => ref.read(dealsProvider.notifier).loadDeals(),
          ),
        ],
      ),
      body: Column(
        children: [
          // KPI Metric Banner
          Container(
            color: AppColors.surfaceLight,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildKpiTile(
                    'Total Deals',
                    state.totalCount.toString(),
                    LucideIcons.handshake,
                    AppColors.primary,
                  ),
                ),
                Container(height: 36, width: 1, color: AppColors.borderLight),
                Expanded(
                  child: _buildKpiTile(
                    'Agreed Volume',
                    '${state.totalVolumeMT.toStringAsFixed(0)} MT',
                    LucideIcons.package,
                    AppColors.success,
                  ),
                ),
                Container(height: 36, width: 1, color: AppColors.borderLight),
                Expanded(
                  child: _buildKpiTile(
                    'Contract Value',
                    currencyFormat.format(state.totalValuation),
                    LucideIcons.indianRupee,
                    AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          // Search & Filter Bar
          Container(
            color: AppColors.surfaceLight,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => ref.read(dealsProvider.notifier).setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Search deals, commodities, counterparties...',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(dealsProvider.notifier).setSearchQuery('');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'All (${state.totalCount})',
                        isSelected: state.presetFilter == null && state.statusFilter == null,
                        onTap: () => ref.read(dealsProvider.notifier).setStatusFilter(null),
                      ),
                      _buildFilterChip(
                        label: 'Active (${state.activeCount})',
                        isSelected: state.presetFilter == 'active',
                        onTap: () => ref.read(dealsProvider.notifier).setPresetFilter('active'),
                      ),
                      _buildFilterChip(
                        label: 'Awaiting Sign-off (${state.signoffCount})',
                        isSelected: state.presetFilter == 'signoff',
                        onTap: () => ref.read(dealsProvider.notifier).setPresetFilter('signoff'),
                      ),
                      _buildFilterChip(
                        label: 'Dispatch Due (${state.dispatchDueCount})',
                        isSelected: state.presetFilter == 'dispatch_due',
                        onTap: () => ref.read(dealsProvider.notifier).setPresetFilter('dispatch_due'),
                      ),
                      _buildFilterChip(
                        label: 'Disputed (${state.disputedCount})',
                        isSelected: state.presetFilter == 'disputed',
                        onTap: () => ref.read(dealsProvider.notifier).setPresetFilter('disputed'),
                      ),
                      _buildFilterChip(
                        label: 'Draft (${state.deals.where((d) => d.status == DealStatus.draft).length})',
                        isSelected: state.statusFilter == DealStatus.draft,
                        onTap: () => ref.read(dealsProvider.notifier).setStatusFilter(DealStatus.draft),
                      ),
                      _buildFilterChip(
                        label: 'Negotiating (${state.deals.where((d) => d.status == DealStatus.negotiation).length})',
                        isSelected: state.statusFilter == DealStatus.negotiation,
                        onTap: () => ref.read(dealsProvider.notifier).setStatusFilter(DealStatus.negotiation),
                      ),
                      _buildFilterChip(
                        label: 'Finalized (${state.finalizedCount})',
                        isSelected: state.statusFilter == DealStatus.finalized,
                        onTap: () => ref.read(dealsProvider.notifier).setStatusFilter(DealStatus.finalized),
                      ),
                      _buildFilterChip(
                        label: 'Cancelled (${state.cancelledCount})',
                        isSelected: state.statusFilter == DealStatus.cancelled,
                        onTap: () => ref.read(dealsProvider.notifier).setStatusFilter(DealStatus.cancelled),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          // Pending Notice or Error Banner
          if (state.contractNotice != null && state.deals.isEmpty) ...[
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.goldMuted.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.goldDark.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.info, size: 16, color: AppColors.goldDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.contractNotice!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.goldDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (state.errorMessage != null && state.deals.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppEmptyState(
                icon: LucideIcons.alertTriangle,
                title: 'Unable to Load Deals',
                description: state.errorMessage!,
              ),
            ),
          ],

          // Deals List
          Expanded(
            child: state.isLoading && state.deals.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.filteredDeals.isEmpty
                    ? const AppEmptyState(
                        icon: LucideIcons.handshake,
                        title: 'No Deals Found',
                        description:
                            'No broker deals match the current status filter or query. Select a compatible offer from the Work Desk to create an allocation and deal.',
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.read(dealsProvider.notifier).loadDeals(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: state.filteredDeals.length,
                          itemBuilder: (context, index) {
                            final deal = state.filteredDeals[index];
                            return DealCard(
                              deal: deal,
                              onTap: () => context.push(deal.isRequirementNegotiation
                                  ? '/requirements/${deal.requirementId}'
                                  : '/deals/${deal.id}'),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTile(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}
