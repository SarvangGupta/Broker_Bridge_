import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../work/domain/trade_master_data.dart';
import '../../../work/presentation/controllers/master_data_controller.dart';
import '../../domain/market_filter_criteria.dart';

/// Modal bottom sheet for filtering and sorting Buyer Requirements and Seller Offers.
class MarketFilterSheet extends ConsumerStatefulWidget {
  final MarketFilterCriteria initialCriteria;
  final bool isOffersTab;
  final ValueChanged<MarketFilterCriteria> onApply;

  const MarketFilterSheet({
    super.key,
    required this.initialCriteria,
    required this.isOffersTab,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required MarketFilterCriteria initialCriteria,
    required bool isOffersTab,
    required ValueChanged<MarketFilterCriteria> onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MarketFilterSheet(
        initialCriteria: initialCriteria,
        isOffersTab: isOffersTab,
        onApply: onApply,
      ),
    );
  }

  @override
  ConsumerState<MarketFilterSheet> createState() => _MarketFilterSheetState();
}

class _MarketFilterSheetState extends ConsumerState<MarketFilterSheet> {
  late String? _commodityId;
  late String? _commodityName;
  late DateFilterPreset _datePreset;
  late DateTime? _customStartDate;
  late DateTime? _customEndDate;
  late TextEditingController _minPriceCtrl;
  late TextEditingController _maxPriceCtrl;
  late TextEditingController _minQtyCtrl;
  late TextEditingController _maxQtyCtrl;
  late MarketSortOption _sortBy;

  final DateFormat _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _commodityId = widget.initialCriteria.commodityId;
    _commodityName = widget.initialCriteria.commodityName;
    _datePreset = widget.initialCriteria.datePreset;
    _customStartDate = widget.initialCriteria.customStartDate;
    _customEndDate = widget.initialCriteria.customEndDate;

    _minPriceCtrl = TextEditingController(
      text: widget.initialCriteria.minPrice != null
          ? widget.initialCriteria.minPrice!.toStringAsFixed(0)
          : '',
    );
    _maxPriceCtrl = TextEditingController(
      text: widget.initialCriteria.maxPrice != null
          ? widget.initialCriteria.maxPrice!.toStringAsFixed(0)
          : '',
    );
    _minQtyCtrl = TextEditingController(
      text: widget.initialCriteria.minQuantity != null
          ? widget.initialCriteria.minQuantity!.toStringAsFixed(0)
          : '',
    );
    _maxQtyCtrl = TextEditingController(
      text: widget.initialCriteria.maxQuantity != null
          ? widget.initialCriteria.maxQuantity!.toStringAsFixed(0)
          : '',
    );
    _sortBy = widget.initialCriteria.sortBy;
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _minQtyCtrl.dispose();
    _maxQtyCtrl.dispose();
    super.dispose();
  }

  void _resetAll() {
    setState(() {
      _commodityId = null;
      _commodityName = null;
      _datePreset = DateFilterPreset.all;
      _customStartDate = null;
      _customEndDate = null;
      _minPriceCtrl.clear();
      _maxPriceCtrl.clear();
      _minQtyCtrl.clear();
      _maxQtyCtrl.clear();
      _sortBy = MarketSortOption.newestFirst;
    });
  }

  void _apply() {
    final minPrice = double.tryParse(_minPriceCtrl.text.trim());
    final maxPrice = double.tryParse(_maxPriceCtrl.text.trim());
    final minQty = double.tryParse(_minQtyCtrl.text.trim());
    final maxQty = double.tryParse(_maxQtyCtrl.text.trim());

    final criteria = MarketFilterCriteria(
      commodityId: _commodityId,
      commodityName: _commodityName,
      datePreset: _datePreset,
      customStartDate: _customStartDate,
      customEndDate: _customEndDate,
      minPrice: minPrice,
      maxPrice: maxPrice,
      minQuantity: minQty,
      maxQuantity: maxQty,
      sortBy: _sortBy,
    );

    widget.onApply(criteria);
    Navigator.of(context).pop();
  }

  Future<void> _pickCustomDate({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? (_customStartDate ?? now.subtract(const Duration(days: 7)))
        : (_customEndDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.primaryNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _customStartDate = picked;
          if (_customEndDate != null && _customEndDate!.isBefore(picked)) {
            _customEndDate = picked;
          }
        } else {
          _customEndDate = picked;
          if (_customStartDate != null && _customStartDate!.isAfter(picked)) {
            _customStartDate = picked;
          }
        }
      });
    }
  }

  void _openCommodityPicker(List<MasterDropdownItem> commodities) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pickerCtx) {
        return _CommoditySearchModal(
          commodities: commodities,
          selectedId: _commodityId,
          onSelected: (item) {
            setState(() {
              if (item == null) {
                _commodityId = null;
                _commodityName = null;
              } else {
                _commodityId = item.id;
                _commodityName = item.name;
              }
            });
            Navigator.of(pickerCtx).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final masterAsync = ref.watch(masterDataProvider);
    final commodities = masterAsync.maybeWhen(
      data: (data) => data.commodities,
      orElse: () => <MasterDropdownItem>[],
    );

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final tabTitle = widget.isOffersTab ? 'Seller Offers' : 'Buyer Requirements';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Title Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.slidersHorizontal, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filter & Sort',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                          Text(
                            tabTitle,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('filter_sheet_close_button'),
                      icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondaryLight),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderLight),

              // Scrollable Filter Sections
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  children: [
                    // --- 1. Raw Material / Commodity ---
                    _sectionHeader('Raw Material (Commodity)', LucideIcons.package),
                    const SizedBox(height: 8),
                    InkWell(
                      key: const Key('filter_commodity_selector'),
                      onTap: () => _openCommodityPicker(commodities),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _commodityId != null ? AppColors.primary : AppColors.borderLight,
                            width: _commodityId != null ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.search, size: 16, color: AppColors.textSecondaryLight),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _commodityName ?? 'All Raw Materials (Tap to select)',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: _commodityId != null ? FontWeight.w700 : FontWeight.w500,
                                  color: _commodityId != null
                                      ? AppColors.primaryNavy
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                            if (_commodityId != null)
                              GestureDetector(
                                key: const Key('filter_commodity_clear'),
                                onTap: () => setState(() {
                                  _commodityId = null;
                                  _commodityName = null;
                                }),
                                child: const Icon(LucideIcons.xCircle, size: 16, color: AppColors.textSecondaryLight),
                              )
                            else
                              const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondaryLight),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // --- 2. Date Filter ---
                    _sectionHeader('Date Range', LucideIcons.calendar),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preset in DateFilterPreset.values)
                          ChoiceChip(
                            key: Key('filter_date_${preset.name}'),
                            label: Text(preset.label),
                            selected: _datePreset == preset,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.surfaceLight,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: _datePreset == preset ? FontWeight.w700 : FontWeight.w500,
                              color: _datePreset == preset ? Colors.white : AppColors.primaryNavy,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: _datePreset == preset ? AppColors.primary : AppColors.borderLight,
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _datePreset = preset;
                                });
                              }
                            },
                          ),
                      ],
                    ),

                    if (_datePreset == DateFilterPreset.custom) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _datePickerField(
                              key: 'filter_custom_start_date',
                              label: 'From Date',
                              date: _customStartDate,
                              onTap: () => _pickCustomDate(isStart: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _datePickerField(
                              key: 'filter_custom_end_date',
                              label: 'To Date',
                              date: _customEndDate,
                              onTap: () => _pickCustomDate(isStart: false),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),

                    // --- 3. Price Filter (₹/MT) ---
                    _sectionHeader(
                      widget.isOffersTab ? 'Asking Price (₹/MT)' : 'Target Price (₹/MT)',
                      LucideIcons.indianRupee,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _numericInput(
                            key: 'filter_min_price',
                            controller: _minPriceCtrl,
                            label: 'Min Price',
                            hint: 'e.g. 20000',
                            prefix: '₹',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _numericInput(
                            key: 'filter_max_price',
                            controller: _maxPriceCtrl,
                            label: 'Max Price',
                            hint: 'e.g. 35000',
                            prefix: '₹',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // --- 4. Quantity Filter (MT) ---
                    _sectionHeader(
                      widget.isOffersTab ? 'Available Quantity (MT)' : 'Required Quantity (MT)',
                      LucideIcons.truck,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _numericInput(
                            key: 'filter_min_quantity',
                            controller: _minQtyCtrl,
                            label: 'Min Qty',
                            hint: 'e.g. 50',
                            suffix: 'MT',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _numericInput(
                            key: 'filter_max_quantity',
                            controller: _maxQtyCtrl,
                            label: 'Max Qty',
                            hint: 'e.g. 500',
                            suffix: 'MT',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // --- 5. Sort Options ---
                    _sectionHeader('Sort By', LucideIcons.arrowUpDown),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final opt in MarketSortOption.values)
                          ChoiceChip(
                            key: Key('filter_sort_${opt.name}'),
                            label: Text(opt.label),
                            selected: _sortBy == opt,
                            selectedColor: AppColors.primaryNavy,
                            backgroundColor: AppColors.surfaceLight,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: _sortBy == opt ? FontWeight.w700 : FontWeight.w500,
                              color: _sortBy == opt ? Colors.white : AppColors.primaryNavy,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: _sortBy == opt ? AppColors.primaryNavy : AppColors.borderLight,
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _sortBy = opt;
                                });
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.borderLight)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        key: const Key('filter_reset_all_button'),
                        onPressed: _resetAll,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondaryLight,
                          side: const BorderSide(color: AppColors.borderLight),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'Reset All',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        key: const Key('filter_apply_button'),
                        onPressed: _apply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
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

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryNavy,
          ),
        ),
      ],
    );
  }

  Widget _numericInput({
    required String key,
    required TextEditingController controller,
    required String label,
    required String hint,
    String? prefix,
    String? suffix,
  }) {
    return TextFormField(
      key: Key(key),
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textDisabled),
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
        prefixText: prefix != null ? '$prefix ' : null,
        suffixText: suffix,
        prefixStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryNavy),
        suffixStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderLight)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }

  Widget _datePickerField({
    required String key,
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: Key(key),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    date != null ? _dateFmt.format(date) : 'Select date',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: date != null ? FontWeight.w700 : FontWeight.w500,
                      color: date != null ? AppColors.primaryNavy : AppColors.textDisabled,
                    ),
                  ),
                ),
                const Icon(LucideIcons.calendar, size: 14, color: AppColors.textSecondaryLight),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Searchable modal bottom sheet to select a commodity from master commodities.
class _CommoditySearchModal extends StatefulWidget {
  final List<MasterDropdownItem> commodities;
  final String? selectedId;
  final ValueChanged<MasterDropdownItem?> onSelected;

  const _CommoditySearchModal({
    required this.commodities,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  State<_CommoditySearchModal> createState() => _CommoditySearchModalState();
}

class _CommoditySearchModalState extends State<_CommoditySearchModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.commodities.where((c) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      final nameMatches = c.name.toLowerCase().contains(q);
      final catMatches = c.categoryName?.toLowerCase().contains(q) ?? false;
      return nameMatches || catMatches;
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  const Text(
                    'Select Raw Material',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('commodity_search_field'),
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (val) => setState(() => _query = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search raw material by name...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textDisabled),
                  prefixIcon: const Icon(LucideIcons.search, size: 16, color: AppColors.textSecondaryLight),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.xCircle, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderLight)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderLight)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // "All Raw Materials" option to clear selection
            ListTile(
              key: const Key('commodity_item_all'),
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.asterisk, size: 16, color: AppColors.primary),
              ),
              title: const Text('All Raw Materials', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              trailing: widget.selectedId == null
                  ? const Icon(LucideIcons.check, size: 18, color: AppColors.primary)
                  : null,
              onTap: () => widget.onSelected(null),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No commodities found',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, index) => const Divider(height: 1, indent: 56),
                      itemBuilder: (ctx, index) {
                        final item = filtered[index];
                        final isSelected = item.id == widget.selectedId;
                        return ListTile(
                          key: Key('commodity_item_${item.id}'),
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(LucideIcons.package, size: 16, color: AppColors.primary),
                          ),
                          title: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? AppColors.primary : AppColors.primaryNavy,
                            ),
                          ),
                          subtitle: item.categoryName != null
                              ? Text(
                                  item.categoryName!,
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
                                )
                              : null,
                          trailing: isSelected
                              ? const Icon(LucideIcons.check, size: 18, color: AppColors.primary)
                              : null,
                          onTap: () => widget.onSelected(item),
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
