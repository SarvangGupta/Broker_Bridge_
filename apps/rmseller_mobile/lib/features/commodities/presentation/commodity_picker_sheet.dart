import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/master_commodity_data.dart';
import '../domain/posting_history.dart';

/// "Category: …" label from the product's category association; never inferred from the name.
class CategoryLabel extends StatelessWidget {
  final String? categoryName;

  const CategoryLabel({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    final name = categoryName?.trim() ?? '';
    final ok = name.isNotEmpty;
    return Text(
      ok ? 'Category: $name' : 'Category unavailable',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: ok ? AppColors.primaryDark : AppColors.error,
      ),
    );
  }
}

/// Posting-history state shown at the top of the picker.
class PickerHistory {
  /// Distinct previously posted products, most recent first.
  final List<PreviousCommodity> items;

  /// Set when the history could not be loaded (never shown as "no history").
  final String? error;

  /// False when no history source applies (e.g. offline mode).
  final bool available;

  const PickerHistory({this.items = const [], this.error, this.available = true});
  const PickerHistory.unavailable() : items = const [], error = null, available = false;
}

/// Opens the searchable product picker over the live catalogue. Resolves to the
/// selected product (with the remembered grade when picked from history), or
/// null when dismissed.
Future<CommodityPick?> showCommodityPickerSheet({
  required BuildContext context,
  required List<MasterCommodity> commodities,
  required Future<List<MasterCommodity>> Function() onRefresh,
  String? selectedId,
  PickerHistory history = const PickerHistory.unavailable(),
  Future<PickerHistory> Function()? onRetryHistory,
  List<MasterCommodity> expertiseCommodities = const [],
}) {
  return showModalBottomSheet<CommodityPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CommodityPickerSheet(
      commodities: commodities,
      onRefresh: onRefresh,
      selectedId: selectedId,
      history: history,
      onRetryHistory: onRetryHistory,
      expertiseCommodities: expertiseCommodities,
    ),
  );
}

class CommodityPickerSheet extends StatefulWidget {
  final List<MasterCommodity> commodities;
  final Future<List<MasterCommodity>> Function() onRefresh;
  final String? selectedId;
  final PickerHistory history;
  final Future<PickerHistory> Function()? onRetryHistory;
  final List<MasterCommodity> expertiseCommodities;

  const CommodityPickerSheet({
    super.key,
    required this.commodities,
    required this.onRefresh,
    this.selectedId,
    this.history = const PickerHistory.unavailable(),
    this.onRetryHistory,
    this.expertiseCommodities = const [],
  });

  @override
  State<CommodityPickerSheet> createState() => _CommodityPickerSheetState();
}

class _CommodityPickerSheetState extends State<CommodityPickerSheet> {
  final _searchController = TextEditingController();
  late List<MasterCommodity> _items = widget.commodities;
  late PickerHistory _history = widget.history;
  bool _isRefreshing = false;
  bool _retryingHistory = false;
  String? _refreshError;

  Future<void> _retryHistory() async {
    final retry = widget.onRetryHistory;
    if (retry == null) return;
    setState(() => _retryingHistory = true);
    final h = await retry();
    if (!mounted) return;
    setState(() {
      _history = h;
      _retryingHistory = false;
    });
  }

  /// History entries whose product is still in the active catalogue and
  /// matches the search.
  List<(PreviousCommodity, MasterCommodity)> get _previous {
    final q = _searchController.text.trim().toLowerCase();
    final byId = {for (final c in _items) c.id: c};
    return [
      for (final p in _history.items)
        if (byId[p.commodityId] case final c?)
          if (q.isEmpty || c.name.toLowerCase().contains(q)) (p, c),
    ];
  }

  Widget _sectionLabel(String text, {Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: AppColors.textSecondaryLight,
      ),
    ),
  );

  List<Widget> _historyWidgets() {
    final h = _history;
    if (!h.available) return const [];
    if (h.error != null) {
      return [
        Padding(
          key: const Key('picker-history-error'),
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  h.error!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ),
              if (widget.onRetryHistory != null)
                _retryingHistory
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: _retryHistory,
                        child: const Text('Retry'),
                      ),
            ],
          ),
        ),
      ];
    }
    if (h.items.isEmpty) {
      return [
        _sectionLabel(
          'Choose your first commodity',
          key: const Key('picker-first-commodity'),
        ),
      ];
    }
    final prev = _previous;
    if (prev.isEmpty) return const [];
    return [
      _sectionLabel(
        'Your Previously Posted Commodities',
        key: const Key('picker-previous-header'),
      ),
      for (final (p, c) in prev)
        ListTile(
          key: Key('previous-option-${p.commodityId}-${p.gradeId ?? ''}'),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const Icon(LucideIcons.history, size: 18, color: AppColors.primary),
          title: Text(
            p.gradeName.isNotEmpty ? '${c.name} · ${p.gradeName}' : c.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: CategoryLabel(categoryName: c.categoryName),
          onTap: () => Navigator.of(context).pop(
            CommodityPick(c, preferredGradeId: p.gradeId),
          ),
        ),
      _sectionLabel('All products'),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _isRefreshing = true;
      _refreshError = null;
    });
    try {
      final items = await widget.onRefresh();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isRefreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _refreshError = 'Could not refresh the product catalogue.';
      });
    }
  }

  List<MasterCommodity> get _filteredExpertise {
    if (widget.expertiseCommodities.isEmpty) return const [];
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.expertiseCommodities;
    return widget.expertiseCommodities
        .where((c) => c.name.toLowerCase().contains(q) || (c.categoryName?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  List<MasterCommodity> get _filteredAll {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where((c) => c.name.toLowerCase().contains(q) || (c.categoryName?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  List<Widget> _buildItemList() {
    final widgets = <Widget>[];

    // Row 0: posting history (previous products first)
    final history = _historyWidgets();
    if (history.isNotEmpty) {
      widgets.addAll(history);
    }

    final expertise = _filteredExpertise;
    final all = _filteredAll;

    if (widget.expertiseCommodities.isNotEmpty && expertise.isNotEmpty) {
      widgets.add(_sectionLabel('My Expertise', key: const Key('picker-expertise-header')));
      for (final c in expertise) {
        final isSelected = c.id == widget.selectedId;
        widgets.add(
          ListTile(
            key: Key('expertise-commodity-option-${c.id}'),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(LucideIcons.sparkles, size: 18, color: AppColors.primary),
            title: Text(
              c.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
            ),
            subtitle: CategoryLabel(categoryName: c.categoryName),
            trailing: isSelected
                ? const Icon(LucideIcons.check, size: 18, color: AppColors.primary)
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Expertise',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ),
            onTap: () => Navigator.of(context).pop(CommodityPick(c)),
          ),
        );
      }
      widgets.add(_sectionLabel('All Commodities', key: const Key('picker-all-commodities-header')));
    }

    for (final c in all) {
      final isSelected = c.id == widget.selectedId;
      widgets.add(
        ListTile(
          key: Key('commodity-option-${c.id}'),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(
            c.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textPrimaryLight,
            ),
          ),
          subtitle: CategoryLabel(categoryName: c.categoryName),
          trailing: isSelected
              ? const Icon(LucideIcons.check, size: 18, color: AppColors.primary)
              : null,
          onTap: () => Navigator.of(context).pop(CommodityPick(c)),
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItemList();
    final all = _filteredAll;
    final expertise = _filteredExpertise;
    final isEmpty = all.isEmpty && expertise.isEmpty;

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Product',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                _isRefreshing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        key: const Key('commodity-picker-refresh'),
                        tooltip: 'Refresh catalogue',
                        icon: const Icon(LucideIcons.refreshCw, size: 18),
                        onPressed: _refresh,
                      ),
              ],
            ),
            TextField(
              key: const Key('commodity-picker-search'),
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Type any part of a product name',
                prefixIcon: Icon(LucideIcons.search, size: 18),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_refreshError != null) ...[
              const SizedBox(height: 8),
              Text(
                _refreshError!,
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ],
            const SizedBox(height: 8),
            Flexible(
              child: isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        _items.isEmpty
                            ? 'No active products are available in the catalogue.'
                            : 'No product matches "${_searchController.text.trim()}".',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) => items[index],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
