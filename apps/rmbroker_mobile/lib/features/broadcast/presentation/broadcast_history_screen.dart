import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/preferences/app_settings_provider.dart';
import '../data/broadcast_history_repository.dart';
import '../domain/broadcast_history_models.dart';

final broadcastHistoryRepositoryProvider = Provider<BroadcastHistoryRepository>((ref) {
  return BroadcastHistoryRepository();
});

class BroadcastHistoryFilterNotifier extends Notifier<BroadcastHistoryFilter> {
  @override
  BroadcastHistoryFilter build() => const BroadcastHistoryFilter();

  void update(BroadcastHistoryFilter Function(BroadcastHistoryFilter) cb) {
    state = cb(state);
  }

  void setFilter(BroadcastHistoryFilter filter) {
    state = filter;
  }

  void reset() {
    state = const BroadcastHistoryFilter();
  }
}

final broadcastHistoryFilterProvider =
    NotifierProvider<BroadcastHistoryFilterNotifier, BroadcastHistoryFilter>(
  BroadcastHistoryFilterNotifier.new,
);

final broadcastHistoryFutureProvider = FutureProvider.autoDispose<List<BroadcastHistoryItem>>((ref) async {
  final repo = ref.watch(broadcastHistoryRepositoryProvider);
  final filter = ref.watch(broadcastHistoryFilterProvider);
  return repo.getBroadcastHistory(filter: filter);
});

class BroadcastHistoryScreen extends ConsumerStatefulWidget {
  const BroadcastHistoryScreen({super.key});

  @override
  ConsumerState<BroadcastHistoryScreen> createState() => _BroadcastHistoryScreenState();
}

class _BroadcastHistoryScreenState extends ConsumerState<BroadcastHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final currentSearch = ref.read(broadcastHistoryFilterProvider).searchQuery;
    if (currentSearch != null) {
      _searchController.text = currentSearch;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    ref.read(broadcastHistoryFilterProvider.notifier).update(
          (state) => state.copyWith(searchQuery: val.trim()),
        );
  }

  void _setDatePreset(HistoryDateFilter preset) {
    ref.read(broadcastHistoryFilterProvider.notifier).update(
          (state) => state.copyWith(dateFilter: preset, clearDates: preset != HistoryDateFilter.custom),
        );
  }

  void _clearAllFilters() {
    _searchController.clear();
    ref.read(broadcastHistoryFilterProvider.notifier).reset();
  }

  void _openAdvancedFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BroadcastFilterModal(
        onApplied: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(appSettingsProvider);
    final filter = ref.watch(broadcastHistoryFilterProvider);
    final historyAsync = ref.watch(broadcastHistoryFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          settings.languagePref == AppLanguagePreference.hi
              ? 'प्रसारण मूल्य इतिहास'
              : 'Broadcast Price History',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          // Asterisk icon-only toggle button
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: settings.iconOnlyMode ? 'Show labels (*)' : 'Hide labels (*)',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: settings.iconOnlyMode
                    ? AppColors.primary
                    : AppColors.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '*',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: settings.iconOnlyMode ? Colors.white : AppColors.primary,
                ),
              ),
            ),
            onPressed: () => ref.read(appSettingsProvider.notifier).toggleIconOnlyMode(),
          ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(LucideIcons.slidersHorizontal, size: 20),
                if (filter.hasActiveFilters)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${filter.activeFilterCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Filter Broadcasts',
            onPressed: () => _openAdvancedFilterModal(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search & Quick Date Presets Bar
          Container(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: settings.languagePref == AppLanguagePreference.hi
                        ? 'जिंस, व्यापारी या संदर्भ आईडी खोजें...'
                        : 'Search raw material, buyer, or ref ID...',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick Date Preset Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPresetChip('All Time', HistoryDateFilter.all, filter.dateFilter),
                      const SizedBox(width: 6),
                      _buildPresetChip('Today', HistoryDateFilter.today, filter.dateFilter),
                      const SizedBox(width: 6),
                      _buildPresetChip('Last 7 Days', HistoryDateFilter.last7Days, filter.dateFilter),
                      const SizedBox(width: 6),
                      _buildPresetChip('Last 30 Days', HistoryDateFilter.last30Days, filter.dateFilter),
                      if (filter.dateFilter == HistoryDateFilter.custom) ...[
                        const SizedBox(width: 6),
                        _buildPresetChip('Custom', HistoryDateFilter.custom, filter.dateFilter),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Active Filters Strip (if any)
          if (filter.hasActiveFilters)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  Text(
                    '${filter.activeFilterCount} active filters:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (filter.commodity != null && filter.commodity != 'All')
                            _buildFilterTag(
                              filter.commodity!,
                              () => ref.read(broadcastHistoryFilterProvider.notifier).update(
                                    (s) => s.copyWith(clearCommodity: true),
                                  ),
                            ),
                          if (filter.buyerSearch != null && filter.buyerSearch!.isNotEmpty)
                            _buildFilterTag(
                              'Buyer: ${filter.buyerSearch}',
                              () => ref.read(broadcastHistoryFilterProvider.notifier).update(
                                    (s) => s.copyWith(clearBuyer: true),
                                  ),
                            ),
                          if (filter.status != null)
                            _buildFilterTag(
                              'Status: ${filter.status!.label}',
                              () => ref.read(broadcastHistoryFilterProvider.notifier).update(
                                    (s) => s.copyWith(clearStatus: true),
                                  ),
                            ),
                          if (filter.minPrice != null || filter.maxPrice != null)
                            _buildFilterTag(
                              '₹${filter.minPrice?.toInt() ?? 0} - ₹${filter.maxPrice?.toInt() ?? 'Max'}',
                              () => ref.read(broadcastHistoryFilterProvider.notifier).update(
                                    (s) => s.copyWith(clearPrice: true),
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearAllFilters,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const Text('Reset', style: TextStyle(fontSize: 12, color: AppColors.error)),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Broadcast History List
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.alertTriangle, size: 40, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load history',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(err.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.refresh(broadcastHistoryFutureProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.history,
                            size: 56,
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            settings.languagePref == AppLanguagePreference.hi
                                ? 'कोई प्रसारण रिकॉर्ड नहीं मिला'
                                : 'No Broadcast Records Found',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            filter.hasActiveFilters
                                ? 'No broadcasts match your active filter settings. Try resetting filters.'
                                : 'You have not dispatched any market price broadcasts yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          if (filter.hasActiveFilters) ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _clearAllFilters,
                              icon: const Icon(LucideIcons.filterX, size: 16),
                              label: const Text('Reset All Filters'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(broadcastHistoryFutureProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _BroadcastHistoryCard(
                        item: item,
                        onTap: () => context.push('/broadcast/history/${item.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, HistoryDateFilter preset, HistoryDateFilter current) {
    final isSelected = preset == current;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (val) {
        if (val) _setDatePreset(preset);
      },
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildFilterTag(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(LucideIcons.x, size: 12, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

/// Card representing a historical broadcast in the list.
class _BroadcastHistoryCard extends StatelessWidget {
  final BroadcastHistoryItem item;
  final VoidCallback onTap;

  const _BroadcastHistoryCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final f = NumberFormat('#,##,###.##', 'en_IN');

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      color: isDark ? AppColors.cardDark : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Broadcast ID, Sent Time, Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.id,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.formattedSentAt,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _buildDeliveryBadge(item),
                ],
              ),
              const SizedBox(height: 10),

              // Raw Materials and Immutable Prices Sent
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  children: item.priceSnapshots.map((p) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        p.commodityName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        'v${p.version}',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  p.sellerCompanyName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${f.format(p.askingPrice)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                '/ ${p.unitSymbol}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 10),

              // Bottom Row: Recipient count & Detail action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.users, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${item.totalRecipients} Associated Buyers',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Inspect Recipients',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 14,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryBadge(BroadcastHistoryItem item) {
    if (item.hasFailure) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.errorBackground.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertTriangle, size: 10, color: AppColors.error),
            const SizedBox(width: 4),
            Text(
              '${item.failedCount} Failed',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.error),
            ),
          ],
        ),
      );
    }

    final readCount = item.recipients.where((r) => r.deliveryStatus == BroadcastDeliveryStatus.read).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.successBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.checkCheck, size: 10, color: AppColors.success),
          const SizedBox(width: 4),
          Text(
            readCount > 0 ? '$readCount Read' : 'Delivered',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
          ),
        ],
      ),
    );
  }
}

/// Advanced multi-criteria filter modal sheet.
class _BroadcastFilterModal extends ConsumerStatefulWidget {
  final VoidCallback onApplied;
  const _BroadcastFilterModal({required this.onApplied});

  @override
  ConsumerState<_BroadcastFilterModal> createState() => _BroadcastFilterModalState();
}

class _BroadcastFilterModalState extends ConsumerState<_BroadcastFilterModal> {
  late HistoryDateFilter _dateFilter;
  DateTime? _startDate;
  DateTime? _endDate;
  late TextEditingController _buyerController;
  late TextEditingController _minPriceController;
  late TextEditingController _maxPriceController;
  String? _selectedCommodity;
  BroadcastDeliveryStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(broadcastHistoryFilterProvider);
    _dateFilter = filter.dateFilter;
    _startDate = filter.customStartDate;
    _endDate = filter.customEndDate;
    _buyerController = TextEditingController(text: filter.buyerSearch ?? '');
    _minPriceController = TextEditingController(text: filter.minPrice?.toStringAsFixed(0) ?? '');
    _maxPriceController = TextEditingController(text: filter.maxPrice?.toStringAsFixed(0) ?? '');
    _selectedCommodity = filter.commodity;
    _selectedStatus = filter.status;
  }

  @override
  void dispose() {
    _buyerController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final minP = double.tryParse(_minPriceController.text.trim());
    final maxP = double.tryParse(_maxPriceController.text.trim());
    final buyer = _buyerController.text.trim();

    ref.read(broadcastHistoryFilterProvider.notifier).setFilter(BroadcastHistoryFilter(
      dateFilter: _dateFilter,
      customStartDate: _startDate,
      customEndDate: _endDate,
      buyerSearch: buyer.isNotEmpty ? buyer : null,
      commodity: _selectedCommodity,
      minPrice: minP,
      maxPrice: maxP,
      status: _selectedStatus,
    ));

    widget.onApplied();
    Navigator.pop(context);
  }

  void _resetModalFilters() {
    setState(() {
      _dateFilter = HistoryDateFilter.all;
      _startDate = null;
      _endDate = null;
      _buyerController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
      _selectedCommodity = null;
      _selectedStatus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle & Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Broadcast History',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  TextButton(
                    onPressed: _resetModalFilters,
                    child: const Text('Reset', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 1. Date Range
                  const Text('Date Range', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: HistoryDateFilter.values.map((f) {
                      return ChoiceChip(
                        label: Text(f.label, style: const TextStyle(fontSize: 12)),
                        selected: _dateFilter == f,
                        onSelected: (val) {
                          if (val) setState(() => _dateFilter = f);
                        },
                      );
                    }).toList(),
                  ),

                  if (_dateFilter == HistoryDateFilter.custom) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime(2025),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) setState(() => _startDate = picked);
                            },
                            child: Text(
                              _startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : 'Start Date',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('to'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now(),
                                firstDate: DateTime(2025),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) setState(() => _endDate = picked);
                            },
                            child: Text(
                              _endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : 'End Date',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // 2. Commodity Filter
                  const Text('Raw Material / Commodity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCommodity,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    hint: const Text('All Commodities'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Commodities')),
                      DropdownMenuItem(value: 'Mustard Seed (Sarson)', child: Text('Mustard Seed (Sarson)')),
                      DropdownMenuItem(value: 'Soybean (Yellow)', child: Text('Soybean (Yellow)')),
                      DropdownMenuItem(value: 'Chana (Gram Desi)', child: Text('Chana (Gram Desi)')),
                      DropdownMenuItem(value: 'Wheat (Sharbati)', child: Text('Wheat (Sharbati)')),
                    ],
                    onChanged: (val) => setState(() => _selectedCommodity = val),
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // 3. Buyer Recipient Search
                  const Text('Buyer / Business Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _buyerController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Sharma Agro, Krishna Solvent',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // 4. Price Range (₹)
                  const Text('Price Range (₹)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            prefixText: '₹ ',
                            hintText: 'Min',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('—'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _maxPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            prefixText: '₹ ',
                            hintText: 'Max',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // 5. Delivery Status
                  const Text('Delivery Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All Statuses', style: TextStyle(fontSize: 12)),
                        selected: _selectedStatus == null,
                        onSelected: (val) {
                          if (val) setState(() => _selectedStatus = null);
                        },
                      ),
                      ...BroadcastDeliveryStatus.values.map((s) {
                        return ChoiceChip(
                          label: Text(s.label, style: const TextStyle(fontSize: 12)),
                          selected: _selectedStatus == s,
                          onSelected: (val) {
                            setState(() => _selectedStatus = val ? s : null);
                          },
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),

            // Apply Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _applyFilters,
                  child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
