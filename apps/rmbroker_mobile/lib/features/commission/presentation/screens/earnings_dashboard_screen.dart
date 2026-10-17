import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../domain/commission_model.dart';
import '../controllers/commission_controller.dart';
import '../widgets/commission_record_card.dart';
import '../widgets/commission_summary_header.dart';
import '../widgets/deal_commission_sheet.dart';
import '../widgets/log_commission_payment_dialog.dart';

/// Primary Brokerage Commission & Earnings Tracking Screen for RMBroker.
class EarningsDashboardScreen extends ConsumerStatefulWidget {
  const EarningsDashboardScreen({super.key});

  @override
  ConsumerState<EarningsDashboardScreen> createState() => _EarningsDashboardScreenState();
}

class _EarningsDashboardScreenState extends ConsumerState<EarningsDashboardScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFiduciaryInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.shieldCheck, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(child: Text('Fiduciary Boundary Rule')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'In commodity brokering, RMBroker operates as an authorized intermediary desk.\n\n'
            '• Brokerage commission is strictly calculated from the agreed fee per Metric Tonne (MT) on authoritative delivered quantities.\n\n'
            '• The gross transaction value of agricultural goods (e.g., ₹50 Lakhs for a wheat or mustard lot) is buyer-to-seller trade turnover and must NEVER be treated as brokerage earnings.\n\n'
            '• Disputed or rejected lots do not generate commission unless explicitly cleared by mutual arbitration.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commissionControllerProvider);
    final controller = ref.read(commissionControllerProvider.notifier);

    // Listen for payment success snackbar
    ref.listen<CommissionState>(commissionControllerProvider, (prev, next) {
      if (next.paymentSuccessMessage != null &&
          next.paymentSuccessMessage != prev?.paymentSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.paymentSuccessMessage!),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Brokerage & Earnings'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.info, size: 20),
            tooltip: 'Fiduciary Principles',
            onPressed: () => _showFiduciaryInfoDialog(context),
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            tooltip: 'Refresh Ledger',
            onPressed: () => controller.loadCommissionData(isRefresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.loadCommissionData(isRefresh: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Top Controls & Summary Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by deal, mandi, buyer, or seller...',
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(LucideIcons.x, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  controller.setSearchQuery('');
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) => controller.setSearchQuery(val),
                    ),
                    const SizedBox(height: 12),

                    // Period Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _PeriodChip(
                            label: 'All Time',
                            isSelected: state.selectedPeriod == 'All Time',
                            onTap: () => controller.setPeriodFilter('All Time'),
                          ),
                          const SizedBox(width: 6),
                          _PeriodChip(
                            label: 'This Month',
                            isSelected: state.selectedPeriod == 'This Month',
                            onTap: () => controller.setPeriodFilter('This Month'),
                          ),
                          const SizedBox(width: 6),
                          _PeriodChip(
                            label: 'Last Month',
                            isSelected: state.selectedPeriod == 'Last Month',
                            onTap: () => controller.setPeriodFilter('Last Month'),
                          ),
                          const SizedBox(width: 6),
                          _PeriodChip(
                            label: 'This Quarter',
                            isSelected: state.selectedPeriod == 'This Quarter',
                            onTap: () => controller.setPeriodFilter('This Quarter'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Summary Header
                    CommissionSummaryHeader(
                      summary: state.summary,
                      onFiduciaryTap: () => _showFiduciaryInfoDialog(context),
                    ),
                    const SizedBox(height: 16),

                    // Status Filter Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Deal Commission Records',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          '${state.filteredRecords.length} deals',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Status Filter Horizontal Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _StatusFilterChip(
                            label: 'All',
                            isSelected: state.selectedStatus == null,
                            onTap: () => controller.setStatusFilter(null),
                          ),
                          const SizedBox(width: 6),
                          _StatusFilterChip(
                            label: 'Eligible',
                            isSelected: state.selectedStatus == CommissionStatus.eligible,
                            onTap: () => controller.setStatusFilter(CommissionStatus.eligible),
                          ),
                          const SizedBox(width: 6),
                          _StatusFilterChip(
                            label: 'Invoiced',
                            isSelected: state.selectedStatus == CommissionStatus.invoiced,
                            onTap: () => controller.setStatusFilter(CommissionStatus.invoiced),
                          ),
                          const SizedBox(width: 6),
                          _StatusFilterChip(
                            label: 'Partially Paid',
                            isSelected: state.selectedStatus == CommissionStatus.partiallyPaid,
                            onTap: () => controller.setStatusFilter(CommissionStatus.partiallyPaid),
                          ),
                          const SizedBox(width: 6),
                          _StatusFilterChip(
                            label: 'Paid',
                            isSelected: state.selectedStatus == CommissionStatus.paid,
                            onTap: () => controller.setStatusFilter(CommissionStatus.paid),
                          ),
                          const SizedBox(width: 6),
                          _StatusFilterChip(
                            label: 'Disputed',
                            isSelected: state.selectedStatus == CommissionStatus.disputed,
                            onTap: () => controller.setStatusFilter(CommissionStatus.disputed),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Records List or Status State
            if (state.status == CommissionViewStatus.loading)
              const SliverFillRemaining(
                child: Center(
                  child: AppLoadingIndicator(message: 'Loading authoritative commission ledger...'),
                ),
              )
            else if (state.status == CommissionViewStatus.error)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.alertTriangle, size: 40, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          state.errorMessage ?? 'An error occurred loading commission data',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: AppColors.textPrimaryLight),
                        ),
                        const SizedBox(height: 16),
                        AppButton(
                          label: 'Retry',
                          onPressed: () => controller.loadCommissionData(),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (state.filteredRecords.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.receipt, size: 40, color: AppColors.textSecondaryLight),
                        const SizedBox(height: 12),
                        const Text(
                          'No commission records match your filter.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Try clearing search terms or status filters.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 16),
                        if (state.selectedStatus != null || state.searchQuery.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              controller.setSearchQuery('');
                              controller.setStatusFilter(null);
                            },
                            child: const Text('Reset All Filters'),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final record = state.filteredRecords[index];
                      return CommissionRecordCard(
                        record: record,
                        onTap: () => DealCommissionSheet.show(context, record: record),
                        onLogPayment: () => LogCommissionPaymentDialog.show(context, record: record),
                      );
                    },
                    childCount: state.filteredRecords.length,
                  ),
                ),
              ),

            // Bottom Spacing
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textPrimaryLight,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceLight,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.borderLight,
        ),
      ),
      onSelected: (_) => onTap(),
    );
  }
}
