import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import 'controllers/matches_controller.dart';
import 'controllers/offers_controller.dart';
import 'controllers/requirements_controller.dart';
import '../domain/match_model.dart';
import '../domain/offer_model.dart';
import '../domain/requirement_model.dart';
import 'widgets/create_offer_sheet.dart';
import 'widgets/create_requirement_sheet.dart';
import 'widgets/match_card.dart';
import 'widgets/offer_card.dart';
import 'widgets/offer_detail_sheet.dart';
import 'widgets/requirement_card.dart';
import 'widgets/requirement_detail_sheet.dart';
import '../../deals/presentation/widgets/create_allocation_sheet.dart';

/// Active Work Desk screen hosting Requirements, Seller Offers, and Match Center.
class WorkScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final String? initialRequirementId;

  const WorkScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialRequirementId,
  });

  @override
  ConsumerState<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends ConsumerState<WorkScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _reqSearchController = TextEditingController();
  final _offerSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reqSearchController.dispose();
    _offerSearchController.dispose();
    super.dispose();
  }

  void _onFindMatchesForRequirement(RequirementItem req) {
    final offers = ref.read(offersProvider).offers;
    ref.read(matchesProvider.notifier).selectRequirement(req, offers);
    _tabController.animateTo(2); // Switch to Match Center tab
  }

  // ============================================================================
  // TAB 1: BUYER REQUIREMENTS
  // ============================================================================
  Widget _buildRequirementsTab(RequirementsState state) {
    if (state.isLoading && state.requirements.isEmpty) {
      return const Center(
        child: AppLoadingIndicator(message: 'Loading Buyer Purchase Mandates...'),
      );
    }

    if (state.isContractPending) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            color: AppColors.surfaceLight,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.goldMuted.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.fileSearch, size: 28, color: AppColors.goldDark),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Requirements Contract Notice',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.contractNotice ??
                        'Authoritative endpoint /api/v1/broker/requirements is pending backend exposure. Direct Supabase desk sync was attempted but tables are restricted or offline.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: const Text('Retry Desk Sync'),
                    onPressed: () => ref.read(requirementsProvider.notifier).loadRequirements(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (state.errorMessage != null && state.requirements.isEmpty) {
      return AppErrorState(
        message: state.errorMessage!,
        onRetry: () => ref.read(requirementsProvider.notifier).loadRequirements(),
      );
    }

    final filtered = state.filteredRequirements;

    return Column(
      children: [
        // Search & Filter Header
        Container(
          color: AppColors.surfaceLight,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _reqSearchController,
                onChanged: (val) => ref.read(requirementsProvider.notifier).setSearchQuery(val),
                decoration: InputDecoration(
                  hintText: 'Search mandates, commodities, buyers...',
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  suffixIcon: _reqSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () {
                            _reqSearchController.clear();
                            ref.read(requirementsProvider.notifier).setSearchQuery('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Status Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatusChip<RequirementStatus?>(
                      label: 'All (${state.totalCount})',
                      isSelected: state.statusFilter == null,
                      onTap: () => ref.read(requirementsProvider.notifier).setStatusFilter(null),
                    ),
                    const SizedBox(width: 6),
                    _buildStatusChip<RequirementStatus?>(
                      label: 'Open (${state.openCount})',
                      isSelected: state.statusFilter == RequirementStatus.open,
                      onTap: () => ref
                          .read(requirementsProvider.notifier)
                          .setStatusFilter(RequirementStatus.open),
                    ),
                    const SizedBox(width: 6),
                    _buildStatusChip<RequirementStatus?>(
                      label: 'Partially Allocated (${state.partiallyAllocatedCount})',
                      isSelected: state.statusFilter == RequirementStatus.partiallyAllocated,
                      onTap: () => ref
                          .read(requirementsProvider.notifier)
                          .setStatusFilter(RequirementStatus.partiallyAllocated),
                    ),
                    const SizedBox(width: 6),
                    _buildStatusChip<RequirementStatus?>(
                      label: 'Expired (${state.expiredCount})',
                      isSelected: state.statusFilter == RequirementStatus.expired,
                      onTap: () => ref
                          .read(requirementsProvider.notifier)
                          .setStatusFilter(RequirementStatus.expired),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List View
        Expanded(
          child: filtered.isEmpty
              ? const AppEmptyState(
                  icon: LucideIcons.fileText,
                  title: 'No Matching Requirements',
                  description: 'No buyer requirements match your search filter.',
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(requirementsProvider.notifier).loadRequirements(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final req = filtered[index];
                      return RequirementCard(
                        requirement: req,
                        onTap: () => RequirementDetailSheet.show(
                          context: context,
                          requirement: req,
                          onFindMatches: () => _onFindMatchesForRequirement(req),
                        ),
                        onFindMatches: () => _onFindMatchesForRequirement(req),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ============================================================================
  // TAB 2: SELLER OFFERS
  // ============================================================================
  Widget _buildOffersTab(OffersState state) {
    if (state.isLoading && state.offers.isEmpty) {
      return const Center(
        child: AppLoadingIndicator(message: 'Loading Seller Supply Lots...'),
      );
    }

    if (state.isContractPending) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            color: AppColors.surfaceLight,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.goldMuted.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.package, size: 28, color: AppColors.goldDark),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Seller Offers Contract Notice',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.contractNotice ??
                        'Authoritative endpoint /api/v1/broker/offers is pending backend exposure. Direct Supabase desk sync was attempted but tables are restricted or offline.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: const Text('Retry Offers Sync'),
                    onPressed: () => ref.read(offersProvider.notifier).loadOffers(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (state.errorMessage != null && state.offers.isEmpty) {
      return AppErrorState(
        message: state.errorMessage!,
        onRetry: () => ref.read(offersProvider.notifier).loadOffers(),
      );
    }

    final filtered = state.filteredOffers;

    return Column(
      children: [
        // Search & Filter Header
        Container(
          color: AppColors.surfaceLight,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _offerSearchController,
                onChanged: (val) => ref.read(offersProvider.notifier).setSearchQuery(val),
                decoration: InputDecoration(
                  hintText: 'Search lots, commodities, sellers, mandis...',
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  suffixIcon: _offerSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () {
                            _offerSearchController.clear();
                            ref.read(offersProvider.notifier).setSearchQuery('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                    _buildStatusChip<OfferStatus?>(
                      label: 'All (${state.totalCount})',
                      isSelected: state.statusFilter == null,
                      onTap: () => ref.read(offersProvider.notifier).setStatusFilter(null),
                    ),
                    const SizedBox(width: 6),
                    _buildStatusChip<OfferStatus?>(
                      label: 'Active Supply (${state.activeCount})',
                      isSelected: state.statusFilter == OfferStatus.open,
                      onTap: () => ref.read(offersProvider.notifier).setStatusFilter(OfferStatus.open),
                    ),
                    const SizedBox(width: 6),
                    _buildStatusChip<OfferStatus?>(
                      label: 'Partially Available (${state.partiallyAvailableCount})',
                      isSelected: state.statusFilter == OfferStatus.partiallyAvailable,
                      onTap: () => ref
                          .read(offersProvider.notifier)
                          .setStatusFilter(OfferStatus.partiallyAvailable),
                    ),
                    const SizedBox(width: 6),
                    _buildStatusChip<OfferStatus?>(
                      label: 'Expired (${state.expiredCount})',
                      isSelected: state.statusFilter == OfferStatus.expired,
                      onTap: () => ref
                          .read(offersProvider.notifier)
                          .setStatusFilter(OfferStatus.expired),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List View
        Expanded(
          child: filtered.isEmpty
              ? const AppEmptyState(
                  icon: LucideIcons.package,
                  title: 'No Matching Offers',
                  description: 'No seller commodity supply lots match your criteria.',
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(offersProvider.notifier).loadOffers(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final offer = filtered[index];
                      return OfferCard(
                        offer: offer,
                        onTap: () => OfferDetailSheet.show(
                          context: context,
                          offer: offer,
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ============================================================================
  // TAB 3: MATCH CENTER (RECOMMENDATION-ONLY, ZERO SILENT ALLOCATION)
  // ============================================================================
  Widget _buildMatchCenterTab(MatchesState matchState, List<RequirementItem> requirements) {
    final selectedReq = matchState.selectedRequirement;
    final filteredMatches = matchState.filteredMatches;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Target Requirement Selector
          const Text(
            'Target Buyer Purchase Mandate',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<RequirementItem>(
                isExpanded: true,
                hint: const Text('Choose a buyer mandate to match...'),
                value: selectedReq != null && requirements.any((r) => r.id == selectedReq.id)
                    ? requirements.firstWhere((r) => r.id == selectedReq.id)
                    : null,
                items: requirements.map((req) {
                  return DropdownMenuItem<RequirementItem>(
                    value: req,
                    child: Text(
                      '${req.ref}: ${req.commodityName} (${req.formattedRemainingQuantity} rem)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (req) {
                  if (req != null) {
                    final offers = ref.read(offersProvider).offers;
                    ref.read(matchesProvider.notifier).selectRequirement(req, offers);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Mandatory Broker Fiduciary Disclaimer Banner (Section 2 & 5)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.shieldAlert, size: 18, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Broker Platform Fiduciary Policy',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'RMBroker is a broker platform. A match is recommendation-only and does NOT allocate quantity, reserve physical stock, or complete a trade deal.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textPrimaryLight,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (selectedReq == null) ...[
            const SizedBox(height: 30),
            const AppEmptyState(
              icon: LucideIcons.sparkles,
              title: 'Select a Requirement to Match',
              description:
                  'Choose an active mandate above to run the deterministic compatibility scoring engine.',
            ),
          ] else ...[
            // Score Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusChip<MatchClassification?>(
                    label: 'All Matches (${matchState.allMatches.length})',
                    isSelected: matchState.scoreFilter == null,
                    onTap: () => ref.read(matchesProvider.notifier).setScoreFilter(null),
                  ),
                  const SizedBox(width: 6),
                  _buildStatusChip<MatchClassification?>(
                    label: 'Strong (${matchState.strongMatchCount})',
                    isSelected: matchState.scoreFilter == MatchClassification.strongMatch,
                    onTap: () => ref
                        .read(matchesProvider.notifier)
                        .setScoreFilter(MatchClassification.strongMatch),
                  ),
                  const SizedBox(width: 6),
                  _buildStatusChip<MatchClassification?>(
                    label: 'Good (${matchState.goodMatchCount})',
                    isSelected: matchState.scoreFilter == MatchClassification.goodMatch,
                    onTap: () => ref
                        .read(matchesProvider.notifier)
                        .setScoreFilter(MatchClassification.goodMatch),
                  ),
                  const SizedBox(width: 6),
                  _buildStatusChip<MatchClassification?>(
                    label: 'Partial (${matchState.partialMatchCount})',
                    isSelected: matchState.scoreFilter == MatchClassification.partialMatch,
                    onTap: () => ref
                        .read(matchesProvider.notifier)
                        .setScoreFilter(MatchClassification.partialMatch),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (matchState.notice != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  matchState.notice!,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
              ),
            ],

            if (filteredMatches.isEmpty) ...[
              const SizedBox(height: 20),
              AppEmptyState(
                icon: LucideIcons.fileX,
                title: 'No Compatible Matches Found',
                description:
                    'No available seller lots match the commodity (${selectedReq.commodityName}) specifications.',
              ),
            ] else ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredMatches.length,
                itemBuilder: (context, index) {
                  final match = filteredMatches[index];
                  return MatchCard(
                    match: match,
                    onTap: () => OfferDetailSheet.show(
                      context: context,
                      offer: match.offer,
                    ),
                    onAllocate: () => CreateAllocationSheet.show(
                      context: context,
                      requirement: selectedReq,
                      offer: match.offer,
                    ),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip<T>({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reqState = ref.watch(requirementsProvider);
    final offerState = ref.watch(offersProvider);
    final matchState = ref.watch(matchesProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Active Work Desk'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryLight,
          tabs: [
            Tab(text: 'Requirements (${reqState.totalCount})'),
            Tab(text: 'Offers (${offerState.totalCount})'),
            const Tab(text: 'Match Center'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequirementsTab(reqState),
          _buildOffersTab(offerState),
          _buildMatchCenterTab(matchState, reqState.requirements),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final tab = _tabController.index;
          if (tab == 0) {
            return FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('New Mandate', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => CreateRequirementSheet.show(context),
            );
          } else if (tab == 1) {
            return FloatingActionButton.extended(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Post Offer', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => CreateOfferSheet.show(context),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
