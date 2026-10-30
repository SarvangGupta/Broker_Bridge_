import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../work/data/work_repository.dart';
import '../../../work/domain/offer_model.dart';
import '../../../work/domain/requirement_model.dart';
import '../../../work/presentation/controllers/offers_controller.dart';
import '../../../work/presentation/controllers/requirements_controller.dart';
import '../../domain/market_filter_criteria.dart';
import '../controllers/home_market_filter_controller.dart';
import 'market_filter_sheet.dart';

/// Home: Buyer Requirements / Seller Offers switch with compact rows and
/// tab-independent filter & sort capabilities.
class HomeMarketSection extends ConsumerStatefulWidget {
  /// Rows shown before "View all in Work Desk".
  static const int maxRows = 10;

  const HomeMarketSection({super.key});

  @override
  ConsumerState<HomeMarketSection> createState() => _HomeMarketSectionState();
}

class _HomeMarketSectionState extends ConsumerState<HomeMarketSection> {
  bool _showOffers = false; // Requirements by default

  static String _age(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return DateFormat('dd MMM').format(at);
  }

  /// "FOR Mill Delivery, Kota Mandi" -> "Kota Mandi".
  static String _place(String terms) {
    final t = terms.trim();
    final comma = t.lastIndexOf(',');
    return comma > 0 && comma < t.length - 1 ? t.substring(comma + 1).trim() : t;
  }

  static final _money = NumberFormat.decimalPattern('en_IN');

  /// Model fallbacks used when the party company is not readable; never shown
  /// as if they were a real company name.
  static const _placeholderNames = {
    WorkRepository.restrictedBuyerLabel,
    'Verified Buyer',
    'Verified Seller',
  };

  static String? _party(String name) {
    final n = name.trim();
    return n.isEmpty || _placeholderNames.contains(n) ? null : n;
  }

  void _openFilterSheet(MarketFilterCriteria current) {
    MarketFilterSheet.show(
      context,
      initialCriteria: current,
      isOffersTab: _showOffers,
      onApply: (newCriteria) {
        final notifier = ref.read(homeMarketFilterProvider.notifier);
        if (_showOffers) {
          notifier.setOffersFilter(newCriteria);
        } else {
          notifier.setRequirementsFilter(newCriteria);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final reqState = ref.watch(requirementsProvider);
    final offerState = ref.watch(offersProvider);
    final filterState = ref.watch(homeMarketFilterProvider);
    final filterNotifier = ref.read(homeMarketFilterProvider.notifier);

    // Apply independent tab filters & sorting
    final filteredReqs = filterState.requirementsFilter.applyToRequirements(reqState.requirements);
    final filteredOffers = filterState.offersFilter.applyToOffers(offerState.offers);

    final currentFilter = _showOffers ? filterState.offersFilter : filterState.requirementsFilter;
    final currentActiveCount = currentFilter.activeFilterCount;
    final hasActiveFilters = currentFilter.hasActiveFilters;

    final reqDisplayCount = filterState.requirementsFilter.hasActiveFilters
        ? filteredReqs.length
        : reqState.totalCount;
    final offerDisplayCount = filterState.offersFilter.hasActiveFilters
        ? filteredOffers.length
        : offerState.totalCount;

    final Widget body;
    if (!_showOffers) {
      body = _list(
        loading: reqState.isLoading && reqState.requirements.isEmpty,
        error: reqState.errorMessage ?? reqState.contractNotice,
        emptyText: 'No buyer requirements assigned to you yet.',
        hasFilters: hasActiveFilters,
        onClearFilters: () => filterNotifier.resetRequirementsFilter(),
        rows: [
          for (final r in filteredReqs.take(HomeMarketSection.maxRows)) _requirementRow(r),
        ],
        total: filteredReqs.length,
        viewAllRoute: '/work?tab=0',
      );
    } else {
      body = _list(
        loading: offerState.isLoading && offerState.offers.isEmpty,
        error: offerState.errorMessage ?? offerState.contractNotice,
        emptyText: 'No seller offers available to you yet.',
        hasFilters: hasActiveFilters,
        onClearFilters: () => filterNotifier.resetOffersFilter(),
        rows: [
          for (final o in filteredOffers.take(HomeMarketSection.maxRows)) _offerRow(o),
        ],
        total: filteredOffers.length,
        viewAllRoute: '/work?tab=1',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tabs + Filter Button Header
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _segment(
                        key: 'home_tab_requirements',
                        icon: LucideIcons.fileText,
                        label: 'Buyer Requirements',
                        count: reqDisplayCount,
                        selected: !_showOffers,
                        onTap: () {
                          setState(() => _showOffers = false);
                          filterNotifier.setTab(false);
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _segment(
                        key: 'home_tab_offers',
                        icon: LucideIcons.tag,
                        label: 'Seller Offers',
                        count: offerDisplayCount,
                        selected: _showOffers,
                        onTap: () {
                          setState(() => _showOffers = true);
                          filterNotifier.setTab(true);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _filterButton(
              activeCount: currentActiveCount,
              onTap: () => _openFilterSheet(currentFilter),
            ),
          ],
        ),

        // Active Filter Chips Bar (visible when filters are applied)
        if (hasActiveFilters) ...[
          const SizedBox(height: 8),
          _activeFilterChips(
            criteria: currentFilter,
            onClearAll: () {
              if (_showOffers) {
                filterNotifier.resetOffersFilter();
              } else {
                filterNotifier.resetRequirementsFilter();
              }
            },
            onUpdate: (updated) {
              if (_showOffers) {
                filterNotifier.setOffersFilter(updated);
              } else {
                filterNotifier.setRequirementsFilter(updated);
              }
            },
          ),
        ],

        const SizedBox(height: 10),
        body,
      ],
    );
  }

  Widget _filterButton({
    required int activeCount,
    required VoidCallback onTap,
  }) {
    final hasFilters = activeCount > 0;
    return Material(
      color: hasFilters ? AppColors.primary : AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('home_market_filter_button'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasFilters ? AppColors.primary : AppColors.borderLight,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                LucideIcons.slidersHorizontal,
                size: 19,
                color: hasFilters ? Colors.white : AppColors.primaryNavy,
              ),
              if (hasFilters)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        '$activeCount',
                        key: const Key('home_market_filter_badge_count'),
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeFilterChips({
    required MarketFilterCriteria criteria,
    required VoidCallback onClearAll,
    required ValueChanged<MarketFilterCriteria> onUpdate,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Clear All link
          GestureDetector(
            key: const Key('home_market_clear_all_chips'),
            onTap: onClearAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.rotateCcw, size: 12, color: Color(0xFFDC2626)),
                  SizedBox(width: 4),
                  Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Raw Material Chip
          if (criteria.commodityId != null)
            _filterChip(
              label: 'Raw Material: ${criteria.commodityName ?? "Selected"}',
              onDelete: () => onUpdate(
                criteria.copyWith(
                  commodityId: () => null,
                  commodityName: () => null,
                ),
              ),
            ),

          // Date Chip
          if (criteria.datePreset != DateFilterPreset.all)
            _filterChip(
              label: criteria.datePreset == DateFilterPreset.custom
                  ? 'Custom Date'
                  : criteria.datePreset.label,
              onDelete: () => onUpdate(
                criteria.copyWith(
                  datePreset: DateFilterPreset.all,
                  customStartDate: () => null,
                  customEndDate: () => null,
                ),
              ),
            ),

          // Price Chip
          if (criteria.minPrice != null || criteria.maxPrice != null)
            _filterChip(
              label: _formatRangeLabel('₹', criteria.minPrice, criteria.maxPrice),
              onDelete: () => onUpdate(
                criteria.copyWith(
                  minPrice: () => null,
                  maxPrice: () => null,
                ),
              ),
            ),

          // Quantity Chip
          if (criteria.minQuantity != null || criteria.maxQuantity != null)
            _filterChip(
              label: '${_formatRangeLabel("", criteria.minQuantity, criteria.maxQuantity)} MT',
              onDelete: () => onUpdate(
                criteria.copyWith(
                  minQuantity: () => null,
                  maxQuantity: () => null,
                ),
              ),
            ),

          // Sort Chip
          if (criteria.sortBy != MarketSortOption.newestFirst)
            _filterChip(
              label: 'Sort: ${criteria.sortBy.label}',
              onDelete: () => onUpdate(
                criteria.copyWith(sortBy: MarketSortOption.newestFirst),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatRangeLabel(String prefix, double? min, double? max) {
    if (min != null && max != null) {
      return '$prefix${min.toStringAsFixed(0)} - $prefix${max.toStringAsFixed(0)}';
    } else if (min != null) {
      return '≥ $prefix${min.toStringAsFixed(0)}';
    } else if (max != null) {
      return '≤ $prefix${max.toStringAsFixed(0)}';
    }
    return '';
  }

  Widget _filterChip({
    required String label,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(LucideIcons.x, size: 13, color: AppColors.primaryNavy),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String key,
    required IconData icon,
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final fg = selected ? Colors.white : AppColors.primaryNavy;
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: ValueKey(key),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: selected ? Colors.white : const Color(0xFF7C3AED)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.error : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    key: ValueKey('${key}_count'),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.primaryNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _list({
    required bool loading,
    required String? error,
    required String emptyText,
    required bool hasFilters,
    required VoidCallback onClearFilters,
    required List<Widget> rows,
    required int total,
    required String viewAllRoute,
  }) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }

    if (rows.isEmpty) {
      if (hasFilters) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.backgroundLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.filterX, size: 22, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 10),
              Text(
                'No ${_showOffers ? "seller offers" : "buyer requirements"} match your active filters.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Try adjusting or resetting your filter criteria to see more records.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                key: const Key('home_market_clear_filters_button'),
                icon: const Icon(LucideIcons.rotateCcw, size: 14),
                label: const Text('Clear Filters', style: TextStyle(fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onClearFilters,
              ),
            ],
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          error ?? emptyText,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: 8), child: r),
        if (total > rows.length)
          TextButton(
            key: const ValueKey('home_market_view_all'),
            onPressed: () => context.go(viewAllRoute),
            child: Text('View all $total in Work Desk'),
          ),
      ],
    );
  }

  Widget _requirementRow(RequirementItem r) {
    final location = r.deliveryTerms.trim().isEmpty ? null : _place(r.deliveryTerms);
    return _MarketRow(
      key: ValueKey('home_req_${r.id}'),
      icon: LucideIcons.layers,
      color: const Color(0xFF0F766E),
      title: r.commodityName,
      quantity: r.formattedRequestedQuantity,
      price: '₹${_money.format(r.targetPrice.round())}/${r.unitSymbol}',
      location: location,
      reference: r.ref,
      party: _party(r.buyerCompanyName),
      partyRole: 'Buyer',
      age: _age(r.createdAt),
      active: r.canBeMatched,
      onTap: () => context.push('/requirements/${r.id}'),
    );
  }

  Widget _offerRow(OfferItem o) {
    final location = o.districtName.trim().isEmpty ? null : o.districtName;
    return _MarketRow(
      key: ValueKey('home_offer_${o.id}'),
      icon: LucideIcons.package,
      color: const Color(0xFF7C3AED),
      title: o.commodityName,
      quantity: o.formattedAvailableQuantity,
      price: '₹${_money.format(o.askingPrice.round())}/${o.unitSymbol}',
      location: location,
      reference: o.ref,
      party: _party(o.sellerCompanyName),
      partyRole: 'Seller',
      age: _age(o.createdAt),
      active: o.canBeMatched,
      onTap: () => context.go('/work?tab=1&offerId=${o.id}'),
    );
  }
}

class _MarketRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String quantity;
  final String price;
  final String? location;
  final String reference;
  final String? party;
  final String partyRole;
  final String age;
  final bool active;
  final VoidCallback onTap;

  const _MarketRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.quantity,
    required this.price,
    required this.location,
    required this.reference,
    required this.party,
    required this.partyRole,
    required this.age,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget fact(IconData i, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 14, color: AppColors.textSecondaryLight),
            const SizedBox(width: 3),
            Flexible(
              child: Text(t,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimaryLight)),
            ),
          ],
        );

    return Material(
      color: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryNavy),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(age, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(top: 3, right: 4),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active ? AppColors.primary : AppColors.textDisabled,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        fact(LucideIcons.truck, quantity),
                        fact(LucideIcons.indianRupee, price),
                        if (location != null) fact(LucideIcons.mapPin, location!),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Reference · party (only when the company is readable)
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              fact(LucideIcons.fileText, reference),
                              if (party != null)
                                Row(
                                  key: ValueKey('home_party_$reference'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.user, size: 14, color: AppColors.textSecondaryLight),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        '$partyRole: $party',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: onTap,
                          style: TextButton.styleFrom(
                            backgroundColor: color.withValues(alpha: 0.1),
                            foregroundColor: color,
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('View', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              Icon(LucideIcons.chevronRight, size: 15),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
