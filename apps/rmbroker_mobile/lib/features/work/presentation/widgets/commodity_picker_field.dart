import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/trade_master_data.dart';

/// Product field for broker forms: shows the selected product with its authoritative
/// category label and opens a searchable picker over the shared catalogue.
class CommodityPickerField extends StatelessWidget {
  final List<MasterDropdownItem> commodities;
  final MasterDropdownItem? selected;
  final ValueChanged<MasterDropdownItem> onSelected;

  const CommodityPickerField({
    super.key,
    required this.commodities,
    required this.selected,
    required this.onSelected,
  });

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<MasterDropdownItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommodityPickerSheet(commodities: commodities, selectedId: selected?.id),
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final sel = selected;
    return InkWell(
      key: const Key('commodity-picker-field'),
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Commodity *',
          border: OutlineInputBorder(),
          isDense: true,
          suffixIcon: Icon(LucideIcons.search, size: 18),
        ),
        child: sel == null
            ? const Text(
                'Tap to search products',
                style: TextStyle(fontSize: 14, color: AppColors.textMutedLight),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sel.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  CategoryLabel(categoryName: sel.categoryName),
                ],
              ),
      ),
    );
  }
}

/// "Category: …" label from the product's category association; never inferred.
class CategoryLabel extends StatelessWidget {
  final String? categoryName;

  const CategoryLabel({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    final name = categoryName?.trim() ?? '';
    final ok = name.isNotEmpty;
    return Text(
      ok ? 'Category: $name' : 'Category unavailable',
      key: const Key('commodity-category-label'),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: ok ? AppColors.primaryDark : AppColors.error,
      ),
    );
  }
}

/// Searchable list of products; case-insensitive partial-name match, A→Z, no preselection.
class CommodityPickerSheet extends StatefulWidget {
  final List<MasterDropdownItem> commodities;
  final String? selectedId;

  const CommodityPickerSheet({super.key, required this.commodities, this.selectedId});

  @override
  State<CommodityPickerSheet> createState() => _CommodityPickerSheetState();
}

class _CommodityPickerSheetState extends State<CommodityPickerSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MasterDropdownItem> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.commodities;
    return widget.commodities.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Material(
      color: AppColors.surfaceLight,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select Product',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('commodity-picker-search'),
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Type any part of a product name',
                prefixIcon: Icon(LucideIcons.search, size: 18),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        widget.commodities.isEmpty
                            ? 'No active products are available in the catalogue.'
                            : 'No product matches "${_searchController.text.trim()}".',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final c = filtered[i];
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
