import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_text_field.dart';
import '../domain/master_requirement_data.dart';

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

/// Opens the searchable commodity picker over the live Product Master catalogue.
/// Resolves to the selected commodity, or null when dismissed.
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
    builder: (ctx) => CommodityPickerSheet(
      commodities: commodities,
      onRefresh: onRefresh,
      selectedId: selectedId,
    ),
  );
}

/// Bottom sheet listing fetched commodities with name search and manual refresh.
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
        _refreshError = 'Could not refresh the commodity catalogue.';
      });
    }
  }

  List<MasterCommodity> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items
        .where(
          (c) =>
              c.name.toLowerCase().contains(query) ||
              c.code.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Commodity',
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
            const SizedBox(height: 8),
            AppTextField(
              key: const Key('commodity-picker-search'),
              controller: _searchController,
              hint: 'Search commodity by name',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
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
              child: _items.isEmpty
                  ? _buildMessage(
                      _isRefreshing ? 'Loading commodity catalogue...' : 'No active commodities are available in the catalogue.',
                    )
                  : filtered.isEmpty
                  ? _buildMessage(
                      'No commodity matches "${_searchController.text.trim()}".',
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final c = filtered[index];
                        final isSelected = c.id == widget.selectedId;
                        return ListTile(
                          key: Key('commodity-option-${c.id}'),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          title: Text(
                            c.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          subtitle: CategoryLabel(categoryName: c.categoryName),
                          trailing: isSelected
                              ? const Icon(
                                  LucideIcons.check,
                                  size: 18,
                                  color: AppColors.primary,
                                )
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

  Widget _buildMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}
