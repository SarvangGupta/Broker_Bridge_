import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/master_commodity_data.dart';

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

/// Opens the searchable product picker over the live catalogue. Resolves to the
/// selected product, or null when dismissed.
Future<MasterCommodity?> showCommodityPickerSheet({
  required BuildContext context,
  required List<MasterCommodity> commodities,
  required Future<List<MasterCommodity>> Function() onRefresh,
  String? selectedId,
}) {
  return showModalBottomSheet<MasterCommodity>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CommodityPickerSheet(
      commodities: commodities,
      onRefresh: onRefresh,
      selectedId: selectedId,
    ),
  );
}

class CommodityPickerSheet extends StatefulWidget {
  final List<MasterCommodity> commodities;
  final Future<List<MasterCommodity>> Function() onRefresh;
  final String? selectedId;

  const CommodityPickerSheet({
    super.key,
    required this.commodities,
    required this.onRefresh,
    this.selectedId,
  });

  @override
  State<CommodityPickerSheet> createState() => _CommodityPickerSheetState();
}

class _CommodityPickerSheetState extends State<CommodityPickerSheet> {
  final _searchController = TextEditingController();
  late List<MasterCommodity> _items = widget.commodities;
  bool _isRefreshing = false;
  String? _refreshError;

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

  List<MasterCommodity> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
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
              child: filtered.isEmpty
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
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final c = filtered[index];
                        final isSelected = c.id == widget.selectedId;
                        return ListTile(
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
                          onTap: () => Navigator.of(context).pop(c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
